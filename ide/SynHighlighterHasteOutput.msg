TSynHasteOutputSyn  {first identifier is the class name}
tko                 {second identifier is the token prefix}
{ Highlighter for Hasten's output panel. Whole lines are coloured by how they start: the command, Haste's
  own two-space-indented reports, errors, passing tests, the test summary and the end-of-run line.
  Everything else is the program's own output and keeps the plain colour. Colours are $00BBGGRR, for the
  same dark background as the editor. }
Sensitive
IdentStart '_', 'a'..'z', 'A'..'Z':: '_', '0'..'9', 'a'..'z', 'A'..'Z'::

TOKENTYPES
Identifier
Command Style=[fsBold]|Foreground=$00FFAA6E
Info Foreground=$00808080
Error Style=[fsBold]|Foreground=$006060FF
Success Foreground=$0062D662
Status Foreground=$005AC8E6
|><|

KEYS Status
passed
failed
|><|

CHARS

'A'..'Z', 'a'..'z', '_':: Word
BeginProc
  if (Run = 0) and ((StrLComp(fLine, 'error:', 6) = 0) or (StrLComp(fLine, 'Unhandled error', 15) = 0)
    or (StrLComp(fLine, 'FAIL', 4) = 0) or (StrLComp(fLine, 'Cannot start', 12) = 0)
    or (StrLComp(fLine, 'Python could not', 16) = 0)) then
  begin
    fTokenID := tkoError;
    repeat
      Inc(Run);
    until IsLineEnd(Run);
  end
  else if (Run = 0) and (StrLComp(fLine, 'ok ', 3) = 0) then
  begin
    fTokenID := tkoSuccess;
    repeat
      Inc(Run);
    until IsLineEnd(Run);
  end
  else
  begin
    fTokenID := IdentKind(fLine + Run);
    Inc(Run, fStringLen);
    while IsIdentChar(fLine[Run]) do
      Inc(Run);
  end;
EndProc

'0'..'9':: Digits
BeginProc
  if (Run = 0) and (StrPos(fLine, ' passed, ') <> nil) then
  begin
    if StrPos(fLine, ' 0 failed') <> nil then
      fTokenID := tkoSuccess
    else
      fTokenID := tkoError;
    repeat
      Inc(Run);
    until IsLineEnd(Run);
  end
  else
  begin
    fTokenID := tkoIdentifier;
    while CharInSet(fLine[Run], ['0'..'9']) do
      Inc(Run);
  end;
EndProc

'>':: Command
BeginProc
  if Run = 0 then
  begin
    fTokenID := tkoCommand;
    repeat
      Inc(Run);
    until IsLineEnd(Run);
  end
  else
  begin
    fTokenID := tkoIdentifier;
    Inc(Run);
  end;
EndProc

'[':: Bracket
BeginProc
  if (Run = 0) and ((StrLComp(fLine, '[finished', 9) = 0) or (StrLComp(fLine, '[stopped', 8) = 0)) then
  begin
    fTokenID := tkoStatus;
    repeat
      Inc(Run);
    until IsLineEnd(Run);
  end
  else
  begin
    fTokenID := tkoIdentifier;
    Inc(Run);
  end;
EndProc

#9, #32:: Blank
BeginProc
  if (Run = 0) and (StrPos(fLine, 'error:') <> nil) then
  begin
    fTokenID := tkoError;
    repeat
      Inc(Run);
    until IsLineEnd(Run);
  end
  else if (Run = 0) and (fLine[0] = ' ') and (fLine[1] = ' ') and (StrLComp(fLine + 2, 'in ', 3) = 0) then
  begin
    fTokenID := tkoError;
    repeat
      Inc(Run);
    until IsLineEnd(Run);
  end
  else if (Run = 0) and (fLine[0] = ' ') and (fLine[1] = ' ')
    and CharInSet(fLine[2], ['A'..'Z', 'a'..'z', '-']) then
  begin
    fTokenID := tkoInfo;
    repeat
      Inc(Run);
    until IsLineEnd(Run);
  end
  else
  begin
    fTokenID := tkoIdentifier;
    while CharInSet(fLine[Run], [#9, ' ']) do
      Inc(Run);
  end;
EndProc

|><|

SAMPLESOURCE
> python C:\Haste\haste.py run C:\Haste\examples\fractal.haste
  Python  3.15.0  C:\Python315\python.exe
  Zig     0.16.0  C:\Haste\tools\zig\zig.exe
  compiling for windows...
  built build\fractal.exe  (85 KB)
  ----
Rendered 1200 x 800 to fractal.bmp in 0.26 seconds
error: fractal.haste:12: '+' needs numbers, got int and string
  in Shade, called from fractal.haste:30
ok    language\print.haste  (2.1s)
FAIL  language\lists.haste
51 passed, 0 failed, 51 tests in 16.1 seconds
[finished, exit code 0]
|><|
