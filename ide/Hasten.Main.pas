unit Hasten.Main;

{ Hasten, the Haste IDE: tabbed editor with Haste highlighting, Run and Build through haste.py, output
  panel, and a jump to the line of each compiler error. Every control is created in code, so there is
  no .dfm to keep in step. }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.IOUtils, System.IniFiles, System.UITypes,
  System.RegularExpressions, System.Actions, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.StdCtrls, Vcl.Menus, Vcl.ActnList, Vcl.Graphics,
  SynEdit, SynEditTypes, SynEditSearch, Hasten.Highlighter, Hasten.Runner;

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
    FOutput: TMemo;
    FStatus: TStatusBar;
    FArgs: TEdit;
    FTarget: TComboBox;
    FActions: TActionList;
    FRunAction, FBuildAction, FStopAction: TAction;
    FHighlighter: THasteHighlighter;
    FSearch: TSynEditSearch;
    FFind: TFindDialog;
    FRunner: TRunner;
    FFinished: TRunner;                         // the last run, freed once its thread is long gone
    FWordsRunner: TRunner;                      // "haste.py words": names to colour, asked in the background
    FWordsFinished: TRunner;
    FWordLines: TStringList;
    FWordsAgain: Boolean;
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
    procedure RefreshWords;
    procedure WordsDone(ExitCode: Cardinal; Stopped: Boolean);
    procedure Start(const Verb: string);
    procedure RunnerLine(const Line: string);
    procedure RunnerDone(ExitCode: Cardinal; Stopped: Boolean);
    function JumpToError(const Line: string): Boolean;
    procedure EditorStatus(Sender: TObject; Changes: TSynStatusChanges);
    procedure UpdateStatus;
    function SwitchHint(Tab: TEditorTab): string;
    procedure PagesChange(Sender: TObject);
    procedure OutputDblClick(Sender: TObject);
    procedure FindNext(Sender: TObject);
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
    procedure DoHastePy(Sender: TObject);
    procedure ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
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
  TargetAll = 'windows,macos,linux';

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
  FHighlighter := THasteHighlighter.Create(Self);
  FWordLines := TStringList.Create;
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

