{-------------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License for
the specific language governing rights and limitations under the License.

Code template generated with SynGen.
The original code is: C:\Haste\ide\SynHighlighterHaste.pas, released 2026-10-11.
Description: Haste Parser/Highlighter
The initial author of this file is Mark Stephen Day.
Copyright (c) 2026, all rights reserved.

Contributors to the SynEdit and mwEdit projects are listed in the
Contributors.txt file.

Alternatively, the contents of this file may be used under the terms of the
GNU General Public License Version 2 or later (the "GPL"), in which case
the provisions of the GPL are applicable instead of those above.
If you wish to allow use of your version of this file only under the terms
of the GPL and not to allow others to use your version of this file
under the MPL, indicate your decision by deleting the provisions above and
replace them with the notice and other provisions required by the GPL.
If you do not delete the provisions above, a recipient may use your version
of this file under either the MPL or the GPL.

$Id: $

You may retrieve the latest version of this file at the SynEdit home page,
located at http://SynEdit.SourceForge.net

-------------------------------------------------------------------------------}

unit SynHighlighterHaste;

interface

uses
  Graphics,
  SynEditTypes,
  SynEditHighlighter,
  SynUnicode,
  SysUtils,
  Classes;

type
  TtkTokenKind = (
    tkBuiltin,
    tkComment,
    tkIdentifier,
    tkKey,
    tkMember,
    tkModule,
    tkNull,
    tkNumber,
    tkSpace,
    tkSpecial,
    tkString,
    tkSymbol,
    tkType,
    tkUnknown);

  TRangeState = (rsUnKnown);

  TProcTableProc = procedure of object;

  PIdentFuncTableFunc = ^TIdentFuncTableFunc;
  TIdentFuncTableFunc = function (Index: Integer): TtkTokenKind of object;

