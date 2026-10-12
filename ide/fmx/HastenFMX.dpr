program HastenFMX;

{ Hasten for FireMonkey: Windows, macOS and Linux. See README.md. }

uses
  System.StartUpCopy,
  FMX.Forms,
  Hasten.FMX.Main in 'Hasten.FMX.Main.pas' {MainForm},
  Syntax.Code.Haste in 'Syntax.Code.Haste.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