destructor TMainForm.Destroy;
begin
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
  RunButton: TButton;
  Lbl: TLabel;

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
  FileMenu, EditMenu, RunMenu: TMenuItem;
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
  Item(FileMenu, AddAction('&New', 'Ctrl+N', DoNew));
  Item(FileMenu, AddAction('&Open...', 'Ctrl+O', DoOpen));
  Item(FileMenu, AddAction('&Save', 'Ctrl+S', DoSave));
  Item(FileMenu, AddAction('Save &As...', 'Ctrl+Shift+S', DoSaveAs));
  Item(FileMenu, AddAction('&Close', 'Ctrl+W', DoCloseTab));
  Item(FileMenu, nil);
  Item(FileMenu, AddAction('E&xit', 'Alt+F4', DoQuit));

  EditMenu := Head('&Edit');
  Item(EditMenu, AddAction('&Find...', 'Ctrl+F', DoFind));
  Item(EditMenu, AddAction('Find &Next', 'F3', DoFindNext));
  Item(EditMenu, AddAction('&Go to Line...', 'Ctrl+G', DoGoToLine));

  RunMenu := Head('&Run');
  FRunAction := AddAction('&Run', 'F9', DoRun);
  FBuildAction := AddAction('&Build', 'Ctrl+F9', DoBuild);
  FStopAction := AddAction('&Stop', 'Ctrl+F2', DoStop);
  Item(RunMenu, FRunAction);
  Item(RunMenu, FBuildAction);
  Item(RunMenu, FStopAction);
  Item(RunMenu, nil);
  Item(RunMenu, AddAction('Where is &haste.py...', '', DoHastePy));

  Bar := TPanel.Create(Self);
  Bar.Parent := Self;
  Bar.Align := alTop;
  Bar.Height := 34;
  Bar.BevelOuter := bvNone;

  RunButton := TButton.Create(Self);
  RunButton.Parent := Bar;
  RunButton.SetBounds(6, 5, 70, 24);
  RunButton.Action := FRunAction;
  RunButton.Caption := 'Run';

  Lbl := TLabel.Create(Self);
  Lbl.Parent := Bar;
  Lbl.SetBounds(88, 9, 70, 16);
  Lbl.Caption := 'Switches:';
  FArgs := TEdit.Create(Self);
  FArgs.Parent := Bar;
  FArgs.SetBounds(150, 6, 360, 22);
  FArgs.Hint := 'Passed to the program on Run, e.g. --width 1920 --height 1080';   // a tooltip: the
  FArgs.ShowHint := True;                       // VCL style draws a TextHint too faintly to read

  Lbl := TLabel.Create(Self);
  Lbl.Parent := Bar;
  Lbl.SetBounds(528, 9, 60, 16);
  Lbl.Caption := 'Build for:';
  FTarget := TComboBox.Create(Self);
  FTarget.Parent := Bar;
  FTarget.SetBounds(590, 6, 180, 22);
  FTarget.Style := csDropDownList;
  FTarget.Items.Add('this system');
  FTarget.Items.Add(TargetAll);
  FTarget.Items.Add('windows');
  FTarget.Items.Add('linux');
  FTarget.Items.Add('macos');
  FTarget.ItemIndex := 0;

  FStatus := TStatusBar.Create(Self);
  FStatus.Parent := Self;
  FStatus.SimplePanel := False;
  FStatus.Panels.Add.Width := 110;
  FStatus.Panels.Add.Width := 90;
  FStatus.Panels.Add;

  FOutput := TMemo.Create(Self);
  FOutput.Parent := Self;
  FOutput.Align := alBottom;
  FOutput.Height := 180;
  FOutput.ReadOnly := True;
  FOutput.ScrollBars := ssBoth;
  FOutput.WordWrap := False;
  FOutput.Font.Name := 'Consolas';
  FOutput.Font.Size := 10;
  FOutput.OnDblClick := OutputDblClick;

  Split := TSplitter.Create(Self);
  Split.Parent := Self;
  Split.Align := alBottom;
  Split.Top := FOutput.Top - 1;                 // keeps the splitter above the output panel

  FPages := TPageControl.Create(Self);
  FPages.Parent := Self;
  FPages.Align := alClient;
  FPages.OnChange := PagesChange;

  FFind := TFindDialog.Create(Self);
  FFind.Options := [frDown];
  FFind.OnFind := FindNext;
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
    FArgs.Text := Ini.ReadString('Run', 'Switches', '');
    FTarget.ItemIndex := FTarget.Items.IndexOf(Ini.ReadString('Run', 'Target', 'this system'));
    if FTarget.ItemIndex < 0 then FTarget.ItemIndex := 0;
    Ini.ReadSectionValues('Open', Files);
    for I := 0 to Files.Count - 1 do               // the files that were open last time
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
    Ini.WriteString('Run', 'Switches', FArgs.Text);
    Ini.WriteString('Run', 'Target', FTarget.Text);
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

{ Asks haste.py which built-ins, members and modules exist, so the highlighter colours a new module in lib
  (or next to the program) without the .msg being regenerated. Runs in the background; a request made
  while one is running is remembered and run straight after. }
procedure TMainForm.RefreshWords;
var
  Cmd: string;
  Tab: TEditorTab;
begin
  if FWordsRunner <> nil then
  begin
    FWordsAgain := True;
    Exit;
  end;
  if not LocateHastePy(False) then Exit;       // never ask for haste.py just to colour words
  Cmd := Quote(FPython) + ' ' + Quote(FHastePy) + ' words';
  Tab := ActiveTab;
  if (Tab <> nil) and (Tab.FileName <> '') then
    Cmd := Cmd + ' ' + Quote(Tab.FileName);    // modules next to the program count too
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
  Cmd: string;
