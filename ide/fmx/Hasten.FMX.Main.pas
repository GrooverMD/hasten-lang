unit Hasten.FMX.Main;

{ Hasten for FireMonkey: Windows, macOS and Linux. The window is designed in Hasten.FMX.Main.fmx; editor tabs
  are made in code (Hasten.FMX.Editor). Files, projects (with the Project Manager at the right), Run, Build,
  Stop and Run Tests through haste.py, Project/Module Options, the output with a jump to each error, and
  names coloured from "haste.py words". What is not about the screen is shared with Hasten for VCL
  (ide/common). Settings, Help Insight and Find come next. }

interface

uses
  FMX.Objects,                                  // first: its TPath (a shape) must not hide System.IOUtils.TPath
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math, System.IOUtils, System.IniFiles,
  System.RegularExpressions, System.Actions, System.Generics.Collections, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.DialogService.Sync, FMX.StdCtrls, FMX.Layouts, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox,
  FMX.Controls.Presentation, FMX.TabControl, FMX.Menus, FMX.ActnList, FMX.Text, FMX.TreeView, FMX.Edit, FMX.MultiView, FMX.ListBox, Hasten.Runner,
  Hasten.Project, Hasten.FMX.Editor, Hasten.FMX.Options, Hasten.FMX.Settings, Hasten.FMX.Insight, Hasten.FMX.Text, Syntax.Code.Haste;

type
  TMainForm = class(TForm)
    StyleBook1: TStyleBook;                    // the style of every Hasten window: the dialogs use this one
    MainMenu: TMenuBar;                        // drawn by FMX in the style; the Mac's own menu bar there
    FileMenu: TMenuItem;
    NewItem: TMenuItem;
    OpenItem: TMenuItem;
    SaveItem: TMenuItem;
    SaveAsItem: TMenuItem;
    CloseItem: TMenuItem;
    FileSep: TMenuItem;
    ExitItem: TMenuItem;
    EditMenu: TMenuItem;
    UndoItem: TMenuItem;
    RedoItem: TMenuItem;
    EditSep1: TMenuItem;
    CutItem: TMenuItem;
    CopyItem: TMenuItem;
    PasteItem: TMenuItem;
    DeleteItem: TMenuItem;
    EditSep2: TMenuItem;
    SelectAllItem: TMenuItem;
    EditSep3: TMenuItem;
    FindItem: TMenuItem;
    FindNextItem: TMenuItem;
    FindPrevItem: TMenuItem;
    GoToLineItem: TMenuItem;
    RunMenu: TMenuItem;
    RunItem: TMenuItem;
    BuildItem: TMenuItem;
    StopItem: TMenuItem;
    RunSep1: TMenuItem;
    TestsItem: TMenuItem;
    RunSep2: TMenuItem;
    HastePyItem: TMenuItem;
    ProjectMenu: TMenuItem;
    NewProjectItem: TMenuItem;
    OpenProjectItem: TMenuItem;
    RecentMenu: TMenuItem;
    SaveProjectItem: TMenuItem;
    SaveProjectAsItem: TMenuItem;
    CloseProjectItem: TMenuItem;
    ProjectSep: TMenuItem;
    OptionsItem: TMenuItem;
    ViewMenu: TMenuItem;
    InsightItem: TMenuItem;
    ToolsMenu: TMenuItem;
    SettingsItem: TMenuItem;
    Actions: TActionList;
    NewAction: TAction;
    OpenAction: TAction;
    SaveAction: TAction;
    SaveAsAction: TAction;
    CloseAction: TAction;
    ExitAction: TAction;
    RunAction: TAction;
    BuildAction: TAction;
    StopAction: TAction;
    TestsAction: TAction;
    HastePyAction: TAction;
    NewProjectAction: TAction;
    OpenProjectAction: TAction;
    SaveProjectAction: TAction;
    SaveProjectAsAction: TAction;
    CloseProjectAction: TAction;
    OptionsAction: TAction;
    SettingsAction: TAction;
    InsightAction: TAction;
    FullScreenAction: TAction;
    UndoAction: TAction;
    RedoAction: TAction;
    CutAction: TAction;
    CopyAction: TAction;
    PasteAction: TAction;
    DeleteAction: TAction;
    SelectAllAction: TAction;
    FindAction: TAction;
    FindNextAction: TAction;
    FindPrevAction: TAction;
    GoToLineAction: TAction;
    Ribbon: TTabControl;                       // Freestyler's ribbon: File opens FileView, the others are pages
    FileTab: TTabItem;
    HomeTab: TTabItem;
    HomeBar: TToolBar;                         // the start page: new, open and the recent projects
    EditTab: TTabItem;
    EditBar: TToolBar;
    ProjectTab: TTabItem;
    ProjectBar: TToolBar;
    RunTab: TTabItem;
    RunBar: TToolBar;
    ViewTab: TTabItem;
    ViewBar: TToolBar;
    Body: TLayout;                             // all below the ribbon: the File panel drops down over it
    FileView: TMultiView;                      // the File panel, its master button FileTab
    Backstage: TPanel;
    BackstageTitle: TLabel;
    BackstageRecent: TPanel;
    RecentLabel: TLabel;
    RecentList: TListBox;
    FindBar: TLayout;
    FindLabel: TLabel;
    FindEdit: TEdit;
    MatchCaseCheck: TCheckBox;
    WholeWordCheck: TCheckBox;
    FindPrevButton: TButton;
    FindNextButton: TButton;
    FindStatus: TLabel;
    FindCloseButton: TButton;
    ProjectTree: TTreeView;
    TreeSplitter: TSplitter;
    TreePopup: TPopupMenu;
    TreeOpenItem: TMenuItem;
    TreeProjectFileItem: TMenuItem;
    TreeSep1: TMenuItem;
    TreeNewModuleItem: TMenuItem;
    TreeRenameItem: TMenuItem;
    TreeDeleteItem: TMenuItem;
    TreeSep2: TMenuItem;
    TreeRescanItem: TMenuItem;
    OpenProjectDialog: TOpenDialog;
    EditorArea: TLayout;                       // the tabs, with the find bar at their foot
    Tabs: TTabControl;
    Splitter: TSplitter;
    Output: TMemo;
    StatusBar: TStatusBar;
    StatusLabel: TLabel;
    SetUpTimer: TTimer;
    OpenDialog: TOpenDialog;
    SaveDialog: TSaveDialog;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormResize(Sender: TObject);
    procedure ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
    procedure NewActionExecute(Sender: TObject);
    procedure OpenActionExecute(Sender: TObject);
    procedure SaveActionExecute(Sender: TObject);
    procedure SaveAsActionExecute(Sender: TObject);
    procedure CloseActionExecute(Sender: TObject);
    procedure ExitActionExecute(Sender: TObject);
    procedure RunActionExecute(Sender: TObject);
    procedure BuildActionExecute(Sender: TObject);
    procedure StopActionExecute(Sender: TObject);
    procedure TestsActionExecute(Sender: TObject);
    procedure HastePyActionExecute(Sender: TObject);
    procedure TabsChange(Sender: TObject);
    procedure OutputDblClick(Sender: TObject);
    procedure SetUpTimerTimer(Sender: TObject);
    procedure NewProjectActionExecute(Sender: TObject);
    procedure OpenProjectActionExecute(Sender: TObject);
    procedure SaveProjectActionExecute(Sender: TObject);
    procedure SaveProjectAsActionExecute(Sender: TObject);
    procedure SettingsActionExecute(Sender: TObject);
    procedure InsightActionExecute(Sender: TObject);
    procedure FullScreenActionExecute(Sender: TObject);
    procedure RibbonChange(Sender: TObject);
    procedure RecentListItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
    procedure EditActionExecute(Sender: TObject);
    procedure FindActionExecute(Sender: TObject);
    procedure FindNextActionExecute(Sender: TObject);
    procedure FindPrevActionExecute(Sender: TObject);
    procedure GoToLineActionExecute(Sender: TObject);
    procedure FindEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
    procedure FindCloseButtonClick(Sender: TObject);
    procedure CloseProjectActionExecute(Sender: TObject);
    procedure OptionsActionExecute(Sender: TObject);
    procedure ProjectTreeDblClick(Sender: TObject);
    procedure TreePopupPopup(Sender: TObject);
    procedure TreeOpenItemClick(Sender: TObject);
    procedure TreeProjectFileItemClick(Sender: TObject);
    procedure TreeNewModuleItemClick(Sender: TObject);
    procedure TreeRenameItemClick(Sender: TObject);
    procedure TreeDeleteItemClick(Sender: TObject);
    procedure TreeRescanItemClick(Sender: TObject);
  private
    FIniName: string;
    FHastePy: string;
    FPython: string;
    FRunner, FFinished: TRunner;               // Finished: the last run, freed when the next one ends
    FWordsRunner, FWordsFinished: TRunner;
    FWordLines: TStringList;
    FWordsAgain: Boolean;
    FRunFolder: string;
    FJumped: Boolean;
    FProject: THasteProject;                   // nil: single files
    FTreeFiles: TArray<string>;                // what the Project Manager shows
    FRecent: TArray<string>;
    FOpenAfterRun: string;                     // a project haste.py new is making
    FFontFamily: string;                       // these and the rest are set in Tools > Settings
    FFontSize: Single;
    FLineNumbers: Boolean;
    FTabWidth: Integer;
    FRightEdge: Integer;                       // 0: no margin line
    FTextSize: Integer;                        // the window's text (tabs, tree, labels, dialogs), in pixels
    FClearOutput: Boolean;                     // on each Run, Build and Run Tests
    FReopen: Boolean;                          // last session's files at start
    FInsight: THasteInsight;                   // Help Insight: tips on names under the mouse
    FRecentTiles: TLayout;                     // Home's recent projects, made anew by BuildRecentMenu
    FRibbonPage: TTabItem;                     // the ribbon page on show: File only opens the File panel
    FOptionsButton: TSpeedButton;
    function OpenProject(const Path: string): Boolean;
    function CloseProject: Boolean;
    function CloseAllTabs: Boolean;
    procedure SaveOpenFiles(Ini: TMemIniFile; const Section: string);
    procedure AddRecent(const Path: string);
    procedure BuildRecentMenu;
    procedure RecentClick(Sender: TObject);
    procedure ShowTree;
    procedure Rescan(Force: Boolean = False);
    function SelectedPath: string;
    function SelectedFolder: string;
    function IsModule(const Path: string): Boolean;
    function AskForName(const Title, Start: string; out Value: string): Boolean;
    function SourceOf(const FileName: string): TStringList;
    procedure ProjectOptions;
    procedure ModuleOptions;
    function ModuleTargets(const FileName: string): string;
    function ModuleSwitchArgs(Tab: TEditorTab): string;
    function ActiveTab: TEditorTab;
    function FindTab(const FileName: string): TEditorTab;
    function NewTab: TEditorTab;
    procedure OpenFile(const FileName: string; Line: Integer = 0);
    function SaveTab(Tab: TEditorTab; AskName: Boolean): Boolean;
    function SaveAll: Boolean;
    function CloseTab(Tab: TEditorTab): Boolean;
    function Ask(const Question: string): TModalResult;
    function Running: Boolean;
    function LocateHastePy(AskUser: Boolean): Boolean;
    procedure Start(const Verb: string);
    procedure RunCommand(const Cmd, Folder, Busy: string);
    procedure RunnerLine(const Line: string);
    procedure RunnerDone(ExitCode: Cardinal; Stopped: Boolean);
    function JumpToError(const Line: string): Boolean;
    procedure OutputAdd(const Line: string);
    procedure RefreshWords;
    procedure WordsDone(ExitCode: Cardinal; Stopped: Boolean);
    procedure EditorChanged(Sender: TObject);
    procedure CaretMoved(Sender: TObject; const ACaretPosition: TCaretPosition);
    procedure UpdateStatus;
    procedure ApplySettings(Tab: TEditorTab);
    procedure LoadSettings;
    procedure SaveSettings;
    function EditorFocused: TEditorTab;
    procedure FindAgain(Backwards: Boolean);
    procedure SetUpRibbon;
    procedure WireCaptionButtons;
    procedure FitRibbon;
    procedure BackstageClick(Sender: TObject);
    function ShortCutAction(Key: Word; Shift: TShiftState): TAction;
    procedure LoadStyle;
  public
    procedure KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Single); override;
  end;

