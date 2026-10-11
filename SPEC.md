# The Haste Language

This is the definition of Haste: what a program means, what is an error, and what happens at run time. The
README introduces the language; this document is the reference that settles questions.

The compiler (`haste.py`), the runtime (`runtime.h`) and the tests (`tests/`) must agree with it. When they
disagree, one of them has a bug, and the fix comes with a test. A change to the language starts here: a rule is
decided and written down before it is built.

Rules marked *Why* give the reason for a decision, so later decisions can be checked against it.

---

## 1. Source text

**Files.** A program is a UTF-8 text file ending in `.haste`. A byte-order mark at the start is ignored. Line
endings may be `\n` or `\r\n`.

**Lines.** A statement ends at the end of its line. A line continues while a `(`, `[` or `{` is open, so long
calls, lists and dictionaries may span lines. There are no semicolons. Blocks (`if`, `while`, `for`, `try`, `fn`,
`class`, `init`, `write`) end with `end`. Indentation is free, but the compiler uses it to point at the block
that is missing its `end`.

**Comments.** `//` to the end of the line, outside strings.

**Names.** A letter or `_`, then letters, digits or `_`. Letters may be any Unicode letter. Names are
case-sensitive: `Total` and `total` are different.

**Keywords.** These cannot be used as names:

```
alias and catch class div elif else end extern false fn for if in init let mod need not or
parallel return shl shr switch then true try var where while write xor
```

`it`, `field` and `self` are ordinary names with a special meaning in the places described below.

**Literals.**

| Kind | Form | Notes |
|---|---|---|
| Whole number | `42`, `-7`, `0xFF`, `0b1010`, `1_000_000` | Decimal, hexadecimal (`0x`) or binary (`0b`); `_` may separate digits. Must fit in 64 bits: −9223372036854775808 to 9223372036854775807. A `-` directly before a number is part of it. |
| Decimal | `3.14`, `0.5`, `1e5`, `2.5e-3` | Digits on both sides of the point; an exponent makes a decimal. A number that runs into letters (`12abc`) is an error. |
| Text | `"Hello {name}"` | One line. Escapes: `\n` `\r` `\t` `\\` `\"` `\{` `\}`. `{expression}` inserts a value (§6.8). |
| True/false | `true`, `false` | |
| List | `[1, 2, 3]`, `[]` | |
| Dictionary | `{"Mark": 50}`, `{}` | |

Not in the language: `!=`, `==`, `+=`, `&&`, `||`, `!`, `;`, `else if` and `do`. The compiler says what to write
instead.

---

## 2. Program structure

A program file holds, in any order:

- statements, which run from top to bottom: this is the program;
- `fn` functions and `class` declarations, usable anywhere in the file, before or after they appear;
- `alias`, `switch` and `need` declarations.

There is no `main`, `program` header or `uses` list. Functions, classes and aliases share one set of names in a
file: declaring a name twice is an error.

*Why:* a program should be as short as its idea. `print("Hello")` is a complete program.

Modules (§11) are files that hold only classes, functions, aliases and `init` blocks.

---

## 3. Types

| Type | Written | Values |
|---|---|---|
| Whole number | `int` | 64-bit signed |
| Decimal | `float` | 64-bit IEEE double |
| Text | `string` | UTF-8 text, immutable |
| True/false | `bool` | `true`, `false` |
| List | `[T]` | items of one type, numbered from 0 |
| Dictionary | `{K: V}` | keys `int`, `string` or `bool`; kept in the order they were added |
| Object | a class name | an instance of a class |

**There is no nil.** Every variable, property and list item always holds a value of its type. A property whose
type is a class needs a default object.

*Why:* nil is the commonest cause of crashes in the languages Haste learns from. Without it, a value that is
there can always be used.

**Type names.** `alias Grid = [[int]]` gives a type a name, usable wherever a type is written.

### 3.1 How types are worked out

Types are rarely written. The compiler works them out, and every value still has exactly one type.

- **Variables** take the type of their first value.
- **Whole number to decimal.** A whole-number variable that is later given a decimal is a decimal from the start:
  `var t = 0` followed by `t = t + 2.5` makes `t` a `float`. No other change of type is allowed.
