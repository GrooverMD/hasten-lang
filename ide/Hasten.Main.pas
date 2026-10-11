unit Hasten.Main;

{ Hasten, the Haste IDE: tabbed editor with Haste highlighting, Run and Build through haste.py, output
  panel, and a jump to the line of each compiler error. Every control is created in code, so there is
  no .dfm to keep in step. }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.IniFiles, System.UITypes,
  System.RegularExpressions, System.Actions, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Menus, Vcl.ActnList, Vcl.Graphics, Vcl.Clipbrd, Vcl.Buttons, Vcl.Themes,
  SynEdit, SynEditTypes, SynEditSearch, SynHighlighterHasteOutput, Hasten.Highlighter, Hasten.Runner,
  Hasten.Watcher, Hasten.Settings, Hasten.ModuleOptions;

type
  TEditorTab = class(TTabSheet)
  private
    FEditor: TSynEdit;
    FFileName: string;
    function GetModified: Boolean;
    procedure SetFileName(const Value: string);
    function GetTitle: string;
  public
    constructor Create(AOwner: TComponent); override;
    procedure UpdateCaption;
    property Editor: TSynEdit read FEditor;
    property FileName: string read FFileName write SetFileName;
    property Modified: Boolean read GetModified;
    property Title: string read GetTitle;
  end;

  TMainForm = class(TForm)
  private
    FPages: TPageControl;
    FOutput: TSynEdit;                          // read-only, coloured by SynHighlighterHasteOutput
    FOutputHighlighter: TSynHasteOutputSyn;
    FStatus: TStatusBar;
    FActions: TActionList;
    FRunAction, FBuildAction, FStopAction, FTestsAction, FModuleAction: TAction;
    FHighlighter: THasteHighlighter;
    FSearch: TSynEditSearch;
    FFind: TFindDialog;
    FEditorMenu: TPopupMenu;                    // right-click menu shared by every editor tab
    FFontName: string;                          // the editor font, kept in Hasten.ini
    FFontSize: Integer;
    FTabWidth: Integer;                         // these and the rest are set in Tools > Settings
    FRightEdge: Integer;                        // 0: no margin line
    FLineNumbers: Boolean;
    FClearOutput: Boolean;                      // on each Run, Build and Run Tests
    FReopen: Boolean;                           // last session's files at start
    FStyleName: string;                         // '' keeps the style Hasten.dpr sets
    FTools: TPanel;                             // the toolbar: icon buttons at the left of the top bar
    FToolbarAction: TAction;
    FEditButtons: TArray<TSpeedButton>;         // Undo ... Paste: enabled as the Edit menu's items are
    FEditMenu: TMenuItem;                       // the main menu's Edit
    FRunner: TRunner;
    FFinished: TRunner;                         // the last run, freed once its thread is long gone
    FWordsRunner: TRunner;                      // "haste.py words": names to colour, asked in the background
    FWordsFinished: TRunner;
    FWordLines: TStringList;
    FWordsAgain: Boolean;
    FWatcher: TFolderWatcher;                   // lib and the program's folder: new modules appear at once
    FWordsTimer: TTimer;                        // gathers a burst of file changes into one refresh
    FRunFolder: string;
    FJumped: Boolean;
    FUntitled: Integer;
    FHastePy: string;
    FPython: string;
    FIniName: string;
    function GetActiveTab: TEditorTab;
    function GetRunning: Boolean;
    function AddAction(const Caption, Keys: string; const Handler: TNotifyEvent): TAction;
    procedure BuildUi;
    procedure LoadSettings;
    procedure SaveSettings;
    function NewTab(const AFileName: string): TEditorTab;
    function FindTab(const AFileName: string): TEditorTab;
    function SaveTab(Tab: TEditorTab; AskName: Boolean): Boolean;
    function CloseTab(Tab: TEditorTab): Boolean;
    function SaveAllForRun: Boolean;
    function LocateHastePy(Ask: Boolean = True): Boolean;
    function PythonCommand: string;
    procedure RefreshWords;
    procedure WatchFolders;
    procedure WordsTimerFire(Sender: TObject);
    procedure WordsDone(ExitCode: Cardinal; Stopped: Boolean);
    procedure Start(const Verb: string);
    procedure RunnerLine(const Line: string);
    procedure RunnerDone(ExitCode: Cardinal; Stopped: Boolean);
    function JumpToError(const Line: string): Boolean;
    procedure EditorStatus(Sender: TObject; Changes: TSynStatusChanges);
    procedure UpdateStatus;
    function ModuleSection(const FileName: string): string;
    function ModuleTargets(const FileName: string): string;
    function ModuleSwitchArgs(Tab: TEditorTab): string;
    procedure PagesChange(Sender: TObject);
    procedure OutputDblClick(Sender: TObject);
    procedure OutputClear;
    procedure OutputAdd(const Line: string);
    procedure FindNext(Sender: TObject);
    procedure BuildEditorMenu;
    procedure ApplyFont;
    procedure ApplyEditor(E: TSynEdit);
    procedure BuildToolbar(Bar: TPanel; const Actions: array of TAction);
    procedure ToolEditClick(Sender: TObject);
    procedure DoToolbar(Sender: TObject);
    procedure DoSettings(Sender: TObject);
    procedure DoModuleOptions(Sender: TObject);
    procedure SetFontSize(Size: Integer);
    procedure EditorMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
      MousePos: TPoint; var Handled: Boolean);
    procedure DoFont(Sender: TObject);
    procedure DoZoomIn(Sender: TObject);
    procedure DoZoomOut(Sender: TObject);
    procedure DoZoomReset(Sender: TObject);
    procedure AddEditItems(Parent: TMenuItem; WithFind: Boolean);
    procedure UpdateEditItems(Parent: TMenuItem);
    procedure EditorMenuPopup(Sender: TObject);
    procedure EditMenuOpen(Sender: TObject);
    procedure EditorMenuClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure DoNew(Sender: TObject);
    procedure DoOpen(Sender: TObject);
    procedure DoSave(Sender: TObject);
    procedure DoSaveAs(Sender: TObject);
    procedure DoCloseTab(Sender: TObject);
    procedure DoQuit(Sender: TObject);
    procedure DoFind(Sender: TObject);
    procedure DoFindNext(Sender: TObject);
    procedure DoGoToLine(Sender: TObject);
    procedure DoRun(Sender: TObject);
    procedure DoBuild(Sender: TObject);
    procedure DoStop(Sender: TObject);
    procedure DoTests(Sender: TObject);
    procedure DoHastePy(Sender: TObject);
    procedure ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure OpenFile(const AFileName: string; Line: Integer = 0);
    property ActiveTab: TEditorTab read GetActiveTab;
    property Running: Boolean read GetRunning;
    property HastePy: string read FHastePy write FHastePy;
    property Python: string read FPython write FPython;
  end;

var
  MainForm: TMainForm;

implementation

const
  HasteFilter = 'Haste files (*.haste)|*.haste|All files (*.*)|*.*';

function Quote(const S: string): string;
begin
  if S.Contains(' ') then Result := '"' + S + '"' else Result := S;
end;

{ ---- TEditorTab ---- }