var
  MainForm: TMainForm;

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows;                               // so the inline RenameFile and DeleteFile are expanded (H2443)
{$ENDIF}

{$R *.fmx}

const
{$IFDEF MSWINDOWS}
  DefaultPython = 'python';
{$ELSE}
  DefaultPython = 'python3';
{$ENDIF}
{$IFDEF MACOS}
  CmdKey = scCommand;                           // Cmd on a Mac, Ctrl elsewhere
{$ELSE}
  CmdKey = scCtrl;
{$ENDIF}

function Quote(const S: string): string;
begin
  if S.Contains(' ') then Result := '"' + S + '"' else Result := S;
end;

{ ---- the window ---- }

procedure TMainForm.FormCreate(Sender: TObject);
begin
{$IFDEF MSWINDOWS}
  FIniName := TPath.Combine(TPath.Combine(TPath.GetHomePath, 'Hasten'), 'HastenFMX.ini');
{$ELSE}
  FIniName := TPath.Combine(TPath.Combine(TPath.GetHomePath, '.hasten'), 'HastenFMX.ini');
{$ENDIF}
  FWordLines := TStringList.Create;
  FInsight := THasteInsight.Create(Self, Tabs);
  FPython := DefaultPython;
  FFontFamily := MonoFont;
  FFontSize := 14;
  FLineNumbers := True;
  FTabWidth := 2;
  FRightEdge := 80;
  FTextSize := DefaultTextSize;
  FClearOutput := True;
  FReopen := True;
  NewAction.ShortCut := CmdKey or Ord('N');      // shortcuts here, not in the .fmx: Cmd or Ctrl by platform
  OpenAction.ShortCut := CmdKey or Ord('O');
  SaveAction.ShortCut := CmdKey or Ord('S');
  SaveProjectAction.ShortCut := CmdKey or scShift or Ord('S');   // Save All, as in Delphi
  OpenProjectAction.ShortCut := CmdKey or scShift or Ord('O');
  OptionsAction.ShortCut := CmdKey or scShift or vkF11;
  CloseAction.ShortCut := CmdKey or Ord('W');
  RunAction.ShortCut := vkF9;
  BuildAction.ShortCut := CmdKey or vkF9;
  StopAction.ShortCut := CmdKey or vkF2;
  FindAction.ShortCut := CmdKey or Ord('F');    // the edit actions have none: the editors take those keys
  FindNextAction.ShortCut := vkF3;
  FindPrevAction.ShortCut := scShift or vkF3;
  GoToLineAction.ShortCut := CmdKey or Ord('G');
  FullScreenAction.ShortCut := vkF11;
{$IFDEF MACOS}
  MainMenu.UseOSMenu := True;                   // a Mac app's menus belong in the bar at the top of the screen
{$ENDIF}
  LoadStyle;
  SetUpRibbon;
  UseTextSizes(Self);                           // the style's 16-pixel text at Hasten's size
  ShowTree;
  LoadSettings;
  if Tabs.TabCount = 0 then
    NewTab;
  UpdateStatus;
  RefreshWords;
end;

