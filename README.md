<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/haste-logo-dark.svg">
    <img src="assets/haste-logo-light.svg" alt="Haste" width="420">
  </picture>
</p>

<p align="center"><b>Fast to write. Fast to run.</b></p>

Haste is an experimental programming language that compiles to small, dependency-free native executables for
**Windows, macOS and Linux**, all from any one of them. It keeps the readability of Pascal, makes properties the
default for everything in a class, works out types for you, and still runs at the speed of C.

> **Status: experimental prototype.** The language changes from day to day and the compiler is a proof of concept
> written in Python. Expect breaking changes. Not for production use.

## Hello World

`examples/hello.haste`:

```haste
alias Write = System.Write

Write("Hello World")
```
or even smaller, a one line "Hello World".
```haste
System.Write("Hello World")
```
```python
> python ../haste.py run hello.haste
Hello World
```

No `main`, no `program` header and no `uses` list: top-level code is the program, and `System` is found
automatically. `alias` gives `System.Write` a short name. The smallest version is a single line,
`print("Hello World")`.

## A little more

```haste
class Account
  Owner = "Unknown" where it <> ""
  Balance = 0.0 where it >= 0
  Tier => if Balance >= 1000 then "Gold" else "Standard"
end

a = Account(Owner: "Mark", Balance: 1500)
print("{a.Owner}: {a.Balance:2} ({a.Tier})")

try
  a.Balance = -20
catch e
  print("Rejected: {e}")
end
```

```
Mark: 1500.00 (Gold)
Rejected: Account.Balance cannot be -20 (requires it >= 0)
```

## Why Haste

- **Properties by default.** Every member of a class is a property. `where` adds validation that runs on every
  assignment, including in the constructor, and `=>` makes a computed, read-only property. One line replaces a
  field, a getter, a setter and its checks.
- **No type declarations, still native speed.** `fn Area(w, h) = w * h` has no types. The compiler generates one
  native version for each combination of argument types you actually use.
- **No imports.** Write `Text.Upper(name)` or `System.Bitmap(...)` and the compiler finds the module. `alias` gives
  long names a short one, and only code your program reaches is compiled in.
- **Cross-compile everything.** One command builds Windows, macOS and Linux executables from the same machine.
- **Every core, safely.** `parallel for` spreads a loop across all cores, and the compiler rejects loops that would
  change shared variables.
- **Command-line switches in one line.** `switch Width = 1200 where it >= 16   // image width` gives you
  `--width`, validation and `--help` with no parsing code.

## Getting started

You need **Python 3.8 or newer**. Everything else is one package, which brings the cross-compiling C toolchain:

```
pip install ziglang
git clone https://github.com/hasten-lang/haste.git
cd haste/examples
python ../haste.py run hello.haste
```

| Command | What it does |
|---|---|
| `python haste.py run file.haste [switches]` | Build for this system and run. Anything after the file goes to your program. |
| `python haste.py build file.haste` | Build for this system |
| `python haste.py build file.haste --target windows,macos,linux` | Build for every system (`macos-x64` for Intel Macs) |
| `python haste.py c file.haste` | Show the generated C |

Executables go into `build/` next to the source file.

## Examples

| Example | Shows |
|---|---|
| [`hello.haste`](examples/hello.haste) | The smallest program, and `alias` |
| [`bank.haste`](examples/bank.haste) | Classes, validated and computed properties, lists, `try`/`catch` |
| [`fractal.haste`](examples/fractal.haste) | Type-free functions, `System.Bitmap`, command-line switches. Try `--width 1920 --height 1080`. |
| [`fivewords.haste`](examples/fivewords.haste) | Five words with 25 different letters, found in about 0.02 seconds with bit masks and `parallel for`. Needs `words_alpha.txt` from [dwyl/english-words](https://github.com/dwyl/english-words). |

## The language in brief

```haste
alias Upper = Text.Upper                  // a short name for anything in a module

switch Name = "World" where it <> ""      // set with --name; validated; listed in --help

fn Greet(who) = "Hello {who}"             // no types: inferred from each call

total = 0                                 // variables are created by assignment...
for i in 1..10
  total = total + i                       // ...and keep the type they started with
end

let squares: [int] = []                   // let = can't be reassigned; lists grow with Add
for i in 1..5
  squares.Add(i * i)
end

flags = 5 or (1 shl 3)                    // and, or, xor, not, shl, shr work on bits, as in Pascal

print(Upper(Greet(Name)))
print("total {total}, {squares.Count} squares, last {squares[4]}, flags {flags}")
```

| Feature | Syntax |
|---|---|
| Property with a default | `Name = "World"` |
| Property with a type | `Items: [Account] = []` |
| Validated property | `Rate = 0.05 where it >= 0 and it <= 0.2` |
| Computed, read-only property | `Summary => "{Name}: {Balance:2}"` |
| Function, one expression | `fn Square(x) = x * x` |
| Function, block | `fn Name(args) ... end` |
| Loops | `for x in list`, `for i in 1..n`, `while cond`, `parallel for x in list` |
| Errors | `try ... catch e ... end` |
| String interpolation | `"{value}"`, `"{price:2}"` for 2 decimals |
| Calling C | `extern fn Sqrt(x: float): float = "sqrt"` |
| Include a whole module | `need Module` (rarely needed) |

There is no `nil`: every property always has a value.

## How it works

`haste.py` parses Haste, infers types and generates C for only the code your program reaches. The C is then
compiled by [Zig](https://ziglang.org/)'s `zig cc`, which is built on LLVM and can target Windows, macOS and Linux
from any of them. The runtime (`runtime.h`) is a few hundred lines of plain C included in each program.

```
haste.py          the compiler
runtime.h         the runtime included in every program
lib/              standard library modules (System, Text, Math, Time, Net)
examples/         example programs
assets/           logo and icons
```

## Limitations

- Memory is never freed. Fine for tools that run and exit, not yet for long-running programs.
- An error inside `parallel for` ends the program; it cannot be caught outside the loop.
- The compiler checks that `parallel for` doesn't change outer variables, but not that two iterations don't change
  the same object through a method call.
- No generics, custom property setters, `return` inside `try`, or GUI yet.
- Error messages give a line number but not always the file name.

## Roadmap

- **Hasten**, the Haste IDE
- Automatic memory management (reference counting with weak references)
- A GUI library
- A faster compiler, written in Haste or Delphi

## Not related to the older "Haste"

This project has no connection with the Haste Haskell-to-JavaScript compiler (`haste-compiler`), which was
abandoned in 2017. Its former website, `haste-lang.org`, is no longer run by that project and is flagged by browsers
as a deceptive site. Do not visit it. This project's only official home is
[github.com/hasten-lang](https://github.com/hasten-lang).

## License

The code is released under the [MIT License](LICENSE). Programs you write in Haste are yours, with no conditions
from this project, even though the runtime is compiled into them.

The names **Haste** and **Hasten** and the Haste logo are not covered by the license. Please don't use them for
modified versions in a way that suggests they are official.
