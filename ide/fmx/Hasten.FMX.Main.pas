unit Hasten.FMX.Main;

{ Hasten for FireMonkey: Windows, macOS and Linux. The window is designed in Hasten.FMX.Main.fmx; editor tabs
  are made in code (Hasten.FMX.Editor). So far: files, Run, Build, Stop and Run Tests through haste.py, the
  output with a jump to each error, and names coloured from "haste.py words". Projects, options, settings
  and Help Insight come next, sharing what they can with Hasten for VCL. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.IOUtils, System.IniFiles,
  System.RegularExpressions, System.Actions, FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.DialogService.Sync, FMX.StdCtrls, FMX.Layouts, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox,
  FMX.Controls.Presentation, FMX.TabControl, FMX.Menus, FMX.ActnList, FMX.Text, Hasten.Runner,
  Hasten.FMX.Editor, Syntax.Code.Haste;

type
  TMainForm = class(TForm)
    MainMenu: TMainMenu;
    FileMenu: TMenuItem;
    NewItem: TMenuItem;
    OpenItem: TMenuItem;
    SaveItem: TMenuItem;
    SaveAsItem: TMenuItem;
    CloseItem: TMenuItem;
    FileSep: TMenuItem;
    ExitItem: TMenuItem;
    RunMenu: TMenuItem;
    RunItem: TMenuItem;
    BuildItem: TMenuItem;
    StopItem: TMenuItem;
    RunSep1: TMenuItem;
    TestsItem: TMenuItem;
    RunSep2: TMenuItem;
    HastePyItem: TMenuItem;
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
    procedure LoadSettings;
    procedure SaveSettings;
  end;

var
  MainForm: TMainForm;

implementation

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
  FPython := DefaultPython;
  NewAction.ShortCut := CmdKey or Ord('N');      // shortcuts here, not in the .fmx: Cmd or Ctrl by platform
  OpenAction.ShortCut := CmdKey or Ord('O');
  SaveAction.ShortCut := CmdKey or Ord('S');
  SaveAsAction.ShortCut := CmdKey or scShift or Ord('S');
  CloseAction.ShortCut := CmdKey or Ord('W');
  RunAction.ShortCut := vkF9;
  BuildAction.ShortCut := CmdKey or vkF9;
  StopAction.ShortCut := CmdKey or vkF2;
  Output.TextSettings.Font.Family := MonoFont;
  LoadSettings;
  if Tabs.TabCount = 0 then
    NewTab;
  UpdateStatus;
  RefreshWords;
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
begin
  SaveAction.Enabled := ActiveTab <> nil;
  SaveAsAction.Enabled := ActiveTab <> nil;
  CloseAction.Enabled := ActiveTab <> nil;
  RunAction.Enabled := not Running and (ActiveTab <> nil);
  BuildAction.Enabled := RunAction.Enabled;
  StopAction.Enabled := Running;
  TestsAction.Enabled := not Running;
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
  if (ActiveTab <> nil) and TCodeSyntaxHaste.ScanAliases(ActiveTab.Memo.Lines) then
    ActiveTab.Recolour;                          // the aliases are those of the file on show
  UpdateStatus;
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
  UpdateStatus;
  RefreshWords;                                  // a file saved into lib is a new module
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

procedure TMainForm.Start(const Verb: string);
var
  Tab: TEditorTab;
begin
  Tab := ActiveTab;
  if Running or (Tab = nil) or not SaveAll or not LocateHastePy(True) then Exit;
  RunCommand(Quote(FPython) + ' ' + Quote(FHastePy) + ' ' + Verb + ' ' + Quote(Tab.FileName),
    ExtractFileDir(Tab.FileName), 'Running ' + Tab.Title + '...');
end;

procedure TMainForm.RunCommand(const Cmd, Folder, Busy: string);
begin
  FRunFolder := Folder;
  FJumped := False;
  Output.Lines.Clear;
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
  Name, Path: string;
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
  Name := M.Groups[1].Value;
  Candidates := [Name, TPath.Combine(FRunFolder, Name),
    TPath.Combine(TPath.Combine(ExtractFileDir(FHastePy), 'lib'), Name)];
  for Path in Candidates do
    if (Path <> '') and FileExists(Path) then
    begin
      OpenFile(TPath.GetFullPath(Path), M.Groups[2].Value.ToInteger);
      Exit(True);
    end;
  if DirectoryExists(FRunFolder) then
    for Path in TDirectory.GetFiles(FRunFolder, ExtractFileName(Name), TSearchOption.soAllDirectories) do
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
  ForceDirectories(ExtractFileDir(FIniName));
  Ini := TMemIniFile.Create(FIniName, TEncoding.UTF8);
  try
    Ini.WriteString('Haste', 'HastePy', FHastePy);
    Ini.WriteString('Haste', 'Python', FPython);
    Ini.EraseSection('Open');
    N := 0;
    for I := 0 to Tabs.TabCount - 1 do
      if TEditorTab(Tabs.Tabs[I]).FileName <> '' then
      begin
        Inc(N);
        Ini.WriteString('Open', 'File' + N.ToString, TEditorTab(Tabs.Tabs[I]).FileName);
      end;
    Ini.UpdateFile;
  finally
    Ini.Free;
  end;
end;

end.
