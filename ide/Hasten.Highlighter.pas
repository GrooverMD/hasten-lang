unit Hasten.Highlighter;

{ The highlighter Hasten uses: the one SynGen generates from SynHighlighterHaste.msg, plus names that change
  without the .msg changing. Built-ins, list and dictionary members, module names and the open file's
  aliases come from "haste.py words", so a new module in lib (or next to the program) is coloured as soon
  as it exists, and module, type and class aliases are coloured like modules.
  The generated unit is never edited by hand. }

interface

uses
  System.Classes, System.SysUtils, System.Generics.Collections, SynEditHighlighter, SynHighlighterHaste;

type
  THasteHighlighter = class(TSynHasteSyn)
  private
    FWords: TDictionary<string, TSynHighlighterAttributes>;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Lines as printed by "haste.py words": a kind, then names, e.g. "module Math System Text". }
    procedure LoadWords(Lines: TStrings);
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    property Words: TDictionary<string, TSynHighlighterAttributes> read FWords;
  end;

implementation

constructor THasteHighlighter.Create(AOwner: TComponent);
begin
  inherited;
  FWords := TDictionary<string, TSynHighlighterAttributes>.Create;
end;

destructor THasteHighlighter.Destroy;
begin
  FWords.Free;
  inherited;
end;

procedure THasteHighlighter.LoadWords(Lines: TStrings);
var
  Line, Name: string;
  Parts: TArray<string>;
  Attr: TSynHighlighterAttributes;
  I: Integer;
begin
  FWords.Clear;
  for Line in Lines do
  begin
    Parts := Line.Trim.Split([' '], TStringSplitOptions.ExcludeEmpty);
    if Length(Parts) < 2 then Continue;
    if Parts[0] = 'builtin' then Attr := BuiltinAttri
    else if Parts[0] = 'member' then Attr := MemberAttri
    else if Parts[0] = 'module' then Attr := ModuleAttri
    else if Parts[0] = 'type' then Attr := ModuleAttri     // type and class aliases look like module
                                                           // aliases, so every alias reads as one
    else Continue;                             // keywords are already in the generated hash table
    for I := 1 to High(Parts) do
    begin
      Name := Parts[I];
      FWords.AddOrSetValue(Name, Attr);
    end;
  end;
end;

{ The generated highlighter calls anything that is not a keyword an identifier; look those up here. }
function THasteHighlighter.GetTokenAttribute: TSynHighlighterAttributes;
var
  Attr: TSynHighlighterAttributes;
begin
  Result := inherited GetTokenAttribute;
  if (Result = IdentifierAttri) and FWords.TryGetValue(GetToken, Attr) then   // TryGetValue clears its
    Result := Attr;                                                            // output when not found
end;

end.
