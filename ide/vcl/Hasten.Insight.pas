unit Hasten.Insight;

{ Help Insight: rest the mouse on a name in the editor and a tip shows what it is: its declaration, its help
  comment, where it is declared, and, once the program has been run or built, the types it was compiled
  with. Everything comes from haste.py: the "insight" lines of "haste.py words" (modules, functions, classes
  and their members, switches, aliases, built-ins, list members and keywords) and the "specialised:" line a
  build prints, kept by Hasten.Names (shared with Hasten for FMX). The IDE keeps no lists of its own.

  It watches the mouse with a timer rather than hooking every editor: a name under a still mouse for
  Delay milliseconds gets its tip, and the tip goes as soon as the mouse leaves the name or the text moves. }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, Vcl.Controls,
  Vcl.Forms, Vcl.ExtCtrls, SynEdit, SynEditTypes, SynEditHighlighter, SynHighlighterHaste, Hasten.Names;

type
  THasteInsight = class(TComponent)
  private
    FNames: THasteNames;
    FTimer: TTimer;
    FHint: THintWindow;
    FHighlighter: TSynHasteSyn;
    FEnabled: Boolean;
    FLastPos: TPoint;
    FStill: Integer;                            // timer ticks the mouse has not moved
    FShown: Boolean;
    FShownEditor: TSynEdit;
    FShownWord: string;
    FShownCaret: TBufferCoord;
    FShownTop: Integer;
    procedure TimerFire(Sender: TObject);
    function WordAt(E: TSynEdit; const ScreenPos: TPoint; out Start: TDisplayCoord): string;
    function GetDelay: Integer;
    procedure SetDelay(Value: Integer);
    procedure SetEnabled(Value: Boolean);
    function GetCount: Integer;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadWords(Lines: TStrings);         // the output of "haste.py words": insight lines are used
    procedure LoadCompiled(const Line: string);   // a build's "specialised: ..." line
    procedure Hide;
    function TextFor(const Word: string): string; // the tip for a name as written ("Text.Upper"), or ''
    property Highlighter: TSynHasteSyn read FHighlighter write FHighlighter;  // tips only in editors using it
    property Enabled: Boolean read FEnabled write SetEnabled;
    property Delay: Integer read GetDelay write SetDelay;    // milliseconds of stillness before a tip
    property Count: Integer read GetCount;                  // names known
  end;

implementation

const
  Tick = 100;                                   // ms between looks at the mouse

constructor THasteInsight.Create(AOwner: TComponent);
begin
  inherited;
  FNames := THasteNames.Create;
  FHint := THintWindow.Create(Self);
  FTimer := TTimer.Create(Self);
  FTimer.Interval := Tick;
  FTimer.OnTimer := TimerFire;
  FTimer.Tag := 600;                            // the delay, in ms
  FEnabled := True;
end;

destructor THasteInsight.Destroy;
begin
  FTimer.Enabled := False;
  FNames.Free;
  inherited;
end;

procedure THasteInsight.LoadWords(Lines: TStrings);
begin
  FNames.LoadWords(Lines);
end;

procedure THasteInsight.LoadCompiled(const Line: string);
begin
  FNames.LoadCompiled(Line);
end;

function THasteInsight.TextFor(const Word: string): string;
begin
  Result := FNames.TextFor(Word);
end;

{ The name under the mouse, with the dotted names before it: on "Upper" in Text.Upper(s) it is "Text.Upper",
  on "Text" just "Text". Nothing in comments and text, in the gutter, or past the end of a line. }
function THasteInsight.WordAt(E: TSynEdit; const ScreenPos: TPoint; out Start: TDisplayCoord): string;
var
  P: TPoint;
  DC: TDisplayCoord;
  BC: TBufferCoord;
  S, Token: string;
  L, R: Integer;
  Attri: TSynHighlighterAttributes;
