unit Hasten.FMX.Text;

{ One text size for Hasten's windows, whatever the style: Tools > Settings > Window text size. Some styles
  (the Windows 10 Modern ones among them) define their own font, 16 pixels, for every control they draw:
  tabs, tree items, labels and buttons come out half as big again as the menu bar, which the system draws.
  Each control still using the style's size is given TextSize instead, and marked, so a new TextSize reaches
  it too; one whose size was set on purpose (the editor, the output, the toolbar's pictures) is left alone. }

interface

uses
  System.Classes, FMX.Types, FMX.Controls, FMX.Graphics;

const
  DefaultTextSize = 12;                          // pixels: 9 pt, as Hasten for VCL and Windows itself

var
  TextSize: Single = DefaultTextSize;            // set before UseTextSizes; kept in HastenFMX.ini

procedure UseTextSize(Obj: TFmxObject);           // one control, e.g. a tab or tree item made in code
procedure UseTextSizes(Owner: TComponent);        // every control a form or frame owns

implementation

uses
  System.SysUtils;

const
  Marked = -9.0;                                 // TagFloat of a control whose size follows TextSize

procedure UseTextSize(Obj: TFmxObject);
var
  Settings: ITextSettings;
begin
  if not Supports(Obj, ITextSettings, Settings) then Exit;
  if TStyledSetting.Size in Settings.StyledSettings then
  begin
    Settings.StyledSettings := Settings.StyledSettings - [TStyledSetting.Size];
    Obj.TagFloat := Marked;
  end
  else if Obj.TagFloat <> Marked then            // set on purpose
    Exit;
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