type
  TSynHasteSyn = class(TSynCustomHighlighter)
  private
    fRange: TRangeState;
    fTokenID: TtkTokenKind;
    fIdentFuncTable: array[0..70] of TIdentFuncTableFunc;
    fBuiltinAttri: TSynHighlighterAttributes;
    fCommentAttri: TSynHighlighterAttributes;
    fIdentifierAttri: TSynHighlighterAttributes;
    fKeyAttri: TSynHighlighterAttributes;
    fMemberAttri: TSynHighlighterAttributes;
    fModuleAttri: TSynHighlighterAttributes;
    fNumberAttri: TSynHighlighterAttributes;
    fSpaceAttri: TSynHighlighterAttributes;
    fSpecialAttri: TSynHighlighterAttributes;
    fStringAttri: TSynHighlighterAttributes;
    fSymbolAttri: TSynHighlighterAttributes;
    fTypeAttri: TSynHighlighterAttributes;
    function HashKey(Str: PWideChar): Cardinal;
    function FuncAlias(Index: Integer): TtkTokenKind;
    function FuncAnd(Index: Integer): TtkTokenKind;
    function FuncBool(Index: Integer): TtkTokenKind;
    function FuncCatch(Index: Integer): TtkTokenKind;
    function FuncClass(Index: Integer): TtkTokenKind;
    function FuncDiv(Index: Integer): TtkTokenKind;
    function FuncElif(Index: Integer): TtkTokenKind;
    function FuncElse(Index: Integer): TtkTokenKind;
    function FuncEnd(Index: Integer): TtkTokenKind;
    function FuncExtern(Index: Integer): TtkTokenKind;
    function FuncFalse(Index: Integer): TtkTokenKind;
    function FuncField(Index: Integer): TtkTokenKind;
    function FuncFloat(Index: Integer): TtkTokenKind;
    function FuncFn(Index: Integer): TtkTokenKind;
    function FuncFor(Index: Integer): TtkTokenKind;
    function FuncIf(Index: Integer): TtkTokenKind;
    function FuncIn(Index: Integer): TtkTokenKind;
    function FuncInit(Index: Integer): TtkTokenKind;
    function FuncInt(Index: Integer): TtkTokenKind;
    function FuncIt(Index: Integer): TtkTokenKind;
    function FuncLet(Index: Integer): TtkTokenKind;
    function FuncMod(Index: Integer): TtkTokenKind;
    function FuncNeed(Index: Integer): TtkTokenKind;
    function FuncNot(Index: Integer): TtkTokenKind;
    function FuncOr(Index: Integer): TtkTokenKind;
    function FuncParallel(Index: Integer): TtkTokenKind;
    function FuncReturn(Index: Integer): TtkTokenKind;
    function FuncSelf(Index: Integer): TtkTokenKind;
    function FuncShl(Index: Integer): TtkTokenKind;
    function FuncShr(Index: Integer): TtkTokenKind;
    function FuncString(Index: Integer): TtkTokenKind;
    function FuncSwitch(Index: Integer): TtkTokenKind;
    function FuncThen(Index: Integer): TtkTokenKind;
    function FuncTrue(Index: Integer): TtkTokenKind;
    function FuncTry(Index: Integer): TtkTokenKind;
    function FuncVar(Index: Integer): TtkTokenKind;
    function FuncWhere(Index: Integer): TtkTokenKind;
    function FuncWhile(Index: Integer): TtkTokenKind;
    function FuncWrite(Index: Integer): TtkTokenKind;
    function FuncXor(Index: Integer): TtkTokenKind;
    procedure IdentProc;
    procedure NumberProc;
    procedure SlashProc;
    procedure StringProc;
    procedure SymbolProc;
    procedure UnknownProc;
    function AltFunc(Index: Integer): TtkTokenKind;
    procedure InitIdent;
    function IdentKind(MayBe: PWideChar): TtkTokenKind;
    procedure NullProc;
    procedure SpaceProc;
    procedure CRProc;
    procedure LFProc;
  protected
    function GetSampleSource: string; override;
    function IsFilterStored: Boolean; override;
  public
    constructor Create(AOwner: TComponent); override;
    class function GetFriendlyLanguageName: string; override;
    class function GetLanguageName: string; override;
    function GetRange: Pointer; override;
    procedure ResetRange; override;
    procedure SetRange(Value: Pointer); override;
    function GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes; override;
    function GetEol: Boolean; override;
    function GetKeyWords(TokenKind: Integer): string; override;
    function GetTokenID: TtkTokenKind;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: Integer; override;
    function IsIdentChar(AChar: WideChar): Boolean; override;
    procedure Next; override;
  published
    property BuiltinAttri: TSynHighlighterAttributes read fBuiltinAttri write fBuiltinAttri;
    property CommentAttri: TSynHighlighterAttributes read fCommentAttri write fCommentAttri;
    property IdentifierAttri: TSynHighlighterAttributes read fIdentifierAttri write fIdentifierAttri;
    property KeyAttri: TSynHighlighterAttributes read fKeyAttri write fKeyAttri;
    property MemberAttri: TSynHighlighterAttributes read fMemberAttri write fMemberAttri;
    property ModuleAttri: TSynHighlighterAttributes read fModuleAttri write fModuleAttri;
    property NumberAttri: TSynHighlighterAttributes read fNumberAttri write fNumberAttri;
    property SpaceAttri: TSynHighlighterAttributes read fSpaceAttri write fSpaceAttri;
    property SpecialAttri: TSynHighlighterAttributes read fSpecialAttri write fSpecialAttri;
    property StringAttri: TSynHighlighterAttributes read fStringAttri write fStringAttri;
    property SymbolAttri: TSynHighlighterAttributes read fSymbolAttri write fSymbolAttri;
    property TypeAttri: TSynHighlighterAttributes read fTypeAttri write fTypeAttri;
  end;

implementation

uses
  SynEditStrConst;

resourcestring
  SYNS_Filterhaste = 'All files (*.haste)|*.haste';
  SYNS_Langhaste = 'haste';
  SYNS_FriendlyLanghaste = 'haste';
  SYNS_AttrBuiltin = 'Builtin';
  SYNS_FriendlyAttrBuiltin = 'Builtin';
  SYNS_AttrMember = 'Member';
  SYNS_FriendlyAttrMember = 'Member';
  SYNS_AttrModule = 'Module';
  SYNS_FriendlyAttrModule = 'Module';
  SYNS_AttrSpecial = 'Special';
  SYNS_FriendlyAttrSpecial = 'Special';
  SYNS_AttrType = 'Type';
  SYNS_FriendlyAttrType = 'Type';

