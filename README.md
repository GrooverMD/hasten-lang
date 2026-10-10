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

```
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
  field, a getter, a setter and its checks, and a `write` block adds custom logic when you need it.
- **No type declarations, still native speed.** `fn Area(w, h) = w * h` has no types. The compiler generates one
  native version for each combination of argument types you actually use.
- **No imports.** Write `Text.Upper(name)` or `System.Bitmap(...)` and the compiler finds the module. `alias` gives
  long names a short one, and only code your program reaches is compiled in.
- **Cross-compile everything.** One command builds Windows, macOS and Linux executables from the same machine.
- **Every core, safely.** `parallel for` spreads a loop across all cores, and the compiler rejects loops that would
  change shared variables.
- **No memory to manage.** No `Free`, no `try ... finally` to release objects, no weak references. A garbage
  collector frees what the program can no longer reach, cycles included, and a program that does no allocating
  doesn't include it.
- **Command-line switches in one line.** `switch Width = 1200 where it >= 16   // image width` gives you
  `--width`, validation and `--help` with no parsing code.

## How Haste compares

**One line of code, a tiny native executable, built for Windows, macOS and Linux from any one of them with one
command.**

This is the complete Hello World program. There are no includes, no `uses` list and no `main`:

```haste
print("Hello World")
```

```
python haste.py build hello.haste --target windows,macos,linux
```

| Executable | Size |
|---|---|
| Linux (static, x86-64) | 5 KB |
| macOS (Apple Silicon) | 48 KB |
| Windows (x86-64) | 73 KB |

The sizes are measured. The Linux and Windows executables have been run; the macOS executable has been built but
not yet run on a Mac.

The comparison below is **untested**. It comes from the other languages' documentation and general knowledge, not
from building anything with them:

| Language | Whole program is one line | Native executable | Cross-compiles to all three, out of the box |
|---|---|---|---|
| **Haste** | ✅ | ✅ 5–73 KB | ✅ one command, nothing extra to install |
| Python, Ruby, Lua | ✅ | ❌ needs the interpreter, or a bundle of several MB | ❌ |
| Nim | ✅ | ✅ | ⚠️ needs a separate cross-compiler per target, and extra flags |
| Crystal | ✅ | ✅ larger | ❌ links on the target machine |
| C, Go, Rust, Delphi | ❌ needs `main` or `program` | ✅ | varies: Go yes, others need extra tools |

Credit where it's due: the cross-compiling comes from [Zig](https://ziglang.org/), which ships every system's C
libraries in one package. Haste's part is building on it, and adding nothing to the executable that the program
doesn't use.

## Getting started

