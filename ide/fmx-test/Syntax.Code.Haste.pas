unit Syntax.Code.Haste;

{ Haste for FMXRichMemo: colours one line at a time, which suits Haste (no text or comment spans lines).
  The colours are those of Hasten's VCL highlighter (SynHighlighterHaste.msg), for a dark background.
  Keywords, types and the special names are fixed; built-ins, members and module names start with a
  default set and can be replaced by the output of "haste.py words" (LoadWords). }

interface

uses
  System.SysUtils, System.Classes, System.UITypes, System.Generics.Collections, FMX.Graphics, FMX.TextLayout,
  Syntax.Code;

type
  THasteToken = (htKey, htType, htSpecial, htBuiltin, htMember, htModule, htFunctionAlias, htString, htNumber,
    htComment, htSymbol);

  TCodeSyntaxHaste = class(TCodeSyntax)
  private
    class var FWords: TDictionary<string, THasteToken>;
    class procedure AddFixed;
    class procedure AddWords(const Names: array of string; Token: THasteToken);
  private
    FFonts: array[THasteToken] of TFont;
    function Attr(Token: THasteToken): TTextAttribute;
  public
    class constructor Create;
    class destructor Destroy;
    constructor Create(DefaultFont: TFont; DefaultColor: TAlphaColor); override;
    destructor Destroy; override;
    function GetAttributesForLine(const Line: string; const Index: Integer): TArray<TTextAttributedRangeData>; override;
    { Lines as "haste.py words" prints them: "module Math Png System ...", "builtin print Int ...", and so on. }
    class procedure LoadWords(Lines: TStrings);
    class property Words: TDictionary<string, THasteToken> read FWords;
  end;

const
  HasteColors: array[THasteToken] of TAlphaColor = (
    $FFFFFF00,     // keywords: yellow
    $FFD4D4D4,     // types: plain text
    $FFFF00FF,     // it, field, self: fuchsia
    $FFFF8080,     // built-ins
    $FF86A668,     // members
    $FF00FF00,     // modules, and type and class aliases: lime
    $FF4FC1FF,     // function aliases: sky blue
    $FFFF8000,     // text: orange
    $FF80FFFF,     // numbers
    $FF3EFF3E,     // comments (italic)
    $FF8080FF);    // symbols

implementation

const
  Keywords: array[0..32] of string = ('alias', 'and', 'catch', 'class', 'div', 'elif', 'else', 'end', 'extern',
    'false', 'fn', 'for', 'if', 'in', 'init', 'let', 'mod', 'need', 'not', 'or', 'parallel', 'return', 'shl',
    'shr', 'switch', 'then', 'true', 'try', 'var', 'where', 'while', 'write', 'xor');

class constructor TCodeSyntaxHaste.Create;
begin
  FWords := TDictionary<string, THasteToken>.Create;
  AddFixed;
  AddWords(['print', 'Int', 'Float', 'Str'], htBuiltin);
  AddWords(['Add', 'Count', 'Length', 'Has', 'Remove', 'Get', 'Insert', 'RemoveAt', 'IndexOf', 'Clear',
    'Reverse', 'Sort', 'Slice', 'Copy'], htMember);
  AddWords(['Math', 'Net', 'Png', 'System', 'Text', 'Time'], htModule);
end;

class destructor TCodeSyntaxHaste.Destroy;
begin
  FWords.Free;
end;

class procedure TCodeSyntaxHaste.AddWords(const Names: array of string; Token: THasteToken);
begin
  for var W in Names do
    FWords.AddOrSetValue(W, Token);
end;

class procedure TCodeSyntaxHaste.AddFixed;
begin
  AddWords(Keywords, htKey);
  AddWords(['int', 'float', 'string', 'bool'], htType);
  AddWords(['it', 'field', 'self'], htSpecial);
end;

class procedure TCodeSyntaxHaste.LoadWords(Lines: TStrings);
var
  Parts: TArray<string>;
  Kind: THasteToken;
