program HastenFMX;

{ Hasten for FireMonkey: Windows, macOS and Linux. See README.md. }

uses
  System.StartUpCopy,
  FMX.Forms,
  Hasten.FMX.Main in 'Hasten.FMX.Main.pas' {MainForm},
  Hasten.FMX.Editor in 'Hasten.FMX.Editor.pas',
  Hasten.FMX.Options in 'Hasten.FMX.Options.pas' {OptionsForm},
  Hasten.Runner in '..\common\Hasten.Runner.pas',
  Hasten.Project in '..\common\Hasten.Project.pas',
  Syntax.Code.Haste in 'Syntax.Code.Haste.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
