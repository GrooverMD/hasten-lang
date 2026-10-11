unit Hasten.Settings;

{ The Settings dialog. Like the main form it is built in code. Each setting is a property: the main form
  sets them, calls Execute, and reads them back if it returns True. }

interface

uses
  System.SysUtils, System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.Dialogs, Vcl.Graphics, Vcl.Themes;

type
  TSettingsDialog = class(TForm)
  private
    FFontName: string;
    FFontSize: Integer;
    FFontLabel: TLabel;
    FTabWidth: TEdit;
    FRightEdge: TEdit;
    FLineNumbers: TCheckBox;
    FStyle: TComboBox;
    FPython: TEdit;
    FHastePy: TEdit;
    FClearOutput: TCheckBox;
    FReopen: TCheckBox;
    function Group(const Caption: string; Top, Height: Integer): TGroupBox;
    function AddLabel(Parent: TWinControl; const Text: string; Left, Top: Integer): TLabel;
    function NumberBox(Parent: TWinControl; Left, Top: Integer): TEdit;
    procedure ShowFont;
    procedure ChooseFont(Sender: TObject);
    procedure BrowseHastePy(Sender: TObject);
    function GetTabWidth: Integer;
    procedure SetTabWidth(Value: Integer);
    function GetRightEdge: Integer;
    procedure SetRightEdge(Value: Integer);
    function GetLineNumbers: Boolean;
    procedure SetLineNumbers(Value: Boolean);
    function GetVclStyle: string;
    procedure SetVclStyle(const Value: string);
    function GetPython: string;
    procedure SetPython(const Value: string);
    function GetHastePy: string;
    procedure SetHastePy(const Value: string);
    function GetClearOutput: Boolean;
    procedure SetClearOutput(Value: Boolean);
    function GetReopen: Boolean;
    procedure SetReopen(Value: Boolean);
    procedure SetFontName(const Value: string);
    procedure SetFontSize(Value: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    function Execute: Boolean;
    property FontName: string read FFontName write SetFontName;
    property FontSize: Integer read FFontSize write SetFontSize;
    property TabWidth: Integer read GetTabWidth write SetTabWidth;
    property RightEdge: Integer read GetRightEdge write SetRightEdge;       // 0: no margin line
    property LineNumbers: Boolean read GetLineNumbers write SetLineNumbers;
    property VclStyle: string read GetVclStyle write SetVclStyle;          // a VCL style linked into Hasten (not StyleName: TControl has one)
    property Python: string read GetPython write SetPython;
    property HastePy: string read GetHastePy write SetHastePy;
    property ClearOutput: Boolean read GetClearOutput write SetClearOutput; // on each Run, Build and Run Tests
    property Reopen: Boolean read GetReopen write SetReopen;               // last session's files at start
  end;

implementation

constructor TSettingsDialog.Create(AOwner: TComponent);
var
  G: TGroupBox;
  B: TButton;
  S: string;
begin
  inherited CreateNew(AOwner);                  // no .dfm
  Caption := 'Settings';
  BorderStyle := bsDialog;
  Position := poOwnerFormCenter;
  ClientWidth := 520;
  ClientHeight := 400;

  G := Group('Editor', 8, 110);
  AddLabel(G, 'Font:', 12, 26);
  FFontLabel := AddLabel(G, '', 110, 26);
  B := TButton.Create(Self);
  B.Parent := G;
  B.SetBounds(400, 20, 96, 25);
  B.Caption := 'Choose...';
  B.OnClick := ChooseFont;
  AddLabel(G, 'Tab width:', 12, 56);
  FTabWidth := NumberBox(G, 110, 52);
  AddLabel(G, 'Right margin at column (0 for none):', 180, 56);
  FRightEdge := NumberBox(G, 400, 52);
  FLineNumbers := TCheckBox.Create(Self);
  FLineNumbers.Parent := G;
  FLineNumbers.SetBounds(12, 82, 200, 20);
  FLineNumbers.Caption := 'Show line numbers';

  G := Group('Appearance', 126, 56);
  AddLabel(G, 'Style:', 12, 26);
  FStyle := TComboBox.Create(Self);
  FStyle.Parent := G;
  FStyle.SetBounds(110, 22, 260, 22);
  FStyle.Style := csDropDownList;
  for S in TStyleManager.StyleNames do          // only the styles linked into Hasten can be chosen
    FStyle.Items.Add(S);
  FStyle.Sorted := True;

  G := Group('Running', 190, 110);
  AddLabel(G, 'Python:', 12, 26);
  FPython := TEdit.Create(Self);
  FPython.Parent := G;
  FPython.SetBounds(110, 22, 260, 22);
  FPython.Hint := 'The command that runs Python, e.g. python or py, or the full path to python.exe';
  FPython.ShowHint := True;
  AddLabel(G, 'haste.py:', 12, 54);
  FHastePy := TEdit.Create(Self);
  FHastePy.Parent := G;
  FHastePy.SetBounds(110, 50, 284, 22);
  B := TButton.Create(Self);
  B.Parent := G;
  B.SetBounds(400, 48, 96, 25);
  B.Caption := 'Browse...';
  B.OnClick := BrowseHastePy;
  FClearOutput := TCheckBox.Create(Self);
  FClearOutput.Parent := G;
  FClearOutput.SetBounds(12, 82, 300, 20);
  FClearOutput.Caption := 'Clear the output on each run';

  G := Group('Starting', 308, 50);
  FReopen := TCheckBox.Create(Self);
  FReopen.Parent := G;
  FReopen.SetBounds(12, 22, 300, 20);
  FReopen.Caption := 'Reopen the files from last time';

  B := TButton.Create(Self);
  B.Parent := Self;
  B.SetBounds(ClientWidth - 196, ClientHeight - 34, 90, 26);
  B.Caption := 'OK';
  B.Default := True;
  B.ModalResult := mrOk;
  B := TButton.Create(Self);
  B.Parent := Self;
  B.SetBounds(ClientWidth - 98, ClientHeight - 34, 90, 26);
  B.Caption := 'Cancel';
  B.Cancel := True;
  B.ModalResult := mrCancel;
end;

function TSettingsDialog.Group(const Caption: string; Top, Height: Integer): TGroupBox;
begin
  Result := TGroupBox.Create(Self);
  Result.Parent := Self;
  Result.SetBounds(8, Top, ClientWidth - 16, Height);
  Result.Caption := ' ' + Caption + ' ';
end;

function TSettingsDialog.AddLabel(Parent: TWinControl; const Text: string; Left, Top: Integer): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := Parent;
  Result.SetBounds(Left, Top, 90, 16);
  Result.AutoSize := True;
  Result.Caption := Text;
end;

function TSettingsDialog.NumberBox(Parent: TWinControl; Left, Top: Integer): TEdit;
begin
  Result := TEdit.Create(Self);
  Result.Parent := Parent;
  Result.SetBounds(Left, Top, 50, 22);
  Result.NumbersOnly := True;
end;

function TSettingsDialog.Execute: Boolean;
begin
  Result := ShowModal = mrOk;
end;

procedure TSettingsDialog.ShowFont;
begin
  FFontLabel.Caption := Format('%s, %d pt', [FFontName, FFontSize]);
end;

{ Only fixed-pitch fonts: code needs columns that line up. }
procedure TSettingsDialog.ChooseFont(Sender: TObject);
var
  Dialog: TFontDialog;
begin
  Dialog := TFontDialog.Create(nil);
  try
    Dialog.Options := [fdFixedPitchOnly, fdForceFontExist, fdNoStyleSel];
    Dialog.Font.Name := FFontName;
    Dialog.Font.Size := FFontSize;
    if Dialog.Execute then
    begin
      FFontName := Dialog.Font.Name;
      FFontSize := Dialog.Font.Size;
      ShowFont;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TSettingsDialog.BrowseHastePy(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Title := 'Where is haste.py?';
    Dialog.Filter := 'haste.py|haste.py|Python files (*.py)|*.py';
    Dialog.FileName := FHastePy.Text;
    if Dialog.Execute then
      FHastePy.Text := Dialog.FileName;
  finally
    Dialog.Free;
  end;
end;

procedure TSettingsDialog.SetFontName(const Value: string);
begin
  FFontName := Value;
  ShowFont;
end;

procedure TSettingsDialog.SetFontSize(Value: Integer);
begin
  FFontSize := Value;
  ShowFont;
end;

function TSettingsDialog.GetTabWidth: Integer;
begin
  Result := StrToIntDef(FTabWidth.Text, 2);
  if Result < 1 then Result := 1;
  if Result > 16 then Result := 16;
end;

procedure TSettingsDialog.SetTabWidth(Value: Integer);
begin
  FTabWidth.Text := Value.ToString;
end;

function TSettingsDialog.GetRightEdge: Integer;
begin
  Result := StrToIntDef(FRightEdge.Text, 0);
  if Result > 1000 then Result := 1000;
end;

procedure TSettingsDialog.SetRightEdge(Value: Integer);
begin
  FRightEdge.Text := Value.ToString;
end;

function TSettingsDialog.GetLineNumbers: Boolean;
begin
  Result := FLineNumbers.Checked;
end;

procedure TSettingsDialog.SetLineNumbers(Value: Boolean);
begin
  FLineNumbers.Checked := Value;
end;

function TSettingsDialog.GetVclStyle: string;
begin
  Result := FStyle.Text;
end;

procedure TSettingsDialog.SetVclStyle(const Value: string);
begin
  FStyle.ItemIndex := FStyle.Items.IndexOf(Value);
end;

function TSettingsDialog.GetPython: string;
begin
  Result := Trim(FPython.Text);
  if Result = '' then Result := 'python';
end;

procedure TSettingsDialog.SetPython(const Value: string);
begin
  FPython.Text := Value;
end;

function TSettingsDialog.GetHastePy: string;
begin
  Result := Trim(FHastePy.Text);
end;

procedure TSettingsDialog.SetHastePy(const Value: string);
begin
  FHastePy.Text := Value;
end;

function TSettingsDialog.GetClearOutput: Boolean;
begin
  Result := FClearOutput.Checked;
end;

procedure TSettingsDialog.SetClearOutput(Value: Boolean);
begin
  FClearOutput.Checked := Value;
end;

function TSettingsDialog.GetReopen: Boolean;
begin
  Result := FReopen.Checked;
end;

procedure TSettingsDialog.SetReopen(Value: Boolean);
begin
  FReopen.Checked := Value;
end;

end.
