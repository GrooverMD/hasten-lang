# Hasten for FMX

The start of a cross-platform Hasten on FireMonkey. For now a test of [FMXRichMemo](https://github.com/HemulGM/FMXRichMemo) (MIT, Delphi 12+) as the editor for an FMX
Hasten that runs on Windows, macOS and Linux. Nothing of Hasten depends on it yet.

## Build

1. Clone FMXRichMemo somewhere: `git clone https://github.com/HemulGM/FMXRichMemo`
   **On Delphi 12**, apply the patch here inside that folder: `git apply path\to\FMXRichMemo-Delphi12.patch`.
   FMXRichMemo's README says Delphi 12+, but since February 2026 it uses Delphi 13's `not in` and an FMX method
   Delphi 12 lacks (`ShouldDrawLeftAndRightSelectionSides`). The patch writes `not (X in S)` and skips that one
   call before Delphi 13, which only drew the caret-coloured edges of a selection.
2. Open `HastenFmxTest.dpr` in Delphi and let it make the project.
3. Project > Options > Building > Delphi Compiler > Search path: add the FMXRichMemo folder.
4. Build for Windows 64-bit first; then macOS and Linux (FMXLinux) if you have them.

| File | |
|---|---|
| `HastenFmxTest.dpr` | The program |
| `Hasten.FmxTest.Main.pas` | The test window, built in code |
| `FMXRichMemo-Delphi12.patch` | Lets FMXRichMemo build with Delphi 12 |
| `Syntax.Code.Haste.pas` | Haste colours for FMXRichMemo, the same as Hasten's VCL highlighter |

## What to check

- **Colours**: the sample shows every kind of token: keywords, types, `it`/`self`, built-ins, members, modules,
  aliases, text, numbers (`1_200`, `0xFF`, `0.5e-3`), comments, symbols.
- **Words**: `python haste.py words examples/Fractal/Fractal.haste > words.txt`, then Words... and load it:
  `Generate` and the aliases should turn lime.
- **Typing**: type, select, undo (Ctrl+Z) and redo, copy and paste, in the middle of a line and at the end.
  Colours should follow at once.
- **Size**: Stress makes 2000+ lines. Note the load and jump times in the status line, then scroll and type
  near the end: it should not lag.
- **Gutter**: line numbers on and off; the current line is shaded.
- **Platforms**: the same on macOS and Linux, if you can build for them.

If typing, scrolling or the gutter fall short, Hasten gets its own FMX editor control instead, and this
highlighter carries over to it.
