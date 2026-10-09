program Hasten;

uses
  Vcl.Forms,
  Hasten.Runner in 'Hasten.Runner.pas',
  Hasten.Main in 'Hasten.Main.pas',
  SynHighlighterHaste in 'SynHighlighterHaste.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Hasten';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
