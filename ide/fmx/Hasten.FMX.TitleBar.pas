unit Hasten.FMX.TitleBar;

{ The window's title bar and edges in HasteSlate's colours, drawn by Windows itself. A style can draw them
  instead (windowborderstyle), but FMX's styled frame stopped the form taking any clicks, so Windows keeps
  the frame and is asked for its colours: Windows 11 takes a caption, text and border colour; Windows 10 only
  the dark title bar. Elsewhere, and on a Windows that knows none of this, nothing changes. Each form calls
  this from its CreateHandle, so a recreated window is coloured too. }

interface

uses
  FMX.Forms;

procedure ColourTitleBar(Form: TCommonCustomForm);

implementation

{$IFDEF MSWINDOWS}
uses
  Winapi.Windows, Winapi.DwmApi, FMX.Platform.Win;

const
  DWMWA_USE_IMMERSIVE_DARK_MODE = 20;            // Windows 10 20H1 and later
  DWMWA_BORDER_COLOR = 34;                       // Windows 11
  DWMWA_CAPTION_COLOR = 35;
  DWMWA_TEXT_COLOR = 36;
  CaptionColour: COLORREF = $00362D24;           // HasteSlate's PANEL $242D36, as Windows writes colours: $00BBGGRR
  TextColour: COLORREF = $00EBE7E3;              // TEXT $E3E7EB
  BorderColour: COLORREF = $006E6255;            // BORDER $55626E

procedure ColourTitleBar(Form: TCommonCustomForm);
var
  Wnd: HWND;
  Dark: BOOL;
  Colour: COLORREF;
begin
  if (Form = nil) or (Form.Handle = nil) then Exit;
  Wnd := FormToHWND(Form);
  if Wnd = 0 then Exit;
  Dark := True;                                  // each call fails quietly where Windows does not know it
  DwmSetWindowAttribute(Wnd, DWMWA_USE_IMMERSIVE_DARK_MODE, @Dark, SizeOf(Dark));
  Colour := CaptionColour;
  DwmSetWindowAttribute(Wnd, DWMWA_CAPTION_COLOR, @Colour, SizeOf(Colour));
  Colour := TextColour;
  DwmSetWindowAttribute(Wnd, DWMWA_TEXT_COLOR, @Colour, SizeOf(Colour));
  Colour := BorderColour;
  DwmSetWindowAttribute(Wnd, DWMWA_BORDER_COLOR, @Colour, SizeOf(Colour));
end;
{$ELSE}
procedure ColourTitleBar(Form: TCommonCustomForm);
begin
end;
{$ENDIF}

end.
