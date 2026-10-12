unit Hasten.Names;

{ What haste.py says about each name, for Help Insight in Hasten for VCL and for FMX: the "insight" lines of
  "haste.py words" (modules, functions, classes and their members, switches, aliases, built-ins, list members
  and keywords) and the "specialised:" line a build prints (the types each function was compiled with). The
  IDEs keep no lists of their own. Nothing here is VCL or FMX: the IDEs find the name under the mouse and
  show the tip. }

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections;

type
  TInsightEntry = record
    Name, Kind, Signature, Help, Place, Target: string;
  end;

  THasteNames = class
  private
    FEntries: TDictionary<string, TInsightEntry>;
    FCompiled: TDictionary<string, string>;     // Name or Class.Method -> how a build compiled it
    function Describe(const E: TInsightEntry): string;
    function CompiledFor(const E: TInsightEntry): string;
    function GetCount: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadWords(Lines: TStrings);         // the output of "haste.py words": insight lines are used
    procedure LoadCompiled(const Line: string);   // a build's "specialised: ..." line
    function TextFor(const Word: string): string; // the tip for a name as written ("Text.Upper"), or ''
    property Count: Integer read GetCount;        // names known
  end;

function IsNameChar(C: Char): Boolean;

{ The name at Col (1-based) in Line, with the dotted names before it: on "Upper" in Text.Upper(s) it is
  "Text.Upper", on "Text" just "Text"; Start is where it begins. '' in a comment or text, or off a name. }
function NameAt(const Line: string; Col: Integer; out Start: Integer): string;

implementation

function IsNameChar(C: Char): Boolean;
begin
  Result := CharInSet(C, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function NameAt(const Line: string; Col: Integer; out Start: Integer): string;
var
  I, R: Integer;
  InText: Boolean;
begin
  Result := '';
  Start := 0;
  if (Col < 1) or (Col > Length(Line)) or not IsNameChar(Line[Col]) then Exit;
  InText := False;                              // "text" (with \ escapes) and // comments, as haste.py lexes
  I := 1;
  while I < Col do
  begin
    if InText then
    begin
      if Line[I] = '\' then Inc(I)
      else if Line[I] = '"' then InText := False;
    end
    else if Line[I] = '"' then
      InText := True
    else if (Line[I] = '/') and (I < Length(Line)) and (Line[I + 1] = '/') then
      Exit;
    Inc(I);
  end;
  if InText then Exit;
  Start := Col;
  while (Start > 1) and (IsNameChar(Line[Start - 1]) or (Line[Start - 1] = '.')) do
    Dec(Start);
  R := Col;
  while (R < Length(Line)) and IsNameChar(Line[R + 1]) do
    Inc(R);
  Result := Copy(Line, Start, R - Start + 1);
end;

constructor THasteNames.Create;
begin
  inherited;
  FEntries := TDictionary<string, TInsightEntry>.Create;
  FCompiled := TDictionary<string, string>.Create;
end;

destructor THasteNames.Destroy;
begin
  FEntries.Free;
  FCompiled.Free;
  inherited;
end;

{ insight<TAB>name<TAB>kind<TAB>signature<TAB>help<TAB>place<TAB>target; line breaks in help come as \n. }
procedure THasteNames.LoadWords(Lines: TStrings);
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
procedure THasteNames.LoadCompiled(const Line: string);
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
function THasteNames.CompiledFor(const E: TInsightEntry): string;
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

function THasteNames.Describe(const E: TInsightEntry): string;
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
function THasteNames.TextFor(const Word: string): string;
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

function THasteNames.GetCount: Integer;
begin
  Result := FEntries.Count;
end;

end.
