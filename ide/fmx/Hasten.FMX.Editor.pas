unit Hasten.FMX.Editor;

{ An editor tab: a memo drawn by FMXRichMemo (github.com/HemulGM/FMXRichMemo) with Haste colours, line numbers
  and the current line, on a dark background whatever the platform's style. The memo's presentation is made
  some time after the tab; Configure is called until it says it is ready. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, FMX.Types, FMX.Controls, FMX.Graphics,
  FMX.TabControl, FMX.Memo, FMX.Memo.Types, FMX.ScrollBox, FMX.Controls.Presentation, FMX.Text,
  FMX.Text.TextEditor, FMX.RichEdit.Style, Syntax.Code.Haste;

type
  { A memo always drawn by FMXRichMemo: one made in code may choose its presentation before an
    OnPresentationNameChoosing event could be assigned, so the name is given here. }
  THasteMemo = class(TMemo)
  protected
    function DefinePresentationName: string; override;
  end;

  TEditorTab = class(TTabItem)
  private
    FMemo: THasteMemo;
    FFileName: string;
    FModified: Boolean;
    FReady: Boolean;
    FLoading: Boolean;
    FLineNumbers: Boolean;
    FOnChange: TNotifyEvent;
    FOnCaret: TCaretPositionChanged;
    procedure MemoChange(Sender: TObject);
    procedure PaintBackground(Sender: TObject; ACanvas: TCanvas);
    procedure SetFileName(const Value: string);
    procedure SetModified(Value: Boolean);
    function GetTitle: string;
    function GetRich: TRichEditStyled;
    procedure UpdateText;
    function GetFontFamily: string;
    procedure SetFontFamily(const Value: string);
    function GetFontSize: Single;
    procedure SetFontSize(Value: Single);
    procedure SetLineNumbers(Value: Boolean);
    procedure FontChanged;
  public
    constructor Create(AOwner: TComponent); override;
    function Configure: Boolean;                 // True once the presentation exists and is set up
    procedure Recolour;                          // after new words or aliases
    procedure Load(const Path: string);
    procedure Save(const Path: string);
    procedure GoToLine(Line: Integer);
    property Memo: THasteMemo read FMemo;
    property Rich: TRichEditStyled read GetRich;  // nil until the presentation exists
    property FileName: string read FFileName write SetFileName;
    property Modified: Boolean read FModified write SetModified;
    property Title: string read GetTitle;
    property Ready: Boolean read FReady;
    property FontFamily: string read GetFontFamily write SetFontFamily;
    property FontSize: Single read GetFontSize write SetFontSize;
    property LineNumbers: Boolean read FLineNumbers write SetLineNumbers;
    property OnChange: TNotifyEvent read FOnChange write FOnChange;
    property OnCaret: TCaretPositionChanged read FOnCaret write FOnCaret;
  end;

const
{$IF Defined(MSWINDOWS)}
  MonoFont = 'Consolas';
{$ELSEIF Defined(MACOS)}
  MonoFont = 'Menlo';
{$ELSE}
  MonoFont = 'DejaVu Sans Mono';
{$ENDIF}
  EditorBackground = $FF1E1E1E;
  EditorText = $FFD4D4D4;

implementation

function THasteMemo.DefinePresentationName: string;
begin
  Result := 'RichEditStyled';                  // registered by FMX.RichEdit.Style
end;

constructor TEditorTab.Create(AOwner: TComponent);
begin
  inherited;
  FMemo := THasteMemo.Create(Self);
  FMemo.Parent := Self;
  FMemo.Align := TAlignLayout.Client;
  FMemo.StyledSettings := FMemo.StyledSettings - [TStyledSetting.Family, TStyledSetting.Size,
    TStyledSetting.FontColor];
  FMemo.TextSettings.Font.Family := MonoFont;
  FMemo.TextSettings.Font.Size := 14;
  FMemo.TextSettings.FontColor := EditorText;
  FMemo.OnChangeTracking := MemoChange;
  FLineNumbers := True;
  UpdateText;
end;

function TEditorTab.GetRich: TRichEditStyled;
begin
  if FMemo.Presentation is TRichEditStyled then
    Result := TRichEditStyled(FMemo.Presentation)
  else
    Result := nil;
end;

function TEditorTab.Configure: Boolean;
begin
  if FReady then Exit(True);
  if Rich = nil then Exit(False);
  Rich.ShowGutter := FLineNumbers;
  Rich.ShowCurrentLine := True;
  Rich.ColorCurrentLine := $18FFFFFF;
  Rich.ColorLineNumberNormal := $FF808080;
  Rich.ColorLineNumberActive := EditorText;
  Rich.OnDrawBefore := PaintBackground;
  Rich.OnChangeCaretPos := FOnCaret;
  FReady := True;
  FontChanged;
  Result := True;
end;

{ The syntax is made again, so every line is coloured afresh. }
procedure TEditorTab.Recolour;
begin
  if not FReady then Exit;
  Rich.SetCodeSyntaxName('haste', FMemo.TextSettings.Font, EditorText);
  FMemo.Repaint;
end;

function TEditorTab.GetFontFamily: string;
begin
  Result := FMemo.TextSettings.Font.Family;
end;

procedure TEditorTab.SetFontFamily(const Value: string);
begin
  if (Value = '') or (Value = FontFamily) then Exit;
  FMemo.TextSettings.Font.Family := Value;
  FontChanged;
end;

function TEditorTab.GetFontSize: Single;
begin
  Result := FMemo.TextSettings.Font.Size;
end;

procedure TEditorTab.SetFontSize(Value: Single);
begin
  if (Value < 6) or (Value = FontSize) then Exit;
  FMemo.TextSettings.Font.Size := Value;
  FontChanged;
end;

procedure TEditorTab.SetLineNumbers(Value: Boolean);
begin
  FLineNumbers := Value;
  if FReady then Rich.ShowGutter := Value;
end;

{ The line numbers follow the editor's font, a point smaller; the colours are made again in the new font. }
procedure TEditorTab.FontChanged;
begin
  if not FReady then Exit;
  Rich.GutterFont.Family := FontFamily;
  Rich.GutterFont.Size := FontSize - 1;
  Recolour;
end;

procedure TEditorTab.PaintBackground(Sender: TObject; ACanvas: TCanvas);
begin
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := EditorBackground;
  ACanvas.FillRect(RectF(-100000, -100000, 100000, 10000000), 0, 0, AllCorners, 1);
end;

procedure TEditorTab.MemoChange(Sender: TObject);
begin
  if FLoading then Exit;
  Modified := True;
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TEditorTab.Load(const Path: string);
begin
  FLoading := True;
  try
    FMemo.Lines.LoadFromFile(Path, TEncoding.UTF8);
  finally
    FLoading := False;
  end;
  FileName := Path;
  Modified := False;
end;

procedure TEditorTab.Save(const Path: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Assign(FMemo.Lines);
    Lines.WriteBOM := False;                   // haste.py reads plain UTF-8
    Lines.SaveToFile(Path, TEncoding.UTF8);
  finally
    Lines.Free;
  end;
  FileName := Path;
  Modified := False;
end;

procedure TEditorTab.GoToLine(Line: Integer);
begin
  if (Line < 1) or (Line > FMemo.Lines.Count) then Exit;
  FMemo.CaretPosition := TCaretPosition.Create(Line - 1, 0);
  if FMemo.CanFocus then FMemo.SetFocus;
end;

procedure TEditorTab.SetFileName(const Value: string);
begin
  FFileName := Value;
  UpdateText;
end;

procedure TEditorTab.SetModified(Value: Boolean);
begin
  if FModified = Value then Exit;
  FModified := Value;
  UpdateText;
end;

function TEditorTab.GetTitle: string;
begin
  if FFileName <> '' then Result := ExtractFileName(FFileName) else Result := 'Untitled';
end;

procedure TEditorTab.UpdateText;
begin
  if FModified then Text := Title + '*' else Text := Title;
end;

end.
