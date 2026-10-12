program HastenFmxTest;

{ A test of FMXRichMemo as the editor for an FMX Hasten. See README.md. }

uses
  System.StartUpCopy,
  FMX.Forms,
  Hasten.FmxTest.Main in 'Hasten.FmxTest.Main.pas',
  Syntax.Code.Haste in 'Syntax.Code.Haste.pas';

begin
  Application.Initialize;
  Application.CreateForm(TTestForm, TestForm);
  Application.Run;
end.
