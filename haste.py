#!/usr/bin/env python3
"""Haste prototype compiler: Haste source -> C -> native executables (via zig cc).

    python haste.py run   examples/bank.haste [program switches...]
    python haste.py build examples/bank.haste --target windows,macos,linux
    python haste.py c     examples/bank.haste          (print generated C)
    python haste.py words [examples/bank.haste]         (names an editor should colour)
"""
import os, re, sys, shutil, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))


class HasteError(Exception):
    pass


# ───────────────────────────── lexer ─────────────────────────────

KEYWORDS = {'need', 'class', 'end', 'fn', 'let', 'var', 'if', 'then', 'elif', 'else',
            'while', 'for', 'in', 'return', 'try', 'catch', 'and', 'or', 'not', 'true', 'false',
            'mod', 'div', 'extern', 'init', 'where', 'alias', 'xor', 'shl', 'shr', 'parallel', 'switch', 'write'}
OPS2 = ('<>', '<=', '>=', '..', '=>')
OPS1 = '=<>+-*/()[]{},.:'
NUM = re.compile(r'\d+(\.\d+)?')
WORD = re.compile(r'\w+')


class Tok:
    def __init__(s, kind, val, line, file):
        s.kind, s.val, s.line, s.file = kind, val, line, file


def string_end(src, i, file, line):
    """Index of the quote closing the string that opens at src[i]. Quotes inside {...} belong to the
    interpolated expression, so "{Join(parts, "|")}" is one string."""
    j, depth, n = i + 1, 0, len(src)
    while j < n:
        c = src[j]
        if c == '\n': break
        if c == '\\': j += 2; continue
        if c == '{': depth += 1
        elif c == '}' and depth: depth -= 1
        elif c == '"':
            if not depth: return j
            j = string_end(src, j, file, line)       # a string inside the expression
        j += 1
    raise HasteError(f'{file}:{line}: unterminated string')


def brace_end(raw, i):
    """Index of the } closing the { at raw[i], skipping strings inside it, or -1."""
    j, depth = i, 0
    while j < len(raw):
        c = raw[j]
        if c == '\\': j += 2; continue
        if c == '"': j = string_end(raw, j, '', 0) + 1; continue
        if c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if not depth: return j
        j += 1
    return -1


def lex(src, file, line=1):
    toks, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == '\n':
            toks.append(Tok('NL', '', line, file)); line += 1; i += 1
        elif c in ' \t\r':
            i += 1
        elif src.startswith('//', i):
            while i < n and src[i] != '\n':
                i += 1
        elif c.isdigit():
            m = NUM.match(src, i)
            toks.append(Tok('FLOAT' if m.group(1) else 'INT', m.group(), line, file)); i = m.end()
        elif c.isalpha() or c == '_':
            w = WORD.match(src, i).group()
            toks.append(Tok('KW' if w in KEYWORDS else 'NAME', w, line, file)); i += len(w)
        elif c == '"':
            j = string_end(src, i, file, line)
            toks.append(Tok('STR', src[i + 1:j], line, file)); i = j + 1
        elif src[i:i + 2] in OPS2:
            toks.append(Tok('OP', src[i:i + 2], line, file)); i += 2
        elif c in OPS1:
            toks.append(Tok('OP', c, line, file)); i += 1
        else:
            raise HasteError(f'{file}:{line}: unexpected character {c!r}')
    toks += [Tok('NL', '', line, file), Tok('EOF', '', line, file)]
    return toks


# ───────────────────────────── parser ─────────────────────────────

class N:
    """AST node: N('kind', line, field=value, ...). Nodes remember the file being parsed."""
    current_file = None

    def __init__(s, kind, line=0, **kw):
        s.kind, s.line, s.file = kind, line, N.current_file
        s.__dict__.update(kw)


ESCAPES = {'n': '\n', 'r': '\r', 't': '\t', '\\': '\\', '"': '"', '{': '{', '}': '}'}


