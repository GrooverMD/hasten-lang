unit Hasten.Runner;

{ Runs a command line in the background and hands each line of its output (stdout and stderr together)
  to the main thread. Stop ends the whole tree, python and the Haste program python started: on Windows
  they are put in a job object; on macOS and Linux the command runs under /bin/sh in a process group of
  its own. Shared by Hasten for VCL and for FMX: nothing here depends on either. }

interface

uses
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ELSE}
  Posix.Base, Posix.Unistd, Posix.Signal, Posix.SysWait, Posix.Fcntl, Posix.SysTypes,
{$ENDIF}
  System.SysUtils, System.Classes;

type
  TLineEvent = reference to procedure(const Line: string);
  TDoneEvent = reference to procedure(ExitCode: Cardinal; Stopped: Boolean);

  TRunner = class(TThread)
  private
    FCommand: string;
    FFolder: string;
    FOnLine: TLineEvent;
    FOnDone: TDoneEvent;
{$IFDEF MSWINDOWS}
    FJob: THandle;
{$ELSE}
    FPid: pid_t;
{$ENDIF}
    FStopped: Boolean;
    procedure Emit(const Line: string);
    procedure Lines(var Pending: TBytes; const Buffer: array of Byte; Count: Integer);
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
{$IFDEF MSWINDOWS}
  FJob := CreateJobObject(nil, nil);
{$ENDIF}
  inherited Create(False);
end;

destructor TRunner.Destroy;
begin
  inherited;                                   // waits for Execute to finish
{$IFDEF MSWINDOWS}
  if FJob <> 0 then
    CloseHandle(FJob);
{$ENDIF}
end;

procedure TRunner.Stop;
begin
  FStopped := True;
{$IFDEF MSWINDOWS}
  if FJob <> 0 then
    TerminateJobObject(FJob, 1);
{$ELSE}
  if FPid > 0 then
    kill(-FPid, SIGTERM);                      // the whole process group
{$ENDIF}
end;

{ Adds what was read to Pending and emits every whole line in it (\n or \r\n); the rest waits for more. }
procedure TRunner.Lines(var Pending: TBytes; const Buffer: array of Byte; Count: Integer);
var
  I, Start, Len: Integer;
begin
  Start := Length(Pending);
  SetLength(Pending, Start + Count);
  Move(Buffer[0], Pending[Start], Count);
  Start := 0;
  for I := 0 to High(Pending) do
    if Pending[I] = 10 then
    begin
      Len := I - Start;
      if (Len > 0) and (Pending[I - 1] = 13) then
        Dec(Len);
      Emit(TEncoding.UTF8.GetString(Copy(Pending, Start, Len)));
      Start := I + 1;
    end;
  Pending := Copy(Pending, Start, Length(Pending) - Start);
end;

{ Each call captures its own Line, so queued calls never see a later value. }
procedure TRunner.Emit(const Line: string);
begin
  Queue(procedure begin FOnLine(Line) end);
end;

{$IFDEF MSWINDOWS}
procedure TRunner.Execute;
var
  Security: TSecurityAttributes;
  ReadPipe, WritePipe, NulInput: THandle;
  Startup: TStartupInfo;
  Info: TProcessInformation;
  Buffer: array[0..4095] of Byte;
  Count: DWORD;
  Pending: TBytes;
  Cmd: string;
  Code: DWORD;
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
      Lines(Pending, Buffer, Count);
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

{$ELSE}
procedure TRunner.Execute;
var
  Pipe: TPipeDescriptors;
  NulInput, Status: Integer;
  Buffer: array[0..4095] of Byte;
  Count: ssize_t;
  Pending: TBytes;
  Shell, Dash, Command, Folder: UTF8String;
  Args: array[0..3] of MarshaledAString;
  Code: Cardinal;
begin
  Code := 1;
  if pipe(Pipe) <> 0 then
  begin
    Emit('Cannot create a pipe');
    Queue(procedure begin FOnDone(1, False) end);
    Exit;
  end;
  Shell := '/bin/sh';                          // everything the child needs is made before fork:
  Dash := '-c';                                // between fork and exec it may only make plain calls
  Command := UTF8String(FCommand);
  Folder := UTF8String(FFolder);
  Args[0] := MarshaledAString(Shell);
  Args[1] := MarshaledAString(Dash);
  Args[2] := MarshaledAString(Command);
  Args[3] := nil;
  NulInput := open('/dev/null', O_RDONLY);
  FPid := fork;
  if FPid = 0 then
  begin
    setpgid(0, 0);                             // its own process group, so Stop ends all it starts
    dup2(NulInput, 0);
    dup2(Pipe.WriteDes, 1);
    dup2(Pipe.WriteDes, 2);
    __close(Pipe.ReadDes);
    if Folder <> '' then
      chdir(MarshaledAString(Folder));
    execv(MarshaledAString(Shell), @Args[0]);
    _exit(127);
  end;
  __close(Pipe.WriteDes);                      // so reading ends when the last process closes its copy
  if NulInput >= 0 then
    __close(NulInput);
  if FPid < 0 then
    Emit('Cannot start: ' + FCommand)
  else
  begin
    Pending := nil;
    repeat
      Count := __read(Pipe.ReadDes, @Buffer[0], SizeOf(Buffer));
      if Count > 0 then
        Lines(Pending, Buffer, Count);
    until Count <= 0;
    if Length(Pending) > 0 then
      Emit(TEncoding.UTF8.GetString(Pending));
    if waitpid(FPid, @Status, 0) = FPid then
      if WIFEXITED(Status) then
        Code := WEXITSTATUS(Status)
      else
        Code := 128 + WTERMSIG(Status);
  end;
  __close(Pipe.ReadDes);
  Queue(procedure begin FOnDone(Code, FStopped) end);
end;
{$ENDIF}

end.