const
  KeyWords: array[0..39] of string = (
    'alias', 'and', 'bool', 'catch', 'class', 'div', 'elif', 'else', 'end', 
    'extern', 'false', 'field', 'float', 'fn', 'for', 'if', 'in', 'init', 'int', 
    'it', 'let', 'mod', 'need', 'not', 'or', 'parallel', 'return', 'self', 
    'shl', 'shr', 'string', 'switch', 'then', 'true', 'try', 'var', 'where', 
    'while', 'write', 'xor' 
  );

  KeyIndices: array[0..70] of Integer = (
    31, -1, 11, 20, 6, -1, 28, -1, -1, 35, 25, -1, -1, 13, 10, 18, 36, -1, -1, 
    -1, 5, 1, 33, -1, -1, -1, -1, 26, 34, -1, -1, 37, 17, 9, 21, 24, -1, -1, 0, 
    27, -1, -1, 15, 22, -1, 19, -1, 7, -1, -1, -1, -1, 3, -1, 23, -1, -1, 39, 
    29, 4, -1, 38, 12, 14, 16, -1, -1, 8, 32, 2, 30 
  );

procedure TSynHasteSyn.InitIdent;
var
  i: Integer;
begin
  for i := Low(fIdentFuncTable) to High(fIdentFuncTable) do
    if KeyIndices[i] = -1 then
      fIdentFuncTable[i] := AltFunc;

  fIdentFuncTable[38] := FuncAlias;
  fIdentFuncTable[21] := FuncAnd;
  fIdentFuncTable[69] := FuncBool;
  fIdentFuncTable[52] := FuncCatch;
  fIdentFuncTable[59] := FuncClass;
  fIdentFuncTable[20] := FuncDiv;
  fIdentFuncTable[4] := FuncElif;
  fIdentFuncTable[47] := FuncElse;
  fIdentFuncTable[67] := FuncEnd;
  fIdentFuncTable[33] := FuncExtern;
  fIdentFuncTable[14] := FuncFalse;
  fIdentFuncTable[2] := FuncField;
  fIdentFuncTable[62] := FuncFloat;
  fIdentFuncTable[13] := FuncFn;
  fIdentFuncTable[63] := FuncFor;
  fIdentFuncTable[42] := FuncIf;
  fIdentFuncTable[64] := FuncIn;
  fIdentFuncTable[32] := FuncInit;
  fIdentFuncTable[15] := FuncInt;
  fIdentFuncTable[45] := FuncIt;
  fIdentFuncTable[3] := FuncLet;
  fIdentFuncTable[34] := FuncMod;
  fIdentFuncTable[43] := FuncNeed;
  fIdentFuncTable[54] := FuncNot;
  fIdentFuncTable[35] := FuncOr;
  fIdentFuncTable[10] := FuncParallel;
  fIdentFuncTable[27] := FuncReturn;
  fIdentFuncTable[39] := FuncSelf;
  fIdentFuncTable[6] := FuncShl;
  fIdentFuncTable[58] := FuncShr;
  fIdentFuncTable[70] := FuncString;
  fIdentFuncTable[0] := FuncSwitch;
  fIdentFuncTable[68] := FuncThen;
  fIdentFuncTable[22] := FuncTrue;
  fIdentFuncTable[28] := FuncTry;
  fIdentFuncTable[9] := FuncVar;
  fIdentFuncTable[16] := FuncWhere;
  fIdentFuncTable[31] := FuncWhile;
  fIdentFuncTable[61] := FuncWrite;
  fIdentFuncTable[57] := FuncXor;
end;

{$Q-}
function TSynHasteSyn.HashKey(Str: PWideChar): Cardinal;
begin
  Result := 0;
  while IsIdentChar(Str^) do
  begin
    Result := Result * 955 + Ord(Str^) * 56;
    inc(Str);
  end;
  Result := Result mod 71;
  fStringLen := Str - fToIdent;
end;
{$Q+}