class Parser:
    def __init__(s, toks, lines=()):
        s.t, s.p, s.lines = toks, 0, lines
        if toks: N.current_file = toks[0].file

    # helpers
    def peek(s, o=0): return s.t[s.p + o]
    def next(s): s.p += 1; return s.t[s.p - 1]
    def at(s, *vals): t = s.peek(); return t.kind in ('OP', 'KW') and t.val in vals

    def fail(s, msg, t=None):
        t = t or s.peek()
        raise HasteError(f"{t.file}:{t.line}: {msg}, found '{t.val or t.kind.lower()}'")

    def eat(s, val):
        if not s.at(val): s.fail(f"expected '{val}'")
        return s.next()

    def name(s):
        if s.peek().kind != 'NAME': s.fail('expected a name')
        return s.next().val

    def skipnl(s):
        while s.peek().kind == 'NL': s.p += 1

    def nl(s):
        if s.peek().kind not in ('NL', 'EOF'): s.fail('expected end of line')
        s.skipnl()

    def dotted(s):
        parts = [s.name()]
        while s.at('.'):
            s.next(); parts.append(s.name())
        return parts

    def type(s):
        if s.at('['):
            s.next(); t = s.type(); s.eat(']'); return f'[{t}]'
        if s.at('{'):                                    # {string: int}
            s.next(); k = s.type(); s.eat(':'); v = s.type(); s.eat('}'); return '{' + k + ':' + v + '}'
        return '.'.join(s.dotted())

    # top level
    def program(s):
        prog = N('program', imports=[], classes={}, funcs={}, stmts=[], inits=[], aliases={}, switches=[])
        seen = {}                            # functions, classes and aliases share one set of names

        def declare(name, line, what):
            if name in seen:
                was, at = seen[name]
                raise HasteError(f'{s.t[0].file}:{line}: {name} is already {was} on line {at}')
            seen[name] = (what, line)
        s.skipnl()
        while s.peek().kind != 'EOF':
            if s.at('need'):
                t = s.next()
                while True:
                    prog.imports.append((t.val, s.name(), t.line))
                    if not s.at(','): break
                    s.next()
                s.nl()
            elif s.at('switch'):
                prog.switches.append(s.switch())
            elif s.at('alias'):
                line = s.next().line; nm = s.name(); s.eat('=')
                declare(nm, line, 'an alias')
                prog.aliases[nm] = (s.dotted(), line); s.nl()
            elif s.at('class'):
                c = s.cls(); declare(c.name, c.line, 'a class'); prog.classes[c.name] = c
            elif s.at('fn', 'extern'):
                f = s.fn(); declare(f.name, f.line, 'a function'); prog.funcs[f.name] = f
            elif s.at('init'):
                s.next(); s.nl(); prog.inits.append(s.block()); s.eat('end'); s.nl()
            else:
                prog.stmts.append(s.stmt())
            s.skipnl()
        return prog

    def text(s, start):
        return ' '.join(f'"{t.val}"' if t.kind == 'STR' else t.val for t in s.t[start:s.p])

    def switch(s):
        line = s.next().line
        sw = N('switch', line, name=s.name(), type=None, where=None, wtext='')
        if s.at(':'): s.next(); sw.type = s.type()
        s.eat('=')
        start = s.p; sw.default = s.expr(); sw.dtext = s.text(start)
        if s.at('where'):
            s.next(); start = s.p; sw.where = s.expr(); sw.wtext = s.text(start)
        raw = s.lines[line - 1] if line <= len(s.lines) else ''
        sw.help = raw.split('//', 1)[1].strip() if '//' in raw.replace('"//', '') else ''
        s.nl()
        return sw

    def fn(s):
        ext = bool(s.at('extern')) and s.next()
        line = s.eat('fn').line
        f = N('fn', line, name=s.name(), params=[], ret=None, body=None, expr=None, cname=None)
        s.eat('(')
        while not s.at(')'):
            pn = s.name(); pt = None
            if s.at(':'): s.next(); pt = s.type()
            elif ext: s.fail(f'extern parameter {pn} needs a type')
            f.params.append((pn, pt))
            if not s.at(')'): s.eat(',')
        s.eat(')')
        if s.at(':'): s.next(); f.ret = s.type()
        if ext:
            s.eat('=')
            if s.peek().kind != 'STR': s.fail('expected the C function name as a string')
            f.cname = s.next().val; f.ret = f.ret or 'void'; s.nl()
        elif s.at('='):
            s.next(); f.expr = s.expr(); s.nl()
        else:
            s.nl(); f.body = s.block(); s.eat('end'); s.nl()
        return f

    def cls(s):
        line = s.eat('class').line
        c = N('class', line, name=s.name(), props={}, methods={})
        s.nl()
        while not s.at('end'):
            if s.peek().kind == 'EOF': s.fail(f"class {c.name} is missing 'end'")
            if s.at('fn'):
                f = s.fn(); c.methods[f.name] = f; continue
            pl = s.peek().line
            p = N('prop', pl, name=s.name(), type=None, default=None, where=None, wtext=None, computed=None, write=None)
            if s.at(':'): s.next(); p.type = s.type()
            if s.at('=>'):
                s.next(); p.computed = s.expr()
            else:
                if s.at('='): s.next(); p.default = s.expr()
                if s.at('where'):
                    s.next(); start = s.p; p.where = s.expr(); p.wtext = s.text(start)
            if not (p.type or p.default or p.computed):
                s.fail(f'property {p.name} needs a type or a default value')
            c.props[p.name] = p
            s.nl()
            if s.at('write'):                    # write ... end: runs on every assignment to the property
                s.next(); s.nl(); p.write = s.block(); s.eat('end'); s.nl()
        s.eat('end'); s.nl()
        return c

    # statements
    def block(s):
        out = []
        s.skipnl()
        while not s.at('end', 'elif', 'else', 'catch'):
            if s.peek().kind == 'EOF': s.fail("missing 'end'")
            out.append(s.stmt()); s.skipnl()
        return out

    def cond_then(s):
        c = s.expr()
        if s.at('then'): s.next()
        s.nl()
        return c

    def stmt(s):
        t = s.peek(); L = t.line
        if s.at('let', 'var'):
            s.next(); nm = s.name(); ty = None
            if s.at(':'): s.next(); ty = s.type()
            s.eat('='); e = s.expr(); s.nl()
            return N('let', L, name=nm, type=ty, value=e, mutable=t.val == 'var')
        if s.at('if'):
            s.next(); arms = [(s.cond_then(), s.block())]; els = None
            while s.at('elif'):
                s.next(); arms.append((s.cond_then(), s.block()))
            if s.at('else'):
                s.next(); s.nl(); els = s.block()
            s.eat('end'); s.nl()
            return N('if', L, arms=arms, els=els)
        if s.at('while'):
            s.next(); c = s.expr(); s.nl(); b = s.block(); s.eat('end'); s.nl()
            return N('while', L, cond=c, body=b)
        if s.at('parallel', 'for'):
            par = s.next().val == 'parallel'
            if par: s.eat('for')
            v = s.name(); s.eat('in'); a = s.expr(); b = None
            if s.at('..'): s.next(); b = s.expr()
            s.nl(); body = s.block(); s.eat('end'); s.nl()
            return N('for', L, var=v, a=a, b=b, body=body, parallel=par)
        if s.at('return'):
            s.next(); e = None if s.peek().kind in ('NL', 'EOF') else s.expr(); s.nl()
            return N('return', L, value=e)
        if s.at('try'):
            s.next(); s.nl(); b = s.block(); s.eat('catch'); v = s.name(); s.nl()
            h = s.block(); s.eat('end'); s.nl()
            return N('try', L, body=b, var=v, handler=h)
        e = s.postfix()                      # a statement is an assignment or a call
        if s.at('='):
            s.next(); v = s.expr(); s.nl()
            return N('assign', L, target=e, value=v)
        s.nl()
        return N('exprstmt', L, expr=e)

    # expressions, lowest precedence first
    def expr(s):
        if s.at('if'):
            L = s.next().line; c = s.expr(); s.eat('then'); a = s.expr(); s.eat('else')
            return N('ifx', L, cond=c, a=a, b=s.expr())
        return s.binary(0)

    LEVELS = [('or', 'xor'), ('and',), None, ('=', '<>', '<', '>', '<=', '>='), ('+', '-'),
              ('*', '/', 'mod', 'div', 'shl', 'shr')]

    def binary(s, lvl):
        if lvl == len(s.LEVELS): return s.unary()
        if s.LEVELS[lvl] is None:            # 'not' sits between 'and' and comparisons
            if s.at('not'):
                L = s.next().line; return N('un', L, op='not', e=s.binary(lvl))
            return s.binary(lvl + 1)
        e = s.binary(lvl + 1)
        while s.at(*s.LEVELS[lvl]):
            t = s.next()
            e = N('bin', t.line, op=t.val, l=e, r=s.binary(lvl + 1))
            if lvl == 3: break                # comparisons don't chain
        return e

    def unary(s):
        if s.at('-'):
            L = s.next().line; return N('un', L, op='-', e=s.unary())
        return s.postfix()

    def postfix(s):
        e = s.primary()
        while True:
            if s.at('('):
                L = s.next().line; e = N('call', L, fn=e, args=s.args())
            elif s.at('.'):
                L = s.next().line; e = N('member', L, obj=e, name=s.name())
            elif s.at('['):
                L = s.next().line; i = s.expr(); s.eat(']'); e = N('index', L, obj=e, idx=i)
            else:
                return e

    def args(s):
        out = []
        while not s.at(')'):
            nm = None
            if s.peek().kind == 'NAME' and s.peek(1).kind == 'OP' and s.peek(1).val == ':':
                nm = s.next().val; s.next()
            out.append((nm, s.expr()))
            if not s.at(')'): s.eat(',')
        s.next()
        return out

    def primary(s):
        t = s.next(); L = t.line
        if t.kind == 'INT': return N('int', L, v=int(t.val))
        if t.kind == 'FLOAT': return N('float', L, v=t.val)
        if t.kind == 'STR': return s.string(t)
        if t.kind == 'NAME': return N('name', L, name=t.val)
        if t.kind == 'KW' and t.val in ('true', 'false'): return N('bool', L, v=t.val == 'true')
        if t.kind == 'OP' and t.val == '(':
            e = s.expr(); s.eat(')'); return e
        if t.kind == 'OP' and t.val == '[':
            items = []
            s.skipnl()
            while not s.at(']'):
                items.append(s.expr()); s.skipnl()
                if not s.at(']'): s.eat(','); s.skipnl()
            s.next()
            return N('list', L, items=items)
        if t.kind == 'OP' and t.val == '{':               # {"Mark": 50, "Ada": 36}
            pairs = []
            s.skipnl()
            while not s.at('}'):
                k = s.expr(); s.eat(':'); pairs.append((k, s.expr())); s.skipnl()
                if not s.at('}'): s.eat(','); s.skipnl()
            s.next()
            return N('dict', L, pairs=pairs)
        s.p -= 1
        s.fail('expected an expression')

    def string(s, t):
        """"Hello {Name}" -> literal pieces and (expression, decimals) pieces."""
        raw, parts, lit, i = t.val, [], '', 0
        while i < len(raw):
            c = raw[i]
            if c == '\\':
                if raw[i + 1:i + 2] not in ESCAPES: s.fail('unknown escape in string', t)
                lit += ESCAPES[raw[i + 1]]; i += 2
            elif c == '{':
                j = brace_end(raw, i)
                if j < 0: s.fail("missing '}' in string", t)
                inner, spec = raw[i + 1:j], None
                m = re.fullmatch(r'(.*):(\d+)', inner, re.S)
                if m: inner, spec = m.group(1), int(m.group(2))
                sub = Parser(lex(inner, t.file, t.line))
                e = sub.expr()
                if sub.peek().kind not in ('NL', 'EOF'): sub.fail('unexpected text in {...}')
                if lit: parts.append(lit); lit = ''
                parts.append((e, spec)); i = j + 1
            else:
                lit += c; i += 1
        if lit or not parts: parts.append(lit)
        if all(isinstance(p, str) for p in parts):
            return N('str', t.line, v=''.join(parts))
        return N('interp', t.line, parts=parts)


# ─────────────────────────── module loading ───────────────────────────

def load(path, registry, search, name, is_main=False):
    """Parse a source file into a module. Its explicit imports load too."""
    try:
        src = open(path, encoding='utf-8-sig').read()
    except OSError:
        raise HasteError(f'cannot read {path}')
    prog = Parser(lex(src, os.path.basename(path)), src.split('\n')).program()
    mod = N('module', name=name, prog=prog, imports={}, needed=False, is_main=is_main,
            cprefix='f' if is_main else name.replace('.', '_'))
    if not is_main and prog.stmts:
        raise HasteError(f'{path}: a module may only contain classes, functions and init blocks')
    registry[name] = mod
    for kind, iname, line in prog.imports:
        dep = find_module(iname, registry, search)
        if not dep:
            raise HasteError(f'{os.path.basename(path)}:{line}: module {iname} not found')
        mod.imports[iname] = dep
        if kind == 'need': dep.needed = True
    return mod


def find_module(name, registry, search):
    """System.Drawing -> <dir>/System/Drawing.haste, searched in each directory."""
    if name in registry: return registry[name]
    for d in search:
        p = os.path.join(d, *name.split('.')) + '.haste'
        if os.path.exists(p):
            return load(p, registry, search, name)
    return None


# ─────────────────────────── code generator ───────────────────────────

class Env:
    def __init__(e, mod, cls=None, parent=None):
        e.vars, e.mod, e.cls, e.parent = {}, mod, cls, parent
        e.spec = parent.spec if parent else None        # function being generated
        e.in_try = parent.in_try if parent else 0
        e.writing = parent.writing if parent else None   # (class, property) whose write block this is

    def lookup(e, n):
        while e:
            if n in e.vars: return e.vars[n]
            e = e.parent
        return None

    def child(e, in_try=None):
        c = Env(e.mod, e.cls, e)
        if in_try is not None: c.in_try = in_try
        return c


