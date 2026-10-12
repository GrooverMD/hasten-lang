unit Hasten.FMX.Settings;

{ The Settings dialog, designed in Hasten.FMX.Settings.fmx. Each setting is a property: the main form sets
  them, calls Execute, and reads them back if it returns True. FMX has no font dialog, so the font is a name
  (a list of fixed-pitch fonts, or type one) and a size. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.Graphics, FMX.Dialogs, FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts, FMX.Edit, FMX.ComboEdit,
  FMX.EditBox, FMX.SpinBox, Hasten.FMX.Text;

type
  TSettingsForm = class(TForm)
    EditorGroup: TGroupBox;
    FontLabel: TLabel;
    FontCombo: TComboEdit;
    SizeLabel: TLabel;
    SizeBox: TSpinBox;
    TabWidthLabel: TLabel;
    TabWidthBox: TSpinBox;
    RightEdgeLabel: TLabel;
    RightEdgeBox: TSpinBox;
    LineNumbersCheck: TCheckBox;
    WindowGroup: TGroupBox;
    TextSizeLabel: TLabel;
    TextSizeBox: TSpinBox;
    TextSizeHint: TLabel;
    RunningGroup: TGroupBox;
    PythonLabel: TLabel;
    PythonEdit: TEdit;
    HastePyLabel: TLabel;
    HastePyEdit: TEdit;
    BrowseButton: TButton;
    ClearOutputCheck: TCheckBox;
    StartingGroup: TGroupBox;
    ReopenCheck: TCheckBox;
    ButtonBar: TLayout;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure BrowseButtonClick(Sender: TObject);
  private
    function GetFontFamily: string;
    procedure SetFontFamily(const Value: string);
    function GetFontSize: Single;
    procedure SetFontSize(Value: Single);
    function GetTabWidth: Integer;
    procedure SetTabWidth(Value: Integer);
    function GetRightEdge: Integer;
    procedure SetRightEdge(Value: Integer);
    function GetLineNumbers: Boolean;
    procedure SetLineNumbers(Value: Boolean);
    function GetTextSize: Integer;
    procedure SetTextSize(Value: Integer);
    function GetPython: string;
    procedure SetPython(const Value: string);
    function GetHastePy: string;
    procedure SetHastePy(const Value: string);
    function GetClearOutput: Boolean;
    procedure SetClearOutput(Value: Boolean);
    function GetReopen: Boolean;
    procedure SetReopen(Value: Boolean);
  public
    function Execute: Boolean;
    property FontFamily: string read GetFontFamily write SetFontFamily;
    property FontSize: Single read GetFontSize write SetFontSize;
    property TabWidth: Integer read GetTabWidth write SetTabWidth;      // spaces to a tab stop
    property RightEdge: Integer read GetRightEdge write SetRightEdge;   // 0: no margin line
    property LineNumbers: Boolean read GetLineNumbers write SetLineNumbers;
    property TextSize: Integer read GetTextSize write SetTextSize;      // the window's text, in pixels
    property Python: string read GetPython write SetPython;
    property HastePy: string read GetHastePy write SetHastePy;
    property ClearOutput: Boolean read GetClearOutput write SetClearOutput;   // on each Run, Build and Run Tests
    property Reopen: Boolean read GetReopen write SetReopen;                  // last session's files at start
  end;

implementation

{$R *.fmx}

const
{$IF Defined(MSWINDOWS)}
  FixedFonts: array[0..4] of string = ('Consolas', 'Cascadia Mono', 'Cascadia Code', 'Courier New', 'Lucida Console');
{$ELSEIF Defined(MACOS)}
  FixedFonts: array[0..3] of string = ('Menlo', 'SF Mono', 'Monaco', 'Courier New');
{$ELSE}
  FixedFonts: array[0..3] of string = ('DejaVu Sans Mono', 'Liberation Mono', 'Noto Sans Mono', 'Ubuntu Mono');
{$ENDIF}

procedure TSettingsForm.FormCreate(Sender: TObject);
var
  F: string;
begin
  for F in FixedFonts do
    FontCombo.Items.Add(F);
  Hasten.FMX.Text.UseTextSizes(Self);
end;

function TSettingsForm.Execute: Boolean;
begin
  Result := ShowModal = mrOk;
end;

procedure TSettingsForm.BrowseButtonClick(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Title := 'Where is haste.py?';
    Dialog.Filter := 'haste.py|haste.py|Python files (*.py)|*.py';
    Dialog.FileName := HastePy;
    if Dialog.Execute then
      HastePy := Dialog.FileName;
  finally
    Dialog.Free;
  end;
end;

function TSettingsForm.GetFontFamily: string;
begin
  Result := FontCombo.Text.Trim;
end;

procedure TSettingsForm.SetFontFamily(const Value: string);
begin
  FontCombo.Text := Value;
end;

function TSettingsForm.GetFontSize: Single;
begin
  Result := SizeBox.Value;
end;

procedure TSettingsForm.SetFontSize(Value: Single);
begin
  SizeBox.Value := Round(Value);
end;

function TSettingsForm.GetTabWidth: Integer;
begin
  Result := Round(TabWidthBox.Value);
end;

procedure TSettingsForm.SetTabWidth(Value: Integer);
begin
  TabWidthBox.Value := Value;
end;

function TSettingsForm.GetRightEdge: Integer;
begin
  Result := Round(RightEdgeBox.Value);
end;

procedure TSettingsForm.SetRightEdge(Value: Integer);
begin
  RightEdgeBox.Value := Value;
end;

function TSettingsForm.GetLineNumbers: Boolean;
begin
  Result := LineNumbersCheck.IsChecked;
end;

procedure TSettingsForm.SetLineNumbers(Value: Boolean);
begin
  LineNumbersCheck.IsChecked := Value;
end;

function TSettingsForm.GetTextSize: Integer;
begin
  Result := Round(TextSizeBox.Value);
end;

procedure TSettingsForm.SetTextSize(Value: Integer);
begin
  TextSizeBox.Value := Value;
end;

function TSettingsForm.GetPython: string;
begin
  Result := PythonEdit.Text.Trim;
end;

procedure TSettingsForm.SetPython(const Value: string);
begin
  PythonEdit.Text := Value;
end;

function TSettingsForm.GetHastePy: string;
begin
  Result := HastePyEdit.Text.Trim;
end;

procedure TSettingsForm.SetHastePy(const Value: string);
begin
  HastePyEdit.Text := Value;
end;

function TSettingsForm.GetClearOutput: Boolean;
begin
  Result := ClearOutputCheck.IsChecked;
end;

procedure TSettingsForm.SetClearOutput(Value: Boolean);
begin
  ClearOutputCheck.IsChecked := Value;
end;

function TSettingsForm.GetReopen: Boolean;
begin
  Result := ReopenCheck.IsChecked;
end;

procedure TSettingsForm.SetReopen(Value: Boolean);
begin
  ReopenCheck.IsChecked := Value;
end;

end.
