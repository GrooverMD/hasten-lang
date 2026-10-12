# Hasten for FMX

Hasten on FireMonkey, for Windows, macOS and Linux. It is being converted from [Hasten for VCL](../vcl/) in
steps, sharing every unit that does not depend on VCL (in [`../common/`](../common/)).

**Done**: files in tabs (New, Open, Save, Save As, Close; reopened next time), Run (F9), Build (Ctrl+F9),
Stop (Ctrl+F2) and Run Tests through `haste.py`, the output with a jump to the first error and a double-click
on any `file.haste:12`, and Haste colours with module names and aliases from `haste.py words`. On a Mac the
shortcuts use Cmd.
**Next**: projects and the Project Manager, Project/Module Options and Settings; then Help Insight, Find and
the toolbar.

## Build

1. Clone [FMXRichMemo](https://github.com/HemulGM/FMXRichMemo) (MIT), the editor control.
   **On Delphi 12**, apply the patch here inside that folder: `git apply path\to\FMXRichMemo-Delphi12.patch`.
   FMXRichMemo's README says Delphi 12+, but since February 2026 it uses Delphi 13's `not in` and an FMX method
   Delphi 12 lacks (`ShouldDrawLeftAndRightSelectionSides`). The patch writes `not (X in S)` and skips that one
   call before Delphi 13, which only drew the caret-coloured edges of a selection.
2. Open `HastenFMX.dpr` in Delphi and add the FMXRichMemo folder to the search path.
3. Build for Windows 64-bit; then macOS and Linux (FMXLinux) if you have them. Hasten finds `haste.py` up to
   eight folders above the program, or asks (Run > Where is haste.py). Python is `python` on Windows and
   `python3` elsewhere; settings are in `HastenFMX.ini` in the Hasten folder of the user's home.

| File | |
|---|---|
| `HastenFMX.dpr` | The program |
| `Hasten.FMX.Main.pas`, `.fmx` | The main window, designed in the form designer: menus, actions, tabs, output |
| `Hasten.FMX.Editor.pas` | An editor tab: FMXRichMemo with Haste colours, line numbers, the current line |
| `Syntax.Code.Haste.pas` | Haste colours for FMXRichMemo, the same as Hasten for VCL |
| `../common/Hasten.Runner.pas` | Runs `haste.py` and streams its output; Stop ends the whole process tree (shared with VCL) |
| `FMXRichMemo-Delphi12.patch` | Lets FMXRichMemo build with Delphi 12 |