PRIM = {'int': 'long long', 'float': 'double', 'string': 'hs_str', 'bool': 'bool', 'void': 'void'}
CMP = {'=': '==', '<>': '!=', '<': '<', '>': '>', '<=': '<=', '>=': '>='}
BUILTINS = ('print', 'Int', 'Float', 'Str')
BITS = {'and': '&', 'or': '|', 'xor': '^', 'shl': '<<', 'shr': '>>'}
LOGIC = {'and': '&&', 'or': '||', 'xor': '!='}


def cstr(v):
    return '"' + v.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n').replace('\r', '\\r').replace('\t', '\\t') + '"'


def is_num(t): return t in ('int', 'float')


def node_t(vs):
    """'[' or '{' for the pending type a tracked variable was declared with."""
    env, name, _ = vs[0]
    return env.vars.get(name, ('[',))[0][:1]


def kv(t):
    """'{string:[int]}' -> ('string', '[int]')"""
    depth = 0
    for i, c in enumerate(t[1:-1], 1):
        if c in '[{': depth += 1
        elif c in ']}': depth -= 1
        elif c == ':' and depth == 0: return t[1:i], t[i + 1:-1]
    raise HasteError(f'bad dictionary type {t}')


def mangle(t):
    if t.startswith('['): return 'L' + mangle(t[1:-1])
    if t.startswith('{'): k, v = kv(t); return 'D' + mangle(k) + '_' + mangle(v) + '_E'
    return {'int': 'i', 'float': 'f', 'string': 's', 'bool': 'b'}.get(t, t.replace('.', '_'))


def returns_value(stmts):
    for st in stmts:
        if st.kind == 'return' and st.value is not None: return True
        kids = [b for _, b in getattr(st, 'arms', [])] + [getattr(st, k, None) for k in ('els', 'body', 'handler')]
        if any(isinstance(b, list) and returns_value(b) for b in kids): return True
    return False


def dotted(e):
    """Name or a.b.c chain as a list of names, else None."""
    if e.kind == 'name': return [e.name]
    if e.kind == 'member':
        p = dotted(e.obj)
        return p + [e.name] if p else None
    return None


