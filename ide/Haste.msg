TSynHasteSyn
tk              {second identifier is the token prefix}
IdentStart '_', 'a'..'z', 'A'..'Z' :: '_', '0'..'9', 'a'..'z', 'A'..'Z'::
|><|
TOKENTYPES
Builtin Foreground=RGB(255,128,128)
Comment Foreground=RGB(62,255,62)|Style=[fsItalic]
Identifiers Foreground=clYellow
Types Foreground=clWindowText
Special Foreground=clFuchsia
Member Foreground=RGB(134,166,104)
Module Foreground=clLime
Symbol Foreground=RGB(128,128,255)
String Foreground=RGB(255,128,0)
|><|
KEYS Builtin
print
Str
|><|
KEYS Identifiers
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
KEYS Types
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
KEYS Member
Add
Count
Length
Has
Remove
Get
|><|
KEYS Module
System
Text
Math
Time
Net
|><|
CHARS
'_', 'a'..'z', 'A'..'Z':: Ident
BeginProc
  fTokenID := IdentKind(fLine + Run);
  inc(Run, fStringLen);
  while IsIdentChar(fLine[Run]) do
    Inc(Run);
EndProc
|><|
ENCLOSEDBY
Comment,CommentLine,//
String,StringDQ,","
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