function TSynHasteSyn.FuncAlias(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncAnd(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncBool(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkType
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncCatch(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncClass(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncDiv(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncElif(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncElse(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncEnd(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncExtern(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncFalse(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncField(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkSpecial
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncFloat(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkType
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncFn(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncFor(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncIf(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncIn(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncInit(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncInt(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkType
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncIt(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkSpecial
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncLet(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncMod(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncNeed(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncNot(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncOr(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncParallel(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncReturn(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncSelf(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkSpecial
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncShl(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncShr(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncString(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkType
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncSwitch(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncThen(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncTrue(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncTry(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncVar(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncWhere(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncWhile(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncWrite(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.FuncXor(Index: Integer): TtkTokenKind;
begin
  if IsCurrentToken(KeyWords[Index]) then
    Result := tkKey
  else
    Result := tkIdentifier;
end;

function TSynHasteSyn.AltFunc(Index: Integer): TtkTokenKind;
begin
  Result := tkIdentifier;
end;

function TSynHasteSyn.IdentKind(MayBe: PWideChar): TtkTokenKind;
var
  Key: Cardinal;
begin
  fToIdent := MayBe;
  Key := HashKey(MayBe);
  if Key <= High(fIdentFuncTable) then
    Result := fIdentFuncTable[Key](KeyIndices[Key])
  else
    Result := tkIdentifier;
end;

procedure TSynHasteSyn.SpaceProc;
begin
  inc(Run);
  fTokenID := tkSpace;
  while (FLine[Run] <= #32) and not IsLineEnd(Run) do inc(Run);
end;

procedure TSynHasteSyn.NullProc;
begin
  fTokenID := tkNull;
  inc(Run);
end;

procedure TSynHasteSyn.CRProc;
begin
  fTokenID := tkSpace;
  inc(Run);
  if fLine[Run] = #10 then
    inc(Run);
end;

procedure TSynHasteSyn.LFProc;
begin
  fTokenID := tkSpace;
  inc(Run);
end;

constructor TSynHasteSyn.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  fCaseSensitive := True;

  fBuiltinAttri := TSynHighLighterAttributes.Create(SYNS_AttrBuiltin, SYNS_FriendlyAttrBuiltin);
  fBuiltinAttri.Foreground := $008080FF;
  AddAttribute(fBuiltinAttri);

  fCommentAttri := TSynHighLighterAttributes.Create(SYNS_AttrComment, SYNS_FriendlyAttrComment);
  fCommentAttri.Style := [fsItalic];
  fCommentAttri.Foreground := $003EFF3E;
  AddAttribute(fCommentAttri);

  fIdentifierAttri := TSynHighLighterAttributes.Create(SYNS_AttrIdentifier, SYNS_FriendlyAttrIdentifier);
  AddAttribute(fIdentifierAttri);

  fKeyAttri := TSynHighLighterAttributes.Create(SYNS_AttrReservedWord, SYNS_FriendlyAttrReservedWord);
  fKeyAttri.Foreground := clYellow;
  AddAttribute(fKeyAttri);

  fMemberAttri := TSynHighLighterAttributes.Create(SYNS_AttrMember, SYNS_FriendlyAttrMember);
  fMemberAttri.Foreground := $0068A686;
  AddAttribute(fMemberAttri);

  fModuleAttri := TSynHighLighterAttributes.Create(SYNS_AttrModule, SYNS_FriendlyAttrModule);
  fModuleAttri.Foreground := clLime;
  AddAttribute(fModuleAttri);

  fNumberAttri := TSynHighLighterAttributes.Create(SYNS_AttrNumber, SYNS_FriendlyAttrNumber);
  fNumberAttri.Foreground := $00FFFF80;
  AddAttribute(fNumberAttri);

  fSpaceAttri := TSynHighLighterAttributes.Create(SYNS_AttrSpace, SYNS_FriendlyAttrSpace);
  AddAttribute(fSpaceAttri);

  fSpecialAttri := TSynHighLighterAttributes.Create(SYNS_AttrSpecial, SYNS_FriendlyAttrSpecial);
  fSpecialAttri.Foreground := clFuchsia;
  AddAttribute(fSpecialAttri);

  fStringAttri := TSynHighLighterAttributes.Create(SYNS_AttrString, SYNS_FriendlyAttrString);
  fStringAttri.Foreground := $000080FF;
  AddAttribute(fStringAttri);

  fSymbolAttri := TSynHighLighterAttributes.Create(SYNS_AttrSymbol, SYNS_FriendlyAttrSymbol);
  fSymbolAttri.Foreground := $00FF8080;
  AddAttribute(fSymbolAttri);

  fTypeAttri := TSynHighLighterAttributes.Create(SYNS_AttrType, SYNS_FriendlyAttrType);
  AddAttribute(fTypeAttri);

  SetAttributesOnChange(DefHighlightChange);
  InitIdent;
  fDefaultFilter := SYNS_Filterhaste;
  fRange := rsUnknown;
end;

procedure TSynHasteSyn.IdentProc;
begin
  fTokenID := IdentKind(fLine + Run);
  Inc(Run, fStringLen);
  while IsIdentChar(fLine[Run]) do
    Inc(Run);
end;

procedure TSynHasteSyn.NumberProc;
begin
  { 255, 1_000, 0xFF, 0b1010, 2.5, 1e5, 2.5e-3 }
  fTokenID := tkNumber;
  while CharInSet(fLine[Run], ['0'..'9', 'a'..'z', 'A'..'Z', '_']) do
    Inc(Run);
  if (fLine[Run] = '.') and CharInSet(fLine[Run + 1], ['0'..'9']) then
  begin
    Inc(Run);
    while CharInSet(fLine[Run], ['0'..'9', 'e', 'E', '_']) do
      Inc(Run);
  end;
  if CharInSet(fLine[Run], ['+', '-']) and CharInSet(fLine[Run - 1], ['e', 'E'])
    and not CharInSet(fLine[fTokenPos + 1], ['x', 'X']) then
  begin
    Inc(Run);
    while CharInSet(fLine[Run], ['0'..'9']) do
      Inc(Run);
  end;
end;

procedure TSynHasteSyn.SlashProc;
begin
  if fLine[Run + 1] = '/' then
  begin
    fTokenID := tkComment;
    repeat
      Inc(Run);
    until IsLineEnd(Run);
  end
  else
  begin
    fTokenID := tkSymbol;
    Inc(Run);
  end;
end;

procedure TSynHasteSyn.StringProc;
begin
  var Depth := 0;
  var Inner := False;
  fTokenID := tkString;
  Inc(Run);
  while not IsLineEnd(Run) do
  begin
    case fLine[Run] of
      '\': if not IsLineEnd(Run + 1) then Inc(Run);
      '{': if not Inner then Inc(Depth);
      '}': if not Inner and (Depth > 0) then Dec(Depth);
      '"':
        if Depth = 0 then
        begin
          Inc(Run);
          Exit;
        end
        else
          Inner := not Inner;
    end;
    Inc(Run);
  end;
end;

procedure TSynHasteSyn.SymbolProc;
begin
  fTokenID := tkSymbol;
  Inc(Run);
end;

procedure TSynHasteSyn.UnknownProc;
begin
  inc(Run);
  fTokenID := tkUnknown;
end;

procedure TSynHasteSyn.Next;
begin
  fTokenPos := Run;
  case fLine[Run] of
    #0: NullProc;
    #10: LFProc;
    #13: CRProc;
    #1..#9, #11, #12, #14..#32: SpaceProc;
    'A'..'Z', 'a'..'z', '_': IdentProc;
    '0'..'9': NumberProc;
    '/': SlashProc;
    '"': StringProc;
    '=', '<', '>', '+', '-', '*', '(', ')', '[', ']', '{', '}', ',', '.', ':': SymbolProc;
  else
    UnknownProc;
  end;
  inherited;
end;

function TSynHasteSyn.GetDefaultAttribute(Index: Integer): TSynHighLighterAttributes;
begin
  case Index of
    SYN_ATTR_COMMENT: Result := fCommentAttri;
    SYN_ATTR_IDENTIFIER: Result := fIdentifierAttri;
    SYN_ATTR_KEYWORD: Result := fKeyAttri;
    SYN_ATTR_STRING: Result := fStringAttri;
    SYN_ATTR_WHITESPACE: Result := fSpaceAttri;
    SYN_ATTR_SYMBOL: Result := fSymbolAttri;
  else
    Result := nil;
  end;
end;

function TSynHasteSyn.GetEol: Boolean;
begin
  Result := Run = fLineLen + 1;
end;

function TSynHasteSyn.GetKeyWords(TokenKind: Integer): string;
begin
  Result := 
    'alias,and,bool,catch,class,div,elif,else,end,extern,false,field,float' +
    ',fn,for,if,in,init,int,it,let,mod,need,not,or,parallel,return,self,shl' +
    ',shr,string,switch,then,true,try,var,where,while,write,xor';
end;

function TSynHasteSyn.GetTokenID: TtkTokenKind;
begin
  Result := fTokenId;
end;

function TSynHasteSyn.GetTokenAttribute: TSynHighLighterAttributes;
begin
  case GetTokenID of
    tkBuiltin: Result := fBuiltinAttri;
    tkComment: Result := fCommentAttri;
    tkIdentifier: Result := fIdentifierAttri;
    tkKey: Result := fKeyAttri;
    tkMember: Result := fMemberAttri;
    tkModule: Result := fModuleAttri;
    tkNumber: Result := fNumberAttri;
    tkSpace: Result := fSpaceAttri;
    tkSpecial: Result := fSpecialAttri;
    tkString: Result := fStringAttri;
    tkSymbol: Result := fSymbolAttri;
    tkType: Result := fTypeAttri;
    tkUnknown: Result := fIdentifierAttri;
  else
    Result := nil;
  end;
end;

function TSynHasteSyn.GetTokenKind: Integer;
begin
  Result := Ord(fTokenId);
end;

function TSynHasteSyn.IsIdentChar(AChar: WideChar): Boolean;
begin
  case AChar of
    '_', '0'..'9', 'a'..'z', 'A'..'Z':
      Result := True;
    else
      Result := False;
  end;
end;

function TSynHasteSyn.GetSampleSource: string;
begin
  Result := 
    '// Haste sample: properties, lists, dictionaries and switches'#13#10 +
    'alias Upper = Text.Upper'#13#10 +
    #13#10 +
    'switch Name = "World" where it <> ""      // set with --name'#13#10 +
    #13#10 +
    'class Account'#13#10 +
    '  Owner = "Unknown" where it <> ""'#13#10 +
    '  Balance = 0.0 where it >= 0'#13#10 +
    '    write'#13#10 +
    '      field = it'#13#10 +
    '    end'#13#10 +
    '  Tier => if Balance >= 1000 then "Gold" else "Standard"'#13#10 +
    'end'#13#10 +
    #13#10 +
    'fn Greet(who) = "Hello {who}"'#13#10 +
    #13#10 +
    'a = Account(Owner: "Mark", Balance: 1500)'#13#10 +
    'print("{a.Owner}: {a.Balance:2} ({a.Tier}) {Text.Upper("ok")}")'#13#10 +
    #13#10 +
    'counts = {}'#13#10 +
    'for w in Text.Split("to be or not to be", " ")'#13#10 +
    '  counts[w] = counts.Get(w, 0) + 1'#13#10 +
    'end'#13#10 +
    #13#10 +
    'total = 0'#13#10 +
    'parallel for i in 1..10'#13#10 +
    '  print(Str(i * 2 shl 1))'#13#10 +
    'end'#13#10 +
    #13#10 +
    'try'#13#10 +
    '  a.Balance = -20'#13#10 +
    'catch e'#13#10 +
    '  print("Rejected: {e}\n")''end';
end;

function TSynHasteSyn.IsFilterStored: Boolean;
begin
  Result := fDefaultFilter <> SYNS_Filterhaste;
end;

class function TSynHasteSyn.GetFriendlyLanguageName: string;
begin
  Result := SYNS_FriendlyLanghaste;
end;

class function TSynHasteSyn.GetLanguageName: string;
begin
  Result := SYNS_Langhaste;
end;

procedure TSynHasteSyn.ResetRange;
begin
  fRange := rsUnknown;
end;

procedure TSynHasteSyn.SetRange(Value: Pointer);
begin
  fRange := TRangeState(Value);
end;

function TSynHasteSyn.GetRange: Pointer;
begin
  Result := Pointer(fRange);
end;

initialization
{$IFNDEF SYN_CPPB_1}
  RegisterPlaceableHighlighter(TSynHasteSyn);
{$ENDIF}
end.
