program Hasten;

uses
  Vcl.Forms,
  Hasten.Runner in 'Hasten.Runner.pas',
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
