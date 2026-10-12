unit Hasten.FMX.Insight;

{ Help Insight for Hasten for FMX: rest the mouse on a name in the editor and a tip shows what it is (its
  declaration, its help comment, where it is declared, and, after a run or build, the types it was compiled
  with). What the tip says comes from Hasten.Names, shared with Hasten for VCL; the editor tab finds the name
  under the mouse (TEditorTab.NameAtPoint).

  As in Hasten for VCL it watches the mouse with a timer: a name under a still mouse for Delay milliseconds
  gets its tip, and the tip goes as soon as the mouse leaves the name, the caret moves or the text scrolls.
  The tip is a rectangle drawn on the form above everything, so it never takes the focus. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Math, FMX.Types, FMX.Controls,
  FMX.Forms, FMX.Graphics, FMX.Objects, FMX.TextLayout, FMX.TabControl, FMX.Text, Hasten.Names,
  Hasten.FMX.Editor;

type
  THasteInsight = class(TComponent)
  private
    FNames: THasteNames;
    FForm: TCommonCustomForm;
    FTabs: TTabControl;
    FTimer: TTimer;
    FTip: TRectangle;
    FText: TText;
    FEnabled: Boolean;
    FDelay: Integer;
    FLastPos: TPointF;
    FStill: Integer;                            // timer ticks the mouse has not moved
    FShown: Boolean;
    FShownTab: TEditorTab;
    FShownWord: string;
    FShownCaret: TCaretPosition;
    FShownView: TPointF;
    procedure TimerFire(Sender: TObject);
    function ActiveEditor: TEditorTab;
    procedure Show(const Text: string; const At: TPointF; LineHeight: Single);
    procedure SetDelay(Value: Integer);
    procedure SetEnabled(Value: Boolean);
  public
    constructor Create(AForm: TCommonCustomForm; ATabs: TTabControl); reintroduce;
    destructor Destroy; override;
    procedure Hide;
    property Names: THasteNames read FNames;                 // what haste.py says about each name
    property Enabled: Boolean read FEnabled write SetEnabled;
    property Delay: Integer read FDelay write SetDelay;      // milliseconds of stillness before a tip
  end;

implementation

const
  Tick = 100;                                   // ms between looks at the mouse
  MaxTipWidth = 560;
  TipPadding = 8;
  TipBackground = $FF2D2D30;
  TipBorder = $FF5A5A5A;

constructor THasteInsight.Create(AForm: TCommonCustomForm; ATabs: TTabControl);
begin
  inherited Create(AForm);
  FForm := AForm;
  FTabs := ATabs;
  FNames := THasteNames.Create;
  FDelay := 600;
  FEnabled := True;

  FTip := TRectangle.Create(Self);
  FTip.Visible := False;
  FTip.HitTest := False;
  FTip.Fill.Color := TipBackground;
  FTip.Stroke.Color := TipBorder;
  FTip.XRadius := 3;
  FTip.YRadius := 3;
  FTip.Parent := FForm;
  FText := TText.Create(Self);
  FText.HitTest := False;
  FText.Parent := FTip;
  FText.Position.Point := PointF(TipPadding, TipPadding);
  FText.WordWrap := True;
  FText.TextSettings.HorzAlign := TTextAlign.Leading;
  FText.TextSettings.VertAlign := TTextAlign.Leading;
  FText.TextSettings.Font.Size := 12;
  FText.TextSettings.FontColor := EditorText;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := Tick;
  FTimer.OnTimer := TimerFire;
end;

destructor THasteInsight.Destroy;
begin
  FTimer.Enabled := False;
  FNames.Free;
  inherited;
end;

function THasteInsight.ActiveEditor: TEditorTab;
begin
  if FTabs.ActiveTab is TEditorTab then Result := TEditorTab(FTabs.ActiveTab) else Result := nil;
end;

procedure THasteInsight.TimerFire(Sender: TObject);
var
  Pos, At: TPointF;
  Tab: TEditorTab;
  Word, Text: string;
  H: Single;
begin
  if not FEnabled or not FForm.Active then
  begin
    Hide;
    Exit;
  end;
  Pos := FForm.ScreenToClient(Screen.MousePos);
  Tab := ActiveEditor;
  if FShown then                                // keep the tip while the mouse stays on the name
  begin
    if (Tab <> FShownTab) or (Tab.NameAtPoint(Pos, At, H) <> FShownWord) or
      (Tab.Memo.CaretPosition <> FShownCaret) or (Tab.Memo.ViewportPosition <> FShownView) then
      Hide;
    Exit;
  end;
  if Pos <> FLastPos then
  begin
    FLastPos := Pos;
    FStill := 0;
    Exit;
  end;
  Inc(FStill);
  if (FStill * Tick <> FDelay) or (Tab = nil) then Exit;     // once per resting place
  Word := Tab.NameAtPoint(Pos, At, H);
  Text := FNames.TextFor(Word);
  if Text = '' then Exit;
  Show(Text, At, H);
  FShownTab := Tab;
  FShownWord := Word;
  FShownCaret := Tab.Memo.CaretPosition;
  FShownView := Tab.Memo.ViewportPosition;
end;

{ Below the name, or above its line when there is no room below; inside the window either way. }
procedure THasteInsight.Show(const Text: string; const At: TPointF; LineHeight: Single);
var
  Layout: TTextLayout;
  W, H, X, Y: Single;
begin
  Layout := TTextLayoutManager.DefaultTextLayout.Create;
  try
    Layout.BeginUpdate;
    Layout.Font.Assign(FText.TextSettings.Font);
    Layout.WordWrap := True;
    Layout.MaxSize := PointF(MaxTipWidth, 100000);
    Layout.Text := Text;
    Layout.EndUpdate;
    W := Ceil(Layout.TextWidth) + 2;
    H := Ceil(Layout.TextHeight) + 2;
  finally
    Layout.Free;
  end;
  FText.Size.Size := TSizeF.Create(W, H);
  FText.Text := Text;
  FTip.Size.Size := TSizeF.Create(W + 2 * TipPadding, H + 2 * TipPadding);
  X := Min(At.X, FForm.ClientWidth - FTip.Width - 4);
  Y := At.Y;
  if Y + FTip.Height > FForm.ClientHeight then
    Y := At.Y - LineHeight - 4 - FTip.Height;
  FTip.Position.Point := PointF(Max(4, X), Max(4, Y));
  FTip.Visible := True;
  FTip.BringToFront;
  FShown := True;
end;

procedure THasteInsight.Hide;
begin
  FTip.Visible := False;
  FShown := False;
  FShownTab := nil;
end;

procedure THasteInsight.SetDelay(Value: Integer);
begin
  FDelay := Max(Tick, Value div Tick * Tick);
end;

procedure THasteInsight.SetEnabled(Value: Boolean);
begin
  FEnabled := Value;
  if not Value then Hide;
end;

end.