- **Empty lists and dictionaries** (`[]`, `{}`) take their item types from their first use: the first `Add`,
  the first `d[k] = v`, or the first `d.Get(k, default)`. One that is used before its type is known is an error,
  and the message shows how to write the type.
- **Functions without types** are compiled once for each combination of argument types they are called with
  (§8). `fn Twice(x) = x * 2` called with an `int` and with a `float` becomes two functions.
- **Return types** come from the `return` statements; `int` and `float` together make `float`; anything else
  mixed is an error.
- **Whole numbers become decimals where a decimal is expected** (an argument, a property, a list of decimals).
  Decimals never silently become whole numbers: use `Int(x)`.

---

## 4. Variables and scope

| Form | Meaning |
|---|---|
| `x = 5` | Declares `x` if it is new, otherwise assigns. A variable declared this way can be changed. |
| `var x = 5` | Declares a variable that can be changed. |
| `let x = 5` | Declares a variable that cannot be changed. |
| `let x: float = 5` | Declares with a written type. |

**Scope.** A variable is known from its declaration to the end of the block it is declared in. A variable
declared inside an `if`, loop or `try` is not known after it. An inner block may declare a name that an outer
block already has; the inner one hides the outer one until the block ends. Declaring the same name twice in one
block is an error.

**Functions see** their parameters and their own variables, plus the functions, classes, aliases and modules of
their file, and the program's switches (§12). They do not see the program's other top-level variables. Methods
also see their object's properties and methods (§9).

*Why:* a function that depends only on its arguments can be understood, tested and run in parallel on its own.

**Cannot be changed:** parameters, `let` variables, `for` loop variables, switches, `it`, `self`, and outer
variables inside `parallel for` (§13).

---

## 5. Checking

Haste builds only the code a program reaches, but it checks all of it. In code nothing calls yet, the compiler
still reports unknown names, aliases that name nothing, unknown written types, and property defaults that do not
match their written type. Types inside functions without written types can only be checked once something calls
them.

*Why:* a typo should not hide until the day the code is first used.

---

## 6. Expressions

### 6.1 Precedence, lowest first

| Level | Operators |
|---|---|
| 1 | `if c then a else b` |
| 2 | `or`, `xor` |
| 3 | `and` |
| 4 | `not` |
| 5 | `=` `<>` `<` `>` `<=` `>=` (one per expression: `a < b < c` is an error) |
| 6 | `+` `-` |
| 7 | `*` `/` `mod` `div` `shl` `shr` |
| 8 | unary `-` |
| 9 | calls `f(x)`, members `a.b`, indexes `a[i]` |

Note that `and`/`or` bind more loosely than comparisons: `flags and 4 = 4` means `flags and (4 = 4)`. Write
`(flags and 4) = 4`.

### 6.2 Arithmetic

| Operator | Whole numbers | Decimals |
|---|---|---|
| `+ - *` | Exact; going past 64 bits is the error *whole number overflow* | IEEE |
| `/` | Always gives a decimal: `7 / 2` is `3.5` | IEEE |
| `div` | Whole-number division, towards zero: `-7 div 2` is `-3` | error |
| `mod` | Remainder with the sign of the left side: `-7 mod 3` is `-1` | `fmod`: `-7.5 mod 2` is `-1.5` |
| unary `-` | Negating the smallest whole number is an overflow | IEEE |

Dividing a whole number by zero (`div`, `mod`) is the error *division by zero*. Decimal division by zero gives
`inf` or `nan`. Mixing `int` and `float` gives `float`. `+` on two texts joins them; text and a number cannot
be added: use `"{n}"` or `Str(n)`.

*Why overflow is an error:* a wrapped number is a wrong answer that looks right. In C it is not even a wrap: the
optimiser may assume it never happens.

### 6.3 Bits

On whole numbers, `and`, `or`, `xor` and `not` work on the bits, as in Pascal. `shl` and `shr` shift by an
amount from 0 to 63 (anything else is an error); `shl` drops the bits shifted out, `shr` keeps the sign.

### 6.4 Logic

On `true`/`false`, `and` and `or` stop as soon as the answer is known: in `l.Count > 5 and l[9] = 1` the index is
not evaluated when the list is short. `xor` is true when exactly one side is. `not` negates. Conditions in `if`,
`while` and `where` must be `true`/`false`, never numbers.

### 6.5 Comparison

