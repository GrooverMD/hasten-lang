unit Hasten.FMX.Editor;

{ An editor tab: a memo drawn by FMXRichMemo (github.com/HemulGM/FMXRichMemo) with Haste colours, line numbers,
  the current line, a right margin and a caret drawn here, on a dark background whatever the platform's style. The memo's
  presentation is made some time after the tab; Configure is called until it says it is ready.

  Tab width works as in Hasten for VCL (SynEdit's eoTabsToSpaces): Tab puts in spaces to the next tab stop,
  or indents the selected lines; Shift+Tab takes them back out. FMX draws a tab character at the platform's
  own width, so the editor never puts one in. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, FMX.Types, FMX.Controls, FMX.Graphics,
  FMX.TabControl, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.Controls.Presentation, FMX.Text,
  FMX.Text.TextEditor, FMX.Text.LinesLayout, FMX.RichEdit.Style, Syntax.Code.Haste;

type
  { A memo always drawn by FMXRichMemo: one made in code may choose its presentation before an
    OnPresentationNameChoosing event could be assigned, so the name is given here. }
  THasteMemo = class(TMemo)
  private
    FTabWidth: Integer;
    procedure SelectedLines(out First, Last: Integer);
    procedure Indent;
    procedure Outdent;
    procedure SelectLines(First, Last: Integer);
  protected
    function DefinePresentationName: string; override;
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    function TabKey(var Key: Word; var KeyChar: WideChar; Shift: TShiftState): Boolean;   // True: taken
    property TabWidth: Integer read FTabWidth write FTabWidth;    // spaces to a tab stop
  end;

  TEditorTab = class(TTabItem)
  private
    FMemo: THasteMemo;
    FFileName: string;
    FModified: Boolean;
    FReady: Boolean;
    FLoading: Boolean;
    FLineNumbers: Boolean;
    FRightEdge: Integer;
    FOnChange: TNotifyEvent;
    FOnCaret: TCaretPositionChanged;
    FBlink: TTimer;
    FCaretOn: Boolean;                           // the drawn caret's half of its blink
    procedure MemoChange(Sender: TObject);
    procedure PaintBackground(Sender: TObject; ACanvas: TCanvas);
    procedure PaintAfter(Sender: TObject; ACanvas: TCanvas);
    procedure PaintMargin(ACanvas: TCanvas);
    procedure PaintCaret(ACanvas: TCanvas);
    procedure BlinkTimer(Sender: TObject);
    procedure CaretChanged(Sender: TObject; const ACaretPosition: TCaretPosition);
    function GetTabWidth: Integer;
    procedure SetTabWidth(Value: Integer);
    procedure SetRightEdge(Value: Integer);
    procedure SetFileName(const Value: string);
    procedure SetModified(Value: Boolean);
    function GetTitle: string;
    function GetRich: TRichEditStyled;
    procedure UpdateText;
    function GetFontFamily: string;
    procedure SetFontFamily(const Value: string);
    function GetFontSize: Single;
    procedure SetFontSize(Value: Single);
    procedure SetLineNumbers(Value: Boolean);
    procedure FontChanged;
  public
    constructor Create(AOwner: TComponent); override;
    function Configure: Boolean;                 // True once the presentation exists and is set up
    procedure Recolour;                          // after new words or aliases
    procedure Load(const Path: string);
    procedure Save(const Path: string);
    procedure GoToLine(Line: Integer);
    property Memo: THasteMemo read FMemo;
    property Rich: TRichEditStyled read GetRich;  // nil until the presentation exists
    property FileName: string read FFileName write SetFileName;
    property Modified: Boolean read FModified write SetModified;
    property Title: string read GetTitle;
    property Ready: Boolean read FReady;
    property FontFamily: string read GetFontFamily write SetFontFamily;
    property FontSize: Single read GetFontSize write SetFontSize;
    property LineNumbers: Boolean read FLineNumbers write SetLineNumbers;
    property TabWidth: Integer read GetTabWidth write SetTabWidth;
    property RightEdge: Integer read FRightEdge write SetRightEdge;    // the margin's column; 0 for none
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnCaret: TCaretPositionChanged read FOnCaret write FOnCaret;
  end;

const
{$IF Defined(MSWINDOWS)}
  MonoFont = 'Consolas';
{$ELSEIF Defined(MACOS)}
  MonoFont = 'Menlo';
{$ELSE}
  MonoFont = 'DejaVu Sans Mono';
{$ENDIF}
  EditorBackground = $FF1E1E1E;
  EditorText = $FFD4D4D4;
  MarginColour = $30FFFFFF;

implementation

uses
  System.Math;

type
  TRichEditAccess = class(TRichEditStyled);    // to reach Editor, where the lines are laid out

{ ---- THasteMemo ---- }

constructor THasteMemo.Create(AOwner: TComponent);
begin
  inherited;
  FTabWidth := 2;
end;

function THasteMemo.DefinePresentationName: string;
begin
  Result := 'RichEditStyled';                  // registered by FMX.RichEdit.Style
end;

{ Tab comes as a key (vkTab) and then as a character (#9); both are taken, so neither a tab character nor a
  move to the next control happens. The form sees keys before the memo does and moves the focus on Tab, so
  its OnKeyDown calls this first; KeyDown is here for a memo on a form that does not. }
function THasteMemo.TabKey(var Key: Word; var KeyChar: WideChar; Shift: TShiftState): Boolean;
begin
  Result := False;
  if (FTabWidth = 0) or ReadOnly or (Shift * [ssCtrl, ssAlt, ssCommand] <> []) then Exit;
  if Key = vkTab then
  begin
    if ssShift in Shift then Outdent else Indent;
    Result := True;
  end
  else if (Key = 0) and (KeyChar = #9) then
    Result := True;
  if Result then
  begin
    Key := 0;
    KeyChar := #0;
  end;
end;

procedure THasteMemo.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  if not TabKey(Key, KeyChar, Shift) then
    inherited;
end;

{ The lines the selection covers; one that it only reaches the start of is not counted. }
procedure THasteMemo.SelectedLines(out First, Last: Integer);
var
  Stop: TCaretPosition;
begin
  First := TextPosToPos(SelStart).Line;
  Stop := TextPosToPos(SelStart + SelLength);
  Last := Stop.Line;
  if (Last > First) and (Stop.Pos = 0) then Dec(Last);
end;

procedure THasteMemo.SelectLines(First, Last: Integer);
begin
  SelStart := PosToTextPos(TCaretPosition.Create(First, 0));
  SelLength := PosToTextPos(TCaretPosition.Create(Last, Lines[Last].Length)) - SelStart;
end;

procedure THasteMemo.Indent;
var
  First, Last, I: Integer;
  Spaces: string;
begin
  SelectedLines(First, Last);
  if Last > First then                          // a block: each line moves one tab stop right
  begin
    Spaces := StringOfChar(' ', FTabWidth);
    for I := First to Last do
      if Lines[I] <> '' then
        InsertAfter(TCaretPosition.Create(I, 0), Spaces, [TInsertOption.CanUndo]);
    SelectLines(First, Last);
    Exit;
  end;
  if SelLength > 0 then                         // part of a line: the spaces take its place
    DeleteFrom(TextPosToPos(SelStart), SelLength, [TDeleteOption.MoveCaret, TDeleteOption.CanUndo]);
  InsertAfter(CaretPosition, StringOfChar(' ', FTabWidth - CaretPosition.Pos mod FTabWidth),
    [TInsertOption.MoveCaret, TInsertOption.CanUndo]);
end;

{ Each line back to the tab stop before its text, as far as it has spaces to lose. }
procedure THasteMemo.Outdent;
var
  First, Last, I, Lead, Cut: Integer;
  Caret: TCaretPosition;
  Block: Boolean;
begin
  SelectedLines(First, Last);
  Block := SelLength > 0;
  Caret := CaretPosition;
  for I := First to Last do
  begin
    Lead := Length(Lines[I]) - Length(Lines[I].TrimLeft);
    if Lead = 0 then Continue;
    Cut := Lead mod FTabWidth;
    if Cut = 0 then Cut := FTabWidth;
    DeleteFrom(TCaretPosition.Create(I, 0), Min(Cut, Lead), [TDeleteOption.CanUndo]);
    if I = Caret.Line then Caret.Pos := Max(0, Caret.Pos - Min(Cut, Lead));
  end;
  if Block then
    SelectLines(First, Last)
  else
    CaretPosition := Caret;
end;

{ ---- TEditorTab ---- }

constructor TEditorTab.Create(AOwner: TComponent);
begin
  inherited;
  FMemo := THasteMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := TAlignLayout.Client;
  FMemo.StyledSettings := FMemo.StyledSettings - [TStyledSetting.Family, TStyledSetting.Size,
    TStyledSetting.FontColor];
  FMemo.TextSettings.Font.Family := MonoFont;
  FMemo.TextSettings.Font.Size := 14;
  FMemo.TextSettings.FontColor := EditorText;
  FMemo.Caret.Visible := False;                // FMX's caret is not seen over FMXRichMemo's painting: PaintCaret
  FBlink := TTimer.Create(Self);
  FBlink.Enabled := False;
  FBlink.Interval := 530;
  FBlink.OnTimer := BlinkTimer;
  FMemo.OnChangeTracking := MemoChange;
  FLineNumbers := True;
  UpdateText;
end;

function TEditorTab.GetRich: TRichEditStyled;
begin
  if FMemo.Presentation is TRichEditStyled then
    Result := TRichEditStyled(FMemo.Presentation)
  else
    Result := nil;
end;

function TEditorTab.Configure: Boolean;
begin
  if FReady then Exit(True);
  if Rich = nil then Exit(False);
  Rich.ShowGutter := FLineNumbers;
  Rich.ShowCurrentLine := True;
  Rich.ColorCurrentLine := $18FFFFFF;
  Rich.ColorLineNumberNormal := $FF808080;
  Rich.ColorLineNumberActive := EditorText;
  Rich.OnDrawBefore := PaintBackground;
  Rich.OnDrawAfter := PaintAfter;
  Rich.OnChangeCaretPos := CaretChanged;
  FCaretOn := True;
  FBlink.Enabled := True;
  FReady := True;
  FontChanged;
  Result := True;
end;

{ The syntax is made again, so every line is coloured afresh. }
procedure TEditorTab.Recolour;
begin
  if not FReady then Exit;
  Rich.SetCodeSyntaxName('haste', FMemo.TextSettings.Font, EditorText);
  FMemo.Repaint;
end;

function TEditorTab.GetFontFamily: string;
begin
  Result := FMemo.TextSettings.Font.Family;
end;

procedure TEditorTab.SetFontFamily(const Value: string);
begin
  if (Value = '') or (Value = FontFamily) then Exit;
  FMemo.TextSettings.Font.Family := Value;
  FontChanged;
end;

function TEditorTab.GetFontSize: Single;
begin
  Result := FMemo.TextSettings.Font.Size;
end;

procedure TEditorTab.SetFontSize(Value: Single);
begin
  if (Value < 6) or (Value = FontSize) then Exit;
  FMemo.TextSettings.Font.Size := Value;
  FontChanged;
end;

procedure TEditorTab.SetLineNumbers(Value: Boolean);
begin
  FLineNumbers := Value;
  if FReady then Rich.ShowGutter := Value;
end;

{ The line numbers follow the editor's font, a point smaller; the colours are made again in the new font. }
procedure TEditorTab.FontChanged;
begin
  if not FReady then Exit;
  Rich.GutterFont.Family := FontFamily;
  Rich.GutterFont.Size := FontSize - 1;
  Recolour;
end;

function TEditorTab.GetTabWidth: Integer;
begin
  Result := FMemo.TabWidth;
end;

procedure TEditorTab.SetTabWidth(Value: Integer);
begin
  FMemo.TabWidth := EnsureRange(Value, 1, 16);
end;

procedure TEditorTab.SetRightEdge(Value: Integer);
begin
  Value := EnsureRange(Value, 0, 1000);
  if Value = FRightEdge then Exit;
  FRightEdge := Value;
  FMemo.Repaint;
end;

procedure TEditorTab.PaintAfter(Sender: TObject; ACanvas: TCanvas);
begin
  if not FReady then Exit;
  PaintMargin(ACanvas);
  PaintCaret(ACanvas);
end;

{ A line down the editor at column RightEdge, measured from where the visible lines' text starts (so it moves
  with horizontal scrolling) in the editor's fixed-pitch font. }
procedure TEditorTab.PaintMargin(ACanvas: TCanvas);
var
  Layout: TLinesLayout;
  Line: Integer;
  X: Single;
begin
  if FRightEdge = 0 then Exit;
  Layout := TRichEditAccess(Rich).Editor.LinesLayout;
  Line := Max(0, Layout.FirstVisibleLineIndex);
  if (Line >= Layout.Count) or Layout[Line].IsInvalidPosition then Exit;
  ACanvas.Font.Assign(FMemo.TextSettings.Font);
  X := Layout[Line].Rect.Left + FRightEdge * ACanvas.TextWidth('0000000000') / 10;
  ACanvas.Stroke.Kind := TBrushKind.Solid;
  ACanvas.Stroke.Color := MarginColour;
  ACanvas.Stroke.Thickness := 1;
  ACanvas.DrawLine(PointF(Round(X) + 0.5, -100000), PointF(Round(X) + 0.5, 10000000), 1);
end;

{ The caret, drawn here: a bar 2 pixels wide in the text colour, after the text before it on its line,
  blinking while the editor has the focus. }
procedure TEditorTab.PaintCaret(ACanvas: TCanvas);
var
  Layout: TLinesLayout;
  P: TCaretPosition;
  Top, X: Single;
begin
  if not FCaretOn or not FMemo.IsFocused then Exit;
  Layout := TRichEditAccess(Rich).Editor.LinesLayout;
  P := FMemo.CaretPosition;
  if (P.Line < 0) or (P.Line >= Layout.Count) or Layout[P.Line].IsInvalidPosition then Exit;
  Top := Layout[P.Line].Rect.Top;
  X := Layout[P.Line].Rect.Left;
  if P.Pos > 0 then
  begin
    var Region := Layout.GetRegionForRange(TCaretPosition.Create(P.Line, 0), P.Pos);
    if Length(Region) > 0 then X := Region[High(Region)].Right;
  end;
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := EditorText;
  ACanvas.FillRect(RectF(Round(X), Top, Round(X) + 2, Top + Layout[P.Line].Size.Height), 0, 0, AllCorners, 1);
end;

procedure TEditorTab.BlinkTimer(Sender: TObject);
begin
  FCaretOn := not FCaretOn;
  if FMemo.IsFocused then FMemo.Repaint;
end;

{ A moved caret shows at once and starts its blink again. }
procedure TEditorTab.CaretChanged(Sender: TObject; const ACaretPosition: TCaretPosition);
begin
  FCaretOn := True;
  FBlink.Enabled := False;
  FBlink.Enabled := True;
  if Assigned(FOnCaret) then FOnCaret(Sender, ACaretPosition);
end;

procedure TEditorTab.PaintBackground(Sender: TObject; ACanvas: TCanvas);
begin
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := EditorBackground;
  ACanvas.FillRect(RectF(-100000, -100000, 100000, 10000000), 0, 0, AllCorners, 1);
end;

procedure TEditorTab.MemoChange(Sender: TObject);
begin
  if FLoading then Exit;
  Modified := True;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TEditorTab.Load(const Path: string);
begin
  FLoading := True;
  try
    FMemo.Lines.LoadFromFile(Path, TEncoding.UTF8);
  finally
    FLoading := False;
  end;
  FileName := Path;
  Modified := False;
end;

procedure TEditorTab.Save(const Path: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Assign(FMemo.Lines);
    Lines.WriteBOM := False;                   // haste.py reads plain UTF-8
    Lines.SaveToFile(Path, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
  FileName := Path;
  Modified := False;
end;

procedure TEditorTab.GoToLine(Line: Integer);
begin
  if (Line < 1) or (Line > FMemo.Lines.Count) then Exit;
  FMemo.CaretPosition := TCaretPosition.Create(Line - 1, 0);
  if FMemo.CanFocus then FMemo.SetFocus;
end;

procedure TEditorTab.SetFileName(const Value: string);
begin
  FFileName := Value;
  UpdateText;
end;

procedure TEditorTab.SetModified(Value: Boolean);
begin
  if FModified = Value then Exit;
  FModified := Value;
  UpdateText;
end;

function TEditorTab.GetTitle: string;
begin
  if FFileName <> '' then Result := ExtractFileName(FFileName) else Result := 'Untitled';
end;

procedure TEditorTab.UpdateText;
begin
  if FModified then Text := Title + '*' else Text := Title;
end;

end.