begin
  Result := '';
  P := E.ScreenToClient(ScreenPos);
  DC := E.PixelsToRowColumn(P.X, P.Y);
  if (DC.Row < 1) or (P.X < E.RowColumnToPixels(DisplayCoord(1, DC.Row)).X) then Exit;
  BC := E.DisplayToBufferPos(DC);
  if (BC.Line < 1) or (BC.Line > E.Lines.Count) then Exit;
  S := E.Lines[BC.Line - 1];
  if (BC.Char < 1) or (BC.Char > Length(S)) or not IsNameChar(S[BC.Char]) then Exit;
  if E.GetHighlighterAttriAtRowCol(BC, Token, Attri) and (FHighlighter <> nil) and
    ((Attri = FHighlighter.CommentAttri) or (Attri = FHighlighter.StringAttri)) then Exit;
  L := BC.Char;
  while (L > 1) and (IsNameChar(S[L - 1]) or (S[L - 1] = '.')) do
    Dec(L);
  R := BC.Char;
  while (R < Length(S)) and IsNameChar(S[R + 1]) do
    Inc(R);
  Result := Copy(S, L, R - L + 1);
  Start := E.BufferToDisplayPos(BufferCoord(L, BC.Line));
end;

procedure THasteInsight.TimerFire(Sender: TObject);
var
  Pos, At: TPoint;
  C: TControl;
  E: TSynEdit;
  Word, Text: string;
  Start: TDisplayCoord;
  R: TRect;
begin
  Pos := Mouse.CursorPos;
  if not FEnabled or not Application.Active or (GetKeyState(VK_LBUTTON) < 0) then
  begin
    Hide;
    Exit;
  end;
  C := FindVCLWindow(Pos);
  if FShown then                                // keep the tip while the mouse stays on the name
  begin
    if (C <> FShownEditor) or (WordAt(FShownEditor, Pos, Start) <> FShownWord) or
      (FShownEditor.CaretX <> FShownCaret.Char) or (FShownEditor.CaretY <> FShownCaret.Line) or
      (FShownEditor.TopLine <> FShownTop) then
      Hide;
    Exit;
  end;
  if (Pos.X <> FLastPos.X) or (Pos.Y <> FLastPos.Y) then
  begin
    FLastPos := Pos;
    FStill := 0;
    Exit;
  end;
  Inc(FStill);
  if FStill * Tick <> FTimer.Tag then Exit;     // once per resting place
  if not (C is TSynEdit) or (TSynEdit(C).Highlighter <> FHighlighter) then Exit;
  E := TSynEdit(C);
  Word := WordAt(E, Pos, Start);
  Text := TextFor(Word);
  if Text = '' then Exit;
  At := E.RowColumnToPixels(Start);
  At := E.ClientToScreen(Point(At.X, At.Y + E.LineHeight + 2));
  R := FHint.CalcHintRect(Screen.Width div 2, Text, nil);
  OffsetRect(R, At.X, At.Y);
  if R.Bottom > Screen.WorkAreaRect.Bottom then  // no room below the line: above it
    OffsetRect(R, 0, -(R.Height + E.LineHeight + 4));
  FHint.ActivateHint(R, Text);
  FShown := True;
  FShownEditor := E;
  FShownWord := Word;
  FShownCaret := E.CaretXY;
  FShownTop := E.TopLine;
end;

procedure THasteInsight.Hide;
begin
  if FShown then
    FHint.ReleaseHandle;
  FShown := False;
  FShownEditor := nil;
end;

function THasteInsight.GetDelay: Integer;
begin
  Result := FTimer.Tag;
end;

procedure THasteInsight.SetDelay(Value: Integer);
begin
  if Value < Tick then Value := Tick;
  FTimer.Tag := Value div Tick * Tick;
end;

procedure THasteInsight.SetEnabled(Value: Boolean);
begin
  FEnabled := Value;
  if not Value then Hide;
end;

function THasteInsight.GetCount: Integer;
begin
  Result := FNames.Count;
end;

end.