| Values | `=` / `<>` | `<` `>` `<=` `>=` |
|---|---|---|
| Numbers | by value, `int` and `float` mixed | by value |
| Text | same characters | by character code |
| True/false | same value | error |
| Lists, dictionaries | same contents (dictionaries: same keys and values, any order) | error |
| Objects | the same object | error |

### 6.6 If expression

`if c then a else b` gives `a` or `b`. Both must have the same type, except that `int` and `float` give `float`.
It cannot be an operand without brackets: `1 + (if c then 1 else 2)`.

### 6.7 Calls, members and indexes

`f(a, b)` calls a function; arguments are positional. `Class(Prop: v, ...)` makes an object (§9).
`list[i]` and `dict[k]` read an item; `list[i] = v` and `dict[k] = v` change one.

### 6.8 Text interpolation

`"{expression}"` inserts the expression's value as `print` would show it (§14). `"{x:2}"` shows a number with 2
decimal places. `\{` is a brace that is just text.

---

## 7. Statements

**Assignment** `target = value` sets a variable, a property (`obj.Name = v`), a list item or a dictionary entry.

**If.**

```haste
if a > 0 then          // "then" is optional
  ...
elif a < 0
  ...
else
  ...
end
```

**While.** `while condition` ... `end`; `then` after the condition is optional, as after `if`.

**For.**

| Form | Runs |
|---|---|
| `for i in a..b` | `i` from `a` to `b` inclusive, up by 1; not at all when `b < a`. `b` may be the largest whole number. |
| `for x in list` | each item in order. Items added during the loop are reached too. |
| `for k in dict` | each key in the order it was added. Removing keys during the loop is safe. |
| `parallel for ...` | the same forms, spread over all cores (§13) |

The loop variable cannot be changed.

**Return.** `return value` or `return` (in a function with no value). Allowed anywhere in a function, including
inside `try`.

**Try.**

```haste
try
  ...
catch e
  ...                  // e is the error's message, as text
end
```

**Expression statements** must be calls: a line holding only `5` or `x + 1` is an error.

---

## 8. Functions

```haste
fn Square(x) = x * x                      // one expression
fn Area(w: float, h: float): float        // types may be written
  return w * h
end
extern fn Sqrt(x: float): float = "sqrt"  // a C function; every type must be written
```

- **Parameters** without types take the types of each call's arguments; a separate version is compiled for each
  combination used. Parameters cannot be changed.
- **The result type** is worked out from the `return`s (§3.1). A function that calls itself before its result
  type is known needs it written: `fn Fact(n): int = ...`.
- **A function that must return a value** and reaches its end without one is an error.
- **Functions as values.** A function's name without brackets is a value that can be passed to a function and
  called there:

  ```haste
  fn Apply(f, x) = f(x)
  fn Twice(x) = x * 2
  print(Apply(Twice, 3))          // 6
  Sort(names, ByLength)           // a compare function
  let up = Text.Upper             // a variable holding a function
  ```

  The type of such a value is the function itself, so each function passed gets its own compiled version of the
  receiver, with a direct call: no cost at run time. A variable or parameter that holds a function always holds
  the same one. Functions cannot be kept in lists or dictionaries, compared or printed. Methods are not values.

  *Why:* this covers what passing functions is for (sorting, filtering, mapping, callbacks) using the same
  compile-per-type design as type-free functions, with no hidden function pointers.