class Gen:
    def __init__(g, main, registry, search):
        g.main, g.reg, g.search = main, registry, search
        g.classes = {}
        for m in list(registry.values()): g.register(m)
        g.fwd, g.lists, g.structs, g.protos, g.funcs = [], [], [], [], []
        g.done, g.queue, g.inferring = set(), [], set()
        g.class_used, g.list_types, g.specs = set(), {}, {}
        g.pending, g.pending_vars = {}, {}          # empty lists whose element type the first Add decides
        g.used = {}
        g.tmp = 0

    def register(g, mod):
        for c in mod.prog.classes.values():
            c.mod = mod
            c.qname = c.name if mod.is_main else f'{mod.name}.{c.name}'
            c.cname = c.qname.replace('.', '_')
            g.classes[c.qname] = c

    def mark(g, mod, name):
        if not mod.is_main: g.used.setdefault(mod.name, set()).add(name)

    def err(g, node, msg):
        where = f'{node.file}:{node.line}' if getattr(node, 'file', None) else f'line {node.line}'
        raise HasteError(f'{where}: {msg}')

    def fresh(g):
        g.tmp += 1
        return f'_t{g.tmp}'

    # ── finding things by name: locals, aliases, this module, any module on disk ──
    def module(g, name):
        before = set(g.reg)
        m = find_module(name, g.reg, g.search)
        for new in set(g.reg) - before: g.register(g.reg[new])
        return m

    def resolve(g, parts, env, node):
        aliases, seen = env.mod.prog.aliases, []
        while parts[0] in aliases and parts[0] not in seen:      # an alias may name another alias
            seen.append(parts[0])
            parts = aliases[parts[0]][0] + parts[1:]
        if len(parts) == 1 and parts[0] in seen:
            g.err(node, 'alias ' + ' -> '.join(seen + [parts[0]]) + ' goes round in a circle')
        if len(parts) == 1:
            n, m = parts[0], env.mod
            if n in m.prog.classes: return ('class', m.prog.classes[n])
            if n in m.prog.funcs: return ('fn', m, m.prog.funcs[n])
            mod = m.imports.get(n) or g.module(n)
            return ('module', mod) if mod else None
        head = '.'.join(parts[:-1])
        mod = env.mod.imports.get(head) or g.module(head)
        if mod:
            last = parts[-1]
            if last in mod.prog.classes: return ('class', mod.prog.classes[last])
            if last in mod.prog.funcs: return ('fn', mod, mod.prog.funcs[last])
        sub = g.module('.'.join(parts))
        if sub: return ('module', sub)
        if mod: g.err(node, f'module {mod.name} has no {parts[-1]}')
        return None

    def is_path(g, parts, env):
        """True when a.b.c should be looked up as a name path, not as a value."""
        return parts and not env.lookup(parts[0]) and not (env.cls and parts[0] in env.cls.props)

    def tname(g, t, env, node):
        """Resolve a written type (int, [Account], System.Bitmap, an alias) to its full name."""
        if t in PRIM: return t
        if t.startswith('['): return '[' + g.tname(t[1:-1], env, node) + ']'
        if t.startswith('{'):
            k, v = kv(t)
            return '{' + g.tname(k, env, node) + ':' + g.tname(v, env, node) + '}'
        r = g.resolve(t.split('.'), env, node)
        if not r or r[0] != 'class': g.err(node, f'unknown type {t}')
        return r[1].qname

    # ── types ──
    def ctype(g, t):
        if t in PRIM: return PRIM[t]
        if t[1:2] == '?': return f'@@P{t[2:-1]}@@*'       # filled in once the first Add or d[k] = v is seen
        if t.startswith('['): return g.list_type(t[1:-1]) + '*'
        if t.startswith('{'): return g.dict_type(*kv(t)) + '*'
        g.use_class(t)
        return f'C_{g.classes[t].cname}*'

    def list_type(g, elem):
        if elem in g.list_types: return g.list_types[elem]
        et = g.ctype(elem)
        name = 'L_' + mangle(elem)
        g.list_types[elem] = name
        va = 'int' if elem == 'bool' else et
        at = int(elem in ('int', 'float', 'bool'))           # numbers hold no pointers: the collector skips them
        g.lists.append(f'''typedef struct {{ {et} *items; long long count, cap; }} {name};
static {name} *{name}_new(void) {{ return hs_alloc(sizeof({name})); }}
static void {name}_add({name} *l, {et} v) {{
    if (l->count == l->cap) {{ l->cap = l->cap ? l->cap * 2 : 8; l->items = hs_grow(l->items, sizeof({et}) * (size_t)l->count, sizeof({et}) * (size_t)l->cap, {at}); }}
    l->items[l->count++] = v;
}}
static void {name}_check({name} *l, long long i) {{
    if (i < 0 || i >= l->count) hs_raise(hs_fmt("index %lld is outside 0..%lld", i, l->count - 1));
}}
static {et} {name}_get({name} *l, long long i) {{ {name}_check(l, i); return l->items[i]; }}
static void {name}_set({name} *l, long long i, {et} v) {{ {name}_check(l, i); l->items[i] = v; }}
static {name} *{name}_of(int n, ...) {{
    {name} *l = {name}_new(); va_list ap; va_start(ap, n);
    for (int k = 0; k < n; k++) {name}_add(l, ({et})va_arg(ap, {va}));
    va_end(ap); return l;
}}''')
        return name

    def dict_type(g, k, v):
        key = '{' + k + ':' + v + '}'
        if key in g.list_types: return g.list_types[key]
        if k not in ('int', 'string', 'bool'):
            raise HasteError(f'dictionary keys must be whole numbers, text or true/false, not {k}')
        kt, vt = g.ctype(k), g.ctype(v)
        name = 'D_' + mangle(key)[1:]
        g.list_types[key] = name
        kva, vva = ('int' if k == 'bool' else kt), ('int' if v == 'bool' else vt)
        ka, va = int(k != 'string'), int(v in ('int', 'float', 'bool'))
        if k == 'string':
            hash_ = 'unsigned long long x = 1469598103934665603ULL; while (*k) { x ^= (unsigned char)*k++; x *= 1099511628211ULL; } return x;'
            eq, show = 'strcmp(a, b) == 0', 'hs_fmt("\\"%s\\"", k)'
        else:
            hash_ = 'unsigned long long x = (unsigned long long)k; x ^= x >> 33; x *= 0xff51afd7ed558ccdULL; x ^= x >> 33; return x;'
            eq, show = 'a == b', 'hs_fmt("%lld", (long long)k)'
        g.lists.append(f'''typedef struct {{ {kt} *keys; {vt} *vals; long long count, cap, *slots, nslots; }} {name};
static {name} *{name}_new(void) {{ return hs_alloc(sizeof({name})); }}
static unsigned long long {name}_hash({kt} k) {{ {hash_} }}
static bool {name}_eq({kt} a, {kt} b) {{ return {eq}; }}
static long long {name}_find({name} *d, {kt} k) {{
    if (!d->nslots) return -1;
    unsigned long long m = (unsigned long long)d->nslots - 1, h = {name}_hash(k) & m;
    while (d->slots[h]) {{ long long i = d->slots[h] - 1; if ({name}_eq(d->keys[i], k)) return i; h = (h + 1) & m; }}
    return -1;
}}
static void {name}_slot({name} *d, long long i) {{
    unsigned long long m = (unsigned long long)d->nslots - 1, h = {name}_hash(d->keys[i]) & m;
    while (d->slots[h]) h = (h + 1) & m;
    d->slots[h] = i + 1;
}}
static void {name}_index({name} *d) {{
    long long n = 16;
    while (n < 2 * d->count + 2) n *= 2;
    d->nslots = n; d->slots = hs_alloc_atomic(sizeof(long long) * (size_t)n);
    for (long long i = 0; i < d->count; i++) {name}_slot(d, i);
}}
static void {name}_set({name} *d, {kt} k, {vt} v) {{
    long long i = {name}_find(d, k);
    if (i >= 0) {{ d->vals[i] = v; return; }}
    if (d->count == d->cap) {{
        d->cap = d->cap ? d->cap * 2 : 8;
        d->keys = hs_grow(d->keys, sizeof({kt}) * (size_t)d->count, sizeof({kt}) * (size_t)d->cap, {ka});
        d->vals = hs_grow(d->vals, sizeof({vt}) * (size_t)d->count, sizeof({vt}) * (size_t)d->cap, {va});
    }}
    d->keys[d->count] = k; d->vals[d->count] = v; d->count++;
    if (2 * d->count + 2 > d->nslots) {name}_index(d); else {name}_slot(d, d->count - 1);
}}
static {vt} {name}_get({name} *d, {kt} k) {{
    long long i = {name}_find(d, k);
    if (i < 0) hs_raise(hs_fmt("key %s is not in the dictionary", {show}));
    return d->vals[i];
}}
static bool {name}_has({name} *d, {kt} k) {{ return {name}_find(d, k) >= 0; }}
static {vt} {name}_get_or({name} *d, {kt} k, {vt} fallback) {{
    long long i = {name}_find(d, k);
    return i < 0 ? fallback : d->vals[i];
}}
static void {name}_remove({name} *d, {kt} k) {{
    long long i = {name}_find(d, k);
    if (i < 0) return;
    memmove(d->keys + i, d->keys + i + 1, sizeof({kt}) * (size_t)(d->count - i - 1));
    memmove(d->vals + i, d->vals + i + 1, sizeof({vt}) * (size_t)(d->count - i - 1));
    d->count--;
    {name}_index(d);
}}
static {name} *{name}_of(int n, ...) {{
    {name} *d = {name}_new(); va_list ap; va_start(ap, n);
    for (int j = 0; j < n; j++) {{ {kt} k = ({kt})va_arg(ap, {kva}); {vt} v = ({vt})va_arg(ap, {vva}); {name}_set(d, k, v); }}
    va_end(ap); return d;
}}''')
        return name

    def use_class(g, qname):
        if qname in g.class_used: return
        g.class_used.add(qname)
        cls = g.classes[qname]
        g.mark(cls.mod, cls.name)
        g.fwd.append(f'typedef struct C_{cls.cname} C_{cls.cname};')
        fields = [f'    {g.ctype(g.prop_type(cls, p))} p_{p.name};'
                  for p in cls.props.values() if not p.computed]
        g.structs.append(f'struct C_{cls.cname} {{\n' + '\n'.join(fields or ['    char _unused;']) + '\n};')

    def prop_type(g, cls, p):
        if getattr(p, 'rtype', None): return p.rtype
        if p.type:
            p.rtype = g.tname(p.type, Env(cls.mod), p)
        else:
            key = ('prop', cls.qname, p.name)
            if key in g.inferring: g.err(p, f'{cls.name}.{p.name} refers to itself; give it a type')
            g.inferring.add(key)
            env = Env(cls.mod, cls if p.computed else None)
            env.vars['self'] = (cls.qname, False, 'self')
            p.rtype = g.expr(p.computed or p.default, env)[1]
            g.inferring.discard(key)
        if p.rtype == 'void': g.err(p, f'{cls.name}.{p.name} has no value')
        return p.rtype

    # ── created empty: x = [] or x = {}. The type comes from the first Add or x[key] = value ──
    def new_pending(g, kind):
        n = len(g.pending)
        g.pending[n] = None
        return f'@@P{n}@@_new()', f'{kind}?{n}{"]" if kind == "[" else "}"}'

    def track(g, env, name, t, node):
        if t[1:2] == '?': g.pending_vars.setdefault(int(t[2:-1]), []).append((env, name, node))

    def settle(g, t, full):
        n = int(t[2:-1])
        g.pending[n] = full
        for env, name, _ in g.pending_vars.get(n, []):
            if env.vars.get(name, ('',))[0] == t:
                _, mutable, cname = env.vars[name]
                env.vars[name] = (full, mutable, cname)

    def example(g, t, name):
        return f'{name}: [int] = []' if t.startswith('[') else f'{name}: {{string: int}} = {{}}'

    def known(g, t, node):
        m = re.search(r'([\[{])\?(\d+)', t)
        if m:
            names = [nm for _, nm, _ in g.pending_vars.get(int(m.group(2)), [])]
            what = names[0] if names else 'this ' + ('list' if m.group(1) == '[' else 'dictionary')
            tip = f', or read it with {what}.Get(key, default)' if m.group(1) == '{' else ''
            g.err(node, f'{what} is used before anything is added to it, so Haste cannot tell what it holds; '
                        f'add something first{tip}, or give it a type, e.g. {g.example(m.group(1), what)}')
        return t

    def coerce(g, code, frm, to, node):
        if frm == to: return code
        if frm[1:2] == '?' and to[:1] == frm[:1] and '?' not in to:
            g.settle(frm, to); return code
        if frm == 'int' and to == 'float': return f'(double)({code})'
        g.err(node, f'expected {to}, got {frm}')

    # ── getters, setters and constructors are generated only when reached ──
    def request(g, key):
        if key not in g.done:
            g.done.add(key)
            g.queue.append(key)

    def drain(g):
        while g.queue:
            key = g.queue.pop(0)
            getattr(g, 'emit_' + key[0])(*key[1:])

    def emit_getter(g, qname, pname):
        cls = g.classes[qname]; p = cls.props[pname]
        env = Env(cls.mod, cls); env.vars['self'] = (qname, False, 'self')
        t = g.prop_type(cls, p)
        c, ct = g.expr(p.computed, env, t)
        sig = f'static {g.ctype(t)} {cls.cname}_g_{pname}(C_{cls.cname} *self)'
        g.protos.append(sig + ';')
        g.funcs.append(f'{sig} {{\n    return {g.coerce(c, ct, t, p)};\n}}')

    def emit_setter(g, qname, pname):
        cls = g.classes[qname]; p = cls.props[pname]
        t = g.prop_type(cls, p)
        sig = f'static C_{cls.cname} *{cls.cname}_s_{pname}(C_{cls.cname} *self, {g.ctype(t)} it)'
        g.protos.append(sig + ';')
        body = []
        env = Env(cls.mod, cls); env.vars['self'] = (qname, False, 'self')
        env.vars['it'] = (t, False, 'it')
        if p.where:
            c, ct = g.expr(p.where, env)
            if ct != 'bool': g.err(p, 'a where clause must be true or false')
            show = {'string': 'hs_fmt("\\"%s\\"", it)', 'int': 'hs_fmt("%lld", it)',
                    'float': 'hs_fmt("%g", it)', 'bool': '(it ? "true" : "false")'}.get(t, '"(object)"')
            body.append(f'    if (!({c})) hs_require_fail("{qname}.{pname}", {show}, {cstr(p.wtext)});')
        if p.write:                              # it = incoming value, field = the stored value
            wenv = env.child()
            wenv.writing = (qname, pname)
            if not p.computed: wenv.vars['field'] = (t, True, f'self->p_{pname}')
            body += g.block(p.write, wenv, 1)
        else:
            body.append(f'    self->p_{pname} = it;')
        body.append('    return self;')
        g.funcs.append(sig + ' {\n' + '\n'.join(body) + '\n}')

    def emit_new(g, qname):
        cls = g.classes[qname]
        sig = f'static C_{cls.cname} *{cls.cname}_new(void)'
        g.protos.append(sig + ';')
        plain = all(g.prop_type(cls, p) in ('int', 'float', 'bool') for p in cls.props.values() if not p.computed)
        alloc = 'hs_alloc_atomic' if plain else 'hs_alloc'   # only numbers inside: nothing for the collector to follow
        body = [f'    C_{cls.cname} *self = {alloc}(sizeof(C_{cls.cname}));']
        for p in cls.props.values():
            if p.computed: continue
            t = g.prop_type(cls, p)
            if p.default:
                c, ct = g.expr(p.default, Env(cls.mod), t)
                c = g.coerce(c, ct, t, p)
            elif t.startswith('['):
                c = f'{g.list_type(t[1:-1])}_new()'
            elif t.startswith('{'):
                c = f'{g.dict_type(*kv(t))}_new()'
            elif t in g.classes:
                g.err(p, f'{cls.name}.{p.name} needs a default object (Haste has no nil)')
            else:
                c = {'string': '""', 'bool': 'false'}.get(t, '0')
            body.append(f'    self->p_{p.name} = {c};')
        body.append('    return self;')
        g.funcs.append(sig + ' {\n' + '\n'.join(body) + '\n}')

    # ── functions: one C version per combination of argument types ──
    def call_fn(g, mod, f, args, node, env, cls=None, obj=None):
        if any(nm for nm, _ in args): g.err(node, f'{f.name} takes positional arguments')
        if len(args) != len(f.params):
            g.err(node, f'{f.name} expects {len(f.params)} argument(s), got {len(args)}')
        codes, types = ([obj] if cls else []), []
        for (_, a), (pn, pt) in zip(args, f.params):
            pt = pt and g.tname(pt, Env(mod), f)
            c, t = g.expr(a, env, pt)
            if t == 'void': g.err(a, 'that expression has no value')
            if pt: c, t = g.coerce(c, t, pt, a), pt
            codes.append(c); types.append(g.known(t, a))
        if f.cname:                                  # extern: call the C function directly
            ret = g.tname(f.ret, Env(mod), f)
            # lists and dictionaries cross into C as plain pointers; the runtime uses the same layout
            codes = [f'(void*)({c})' if t[:1] in '[{' else c for c, t in zip(codes, types)]
            call = f'{f.cname}({", ".join(codes)})'
            return (f'(({g.ctype(ret)}){call})' if ret[:1] in '[{' else call), ret
        cname, ret = g.specialize(mod, f, cls, tuple(types), node)
        return f'{cname}({", ".join(codes)})', ret

    def specialize(g, mod, f, cls, types, node):
        key = (mod.name, cls and cls.qname, f.name, types)
        s = g.specs.get(key)
        if s:
            if s.ret: return s.cname, s.ret
            if s.hint: return s.cname, s.hint
            g.err(node, f'{f.name} calls itself before its result type is known; '
                        f'write its type, e.g. fn {f.name}(...): int')
        base = f'{cls.cname}_m_{f.name}' if cls else f'{mod.cprefix}_{f.name}'
        generic = any(pt is None for _, pt in f.params)
        cname = base + ('__' + '_'.join(mangle(t) for t in types) if generic else '')
        s = N('spec', cname=cname, ret=None, hint=None, rets=[], f=f, top=f.expr, generic=generic,
              label=f'{cls.name + "." if cls else ""}{f.name}({", ".join(types)})')
        if f.ret: s.ret = g.tname(f.ret, Env(mod), f)
        elif f.body is not None and not returns_value(f.body): s.ret = 'void'
        g.specs[key] = s
        env = Env(mod, cls); env.spec = s
        if cls: env.vars['self'] = (cls.qname, False, 'self')
        for (pn, _), t in zip(f.params, types):
            env.vars[pn] = (t, False, 'v_' + pn)
        try:
            if f.expr:
                c, t = g.expr(f.expr, env, s.ret)
                ret = s.ret or t
                body = [f'    {c};'] if ret == 'void' else [f'    return {g.coerce(c, t, ret, f.expr)};']
            else:
                body = g.block(f.body, env, 1)
                ret = s.ret or g.unify(s.rets, f)
        except HasteError as ex:             # a type-free function failed for these argument types: say who called it
            if generic and getattr(node, 'file', None):
                raise HasteError(f'{ex}\n  in {s.label}, called from {node.file}:{node.line}')
            raise
            if ret != 'void':
                body.append(f'    hs_raise("{f.name} ended without returning a value"); return 0;')
        s.ret = ret
        params = ([f'C_{cls.cname} *self'] if cls else []) + \
                 [f'{g.ctype(t)} v_{pn}' for (pn, _), t in zip(f.params, types)]
        sig = f'static {g.ctype(ret)} {cname}({", ".join(params) or "void"})'
        g.protos.append(sig + ';')
        g.funcs.append(sig + ' {\n' + '\n'.join(body) + '\n}')
        return cname, ret

    def unify(g, rets, f):
        if not rets: return 'void'
        if all(r == rets[0] for r in rets): return rets[0]
        if all(is_num(r) for r in rets): return 'float'
        g.err(f, f'{f.name} returns different types: {", ".join(sorted(set(rets)))}')

    # ── statements ──
    def block(g, stmts, env, depth):
        out = []
        for st in stmts:
            out += g.stmt(st, env, depth)
        return out

    def stmt(g, st, env, d):
        pad = '    ' * d
        k = st.kind
        if k == 'let':
            if st.name in env.vars: g.err(st, f'{st.name} is already declared')
            want = st.type and g.tname(st.type, env, st)
            c, t = g.expr(st.value, env, want)
            if want: c, t = g.coerce(c, t, want, st), want
            if t == 'void': g.err(st, 'that expression has no value')
            env.vars[st.name] = (t, st.mutable, 'v_' + st.name)
            g.track(env, st.name, t, st)
            return [f'{pad}{g.ctype(t)} v_{st.name} = {c};']
        if k == 'assign':
            return [pad + g.assign(st, env) + ';']
        if k == 'exprstmt':
            if st.expr.kind != 'call': g.err(st, 'a statement must be a call or an assignment')
            return [pad + g.expr(st.expr, env)[0] + ';']
        if k == 'if':
            out = []
            for n, (cond, body) in enumerate(st.arms):
                out.append(f'{pad}{"} else " if n else ""}if ({g.cond(cond, env)}) {{')
                out += g.block(body, env.child(), d + 1)
            if st.els is not None:
                out.append(f'{pad}}} else {{')
                out += g.block(st.els, env.child(), d + 1)
            return out + [pad + '}']
        if k == 'while':
            return [f'{pad}while ({g.cond(st.cond, env)}) {{'] + g.block(st.body, env.child(), d + 1) + [pad + '}']
        if k == 'for' and st.parallel:
            return g.parallel_for(st, env, pad)
        if k == 'for':
            inner = env.child()
            if st.b is not None:
                a, at = g.expr(st.a, env); b, bt = g.expr(st.b, env)
                if at != 'int' or bt != 'int': g.err(st, 'a range needs whole numbers')
                end = g.fresh()
                inner.vars[st.var] = ('int', False, 'v_' + st.var)
                head = f'{pad}for (long long v_{st.var} = {a}, {end} = {b}; v_{st.var} <= {end}; v_{st.var}++) {{'
                return [head] + g.block(st.body, inner, d + 1) + [pad + '}']
            c, t = g.expr(st.a, env)
            if not t[:1] in '[{': g.err(st, f'cannot loop over {t}')
            g.known(t, st)
            if t.startswith('{'):                        # a dictionary: its keys, in the order they were added
                k, _ = kv(t); dt = g.dict_type(*kv(t)); dv, i = g.fresh(), g.fresh()
                inner.vars[st.var] = (k, False, 'v_' + st.var)
                return [f'{pad}{{', f'{pad}    {dt} *{dv} = {c};',
                        f'{pad}    for (long long {i} = 0; {i} < {dv}->count; {i}++) {{',
                        f'{pad}        {g.ctype(k)} v_{st.var} = {dv}->keys[{i}];'] + \
                    g.block(st.body, inner, d + 2) + [f'{pad}    }}', f'{pad}}}']
            et = t[1:-1]; lt = g.list_type(et); l, i = g.fresh(), g.fresh()
            inner.vars[st.var] = (et, False, 'v_' + st.var)
            return [f'{pad}{{', f'{pad}    {lt} *{l} = {c};',
                    f'{pad}    for (long long {i} = 0; {i} < {l}->count; {i}++) {{',
                    f'{pad}        {g.ctype(et)} v_{st.var} = {l}->items[{i}];'] + \
                g.block(st.body, inner, d + 2) + [f'{pad}    }}', f'{pad}}}']
        if k == 'return':
            s = env.spec
            if not s: g.err(st, 'return is only allowed inside a function')
            if env.in_try: g.err(st, 'return inside try is not supported yet')
            declared = s.f.ret is not None
            if st.value is None:
                if declared and s.ret != 'void': g.err(st, f'must return a {s.ret}')
                s.rets.append('void')
                return [pad + 'return;']
            c, t = g.expr(st.value, env, s.ret if declared else None)
            if declared:
                c = g.coerce(c, t, s.ret, st)
            else:
                s.rets.append(t); s.hint = s.hint or t
            return [f'{pad}return {c};']
        if k == 'try':
            jb = g.fresh()
            handler = env.child()
            handler.vars[st.var] = ('string', False, 'v_' + st.var)
            return [f'{pad}{{', f'{pad}    jmp_buf {jb}; hs_try_push(&{jb});',
                    f'{pad}    if (setjmp({jb}) == 0) {{'] + \
                g.block(st.body, env.child(in_try=env.in_try + 1), d + 2) + \
                [f'{pad}        hs_try_pop();', f'{pad}    }} else {{',
                 f'{pad}        hs_str v_{st.var} = hs_error;'] + \
                g.block(st.handler, handler, d + 2) + [f'{pad}    }}', f'{pad}}}']
        g.err(st, f'unknown statement {k}')

    def parallel_for(g, st, env, pad):
        """The loop body becomes its own C function; every variable in scope is
        copied into a context struct and is read-only inside the body."""
        pid = g.fresh()
        seen, e = {}, env
        while e:
            for name, v in e.vars.items(): seen.setdefault(name, v)
            e = e.parent
        fields = {v[2]: v[0] for v in seen.values()}
        body_env = Env(env.mod, env.cls)
        for name, (t, _, cn) in seen.items(): body_env.vars[name] = (t, None, cn)
        inner = body_env.child()
        if st.b is not None:
            a, at = g.expr(st.a, env); b, bt = g.expr(st.b, env)
            if at != 'int' or bt != 'int': g.err(st, 'a range needs whole numbers')
            src, count, item = ('long long', a), f'({b}) - _c.src + 1', 'ctx->src + i'
            inner.vars[st.var] = ('int', False, 'v_' + st.var)
            et = 'int'
        else:
            c, t = g.expr(st.a, env)
            if not t.startswith('['): g.err(st, f'cannot loop over {t}')
            g.known(t, st)
            et = t[1:-1]
            src, count, item = (g.list_type(et) + ' *', c), '_c.src->count', 'ctx->src->items[i]'
            inner.vars[st.var] = (et, False, 'v_' + st.var)
        body = g.block(st.body, inner, 1)
        decl = [f'    {g.ctype(t)} {cn};' for cn, t in fields.items()]
        g.structs.append(f'typedef struct {{\n    {src[0]} src;\n' + '\n'.join(decl) + f'\n}} {pid}_ctx;')
        sig = f'static void {pid}_body(void *c, long long i)'
        g.protos.append(sig + ';')
        copy = [f'    {g.ctype(t)} {cn} = ctx->{cn};' for cn, t in fields.items()]
        g.funcs.append(sig + ' {\n' + '\n'.join([f'    {pid}_ctx *ctx = c;'] + copy +
                       [f'    {g.ctype(et)} v_{st.var} = {item};'] + body) + '\n}')
        init = ', '.join([f'.src = {src[1]}'] + [f'.{cn} = {cn}' for cn in fields])
        return [f'{pad}{{', f'{pad}    {pid}_ctx _c = {{ {init} }};',
                f'{pad}    hs_parallel({count}, {pid}_body, &_c);', f'{pad}}}']

    def cond(g, e, env):
        c, t = g.expr(e, env)
        if t != 'bool': g.err(e, f'a condition must be true or false, got {t}')
        return c

    def assign(g, st, env):
        tg = st.target
        if tg.kind == 'name':
            v = env.lookup(tg.name)
            if v:
                t, mutable, cname = v
                if mutable is None:
                    g.err(st, f'{tg.name} cannot be changed inside parallel for: '
                              'iterations run at the same time, so each must only change its own data')
                if not mutable: g.err(st, f'{tg.name} is declared with let; use var to change it')
                c, ct = g.expr(st.value, env, t)
                return f'{cname} = {g.coerce(c, ct, t, st)}'
            if env.cls and tg.name in env.cls.props:
                return g.set_prop('self', env.cls, tg.name, st.value, env)
            if tg.name == 'field' and env.writing:
                g.err(st, f'{env.writing[1]} is computed, so it has no field to store into; '
                          'set the properties it is computed from instead')
            c, t = g.expr(st.value, env)             # first assignment declares the variable
            if t == 'void': g.err(st, 'that expression has no value')
            env.vars[tg.name] = (t, True, 'v_' + tg.name)
            g.track(env, tg.name, t, st)
            return f'{g.ctype(t)} v_{tg.name} = {c}'
        if tg.kind == 'member':
            oc, ot = g.expr(tg.obj, env)
            if ot in g.classes and tg.name in g.classes[ot].props:
                return g.set_prop(oc, g.classes[ot], tg.name, st.value, env)
            g.err(st, f'{ot} has no property {tg.name}')
        if tg.kind == 'index' and g.expr(tg.obj, env)[1][:1] == '{':     # d[key] = value
            oc, ot = g.expr(tg.obj, env)
            if ot[1:2] == '?':                          # the first d[key] = value decides the type
                kc, kt = g.expr(tg.idx, env); vc, vt = g.expr(st.value, env)
                if 'void' in (kt, vt): g.err(st, 'that expression has no value')
                oc, now = g.expr(tg.obj, env)            # the value may have settled it, e.g. d.Get(k, 0) + 1
                if now[1:2] != '?':
                    k, v = kv(now)
                    return f'{g.dict_type(k, v)}_set({oc}, {g.coerce(kc, kt, k, st)}, {g.coerce(vc, vt, v, st)})'
                g.settle(ot, '{' + g.known(kt, st) + ':' + g.known(vt, st) + '}')
                return f'{g.dict_type(kt, vt)}_set({oc}, {kc}, {vc})'
            k, v = kv(ot)
            kc, kt = g.expr(tg.idx, env, k); vc, vt = g.expr(st.value, env, v)
            return f'{g.dict_type(k, v)}_set({oc}, {g.coerce(kc, kt, k, st)}, {g.coerce(vc, vt, v, st)})'
        if tg.kind == 'index':
            oc, ot = g.expr(tg.obj, env)
            if not ot.startswith('['): g.err(st, f'cannot index {ot}')
            g.known(ot, st)
            ic, it = g.expr(tg.idx, env)
            if it != 'int': g.err(st, 'an index must be a whole number')
            c, ct = g.expr(st.value, env, ot[1:-1])
            return f'{g.list_type(ot[1:-1])}_set({oc}, {ic}, {g.coerce(c, ct, ot[1:-1], st)})'
        g.err(st, 'cannot assign to that')

    def set_prop(g, objc, cls, pname, value, env):
        p = cls.props[pname]
        if p.computed and not p.write: g.err(value, f'{cls.name}.{pname} is computed and read-only')
        if env.writing == (cls.qname, pname):
            g.err(value, f'inside its own write block, assign to field instead of {pname}, or it would call itself forever'
                  if not p.computed else f'{pname} is computed: set the properties it is computed from instead')
        t = g.prop_type(cls, p)
        c, ct = g.expr(value, env, t)
        g.request(('setter', cls.qname, pname))
        return f'{cls.cname}_s_{pname}({objc}, {g.coerce(c, ct, t, value)})'

    def get_prop(g, objc, cls, p):
        t = g.prop_type(cls, p)
        if p.computed:
            g.request(('getter', cls.qname, p.name))
            return f'{cls.cname}_g_{p.name}({objc})', t
        return f'{objc}->p_{p.name}', t

    # ── expressions: return (C code, Haste type) ──
    def expr(g, e, env, want=None):
        k = e.kind
        if k == 'int': return f'{e.v}LL', 'int'
        if k == 'float': return e.v, 'float'
        if k == 'bool': return ('true' if e.v else 'false'), 'bool'
        if k == 'str': return cstr(e.v), 'string'
        if k == 'interp':
            fmt, args = '', []
            for part in e.parts:
                if isinstance(part, str):
                    fmt += part.replace('%', '%%'); continue
                x, spec = part
                c, t = g.expr(x, env)
                if t == 'string': fmt += '%s'; args.append(c)
                elif t == 'bool': fmt += '%s'; args.append(f'({c} ? "true" : "false")')
                elif is_num(t) and spec is not None: fmt += f'%.{spec}f'; args.append(f'(double)({c})')
                elif t == 'int': fmt += '%lld'; args.append(c)
                elif t == 'float': fmt += '%g'; args.append(c)
                else: g.err(x, f'cannot put a {t} in a string')
            return f'hs_fmt({", ".join([cstr(fmt)] + args)})', 'string'
        if k == 'name':
            v = env.lookup(e.name)
            if v: return v[2], v[0]
            if env.cls and e.name in env.cls.props:
                return g.get_prop('self', env.cls, env.cls.props[e.name])
            g.not_a_value([e.name], env, e)
        if k == 'list':
            if not e.items:
                if not (want and want.startswith('[')): return g.new_pending('[')
                return f'{g.list_type(want[1:-1])}_new()', want
            elem_want = want[1:-1] if want and want.startswith('[') else None
            items = [g.expr(x, env, elem_want) for x in e.items]
            et = elem_want or ('float' if any(t == 'float' for _, t in items) and all(is_num(t) for _, t in items)
                               else items[0][1])
            codes = [g.coerce(c, t, et, x) for (c, t), x in zip(items, e.items)]
            return f'{g.list_type(et)}_of({len(codes)}, {", ".join(codes)})', f'[{et}]'
        if k == 'dict':
            if not e.pairs:
                if not (want and want.startswith('{')): return g.new_pending('{')
                return f'{g.dict_type(*kv(want))}_new()', want
            kw_, vw_ = kv(want) if want and want.startswith('{') else (None, None)
            keys = [g.expr(a, env, kw_) for a, _ in e.pairs]
            vals = [g.expr(b, env, vw_) for _, b in e.pairs]
            kt = kw_ or keys[0][1]
            vt = vw_ or ('float' if any(t == 'float' for _, t in vals) and all(is_num(t) for _, t in vals)
                         else vals[0][1])
            codes = []
            for (kc, kt2), (vc, vt2), (a, b) in zip(keys, vals, e.pairs):
                codes += [g.coerce(kc, kt2, kt, a), g.coerce(vc, vt2, vt, b)]
            return f'{g.dict_type(kt, vt)}_of({len(e.pairs)}, {", ".join(codes)})', '{' + kt + ':' + vt + '}'
        if k == 'ifx':
            c = g.cond(e.cond, env)
            a, at = g.expr(e.a, env, want)
            s = env.spec                         # lets  fn Fib(n) = if .. then n else Fib(..)  recurse
            if s and s.top is e and not s.ret and not s.hint: s.hint = at
            b, bt = g.expr(e.b, env, want)
            t = 'float' if is_num(at) and is_num(bt) and 'float' in (at, bt) else at
            return f'(({c}) ? ({g.coerce(a, at, t, e.a)}) : ({g.coerce(b, bt, t, e.b)}))', t
        if k == 'un':
            c, t = g.expr(e.e, env)
            if e.op == 'not':
                if t == 'int': return f'(~{c})', 'int'
                if t != 'bool': g.err(e, 'not needs true or false, or a whole number')
                return f'(!{c})', 'bool'
            if not is_num(t): g.err(e, f'cannot negate {t}')
            return f'(-{c})', t
        if k == 'bin': return g.binop(e, env)
        if k == 'member':
            parts = dotted(e)
            if g.is_path(parts, env): g.not_a_value(parts, env, e)
            oc, ot = g.expr(e.obj, env)
            if ot[:1] in '[{' and e.name == 'Count': return f'({oc})->count', 'int'
            if ot == 'string' and e.name == 'Length': return f'(long long)hs_len({oc})', 'int'
            if ot in g.classes:
                cls = g.classes[ot]
                if e.name in cls.props: return g.get_prop(oc, cls, cls.props[e.name])
                if e.name in cls.methods: g.err(e, f'{e.name} is a method; call it with ()')
            g.err(e, f'{ot} has no property {e.name}')
        if k == 'index':
            oc, ot = g.expr(e.obj, env)
            if ot.startswith('{'):
                g.known(ot, e); kt_, vt_ = kv(ot)
                kc, kt = g.expr(e.idx, env, kt_)
                return f'{g.dict_type(kt_, vt_)}_get({oc}, {g.coerce(kc, kt, kt_, e)})', vt_
            if not ot.startswith('['): g.err(e, f'cannot index {ot}')
            g.known(ot, e)
            ic, it = g.expr(e.idx, env)
            if it != 'int': g.err(e, 'an index must be a whole number')
            return f'{g.list_type(ot[1:-1])}_get({oc}, {ic})', ot[1:-1]
        if k == 'call': return g.call(e, env)
        g.err(e, f'unknown expression {k}')

    def not_a_value(g, parts, env, e):
        name = '.'.join(parts)
        r = g.resolve(parts, env, e)
        if not r: g.err(e, f'unknown name {name}')
        what = {'module': 'a module', 'class': 'a class; create one with ' + name + '(...)',
                'fn': 'a function; call it with ()'}[r[0]]
        g.err(e, f'{name} is {what}')

    def binop(g, e, env):
        (l, lt), (r, rt) = g.expr(e.l, env), g.expr(e.r, env)
        op = e.op
        if op in BITS:                       # Pascal style: on whole numbers they work on bits
            if lt == rt == 'int': return f'({l} {BITS[op]} {r})', 'int'
            if lt == rt == 'bool' and op in LOGIC: return f'({l} {LOGIC[op]} {r})', 'bool'
            g.err(e, f'{op} needs two whole numbers' + (' or two true/false values' if op in LOGIC else '')
                  + f', got {lt} and {rt}')
        if op in CMP:
            if lt == rt == 'string':
                return f'(strcmp({l}, {r}) {CMP[op]} 0)', 'bool'
            if (is_num(lt) and is_num(rt)) or (lt == rt and op in ('=', '<>')):
                return f'({l} {CMP[op]} {r})', 'bool'
            g.err(e, f'cannot compare {lt} with {rt}')
        if op == '+' and lt == rt == 'string': return f'hs_cat({l}, {r})', 'string'
        if not (is_num(lt) and is_num(rt)): g.err(e, f"'{op}' needs numbers, got {lt} and {rt}")
        if op == '/': return f'((double)({l}) / (double)({r}))', 'float'
        if op in ('div', 'mod'):
            if lt == rt == 'int': return f'hs_i{op}({l}, {r})', 'int'
            if op == 'mod': return f'fmod({l}, {r})', 'float'
            g.err(e, 'div needs whole numbers')
        return f'({l} {op} {r})', 'float' if 'float' in (lt, rt) else 'int'

    def builtin(g, n, e, env):
        if len(e.args) != 1: g.err(e, f'{n} takes one value')
        c, t = g.expr(e.args[0][1], env)
        text = {'string': c, 'int': f'hs_fmt("%lld", {c})', 'float': f'hs_fmt("%g", {c})',
                'bool': f'({c} ? "true" : "false")'}
        if n == 'Int' and is_num(t): return f'((long long)({c}))', 'int'
        if n == 'Float' and is_num(t): return f'((double)({c}))', 'float'
        if n in ('Str', 'print') and t in text:
            return (f'hs_print({text[t]})', 'void') if n == 'print' else (text[t], 'string')
        g.err(e, f'{n} cannot take a {t}')

    def call(g, e, env):
        f = e.fn
        if f.kind == 'name' and f.name in BUILTINS and not env.lookup(f.name):
            return g.builtin(f.name, e, env)
        if f.kind == 'name' and env.cls and f.name in env.cls.methods and not env.lookup(f.name):
            return g.call_fn(env.mod, env.cls.methods[f.name], e.args, e, env, env.cls, 'self')
        parts = dotted(f)
        if g.is_path(parts, env):
            r = g.resolve(parts, env, e)
            if not r: g.err(e, f'unknown function {".".join(parts)}')
            if r[0] == 'class': return g.construct(r[1], e, env)
            if r[0] == 'fn':
                g.mark(r[1], r[2].name)
                return g.call_fn(r[1], r[2], e.args, e, env)
            g.err(e, f'{".".join(parts)} is a module, not a function')
        if f.kind == 'member':
            oc, ot = g.expr(f.obj, env)
            if ot.startswith('[?') and f.name == 'Add':        # the first Add decides the type
                if len(e.args) != 1: g.err(e, 'Add takes one value')
                c, t = g.expr(e.args[0][1], env)
                if t == 'void': g.err(e, 'that expression has no value')
                g.settle(ot, f'[{g.known(t, e)}]')
                return f'{g.list_type(t)}_add({oc}, {c})', 'void'
            if ot.startswith('{') and f.name == 'Get':      # d.Get(key, default): the default decides the type
                if len(e.args) != 2: g.err(e, 'Get takes a key and a default value')
                if ot[1:2] == '?':
                    kc, kt = g.expr(e.args[0][1], env); vc, vt = g.expr(e.args[1][1], env)
                    g.settle(ot, '{' + g.known(kt, e) + ':' + g.known(vt, e) + '}')
                    return f'{g.dict_type(kt, vt)}_get_or({oc}, {kc}, {vc})', vt
                k, v = kv(ot)
                kc, kt = g.expr(e.args[0][1], env, k); vc, vt = g.expr(e.args[1][1], env, v)
                return f'{g.dict_type(k, v)}_get_or({oc}, {g.coerce(kc, kt, k, e)}, {g.coerce(vc, vt, v, e)})', v
            if ot.startswith('{') and f.name in ('Has', 'Remove'):
                if len(e.args) != 1: g.err(e, f'{f.name} takes one key')
                g.known(ot, e); k, v = kv(ot)
                kc, kt = g.expr(e.args[0][1], env, k)
                return f'{g.dict_type(k, v)}_{f.name.lower()}({oc}, {g.coerce(kc, kt, k, e)})', \
                    ('bool' if f.name == 'Has' else 'void')
            if ot.startswith('[') and f.name == 'Add':
                if len(e.args) != 1: g.err(e, 'Add takes one value')
                c, t = g.expr(e.args[0][1], env, ot[1:-1])
                return f'{g.list_type(ot[1:-1])}_add({oc}, {g.coerce(c, t, ot[1:-1], e)})', 'void'
            if ot in g.classes and f.name in g.classes[ot].methods:
                cls = g.classes[ot]
                return g.call_fn(cls.mod, cls.methods[f.name], e.args, e, env, cls, oc)
            g.err(e, f'{ot} has no method {f.name}')
        g.err(e, 'that cannot be called')

    def construct(g, cls, e, env):
        g.use_class(cls.qname)
        g.request(('new', cls.qname))
        code = f'{cls.cname}_new()'
        for nm, a in e.args:
            if not nm: g.err(e, f'{cls.name}(...) takes named properties, e.g. {cls.name}(Name: "x")')
            if nm not in cls.props: g.err(e, f'{cls.name} has no property {nm}')
            code = g.set_prop(code, cls, nm, a, env)
        return code, cls.qname

    # ── command-line switches: variables whose defaults the command line can override ──
    def switches(g, env):
        sws = g.main.prog.switches
        if not sws: return []
        kinds = {'int': 0, 'float': 1, 'string': 2, 'bool': 3}
        decl, table, checks = [], [], []
        for n, sw in enumerate(sws):
            if sw.name in env.vars: g.err(sw, f'switch {sw.name} is declared twice')
            want = sw.type and g.tname(sw.type, env, sw)
            c, t = g.expr(sw.default, env, want)
            if want: c, t = g.coerce(c, t, want, sw), want
            if t not in kinds: g.err(sw, f'a switch must be a whole number, decimal, string or true/false, not {t}')
            cn = 'v_' + sw.name
            decl.append(f'    {g.ctype(t)} {cn} = {c};')
            env.vars[sw.name] = (t, False, cn)
            table.append(f'        {{ {cstr(sw.name)}, {kinds[t]}, &{cn}, {cstr(sw.help)}, {cstr(sw.dtext)}, {cstr(sw.wtext)} }}')
            if sw.where:
                wenv = env.child(); wenv.vars['it'] = (t, False, cn)
                checks.append(f'    if (!({g.cond(sw.where, wenv)})) hs_switch_fail(&_sw[{n}]);')
        return decl + ['    hs_switch _sw[] = {', ',\n'.join(table), '    };',
                       f'    hs_switches(argc, argv, _sw, {len(sws)});'] + checks

    # ── whole program ──
    def program(g):
        env = Env(g.main)
        switches = g.switches(env)
        body = g.block(g.main.prog.stmts, env, 1)
        g.drain()
        inits, seen = [], set()
        while True:                          # init blocks run only for modules that are kept
            kept = [m for m in list(g.reg.values())
                    if not m.is_main and (m.name in g.used or m.needed) and m.name not in seen]
            if not kept: break
            for m in kept:
                seen.add(m.name)
                if m.needed:                 # need: keep every function that has fixed types
                    for fname, f in m.prog.funcs.items():
                        g.mark(m, fname)
                        if not f.cname and all(pt for _, pt in f.params):
                            g.specialize(m, f, None, tuple(g.tname(pt, Env(m), f) for _, pt in f.params), f)
                for blk in m.prog.inits:
                    inits += g.block(blk, Env(m), 1)
            g.drain()
        with open(os.path.join(HERE, 'runtime.h')) as fh:
            runtime = fh.read()
        names = {}
        for n, full in g.pending.items():
            if full is None:
                vs = g.pending_vars.get(n)
                if vs:
                    _, nm, node = vs[0]
                    g.err(node, f'{nm} never has anything added to it, so Haste cannot tell what it holds; '
                                f'give it a type, e.g. {g.example(node_t(vs), nm)}')
                raise HasteError('an empty list or dictionary never has anything added to it')
            names[n] = g.ctype(full)[:-1]
        parts = [runtime] + g.fwd + g.lists + g.structs + g.protos + g.funcs
        # The program runs in its own function, so every frame the collector must scan is below main's.
        main = ('static __attribute__((noinline)) int hs_program(int argc, char **argv) {\n' +
                '\n'.join(switches + inits + body) + '\n    return 0;\n}\n\n' +
                'int main(int argc, char **argv) {\n    volatile char base = 0;\n    hs_stack_base = (char *)&base;\n'
                '    return hs_program(argc, argv);\n}')
        out = '\n\n'.join(p for p in parts if p) + '\n\n' + main + '\n'
        for n, name in names.items():
            out = out.replace(f'@@P{n}@@', name)
        return out

    def report(g):
        lines = []
        for m in g.reg.values():
            if m.is_main: continue
            total = len(m.prog.funcs) + len(m.prog.classes)
            used = sorted(g.used.get(m.name, ()))
            if m.needed:
                lines.append(f'  {m.name:<7} needed, all {total} kept')
            elif used:
                lines.append(f'  {m.name:<7} kept {len(used)} of {total}: {", ".join(used)}')
            else:
                lines.append(f'  {m.name:<7} dropped, nothing used')
        gen = [s for s in g.specs.values() if s.generic]
        if gen:
            lines.append('  specialised: ' + ', '.join(f'{s.label} -> {s.ret}' for s in gen))
        return '\n'.join(lines)


