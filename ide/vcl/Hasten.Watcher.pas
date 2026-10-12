unit Hasten.Watcher;

{ Watches folders for files and folders being added, removed or renamed, and calls OnChange on the main
  thread when one is. Hasten uses it to colour a new module the moment it appears in lib or next to the
  program, even when it was copied there outside the IDE. }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes;

type
  TFolderWatcher = class(TThread)
  private
    FFolders: TArray<string>;
    FOnChange: TThreadProcedure;
    FStopEvent: THandle;
  protected
    procedure Execute; override;
  public
    constructor Create(const Folders: TArray<string>; const OnChange: TThreadProcedure);
    destructor Destroy; override;
    property Folders: TArray<string> read FFolders;
  end;

implementation

constructor TFolderWatcher.Create(const Folders: TArray<string>; const OnChange: TThreadProcedure);
begin
  FFolders := Folders;
  FOnChange := OnChange;
  FStopEvent := CreateEvent(nil, True, False, nil);
  inherited Create(False);
end;

destructor TFolderWatcher.Destroy;
begin
  SetEvent(FStopEvent);                        // wakes Execute, which then returns
  inherited;                                   // waits for it
  TThread.RemoveQueuedEvents(Self);            // a change queued just before stopping must not run
  CloseHandle(FStopEvent);
end;

procedure TFolderWatcher.Execute;
var
  Handles: TArray<THandle>;
  H: THandle;
  Folder: string;
  R: DWORD;
  I: Integer;
begin
  Handles := [FStopEvent];
  for Folder in FFolders do
    if DirectoryExists(Folder) then
    begin
      H := FindFirstChangeNotification(PChar(Folder), True,     // True: subfolders too (folder modules)
        FILE_NOTIFY_CHANGE_FILE_NAME or FILE_NOTIFY_CHANGE_DIR_NAME);
      if H <> INVALID_HANDLE_VALUE then
        Handles := Handles + [H];
    end;
  try
    while not Terminated do
    begin
      R := WaitForMultipleObjects(Length(Handles), @Handles[0], False, INFINITE);
      if R = WAIT_OBJECT_0 then
        Break;                                 // asked to stop
      I := Integer(R - WAIT_OBJECT_0);
      if (I < 1) or (I >= Length(Handles)) then
        Break;                                 // a wait failure: stop watching rather than spin
      Queue(FOnChange);
      FindNextChangeNotification(Handles[I]);
    end;
  finally
    for I := 1 to High(Handles) do
      FindCloseChangeNotification(Handles[I]);
  end;
end;

end.
