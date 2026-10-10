#!/usr/bin/env python3
"""Haste test suite.

    python tests/run.py              run every test
    python tests/run.py dict         run the tests whose path contains "dict"

A test is an ordinary Haste program whose comments say what should happen:

    // out: text      the next line the program must print (in order; "// out:" alone is an empty line)
    // error: text    the build or the run must fail, and its messages must contain this text
    // args: --x 5    switches to run the program with

Lines the program prints must match the "out" lines exactly and completely. Tests build in parallel, one
per core, and the exit code is the number of failures (0 when everything passes).
"""
import os, re, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
HASTE = os.path.join(os.path.dirname(HERE), 'haste.py')
SKIP = {'build'}


def spec(path):
    want, error, args = [], None, []
    for line in open(path, encoding='utf-8-sig'):
        m = re.search(r'//\s*(out|error|args):(.*)$', line)
        if not m: continue
        kind, text = m.group(1), m.group(2)
        text = text[1:] if text.startswith(' ') else text      # one space after the colon is layout
        if kind == 'out': want.append(text.rstrip())
        elif kind == 'error': error = text.strip()
        else: args = text.split()
    return want, error, args


def run(path):
    """Returns (path, failure message or None, seconds)."""
    start = time.time()
    want, error, args = spec(path)
    folder = os.path.dirname(path)
    b = subprocess.run([sys.executable, HASTE, 'build', path], cwd=folder, capture_output=True, text=True)
    if b.returncode != 0:
        msg = (b.stdout + b.stderr).strip()
        if error and error in msg: return path, None, time.time() - start
        return path, ('expected it to build, got:\n' if not error else
                      f'expected an error containing "{error}", got:\n') + indent(msg), time.time() - start
    built = re.search(r'built (\S+)', b.stdout)
    exe = os.path.join(folder, built.group(1))
    try:
        r = subprocess.run([exe] + args, cwd=folder, capture_output=True, text=True, timeout=60)
    except subprocess.TimeoutExpired:
        return path, 'did not finish within 60 seconds', time.time() - start
    got = [l.rstrip() for l in r.stdout.splitlines()]
    problems = []
    if got != want:
        problems.append('output differs:\n' + diff(want, got))
    if error:
        if r.returncode == 0: problems.append(f'expected an error containing "{error}", but it ran to the end')
        elif error not in r.stderr + r.stdout: problems.append(f'expected an error containing "{error}", got:\n'
                                                           + indent(r.stderr.strip()))
    elif r.returncode != 0:
        problems.append(f'exit code {r.returncode}:\n' + indent(r.stderr.strip()))
    return path, '\n'.join(problems) or None, time.time() - start


def indent(text):
    return '\n'.join('      ' + l for l in text.splitlines())


def diff(want, got):
    out = []
    for i in range(max(len(want), len(got))):
        w = want[i] if i < len(want) else '(nothing)'
        g = got[i] if i < len(got) else '(nothing)'
        mark = '  ' if w == g else '->'
        out.append(f'   {mark} line {i + 1}: expected {w!r}' + ('' if w == g else f'\n            got      {g!r}'))
    return '\n'.join(out)


def main(argv):
    pattern = argv[0] if argv else ''
    tests = sorted(os.path.join(d, f) for d, dirs, files in os.walk(HERE)
                   for f in files if f.endswith('.haste') and pattern in os.path.relpath(os.path.join(d, f), HERE)
                   if not (set(os.path.relpath(d, HERE).split(os.sep)) & SKIP))
    if not tests:
        print('no tests match', repr(pattern)); return 1
    start, failed = time.time(), 0
    with ThreadPoolExecutor(max_workers=os.cpu_count() or 2) as pool:
        for path, problem, secs in pool.map(run, tests):
            name = os.path.relpath(path, HERE)
            if problem:
                failed += 1
                print(f'FAIL  {name}\n{problem}')
            else:
                print(f'ok    {name}  ({secs:.1f}s)')
    print(f'\n{len(tests) - failed} passed, {failed} failed, {len(tests)} tests in {time.time() - start:.1f} seconds')
    return failed


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
