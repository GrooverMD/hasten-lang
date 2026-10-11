unit Hasten.Insight;

{ Help Insight: rest the mouse on a name in the editor and a tip shows what it is: its declaration, its help
  comment, where it is declared, and, once the program has been run or built, the types it was compiled
  with. Everything comes from haste.py: the "insight" lines of "haste.py words" (modules, functions, classes
  and their members, switches, aliases, built-ins, list members and keywords) and the "specialised:" line a
  build prints. The IDE keeps no lists of its own.

  It watches the mouse with a timer rather than hooking every editor: a name under a still mouse for
  Delay milliseconds gets its tip, and the tip goes as soon as the mouse leaves the name or the text moves. }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.Generics.Collections, Vcl.Controls,
  Vcl.Forms, Vcl.ExtCtrls, SynEdit, SynEditTypes, SynEditHighlighter, SynHighlighterHaste;

type
  TInsightEntry = record
    Name, Kind, Signature, Help, Place, Target: string;
  end;

  THasteInsight = class(TComponent)
  private
    FEntries: TDictionary<string, TInsightEntry>;
    FCompiled: TDictionary<string, string>;     // Name or Class.Method -> how a build compiled it
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
    function Describe(const E: TInsightEntry): string;
    function CompiledFor(const E: TInsightEntry): string;
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

function IsNameChar(C: Char): Boolean;
begin
  Result := CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

constructor THasteInsight.Create(AOwner: TComponent);
begin
  inherited;
  FEntries := TDictionary<string, TInsightEntry>.Create;
  FCompiled := TDictionary<string, string>.Create;
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
  FEntries.Free;
  FCompiled.Free;
  inherited;
end;

{ insight<TAB>name<TAB>kind<TAB>signature<TAB>help<TAB>place<TAB>target; line breaks in help come as \n. }
procedure THasteInsight.LoadWords(Lines: TStrings);
var
  Line: string;
  F: TArray<string>;
  E: TInsightEntry;
begin
  FEntries.Clear;
  for Line in Lines do
  begin
    if not Line.StartsWith('insight'#9) then Continue;
    F := Line.Split([#9]);
    if Length(F) < 7 then Continue;
    E.Name := F[1];
    E.Kind := F[2];
    E.Signature := F[3];
    E.Help := F[4].Replace('\n', sLineBreak);
    E.Place := F[5];
    E.Target := F[6];
    FEntries.AddOrSetValue(E.Name, E);
  end;
end;

{ "  specialised: Iterations(float, float, int) -> int, Bitmap.SetPixel(int, int, int) -> void, ...": split at
  the commas between entries, not those inside brackets. A function compiled for several types has several. }
procedure THasteInsight.LoadCompiled(const Line: string);
var
  S, Item, Key, Was: string;
  I, Depth, From: Integer;

  procedure Add(const Text: string);
  var
    P: Integer;
  begin
    Item := Text.Trim;
    P := Item.IndexOf('(');
    if P <= 0 then Exit;
    Key := Item.Substring(0, P);
    if FCompiled.TryGetValue(Key, Was) then
      FCompiled[Key] := Was + sLineBreak + Item
    else
      FCompiled.Add(Key, Item);
  end;

begin
  S := Line.Trim;
  if not S.StartsWith('specialised:') then Exit;
  FCompiled.Clear;
  S := S.Substring(Length('specialised:'));
  Depth := 0;
  From := 1;
  for I := 1 to Length(S) do
    case S[I] of
      '(', '[', '{': Inc(Depth);
      ')', ']', '}': Dec(Depth);
      ',': if Depth = 0 then
           begin
             Add(Copy(S, From, I - From));
             From := I + 1;
           end;
    end;
  Add(Copy(S, From, MaxInt));
end;

{ A method is compiled as Class.Method, anything else by its own name. }
function THasteInsight.CompiledFor(const E: TInsightEntry): string;
var
  Parts: TArray<string>;
  Key: string;
begin
  Result := '';
  Parts := E.Name.Split(['.']);
  if Length(Parts) = 0 then Exit;
  Key := Parts[High(Parts)];
  if (E.Kind = 'method') and (Length(Parts) >= 2) then
    Key := Parts[High(Parts) - 1] + '.' + Key
  else if E.Kind <> 'function' then
    Exit;
  FCompiled.TryGetValue(Key, Result);
end;

function THasteInsight.Describe(const E: TInsightEntry): string;
var
  Compiled: string;
begin
  Result := E.Signature;
  if E.Help <> '' then
    Result := Result + sLineBreak + sLineBreak + E.Help;
  Compiled := CompiledFor(E);
  if Compiled <> '' then
    Result := Result + sLineBreak + sLineBreak + 'Compiled as:' + sLineBreak + Compiled;
  if E.Place <> '' then
    Result := Result + sLineBreak + sLineBreak + E.Place;
end;

{ The name as written, e.g. "Text.Upper", "Bmp.Save" (an alias) or "img.SetPixel" (a member of something
  whose type only the compiler knows: every member of that name is shown). }
function THasteInsight.TextFor(const Word: string): string;
var
  W, Last: string;
  Parts: TArray<string>;
  E, A: TInsightEntry;
  Found: Integer;
begin
  Result := '';
  W := Word.Trim(['.']);
  if W = '' then Exit;
  Parts := W.Split(['.']);
  if FEntries.TryGetValue(Parts[0], A) and (A.Kind = 'alias') and (A.Target <> '') then
  begin
    if Length(Parts) = 1 then                   // the alias itself: it, then what it stands for
    begin
      Result := Describe(A);
      if FEntries.TryGetValue(A.Target, E) then
        Result := Result + sLineBreak + '--------' + sLineBreak + Describe(E);
      Exit;
    end;
    W := A.Target + W.Substring(Length(Parts[0]));
  end;
  if FEntries.TryGetValue(W, E) then
    Exit(Describe(E));
  if (Length(Parts) < 2) and not Word.StartsWith('.') then Exit;
  Last := Parts[High(Parts)];
  if FEntries.TryGetValue('.' + Last, E) then   // a list, dictionary or text member
    Result := Describe(E);
  Found := 0;
  for E in FEntries.Values do
    if ((E.Kind = 'method') or (E.Kind = 'property')) and E.Name.EndsWith('.' + Last) and (Found < 3) then
    begin
      if Result <> '' then Result := Result + sLineBreak + '--------' + sLineBreak;
      Result := Result + E.Name + sLineBreak + Describe(E);
      Inc(Found);
    end;
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
  Result := FEntries.Count;
end;

end.
