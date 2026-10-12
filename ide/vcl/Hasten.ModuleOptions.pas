unit Hasten.ModuleOptions;

{ The Module Options dialog: what to build a program for, and the values to run it with. Each program
  (module) keeps its own, in Hasten.ini. The switches are read from the program's own source, so the list
  is always the one it has now. Built in code, like the rest of Hasten. }

interface

uses
  System.SysUtils, System.Classes, System.StrUtils, System.RegularExpressions, Hasten.Project, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls,
  Vcl.Grids, Vcl.ExtCtrls;

type
  TModuleOptionsDialog = class(TForm)
  private
    FThisSystem: TRadioButton;
    FOther: TRadioButton;
    FTargets: array[0..3] of TCheckBox;
    FGrid: TStringGrid;
    FHelp: TLabel;
    FSwitches: TArray<TSwitchInfo>;
    procedure TargetsClick(Sender: TObject);
    procedure GridSelect(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure ShowHelp(Row: Integer);
    function GetTargets: string;
    procedure SetTargets(const Value: string);
    function GetValue(const Name: string): string;
    procedure SetValue(const Name, Value: string);
    function GetSwitchCount: Integer;
    function GetSwitch(Index: Integer): TSwitchInfo;
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadSwitches(Source: TStrings);
    function Execute(const ModuleName: string; IsProject: Boolean = False): Boolean;
    property Targets: string read GetTargets write SetTargets;    // '' for this system, else 'windows,linux'...
    property Values[const Name: string]: string read GetValue write SetValue;   // '' for the default
    property SwitchCount: Integer read GetSwitchCount;
    property Switches[Index: Integer]: TSwitchInfo read GetSwitch;
  end;

implementation

const
  TargetNames: array[0..3] of string = ('windows', 'macos', 'macos-x64', 'linux');
  TargetCaptions: array[0..3] of string = ('Windows', 'macOS (Apple Silicon)', 'macOS (Intel)', 'Linux');

{ ---- the dialog ---- }

constructor TModuleOptionsDialog.Create(AOwner: TComponent);
var
  G, T: TGroupBox;
  B: TButton;
  I: Integer;
begin
  inherited CreateNew(AOwner);                  // no .dfm
  BorderStyle := bsSizeable;
  BorderIcons := [biSystemMenu];
  Position := poOwnerFormCenter;
  ClientWidth := 460;
  ClientHeight := 500;
  Constraints.MinWidth := 400;
  Constraints.MinHeight := 420;

  G := TGroupBox.Create(Self);
  G.Parent := Self;
  G.SetBounds(8, 8, ClientWidth - 16, 232);
  G.Anchors := [akLeft, akTop, akRight];
  G.Caption := ' Build for ';
  FThisSystem := TRadioButton.Create(Self);
  FThisSystem.Parent := G;
  FThisSystem.SetBounds(14, 24, 200, 20);
  FThisSystem.Caption := 'This system';
  FThisSystem.OnClick := TargetsClick;
  FOther := TRadioButton.Create(Self);
  FOther.Parent := G;
  FOther.SetBounds(14, 50, 200, 20);
  FOther.Caption := 'Other';
  FOther.OnClick := TargetsClick;
  T := TGroupBox.Create(Self);
  T.Parent := G;
  T.SetBounds(14, 78, G.Width - 28, 140);
  T.Anchors := [akLeft, akTop, akRight];
  T.Caption := ' Targets ';
  for I := 0 to High(FTargets) do
  begin
    FTargets[I] := TCheckBox.Create(Self);
    FTargets[I].Parent := T;
    FTargets[I].SetBounds(14, 22 + I * 28, 260, 20);
    FTargets[I].Caption := TargetCaptions[I];
  end;

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.SetBounds(8, 248, ClientWidth - 16, ClientHeight - 248 - 76);
  FGrid.Anchors := [akLeft, akTop, akRight, akBottom];
  FGrid.ColCount := 3;
  FGrid.RowCount := 2;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.Options := [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goColSizing, goEditing,
    goAlwaysShowEditor, goTabs];
  FGrid.DefaultRowHeight := 22;
  FGrid.ColWidths[0] := 120;
  FGrid.ColWidths[1] := 140;
  FGrid.ColWidths[2] := FGrid.ClientWidth - 120 - 140 - 4;
  FGrid.Cells[0, 0] := 'Switch';
  FGrid.Cells[1, 0] := 'Default';
  FGrid.Cells[2, 0] := 'Value';
  FGrid.OnSelectCell := GridSelect;

  FHelp := TLabel.Create(Self);
  FHelp.Parent := Self;
  FHelp.SetBounds(8, ClientHeight - 70, ClientWidth - 16, 30);
  FHelp.Anchors := [akLeft, akRight, akBottom];
  FHelp.AutoSize := False;
  FHelp.WordWrap := True;

  B := TButton.Create(Self);
  B.Parent := Self;
  B.SetBounds(ClientWidth - 196, ClientHeight - 34, 90, 26);
  B.Anchors := [akRight, akBottom];
  B.Caption := 'OK';
  B.Default := True;
  B.ModalResult := mrOk;
  B := TButton.Create(Self);
  B.Parent := Self;
  B.SetBounds(ClientWidth - 98, ClientHeight - 34, 90, 26);
  B.Anchors := [akRight, akBottom];
  B.Caption := 'Cancel';
  B.Cancel := True;
  B.ModalResult := mrCancel;

  FThisSystem.Checked := True;
  TargetsClick(nil);
end;

{ One row per switch: its name, its default, and the value to run with (empty: the default). }
procedure TModuleOptionsDialog.LoadSwitches(Source: TStrings);
var
  I: Integer;
begin
  FSwitches := ReadSwitches(Source);
  if Length(FSwitches) = 0 then
  begin
    FGrid.RowCount := 2;
    FGrid.Cells[0, 1] := '';
    FGrid.Cells[1, 1] := '';
    FGrid.Cells[2, 1] := '';
    FGrid.Enabled := False;
    FHelp.Caption := 'This program has no switches. Declare one with: switch Width = 640   // help';
    Exit;
  end;
  FGrid.RowCount := Length(FSwitches) + 1;
  for I := 0 to High(FSwitches) do
  begin
    FGrid.Cells[0, I + 1] := '--' + FSwitches[I].Name.ToLower;
    FGrid.Cells[1, I + 1] := FSwitches[I].Default;
    FGrid.Cells[2, I + 1] := '';
  end;
  FGrid.Col := 2;
  FGrid.Row := 1;
  ShowHelp(1);
end;

function TModuleOptionsDialog.Execute(const ModuleName: string; IsProject: Boolean): Boolean;
begin
  if IsProject then
    Caption := 'Project Options - ' + ModuleName
  else
    Caption := 'Module Options - ' + ModuleName;
  Result := ShowModal = mrOk;
end;

procedure TModuleOptionsDialog.TargetsClick(Sender: TObject);
var
  C: TCheckBox;
begin
  for C in FTargets do
    C.Enabled := FOther.Checked;
end;

{ Only the Value column can be edited. }
procedure TModuleOptionsDialog.GridSelect(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
begin
  CanSelect := ACol = 2;
  if CanSelect then ShowHelp(ARow);
end;

procedure TModuleOptionsDialog.ShowHelp(Row: Integer);
var
  S: TSwitchInfo;
  Text: string;
begin
  if (Row < 1) or (Row > Length(FSwitches)) then Exit;
  S := FSwitches[Row - 1];
  Text := S.Help;
  if S.Rule <> '' then
  begin
    if Text <> '' then Text := Text + '. ';
    Text := Text + 'Must satisfy: ' + S.Rule;
  end;
  if Text = '' then Text := 'Leave the value empty to use the default, ' + S.Default + '.';
  FHelp.Caption := '--' + S.Name.ToLower + ': ' + Text;
end;

function TModuleOptionsDialog.GetTargets: string;
var
  I: Integer;
begin
  Result := '';
  if FThisSystem.Checked then Exit;
  for I := 0 to High(FTargets) do
    if FTargets[I].Checked then
    begin
      if Result <> '' then Result := Result + ',';
      Result := Result + TargetNames[I];
    end;
end;

procedure TModuleOptionsDialog.SetTargets(const Value: string);
var
  I: Integer;
  Names: TArray<string>;
begin
  Names := Value.Split([',']);
  for I := 0 to High(FTargets) do
    FTargets[I].Checked := MatchText(TargetNames[I], Names);
  FOther.Checked := Value <> '';
  FThisSystem.Checked := Value = '';
  TargetsClick(nil);
end;

function TModuleOptionsDialog.GetValue(const Name: string): string;
var
  I: Integer;
begin
  for I := 0 to High(FSwitches) do
    if SameText(FSwitches[I].Name, Name) then
      Exit(FGrid.Cells[2, I + 1].Trim);
  Result := '';
end;

procedure TModuleOptionsDialog.SetValue(const Name, Value: string);
var
  I: Integer;
begin
  for I := 0 to High(FSwitches) do
    if SameText(FSwitches[I].Name, Name) then
      FGrid.Cells[2, I + 1] := Value;
end;

function TModuleOptionsDialog.GetSwitchCount: Integer;
begin
  Result := Length(FSwitches);
end;

function TModuleOptionsDialog.GetSwitch(Index: Integer): TSwitchInfo;
begin
  Result := FSwitches[Index];
end;

end.