You need **Python 3.8 or newer**. The only other thing is [Zig](https://ziglang.org/), the cross-compiling C
toolchain, which `haste.py setup` downloads into the Haste folder:

```
git clone https://github.com/GrooverMD/hasten-lang.git
cd hasten-lang
python haste.py setup
cd examples
python ../haste.py run hello.haste
```

`setup` puts Zig in `tools/zig`, checked against the checksum ziglang.org publishes. `pip install ziglang` works
too; Haste uses `tools/zig` first, then a `zig` on the PATH, then the pip package.

**Antivirus programs** (Norton, Avast and AVG in particular) can mistake freshly built programs, and even Zig
itself, for threats and quarantine them; the detection usually has "gen" in its name, such as
`Win64:Evo-gen [Trj]`. Exclude the Haste folder from scanning, and with it Zig's cache, `%LOCALAPPDATA%\zig`
on Windows. Keeping Zig in `tools/zig` means the one exclusion covers it.

| Command | What it does |
|---|---|
| `python haste.py run file.haste [switches]` | Build for this system and run. Anything after the file goes to your program. |
| `python haste.py build file.haste` | Build for this system |
| `python haste.py build file.haste --target windows,macos,linux` | Build for every system (`macos-x64` for Intel Macs) |
| `python haste.py c file.haste` | Show the generated C |
| `python haste.py setup` | Download Zig into `tools/zig` |

Executables go into `build/` next to the source file.

## Examples

| Example | Shows |
|---|---|
| [`hello.haste`](examples/hello.haste) | The smallest program, and `alias` |
| [`bank.haste`](examples/bank.haste) | Classes, validated and computed properties, lists, `try`/`catch` |
| [`fractal.haste`](examples/fractal.haste) | Type-free functions, `System.Bitmap`, command-line switches. Try `--width 1920 --height 1080`. |
| [`scores.haste`](examples/scores.haste) | `write` blocks, dictionaries, and reading and writing text files |
| [`fivewords.haste`](examples/fivewords.haste) | Five words with 25 different letters, found in about 0.02 seconds with bit masks and `parallel for`. Needs the word list [`words_alpha.txt`](https://raw.githubusercontent.com/dwyl/english-words/master/words_alpha.txt) from [dwyl/english-words](https://github.com/dwyl/english-words), saved in `examples/`. |

## The language in brief

```haste
alias Upper = Text.Upper                  // a short name for anything in a module

switch Name = "World" where it <> ""      // set with --name; validated; listed in --help

fn Greet(who) = "Hello {who}"             // no types: inferred from each call

total = 0                                 // variables are created by assignment...
for i in 1..10
  total = total + i                       // ...and keep the type they started with
end

squares = []                              // no type needed: the first Add decides
for i in 1..5
  squares.Add(i * i)                      // so squares holds whole numbers
end

flags = 5 or (1 shl 3)                    // and, or, xor, not, shl, shr work on bits, as in Pascal

print(Upper(Greet(Name)))
print("total {total}, {squares.Count} squares, last {squares[4]}, flags {flags}")
```

| Feature | Syntax |
|---|---|
| Property with a default | `Name = "World"` |
| Empty list, type from the first `Add` | `names = []` then `names.Add("Ada")` |
| Property with a type | `Items: [Account] = []` |
| Validated property | `Rate = 0.05 where it >= 0 and it <= 0.2` |
| Computed, read-only property | `Summary => "{Name}: {Balance:2}"` |
| Custom setter: `it` is the new value, `field` the stored one | `Name = "?"` then `write` / `field = Text.Trim(it)` / `end` on the lines below |
| Writable computed property | `Fahrenheit => Celsius * 9 / 5 + 32` then `write` / `Celsius = (it - 32) * 5 / 9` / `end` |
| Dictionary | `ages = {"Mark": 50}`, `ages["Ada"] = 36`, `ages.Has(k)`, `ages.Remove(k)`, `ages.Count` |
| Empty dictionary, type from first use | `counts = {}` then `counts[w] = counts.Get(w, 0) + 1` |
| Dictionary type | `Stock: {string: int} = {}` |
| Loop over a dictionary's keys | `for name in ages` (in the order they were added) |
| Function, one expression | `fn Square(x) = x * x` |
| Function, block | `fn Name(args) ... end` |
| Loops | `for x in list`, `for i in 1..n`, `while cond`, `parallel for x in list` |
| Errors | `try ... catch e ... end` |
| String interpolation | `"{value}"`, `"{price:2}"` for 2 decimals |
| Calling C | `extern fn Sqrt(x: float): float = "sqrt"` |
| Short names | `alias T = Text`, `alias Bmp = System.Bitmap`, `alias Up = Text.Upper` |
| Type names | `alias Grid = [[int]]`, `alias Stock = {string: int}`, then `Cells: Grid = []` |
| Include a whole module | `need Module` (rarely needed) |
| Long lines | A line continues while a `(`, `[` or `{` is open |

There is no `nil`: every property always has a value. Whole numbers are 64-bit, and going past that is an error you can `catch`, never a silent wrap; `shl` and `shr` take amounts from 0 to 63. An unhandled error names the line it happened on and the lines each call came from. `=` compares lists and dictionaries by what they hold, and objects by being the same object. Haste only builds the code a program uses, but it checks all of it: a misspelt name in a function nothing calls yet is still an error.

```haste
class Temperature
  Celsius = 0.0
  Fahrenheit => Celsius * 9 / 5 + 32
    write
      Celsius = (it - 32) * 5 / 9
    end
end

t = Temperature()
t.Fahrenheit = 212
print("{t.Celsius} C")

counts = {}
for w in Text.Split("to be or not to be", " ")
  counts[w] = counts.Get(w, 0) + 1
end
for w in counts
  print("{w}: {counts[w]}")
end
```

### Text and files

| Function | Does |
|---|---|
| `Text.Split(s, sep)` / `Text.Join(list, sep)` | Text to a list and back |
| `Text.Trim(s)`, `Text.Upper(s)`, `Text.Lower(s)` | Tidy text |
| `s.Length`, `Text.Sub(s, start, count)`, `Text.Code(s, i)` | Lengths and positions count characters, so `"café".Length` is 4. `Upper`/`Lower` know accented Latin letters, Greek and Cyrillic. |
| `Text.Contains(s, part)`, `Text.IndexOf(s, part, from)`, `Text.Replace(s, old, new)` | Search and replace (`IndexOf` gives the length when not found) |
| `Text.ToInt(s)`, `Text.ToFloat(s)` | Text to numbers; bad text raises an error you can `catch` |
| `System.ReadLines(path)`, `System.ReadText(path)` | Read a file as lines (Windows line endings handled) or as one string |
| `System.WriteText(path, text)`, `System.AppendText(path, text)`, `System.FileExists(path)` | Write and check files |

## Tests

```
python tests/run.py           run every test (about 3 seconds)
python tests/run.py dict      run only the tests whose path contains "dict"
```

Each test is an ordinary Haste program in `tests/` whose comments say what must happen: `// out:` lines it
must print, `// error:` text the build or the run must fail with, and `// args:` switches to run it with.
Run the tests after every change to the compiler or the runtime.

## How it works

`haste.py` parses Haste, infers types and generates C for only the code your program reaches. The C is then
compiled by [Zig](https://ziglang.org/)'s `zig cc`, which is built on LLVM and can target Windows, macOS and Linux
from any of them. The runtime (`runtime.h`) is a few hundred lines of plain C included in each program.

Memory is managed by a mark-and-sweep garbage collector in the runtime. When 8 MB of new memory has been used (or
as much as was still in use after the last collection, if that is more), it marks everything the program can
still reach and frees the rest. The heap stays below about twice the memory actually in use. Small blocks come
from 64 KB pages grouped by size, so allocating and freeing them is fast. Text and lists of numbers are never
searched for pointers. The stack is scanned conservatively: any value that looks like a pointer into a block
keeps that block. So the generated C needs no bookkeeping, and an unlucky number can at worst keep a block
alive a little longer. No collection runs during a `parallel for`; garbage made inside one is freed after it.

```
haste.py          the compiler
runtime.h         the runtime included in every program
lib/              standard library modules (System, Text, Math, Time, Net)
examples/         example programs
tests/            the test suite: language, library, error messages, stress
ide/              Hasten, the Haste IDE (Delphi, SynEdit)
assets/           logo and icons
```

## Limitations

- Memory the collector frees is reused by the program but not handed back to the system until it ends.
- A C library called through `extern fn` must not keep Haste lists, dictionaries or text in its own memory after
  the call returns: the collector cannot see them there.
- An error inside `parallel for` ends the program; it cannot be caught outside the loop.
- The compiler checks that `parallel for` doesn't change outer variables, but not that two iterations don't change
  the same object through a method call.
- No generics, `return` inside `try`, or GUI yet.
- Class properties holding a list or dictionary need a type (`Items: [Account] = []`); local variables don't.

## Roadmap

- **Hasten**, the Haste IDE: a first version is in [`ide/`](ide/) (editor, highlighting, Run, Build, jump to errors)
- A GUI library
- A faster compiler, written in Haste or Delphi

## Not related to the older "Haste"

This project has no connection with the Haste Haskell-to-JavaScript compiler (`haste-compiler`), which was
abandoned in 2017. Its former website, `haste-lang.org`, is no longer run by that project and is flagged by browsers
as a deceptive site. Do not visit it. This project's only official home is
[github.com/GrooverMD/hasten-lang](https://github.com/GrooverMD/hasten-lang).

## License

The code is released under the [MIT License](LICENSE). Programs you write in Haste are yours, with no conditions
from this project, even though the runtime is compiled into them.

The names **Haste** and **Hasten** and the Haste logo are not covered by the license. Please don't use them for
modified versions in a way that suggests they are official.