constructor TEditorTab.Create(AOwner: TComponent);
begin
  inherited;
  FEditor := TSynEdit.Create(Self);
  FEditor.Parent := Self;
  FEditor.Align := alClient;
  FEditor.Font.Name := 'Consolas';
  FEditor.Font.Size := 11;
  FEditor.Color := $001E1E1E;                    // dark, for the colours in SynHighlighterHaste.msg
  FEditor.Font.Color := $00D4D4D4;              // identifiers and types use the plain text colour
  FEditor.Gutter.Color := $00262626;
  FEditor.Gutter.Font.Color := $00808080;
  FEditor.TabWidth := 2;
  FEditor.WantTabs := True;
  FEditor.Options := FEditor.Options + [eoAutoIndent, eoTabsToSpaces];
  FEditor.Gutter.ShowLineNumbers := True;
  FEditor.Lines.WriteBOM := False;              // haste.py reads plain UTF-8
end;

function TEditorTab.GetModified: Boolean;
begin
  Result := FEditor.Modified;
end;

function TEditorTab.GetTitle: string;
begin
  if FFileName <> '' then Result := ExtractFileName(FFileName) else Result := string(Caption).TrimRight(['*']);   // TCaption has no string helper
end;

procedure TEditorTab.SetFileName(const Value: string);
begin
  FFileName := Value;
  UpdateCaption;
end;

procedure TEditorTab.UpdateCaption;
begin
  if Modified then Caption := Title + '*' else Caption := Title;
end;

{ ---- TMainForm ---- }

constructor TMainForm.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited CreateNew(AOwner);                  // no .dfm: everything is built in BuildUi
  FFontName := 'Consolas';
  FFontSize := 11;
  FTabWidth := 2;
  FRightEdge := 80;
  FLineNumbers := True;
  FClearOutput := True;
  FReopen := True;
  FHighlighter := THasteHighlighter.Create(Self);
  FWordLines := TStringList.Create;
  FWordsTimer := TTimer.Create(Self);
  FWordsTimer.Enabled := False;
  FWordsTimer.Interval := 300;
  FWordsTimer.OnTimer := WordsTimerFire;
  FSearch := TSynEditSearch.Create(Self);
  FIniName := TPath.Combine(TPath.Combine(TPath.GetHomePath, 'Hasten'), 'Hasten.ini');
  Application.HintHidePause := 30000;            // long enough to read the list of switches
  SetEnvironmentVariable('PYTHONIOENCODING', 'utf-8');
  SetEnvironmentVariable('PYTHONUNBUFFERED', '1');
  BuildUi;
  LoadSettings;
  for I := 1 to ParamCount do                   // files dropped on the exe, or opened from Explorer
    if FileExists(ParamStr(I)) then
      OpenFile(ParamStr(I));
  if FPages.PageCount = 0 then
    DoNew(nil);
  ActiveControl := ActiveTab.Editor;            // focused when the form appears; SetFocus can't be used yet
  RefreshWords;
end;

