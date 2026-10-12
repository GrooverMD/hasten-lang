program Hasten;

uses
  Vcl.Forms,
  Hasten.Runner in '..\common\Hasten.Runner.pas',
  Hasten.Names in '..\common\Hasten.Names.pas',
  Hasten.Project in '..\common\Hasten.Project.pas',
  Hasten.Main in 'Hasten.Main.pas',
  SynHighlighterHaste in 'SynHighlighterHaste.pas',
  Vcl.Themes,
  Vcl.Styles;

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Windows10 SlateGray');
  Application.Title := 'Hasten';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
