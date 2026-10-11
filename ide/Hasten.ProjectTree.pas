unit Hasten.ProjectTree;

{ The Project Manager: the open project's files as a tree. The heading is the project and what it builds for
  ("Fractal - [windows, linux]"); under it the program (Name.haste) comes first, then the modules beside it, then
  folders of modules (a folder makes a dotted name: Shapes\Rect.haste is Shapes.Rect). The build folder is left
  out. Double-click or Enter opens a file. The right-click menu opens a file or the project file, makes a new
  module, renames or deletes one (to the Recycle Bin), shows it in Explorer, or looks at the folder again.

  The tree is the folder: Rescan reads it again and rebuilds only when the files have changed, so it can be
  called whenever something might have changed (Hasten calls it on every save, tab change and folder change).
  The program is renamed with the project (Save Project As), never on its own here. }

interface

uses
  Winapi.Windows, Winapi.ShellAPI, System.SysUtils, System.Classes, System.IOUtils, System.IniFiles,
  System.RegularExpressions, Vcl.Controls, Vcl.Forms, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs;

type
  TOpenFileEvent = procedure(Sender: TObject; const FileName: string) of object;
  TRenamedEvent = procedure(Sender: TObject; const OldName, NewName: string) of object;

  TProjectTree = class(TTreeView)
  private
    FProject: string;
    FFiles: TArray<string>;                     // a file node's Data is its index here + 1
    FOnOpenFile: TOpenFileEvent;
    FOnRenamed: TRenamedEvent;
    FOnDeleting: TOpenFileEvent;
    FPopup: TPopupMenu;
    FOpenItem, FProjectFileItem, FRenameItem, FDeleteItem: TMenuItem;
    procedure SetProject(const Value: string);
    function GetProjectName: string;
    function GetProgramFile: string;
    function GetTargets: string;
    function GetHeading: string;
    function Scan: TArray<string>;
    procedure Build;
    function PathOf(Node: TTreeNode): string;
    function FolderOf(Node: TTreeNode): string;
    function IsModule(Node: TTreeNode): Boolean;
    function AskName(const Title, Start: string; out Name: string): Boolean;
    procedure OpenNode(Node: TTreeNode);
    procedure TreeDblClick(Sender: TObject);
    procedure TreeKeyPress(Sender: TObject; var Key: Char);
    procedure TreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MenuPopup(Sender: TObject);
    procedure MenuOpen(Sender: TObject);
    procedure MenuProjectFile(Sender: TObject);
    procedure MenuNewModule(Sender: TObject);
    procedure MenuRename(Sender: TObject);
    procedure MenuDelete(Sender: TObject);
    procedure MenuExplorer(Sender: TObject);
    procedure MenuRescan(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Rescan(Force: Boolean = False);
    procedure Select(const FileName: string);
    property Project: string read FProject write SetProject;      // the .hproj; '' empties the tree
    property ProjectName: string read GetProjectName;
    property ProgramFile: string read GetProgramFile;              // Name.haste beside the .hproj
    property Targets: string read GetTargets;                      // from the .hproj; '' for this system
    property Heading: string read GetHeading;                      // "Fractal - [windows, linux]"
    property Files: TArray<string> read FFiles;                    // the program, then the modules
    property OnOpenFile: TOpenFileEvent read FOnOpenFile write FOnOpenFile;
    property OnRenamed: TRenamedEvent read FOnRenamed write FOnRenamed;     // after a module is renamed
    property OnDeleting: TOpenFileEvent read FOnDeleting write FOnDeleting; // before a module is deleted
  end;

implementation

const
  NamePattern = '^[A-Za-z_][A-Za-z0-9_]*$';

constructor TProjectTree.Create(AOwner: TComponent);

  function Add(const Caption: string; Handler: TNotifyEvent): TMenuItem;
  begin
    Result := TMenuItem.Create(FPopup);
    Result.Caption := Caption;
    Result.OnClick := Handler;
    FPopup.Items.Add(Result);
  end;

begin
  inherited;
  ReadOnly := True;
  HideSelection := False;
  RowSelect := True;
  BorderStyle := bsNone;
  OnDblClick := TreeDblClick;
  OnKeyPress := TreeKeyPress;
  OnMouseDown := TreeMouseDown;
  FPopup := TPopupMenu.Create(Self);
  FPopup.OnPopup := MenuPopup;
  FOpenItem := Add('&Open', MenuOpen);
  FProjectFileItem := Add('Open &Project File', MenuProjectFile);
  Add('-', nil);
  Add('&New Module...', MenuNewModule);
  FRenameItem := Add('&Rename...', MenuRename);
  FDeleteItem := Add('&Delete', MenuDelete);
  Add('-', nil);
  Add('Show in &Explorer', MenuExplorer);
  Add('&Look Again', MenuRescan);
  PopupMenu := FPopup;
end;

procedure TProjectTree.SetProject(const Value: string);
begin
  FProject := Value;
  Rescan(True);
end;

function TProjectTree.GetProjectName: string;
begin
  Result := ChangeFileExt(ExtractFileName(FProject), '');
end;

function TProjectTree.GetProgramFile: string;
begin
  if FProject = '' then Result := '' else Result := ChangeFileExt(FProject, '.haste');
end;

function TProjectTree.GetTargets: string;
var
  Ini: TMemIniFile;
begin
  Result := '';
  if not FileExists(FProject) then Exit;
  Ini := TMemIniFile.Create(FProject, TEncoding.UTF8);
  try
    Result := Ini.ReadString('Build', 'Targets', '').Trim;
  finally
    Ini.Free;
  end;
end;

{ Hasten runs on Windows, so "this system" is windows. }
function TProjectTree.GetHeading: string;
var
  T: string;
begin
  T := Targets;
  if T = '' then T := 'windows';
  Result := ProjectName + ' - [' + T.Replace(',', ', ') + ']';
end;

{ The project's .haste files, the program first, then by path; nothing in a build folder. }
function TProjectTree.Scan: TArray<string>;
var
  Folder, F, Main: string;
  List: TStringList;
begin
  Result := nil;
  if FProject = '' then Exit;
  Folder := ExtractFileDir(FProject);
  Main := ProgramFile;
  List := TStringList.Create;
  try
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

procedure TProjectTree.Rescan(Force: Boolean);
var
  Found: TArray<string>;
  I: Integer;
  Same: Boolean;
begin
  Found := Scan;
  Same := Length(Found) = Length(FFiles);
  if Same then
    for I := 0 to High(Found) do
      if not SameFileName(Found[I], FFiles[I]) then
      begin
        Same := False;
        Break;
      end;
  if Same and not Force and ((Items.Count > 0) = (FProject <> '')) then
  begin
    if (Items.Count > 0) and (Items[0].Text <> Heading) then   // the targets changed
      Items[0].Text := Heading;
    Exit;
  end;
  FFiles := Found;
  Build;
end;

procedure TProjectTree.Build;
var
  Root, Holder, Node: TTreeNode;
  Folder, Rel, Part, Shown: string;
  Parts: TArray<string>;
  I, J: Integer;

  function Child(Under: TTreeNode; const Text: string): TTreeNode;
  begin
    Result := Under.getFirstChild;
    while (Result <> nil) and not ((Result.Data = nil) and SameText(Result.Text, Text)) do
      Result := Result.getNextSibling;
    if Result = nil then
      Result := Items.AddChild(Under, Text);
  end;

begin
  Items.BeginUpdate;
  try
    Items.Clear;
    if FProject = '' then Exit;
    Folder := IncludeTrailingPathDelimiter(ExtractFileDir(FProject));
    Root := Items.Add(nil, Heading);
    for I := 0 to High(FFiles) do
    begin
      Rel := ExtractRelativePath(Folder, FFiles[I]);
      Parts := Rel.Split([PathDelim]);
      Holder := Root;
      for J := 0 to High(Parts) - 1 do           // a folder of modules
      begin
        Part := Parts[J];
        Holder := Child(Holder, Part);
      end;
      Shown := Parts[High(Parts)];
      if I = 0 then
        Shown := Shown + '   (program)';
      Node := Items.AddChild(Holder, Shown);
      Node.Data := Pointer(NativeInt(I + 1));
    end;
    Root.Expand(True);
  finally
    Items.EndUpdate;
  end;
end;

function TProjectTree.PathOf(Node: TTreeNode): string;
begin
  if (Node <> nil) and (Node.Data <> nil) then
    Result := FFiles[NativeInt(Node.Data) - 1]
  else
    Result := '';
end;

function TProjectTree.IsModule(Node: TTreeNode): Boolean;
begin
  Result := (PathOf(Node) <> '') and not SameFileName(PathOf(Node), ProgramFile);
end;

{ The folder a new module goes in: the selected folder, the selected file's folder, or the project's. }
function TProjectTree.FolderOf(Node: TTreeNode): string;
var
  Path: TArray<string>;
  Part: string;
begin
  if Node = nil then Exit(ExtractFileDir(FProject));
  if Node.Data <> nil then Exit(ExtractFileDir(PathOf(Node)));
  Path := nil;
  while (Node <> nil) and (Node.Parent <> nil) do       // a folder node: its names up to the root
  begin
    Path := [Node.Text] + Path;
    Node := Node.Parent;
  end;
  Result := ExtractFileDir(FProject);
  for Part in Path do
    Result := TPath.Combine(Result, Part);
end;

function TProjectTree.AskName(const Title, Start: string; out Name: string): Boolean;
begin
  Name := Start;
  repeat
    if not InputQuery(Title, 'Module name:', Name) then Exit(False);
    Name := Name.Trim;
    if TRegEx.IsMatch(Name, NamePattern) then Exit(True);
    MessageDlg('A module name is letters, digits and _, starting with a letter or _.', mtWarning, [mbOK], 0);
  until False;
end;

procedure TProjectTree.Select(const FileName: string);
var
  I: Integer;
begin
  for I := 0 to Items.Count - 1 do
    if SameFileName(PathOf(Items[I]), FileName) then
    begin
      Selected := Items[I];
      Exit;
    end;
end;

procedure TProjectTree.OpenNode(Node: TTreeNode);
begin
  if (PathOf(Node) <> '') and Assigned(FOnOpenFile) then
    FOnOpenFile(Self, PathOf(Node));
end;

procedure TProjectTree.TreeDblClick(Sender: TObject);
begin
  OpenNode(Selected);
end;

procedure TProjectTree.TreeKeyPress(Sender: TObject; var Key: Char);
begin
  if Key = #13 then
  begin
    OpenNode(Selected);
    Key := #0;
  end;
end;

{ A right click selects what it is on, so the menu acts on that. }
procedure TProjectTree.TreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  if (Button = mbRight) and (GetNodeAt(X, Y) <> nil) then
    Selected := GetNodeAt(X, Y);
end;

{ Only what applies to the node: files open, modules (not the program) are renamed and deleted. }
procedure TProjectTree.MenuPopup(Sender: TObject);
begin
  FOpenItem.Visible := PathOf(Selected) <> '';
  FProjectFileItem.Visible := FProject <> '';
  FRenameItem.Visible := IsModule(Selected);
  FDeleteItem.Visible := IsModule(Selected);
end;

procedure TProjectTree.MenuOpen(Sender: TObject);
begin
  OpenNode(Selected);
end;

procedure TProjectTree.MenuProjectFile(Sender: TObject);
begin
  if (FProject <> '') and Assigned(FOnOpenFile) then
    FOnOpenFile(Self, FProject);
end;

procedure TProjectTree.MenuNewModule(Sender: TObject);
var
  ModName, Path: string;
  Lines: TStringList;
begin
  if (FProject = '') or not AskName('New Module', '', ModName) then Exit;
  Path := TPath.Combine(FolderOf(Selected), ModName + '.haste');
  if FileExists(Path) then
  begin
    MessageDlg(Path + ' is already there.', mtWarning, [mbOK], 0);
    Exit;
  end;
  Lines := TStringList.Create;
  try
    Lines.WriteBOM := False;                    // haste.py reads plain UTF-8
    Lines.Add('// ' + ModName + ': what this module is for');
    Lines.SaveToFile(Path, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
  Rescan;
  Select(Path);
  if Assigned(FOnOpenFile) then
    FOnOpenFile(Self, Path);
end;

procedure TProjectTree.MenuRename(Sender: TObject);
var
  OldPath, NewPath, ModName: string;
begin
  if not IsModule(Selected) then Exit;
  OldPath := PathOf(Selected);
  if not AskName('Rename Module', ChangeFileExt(ExtractFileName(OldPath), ''), ModName) then Exit;
  NewPath := TPath.Combine(ExtractFileDir(OldPath), ModName + '.haste');
  if SameStr(NewPath, OldPath) then Exit;
  if FileExists(NewPath) and not SameFileName(NewPath, OldPath) then
  begin
    MessageDlg(NewPath + ' is already there.', mtWarning, [mbOK], 0);
    Exit;
  end;
  if not RenameFile(OldPath, NewPath) then
  begin
    MessageDlg('Could not rename ' + OldPath + ': ' + SysErrorMessage(GetLastError), mtError, [mbOK], 0);
    Exit;
  end;
  Rescan(True);
  Select(NewPath);
  if Assigned(FOnRenamed) then
    FOnRenamed(Self, OldPath, NewPath);
end;

{ To the Recycle Bin, so a slip can be undone. }
procedure TProjectTree.MenuDelete(Sender: TObject);
var
  Path: string;
  Op: TSHFileOpStruct;
begin
  if not IsModule(Selected) then Exit;
  Path := PathOf(Selected);
  if MessageDlg('Delete ' + ExtractFileName(Path) + '? It goes to the Recycle Bin.', mtConfirmation,
    [mbYes, mbNo], 0) <> mrYes then Exit;
  if Assigned(FOnDeleting) then
    FOnDeleting(Self, Path);                    // Hasten closes its tab first
  FillChar(Op, SizeOf(Op), 0);
  Op.Wnd := Handle;
  Op.wFunc := FO_DELETE;
  Op.pFrom := PChar(Path + #0);                 // the list ends with two #0s
  Op.fFlags := FOF_ALLOWUNDO or FOF_NOCONFIRMATION or FOF_SILENT;
  if SHFileOperation(Op) <> 0 then
    MessageDlg('Could not delete ' + Path + '.', mtError, [mbOK], 0);
  Rescan(True);
end;

procedure TProjectTree.MenuExplorer(Sender: TObject);
var
  Path: string;
begin
  if FProject = '' then Exit;
  Path := PathOf(Selected);
  if Path = '' then
    Path := FProject;
  ShellExecute(0, 'open', 'explorer.exe', PChar('/select,"' + Path + '"'), nil, SW_SHOWNORMAL);
end;

procedure TProjectTree.MenuRescan(Sender: TObject);
begin
  Rescan(True);
end;

end.
