unit Hasten.FmxTest.Main;

{ A test of FMXRichMemo (github.com/HemulGM/FMXRichMemo) as Hasten's editor on FMX: Haste colours, line
  numbers, the current line, and timings for loading and for a 2000-line file. Built in code, like Hasten.
  What to try is in README.md. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Diagnostics, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Layouts, FMX.Memo, FMX.Memo.Types,
  FMX.ScrollBox, FMX.Controls.Presentation, FMX.Text, FMX.RichEdit.Style, Syntax.Code.Haste;

type
  { A memo always drawn by FMXRichMemo. Naming the presentation here, not in OnPresentationNameChoosing, works
    however early the memo makes it: a memo made in code can make it before an event could be assigned. }
  THasteMemo = class(TMemo)
  protected
    function DefinePresentationName: string; override;
  end;

  TTestForm = class(TForm)
  private
    FMemo: THasteMemo;
    FSetUpTimer: TTimer;
    FStatus: TLabel;
    FGutter: TCheckBox;
    function Rich: TRichEditStyled;
    function AddButton(Parent: TFmxObject; const Text: string; Click: TNotifyEvent): TButton;
    procedure SetUpWhenReady(Sender: TObject);
    procedure SetSyntax;
    procedure PaintBackground(Sender: TObject; ACanvas: TCanvas);
    procedure CaretMoved(Sender: TObject; const ACaretPosition: TCaretPosition);
    procedure OpenClick(Sender: TObject);
    procedure WordsClick(Sender: TObject);
    procedure StressClick(Sender: TObject);
    procedure GutterChange(Sender: TObject);
    procedure Status(const Text: string);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  TestForm: TTestForm;

implementation

const
{$IF Defined(MSWINDOWS)}
  MonoFont = 'Consolas';
{$ELSEIF Defined(MACOS)}
  MonoFont = 'Menlo';
{$ELSE}
  MonoFont = 'DejaVu Sans Mono';
{$ENDIF}
  Background = $FF1E1E1E;
  TextColor = $FFD4D4D4;
  SampleLines: array[0..26] of string = (
    '// Every kind of Haste token, to check the colours',
    'alias Bitmap = System.Bitmap',
    'alias Up = Text.Upper',
    '',
    'switch Width = 1_200 where it >= 16     // image width in pixels',
    'switch Name = "Mark"',
    '',
    'class Point',
    '  X = 0.0',
    '  Y: float = 0.5e-3',
    '  Label => Up("p{X}")',
    '  fn Moved(dx) = Point(X: X + dx, Y: self.Y)',
    'end',
    '',
    'fn Iterations(cx, cy, limit: int): int',
    '  var n = 0',
    '  while n < limit and cx * cy < 4 or not false',
    '    n = n + 0xFF shl 1 div 2 mod 7',
    '  end',
    '  return n',
    'end',
    '',
    'let names: [string] = ["a", "b\"c"]',
    'names.Add("d")',
    'print("{names.Count} names, {Iterations(0.5, 1.5, 256)} steps")',
    'img = Bitmap(Width: Width, Height: 600)',
    'Png.Save(img, "fractal.png")');

constructor TTestForm.Create(AOwner: TComponent);
var
  Bar: TLayout;
begin
  inherited CreateNew(AOwner);                  // no .fmx
  Caption := 'Hasten FMX editor test (FMXRichMemo)';
  Width := 1000;
  Height := 700;
  Fill.Kind := TBrushKind.Solid;
  Fill.Color := $FF2B2B2B;

  Bar := TLayout.Create(Self);
  Bar.Parent := Self;
  Bar.Align := TAlignLayout.Top;
  Bar.Height := 40;
  Bar.Padding.Rect := RectF(6, 6, 6, 6);
  AddButton(Bar, 'Open...', OpenClick);
  AddButton(Bar, 'Words...', WordsClick);
  AddButton(Bar, 'Stress: 2000 lines', StressClick);
  FGutter := TCheckBox.Create(Self);
  FGutter.Parent := Bar;
  FGutter.Align := TAlignLayout.Left;
  FGutter.Margins.Left := 12;
  FGutter.Width := 120;
  FGutter.Text := 'Line numbers';
  FGutter.IsChecked := True;
  FGutter.OnChange := GutterChange;

  FStatus := TLabel.Create(Self);
  FStatus.Parent := Self;
  FStatus.Align := TAlignLayout.Bottom;
  FStatus.Height := 24;
  FStatus.Margins.Rect := RectF(8, 0, 8, 2);
  FStatus.StyledSettings := FStatus.StyledSettings - [TStyledSetting.FontColor];
  FStatus.TextSettings.FontColor := TAlphaColors.Silver;

  FMemo := THasteMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := TAlignLayout.Client;
  FMemo.Margins.Rect := RectF(4, 0, 4, 0);
  FMemo.StyledSettings := FMemo.StyledSettings - [TStyledSetting.Family, TStyledSetting.Size,
    TStyledSetting.FontColor];
  FMemo.TextSettings.Font.Family := MonoFont;
  FMemo.TextSettings.Font.Size := 14;
  FMemo.TextSettings.FontColor := TextColor;
  FMemo.Lines.Text := string.Join(sLineBreak, SampleLines);

  FSetUpTimer := TTimer.Create(Self);           // the presentation appears once the form is on screen
  FSetUpTimer.Interval := 50;
  FSetUpTimer.OnTimer := SetUpWhenReady;
end;

function THasteMemo.DefinePresentationName: string;
begin
  Result := 'RichEditStyled';                   // registered by FMX.RichEdit.Style
end;

function TTestForm.AddButton(Parent: TFmxObject; const Text: string; Click: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := Parent;
  Result.Align := TAlignLayout.Left;
  Result.Margins.Right := 6;
  Result.Width := 130;
  Result.Text := Text;
  Result.OnClick := Click;
end;

function TTestForm.Rich: TRichEditStyled;
begin
  if FMemo.Presentation is TRichEditStyled then
    Result := TRichEditStyled(FMemo.Presentation)
  else
    Result := nil;
end;

procedure TTestForm.SetUpWhenReady(Sender: TObject);
begin
  if Rich = nil then
  begin
    FSetUpTimer.Tag := FSetUpTimer.Tag + 1;
    if FSetUpTimer.Tag >= 40 then               // two seconds: say what the memo is drawn by instead
    begin
      FSetUpTimer.Enabled := False;
      if FMemo.Presentation = nil then
        Status('The memo has no presentation yet.')
      else
        Status('The memo is drawn by ' + FMemo.Presentation.ClassName + ', not FMXRichMemo''s TRichEditStyled.');
    end;
    Exit;
  end;
  FSetUpTimer.Enabled := False;
  Rich.ShowGutter := True;
  Rich.ShowCurrentLine := True;
  Rich.ColorCurrentLine := $18FFFFFF;
  Rich.ColorLineNumberNormal := $FF808080;
  Rich.ColorLineNumberActive := TextColor;
  Rich.GutterFont.Family := MonoFont;
  Rich.GutterFont.Size := 13;
  Rich.OnDrawBefore := PaintBackground;
  Rich.OnChangeCaretPos := CaretMoved;
  SetSyntax;
  Status('Ready. Open a .haste file, load words.txt from "haste.py words", or try the stress test.');
end;

{ Also how new words take effect: the syntax is made again and every line is coloured afresh. }
procedure TTestForm.SetSyntax;
begin
  Rich.SetCodeSyntaxName('haste', FMemo.TextSettings.Font, TextColor);
  FMemo.Repaint;
end;

{ The colours are for a dark background, whatever the platform's light or dark style draws. }
procedure TTestForm.PaintBackground(Sender: TObject; ACanvas: TCanvas);
begin
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := Background;
  ACanvas.FillRect(RectF(-100000, -100000, 100000, 10000000), 0, 0, AllCorners, 1);
end;

procedure TTestForm.CaretMoved(Sender: TObject; const ACaretPosition: TCaretPosition);
begin
  Status(Format('Line %d, Col %d    %d lines', [ACaretPosition.Line + 1, ACaretPosition.Pos + 1,
    FMemo.Lines.Count]));
end;

procedure TTestForm.Status(const Text: string);
begin
  FStatus.Text := Text;
end;

procedure TTestForm.OpenClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  Watch: TStopwatch;
begin
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Filter := 'Haste files (*.haste)|*.haste|All files|*';
    if not Dialog.Execute then Exit;
    Watch := TStopwatch.StartNew;
    FMemo.Lines.LoadFromFile(Dialog.FileName, TEncoding.UTF8);
    Status(Format('%s: %d lines in %d ms', [ExtractFileName(Dialog.FileName), FMemo.Lines.Count,
      Watch.ElapsedMilliseconds]));
  finally
    Dialog.Free;
  end;
end;

{ words.txt: run   python haste.py words yourprogram.haste > words.txt   and load it here. }
procedure TTestForm.WordsClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  Lines: TStringList;
begin
  if Rich = nil then Exit;
  Dialog := TOpenDialog.Create(nil);
  Lines := TStringList.Create;
  try
    Dialog.Filter := 'Words (*.txt)|*.txt|All files|*';
    if not Dialog.Execute then Exit;
    Lines.LoadFromFile(Dialog.FileName, TEncoding.UTF8);
    TCodeSyntaxHaste.LoadWords(Lines);
    SetSyntax;
    Status(Format('%d names known', [TCodeSyntaxHaste.Words.Count]));
  finally
    Lines.Free;
    Dialog.Free;
  end;
end;

{ The text, repeated to 2000 lines or more: how long it takes to load, and to jump to the end. }
procedure TTestForm.StressClick(Sender: TObject);
var
  Base: string;
  Lines: TStringList;
  Watch: TStopwatch;
  Load, Jump: Int64;
begin
  Base := FMemo.Lines.Text;
  if Base.Trim = '' then Base := string.Join(sLineBreak, SampleLines) + sLineBreak;
  Lines := TStringList.Create;
  try
    while Lines.Count < 2000 do
      Lines.Text := Lines.Text + Base;
    Watch := TStopwatch.StartNew;
    FMemo.Lines.Text := Lines.Text;
    Load := Watch.ElapsedMilliseconds;
    Watch := TStopwatch.StartNew;
    FMemo.GoToTextEnd;
    FMemo.Repaint;
    Application.ProcessMessages;
    Jump := Watch.ElapsedMilliseconds;
    Status(Format('%d lines: loaded in %d ms, to the end in %d ms. Now type and scroll: is it smooth?',
      [FMemo.Lines.Count, Load, Jump]));
  finally
    Lines.Free;
  end;
end;

procedure TTestForm.GutterChange(Sender: TObject);
begin
  if Rich <> nil then
    Rich.ShowGutter := FGutter.IsChecked;
end;

end.
