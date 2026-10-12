unit Hasten.Project;

{ What Hasten for VCL and for FMX share about projects and switches. Nothing here is VCL or FMX.

  A project is Name.hproj beside Name.haste, its program, which builds to Name. The .hproj is an INI file
  that haste.py reads too:
    [Project]  Version=1
    [Build]    Targets=windows,linux       (empty: this system)
    [Switches] Width=1920                   (passed on Run)
  Which files were open is the user's own, so the IDEs keep that in their settings, not here. }

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.IniFiles, System.RegularExpressions;

type
  TSwitchInfo = record
    Name, Default, Rule, Help: string;
  end;

  THasteProject = class
  private
    FFileName: string;
    function GetName: string;
    function GetFolder: string;
    function GetProgramFile: string;
    function GetTargets: string;
    procedure SetTargets(const Value: string);
    function GetSwitchValue(const Name: string): string;
    procedure SetSwitchValue(const Name, Value: string);
    function GetFiles: TArray<string>;
    function GetHeading: string;
  public
    constructor Create(const FileName: string);
    procedure ClearSwitchValues;                 // before writing them again: a switch gone from the program goes too
    class function IsValidName(const Name: string): Boolean;
    property FileName: string read FFileName;                    // the .hproj, full path
    property Name: string read GetName;                          // Fractal
    property Folder: string read GetFolder;
    property ProgramFile: string read GetProgramFile;            // Fractal.haste beside the .hproj
    property Targets: string read GetTargets write SetTargets;   // '' for this system, else windows,linux ...
    property SwitchValues[const Name: string]: string read GetSwitchValue write SetSwitchValue;  // '' = default
    property Files: TArray<string> read GetFiles;                // the program, then the modules; not build
    property Heading: string read GetHeading;                    // Fractal - [windows, linux]
  end;

{ The switches a program declares, read the way haste.py reads them:
    switch Name[: type] = default [where rule]   // help }
function ReadSwitches(Source: TStrings): TArray<TSwitchInfo>;

{ --name value for every switch given a value, quoted where needed: what Run passes to the program. }
function SwitchArgs(const Names, Values: TArray<string>): string;

{ Shapes/Rect.haste in Folder is the module Shapes.Rect. }
function ModuleNameOf(const Folder, FileName: string): string;

{ Text with the module OldName's uses (OldName.X and "alias Y = OldName") changed to NewName. }
function RenameModuleUses(const Text, OldName, NewName: string): string;

const
  NamePattern = '^[A-Za-z_][A-Za-z0-9_]*$';      // a project or module name

implementation

{ ---- switches ---- }

function ReadSwitches(Source: TStrings): TArray<TSwitchInfo>;
var
  Line: string;
  M: TMatch;
  S: TSwitchInfo;
begin
  Result := nil;
  for Line in Source do
  begin
    if not Line.TrimLeft.StartsWith('switch ') then Continue;
    M := TRegEx.Match(Line, '^\s*switch\s+(\w+)\s*(?::\s*\w+\s*)?=\s*("(?:[^"\\]|\\.)*"|.+?)(?:\s+where\s+(.+?))?\s*(?://\s*(.*))?$');
    if not M.Success then Continue;
    S.Name := M.Groups[1].Value;
    S.Default := M.Groups[2].Value;
    S.Rule := '';
    S.Help := '';
    if (M.Groups.Count > 3) and M.Groups[3].Success then S.Rule := M.Groups[3].Value;
    if (M.Groups.Count > 4) and M.Groups[4].Success then S.Help := M.Groups[4].Value;
    Result := Result + [S];
  end;
end;

function SwitchArgs(const Names, Values: TArray<string>): string;
var
  I: Integer;
  V: string;
begin
  Result := '';
  for I := 0 to High(Names) do
  begin
    V := Values[I].Trim;
    if V = '' then Continue;
    if V.Contains(' ') or V.Contains('"') then
      V := '"' + V.Replace('"', '\"') + '"';
    Result := Result + ' --' + Names[I].ToLower + ' ' + V;
  end;
  Result := Result.Trim;
end;

{ ---- modules ---- }

function ModuleNameOf(const Folder, FileName: string): string;
begin
  Result := ChangeFileExt(ExtractRelativePath(IncludeTrailingPathDelimiter(Folder), FileName), '')
    .Replace(PathDelim, '.');
end;

function RenameModuleUses(const Text, OldName, NewName: string): string;
begin
  Result := TRegEx.Replace(Text, '(?<![\w.])' + TRegEx.Escape(OldName) + '(?=\s*\.)', NewName);
  Result := TRegEx.Replace(Result, '^(\s*alias\s+\w+\s*=\s*)' + TRegEx.Escape(OldName) + '(?=\s*(//|$))',
    '\1' + NewName, [roMultiLine]);
end;

{ ---- projects ---- }

constructor THasteProject.Create(const FileName: string);
begin
  inherited Create;
  FFileName := TPath.GetFullPath(FileName);
end;

class function THasteProject.IsValidName(const Name: string): Boolean;
begin
  Result := TRegEx.IsMatch(Name, NamePattern);
end;

function THasteProject.GetName: string;
begin
  Result := ChangeFileExt(ExtractFileName(FFileName), '');
end;

function THasteProject.GetFolder: string;
begin
  Result := ExtractFileDir(FFileName);
end;

function THasteProject.GetProgramFile: string;
begin
  Result := ChangeFileExt(FFileName, '.haste');
end;

function THasteProject.GetTargets: string;
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(FFileName, TEncoding.UTF8);
  try
    Result := Ini.ReadString('Build', 'Targets', '').Trim;
  finally
    Ini.Free;
  end;
end;

procedure THasteProject.SetTargets(const Value: string);
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(FFileName, TEncoding.UTF8);
  try
    Ini.WriteString('Build', 'Targets', Value);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

function THasteProject.GetSwitchValue(const Name: string): string;
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(FFileName, TEncoding.UTF8);
  try
    Result := Ini.ReadString('Switches', Name, '');
  finally
    Ini.Free;
  end;
end;

procedure THasteProject.SetSwitchValue(const Name, Value: string);
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(FFileName, TEncoding.UTF8);
  try
    if Value = '' then
      Ini.DeleteKey('Switches', Name)
    else
      Ini.WriteString('Switches', Name, Value);
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

procedure THasteProject.ClearSwitchValues;
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(FFileName, TEncoding.UTF8);
  try
    Ini.EraseSection('Switches');
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

function THasteProject.GetFiles: TArray<string>;
var
  F, Main: string;
  List: TStringList;
begin
  Result := nil;
  Main := ProgramFile;
  List := TStringList.Create;
  try
    if DirectoryExists(Folder) then
      for F in TDirectory.GetFiles(Folder, '*.haste', TSearchOption.soAllDirectories) do
        if not ExtractRelativePath(IncludeTrailingPathDelimiter(Folder), F).StartsWith('build' + PathDelim, True)
          and not SameFileName(F, Main) then
          List.Add(F);
    List.Sort;
    if FileExists(Main) then
      Result := [Main];
    Result := Result + List.ToStringArray;
  finally
    List.Free;
  end;
end;

{ Hasten runs the build here, so "this system" is the one it runs on. }
function THasteProject.GetHeading: string;
var
  T: string;
begin
  T := Targets;
  if T = '' then
{$IF Defined(MSWINDOWS)}
    T := 'windows';
{$ELSEIF Defined(MACOS)}
    T := 'macos';
{$ELSE}
    T := 'linux';
{$ENDIF}
  Result := Name + ' - [' + T.Replace(',', ', ') + ']';
end;

end.