{ The window handle is made inside the constructor (reopening last session's files needs it), which is
  before Application.CreateForm records this form as the main form. VCL then makes the hidden application
  window its owner, and an owned window gets no taskbar button and minimises to the desktop. This is the
  main window, so it is never owned and always has its own taskbar button. }
procedure TMainForm.CreateParams(var Params: TCreateParams);
begin
  inherited;
  Params.ExStyle := Params.ExStyle or WS_EX_APPWINDOW;
  Params.WndParent := 0;
end;

destructor TMainForm.Destroy;
begin
  FWordsTimer.Enabled := False;
  FreeAndNil(FWatcher);
  if FRunner <> nil then
  begin
    FRunner.Stop;
    FRunner.WaitFor;                            // the job is ended, so its pipe closes and Execute returns
    TThread.RemoveQueuedEvents(FRunner);        // its last lines must not reach a destroyed form
    FreeAndNil(FRunner);
  end;
  FFinished.Free;
  if FWordsRunner <> nil then
  begin
    FWordsRunner.Stop;
    FWordsRunner.WaitFor;
    TThread.RemoveQueuedEvents(FWordsRunner);
    FreeAndNil(FWordsRunner);
  end;
  FWordsFinished.Free;
  FWordLines.Free;
  inherited;
end;

function TMainForm.AddAction(const Caption, Keys: string; const Handler: TNotifyEvent): TAction;
begin
  Result := TAction.Create(FActions);
  Result.ActionList := FActions;
  Result.Caption := Caption;
  if Keys <> '' then
    Result.ShortCut := TextToShortCut(Keys);
  Result.OnExecute := Handler;
end;

procedure TMainForm.BuildUi;
var
  Menu: TMainMenu;
  Bar: TPanel;
  Split: TSplitter;

  function Item(Parent: TMenuItem; Action: TAction): TMenuItem;
  begin
    Result := TMenuItem.Create(Menu);
    if Action = nil then Result.Caption := '-' else Result.Action := Action;
    Parent.Add(Result);
  end;

  function Head(const Caption: string): TMenuItem;
  begin
    Result := TMenuItem.Create(Menu);
    Result.Caption := Caption;
    Menu.Items.Add(Result);
  end;

var
  FileMenu, EditMenu, ViewMenu, RunMenu, ToolsMenu: TMenuItem;
  Zoom, NewAction, OpenAction, SaveAction, FindAction, SettingsAction: TAction;
begin
  Caption := 'Hasten';
  Width := 1100;
  Height := 760;
  Position := poScreenCenter;
  OnCloseQuery := FormCloseQuery;

  FActions := TActionList.Create(Self);
  FActions.OnUpdate := ActionsUpdate;
  Menu := TMainMenu.Create(Self);
  Self.Menu := Menu;

  FileMenu := Head('&File');
  NewAction := AddAction('&New', 'Ctrl+N', DoNew);
  OpenAction := AddAction('&Open...', 'Ctrl+O', DoOpen);
  SaveAction := AddAction('&Save', 'Ctrl+S', DoSave);
  Item(FileMenu, NewAction);
  Item(FileMenu, OpenAction);
  Item(FileMenu, SaveAction);
  Item(FileMenu, AddAction('Save &As...', 'Ctrl+Shift+S', DoSaveAs));
  Item(FileMenu, AddAction('&Close', 'Ctrl+W', DoCloseTab));
  Item(FileMenu, nil);
  Item(FileMenu, AddAction('E&xit', 'Alt+F4', DoQuit));

  EditMenu := Head('&Edit');
  FEditMenu := EditMenu;
  EditMenu.OnClick := EditMenuOpen;             // runs as the menu opens: grey out what can't apply
  AddEditItems(EditMenu, False);
  Item(EditMenu, nil);
  FindAction := AddAction('&Find...', 'Ctrl+F', DoFind);
  Item(EditMenu, FindAction);
  Item(EditMenu, AddAction('Find &Next', 'F3', DoFindNext));
  Item(EditMenu, AddAction('&Go to Line...', 'Ctrl+G', DoGoToLine));

  ViewMenu := Head('&View');
  FToolbarAction := AddAction('&Toolbar', '', DoToolbar);
  FToolbarAction.AutoCheck := True;
  FToolbarAction.Checked := True;
  Item(ViewMenu, FToolbarAction);
  Item(ViewMenu, nil);
  Item(ViewMenu, AddAction('&Font...', '', DoFont));
  Item(ViewMenu, nil);
  Zoom := AddAction('Zoom &In', '', DoZoomIn);          // Ctrl + NumPad +, -, 0; Ctrl+wheel also zooms
  Zoom.ShortCut := Vcl.Menus.ShortCut(VK_ADD, [ssCtrl]);
  Item(ViewMenu, Zoom);
  Zoom := AddAction('Zoom &Out', '', DoZoomOut);
  Zoom.ShortCut := Vcl.Menus.ShortCut(VK_SUBTRACT, [ssCtrl]);
  Item(ViewMenu, Zoom);
  Zoom := AddAction('&Reset Zoom', '', DoZoomReset);
  Zoom.ShortCut := Vcl.Menus.ShortCut(VK_NUMPAD0, [ssCtrl]);
  Item(ViewMenu, Zoom);

  RunMenu := Head('&Run');
  FRunAction := AddAction('&Run', 'F9', DoRun);
  FBuildAction := AddAction('&Build', 'Ctrl+F9', DoBuild);
  FStopAction := AddAction('&Stop', 'Ctrl+F2', DoStop);
  FTestsAction := AddAction('Run &Tests', '', DoTests);
  FModuleAction := AddAction('Module &Options...', 'Shift+Ctrl+F11', DoModuleOptions);
  Item(RunMenu, FRunAction);
  Item(RunMenu, FBuildAction);
  Item(RunMenu, FStopAction);
  Item(RunMenu, nil);
  Item(RunMenu, FTestsAction);
  Item(RunMenu, nil);
  Item(RunMenu, FModuleAction);
  Item(RunMenu, nil);
  Item(RunMenu, AddAction('Where is &haste.py...', '', DoHastePy));

  ToolsMenu := Head('&Tools');
  SettingsAction := AddAction('&Settings...', '', DoSettings);
  Item(ToolsMenu, SettingsAction);

  Bar := TPanel.Create(Self);
  Bar.Parent := Self;
  Bar.Align := alTop;
  Bar.Height := 34;
  Bar.BevelOuter := bvNone;
  BuildToolbar(Bar, [NewAction, OpenAction, SaveAction, nil, nil, FindAction, FRunAction, FBuildAction,
    FStopAction, FTestsAction, FModuleAction, SettingsAction]);

  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.SimplePanel := False;
  FStatus.Panels.Add.Width := 110;
  FStatus.Panels.Add.Width := 90;
  FStatus.Panels.Add;

  FOutputHighlighter := TSynHasteOutputSyn.Create(Self);
  FOutput := TSynEdit.Create(Self);
  FOutput.Parent := Self;
  FOutput.Align := alBottom;
  FOutput.Height := 180;
  FOutput.ReadOnly := True;
  FOutput.Highlighter := FOutputHighlighter;
  FOutput.Font.Name := 'Consolas';
  FOutput.Font.Size := 10;
  FOutput.Color := $001E1E1E;                    // the same dark background as the editor
  FOutput.Font.Color := $00D4D4D4;
  FOutput.Gutter.Visible := False;
  FOutput.RightEdge := 0;                        // no margin line in the output
  FOutput.OnDblClick := OutputDblClick;

  Split := TSplitter.Create(Self);
  Split.Parent := Self;
  Split.Align := alBottom;
  Split.Top := FOutput.Top - 1;                 // keeps the splitter above the output panel

  FPages := TPageControl.Create(Self);
  FPages.Parent := Self;
  FPages.Align := alClient;
  FPages.OnChange := PagesChange;

  BuildEditorMenu;

  FFind := TFindDialog.Create(Self);
  FFind.Options := [frDown];
  FFind.OnFind := FindNext;
end;

{ ---- right-click menu ----
  SynEdit has no context menu of its own. The keys are shown after a tab, not set as ShortCut, because the
  editor already handles Ctrl+Z, Ctrl+C and the rest itself; a real ShortCut would also fire them in
  other controls. Tag says what an item does. }

const
  emUndo = 1; emRedo = 2; emCut = 3; emCopy = 4; emPaste = 5; emDelete = 6; emSelectAll = 7;
  emFind = 8; emGoToLine = 9;

procedure TMainForm.AddEditItems(Parent: TMenuItem; WithFind: Boolean);

  procedure Add(const Caption, Keys: string; Tag: Integer);
  var
    Item: TMenuItem;
  begin
    Item := TMenuItem.Create(Self);
    Item.Caption := Caption;
    if Keys <> '' then
      Item.Caption := Item.Caption + #9 + Keys;
    Item.Tag := Tag;
    if Tag > 0 then
      Item.OnClick := EditorMenuClick;
    Parent.Add(Item);
  end;

begin
  Add('&Undo', 'Ctrl+Z', emUndo);
  Add('&Redo', 'Ctrl+Shift+Z', emRedo);
  Add('-', '', 0);
  Add('Cu&t', 'Ctrl+X', emCut);
  Add('&Copy', 'Ctrl+C', emCopy);
  Add('&Paste', 'Ctrl+V', emPaste);
  Add('&Delete', 'Del', emDelete);
  Add('-', '', 0);
  Add('Select &All', 'Ctrl+A', emSelectAll);
  if WithFind then                              // the Edit menu has these as actions already
  begin
    Add('-', '', 0);
    Add('&Find...', 'Ctrl+F', emFind);
    Add('&Go to Line...', 'Ctrl+G', emGoToLine);
  end;
end;

procedure TMainForm.BuildEditorMenu;
begin
  FEditorMenu := TPopupMenu.Create(Self);
  FEditorMenu.OnPopup := EditorMenuPopup;
  AddEditItems(FEditorMenu.Items, True);
end;

{ What the items act on: the right-click menu acts on the editor it was opened in; the Edit menu acts on
  whatever has focus, so Copy works in the output panel and Paste in the switches box too. }
function EditTarget(Form: TMainForm; FromPopup: Boolean): TWinControl;
begin
  Result := nil;
  if not FromPopup and ((Form.ActiveControl is TCustomEdit) or (Form.ActiveControl is TSynEdit)) then
    Result := Form.ActiveControl
  else if Form.ActiveTab <> nil then
    Result := Form.ActiveTab.Editor;
end;

{ Grey out what can't be done right now. }
procedure TMainForm.UpdateEditItems(Parent: TMenuItem);
var
  Item: TMenuItem;
  Target: TWinControl;
  E: TSynEdit;
  C: TCustomEdit;
begin
  Target := EditTarget(Self, Parent = FEditorMenu.Items);
  for Item in Parent do
  begin
    if Item.Tag = 0 then Continue;
    if Target is TSynEdit then
    begin
      E := TSynEdit(Target);
      case Item.Tag of
        emUndo: Item.Enabled := E.CanUndo;
        emRedo: Item.Enabled := E.CanRedo;
        emCut, emDelete: Item.Enabled := E.SelAvail and not E.ReadOnly;
        emCopy: Item.Enabled := E.SelAvail;
        emPaste: Item.Enabled := E.CanPaste;
      else
        Item.Enabled := True;
      end;
    end
    else if Target is TCustomEdit then
    begin
      C := TCustomEdit(Target);
      case Item.Tag of
        emUndo: Item.Enabled := C.CanUndo;
        emRedo: Item.Enabled := False;          // a plain edit box has one level of undo, no redo
        emCut, emDelete: Item.Enabled := (C.SelLength > 0) and not C.ReadOnly;
        emCopy: Item.Enabled := C.SelLength > 0;
        emPaste: Item.Enabled := not C.ReadOnly and Clipboard.HasFormat(CF_TEXT);
      else
        Item.Enabled := True;
      end;
    end
    else
      Item.Enabled := False;
  end;
end;

procedure TMainForm.EditorMenuPopup(Sender: TObject);
begin
  UpdateEditItems(FEditorMenu.Items);
end;

procedure TMainForm.EditMenuOpen(Sender: TObject);
begin
  UpdateEditItems(FEditMenu);
end;

procedure TMainForm.EditorMenuClick(Sender: TObject);
var
  Item: TMenuItem;
  Target: TWinControl;
begin
  Item := Sender as TMenuItem;
  Target := EditTarget(Self, Item.GetParentMenu = FEditorMenu);
  if Target is TSynEdit then
    with TSynEdit(Target) do
      case Item.Tag of
        emUndo: Undo;
        emRedo: Redo;
        emCut: CutToClipboard;
        emCopy: CopyToClipboard;
        emPaste: PasteFromClipboard;
        emDelete: SelText := '';
        emSelectAll: SelectAll;
      end
  else if Target is TCustomEdit then
    with TCustomEdit(Target) do
      case Item.Tag of
        emUndo: Undo;
        emCut: CutToClipboard;
        emCopy: CopyToClipboard;
        emPaste: PasteFromClipboard;
        emDelete: ClearSelection;
        emSelectAll: SelectAll;
      end;
  case Item.Tag of
    emFind: DoFind(Sender);
    emGoToLine: DoGoToLine(Sender);
  end;
end;

{ ---- the toolbar ----
  Flat buttons whose pictures are characters of Windows' own icon font (Segoe Fluent Icons on Windows 11,
  Segoe MDL2 Assets on Windows 10): no image files, sharp at any size, drawn in the VCL style's colours.
  Without either font the buttons show short words. Buttons with an action follow it (Stop is enabled only
  while something runs); Undo ... Paste act on what has focus, as the Edit menu does. A nil in Actions
  stands for the edit buttons, then a gap. }

type
  TTool = record Glyph: Char; Word, Hint: string; Tag: Integer; end;

procedure TMainForm.BuildToolbar(Bar: TPanel; const Actions: array of TAction);
const
  Glyphs: array[0..11] of TTool = (
    (Glyph: #$E8A5; Word: 'New'; Hint: 'New (Ctrl+N)'; Tag: 0),
    (Glyph: #$E8E5; Word: 'Open'; Hint: 'Open (Ctrl+O)'; Tag: 0),
    (Glyph: #$E74E; Word: 'Save'; Hint: 'Save (Ctrl+S)'; Tag: 0),
    (Glyph: #0; Word: ''; Hint: ''; Tag: 0), (Glyph: #0; Word: ''; Hint: ''; Tag: 0),
    (Glyph: #$E721; Word: 'Find'; Hint: 'Find (Ctrl+F)'; Tag: 0),
    (Glyph: #$E768; Word: 'Run'; Hint: 'Run (F9)'; Tag: 0),
    (Glyph: #$E90F; Word: 'Build'; Hint: 'Build (Ctrl+F9)'; Tag: 0),
    (Glyph: #$E71A; Word: 'Stop'; Hint: 'Stop (Ctrl+F2)'; Tag: 0),
    (Glyph: #$E9D5; Word: 'Tests'; Hint: 'Run Tests'; Tag: 0),
    (Glyph: #$E9E9; Word: 'Options'; Hint: 'Module Options (Shift+Ctrl+F11)'; Tag: 0),
    (Glyph: #$E713; Word: 'Settings'; Hint: 'Settings'; Tag: 0));
  Edits: array[0..4] of TTool = (
    (Glyph: #$E7A7; Word: 'Undo'; Hint: 'Undo (Ctrl+Z)'; Tag: emUndo),
    (Glyph: #$E7A6; Word: 'Redo'; Hint: 'Redo (Ctrl+Shift+Z)'; Tag: emRedo),
    (Glyph: #$E8C6; Word: 'Cut'; Hint: 'Cut (Ctrl+X)'; Tag: emCut),
    (Glyph: #$E8C8; Word: 'Copy'; Hint: 'Copy (Ctrl+C)'; Tag: emCopy),
    (Glyph: #$E77F; Word: 'Paste'; Hint: 'Paste (Ctrl+V)'; Tag: emPaste));
var
  IconFont: string;
  X, I, J: Integer;
  EditsDone: Boolean;

  function Button(const T: TTool; Action: TAction): TSpeedButton;
  begin
    Result := TSpeedButton.Create(Self);
    Result.Parent := FTools;
    Result.Flat := True;
    if Action <> nil then Result.Action := Action;   // enabled with the action; sets Caption, so after:
    if IconFont <> '' then
    begin
      Result.Font.Name := IconFont;
      Result.Font.Size := 12;
      Result.Caption := T.Glyph;
      Result.SetBounds(X, 3, 30, 28);
    end
    else
    begin
      Result.Caption := T.Word;
      Result.SetBounds(X, 3, Canvas.TextWidth(T.Word) + 16, 28);
    end;
    Result.Hint := T.Hint;
    Result.ShowHint := True;
    Inc(X, Result.Width + 1);
  end;

  procedure Gap;
  begin
    Inc(X, 10);
  end;

begin
  if Screen.Fonts.IndexOf('Segoe Fluent Icons') >= 0 then IconFont := 'Segoe Fluent Icons'
  else if Screen.Fonts.IndexOf('Segoe MDL2 Assets') >= 0 then IconFont := 'Segoe MDL2 Assets'
  else IconFont := '';
  FTools := TPanel.Create(Self);
  FTools.Parent := Bar;
  FTools.Align := alLeft;
  FTools.BevelOuter := bvNone;
  X := 4;
  EditsDone := False;
  for I := 0 to High(Actions) do
    if Actions[I] <> nil then
    begin
      if I in [6, 11] then Gap;                  // before Run, and before Settings
      Button(Glyphs[I], Actions[I]);
    end
    else if not EditsDone then
    begin
      Gap;
      for J := 0 to High(Edits) do
      begin
        FEditButtons := FEditButtons + [Button(Edits[J], nil)];
        FEditButtons[J].Tag := Edits[J].Tag;
        FEditButtons[J].OnClick := ToolEditClick;
      end;
      Gap;
      EditsDone := True;
    end;
  FTools.Width := X + 4;
end;

{ Undo ... Paste on the toolbar: a speed button never takes the focus, so the editor or box that had it
  is still ActiveControl, and the Edit menu's code does the work. }
procedure TMainForm.ToolEditClick(Sender: TObject);
var
  Item: TMenuItem;
begin
  for Item in FEditMenu do
    if Item.Tag = TSpeedButton(Sender).Tag then
    begin
      UpdateEditItems(FEditMenu);
      if Item.Enabled then EditorMenuClick(Item);
      Exit;
    end;
end;

procedure TMainForm.DoToolbar(Sender: TObject);
begin
  FTools.Parent.Visible := FToolbarAction.Checked;   // the whole top bar: the toolbar is all it holds
end;

{ ---- settings that apply to every editor ---- }

procedure TMainForm.ApplyEditor(E: TSynEdit);
begin
  E.Font.Name := FFontName;
  E.Font.Size := FFontSize;
  E.Gutter.Font.Name := FFontName;
  E.Gutter.Font.Size := FFontSize;
  E.TabWidth := FTabWidth;
  E.RightEdge := FRightEdge;
  E.Gutter.ShowLineNumbers := FLineNumbers;
end;

procedure TMainForm.DoSettings(Sender: TObject);
var
  Dialog: TSettingsDialog;
begin
  Dialog := TSettingsDialog.Create(Self);
  try
    Dialog.FontName := FFontName;
    Dialog.FontSize := FFontSize;
    Dialog.TabWidth := FTabWidth;
    Dialog.RightEdge := FRightEdge;
    Dialog.LineNumbers := FLineNumbers;
    Dialog.StyleName := TStyleManager.ActiveStyle.Name;
    Dialog.Python := FPython;
    Dialog.HastePy := FHastePy;
    Dialog.ClearOutput := FClearOutput;
    Dialog.Reopen := FReopen;
    if not Dialog.Execute then Exit;
    FFontName := Dialog.FontName;
    FFontSize := Dialog.FontSize;
    FTabWidth := Dialog.TabWidth;
    FRightEdge := Dialog.RightEdge;
    FLineNumbers := Dialog.LineNumbers;
    FPython := Dialog.Python;
    if Dialog.HastePy <> FHastePy then
    begin
      FHastePy := Dialog.HastePy;
      RefreshWords;                             // another haste.py can mean other modules
    end;
    FClearOutput := Dialog.ClearOutput;
    FReopen := Dialog.Reopen;
    if (Dialog.StyleName <> '') and (Dialog.StyleName <> TStyleManager.ActiveStyle.Name) then
    begin
      FStyleName := Dialog.StyleName;
      TStyleManager.TrySetStyle(FStyleName);
    end;
    ApplyFont;
    SaveSettings;
  finally
    Dialog.Free;
  end;
end;

{ ---- module options: each program's own, in Hasten.ini under [Module <full file name>] ---- }

function TMainForm.ModuleSection(const FileName: string): string;
begin
  Result := 'Module ' + FileName;
end;

{ '' builds for this system; else the targets for haste.py --target, e.g. windows,linux. }
function TMainForm.ModuleTargets(const FileName: string): string;
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  try
    Result := Ini.ReadString(ModuleSection(FileName), 'Targets', '');
  finally
    Ini.Free;
  end;
end;

{ The values saved for the switches the program declares now: one removed from the source is not passed. }
function TMainForm.ModuleSwitchArgs(Tab: TEditorTab): string;
var
  Ini: TMemIniFile;
  Switches: TArray<TSwitchInfo>;
  Names, Values: TArray<string>;
  S: TSwitchInfo;
begin
  Switches := ReadSwitches(Tab.Editor.Lines);
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  try
    for S in Switches do
    begin
      Names := Names + [S.Name];
      Values := Values + [Ini.ReadString(ModuleSection(Tab.FileName), 'Switch.' + S.Name, '')];
    end;
  finally
    Ini.Free;
  end;
  Result := SwitchArgs(Names, Values);
end;

procedure TMainForm.DoModuleOptions(Sender: TObject);
var
  Tab: TEditorTab;
  Dialog: TModuleOptionsDialog;
  Ini: TMemIniFile;
  Section: string;
  I: Integer;
begin
  Tab := ActiveTab;
  if Tab = nil then Exit;
  if Tab.FileName = '' then                     // the options are kept by file, so it needs a name
  begin
    if MessageDlg('Save ' + Tab.Title + ' first? Module options are kept with the file.',
      mtConfirmation, [mbOK, mbCancel], 0) <> mrOk then Exit;
    if not SaveTab(Tab, True) or (Tab.FileName = '') then Exit;
  end;
  Section := ModuleSection(Tab.FileName);
  ForceDirectories(ExtractFilePath(FIniName));
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  Dialog := TModuleOptionsDialog.Create(Self);
  try
    Dialog.LoadSwitches(Tab.Editor.Lines);
    Dialog.Targets := Ini.ReadString(Section, 'Targets', '');
    for I := 0 to Dialog.SwitchCount - 1 do
      Dialog.Values[Dialog.Switches[I].Name] := Ini.ReadString(Section, 'Switch.' + Dialog.Switches[I].Name, '');
    if not Dialog.Execute(Tab.Title) then Exit;
    Ini.EraseSection(Section);                  // switches no longer in the program go with it
    if Dialog.Targets <> '' then
      Ini.WriteString(Section, 'Targets', Dialog.Targets);
    for I := 0 to Dialog.SwitchCount - 1 do
      if Dialog.Values[Dialog.Switches[I].Name] <> '' then
        Ini.WriteString(Section, 'Switch.' + Dialog.Switches[I].Name, Dialog.Values[Dialog.Switches[I].Name]);
    Ini.UpdateFile;
  finally
    Dialog.Free;
    Ini.Free;
  end;
end;

{ ---- the editor font: one font and size for every tab, chosen under View or with Ctrl+mouse wheel ---- }

const
  DefaultFontSize = 11;

procedure TMainForm.ApplyFont;
var
  I: Integer;
  E: TSynEdit;
begin
  for I := 0 to FPages.PageCount - 1 do
  begin
    E := TEditorTab(FPages.Pages[I]).Editor;
    ApplyEditor(E);
  end;
  FOutput.Font.Name := FFontName;              // the output panel follows, a point smaller
  if FFontSize > 7 then FOutput.Font.Size := FFontSize - 1 else FOutput.Font.Size := FFontSize;
end;

procedure TMainForm.SetFontSize(Size: Integer);
begin
  if Size < 6 then Size := 6;
  if Size > 48 then Size := 48;
  if Size = FFontSize then Exit;
  FFontSize := Size;
  ApplyFont;
  FStatus.Panels[2].Text := Format('Font: %s, %d pt', [FFontName, FFontSize]);
end;

{ Ctrl+wheel zooms every tab at once and is remembered; SynEdit's own wheel zoom would change only the
  editor under the mouse, and only until Hasten closes. }
procedure TMainForm.EditorMouseWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer;
  MousePos: TPoint; var Handled: Boolean);
begin
  if Shift * [ssCtrl, ssShift, ssAlt] = [ssCtrl] then
  begin
    if WheelDelta > 0 then SetFontSize(FFontSize + 1) else SetFontSize(FFontSize - 1);
    Handled := True;
  end;
end;

procedure TMainForm.DoZoomIn(Sender: TObject);
begin
  SetFontSize(FFontSize + 1);
end;

procedure TMainForm.DoZoomOut(Sender: TObject);
begin
  SetFontSize(FFontSize - 1);
end;

procedure TMainForm.DoZoomReset(Sender: TObject);
begin
  SetFontSize(DefaultFontSize);
end;

{ The font dialog lists only fixed-pitch fonts: code needs columns that line up. }
procedure TMainForm.DoFont(Sender: TObject);
var
  Dialog: TFontDialog;
begin
  Dialog := TFontDialog.Create(nil);
  try
    Dialog.Options := [fdFixedPitchOnly, fdForceFontExist, fdNoStyleSel];
    Dialog.Font.Name := FFontName;
    Dialog.Font.Size := FFontSize;
    if Dialog.Execute then
    begin
      FFontName := Dialog.Font.Name;
      FFontSize := Dialog.Font.Size;
      ApplyFont;
    end;
  finally
    Dialog.Free;
  end;
end;

{ ---- settings: %APPDATA%\Hasten\Hasten.ini ---- }

procedure TMainForm.LoadSettings;
var
  Ini: TMemIniFile;
  Files: TStringList;
  I: Integer;
begin
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  Files := TStringList.Create;
  try
    FHastePy := Ini.ReadString('Haste', 'HastePy', '');
    FPython := Ini.ReadString('Haste', 'Python', 'python');
    FFontName := Ini.ReadString('Editor', 'FontName', FFontName);
    FFontSize := Ini.ReadInteger('Editor', 'FontSize', FFontSize);
    FTabWidth := Ini.ReadInteger('Editor', 'TabWidth', FTabWidth);
    FRightEdge := Ini.ReadInteger('Editor', 'RightEdge', FRightEdge);
    FLineNumbers := Ini.ReadBool('Editor', 'LineNumbers', FLineNumbers);
    FClearOutput := Ini.ReadBool('Run', 'ClearOutput', FClearOutput);
    FReopen := Ini.ReadBool('Start', 'Reopen', FReopen);
    FStyleName := Ini.ReadString('View', 'Style', '');
    if FStyleName <> '' then
      TStyleManager.TrySetStyle(FStyleName, False);   // False: no error if it is no longer linked in
    FToolbarAction.Checked := Ini.ReadBool('View', 'Toolbar', True);
    DoToolbar(nil);
    ApplyFont;
    Ini.ReadSectionValues('Open', Files);
    if FReopen then
      for I := 0 to Files.Count - 1 do             // the files that were open last time
        if FileExists(Files.ValueFromIndex[I]) then
          OpenFile(Files.ValueFromIndex[I]);
  finally
    Files.Free;
    Ini.Free;
  end;
end;

procedure TMainForm.SaveSettings;
var
  Ini: TMemIniFile;
  I, N: Integer;
begin
  ForceDirectories(ExtractFilePath(FIniName));
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  try
    Ini.WriteString('Haste', 'HastePy', FHastePy);
    Ini.WriteString('Haste', 'Python', FPython);
    Ini.WriteString('Editor', 'FontName', FFontName);
    Ini.WriteInteger('Editor', 'FontSize', FFontSize);
    Ini.WriteInteger('Editor', 'TabWidth', FTabWidth);
    Ini.WriteInteger('Editor', 'RightEdge', FRightEdge);
    Ini.WriteBool('Editor', 'LineNumbers', FLineNumbers);
    Ini.WriteBool('Run', 'ClearOutput', FClearOutput);
    Ini.WriteBool('Start', 'Reopen', FReopen);
    Ini.WriteString('View', 'Style', FStyleName);
    Ini.WriteBool('View', 'Toolbar', FToolbarAction.Checked);
    Ini.DeleteKey('Run', 'Switches');           // from before Module Options: each program keeps its own now
    Ini.DeleteKey('Run', 'Target');
    Ini.EraseSection('Open');
    N := 0;
    for I := 0 to FPages.PageCount - 1 do
      if TEditorTab(FPages.Pages[I]).FileName <> '' then
      begin
        Inc(N);
        Ini.WriteString('Open', 'File' + N.ToString, TEditorTab(FPages.Pages[I]).FileName);
      end;
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

{ ---- tabs and files ---- }

function TMainForm.GetActiveTab: TEditorTab;
begin
  Result := TEditorTab(FPages.ActivePage);
end;

function TMainForm.GetRunning: Boolean;
begin
  Result := FRunner <> nil;
end;

function TMainForm.NewTab(const AFileName: string): TEditorTab;
begin
  Result := TEditorTab.Create(FPages);
  Result.PageControl := FPages;
  Result.Editor.Highlighter := FHighlighter;
  Result.Editor.SearchEngine := FSearch;
  Result.Editor.OnStatusChange := EditorStatus;
  Result.Editor.PopupMenu := FEditorMenu;
  Result.Editor.OnMouseWheel := EditorMouseWheel;
  ApplyEditor(Result.Editor);
  if AFileName = '' then
  begin
    Inc(FUntitled);
    Result.Caption := 'Untitled' + FUntitled.ToString;
  end
  else
  begin
    Result.Editor.Lines.LoadFromFile(AFileName, TEncoding.UTF8);
    Result.Editor.Modified := False;
    Result.FileName := AFileName;
  end;
  FPages.ActivePage := Result;
  UpdateStatus;
end;

function TMainForm.FindTab(const AFileName: string): TEditorTab;
var
  I: Integer;
begin
  for I := 0 to FPages.PageCount - 1 do
    if SameFileName(TEditorTab(FPages.Pages[I]).FileName, AFileName) then
      Exit(TEditorTab(FPages.Pages[I]));
  Result := nil;
end;

procedure TMainForm.OpenFile(const AFileName: string; Line: Integer);
var
  Tab: TEditorTab;
begin
  Tab := FindTab(AFileName);
  if Tab = nil then
  begin
    Tab := ActiveTab;                           // reuse an empty, untouched Untitled tab
    if (Tab <> nil) and (Tab.FileName = '') and not Tab.Modified and (Tab.Editor.Lines.Count = 0) then
    begin
      Tab.Editor.Lines.LoadFromFile(AFileName, TEncoding.UTF8);
      Tab.Editor.Modified := False;
      Tab.FileName := AFileName;
    end
    else
      Tab := NewTab(AFileName);
  end;
  FPages.ActivePage := Tab;
  if Line > 0 then
    Tab.Editor.GotoLineAndCenter(Line);
  if Showing and Tab.Editor.CanFocus then      // not while the constructor reopens last session's files:
    Tab.Editor.SetFocus;                        // the form isn't on screen yet and SetFocus would raise
  UpdateStatus;
  RefreshWords;
end;

function TMainForm.SaveTab(Tab: TEditorTab; AskName: Boolean): Boolean;
var
  Dialog: TSaveDialog;
begin
  if AskName or (Tab.FileName = '') then
  begin
    Dialog := TSaveDialog.Create(nil);
    try
      Dialog.Filter := HasteFilter;
      Dialog.DefaultExt := 'haste';
      Dialog.FileName := Tab.Title;
      Dialog.Options := Dialog.Options + [ofOverwritePrompt];
      if not Dialog.Execute then Exit(False);
      Tab.FileName := Dialog.FileName;
    finally
      Dialog.Free;
    end;
  end;
  Tab.Editor.Lines.SaveToFile(Tab.FileName, TEncoding.UTF8);
  Tab.Editor.Modified := False;
  Tab.UpdateCaption;
  RefreshWords;                                 // a file saved into lib is a new module
  Result := True;
end;

function TMainForm.CloseTab(Tab: TEditorTab): Boolean;
begin
  if Tab.Modified then
    case MessageDlg('Save changes to ' + Tab.Title + '?', mtConfirmation, mbYesNoCancel, 0) of
      mrYes: if not SaveTab(Tab, False) then Exit(False);
      mrCancel: Exit(False);
    end;
  Tab.Free;
  Result := True;
end;

{ Run and Build work on files, so every changed tab is saved first. }
function TMainForm.SaveAllForRun: Boolean;
var
  I: Integer;
  Tab: TEditorTab;
begin
  for I := 0 to FPages.PageCount - 1 do
  begin
    Tab := TEditorTab(FPages.Pages[I]);
    if (Tab.Modified or (Tab.FileName = '')) and ((Tab = ActiveTab) or (Tab.FileName <> '')) then
      if not SaveTab(Tab, False) then Exit(False);
  end;
  Result := True;
end;

{ ---- running haste.py ---- }

{ haste.py is found once: next to the exe or up to four folders above it (the repository layout puts
  the IDE in ide\Win64\Debug), otherwise the user is asked. }
function TMainForm.LocateHastePy(Ask: Boolean): Boolean;
var
  Dir: string;
  I: Integer;
begin
  if FileExists(FHastePy) then Exit(True);
  Dir := ExtractFileDir(ParamStr(0));
  for I := 0 to 4 do
  begin
    if FileExists(TPath.Combine(Dir, 'haste.py')) then
    begin
      FHastePy := TPath.Combine(Dir, 'haste.py');
      Exit(True);
    end;
    Dir := ExtractFileDir(Dir);
  end;
  if Ask then
    DoHastePy(nil);
  Result := FileExists(FHastePy);
end;

{ The Python to run haste.py with: the setting (normally "python") if Windows can find it, otherwise "py",
  the launcher the python.org installer puts in the Windows folder, which every program can find even
  when it was started before Python was installed and so has an old PATH. }
function TMainForm.PythonCommand: string;

  function Found(const Name: string): Boolean;
  var
    Buffer: array[0..MAX_PATH] of Char;
    FilePart: PChar;
  begin
    Result := FileExists(Name) or (SearchPath(nil, PChar(Name), '.exe', MAX_PATH, Buffer, FilePart) > 0);
  end;

begin
  Result := FPython;
  if not Found(Result) and Found('py') then
    Result := 'py';
end;

{ Asks haste.py which built-ins, members and modules exist, so the highlighter colours a new module in lib
  (or next to the program) without the .msg being regenerated. Runs in the background; a request made
  while one is running is remembered and run straight after. }
procedure TMainForm.RefreshWords;
var
  Cmd: string;
  Tab: TEditorTab;
begin
  if not LocateHastePy(False) then Exit;       // never ask for haste.py just to colour words
  WatchFolders;
  if FWordsRunner <> nil then
  begin
    FWordsAgain := True;
    Exit;
  end;
  Cmd := Quote(PythonCommand) + ' ' + Quote(FHastePy) + ' words';
  Tab := ActiveTab;
  if (Tab <> nil) and (Tab.FileName <> '') then
    Cmd := Cmd + ' ' + Quote(Tab.FileName);    // modules next to the program count too
  FWordLines.Clear;
  FWordsRunner := TRunner.Create(Cmd, ExtractFileDir(FHastePy),
    procedure(const Line: string) begin FWordLines.Add(Line) end, WordsDone);
end;

{ Watch the folders haste.py words looks in: lib, and the open program's folder. Only restarts the watcher
  when that set changes, e.g. on switching to a tab from another folder. }
procedure TMainForm.WatchFolders;
var
  Folders: TArray<string>;
  Tab: TEditorTab;
begin
  if not FileExists(FHastePy) then Exit;
  Folders := [TPath.Combine(ExtractFileDir(FHastePy), 'lib')];
  Tab := ActiveTab;
  if (Tab <> nil) and (Tab.FileName <> '') and not SameFileName(ExtractFileDir(Tab.FileName), Folders[0]) then
    Folders := Folders + [ExtractFileDir(Tab.FileName)];
  if (FWatcher <> nil) and (string.Join('|', FWatcher.Folders) = string.Join('|', Folders)) then Exit;
  FreeAndNil(FWatcher);
  FWatcher := TFolderWatcher.Create(Folders,
    procedure
    begin
      FWordsTimer.Enabled := False;             // restart the wait: a copy of ten files is one refresh
      FWordsTimer.Enabled := True;
    end);
end;

procedure TMainForm.WordsTimerFire(Sender: TObject);
begin
  FWordsTimer.Enabled := False;
  RefreshWords;
end;

procedure TMainForm.WordsDone(ExitCode: Cardinal; Stopped: Boolean);
var
  I: Integer;
begin
  if (ExitCode = 0) and not Stopped then
  begin
    FHighlighter.LoadWords(FWordLines);
    for I := 0 to FPages.PageCount - 1 do
      TEditorTab(FPages.Pages[I]).Editor.Invalidate;
  end;
  FWordsFinished.Free;                          // same reason as in RunnerDone
  FWordsFinished := FWordsRunner;
  FWordsRunner := nil;
  if FWordsAgain then
  begin
    FWordsAgain := False;
    RefreshWords;
  end;
end;

procedure TMainForm.Start(const Verb: string);
var
  Tab: TEditorTab;
  Cmd, Targets, Args: string;
begin
  Tab := ActiveTab;
  if Running or (Tab = nil) or not SaveAllForRun or not LocateHastePy then Exit;
  Cmd := Quote(PythonCommand) + ' ' + Quote(FHastePy) + ' ' + Verb + ' ' + Quote(Tab.FileName);
  if Verb = 'build' then
    Targets := ModuleTargets(Tab.FileName)
  else
    Targets := '';
  if Targets <> '' then
    Cmd := Cmd + ' --target ' + Targets;
  if Verb = 'run' then
    Args := ModuleSwitchArgs(Tab)
  else
    Args := '';
  if Args <> '' then
    Cmd := Cmd + ' ' + Args;
  FRunFolder := ExtractFileDir(Tab.FileName);
  FJumped := False;
  OutputClear;
  OutputAdd('> ' + Cmd);
  FStatus.Panels[2].Text := 'Running ' + Tab.Title + '...';
  FRunner := TRunner.Create(Cmd, FRunFolder, RunnerLine, RunnerDone);
end;

procedure TMainForm.RunnerLine(const Line: string);
begin
  OutputAdd(Line);
  if Line.StartsWith('Cannot start: ') then
    OutputAdd('Python could not be started. Check that "python --version" works in a new command ' +
      'prompt; if Python was installed while Hasten was open, restart Hasten so it sees the new PATH.');
  if not FJumped and (Line.StartsWith('error:') or Line.StartsWith('  in ')) then
    FJumped := JumpToError(Line);               // go straight to the first compiler or run-time error
end;

procedure TMainForm.RunnerDone(ExitCode: Cardinal; Stopped: Boolean);
begin
  if Stopped then
    OutputAdd('[stopped]')
  else
    OutputAdd(Format('[finished, exit code %d]', [ExitCode]));
  FStatus.Panels[2].Text := '';
  FFinished.Free;                               // the run before this one: its thread ended long ago
  FFinished := FRunner;                         // this one is still inside its own callback, so not yet
  FRunner := nil;
  RefreshWords;
end;

{ Compiler errors look like  error: fractal.haste:12: message  and a second line may add
  in Shade, called from fractal.haste:30. Run-time errors are followed by  in fractal.haste:12  and
  called from ... lines. The file is looked for next to the program, then in lib. }
function TMainForm.JumpToError(const Line: string): Boolean;
var
  M: TMatch;
  Name, Path: string;
  Candidates: TArray<string>;
begin
  M := TRegEx.Match(Line, '^FAIL\s+(\S+\.haste)');                // a failed test: open the test itself
  if M.Success and FileExists(TPath.Combine(FRunFolder, M.Groups[1].Value)) then
  begin
    OpenFile(TPath.GetFullPath(TPath.Combine(FRunFolder, M.Groups[1].Value)));
    Exit(True);
  end;
  M := TRegEx.Match(Line, '([^\s:]+\.haste):(\d+)');
  if not M.Success then Exit(False);
  Name := M.Groups[1].Value;
  Candidates := [Name, TPath.Combine(FRunFolder, Name),
    TPath.Combine(TPath.Combine(ExtractFileDir(FHastePy), 'lib'), Name)];
  for Path in Candidates do
    if (Path <> '') and FileExists(Path) then
    begin
      OpenFile(TPath.GetFullPath(Path), M.Groups[2].Value.ToInteger);
      Exit(True);
    end;
  if DirectoryExists(FRunFolder) then           // only then look in subfolders (tests live in tests\errors etc.)
    for Path in TDirectory.GetFiles(FRunFolder, ExtractFileName(Name), TSearchOption.soAllDirectories) do
    begin
      OpenFile(Path, M.Groups[2].Value.ToInteger);
      Exit(True);
    end;
  Result := False;
end;

{ Each run starts on a clean panel, or under the last one's output if Clear the output is off. }
procedure TMainForm.OutputClear;
begin
  if FClearOutput then
    FOutput.Lines.Clear
  else if FOutput.Lines.Count > 0 then
    FOutput.Lines.Add('');
end;

{ Adds a line and keeps the end of the output in view, as a console does. A line holding several lines
  (an error with its cause) is split, so each gets its own colour. }
procedure TMainForm.OutputAdd(const Line: string);
var
  Part: string;
begin
  for Part in Line.Replace(#13#10, #10).Split([#10]) do
    FOutput.Lines.Add(Part);
  FOutput.CaretXY := BufferCoord(1, FOutput.Lines.Count);
  FOutput.EnsureCursorPosVisible;
end;

procedure TMainForm.OutputDblClick(Sender: TObject);
var
  Row: Integer;
begin
  Row := FOutput.CaretY - 1;                    // SynEdit counts lines from 1
  if (Row >= 0) and (Row < FOutput.Lines.Count) then
    JumpToError(FOutput.Lines[Row]);
end;

{ ---- status ---- }

procedure TMainForm.EditorStatus(Sender: TObject; Changes: TSynStatusChanges);
begin
  if (scModified in Changes) and (ActiveTab <> nil) then
    ActiveTab.UpdateCaption;
  UpdateStatus;
end;

procedure TMainForm.UpdateStatus;
var
  Tab: TEditorTab;
begin
  Tab := ActiveTab;
  if Tab = nil then
  begin
    Caption := 'Hasten';
    Exit;
  end;
  FStatus.Panels[0].Text := Format('Line %d, Col %d', [Tab.Editor.CaretY, Tab.Editor.CaretX]);
  if Tab.Modified then FStatus.Panels[1].Text := 'Modified' else FStatus.Panels[1].Text := '';
  if Tab.FileName <> '' then Caption := Tab.FileName + ' - Hasten' else Caption := Tab.Title + ' - Hasten';
end;

procedure TMainForm.PagesChange(Sender: TObject);
begin
  UpdateStatus;
  RefreshWords;                                 // another folder can mean other modules
end;

procedure TMainForm.ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
var
  B: TSpeedButton;
  Item: TMenuItem;
begin
  if Action = FStopAction then                  // once per round of updates: grey out Undo ... Paste
  begin
    UpdateEditItems(FEditMenu);
    for B in FEditButtons do
      for Item in FEditMenu do
        if Item.Tag = B.Tag then B.Enabled := Item.Enabled;
  end;
  FStopAction.Enabled := Running;
  FRunAction.Enabled := not Running and (ActiveTab <> nil);
  FBuildAction.Enabled := FRunAction.Enabled;
  FTestsAction.Enabled := not Running;
  FModuleAction.Enabled := ActiveTab <> nil;
end;

{ ---- commands ---- }

procedure TMainForm.DoNew(Sender: TObject);
begin
  NewTab('');
end;

procedure TMainForm.DoOpen(Sender: TObject);
var
  Dialog: TOpenDialog;
  F: string;
begin
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Filter := HasteFilter;
    Dialog.Options := Dialog.Options + [ofAllowMultiSelect, ofFileMustExist];
    if Dialog.Execute then
      for F in Dialog.Files do
        OpenFile(F);
  finally
    Dialog.Free;
  end;
end;

procedure TMainForm.DoSave(Sender: TObject);
begin
  if ActiveTab <> nil then SaveTab(ActiveTab, False);
end;

procedure TMainForm.DoSaveAs(Sender: TObject);
begin
  if ActiveTab <> nil then SaveTab(ActiveTab, True);
end;

procedure TMainForm.DoCloseTab(Sender: TObject);
begin
  if ActiveTab <> nil then CloseTab(ActiveTab);
  UpdateStatus;
end;

procedure TMainForm.DoQuit(Sender: TObject);
begin
  Close;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  I: Integer;
  Tab: TEditorTab;
begin
  for I := 0 to FPages.PageCount - 1 do
  begin
    Tab := TEditorTab(FPages.Pages[I]);
    if Tab.Modified then
    begin
      FPages.ActivePage := Tab;
      case MessageDlg('Save changes to ' + Tab.Title + '?', mtConfirmation, mbYesNoCancel, 0) of
        mrYes: if not SaveTab(Tab, False) then begin CanClose := False; Exit; end;
        mrCancel: begin CanClose := False; Exit; end;
      end;
    end;
  end;
  SaveSettings;
  CanClose := True;
end;

procedure TMainForm.DoFind(Sender: TObject);
begin
  if (ActiveTab <> nil) and ActiveTab.Editor.SelAvail then
    FFind.FindText := ActiveTab.Editor.SelText;
  FFind.Execute;
end;

procedure TMainForm.FindNext(Sender: TObject);
var
  Options: TSynSearchOptions;
begin
  if ActiveTab = nil then Exit;
  Options := [];
  if frMatchCase in FFind.Options then Include(Options, ssoMatchCase);
  if frWholeWord in FFind.Options then Include(Options, ssoWholeWord);
  if not (frDown in FFind.Options) then Include(Options, ssoBackwards);
  if ActiveTab.Editor.SearchReplace(FFind.FindText, '', Options) = 0 then
    FStatus.Panels[2].Text := '"' + FFind.FindText + '" not found'
  else
    FStatus.Panels[2].Text := '';
end;

procedure TMainForm.DoFindNext(Sender: TObject);
begin
  if FFind.FindText = '' then DoFind(Sender) else FindNext(Sender);
end;

procedure TMainForm.DoGoToLine(Sender: TObject);
var
  S: string;
  N: Integer;
begin
  if ActiveTab = nil then Exit;
  S := ActiveTab.Editor.CaretY.ToString;
  if InputQuery('Go to Line', 'Line number:', S) and TryStrToInt(S, N) then
  begin
    ActiveTab.Editor.GotoLineAndCenter(N);
    ActiveTab.Editor.SetFocus;
  end;
end;

procedure TMainForm.DoRun(Sender: TObject);
begin
  Start('run');
end;

procedure TMainForm.DoBuild(Sender: TObject);
begin
  Start('build');
end;

procedure TMainForm.DoStop(Sender: TObject);
begin
  if FRunner <> nil then FRunner.Stop;
end;

{ Runs tests/run.py beside haste.py. Changed files are saved first, so an edited test is the one that runs;
  output goes to the panel, and double-clicking a FAIL line opens that test. }
procedure TMainForm.DoTests(Sender: TObject);
var
  I: Integer;
  Tab: TEditorTab;
  Tests, Cmd: string;
begin
  if Running or not LocateHastePy then Exit;
  Tests := TPath.Combine(TPath.Combine(ExtractFileDir(FHastePy), 'tests'), 'run.py');
  if not FileExists(Tests) then
  begin
    MessageDlg('There is no test suite at ' + Tests, mtInformation, [mbOK], 0);
    Exit;
  end;
  for I := 0 to FPages.PageCount - 1 do
  begin
    Tab := TEditorTab(FPages.Pages[I]);
    if Tab.Modified and (Tab.FileName <> '') then
      SaveTab(Tab, False);
  end;
  Cmd := Quote(PythonCommand) + ' ' + Quote(Tests);
  FRunFolder := ExtractFileDir(Tests);
  FJumped := True;                              // a failing test should not pull the editor away
  OutputClear;
  OutputAdd('> ' + Cmd);
  FStatus.Panels[2].Text := 'Running the test suite...';
  FRunner := TRunner.Create(Cmd, FRunFolder, RunnerLine, RunnerDone);
end;

procedure TMainForm.DoHastePy(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Title := 'Where is haste.py?';
    Dialog.Filter := 'haste.py|haste.py|Python files (*.py)|*.py';
    Dialog.FileName := FHastePy;
    if Dialog.Execute then
      FHastePy := Dialog.FileName;
  finally
    Dialog.Free;
  end;
end;

end.
