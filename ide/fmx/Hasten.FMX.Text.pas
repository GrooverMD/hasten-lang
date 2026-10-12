unit Hasten.FMX.Text;

{ One text size for Hasten's windows, whatever the style. Some styles (the Windows 10 Modern ones among them)
  define their own font, 16 pixels, for every control they draw: tabs, tree items, labels and buttons come
  out half as big again as the menu bar, which the system draws. Each control still using the style's size
  is given TextSize instead; one whose size was set on purpose (the editor, the output, the toolbar's
  pictures) is left alone. }

interface

uses
  System.Classes, FMX.Types, FMX.Controls, FMX.Graphics;

const
  TextSize = 12;                                 // pixels: 9 pt, as Hasten for VCL and Windows itself

procedure UseTextSize(Obj: TFmxObject);           // one control, e.g. a tab or tree item made in code
procedure UseTextSizes(Owner: TComponent);        // every control a form or frame owns

implementation

uses
  System.SysUtils;

procedure UseTextSize(Obj: TFmxObject);
var
  Settings: ITextSettings;
begin
  if not Supports(Obj, ITextSettings, Settings) then Exit;
  if not (TStyledSetting.Size in Settings.StyledSettings) then Exit;     // set on purpose
  Settings.StyledSettings := Settings.StyledSettings - [TStyledSetting.Size];
  Settings.TextSettings.Font.Size := TextSize;
end;

procedure UseTextSizes(Owner: TComponent);
var
  I: Integer;
begin
  for I := 0 to Owner.ComponentCount - 1 do
    if Owner.Components[I] is TFmxObject then
      UseTextSize(TFmxObject(Owner.Components[I]));
end;

end.
