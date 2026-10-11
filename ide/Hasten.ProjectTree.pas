unit Hasten.ProjectTree;

{ The Project Manager: the open project's files as a tree. The program (Name.haste) comes first, then the
  modules beside it, then folders of modules (a folder makes a dotted name: Shapes\Rect.haste is Shapes.Rect).
  The build folder is left out. Double-click or Enter opens a file; the right-click menu opens, makes a new
  module, shows a file in Explorer, or looks at the folder again.

  The tree is the folder: Rescan reads it again and rebuilds only when the files have changed, so it can be
  called whenever something might have changed (Hasten calls it on every save, tab change and folder change). }

interface

uses
  Winapi.Windows, Winapi.ShellAPI, System.SysUtils, System.Classes, System.IOUtils, System.RegularExpressions,
  Vcl.Controls, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs;

type
  TOpenFileEvent = procedure(Sender: TObject; const FileName: string) of object;

  TProjectTree = class(TTreeView)
  private
    FProject: string;
    FFiles: TArray<string>;                     // a file node's Data is its index here + 1
    FOnOpenFile: TOpenFileEvent;
    FPopup: TPopupMenu;
    procedure SetProject(const Value: string);
    function GetProjectName: string;
    function GetProgramFile: string;
    function Scan: TArray<string>;
    procedure Build;
    function PathOf(Node: TTreeNode): string;
    function FolderOf(Node: TTreeNode): string;
    procedure OpenNode(Node: TTreeNode);
    procedure TreeDblClick(Sender: TObject);
    procedure TreeKeyPress(Sender: TObject; var Key: Char);
    procedure TreeMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure MenuOpen(Sender: TObject);
    procedure MenuNewModule(Sender: TObject);
    procedure MenuExplorer(Sender: TObject);
    procedure MenuRescan(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    procedure Rescan(Force: Boolean = False);
    procedure Select(const FileName: string);
    property Project: string read FProject write SetProject;      // the .hproj; '' empties the tree
    property ProjectName: string read GetProjectName;
    property ProgramFile: string read GetProgramFile;              // Name.haste beside the .hproj
    property OnOpenFile: TOpenFileEvent read FOnOpenFile write FOnOpenFile;
  end;

implementation

constructor TProjectTree.Create(AOwner: TComponent);

  procedure Add(const Caption: string; Handler: TNotifyEvent);
  var
    Item: TMenuItem;
  begin
    Item := TMenuItem.Create(FPopup);
    Item.Caption := Caption;
    Item.OnClick := Handler;
    FPopup.Items.Add(Item);
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
  Add('&Open', MenuOpen);
  Add('&New Module...', MenuNewModule);
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
  if Same and not Force and ((Items.Count > 0) = (FProject <> '')) then Exit;
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
    Root := Items.Add(nil, ProjectName);
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

procedure TProjectTree.MenuOpen(Sender: TObject);
begin
  OpenNode(Selected);
end;

procedure TProjectTree.MenuNewModule(Sender: TObject);
var
  ModName, Path: string;
  Lines: TStringList;
begin
  if FProject = '' then Exit;
  ModName := '';
  repeat
    if not InputQuery('New Module', 'Module name:', ModName) then Exit;
    ModName := ModName.Trim;
    if TRegEx.IsMatch(ModName, '^[A-Za-z_][A-Za-z0-9_]*$') then Break;
    MessageDlg('A module name is letters, digits and _, starting with a letter or _.', mtWarning, [mbOK], 0);
  until False;
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

procedure TProjectTree.MenuExplorer(Sender: TObject);
var
  Path: string;
begin
  if FProject = '' then Exit;
  Path := PathOf(Selected);
  if Path <> '' then
    ShellExecute(0, 'open', 'explorer.exe', PChar('/select,"' + Path + '"'), nil, SW_SHOWNORMAL)
  else
    ShellExecute(0, 'open', PChar(FolderOf(Selected)), nil, nil, SW_SHOWNORMAL);
end;

procedure TProjectTree.MenuRescan(Sender: TObject);
begin
  Rescan(True);
end;

end.
