unit Hasten.Runner;

{ Runs a command line in the background and hands each line of its output (stdout and stderr together)
  to the main thread. The process and everything it starts are put in a job object, so Stop ends the
  whole tree: python, and the Haste program python started. }

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes;

type
  TLineEvent = reference to procedure(const Line: string);
  TDoneEvent = reference to procedure(ExitCode: Cardinal; Stopped: Boolean);

  TRunner = class(TThread)
  private
    FCommand: string;
    FFolder: string;
    FOnLine: TLineEvent;
    FOnDone: TDoneEvent;
    FJob: THandle;
    FStopped: Boolean;
    procedure Emit(const Line: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const Command, Folder: string; const OnLine: TLineEvent; const OnDone: TDoneEvent);
    destructor Destroy; override;
    procedure Stop;
    property Command: string read FCommand;
    property Stopped: Boolean read FStopped;
  end;

implementation

constructor TRunner.Create(const Command, Folder: string; const OnLine: TLineEvent; const OnDone: TDoneEvent);
begin
  FCommand := Command;
  FFolder := Folder;
  FOnLine := OnLine;
  FOnDone := OnDone;
  FJob := CreateJobObject(nil, nil);
  inherited Create(False);
end;

destructor TRunner.Destroy;
begin
  inherited;                                   // waits for Execute to finish
  if FJob <> 0 then
    CloseHandle(FJob);
end;

procedure TRunner.Stop;
begin
  FStopped := True;
  if FJob <> 0 then
    TerminateJobObject(FJob, 1);
end;

{ Each call captures its own Line, so queued calls never see a later value. }
procedure TRunner.Emit(const Line: string);
begin
  Queue(procedure begin FOnLine(Line) end);
end;

procedure TRunner.Execute;
var
  Security: TSecurityAttributes;
  ReadPipe, WritePipe, NulInput: THandle;
  Startup: TStartupInfo;
  Info: TProcessInformation;
  Buffer: array[0..4095] of Byte;
  Count: DWORD;
  Pending: TBytes;
  Line: TBytes;
  Cmd: string;
  Code: DWORD;
  I, Start, Len: Integer;
begin
  Security.nLength := SizeOf(Security);
  Security.lpSecurityDescriptor := nil;
  Security.bInheritHandle := True;
  if not CreatePipe(ReadPipe, WritePipe, @Security, 0) then
  begin
    Emit('Cannot create a pipe: ' + SysErrorMessage(GetLastError));
    Queue(procedure begin FOnDone(1, False) end);
    Exit;
  end;
  SetHandleInformation(ReadPipe, HANDLE_FLAG_INHERIT, 0);
  NulInput := CreateFile('NUL', GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE, @Security, OPEN_EXISTING, 0, 0);

  FillChar(Startup, SizeOf(Startup), 0);
  Startup.cb := SizeOf(Startup);
  Startup.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  Startup.wShowWindow := SW_HIDE;
  Startup.hStdInput := NulInput;
  Startup.hStdOutput := WritePipe;
  Startup.hStdError := WritePipe;

  Cmd := FCommand;
  UniqueString(Cmd);                           // CreateProcess may write to the command line
  Code := 1;
  if CreateProcess(nil, PChar(Cmd), nil, nil, True, CREATE_NO_WINDOW or CREATE_SUSPENDED, nil,
    PChar(FFolder), Startup, Info) then
  begin
    AssignProcessToJobObject(FJob, Info.hProcess);
    ResumeThread(Info.hThread);
    CloseHandle(Info.hThread);
    CloseHandle(WritePipe);                    // so ReadFile ends when the last process closes its copy
    WritePipe := 0;

    Pending := nil;
    while ReadFile(ReadPipe, Buffer, SizeOf(Buffer), Count, nil) and (Count > 0) do
    begin
      Start := Length(Pending);
      SetLength(Pending, Start + Integer(Count));
      Move(Buffer, Pending[Start], Count);
      Start := 0;
      for I := 0 to High(Pending) do
        if Pending[I] = 10 then
        begin
          Len := I - Start;
          if (Len > 0) and (Pending[I - 1] = 13) then
            Dec(Len);
          Line := Copy(Pending, Start, Len);
          Emit(TEncoding.UTF8.GetString(Line));
          Start := I + 1;
        end;
      Pending := Copy(Pending, Start, Length(Pending) - Start);
    end;
    if Length(Pending) > 0 then
      Emit(TEncoding.UTF8.GetString(Pending));

    WaitForSingleObject(Info.hProcess, INFINITE);
    GetExitCodeProcess(Info.hProcess, Code);
    CloseHandle(Info.hProcess);
  end
  else
    Emit('Cannot start: ' + FCommand + sLineBreak + SysErrorMessage(GetLastError));

  if WritePipe <> 0 then
    CloseHandle(WritePipe);
  CloseHandle(ReadPipe);
  if NulInput <> INVALID_HANDLE_VALUE then
    CloseHandle(NulInput);
  Queue(procedure begin FOnDone(Code, FStopped) end);
end;

end.