def compile_to_c(path):
    registry = {}
    search = [os.path.dirname(os.path.abspath(path)), os.path.join(HERE, 'lib')]
    main = load(path, registry, search, '__main__', is_main=True)
    g = Gen(main, registry, search)
    return g.program(), g.report()


# ─────────────────────────── build driver ───────────────────────────

TARGETS = {
    'linux':     ('x86_64-linux-musl',  '-linux', ['-static', '-s', '-lm']),
    'windows':   ('x86_64-windows-gnu', '.exe',   ['-s']),
    'macos':     ('aarch64-macos',      '-macos', []),
    'macos-x64': ('x86_64-macos',       '-macos-x64', []),
}


def zig():
    if shutil.which('zig'): return ['zig']
    try:
        import ziglang  # noqa: F401  (pip install ziglang)
        return [sys.executable, '-m', 'ziglang']
    except ImportError:
        raise HasteError('zig not found: install it with  pip install ziglang')


def build(path, targets):
    c_src, report = compile_to_c(path)
    out_dir = os.path.join(os.path.dirname(os.path.abspath(path)), 'build')
    os.makedirs(out_dir, exist_ok=True)
    stem = os.path.splitext(os.path.basename(path))[0]
    c_file = os.path.join(out_dir, stem + '.c')
    with open(c_file, 'w') as fh:
        fh.write(c_src)
    if report: print(report)
    outs = []
    for t in targets:
        if t not in TARGETS: raise HasteError(f'unknown target {t}; choose from {", ".join(TARGETS)}')
        triple, suffix, extra = TARGETS[t]
        out = os.path.join(out_dir, stem + suffix)
        cmd = zig() + ['cc', '-target', triple, '-O2', '-std=gnu11', '-w', c_file, '-o', out] + extra
        r = subprocess.run(cmd, capture_output=True, text=True)
        if r.returncode:
            raise HasteError(f'C compiler failed for {t}:\n{r.stderr}')
        print(f'  built {os.path.relpath(out)}  ({os.path.getsize(out) // 1024} KB)')
        outs.append(out)
    return outs