{ Every mouse move reaches the form first, in the coordinates its controls use: Help Insight's only source. }
procedure TMainForm.MouseMove(Shift: TShiftState; X, Y: Single);
begin
  inherited;
  if FInsight <> nil then FInsight.MouseAt(PointF(X, Y));
end;

{ The form moves the focus on Tab before the focused control sees the key, and before OnKeyDown, so Tab in an
  editor is taken here first: it indents (THasteMemo.TabKey). }
procedure TMainForm.KeyDown(var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
var
  Tab: TEditorTab;
  Act: TAction;
begin
  Tab := EditorFocused;
  if (Tab <> nil) and Tab.Memo.TabKey(Key, KeyChar, Shift) then Exit;
{$IFNDEF MACOS}
  Act := ShortCutAction(Key, Shift);            // a Mac's menu bar takes its keys itself
  if Act <> nil then
  begin
    Key := 0;
    KeyChar := #0;
    Act.Update;                                 // enabled as the menus would show it
    if Act.Enabled then Act.Execute;
    Exit;
  end;
{$ENDIF}
  inherited;
end;

{ The tab whose editor has the focus: the memo itself or a part of its presentation. }
function TMainForm.EditorFocused: TEditorTab;
var
  O: TFmxObject;
begin
  Result := ActiveTab;
  if (Result = nil) or (Focused = nil) then Exit(nil);
  O := Focused.GetObject;
  while (O <> nil) and (O <> Result.Memo) do
    O := O.Parent;
  if O = nil then Result := nil;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  if FRunner <> nil then FRunner.Stop;
  if FWordsRunner <> nil then FWordsRunner.Stop;
  FRunner.Free;
  FFinished.Free;
  FWordsRunner.Free;
  FWordsFinished.Free;
  FWordLines.Free;
  FProject.Free;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  I: Integer;
  Tab: TEditorTab;
begin
  for I := 0 to Tabs.TabCount - 1 do
  begin
    Tab := TEditorTab(Tabs.Tabs[I]);
    if Tab.Modified then
    begin
      Tabs.ActiveTab := Tab;
      case Ask('Save changes to ' + Tab.Title + '?') of
        mrYes: if not SaveTab(Tab, False) then begin CanClose := False; Exit; end;
        mrCancel: begin CanClose := False; Exit; end;
      end;
    end;
  end;
  SaveSettings;
  CanClose := True;
end;

function TMainForm.Ask(const Question: string): TModalResult;
begin
  Result := TDialogServiceSync.MessageDialog(Question, TMsgDlgType.mtConfirmation,
    [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo, TMsgDlgBtn.mbCancel], TMsgDlgBtn.mbYes, 0);
end;

procedure TMainForm.ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
var
  S: string;
begin
  WireCaptionButtons;                           // the frame is made again after full screen: its button too
  SaveAction.Enabled := ActiveTab <> nil;
  SaveAsAction.Enabled := ActiveTab <> nil;
  CloseAction.Enabled := ActiveTab <> nil;
  RunAction.Enabled := not Running and ((ActiveTab <> nil) or (FProject <> nil));
  BuildAction.Enabled := RunAction.Enabled;
  StopAction.Enabled := Running;
  TestsAction.Enabled := not Running;
  NewProjectAction.Enabled := not Running;
  SaveProjectAction.Enabled := FProject <> nil;
  SaveProjectAsAction.Enabled := (FProject <> nil) and not Running;
  CloseProjectAction.Enabled := FProject <> nil;
  OptionsAction.Enabled := (FProject <> nil) or (ActiveTab <> nil);
  FindAction.Enabled := ActiveTab <> nil;
  FindNextAction.Enabled := ActiveTab <> nil;
  FindPrevAction.Enabled := ActiveTab <> nil;
  GoToLineAction.Enabled := ActiveTab <> nil;
  if FProject <> nil then S := 'Project &Options...' else S := 'Module &Options...';
  if OptionsAction.Text <> S then
  begin
    OptionsAction.Text := S;
    FOptionsButton.Text := 'Options';           // the ribbon's word, not the action's text
  end;
  Handled := True;
end;

{ The memo of a new tab gets its FMXRichMemo presentation a moment later: set each up once it has. }
procedure TMainForm.SetUpTimerTimer(Sender: TObject);
var
  I: Integer;
  All: Boolean;
begin
  All := True;
  for I := 0 to Tabs.TabCount - 1 do
    if not TEditorTab(Tabs.Tabs[I]).Configure then
      All := False;
  if All then
    SetUpTimer.Enabled := False;
end;

procedure TMainForm.UpdateStatus;
var
  Tab: TEditorTab;
begin
  Tab := ActiveTab;
  if Tab = nil then
    Caption := 'Hasten'
  else if Tab.FileName <> '' then
    Caption := Tab.FileName + ' - Hasten'
  else
    Caption := Tab.Title + ' - Hasten';
  if FProject <> nil then
    Caption := FProject.Name + ' - ' + Caption;
end;

procedure TMainForm.CaretMoved(Sender: TObject; const ACaretPosition: TCaretPosition);
begin
  StatusLabel.Text := Format('Line %d, Col %d', [ACaretPosition.Line + 1, ACaretPosition.Pos + 1]);
end;

{ An edit: aliases added or changed recolour the text. }
procedure TMainForm.EditorChanged(Sender: TObject);
var
  Tab: TEditorTab;
begin
  Tab := TEditorTab(Sender);
  if (Tab = ActiveTab) and TCodeSyntaxHaste.ScanAliases(Tab.Memo.Lines) then
    Tab.Recolour;
end;

procedure TMainForm.TabsChange(Sender: TObject);
begin
  FInsight.Hide;
  if (ActiveTab <> nil) and TCodeSyntaxHaste.ScanAliases(ActiveTab.Memo.Lines) then
    ActiveTab.Recolour;                          // the aliases are those of the file on show
  UpdateStatus;
  if ActiveTab <> nil then
    for var I := 0 to ProjectTree.GlobalCount - 1 do      // the file on show is the one selected
      if SameFileName(ProjectTree.ItemByGlobalIndex(I).TagString, ActiveTab.FileName) then
        ProjectTree.Selected := ProjectTree.ItemByGlobalIndex(I);
  RefreshWords;
end;

{ ---- tabs and files ---- }

function TMainForm.ActiveTab: TEditorTab;
begin
  if Tabs.ActiveTab is TEditorTab then Result := TEditorTab(Tabs.ActiveTab) else Result := nil;
end;

function TMainForm.FindTab(const FileName: string): TEditorTab;
var
  I: Integer;
begin
  for I := 0 to Tabs.TabCount - 1 do
    if SameFileName(TEditorTab(Tabs.Tabs[I]).FileName, FileName) then
      Exit(TEditorTab(Tabs.Tabs[I]));
  Result := nil;
end;

function TMainForm.NewTab: TEditorTab;
begin
  Result := TEditorTab.Create(Tabs);
  Result.OnChange := EditorChanged;
  Result.OnCaret := CaretMoved;
  Result.Parent := Tabs;
  UseTextSize(Result);
  ApplySettings(Result);
  Tabs.ActiveTab := Result;
  SetUpTimer.Enabled := True;
  UpdateStatus;
end;

procedure TMainForm.OpenFile(const FileName: string; Line: Integer);
var
  Tab: TEditorTab;
begin
  Tab := FindTab(FileName);
  if Tab = nil then
  begin
    Tab := ActiveTab;                            // reuse an empty, untouched Untitled tab
    if (Tab = nil) or (Tab.FileName <> '') or Tab.Modified or (Tab.Memo.Lines.Text.Trim <> '') then
      Tab := NewTab;
    Tab.Load(FileName);
  end;
  Tabs.ActiveTab := Tab;
  if Line > 0 then
    Tab.GoToLine(Line);
  TabsChange(nil);
end;

function TMainForm.SaveTab(Tab: TEditorTab; AskName: Boolean): Boolean;
begin
  if AskName or (Tab.FileName = '') then
  begin
    SaveDialog.FileName := Tab.Title;
    if not SaveDialog.Execute then Exit(False);
    Tab.Save(SaveDialog.FileName);
  end
  else
    Tab.Save(Tab.FileName);
  if (FProject <> nil) and SameFileName(Tab.FileName, FProject.FileName) then
    Rescan;                                      // the project file: the heading shows its targets
  UpdateStatus;
  RefreshWords;                                  // a file saved into lib is a new module
  Rescan;
  Result := True;
end;

{ Run and Build work on files, so every changed file is saved first. }
function TMainForm.SaveAll: Boolean;
var
  I: Integer;
  Tab: TEditorTab;
begin
  for I := 0 to Tabs.TabCount - 1 do
  begin
    Tab := TEditorTab(Tabs.Tabs[I]);
    if (Tab.Modified or (Tab.FileName = '')) and ((Tab = ActiveTab) or (Tab.FileName <> '')) then
      if not SaveTab(Tab, False) then Exit(False);
  end;
  Result := True;
end;

function TMainForm.CloseTab(Tab: TEditorTab): Boolean;
begin
  if Tab.Modified then
    case Ask('Save changes to ' + Tab.Title + '?') of
      mrYes: if not SaveTab(Tab, False) then Exit(False);
      mrCancel: Exit(False);
    end;
  Tab.Free;
  UpdateStatus;
  Result := True;
end;

procedure TMainForm.NewActionExecute(Sender: TObject);
begin
  NewTab;
end;

procedure TMainForm.OpenActionExecute(Sender: TObject);
var
  F: string;
begin
  if OpenDialog.Execute then
    for F in OpenDialog.Files do
      OpenFile(F);
end;

procedure TMainForm.SaveActionExecute(Sender: TObject);
begin
  if ActiveTab <> nil then SaveTab(ActiveTab, False);
end;

procedure TMainForm.SaveAsActionExecute(Sender: TObject);
begin
  if ActiveTab <> nil then SaveTab(ActiveTab, True);
end;

procedure TMainForm.CloseActionExecute(Sender: TObject);
begin
  if ActiveTab <> nil then CloseTab(ActiveTab);
end;

procedure TMainForm.ExitActionExecute(Sender: TObject);
begin
  Close;
end;

{ ---- running haste.py ---- }

function TMainForm.Running: Boolean;
begin
  Result := FRunner <> nil;
end;

{ haste.py is found once: next to the program or up to eight folders above it (the repository puts the IDE
  in ide\fmx\Win64\Debug; a macOS app is deeper, in Hasten.app/Contents/MacOS), otherwise the user is asked. }
function TMainForm.LocateHastePy(AskUser: Boolean): Boolean;
var
  Dir: string;
  I: Integer;
begin
  if FileExists(FHastePy) then Exit(True);
  Dir := ExtractFileDir(ParamStr(0));
  for I := 0 to 8 do
  begin
    if FileExists(TPath.Combine(Dir, 'haste.py')) then
    begin
      FHastePy := TPath.Combine(Dir, 'haste.py');
      Exit(True);
    end;
    Dir := ExtractFileDir(Dir);
  end;
  if AskUser then
    HastePyActionExecute(nil);
  Result := FileExists(FHastePy);
end;

procedure TMainForm.HastePyActionExecute(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Title := 'Where is haste.py?';
    Dialog.Filter := 'haste.py|haste.py|Python files (*.py)|*.py';
    if Dialog.Execute then
    begin
      FHastePy := Dialog.FileName;
      RefreshWords;
    end;
  finally
    Dialog.Free;
  end;
end;

{ With a project open, its program, whichever tab is on show; haste.py reads its targets and switch values.
  Otherwise the file on show, with its Module Options. }
procedure TMainForm.Start(const Verb: string);
var
  Tab: TEditorTab;
  Cmd, Extra: string;
begin
  Tab := ActiveTab;
  if Running or ((Tab = nil) and (FProject = nil)) or not SaveAll or not LocateHastePy(True) then Exit;
  if FProject <> nil then
  begin
    RunCommand(Quote(FPython) + ' ' + Quote(FHastePy) + ' ' + Verb + ' ' + Quote(FProject.FileName),
      FProject.Folder, 'Running ' + FProject.Name + '...');
    Exit;
  end;
  Cmd := Quote(FPython) + ' ' + Quote(FHastePy) + ' ' + Verb + ' ' + Quote(Tab.FileName);
  if Verb = 'build' then Extra := ModuleTargets(Tab.FileName) else Extra := '';
  if Extra <> '' then Cmd := Cmd + ' --target ' + Extra;
  if Verb = 'run' then Extra := ModuleSwitchArgs(Tab) else Extra := '';
  if Extra <> '' then Cmd := Cmd + ' ' + Extra;
  RunCommand(Cmd, ExtractFileDir(Tab.FileName), 'Running ' + Tab.Title + '...');
end;

procedure TMainForm.RunCommand(const Cmd, Folder, Busy: string);
begin
  FRunFolder := Folder;
  FJumped := False;
  if FClearOutput then
    Output.Lines.Clear
  else if Output.Lines.Count > 0 then
    OutputAdd('');
  OutputAdd('> ' + Cmd);
  StatusLabel.Text := Busy;
  FRunner := TRunner.Create(Cmd, Folder, RunnerLine, RunnerDone);
end;

procedure TMainForm.RunActionExecute(Sender: TObject);
begin
  Start('run');
end;

procedure TMainForm.BuildActionExecute(Sender: TObject);
begin
  Start('build');
end;

procedure TMainForm.StopActionExecute(Sender: TObject);
begin
  if FRunner <> nil then FRunner.Stop;
end;

procedure TMainForm.TestsActionExecute(Sender: TObject);
var
  Dir: string;
begin
  if Running or not LocateHastePy(True) then Exit;
  Dir := ExtractFileDir(FHastePy);
  RunCommand(Quote(FPython) + ' ' + Quote(TPath.Combine(TPath.Combine(Dir, 'tests'), 'run.py')),
    TPath.Combine(Dir, 'tests'), 'Running the tests...');
end;

procedure TMainForm.RunnerLine(const Line: string);
begin
  OutputAdd(Line);
  if Line.TrimLeft.StartsWith('specialised:') then
    FInsight.Names.LoadCompiled(Line);          // the types each function was compiled with, for the tips
  if Line.StartsWith('Cannot start: ') then
    OutputAdd('Python could not be started. Check that "' + FPython + ' --version" works in a terminal.');
  if not FJumped and (Line.StartsWith('error:') or Line.StartsWith('  in ')) then
    FJumped := JumpToError(Line);               // straight to the first compiler or run-time error
end;

procedure TMainForm.RunnerDone(ExitCode: Cardinal; Stopped: Boolean);
begin
  if Stopped then
    OutputAdd('[stopped]')
  else
    OutputAdd(Format('[finished, exit code %d]', [ExitCode]));
  StatusLabel.Text := '';
  FFinished.Free;                                // the run before this one: its thread ended long ago
  FFinished := FRunner;                          // this one is still inside its own callback
  FRunner := nil;
  if FOpenAfterRun <> '' then                    // haste.py new has made a project: open it
  begin
    if (ExitCode = 0) and not Stopped and FileExists(FOpenAfterRun) then
      OpenProject(FOpenAfterRun);
    FOpenAfterRun := '';
  end;
  RefreshWords;
end;

procedure TMainForm.OutputAdd(const Line: string);
begin
  for var Part in Line.Replace(#13#10, #10).Split([#10]) do
    Output.Lines.Add(Part);
  Output.GoToTextEnd;
end;

procedure TMainForm.OutputDblClick(Sender: TObject);
var
  Row: Integer;
begin
  Row := Output.CaretPosition.Line;
  if (Row >= 0) and (Row < Output.Lines.Count) then
    JumpToError(Output.Lines[Row]);
end;

{ Compiler errors look like  error: fractal.haste:12: message ; run-time errors are followed by
  in fractal.haste:12 . The file is looked for next to the program, then in lib, then below the folder. }
function TMainForm.JumpToError(const Line: string): Boolean;
var
  M: TMatch;
  Given, Path: string;
  Candidates: TArray<string>;
begin
  M := TRegEx.Match(Line, '^FAIL\s+(\S+\.haste)');            // a failed test: open the test itself
  if M.Success and FileExists(TPath.Combine(FRunFolder, M.Groups[1].Value)) then
  begin
    OpenFile(TPath.GetFullPath(TPath.Combine(FRunFolder, M.Groups[1].Value)));
    Exit(True);
  end;
  M := TRegEx.Match(Line, '([^\s:]+\.haste):(\d+)');
  if not M.Success then Exit(False);
  Given := M.Groups[1].Value;
  Candidates := [Given, TPath.Combine(FRunFolder, Given),
    TPath.Combine(TPath.Combine(ExtractFileDir(FHastePy), 'lib'), Given)];
  for Path in Candidates do
    if (Path <> '') and FileExists(Path) then
    begin
      OpenFile(TPath.GetFullPath(Path), M.Groups[2].Value.ToInteger);
      Exit(True);
    end;
  if DirectoryExists(FRunFolder) then
    for Path in TDirectory.GetFiles(FRunFolder, ExtractFileName(Given), TSearchOption.soAllDirectories) do
    begin
      OpenFile(Path, M.Groups[2].Value.ToInteger);
      Exit(True);
    end;
  Result := False;
end;

{ ---- names to colour: "haste.py words", for the file on show ---- }

procedure TMainForm.RefreshWords;
var
  Cmd: string;
begin
  if not LocateHastePy(False) then Exit;         // never ask for haste.py just to colour words
  if FWordsRunner <> nil then
  begin
    FWordsAgain := True;
    Exit;
  end;
  Cmd := Quote(FPython) + ' ' + Quote(FHastePy) + ' words';
  if (ActiveTab <> nil) and (ActiveTab.FileName <> '') then
    Cmd := Cmd + ' ' + Quote(ActiveTab.FileName);
  FWordLines.Clear;
  FWordsRunner := TRunner.Create(Cmd, ExtractFileDir(FHastePy),
    procedure(const Line: string) begin FWordLines.Add(Line) end, WordsDone);
end;

procedure TMainForm.WordsDone(ExitCode: Cardinal; Stopped: Boolean);
var
  I: Integer;
begin
  if (ExitCode = 0) and not Stopped then
  begin
    TCodeSyntaxHaste.LoadWords(FWordLines);
    FInsight.Names.LoadWords(FWordLines);
    if ActiveTab <> nil then
      TCodeSyntaxHaste.ScanAliases(ActiveTab.Memo.Lines);
    for I := 0 to Tabs.TabCount - 1 do
      TEditorTab(Tabs.Tabs[I]).Recolour;
  end;
  FWordsFinished.Free;
  FWordsFinished := FWordsRunner;
  FWordsRunner := nil;
  if FWordsAgain then
  begin
    FWordsAgain := False;
    RefreshWords;
  end;
end;

{ ---- settings: HastenFMX.ini in the user's Hasten folder ---- }

{ The editor settings on one tab, or with nil on every tab and the output (a point smaller). }
procedure TMainForm.ApplySettings(Tab: TEditorTab);
var
  I: Integer;
begin
  if Tab <> nil then
  begin
    Tab.FontFamily := FFontFamily;
    Tab.FontSize := FFontSize;
    Tab.LineNumbers := FLineNumbers;
    Tab.TabWidth := FTabWidth;
    Tab.RightEdge := FRightEdge;
    Exit;
  end;
  for I := 0 to Tabs.TabCount - 1 do
    ApplySettings(TEditorTab(Tabs.Tabs[I]));
  Hasten.FMX.Text.TextSize := FTextSize;        // the window's text: the form's controls, tabs and tree
  UseTextSizes(Self);
  UseTextSizes(ProjectTree);
  for I := 0 to Tabs.TabCount - 1 do
    UseTextSize(Tabs.Tabs[I]);
  Output.TextSettings.Font.Family := FFontFamily;
  Output.TextSettings.Font.Size := FFontSize - 1;
end;

{ The style, into StyleBook1, which every Hasten window uses: the first .style file beside the program, or
  else the first in a styles folder above it (ide/fmx/styles/HasteSlate.style, Hasten's own, when it runs from
  where Delphi built it). The StyleBook stays empty in the designer, so no style is kept in the .fmx. }
procedure TMainForm.LoadStyle;
var
  Folder: string;
  Files: TArray<string>;
  Level: Integer;
begin
  Folder := ExtractFileDir(ParamStr(0));
  Files := TDirectory.GetFiles(Folder, '*.style');
  Level := 0;
  while (Length(Files) = 0) and (Level < 5) and (ExtractFileDir(Folder) <> Folder) do
  begin
    Folder := ExtractFileDir(Folder);
    if DirectoryExists(TPath.Combine(Folder, 'styles')) then
      Files := TDirectory.GetFiles(TPath.Combine(Folder, 'styles'), '*.style');
    Inc(Level);
  end;
  if Length(Files) = 0 then Exit;
  TArray.Sort<string>(Files);
  try
    StyleBook1.LoadFromFile(Files[0]);
  except
    on E: Exception do
      OutputAdd('Could not load the style ' + Files[0] + ': ' + E.Message);
  end;
end;

{ ---- the ribbon (Freestyler's) ----
  Pages of large buttons in groups, each on an action: a picture (on Windows, a character of its icon font,
  Segoe MDL2 Assets; macOS and Linux have none, so there only the name) above its name. The buttons never take
  the focus, so the edit buttons act on the editor or box that has it. File is not a page: it opens FileView,
  the File panel, with the file commands and the recent projects. }

type
  TRibbonItem = record
    Action: TAction;
    Glyph: Char;
    Name: string;
  end;

{ A shortcut as a hint shows it: Ctrl+Shift+S, F9 (Cmd on a Mac). Letters, digits and F1-F12 are all Hasten uses. }
function KeysText(SC: TShortCut): string;
var
  Key: Word;
begin
  Result := '';
{$IFDEF MACOS}
  if SC and scCommand <> 0 then Result := Result + 'Cmd+';
{$ENDIF}
  if SC and scCtrl <> 0 then Result := Result + 'Ctrl+';
  if SC and scShift <> 0 then Result := Result + 'Shift+';
  if SC and scAlt <> 0 then Result := Result + 'Alt+';
  Key := SC and $FF;
  if (Key >= vkF1) and (Key <= vkF12) then
    Result := Result + 'F' + (Key - vkF1 + 1).ToString
  else if CharInSet(Char(Key), ['0'..'9', 'A'..'Z']) then
    Result := Result + Char(Key)
  else
    Result := '';
end;

function RB(Action: TAction; Glyph: Char; const Name: string): TRibbonItem;
begin
  Result.Action := Action;
  Result.Glyph := Glyph;
  Result.Name := Name;
end;

procedure TMainForm.SetUpRibbon;
var
  Y: Single;                                    // the File panel's next command, top down

  { A page: groups of buttons left to right, each group named below its buttons, a line between groups. An
    item with no action starts a group, its Name the group's. Position.X puts them in order (Align Left goes
    by it), so they are made as they come. }
  function Page(Bar: TToolBar; const Items: array of TRibbonItem): TLayout;
  var
    I, N: Integer;
    X: Single;
    B: TSpeedButton;
    Group: TLayout;
    Caption: TLabel;
    Line: TPanel;
    Icon: TText;
  begin
    X := 0;
    Group := nil;
    N := 0;
    for I := 0 to High(Items) do
      if Items[I].Action = nil then
      begin
        if Group <> nil then
        begin
          Group.Width := N * 65;
          Line := TPanel.Create(Self);
          Line.StyleLookup := 'ribbonseparatorstyle';
          Line.Align := TAlignLayout.Left;
          Line.Width := 1;
          Line.Margins.Rect := RectF(6, 4, 6, 4);
          X := X + 100;
          Line.Position.X := X;
          Line.Parent := Bar;
        end;
        Group := TLayout.Create(Self);
        Group.Align := TAlignLayout.Left;
        X := X + 100;
        Group.Position.X := X;
        Group.Parent := Bar;
        Caption := TLabel.Create(Self);           // the group's name, dim, under its buttons
        Caption.Align := TAlignLayout.Bottom;
        Caption.Height := 16;
        Caption.Text := Items[I].Name;
        Caption.StyledSettings := Caption.StyledSettings - [TStyledSetting.FontColor];
        Caption.TextSettings.FontColor := $FFA8B3C2;
        Caption.TextSettings.HorzAlign := TTextAlign.Center;
        Caption.Parent := Group;
        N := 0;
      end
      else
      begin
        B := TSpeedButton.Create(Self);
        B.StyleLookup := 'ribbonbuttonstyle';
        B.Action := Items[I].Action;
        B.Text := Items[I].Name;
        B.TagString := Items[I].Name;            // FitRibbon takes the name away when room is short
        B.Align := TAlignLayout.Left;
        B.Width := 64;
        B.Margins.Left := 1;
        B.Position.X := N * 100;
        B.Hint := Items[I].Action.Text.Replace('&', '');
        if Items[I].Action.ShortCut <> 0 then
          B.Hint := B.Hint + ' (' + KeysText(Items[I].Action.ShortCut) + ')';
        B.ShowHint := True;
        B.StaysPressed := Items[I].Action.AutoCheck;  // Help Insight shows whether it is on
        B.Parent := Group;
{$IFDEF MSWINDOWS}
        Icon := TText.Create(B);
        Icon.Parent := B;
        Icon.Align := TAlignLayout.Client;
        Icon.Margins.Bottom := 20;
        Icon.HitTest := False;
        Icon.Text := Items[I].Glyph;
        Icon.TextSettings.Font.Family := 'Segoe MDL2 Assets';
        Icon.TextSettings.Font.Size := 20;
        Icon.TextSettings.FontColor := EditorText;
        B.TagObject := Icon;
{$ENDIF}
        if Items[I].Action = OptionsAction then FOptionsButton := B;
        Inc(N);
      end;
    if Group <> nil then Group.Width := N * 65;
    Result := Group;
  end;

  { A File panel command, or with no action a line between commands. Align Top and Bottom stack by
    Position.Y, so they are made top down with Y counting up. }
  procedure Command(Action: TAction; Glyph: Char; const Name: string; Align: TAlignLayout);
  var
    B: TSpeedButton;
    Icon: TText;
    Line: TPanel;
  begin
    Y := Y + 10;
    if Action = nil then
    begin
      Line := TPanel.Create(Self);
      Line.StyleLookup := 'ribbonseparatorstyle';
      Line.Align := Align;
      Line.Height := 1;
      Line.Margins.Rect := RectF(20, 8, 20, 8);
      Line.Position.Y := Y;
      Line.Parent := Backstage;
      Exit;
    end;
    B := TSpeedButton.Create(Self);
    B.StyleLookup := 'backstagebuttonstyle';
    B.Action := Action;
    B.Text := Name;
    B.Align := Align;
    B.Height := 42;
    B.Position.Y := Y;
    B.OnClick := BackstageClick;               // closes the panel, then runs the action
    B.Parent := Backstage;
{$IFDEF MSWINDOWS}
    Icon := TText.Create(B);
    Icon.Parent := B;
    Icon.Align := TAlignLayout.Left;
    Icon.Width := 48;
    Icon.HitTest := False;
    Icon.Text := Glyph;
    Icon.TextSettings.Font.Family := 'Segoe MDL2 Assets';
    Icon.TextSettings.Font.Size := 18;
    Icon.TextSettings.FontColor := EditorText;
{$ENDIF}
  end;

const
  FindGlyphs: array[0..2] of Char = (#$E70E, #$E70D, #$E8BB);    // up, down, close (Segoe MDL2 Assets)
  FindChars: array[0..2] of Char = (#$25B2, #$25BC, #$2715);
  FindHints: array[0..2] of string = ('Previous (Shift+F3)', 'Next (F3)', 'Close (Esc)');
var
  FindButtons: TArray<TButton>;
  I: Integer;
begin
  Y := 100;                                     // below the File panel's title
  FRecentTiles := Page(HomeBar, [RB(nil, ' ', 'Project'), RB(NewProjectAction, #$E710, 'New'),
    RB(OpenProjectAction, #$E838, 'Open'), RB(nil, ' ', 'Recent Projects')]);   // BuildRecentMenu fills it
  Page(EditBar, [RB(nil, ' ', 'Undo'), RB(UndoAction, #$E7A7, 'Undo'), RB(RedoAction, #$E7A6, 'Redo'),
    RB(nil, ' ', 'Clipboard'), RB(CutAction, #$E8C6, 'Cut'), RB(CopyAction, #$E8C8, 'Copy'),
    RB(PasteAction, #$E77F, 'Paste'), RB(SelectAllAction, #$E8B3, 'Select All'),
    RB(nil, ' ', 'Find'), RB(FindAction, #$E721, 'Find'), RB(FindNextAction, #$E72A, 'Next'),
    RB(FindPrevAction, #$E72B, 'Previous'), RB(GoToLineAction, #$E8FD, 'Go to Line')]);
  Page(ProjectBar, [RB(nil, ' ', 'Project'), RB(NewProjectAction, #$E710, 'New'), RB(OpenProjectAction, #$E838, 'Open'),
    RB(SaveProjectAction, #$E78C, 'Save'), RB(SaveProjectAsAction, #$E792, 'Save As'),
    RB(CloseProjectAction, #$E711, 'Close'), RB(nil, ' ', 'Build'), RB(OptionsAction, #$E9E9, 'Options')]);
  Page(RunBar, [RB(nil, ' ', 'Run'), RB(RunAction, #$E768, 'Run'), RB(BuildAction, #$E90F, 'Build'),
    RB(StopAction, #$E71A, 'Stop'), RB(nil, ' ', 'Test'), RB(TestsAction, #$E9D5, 'Tests'),
    RB(nil, ' ', 'Haste'), RB(HastePyAction, #$E8B7, 'haste.py')]);
  Page(ViewBar, [RB(nil, ' ', 'Show'), RB(InsightAction, #$E946, 'Insight'), RB(FullScreenAction, #$E740, 'Full Screen'),
    RB(nil, ' ', 'Hasten'), RB(SettingsAction, #$E713, 'Settings')]);
  // the find bar's buttons: pictures, the words in their hints
  FindButtons := [FindPrevButton, FindNextButton, FindCloseButton];
  for I := 0 to High(FindButtons) do
  begin
{$IFDEF MSWINDOWS}
    FindButtons[I].StyledSettings := FindButtons[I].StyledSettings - [TStyledSetting.Family, TStyledSetting.Size];
    FindButtons[I].TextSettings.Font.Family := 'Segoe MDL2 Assets';
    FindButtons[I].TextSettings.Font.Size := 11;
    FindButtons[I].Text := FindGlyphs[I];
{$ELSE}
    FindButtons[I].Text := FindChars[I];
{$ENDIF}
    FindButtons[I].Hint := FindHints[I];
    FindButtons[I].ShowHint := True;
  end;
  // the File panel, top down; Align Top stacks the last made lowest, Bottom the last made highest
  Command(NewAction, #$E8A5, 'New', TAlignLayout.Top);
  Command(OpenAction, #$E8E5, 'Open...', TAlignLayout.Top);
  Command(nil, ' ', '', TAlignLayout.Top);
  Command(SaveAction, #$E74E, 'Save', TAlignLayout.Top);
  Command(SaveAsAction, #$E792, 'Save As...', TAlignLayout.Top);
  Command(nil, ' ', '', TAlignLayout.Top);
  Command(CloseAction, #$E711, 'Close', TAlignLayout.Top);
  Command(nil, ' ', '', TAlignLayout.Bottom);
  Command(SettingsAction, #$E713, 'Settings', TAlignLayout.Bottom);
  Command(ExitAction, #$E7E8, 'Exit', TAlignLayout.Bottom);
  FRibbonPage := HomeTab;
  Ribbon.ActiveTab := HomeTab;
  FitRibbon;
{$IFNDEF MACOS}
  MainMenu.Visible := False;                    // the ribbon has it all; a Mac keeps its menus in the menu bar
{$ENDIF}
end;

{ Full screen: no title bar or edges; F11 or the ribbon's View > Full Screen comes back. }
procedure TMainForm.FullScreenActionExecute(Sender: TObject);
begin
  FullScreen := not FullScreen;
end;

{ The frame (HasteSlate's windowborderstyle) has a fullscreen button beside FMX's own three, and its maximise
  button shows restore's picture while the window is maximised. FMX does not know
  it, so it is found in the frame by its style name and given the Full Screen action. Leaving full screen makes
  the frame, and the button, anew, so this looks each time the actions are updated and connects a new one. }
procedure TMainForm.WireCaptionButtons;

  function Find(Root: TFmxObject; const Name: string): TFmxObject;
  var
    I: Integer;
  begin
    Result := nil;
    for I := 0 to Root.ChildrenCount - 1 do
    begin
      if SameText(Root.Children[I].StyleName, Name) then Exit(Root.Children[I]);
      Result := Find(Root.Children[I], Name);
      if Result <> nil then Exit;
    end;
  end;

const
  MaxGlyph: array[Boolean] of Char = (#$E922, #$E923);   // maximise; restore (Segoe MDL2 Assets)
var
  Button, Glyph: TFmxObject;
begin
  if not (TObject(Border.WindowBorder) is TFmxObject) then Exit;
  Button := Find(TFmxObject(Border.WindowBorder), 'max');     // restore's picture while maximised
  if Button <> nil then
  begin
    Glyph := Find(Button, 'glyph');
    if (Glyph is TText) and (TText(Glyph).Text <> MaxGlyph[WindowState = TWindowState.wsMaximized]) then
      TText(Glyph).Text := MaxGlyph[WindowState = TWindowState.wsMaximized];
  end;
  Button := Find(TFmxObject(Border.WindowBorder), 'fullscreen');
  if (Button is TSpeedButton) and not Assigned(TSpeedButton(Button).OnClick) then
  begin
    TSpeedButton(Button).OnClick := FullScreenActionExecute;
    TSpeedButton(Button).Hint := 'Full Screen (F11)';
    TSpeedButton(Button).ShowHint := True;
  end;
end;

{ When a page's buttons are wider than the window, they shrink to their pictures alone (on Windows; elsewhere
  there are no pictures), the names in their hints; with room again, the names come back. }
procedure TMainForm.FitRibbon;
{$IFDEF MSWINDOWS}
var
  Bars: TArray<TToolBar>;
  Bar: TToolBar;
  Group, Child: TFmxObject;
  Need: Single;
  Compact: Boolean;
  I, J: Integer;
begin
  Bars := [HomeBar, EditBar, ProjectBar, RunBar, ViewBar];
  for Bar in Bars do
  begin
    Need := 0;                                  // the full width: 65 a button, 13 a line
    for I := 0 to Bar.ChildrenCount - 1 do
    begin
      Group := Bar.Children[I];
      if Group = FRecentTiles then
        Need := Need + FRecentTiles.Width
      else if Group is TLayout then
        for J := 0 to Group.ChildrenCount - 1 do
          if Group.Children[J] is TSpeedButton then Need := Need + 65;
      if Group is TPanel then Need := Need + 13;
    end;
    Compact := Need > Ribbon.Width - 12;
    for I := 0 to Bar.ChildrenCount - 1 do
    begin
      Group := Bar.Children[I];
      if not (Group is TLayout) or (Group = FRecentTiles) then Continue;   // the tiles keep their size
      var N := 0;
      for J := 0 to Group.ChildrenCount - 1 do
      begin
        Child := Group.Children[J];
        if not (Child is TSpeedButton) then Continue;
        Inc(N);
        if Compact then
        begin
          TSpeedButton(Child).Text := '';
          TSpeedButton(Child).Width := 36;
          if TSpeedButton(Child).TagObject is TText then TText(TSpeedButton(Child).TagObject).Margins.Bottom := 0;
        end
        else
        begin
          TSpeedButton(Child).Text := TSpeedButton(Child).TagString;
          TSpeedButton(Child).Width := 64;
          if TSpeedButton(Child).TagObject is TText then TText(TSpeedButton(Child).TagObject).Margins.Bottom := 20;
        end;
      end;
      if Compact then TLayout(Group).Width := N * 37 else TLayout(Group).Width := N * 65;
    end;
  end;
end;
{$ELSE}
begin
end;
{$ENDIF}

procedure TMainForm.FormResize(Sender: TObject);
begin
  if HomeBar <> nil then FitRibbon;
end;

{ File is the File panel's master button, not a page: the page on show stays. }
procedure TMainForm.RibbonChange(Sender: TObject);
begin
  if Ribbon.ActiveTab = FileTab then
    Ribbon.ActiveTab := FRibbonPage
  else if Ribbon.ActiveTab <> nil then
    FRibbonPage := Ribbon.ActiveTab;
end;

procedure TMainForm.BackstageClick(Sender: TObject);
var
  Action: TBasicAction;
begin
  Action := TSpeedButton(Sender).Action;
  FileView.HideMaster;
  if Action <> nil then Action.Execute;
end;

procedure TMainForm.RecentListItemClick(const Sender: TCustomListBox; const Item: TListBoxItem);
begin
  FileView.HideMaster;
  RecentClick(Item);                            // its Tag is the index in FRecent, as a Recent Projects item's
end;

{ The action whose key this is: with the menus gone from the window, Hasten takes the shortcuts itself. }
function TMainForm.ShortCutAction(Key: Word; Shift: TShiftState): TAction;
var
  SC: TShortCut;
  I: Integer;
begin
  Result := nil;
  if Key = 0 then Exit;
  SC := Key;
  if ssShift in Shift then SC := SC or scShift;
  if ssCtrl in Shift then SC := SC or scCtrl;
  if ssAlt in Shift then SC := SC or scAlt;
  if ssCommand in Shift then SC := SC or scCommand;
  for I := 0 to Actions.ActionCount - 1 do
    if (Actions.Actions[I] is TAction) and (TAction(Actions.Actions[I]).ShortCut = SC) then
      Exit(TAction(Actions.Actions[I]));
end;

{ ---- Edit: on the editor or edit box with the focus (the output too); the keys are the controls' own ---- }

procedure TMainForm.EditActionExecute(Sender: TObject);
var
  O: TFmxObject;
begin
  if Focused = nil then Exit;
  O := Focused.GetObject;
  while (O <> nil) and not (O is TCustomMemo) and not (O is TCustomEdit) do
    O := O.Parent;
  if O is TCustomMemo then
    case TComponent(Sender).Tag of
      1: TCustomMemo(O).Undo;
      2: if (ActiveTab <> nil) and (O = ActiveTab.Memo) then ActiveTab.Redo;
      3: TCustomMemo(O).CutToClipboard;
      4: TCustomMemo(O).CopyToClipboard;
      5: TCustomMemo(O).PasteFromClipboard;
      6: TCustomMemo(O).DeleteSelection;
      7: TCustomMemo(O).SelectAll;
    end
  else if O is TCustomEdit then
    case TComponent(Sender).Tag of
      3: TCustomEdit(O).CutToClipboard;
      4: TCustomEdit(O).CopyToClipboard;
      5: TCustomEdit(O).PasteFromClipboard;
      7: TCustomEdit(O).SelectAll;
    end;
end;

{ ---- Find: a bar above the editor; Enter finds the next, Shift+Enter the one before, Esc closes it ---- }

procedure TMainForm.FindActionExecute(Sender: TObject);
begin
  if ActiveTab = nil then Exit;
  if ActiveTab.SelectedLineText <> '' then
    FindEdit.Text := ActiveTab.SelectedLineText;
  FindStatus.Text := '';
  FindBar.Visible := True;
  FindEdit.SetFocus;
  FindEdit.SelectAll;
end;

procedure TMainForm.FindNextActionExecute(Sender: TObject);
begin
  FindAgain(False);
end;

procedure TMainForm.FindPrevActionExecute(Sender: TObject);
begin
  FindAgain(True);
end;

procedure TMainForm.FindAgain(Backwards: Boolean);
var
  Wrapped: Boolean;
begin
  if ActiveTab = nil then Exit;
  if FindEdit.Text = '' then
  begin
    FindActionExecute(nil);
    Exit;
  end;
  if ActiveTab.Find(FindEdit.Text, MatchCaseCheck.IsChecked, WholeWordCheck.IsChecked, Backwards, Wrapped) then
  begin
    if Wrapped then FindStatus.Text := 'Wrapped round' else FindStatus.Text := '';
  end
  else
    FindStatus.Text := '"' + FindEdit.Text + '" not found';
  StatusLabel.Text := FindStatus.Text;
end;

procedure TMainForm.FindEditKeyDown(Sender: TObject; var Key: Word; var KeyChar: WideChar; Shift: TShiftState);
begin
  case Key of
    vkReturn:
      begin
        FindAgain(ssShift in Shift);
        Key := 0;
      end;
    vkEscape:
      begin
        FindCloseButtonClick(nil);
        Key := 0;
      end;
  end;
end;

procedure TMainForm.FindCloseButtonClick(Sender: TObject);
begin
  FindBar.Visible := False;
  if (ActiveTab <> nil) and ActiveTab.Memo.CanFocus then
    ActiveTab.Memo.SetFocus;
end;

procedure TMainForm.GoToLineActionExecute(Sender: TObject);
var
  Values: TArray<string>;
begin
  if ActiveTab = nil then Exit;
  Values := [(ActiveTab.Memo.CaretPosition.Line + 1).ToString];
  if TDialogServiceSync.InputQuery('Go to Line', [Format('Line (1 - %d):', [ActiveTab.Memo.Lines.Count])],
    Values) then
    ActiveTab.GoToLine(StrToIntDef(Values[0].Trim, 0));
end;

procedure TMainForm.InsightActionExecute(Sender: TObject);
begin
  FInsight.Enabled := InsightAction.Checked;    // AutoCheck: already toggled when this runs
end;

procedure TMainForm.SettingsActionExecute(Sender: TObject);
var
  Dialog: TSettingsForm;
begin
  Dialog := TSettingsForm.Create(nil);
  try
    Dialog.FontFamily := FFontFamily;
    Dialog.FontSize := FFontSize;
    Dialog.LineNumbers := FLineNumbers;
    Dialog.TabWidth := FTabWidth;
    Dialog.RightEdge := FRightEdge;
    Dialog.TextSize := FTextSize;
    Dialog.Python := FPython;
    Dialog.HastePy := FHastePy;
    Dialog.ClearOutput := FClearOutput;
    Dialog.Reopen := FReopen;
    if not Dialog.Execute then Exit;
    if Dialog.FontFamily <> '' then FFontFamily := Dialog.FontFamily;
    FFontSize := Dialog.FontSize;
    FLineNumbers := Dialog.LineNumbers;
    FTabWidth := Dialog.TabWidth;
    FRightEdge := Dialog.RightEdge;
    FTextSize := Dialog.TextSize;
    FPython := Dialog.Python;
    if FPython = '' then FPython := DefaultPython;
    FClearOutput := Dialog.ClearOutput;
    FReopen := Dialog.Reopen;
    if not SameFileName(Dialog.HastePy, FHastePy) then
    begin
      FHastePy := Dialog.HastePy;
      RefreshWords;                             // another haste.py may know other words
    end;
  finally
    Dialog.Free;
  end;
  ApplySettings(nil);
  SaveSettings;
end;

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
    FPython := Ini.ReadString('Haste', 'Python', DefaultPython);
    FFontFamily := Ini.ReadString('Editor', 'FontFamily', FFontFamily);
    FFontSize := Ini.ReadInteger('Editor', 'FontSize', Round(FFontSize));   // whole points, whatever the locale
    FLineNumbers := Ini.ReadBool('Editor', 'LineNumbers', FLineNumbers);
    FTabWidth := Ini.ReadInteger('Editor', 'TabWidth', FTabWidth);
    FRightEdge := Ini.ReadInteger('Editor', 'RightEdge', FRightEdge);
    FTextSize := Ini.ReadInteger('Window', 'TextSize', FTextSize);
    FClearOutput := Ini.ReadBool('Run', 'ClearOutput', FClearOutput);
    FReopen := Ini.ReadBool('Start', 'Reopen', FReopen);
    InsightAction.Checked := Ini.ReadBool('View', 'HelpInsight', True);
    InsightActionExecute(nil);
    ApplySettings(nil);
    BuildRecentMenu;
    if not FReopen then Exit;
    if FileExists(Ini.ReadString('Session', 'Project', '')) then
      OpenProject(Ini.ReadString('Session', 'Project', ''))    // it reopens its own files
    else
    begin
      Ini.ReadSectionValues('Open', Files);
      for I := 0 to Files.Count - 1 do             // the files that were open last time
        if FileExists(Files.ValueFromIndex[I]) then
          OpenFile(Files.ValueFromIndex[I]);
    end;
  finally
    Files.Free;
    Ini.Free;
  end;
end;

procedure TMainForm.SaveSettings;
var
  Ini: TMemIniFile;
begin
  ForceDirectories(ExtractFileDir(FIniName));
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  try
    Ini.WriteString('Haste', 'HastePy', FHastePy);
    Ini.WriteString('Haste', 'Python', FPython);
    Ini.WriteString('Editor', 'FontFamily', FFontFamily);
    Ini.WriteInteger('Editor', 'FontSize', Round(FFontSize));
    Ini.WriteBool('Editor', 'LineNumbers', FLineNumbers);
    Ini.WriteInteger('Editor', 'TabWidth', FTabWidth);
    Ini.WriteInteger('Editor', 'RightEdge', FRightEdge);
    Ini.WriteInteger('Window', 'TextSize', FTextSize);
    Ini.WriteBool('Run', 'ClearOutput', FClearOutput);
    Ini.WriteBool('Start', 'Reopen', FReopen);
    Ini.WriteBool('View', 'HelpInsight', InsightAction.Checked);
    SaveOpenFiles(Ini, 'Open');
    if FProject <> nil then
    begin
      Ini.WriteString('Session', 'Project', FProject.FileName);
      SaveOpenFiles(Ini, 'Project ' + FProject.FileName);
    end
    else
      Ini.WriteString('Session', 'Project', '');
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

{ ---- projects: Name.hproj beside Name.haste (Hasten.Project) ---- }

procedure TMainForm.SaveOpenFiles(Ini: TMemIniFile; const Section: string);
var
  I, N: Integer;
begin
  Ini.EraseSection(Section);
  N := 0;
  for I := 0 to Tabs.TabCount - 1 do
    if TEditorTab(Tabs.Tabs[I]).FileName <> '' then
    begin
      Inc(N);
      Ini.WriteString(Section, 'File' + N.ToString, TEditorTab(Tabs.Tabs[I]).FileName);
    end;
end;

function TMainForm.CloseAllTabs: Boolean;
begin
  while Tabs.TabCount > 0 do
    if not CloseTab(TEditorTab(Tabs.Tabs[Tabs.TabCount - 1])) then
      Exit(False);
  Result := True;
end;

function TMainForm.CloseProject: Boolean;
var
  Ini: TMemIniFile;
begin
  if FProject = nil then Exit(True);
  ForceDirectories(ExtractFileDir(FIniName));
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  try
    SaveOpenFiles(Ini, 'Project ' + FProject.FileName);   // reopened with the project next time
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
  Result := CloseAllTabs;
  if Result then
  begin
    FreeAndNil(FProject);
    ShowTree;
    Rescan;
    UpdateStatus;
  end;
end;

{ Closes what is open (asking to save changes), then opens the project's files from last time, or its program. }
function TMainForm.OpenProject(const Path: string): Boolean;
var
  Ini: TMemIniFile;
  Files: TStringList;
  Full: string;
  I: Integer;
begin
  Full := TPath.GetFullPath(Path);
  if not FileExists(ChangeFileExt(Full, '.haste')) then
  begin
    TDialogServiceSync.MessageDialog(Format('%s needs its program, %s, beside it.', [ExtractFileName(Full),
      ChangeFileExt(ExtractFileName(Full), '.haste')]), TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
    Exit(False);
  end;
  if not CloseProject or not CloseAllTabs then Exit(False);
  FProject := THasteProject.Create(Full);
  AddRecent(Full);
  Files := TStringList.Create;
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  try
    Ini.ReadSectionValues('Project ' + Full, Files);
    for I := 0 to Files.Count - 1 do
      if FileExists(Files.ValueFromIndex[I]) then
        OpenFile(Files.ValueFromIndex[I]);
  finally
    Ini.Free;
    Files.Free;
  end;
  if FindTab(FProject.ProgramFile) = nil then
    OpenFile(FProject.ProgramFile);
  ShowTree;
  Rescan(True);
  UpdateStatus;
  Result := True;
end;

procedure TMainForm.NewProjectActionExecute(Sender: TObject);
var
  ProjectName, Folder: string;
begin
  if Running or not LocateHastePy(True) then Exit;
  if not AskForName('New Project', '', ProjectName) then Exit;
  Folder := TPath.GetDocumentsPath;
  if not SelectDirectory('Where should the ' + ProjectName + ' folder go?', '', Folder) then Exit;
  FOpenAfterRun := TPath.Combine(TPath.Combine(Folder, ProjectName), ProjectName + '.hproj');
  RunCommand(Quote(FPython) + ' ' + Quote(FHastePy) + ' new ' + ProjectName + ' ' + Quote(Folder), Folder,
    'Making ' + ProjectName + '...');           // haste.py new: the IDE and the command line make the same
end;

procedure TMainForm.OpenProjectActionExecute(Sender: TObject);
begin
  if OpenProjectDialog.Execute then
    OpenProject(OpenProjectDialog.FileName);
end;

procedure TMainForm.SaveProjectActionExecute(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to Tabs.TabCount - 1 do
    if TEditorTab(Tabs.Tabs[I]).Modified and not SaveTab(TEditorTab(Tabs.Tabs[I]), False) then
      Exit;
end;

{ A new name and/or folder for the project. In its own folder, the project file and the program are renamed;
  in another folder, the whole project (program, modules and project file) is copied there and opened. }
procedure TMainForm.SaveProjectAsActionExecute(Sender: TObject);
var
  Dialog: TSaveDialog;
  NewProj, NewName, NewDir, OldProj, OldDir, OldMain, NewMain, F, Dest: string;
  Files: TArray<string>;
  Tab: TEditorTab;
  I: Integer;

  procedure Warn(const Text: string);
  begin
    TDialogServiceSync.MessageDialog(Text, TMsgDlgType.mtWarning, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
  end;

  function DestOf(const Source: string): string;
  begin
    if SameFileName(Source, OldMain) then Result := NewMain
    else Result := TPath.Combine(NewDir, ExtractRelativePath(IncludeTrailingPathDelimiter(OldDir), Source));
  end;

begin
  if FProject = nil then Exit;
  SaveProjectActionExecute(nil);
  for I := 0 to Tabs.TabCount - 1 do            // what was not saved would be left behind
    if TEditorTab(Tabs.Tabs[I]).Modified then Exit;
  Dialog := TSaveDialog.Create(nil);
  try
    Dialog.Title := 'Save Project As';
    Dialog.Filter := OpenProjectDialog.Filter;
    Dialog.DefaultExt := 'hproj';
    Dialog.InitialDir := FProject.Folder;
    Dialog.FileName := FProject.Name;
    if not Dialog.Execute then Exit;
    NewProj := ChangeFileExt(Dialog.FileName, '.hproj');
  finally
    Dialog.Free;
  end;
  OldProj := FProject.FileName;
  if SameFileName(NewProj, OldProj) then Exit;
  NewName := ChangeFileExt(ExtractFileName(NewProj), '');
  if not THasteProject.IsValidName(NewName) then
  begin
    Warn('A project name is letters, digits and _, starting with a letter or _.');
    Exit;
  end;
  NewDir := ExtractFileDir(NewProj);
  OldDir := FProject.Folder;
  OldMain := FProject.ProgramFile;
  NewMain := ChangeFileExt(NewProj, '.haste');
  if SameFileName(NewDir, OldDir) then
  begin
    if FileExists(NewProj) or (FileExists(NewMain) and not SameFileName(NewMain, OldMain)) then
    begin
      Warn(NewName + '.hproj or ' + NewName + '.haste is already in this folder.');
      Exit;
    end;
    if not RenameFile(OldProj, NewProj) or not RenameFile(OldMain, NewMain) then
    begin
      TDialogServiceSync.MessageDialog('Could not rename the project.', TMsgDlgType.mtError, [TMsgDlgBtn.mbOK],
        TMsgDlgBtn.mbOK, 0);
      Exit;
    end;
    Tab := FindTab(OldMain);
    if Tab <> nil then Tab.FileName := NewMain;
    Tab := FindTab(OldProj);
    if Tab <> nil then Tab.FileName := NewProj;
    FreeAndNil(FProject);
    FProject := THasteProject.Create(NewProj);
    AddRecent(NewProj);
    Rescan(True);
    UpdateStatus;
    RefreshWords;
    Exit;
  end;
  Files := FProject.Files;
  for F in Files do                             // copy nothing until it is sure nothing is overwritten
    if FileExists(DestOf(F)) then
    begin
      Warn(DestOf(F) + ' is already there.');
      Exit;
    end;
  if FileExists(NewProj) then
  begin
    Warn(NewProj + ' is already there.');
    Exit;
  end;
  for F in Files do
  begin
    Dest := DestOf(F);
    ForceDirectories(ExtractFileDir(Dest));
    TFile.Copy(F, Dest);
  end;
  TFile.Copy(OldProj, NewProj);
  OpenProject(NewProj);
end;

procedure TMainForm.CloseProjectActionExecute(Sender: TObject);
begin
  CloseProject;
end;

procedure TMainForm.AddRecent(const Path: string);
var
  Ini: TMemIniFile;
  Old: TStringList;
  I, N: Integer;
begin
  ForceDirectories(ExtractFileDir(FIniName));
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  Old := TStringList.Create;
  try
    Ini.ReadSectionValues('Recent', Old);
    Ini.EraseSection('Recent');
    Ini.WriteString('Recent', 'Project1', Path);
    N := 1;
    for I := 0 to Old.Count - 1 do
      if (N < 8) and not SameFileName(Old.ValueFromIndex[I], Path) then
      begin
        Inc(N);
        Ini.WriteString('Recent', 'Project' + N.ToString, Old.ValueFromIndex[I]);
      end;
    Ini.UpdateFile;
  finally
    Old.Free;
    Ini.Free;
  end;
  BuildRecentMenu;
end;

{ The recent projects, in three places: Project > Recent Projects on a Mac's menu bar, tiles on the ribbon's
  Home page (two rows of them, as many as fit), and rows in the File panel: each its name over its folder. }
procedure TMainForm.BuildRecentMenu;
const
  TileWidth = 230;
  TileHeight = 30;
  MaxTiles = 8;
{$IFDEF MSWINDOWS}
  ProjectGlyph = #$E8B7;                        // a folder (Segoe MDL2 Assets)
{$ENDIF}

  function Line(Parent: TFmxObject; const Text: string; Size: Single; Color: TAlphaColor;
    Align: TAlignLayout): TLabel;
  begin
    Result := TLabel.Create(Self);
    Result.Parent := Parent;
    Result.Align := Align;
    Result.HitTest := False;
    Result.StyledSettings := Result.StyledSettings - [TStyledSetting.Size, TStyledSetting.FontColor];
    Result.TextSettings.Font.Size := Size;
    Result.TextSettings.FontColor := Color;
    Result.TextSettings.WordWrap := False;
    Result.TextSettings.Trimming := TTextTrimming.Character;
    Result.Text := Text;
    Result.Height := Size + 10;
  end;

  procedure Picture(Parent: TFmxObject; Width, Size: Single);
{$IFDEF MSWINDOWS}
  var
    Icon: TText;
  begin
    Icon := TText.Create(Self);
    Icon.Parent := Parent;
    Icon.Align := TAlignLayout.Left;
    Icon.Width := Width;
    Icon.HitTest := False;
    Icon.Text := ProjectGlyph;
    Icon.TextSettings.Font.Family := 'Segoe MDL2 Assets';
    Icon.TextSettings.Font.Size := Size;
    Icon.TextSettings.FontColor := $FF0F90CA;  // HasteSlate's accent
  end;
{$ELSE}
  begin
  end;
{$ENDIF}

var
  Ini: TMemIniFile;
  List: TStringList;
  Item: TMenuItem;
  Row: TListBoxItem;
  Tile: TSpeedButton;
  Title, Folder: string;
  I, Shown: Integer;
begin
  while RecentMenu.ItemsCount > 0 do
    RecentMenu.Items[0].Free;
  RecentList.Clear;
  for I := FRecentTiles.ChildrenCount - 1 downto 0 do
    if FRecentTiles.Children[I] is TSpeedButton then FRecentTiles.Children[I].Free;
  FRecent := nil;
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  List := TStringList.Create;
  try
    Ini.ReadSectionValues('Recent', List);
    for I := 0 to List.Count - 1 do
    begin
      FRecent := FRecent + [List.ValueFromIndex[I]];
      Title := ChangeFileExt(ExtractFileName(FRecent[I]), '');
      Folder := ExtractFileDir(FRecent[I]);
      Item := TMenuItem.Create(Self);
      Item.Text := Format('%d  %s    %s', [I + 1, Title, Folder]);
      Item.Tag := I;
      Item.OnClick := RecentClick;
      RecentMenu.AddObject(Item);

      Row := TListBoxItem.Create(RecentList);  // the File panel
      Row.Height := 52;
      Row.Hint := FRecent[I];
      Row.ShowHint := True;
      Row.Tag := I;
      RecentList.AddObject(Row);
      Picture(Row, 44, 20);
      Line(Row, Title, TextSize + 2, $FFFDFDFD, TAlignLayout.Top).Margins.Rect := RectF(4, 7, 8, 0);
      Line(Row, Folder, TextSize - 1, $FFA8B3C2, TAlignLayout.Client).Margins.Rect := RectF(4, 0, 8, 7);

      if I >= MaxTiles then Continue;          // Home: two rows of tiles, column by column
      Tile := TSpeedButton.Create(Self);
      Tile.StyleLookup := 'ribbonbuttonstyle';
      Tile.Text := '';
      Tile.Tag := I;
      Tile.Hint := FRecent[I];
      Tile.ShowHint := True;
      Tile.SetBounds(I div 2 * (TileWidth + 2), I mod 2 * (TileHeight + 2), TileWidth, TileHeight);
      Tile.OnClick := RecentClick;
      Tile.Parent := FRecentTiles;
      Picture(Tile, 30, 14);
      Line(Tile, Title, TextSize, $FFFDFDFD, TAlignLayout.Left).AutoSize := True;
      Line(Tile, Folder, TextSize - 1, $FFA8B3C2, TAlignLayout.Client).Margins.Rect := RectF(10, 0, 6, 0);
    end;
  finally
    List.Free;
    Ini.Free;
  end;
  Shown := Min(Length(FRecent), MaxTiles);
  FRecentTiles.Width := Max(1, (Shown + 1) div 2) * (TileWidth + 2);
  RecentMenu.Enabled := Length(FRecent) > 0;
  FitRibbon;
end;

procedure TMainForm.RecentClick(Sender: TObject);
var
  Path: string;
begin
  Path := FRecent[TComponent(Sender).Tag];     // a Recent Projects item or the File panel's list
  if FileExists(Path) then
    OpenProject(Path)
  else
    TDialogServiceSync.MessageDialog(Path + ' is no longer there.', TMsgDlgType.mtWarning, [TMsgDlgBtn.mbOK],
      TMsgDlgBtn.mbOK, 0);
end;

{ ---- the Project Manager ---- }

{ Shown while a project is open. Right-aligned controls stack by position, so each time it appears the tree is
  put at the far right and its splitter just left of it. }
procedure TMainForm.ShowTree;
var
  Show: Boolean;
begin
  Show := FProject <> nil;
  if Show = ProjectTree.Visible then Exit;
  ProjectTree.Visible := Show;
  TreeSplitter.Visible := Show;
  if Show then
  begin
    ProjectTree.Position.X := ClientWidth + 1000;
    TreeSplitter.Position.X := ProjectTree.Position.X - TreeSplitter.Width - 1;
  end;
end;

{ The tree is the folder: the program first, then the modules, folders of modules under their folder; the
  heading is the project and its targets. Built again only when the files have changed. }
procedure TMainForm.Rescan(Force: Boolean);
var
  Files, Parts: TArray<string>;
  Root, Holder, Item, Child: TTreeViewItem;
  Rel, Shown: string;
  Same: Boolean;
  I, J, K: Integer;
begin
  if FProject = nil then
  begin
    ProjectTree.Clear;
    FTreeFiles := nil;
    Exit;
  end;
  Files := FProject.Files;
  Same := (Length(Files) = Length(FTreeFiles)) and (ProjectTree.Count > 0);
  if Same then
    for I := 0 to High(Files) do
      if not SameFileName(Files[I], FTreeFiles[I]) then Same := False;
  if Same and not Force then
  begin
    if ProjectTree.Items[0].Text <> FProject.Heading then
      ProjectTree.Items[0].Text := FProject.Heading;      // the targets changed
    Exit;
  end;
  FTreeFiles := Files;
  ProjectTree.BeginUpdate;
  try
    ProjectTree.Clear;
    Root := TTreeViewItem.Create(ProjectTree);
    Root.Text := FProject.Heading;
    Root.Parent := ProjectTree;
    for I := 0 to High(Files) do
    begin
      Rel := ExtractRelativePath(IncludeTrailingPathDelimiter(FProject.Folder), Files[I]);
      Parts := Rel.Split([PathDelim]);
      Holder := Root;
      for J := 0 to High(Parts) - 1 do           // a folder of modules
      begin
        Child := nil;
        for K := 0 to Holder.Count - 1 do
          if (Holder.Items[K].TagString = '') and SameText(Holder.Items[K].Text, Parts[J]) then
            Child := Holder.Items[K];
        if Child = nil then
        begin
          Child := TTreeViewItem.Create(ProjectTree);
          Child.Text := Parts[J];
          Child.Parent := Holder;
        end;
        Holder := Child;
      end;
      Shown := Parts[High(Parts)];
      if I = 0 then Shown := Shown + '   (program)';
      Item := TTreeViewItem.Create(ProjectTree);
      Item.Text := Shown;
      Item.TagString := Files[I];
      Item.Parent := Holder;
    end;
  finally
    ProjectTree.EndUpdate;
  end;
  UseTextSizes(ProjectTree);                    // the items it owns
  ProjectTree.ExpandAll;
end;

function TMainForm.SelectedPath: string;
begin
  if ProjectTree.Selected <> nil then Result := ProjectTree.Selected.TagString else Result := '';
end;

{ Where a new module goes: the selected folder, the selected file's folder, or the project's. }
function TMainForm.SelectedFolder: string;
var
  Item: TTreeViewItem;
  Path: TArray<string>;
begin
  Result := FProject.Folder;
  Item := ProjectTree.Selected;
  if Item = nil then Exit;
  if Item.TagString <> '' then Exit(ExtractFileDir(Item.TagString));
  Path := nil;
  while (Item <> nil) and (Item.ParentItem <> nil) do
  begin
    Path := [Item.Text] + Path;
    Item := Item.ParentItem;
  end;
  for var Part in Path do
    Result := TPath.Combine(Result, Part);
end;

function TMainForm.IsModule(const Path: string): Boolean;
begin
  Result := (FProject <> nil) and (Path <> '') and not SameFileName(Path, FProject.ProgramFile);
end;

function TMainForm.AskForName(const Title, Start: string; out Value: string): Boolean;
var
  Values: TArray<string>;
begin
  Values := [Start];
  repeat
    if not TDialogServiceSync.InputQuery(Title, ['Value (letters, digits and _):'], Values) then Exit(False);
    Value := Values[0].Trim;
    if THasteProject.IsValidName(Value) then Exit(True);
    TDialogServiceSync.MessageDialog('A name is letters, digits and _, starting with a letter or _.',
      TMsgDlgType.mtWarning, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0);
  until False;
end;

procedure TMainForm.ProjectTreeDblClick(Sender: TObject);
begin
  if SelectedPath <> '' then OpenFile(SelectedPath);
end;

{ Only what applies: files open; modules, not the program, are renamed and deleted. }
procedure TMainForm.TreePopupPopup(Sender: TObject);
begin
  TreeOpenItem.Visible := SelectedPath <> '';
  TreeProjectFileItem.Visible := FProject <> nil;
  TreeRenameItem.Visible := IsModule(SelectedPath);
  TreeDeleteItem.Visible := IsModule(SelectedPath);
end;

procedure TMainForm.TreeOpenItemClick(Sender: TObject);
begin
  ProjectTreeDblClick(nil);
end;

procedure TMainForm.TreeProjectFileItemClick(Sender: TObject);
begin
  if FProject <> nil then OpenFile(FProject.FileName);
end;

procedure TMainForm.TreeNewModuleItemClick(Sender: TObject);
var
  ModName, Path: string;
  Lines: TStringList;
begin
  if (FProject = nil) or not AskForName('New Module', '', ModName) then Exit;
  Path := TPath.Combine(SelectedFolder, ModName + '.haste');
  if FileExists(Path) then
  begin
    TDialogServiceSync.MessageDialog(Path + ' is already there.', TMsgDlgType.mtWarning, [TMsgDlgBtn.mbOK],
      TMsgDlgBtn.mbOK, 0);
    Exit;
  end;
  Lines := TStringList.Create;
  try
    Lines.WriteBOM := False;                     // haste.py reads plain UTF-8
    Lines.Add('// ' + ModName + ': what this module is for');
    Lines.SaveToFile(Path, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
  Rescan;
  OpenFile(Path);
end;

{ The tab follows; the files that use the old name (Old.Name, "alias X = Old") can be changed too: open tabs
  in their editors, unsaved so they can be checked, the rest on disk. }
procedure TMainForm.TreeRenameItemClick(Sender: TObject);
var
  OldPath, NewPath, NewName, OldMod, NewMod, Users, F, Text: string;
  Tab: TEditorTab;
  Lines: TStringList;
  Changed: TArray<string>;
begin
  OldPath := SelectedPath;
  if not IsModule(OldPath) or not AskForName('Rename Module', ChangeFileExt(ExtractFileName(OldPath), ''), NewName) then
    Exit;
  NewPath := TPath.Combine(ExtractFileDir(OldPath), NewName + '.haste');
  if SameStr(NewPath, OldPath) then Exit;
  if FileExists(NewPath) and not SameFileName(NewPath, OldPath) then
  begin
    TDialogServiceSync.MessageDialog(NewPath + ' is already there.', TMsgDlgType.mtWarning, [TMsgDlgBtn.mbOK],
      TMsgDlgBtn.mbOK, 0);
    Exit;
  end;
  if not RenameFile(OldPath, NewPath) then
  begin
    TDialogServiceSync.MessageDialog('Could not rename ' + OldPath + '.', TMsgDlgType.mtError, [TMsgDlgBtn.mbOK],
      TMsgDlgBtn.mbOK, 0);
    Exit;
  end;
  Tab := FindTab(OldPath);
  if Tab <> nil then Tab.FileName := NewPath;
  OldMod := ModuleNameOf(FProject.Folder, OldPath);
  NewMod := ModuleNameOf(FProject.Folder, NewPath);
  Changed := nil;
  Users := '';
  for F in FProject.Files do
  begin
    Tab := FindTab(F);
    if Tab <> nil then Text := Tab.Memo.Lines.Text else Text := TFile.ReadAllText(F, TEncoding.UTF8);
    if RenameModuleUses(Text, OldMod, NewMod) <> Text then
    begin
      Changed := Changed + [F];
      Users := Users + sLineBreak + '  ' + ExtractFileName(F);
    end;
  end;
  if (Length(Changed) > 0) and (TDialogServiceSync.MessageDialog(Format('These files use %s. Change them to %s?',
    [OldMod, NewMod]) + Users, TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbYes,
    0) = mrYes) then
    for F in Changed do
    begin
      Tab := FindTab(F);
      if Tab <> nil then
      begin
        Tab.Memo.Lines.Text := RenameModuleUses(Tab.Memo.Lines.Text, OldMod, NewMod);
        Tab.Modified := True;
      end
      else
      begin
        Lines := TStringList.Create;
        try
          Lines.WriteBOM := False;
          Lines.Text := RenameModuleUses(TFile.ReadAllText(F, TEncoding.UTF8), OldMod, NewMod);
          Lines.SaveToFile(F, TEncoding.UTF8);
        finally
          Lines.Free;
        end;
      end;
    end;
  Rescan(True);
  UpdateStatus;
  RefreshWords;
end;

procedure TMainForm.TreeDeleteItemClick(Sender: TObject);
var
  Path: string;
  Tab: TEditorTab;
begin
  Path := SelectedPath;
  if not IsModule(Path) then Exit;
  if TDialogServiceSync.MessageDialog('Delete ' + ExtractFileName(Path) + '? This cannot be undone.',
    TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], TMsgDlgBtn.mbNo, 0) <> mrYes then Exit;
  Tab := FindTab(Path);
  if Tab <> nil then Tab.Free;                   // the file is going: nothing to save
  if not System.SysUtils.DeleteFile(Path) then
    TDialogServiceSync.MessageDialog('Could not delete ' + Path + '.', TMsgDlgType.mtError, [TMsgDlgBtn.mbOK],
      TMsgDlgBtn.mbOK, 0);
  Rescan(True);
  UpdateStatus;
end;

procedure TMainForm.TreeRescanItemClick(Sender: TObject);
begin
  Rescan(True);
end;

{ ---- Project Options, or Module Options for a single file ---- }

procedure TMainForm.OptionsActionExecute(Sender: TObject);
begin
  if FProject <> nil then ProjectOptions else ModuleOptions;
end;

{ A file's text as it is now: its tab's, unsaved changes included, or the file's. The caller frees it. }
function TMainForm.SourceOf(const FileName: string): TStringList;
var
  Tab: TEditorTab;
begin
  Result := TStringList.Create;
  Tab := FindTab(FileName);
  if Tab <> nil then
    Result.Assign(Tab.Memo.Lines)
  else if FileExists(FileName) then
    Result.LoadFromFile(FileName, TEncoding.UTF8);
end;

procedure TMainForm.ProjectOptions;
var
  Form: TOptionsForm;
  Source: TStringList;
  Tab: TEditorTab;
  I: Integer;
begin
  Tab := FindTab(FProject.FileName);             // the project file open in a tab: its changes first
  if (Tab <> nil) and Tab.Modified and not SaveTab(Tab, False) then Exit;
  Source := SourceOf(FProject.ProgramFile);
  Form := TOptionsForm.Create(nil);
  try
    Form.LoadSwitches(Source);
    Form.Targets := FProject.Targets;
    for I := 0 to Form.SwitchCount - 1 do
      Form.Values[Form.Switches[I].Name] := FProject.SwitchValues[Form.Switches[I].Name];
    if not Form.Execute(FProject.Name, True) then Exit;
    FProject.Targets := Form.Targets;
    FProject.ClearSwitchValues;                  // switches no longer in the program go with them
    for I := 0 to Form.SwitchCount - 1 do
      FProject.SwitchValues[Form.Switches[I].Name] := Form.Values[Form.Switches[I].Name];
    if Tab <> nil then
      Tab.Load(FProject.FileName);               // and the tab shows what was saved
    Rescan;
  finally
    Form.Free;
    Source.Free;
  end;
end;

{ Module Options: kept in HastenFMX.ini under [Module <full file name>]. }
procedure TMainForm.ModuleOptions;
var
  Form: TOptionsForm;
  Tab: TEditorTab;
  Ini: TMemIniFile;
  Section: string;
  I: Integer;
begin
  Tab := ActiveTab;
  if Tab = nil then Exit;
  if (Tab.FileName = '') and not SaveTab(Tab, True) then Exit;   // options are kept by file name
  Section := 'Module ' + Tab.FileName;
  ForceDirectories(ExtractFileDir(FIniName));
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  Form := TOptionsForm.Create(nil);
  try
    Form.LoadSwitches(Tab.Memo.Lines);
    Form.Targets := Ini.ReadString(Section, 'Targets', '');
    for I := 0 to Form.SwitchCount - 1 do
      Form.Values[Form.Switches[I].Name] := Ini.ReadString(Section, 'Switch.' + Form.Switches[I].Name, '');
    if not Form.Execute(Tab.Title, False) then Exit;
    Ini.EraseSection(Section);
    if Form.Targets <> '' then
      Ini.WriteString(Section, 'Targets', Form.Targets);
    for I := 0 to Form.SwitchCount - 1 do
      if Form.Values[Form.Switches[I].Name] <> '' then
        Ini.WriteString(Section, 'Switch.' + Form.Switches[I].Name, Form.Values[Form.Switches[I].Name]);
    Ini.UpdateFile;
  finally
    Form.Free;
    Ini.Free;
  end;
end;

function TMainForm.ModuleTargets(const FileName: string): string;
var
  Ini: TMemIniFile;
begin
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  try
    Result := Ini.ReadString('Module ' + FileName, 'Targets', '');
  finally
    Ini.Free;
  end;
end;

{ The values saved for the switches the program declares now: one removed from the source is not passed. }
function TMainForm.ModuleSwitchArgs(Tab: TEditorTab): string;
var
  Ini: TMemIniFile;
  Names, Values: TArray<string>;
begin
  Names := nil;
  Values := nil;
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  try
    for var S in ReadSwitches(Tab.Memo.Lines) do
    begin
      Names := Names + [S.Name];
      Values := Values + [Ini.ReadString('Module ' + Tab.FileName, 'Switch.' + S.Name, '')];
    end;
  finally
    Ini.Free;
  end;
  Result := SwitchArgs(Names, Values);
end;

end.
