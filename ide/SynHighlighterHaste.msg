TSynHasteSyn    {first identifier is the class name}
tk              {second identifier is the token prefix}
{ Colours from Haste.msg (SynEdit Msg Designer), for a dark background. RGB(r,g,b) is written as $00BBGGRR,
  because the unit SynGen writes uses only Graphics, which has no RGB function. }
Sensitive
IdentStart '_', 'a'..'z', 'A'..'Z':: '_', '0'..'9', 'a'..'z', 'A'..'Z'::

TOKENTYPES
Identifier
Comment Style=[fsItalic]|Foreground=$003EFF3E
Space
String Foreground=$000080FF
Number Foreground=$00FFFF80
Symbol Foreground=$00FF8080
Key Foreground=clYellow
Builtin Foreground=$008080FF
Type
Special Foreground=clFuchsia
Member Foreground=$0068A686
Module Foreground=clLime
|><|

KEYS
alias
and
catch
class
div
elif
else
end
extern
false
fn
for
if
in
init
let
mod
need
not
or
parallel
return
shl
shr
switch
then
true
try
var
where
while
write
xor
|><|

KEYS Builtin
print
|><|

KEYS Type
int
float
string
bool
|><|

KEYS Special
it
field
self
|><|

CHARS

'A'..'Z', 'a'..'z', '_':: Ident
BeginProc
  fTokenID := IdentKind(fLine + Run);
  Inc(Run, fStringLen);
  while IsIdentChar(fLine[Run]) do
    Inc(Run);
  // Capitalised words are coloured here, not in KEYS: SynGen's case-sensitive hash table is wrong for
  // keywords with capitals (it hashes them lowercased in InitIdent but as written in KeyIndices), which
  // leaves nil entries in fIdentFuncTable and crashes on the first identifier that lands on one.
  if fTokenID = tkIdentifier then
  begin
    var S: string;
    SetString(S, fLine + fTokenPos, Run - fTokenPos);
    if (S = 'Str') or (S = 'Int') or (S = 'Float') then
      fTokenID := tkBuiltin
    else if (S = 'Add') or (S = 'Count') or (S = 'Length') or (S = 'Has') or (S = 'Remove') or (S = 'Get') then
      fTokenID := tkMember
    else if (S = 'System') or (S = 'Text') or (S = 'Math') or (S = 'Time') or (S = 'Net') then
      fTokenID := tkModule;
  end;
EndProc

'0'..'9':: Number
BeginProc
  fTokenID := tkNumber;
  while CharInSet(fLine[Run], ['0'..'9']) do
    Inc(Run);
  if (fLine[Run] = '.') and CharInSet(fLine[Run + 1], ['0'..'9']) then
  begin
    Inc(Run);
    while CharInSet(fLine[Run], ['0'..'9']) do
      Inc(Run);
  end;
EndProc

'"':: String
BeginProc
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
EndProc

'/':: Slash
BeginProc
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
EndProc

'=', '<', '>', '+', '-', '*', '(', ')', '[', ']', '{', '}', ',', '.', ':':: Symbol
BeginProc
  fTokenID := tkSymbol;
  Inc(Run);
EndProc

|><|

SAMPLESOURCE
// Haste sample: properties, lists, dictionaries and switches
alias Upper = Text.Upper

switch Name = "World" where it <> ""      // set with --name

class Account
  Owner = "Unknown" where it <> ""
  Balance = 0.0 where it >= 0
    write
      field = it
    end
  Tier => if Balance >= 1000 then "Gold" else "Standard"
end

fn Greet(who) = "Hello {who}"

a = Account(Owner: "Mark", Balance: 1500)
print("{a.Owner}: {a.Balance:2} ({a.Tier}) {Text.Upper("ok")}")

counts = {}
for w in Text.Split("to be or not to be", " ")
  counts[w] = counts.Get(w, 0) + 1
end

total = 0
parallel for i in 1..10
  print(Str(i * 2 shl 1))
end

try
  a.Balance = -20
catch e
  print("Rejected: {e}\n")
end
|><|
