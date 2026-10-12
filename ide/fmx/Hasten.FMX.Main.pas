unit Hasten.FMX.Main;

{ Hasten for FireMonkey: the main window, designed in Hasten.FMX.Main.fmx. So far it is the editor: FMXRichMemo
  (github.com/HemulGM/FMXRichMemo) with Haste colours, line numbers and the current line, plus timings for
  loading and for a 2000-line file. What to try is in README.md. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Diagnostics, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Layouts, FMX.Memo, FMX.Memo.Types,
  FMX.ScrollBox, FMX.Controls.Presentation, FMX.Text, FMX.RichEdit.Style, Syntax.Code.Haste;

type
  TMainForm = class(TForm)
    Bar: TLayout;
    OpenButton: TButton;
    WordsButton: TButton;
    StressButton: TButton;
    GutterCheck: TCheckBox;
    StatusLabel: TLabel;
    Memo: TMemo;
    SetUpTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure MemoPresentationNameChoosing(Sender: TObject; var PresenterName: string);
    procedure MemoChangeTracking(Sender: TObject);
    procedure SetUpWhenReady(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure WordsClick(Sender: TObject);
    procedure StressClick(Sender: TObject);
    procedure GutterCheckChange(Sender: TObject);
  private
    function Rich: TRichEditStyled;
    procedure SetSyntax;
    procedure PaintEditorBackground(Sender: TObject; ACanvas: TCanvas);
    procedure CaretMoved(Sender: TObject; const ACaretPosition: TCaretPosition);
    procedure TextChanged(Sender: TObject);
    procedure Status(const Text: string);
  end;

var
  MainForm: TMainForm;

implementation

{$R *.fmx}

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

{ The editor's font is set here, not in the .fmx, because the monospaced font differs by platform. }
procedure TMainForm.FormCreate(Sender: TObject);
begin
  Memo.TextSettings.Font.Family := MonoFont;
  Memo.Lines.Text := string.Join(sLineBreak, SampleLines);
end;

{ FMXRichMemo draws the memo; FMX.RichEdit.Style registers this presentation. }
procedure TMainForm.MemoPresentationNameChoosing(Sender: TObject; var PresenterName: string);
begin
  PresenterName := 'RichEditStyled';
end;

function TMainForm.Rich: TRichEditStyled;
begin
  if Memo.Presentation is TRichEditStyled then
    Result := TRichEditStyled(Memo.Presentation)
  else
    Result := nil;
end;

procedure TMainForm.SetUpWhenReady(Sender: TObject);
begin
  if Rich = nil then
  begin
    SetUpTimer.Tag := SetUpTimer.Tag + 1;
    if SetUpTimer.Tag >= 40 then               // two seconds: say what the memo is drawn by instead
    begin
      SetUpTimer.Enabled := False;
      if Memo.Presentation = nil then
        Status('The memo has no presentation yet.')
      else
        Status('The memo is drawn by ' + Memo.Presentation.ClassName + ', not FMXRichMemo''s TRichEditStyled.');
    end;
    Exit;
  end;
  SetUpTimer.Enabled := False;
  Rich.ShowGutter := True;
  Rich.ShowCurrentLine := True;
  Rich.ColorCurrentLine := $18FFFFFF;
  Rich.ColorLineNumberNormal := $FF808080;
  Rich.ColorLineNumberActive := TextColor;
  Rich.GutterFont.Family := MonoFont;
  Rich.GutterFont.Size := 13;
  Rich.OnDrawBefore := PaintEditorBackground;
  Rich.OnChangeCaretPos := CaretMoved;
  SetSyntax;
  Status('Ready. Open a .haste file, load words.txt from "haste.py words", or try the stress test.');
end;

procedure TMainForm.SetSyntax;
begin
  TCodeSyntaxHaste.ScanAliases(Memo.Lines);
  Rich.SetCodeSyntaxName('haste', Memo.TextSettings.Font, TextColor);
  Memo.Repaint;
end;

procedure TMainForm.PaintEditorBackground(Sender: TObject; ACanvas: TCanvas);
begin
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := Background;
  ACanvas.FillRect(RectF(-100000, -100000, 100000, 10000000), 0, 0, AllCorners, 1);
end;

procedure TMainForm.CaretMoved(Sender: TObject; const ACaretPosition: TCaretPosition);
begin
  Status(Format('Line %d, Col %d    %d lines', [ACaretPosition.Line + 1, ACaretPosition.Pos + 1,
    Memo.Lines.Count]));
end;

procedure TMainForm.Status(const Text: string);
begin
  StatusLabel.Text := Text;
end;

procedure TMainForm.OpenClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  Watch: TStopwatch;
begin
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Filter := 'Haste files (*.haste)|*.haste|All files|*';
    if not Dialog.Execute then Exit;
    Watch := TStopwatch.StartNew;
    Memo.Lines.LoadFromFile(Dialog.FileName, TEncoding.UTF8);
    TextChanged(nil);
    Status(Format('%s: %d lines in %d ms', [ExtractFileName(Dialog.FileName), Memo.Lines.Count,
      Watch.ElapsedMilliseconds]));
  finally
    Dialog.Free;
  end;
end;

procedure TMainForm.WordsClick(Sender: TObject);
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

procedure TMainForm.StressClick(Sender: TObject);
var
  Base: string;
  Lines: TStringList;
  Watch: TStopwatch;
  Load, Jump: Int64;
begin
  Base := Memo.Lines.Text;
  if Base.Trim = '' then Base := string.Join(sLineBreak, SampleLines) + sLineBreak;
  Lines := TStringList.Create;
  try
    while Lines.Count < 2000 do
      Lines.Text := Lines.Text + Base;
    Watch := TStopwatch.StartNew;
    Memo.Lines.Text := Lines.Text;
    TextChanged(nil);
    Load := Watch.ElapsedMilliseconds;
    Watch := TStopwatch.StartNew;
    Memo.GoToTextEnd;
    Memo.Repaint;
    Application.ProcessMessages;
    Jump := Watch.ElapsedMilliseconds;
    Status(Format('%d lines: loaded in %d ms, to the end in %d ms. Now type and scroll: is it smooth?',
      [Memo.Lines.Count, Load, Jump]));
  finally
    Lines.Free;
  end;
end;

{ Every edit: an alias added or changed recolours the text. }
procedure TMainForm.MemoChangeTracking(Sender: TObject);
begin
  TextChanged(Sender);
end;

procedure TMainForm.TextChanged(Sender: TObject);
begin
  if (Rich <> nil) and TCodeSyntaxHaste.ScanAliases(Memo.Lines) then
    SetSyntax;
end;

procedure TMainForm.GutterCheckChange(Sender: TObject);
begin
  if Rich <> nil then
    Rich.ShowGutter := GutterCheck.IsChecked;
end;

end.