begin
  Tab := ActiveTab;
  if Running or (Tab = nil) or not SaveAllForRun or not LocateHastePy then Exit;
  Cmd := Quote(FPython) + ' ' + Quote(FHastePy) + ' ' + Verb + ' ' + Quote(Tab.FileName);
  if (Verb = 'build') and (FTarget.ItemIndex > 0) then
    Cmd := Cmd + ' --target ' + FTarget.Text;
  if (Verb = 'run') and (Trim(FArgs.Text) <> '') then
    Cmd := Cmd + ' ' + Trim(FArgs.Text);
  FRunFolder := ExtractFileDir(Tab.FileName);
  FJumped := False;
  FOutput.Clear;
  FOutput.Lines.Add('> ' + Cmd);
  FStatus.Panels[2].Text := 'Running ' + Tab.Title + '...';
  FRunner := TRunner.Create(Cmd, FRunFolder, RunnerLine, RunnerDone);
end;

procedure TMainForm.RunnerLine(const Line: string);
begin
  FOutput.Lines.Add(Line);
  if not FJumped and Line.StartsWith('error:') then
    FJumped := JumpToError(Line);               // go straight to the first compiler error
end;

procedure TMainForm.RunnerDone(ExitCode: Cardinal; Stopped: Boolean);
begin
  if Stopped then
    FOutput.Lines.Add('[stopped]')
  else
    FOutput.Lines.Add(Format('[finished, exit code %d]', [ExitCode]));
  FStatus.Panels[2].Text := '';
  FFinished.Free;                               // the run before this one: its thread ended long ago
  FFinished := FRunner;                         // this one is still inside its own callback, so not yet
  FRunner := nil;
  RefreshWords;
end;

{ Compiler errors look like  error: fractal.haste:12: message  and a second line may add
  in Shade, called from fractal.haste:30. The file is looked for next to the program, then in lib. }
function TMainForm.JumpToError(const Line: string): Boolean;
var
  M: TMatch;
  Name, Path: string;
  Candidates: TArray<string>;
begin
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
  Result := False;
end;

procedure TMainForm.OutputDblClick(Sender: TObject);
var
  Row: Integer;
begin
  Row := FOutput.CaretPos.Y;
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
  FArgs.Hint := SwitchHint(Tab);
end;

{ The switches the open program accepts, read from its source the way haste.py reads them:
    switch Name[: type] = default [where rule]   // help
  Kept current as you type, because UpdateStatus runs on every edit and caret move. }
function TMainForm.SwitchHint(Tab: TEditorTab): string;
var
  I: Integer;
  Line, Item: string;
  M: TMatch;
begin
  Result := '';
  for I := 0 to Tab.Editor.Lines.Count - 1 do
  begin
    Line := Tab.Editor.Lines[I];
    if not Line.TrimLeft.StartsWith('switch ') then Continue;
    M := TRegEx.Match(Line, '^\s*switch\s+(\w+)\s*(?::\s*\w+\s*)?=\s*("(?:[^"\\]|\\.)*"|.+?)(?:\s+where\s+(.+?))?\s*(?://\s*(.*))?$');
    if not M.Success then Continue;
    Item := '--' + M.Groups[1].Value.ToLower + ' ' + M.Groups[2].Value;
    if (M.Groups.Count > 4) and (M.Groups[4].Value <> '') then
      Item := Item + '    ' + M.Groups[4].Value;
    if (M.Groups.Count > 3) and (M.Groups[3].Value <> '') then
      Item := Item + '    (' + M.Groups[3].Value + ')';
    Result := Result + sLineBreak + Item.Replace('|', '/');   // | would split the hint in two
  end;
  if Result = '' then
    Result := Tab.Title + ' has no switches. Anything typed here is passed to the program on Run.'
  else
    Result := 'Switches for ' + Tab.Title + ', passed on Run (shown with their defaults):' + Result;
end;

procedure TMainForm.PagesChange(Sender: TObject);
begin
  UpdateStatus;
  RefreshWords;                                 // another folder can mean other modules
end;

procedure TMainForm.ActionsUpdate(Action: TBasicAction; var Handled: Boolean);
begin
  FStopAction.Enabled := Running;
  FRunAction.Enabled := not Running and (ActiveTab <> nil);
  FBuildAction.Enabled := FRunAction.Enabled;
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