def host_target():
    return {'win32': 'windows', 'darwin': 'macos'}.get(sys.platform, 'linux')


MEMBERS = ('Add', 'Count', 'Length', 'Has', 'Remove', 'Get')    # members of lists, dictionaries and text


def words(path=None):
    """Print the names an editor should colour, one kind per line ("module Math System Text ..."), so the
    IDE never keeps lists of its own. Modules are found the way the compiler finds them: next to the
    program, then in lib. A folder of .haste files is a module too (System/Drawing.haste is System.Drawing)."""
    dirs = ([os.path.dirname(os.path.abspath(path))] if path else []) + [os.path.join(HERE, 'lib')]
    mods = set()
    for d in dirs:
        for e in (os.listdir(d) if os.path.isdir(d) else []):
            full, stem = os.path.join(d, e), os.path.splitext(e)[0]
            if e.endswith('.haste') and not (path and os.path.abspath(path) == full):
                mods.add(stem)
            elif os.path.isdir(full) and any(f.endswith('.haste') for f in os.listdir(full)):
                mods.add(e)
    print('keyword', *sorted(KEYWORDS))
    print('builtin', *BUILTINS)
    print('member', *MEMBERS)
    print('module', *sorted(m for m in mods if re.fullmatch(r'[A-Za-z_]\w*', m)))
    return 0


def main(argv):
    if argv[:1] == ['words']:
        return words(argv[1] if len(argv) > 1 else None)
    if len(argv) < 2 or argv[0] not in ('build', 'run', 'c'):
        print(__doc__); return 2
    cmd, path = argv[0], argv[1]
    try:
        if cmd == 'c':
            print(compile_to_c(path)[0]); return 0
        targets, extra = [host_target()], argv[2:]
        if cmd == 'build' and '--target' in extra:
            targets = extra[extra.index('--target') + 1].split(',')
        outs = build(path, targets)
        if cmd == 'run':
            print('  ----')
            return subprocess.run([outs[0]] + extra).returncode
        return 0
    except HasteError as ex:
        print(f'error: {ex}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