begin
  FWords.Clear;
  AddFixed;
  for var Line in Lines do
  begin
    Parts := Line.Trim.Split([' '], TStringSplitOptions.ExcludeEmpty);
    if Length(Parts) < 2 then Continue;
    if Parts[0] = 'builtin' then Kind := htBuiltin
    else if Parts[0] = 'member' then Kind := htMember
    else if (Parts[0] = 'module') or (Parts[0] = 'type') then Kind := htModule
    else if Parts[0] = 'function' then Kind := htFunctionAlias
    else Continue;                              // keywords are fixed; insight lines are for Help Insight
    for var I := 1 to High(Parts) do
      FWords.AddOrSetValue(Parts[I], Kind);
  end;
end;

constructor TCodeSyntaxHaste.Create(DefaultFont: TFont; DefaultColor: TAlphaColor);
begin
  inherited;
  for var T := Low(THasteToken) to High(THasteToken) do
  begin
    FFonts[T] := TFont.Create;
    FFonts[T].Assign(DefaultFont);
  end;
  FFonts[htComment].Style := [TFontStyle.fsItalic];
end;

destructor TCodeSyntaxHaste.Destroy;
begin
  for var T := Low(THasteToken) to High(THasteToken) do
    FFonts[T].Free;
  inherited;
end;

function TCodeSyntaxHaste.Attr(Token: THasteToken): TTextAttribute;
begin
  Result := TTextAttribute.Create(FFonts[Token], HasteColors[Token]);
end;

{ Not cached: a line is coloured in one quick pass, and the memo asks only for the lines on screen. }
function TCodeSyntaxHaste.GetAttributesForLine(const Line: string; const Index: Integer): TArray<TTextAttributedRangeData>;
var
  I, J, N: Integer;
  C: Char;
  Word: string;
  Token: THasteToken;

  procedure Add(Start, Count: Integer; T: THasteToken);
  begin
    Result := Result + [TTextAttributedRangeData.Create(TTextRange.Create(Start, Count), Attr(T))];
  end;

  function IsIdent(Ch: Char; First: Boolean): Boolean;
  begin
    Result := CharInSet(Ch, ['A'..'Z', 'a'..'z', '_']) or (not First and CharInSet(Ch, ['0'..'9']));
  end;

begin
  Result := nil;
  N := Line.Length;
  I := 0;
  while I < N do
  begin
    C := Line.Chars[I];
    if (C = '/') and (I + 1 < N) and (Line.Chars[I + 1] = '/') then
    begin
      Add(I, N - I, htComment);                 // to the end of the line
      Exit;
    end
    else if C = '"' then
    begin
      J := I + 1;
      while (J < N) and (Line.Chars[J] <> '"') do
        if Line.Chars[J] = '\' then Inc(J, 2) else Inc(J);
      if J >= N then J := N - 1;                // unterminated: colour to the end
      Add(I, J - I + 1, htString);
      I := J + 1;
    end
    else if CharInSet(C, ['0'..'9']) then
    begin
      J := I;                                   // 255, 1_000, 0xFF, 0b1010, 2.5, 1e5, 2.5e-3
      while (J < N) and CharInSet(Line.Chars[J], ['0'..'9', 'a'..'z', 'A'..'Z', '_']) do Inc(J);
      if (J + 1 < N) and (Line.Chars[J] = '.') and CharInSet(Line.Chars[J + 1], ['0'..'9']) then
      begin
        Inc(J);
        while (J < N) and CharInSet(Line.Chars[J], ['0'..'9', 'e', 'E', '_']) do Inc(J);
      end;
      if (J < N) and CharInSet(Line.Chars[J], ['+', '-']) and CharInSet(Line.Chars[J - 1], ['e', 'E']) then
      begin
        Inc(J);
        while (J < N) and CharInSet(Line.Chars[J], ['0'..'9']) do Inc(J);
      end;
      Add(I, J - I, htNumber);
      I := J;
    end
    else if IsIdent(C, True) then
    begin
      J := I;
      while (J < N) and IsIdent(Line.Chars[J], J = I) do Inc(J);
      Word := Line.Substring(I, J - I);
      if FWords.TryGetValue(Word, Token) and (Token <> htType) then
        Add(I, J - I, Token);
      I := J;
    end
    else
    begin
      if CharInSet(C, ['=', '<', '>', '+', '-', '*', '/', '(', ')', '[', ']', '{', '}', ',', '.', ':']) then
        Add(I, 1, htSymbol);
      Inc(I);
    end;
  end;
end;

initialization
  TCodeSyntax.RegisterSyntax(['haste'], TCodeSyntaxHaste);

end.