- **Recursion** may go about 16 million calls deep for small functions (the program's stack is 256 MB). Deeper is
  the error *recursion too deep*, which can be caught.

---

## 9. Classes

```haste
class Account
  Owner = "Unknown" where it <> ""            // a property with a default and a rule
  Balance = 0.0 where it >= 0
  History: [float] = []                        // a written type
  Tier => if Balance >= 1000 then "Gold" else "Standard"   // computed, read-only
  Name = "?"
    write                                      // runs on every assignment
      field = Text.Trim(it)
    end
  fn Deposit(amount)                           // a method
    Balance = Balance + amount
  end
end

a = Account(Owner: "Mark", Balance: 1500)
```

**Properties** need a type or a default, or both. A property holding a list or dictionary needs its type written,
and cannot have a `where` rule: the rule would only see a whole new list being assigned, never items being added,
so it would look like protection it does not give. Check items in the method that adds them.
Inside the class, properties and methods are used by their bare names or through `self`.

**Rules.** `where` gives a condition on the property's value, `it`. When a property is set, its rule is checked
before the new value is stored; if it fails, the error is *Account.Balance cannot be -20 (requires it >= 0)*.

**Computed properties** (`=>`) are worked out each time they are read and cannot be set, unless they have a
`write` block.

**Write blocks** run instead of storing the value: `it` is the incoming value and `field` the stored one
(a computed property has no `field`). Inside its own write block, a property must be set through `field`.

**Making objects.** `Class(Prop: value, ...)` takes named properties only, each at most once. Properties not given
take their defaults. Write blocks run for the values given. Once every property has its value, all the object's
rules are checked together, so defaults are checked too and a rule may compare properties (`Hi = 10 where it >= Lo`)
whatever order they were given in.

**Default cycles.** A default that makes another object of the same class, directly or through other classes
(`Next: Node = Node()`), is an error: each new object would make another forever. Hold such objects in a list:
`Next: [Node] = []`.

**Methods** are functions (§8) that also see the object's properties and methods. Objects are shared, never
copied: assigning an object or putting it in a list refers to the same object.

---

## 10. Errors

**Compile-time errors** stop the build with *file:line: message*. A missing `end` is reported at the line where
the block begins.

**Run-time errors** include: whole number overflow, division by zero, an index outside a list, a missing dictionary
key, a broken property rule, text that is not a number (`Text.ToInt`), a file that cannot be read or written,
an out-of-range bitmap pixel, recursion too deep, and `System.Fail(message)`.

**Catching.** `try ... catch e ... end` catches any run-time error raised inside the `try`, including inside
functions it calls. `e` is the message. Variables the `try` changed have their latest values in the `catch`.
`System.Fail(message)` raises an error from Haste code.

**Unhandled errors** end the program with exit code 1 and print where they happened:

```
Unhandled error: index 5 is outside 0..1
  in scores.haste:12
  called from scores.haste:30
```

A recursion's repeats are shown once, with how many more times they repeat.

---

## 11. Modules

**A module is a file.** `Text.Upper` refers to the function `Upper` in `Text.haste`. A module is looked for first
in the program's folder, then in `lib/`. A folder makes a dotted name: `Shapes.Rect` is `Shapes/Rect.haste`. Names
must match the file name exactly, including upper and lower case, on every system.

**No imports.** Using a module's name loads it. Only the functions and classes a program reaches are compiled in.
`need Module` keeps all of a module's functions that have written types, whether used or not (rarely needed).

**A module holds** classes, functions, aliases and `init` blocks; a statement in a module is an error. Modules may
use each other, in a circle too. The same name may be used in different modules and in the program.

**Init blocks** (`init` ... `end`) run once, before the program, for each module the program uses.

**Aliases** give anything a short name: a module (`alias T = Text`), a class (`alias Bmp = System.Bitmap`), a
function (`alias Up = Text.Upper`), a type (`alias Grid = [[int]]`), or another alias. An alias that goes round in
a circle is an error.

---

## 12. Switches

```haste
switch Width = 640 where it > 0          // the window width
switch Title = "untitled"
switch Quiet = false
```

A switch is a top-level variable that the command line can set. Its type comes from its default (or is written:
`switch Width: int = 640`) and must be `int`, `float`, `string` or `bool`. The comment on its line is its help.
Switches can be read everywhere in the program's file, including in functions and methods, but not changed:
they are the program's settings.

| Command line | Means |
|---|---|
| `--width 1920`, `--width=1920`, `-width 1920` | set a switch (names ignore case) |
| `/width:1920` | the same, on Windows only |
| `--quiet` | an on/off switch alone means on |
| `--quiet false` | `true/false`, `yes/no`, `on/off`, `1/0` |
| `--help`, `-h`, `-?`, `/?` | list the switches with their help, defaults and rules |

A value of the wrong kind, a value too big for its type, an unknown switch, a missing value, or a value that
breaks the switch's `where` rule ends the program with a message before it starts. Given twice, the last value
counts.

---

## 13. Parallel for

`parallel for` runs its iterations at the same time on all cores, in no particular order.

- **Outer variables** are read-only inside the loop: changing one is a compile error.
- **Setting a property** of an object from outside the loop (`c.N = ...`, or a property of `self`) is a compile
  error: every iteration would change the same object. Change the loop's own item (`t.Found = ...`) instead.
- **Shared lists and dictionaries** may be added to or changed by many iterations: each change is locked, and the
  order of additions is not defined.
- **Filling a list made before the loop** by index (`out[i] = ...`) is the usual way to collect results; each
  iteration should write only its own slots.
- **An error** that is not caught inside the loop ends the program.

The compiler cannot see changes made through method calls; two iterations calling a method that changes the same
object is a mistake it does not catch.

---

## 14. Text and numbers as text

**Characters.** Lengths and positions count characters (Unicode code points), not bytes: `"café".Length` is 4.
A byte that is not valid UTF-8 counts as one character.

| Function | Does |
|---|---|
| `s.Length` | number of characters |
| `Text.Sub(s, start, count)` | `count` characters from position `start`; outside the text is an error |
| `Text.Code(s, i)` | the character code at position `i` |
| `Text.Find(s, code, from)`, `Text.IndexOf(s, part, from)` | position of the next match at or after `from`, or the length if none |
| `Text.PadRight(s, width)` | spaces after `s` up to `width` characters; never shortens |
| `Text.Repeat(s, n)` | `s` `n` times; empty for `n <= 0` |
| `Text.Upper(s)`, `Text.Lower(s)` | ASCII, accented Latin letters, Greek and Cyrillic |
| `Text.ToInt(s)`, `Text.ToFloat(s)` | spaces around are allowed; anything else is an error |
| `Text.StartsWith(s, p)`, `Text.EndsWith(s, p)` | whether `s` begins or ends with `p` |
| `Text.PadLeft(s, width)` | spaces before `s` up to `width` characters; never shortens |
| `Text.Char(code)` | the character with this code, as text: the opposite of `Code` |
| `Text.TrimStart(s)`, `Text.TrimEnd(s)` | spaces removed from one end (`Text.Trim` does both) |
| `Text.Reverse(s)` | the characters in reverse order |
| `Text.LastIndexOf(s, part)` | position of the last match, or -1 |
| `Text.Lines(s)` | the lines of `s`, without their `\n` or `\r\n` |
| `Text.IsDigit(c)`, `Text.IsLetter(c)`, `Text.IsSpace(c)` | tests on a character code; letters are ASCII, accented Latin, Greek and Cyrillic |

**Numbers as text.** Whole numbers print in decimal. Decimals print in their shortest form with up to 15
significant digits that reads back as the same number (as Delphi's `FloatToStr`): `250`, `1234567.5`, `0.3` for
`0.1 + 0.2`, `9` for `9.0`, `1e+15` once a number has more than 15 digits, `inf`, `nan`.

**Built-ins.** `print(x)` prints any value on its own line; `Str(x)` gives the same text. `Int(x)` turns a
decimal into a whole number towards zero (an infinite or out-of-range decimal is an error); `Float(x)` the other
way.

**Lists, dictionaries and objects as text** look as they would be written: `[1, 2, 3]`, `["a", "b"]`,
`{"Mark": 50}`, `Point(X: 1, Y: 2.5)` (stored properties, not computed ones). Text inside them is quoted. Nesting
stops at 3 levels (`[...]`, `Point(...)`), and a list shows its first 100 items then `... N more`, so an object
that holds itself still prints as one line.

**Members.** Text: `Length`. Dictionaries: `Has(k)`, `Remove(k)` (nothing happens if `k` is not there),
`Get(k, default)`, `Count`, `[k]`. Lists:

| Member | Does |
|---|---|
| `Add(v)`, `Count`, `[i]` | add at the end, count, read or change an item |
| `Insert(i, v)` | put `v` at position `i`, from 0 to `Count` |
| `RemoveAt(i)` | remove the item at `i` and give it back |
| `Remove(v)` | remove the first item equal to `v`; nothing happens if there is none |
| `Has(v)`, `IndexOf(v)` | whether `v` is there; its first position, or -1 |
| `Clear()`, `Reverse()` | empty the list; reverse it in place |
| `Sort()`, `Sort(Before)` | sort in place, keeping equal items in their order: numbers, text and true/false by their natural order, anything else with a function `Before(a, b)` that says whether `a` goes before `b` |
| `Slice(start, count)`, `Copy()` | a new list with `count` items from `start`; a new list with all of them |

Equal means equal as `=` sees it (§6.5). A position outside the list is an error. Adding, inserting, removing and
clearing are locked during `parallel for` (§13); sorting and reversing are not, so sort before or after the loop.

**Math.** `Abs`, `Sign`, `Max`, `Min` and `Clamp` have no types, so whole numbers stay whole (`Max(3, 5)` is `5`).
`Sqrt`, `Pow`, `Floor`, `Ceil`, `Exp`, `Log` (natural), `Log10`, `Sin`, `Cos`, `Tan`, `Asin`, `Acos`, `Atan`,
`Atan2`, `Hypot` work on decimals, angles in radians; `Pi()` and `E()` are constants. `Round(x, places)` rounds
halves away from zero. `Random()` gives a decimal from 0 up to but not including 1, `RandomInt(lo, hi)` a whole
number from `lo` to `hi` inclusive, without bias; each thread has its own generator, and `Seed(n)` makes the calling
thread's sequence repeatable.

**Time.** A time is a decimal: seconds since 1 January 1970, UTC, so times compare and move by arithmetic
(`t + 86400` is a day later). `Time.Now()` is the current time and `Time.Sleep(seconds)` waits. `Time.Local(t)` and
`Time.Utc(t)` give a `Moment` with `Year`, `Month` (1-12), `Day`, `Hour`, `Minute`, `Second`, `Weekday` (1 Monday to
7 Sunday) and `Text` (`2026-10-11 09:55:03`). `Time.Make(...)` and `Time.MakeUtc(...)` turn a date and time back
into a time; an impossible one, such as 30 February, is an error rather than being moved to another day.
`Time.Elapsed()` measures intervals: subtract two readings.

**Files and the outside world** are in `System` (`ReadText`, `ReadLines`, `WriteText`, `AppendText`,
`FileExists`, `FileOpen`/`FileByte`/`FileClose`, `Bitmap`, `Fail`), `Text`, `Math`, `Time` and `Net`. `System.Files(folder)` and `System.Folders(folder)` list a folder's
files and folders by name, sorted; `System.FolderExists`, `System.MakeFolder` (with any missing folders above it) and
`System.DeleteFile` manage them. `System.Env(name, default)` reads an environment variable. `System.Exit(code)` ends
the program at once with that exit code. File names
are UTF-8 on every system. `FileExists` is false for a folder. Reading a folder, or a file holding a zero byte, as
text is an error.

---

## 15. Memory

Memory is managed by a garbage collector: there is no `Free`, and cycles are no problem. It runs when 8 MB have
been allocated since the last collection (or as much as was in use, if more), including during `parallel for`,
when the worker threads pause at their next allocation or iteration. Freed memory is reused by the program but not
returned to the system until it ends. A C library called through `extern fn` must not keep Haste values after the
call returns.

---

## 16. Limits

| Limit | Value |
|---|---|
| Whole numbers | 64-bit signed |
| Nesting of one expression | 2000 levels |
| Program stack (recursion) | 256 MB; `parallel for` workers 64 MB each |
| Files open with `FileOpen` at once | 64 |
| `parallel for` threads | one per core, up to 64 |

---

## 17. Decisions

Questions that were open, and what was decided.

1. **Switches in functions:** readable everywhere, as settings; never changeable (§12).
2. **`then` after `while`:** optional, as after `if` (§7).
3. **Hexadecimal, binary and exponent literals, and `_` between digits:** added (§1).
4. **Rules on list properties:** not allowed, because they could not see items being added (§9).
5. **Printing lists, dictionaries and objects:** shown as they would be written (§14).
6. **Functions as values:** added, compiled per function passed (§8).
7. **Local aliases:** not added. An alias is top-level but may be placed anywhere in the file, so it can sit
   just before the code that uses it; inside a block it would let a type or function name mean different things
   on different lines (§11).

## 18. Open questions

1. **Generic classes**, such as a `Stack` that works for any item type. Lists and dictionaries are already generic,
   and type-free functions already work on any type, so most programs do not need them. The design that fits Haste
   is the one functions use: a class whose properties have no type and no default would be compiled once for each
   combination of property types it is made with (`Pair(First: 1, Second: "a")`). That changes how every class type
   is named and checked, so it waits for a program that needs it.
