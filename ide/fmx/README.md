# Hasten for FMX

Hasten on FireMonkey, for Windows, macOS and Linux. It is being converted from [Hasten for VCL](../vcl/) in
steps, sharing every unit that does not depend on VCL (in [`../common/`](../common/)).

**Done**: files in tabs (New, Open, Save, Save As, Close; reopened next time), Run (F9), Build (Ctrl+F9),
Stop (Ctrl+F2) and Run Tests through `haste.py`, the output with a jump to the first error and a double-click
on any `file.haste:12`, and Haste colours with module names and aliases from `haste.py words`. Projects: New
Project (through `haste.py new`), Open, Recent, Save Project (Ctrl+Shift+S), Save Project As (rename, or copy
to another folder), Close, the Project Manager at the
right (Open, Open Project File, New Module, Rename with the uses changed, Delete, Look Again; the heading shows
the targets) and Project/Module Options (Ctrl+Shift+F11). Tools > Settings: the window's text size, the editor font and size, tab
width, the right margin, line numbers, Python, `haste.py`, clearing the output on each run, and reopening last
time's files. Tab puts in spaces to the next tab stop, or indents the selected lines; Shift+Tab takes them back
out (as SynEdit's eoTabsToSpaces in Hasten for VCL: FMX draws a tab character at the platform's own width, so
the editor never puts one in). On a Mac the shortcuts use Cmd.
Help Insight: rest the mouse on a name for its declaration, help comment and file:line, and after a Run or
Build the types it was compiled with (View > Help Insight turns it off).
Edit menu: Undo, Redo, Cut, Copy, Paste, Delete, Select All (on the editor or box with the focus, the output
too), Find (Ctrl+F: a bar above the editor with Match case and Whole word; Enter, F3 the next, Shift+Enter,
Shift+F3 the one before, wrapping round; Esc closes it) and Go to Line (Ctrl+G).
The toolbar: New, Open, Save; Undo, Redo, Cut, Copy, Paste; Find; Run, Build, Stop, Tests, Options; Settings,
each with its keys in its hint. On Windows the pictures are characters of Segoe MDL2 Assets; on macOS and Linux
the buttons show words.
Hasten for FMX now does what Hasten for VCL does, except VCL styles. Not in FMX: VCL styles.

## Build

1. Clone [FMXRichMemo](https://github.com/HemulGM/FMXRichMemo) (MIT), the editor control.
   **On Delphi 12**, apply the patch here inside that folder: `git apply path\to\FMXRichMemo-Delphi12.patch`.
   FMXRichMemo's README says Delphi 12+, but since February 2026 it uses Delphi 13's `not in` and an FMX method
   Delphi 12 lacks (`ShouldDrawLeftAndRightSelectionSides`). The patch writes `not (X in S)` and skips that one
   call before Delphi 13, which only drew the caret-coloured edges of a selection.
2. Open `HastenFMX.dpr` in Delphi and add the FMXRichMemo folder to the search path.
3. The style: Hasten loads the first `.style` file beside the program into `MainForm.StyleBook1`, which every
   Hasten window uses, or else the first in a `styles` folder above it: run from where Delphi builds it, that is
   `styles/HasteSlate.style`, Hasten's own (slate, steel-blue accent, 12 px text; vector shapes, no bitmaps).
   `styles/make_hasteslate.py` writes it: change the palette there and run it again. Keep `StyleBook1` empty in
   the designer; `.gitignore` leaves out every `.style` but HasteSlate.
4. Build for Windows 64-bit; then macOS and Linux (FMXLinux) if you have them. Hasten finds `haste.py` up to
   eight folders above the program, or asks (Run > Where is haste.py). Python is `python` on Windows and
   `python3` elsewhere; settings are in `HastenFMX.ini` in the Hasten folder of the user's home.

| File | |
|---|---|
| `HastenFMX.dpr` | The program |
| `Hasten.FMX.Main.pas`, `.fmx` | The main window, designed in the form designer: menus, toolbar, actions, find bar, tabs, output, Project Manager |
| `Hasten.FMX.Options.pas`, `.fmx` | Project/Module Options: build targets and switch values |
| `Hasten.FMX.Settings.pas`, `.fmx` | Tools > Settings |
| `Hasten.FMX.Editor.pas` | An editor tab: FMXRichMemo with Haste colours, line numbers, the current line, the right margin, Tab as spaces, and its own caret (FMX's is not seen over FMXRichMemo's painting) |
| `Syntax.Code.Haste.pas` | Haste colours for FMXRichMemo, the same as Hasten for VCL |
| `../common/Hasten.Runner.pas` | Runs `haste.py` and streams its output; Stop ends the whole process tree (shared with VCL) |
| `Hasten.FMX.Text.pas` | One text size for the window whatever the style (some draw everything at 16 px): Tools > Settings > Window, 12 px (9 pt) by default |
| `Hasten.FMX.Insight.pas` | Help Insight: watches the mouse and draws the tip |
| `../common/Hasten.Names.pas` | What each name is, from `haste.py words` and a build's `specialised:` line (shared with VCL) |
| `../common/Hasten.Project.pas` | Projects (`.hproj`), switches read from a program, module names and renames (shared with VCL) |
| `styles/HasteSlate.style`, `make_hasteslate.py` | Hasten's own style, and the script that writes it |
| `FMXRichMemo-Delphi12.patch` | Lets FMXRichMemo build with Delphi 12 |
