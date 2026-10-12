unit Hasten.FMX.Options;

{ Project Options, or Module Options for a single file: what to build for, and a value for each switch the
  program declares (read from its source, so the list is always the one it has now; empty means the
  default). The same dialog as Hasten for VCL, designed in Hasten.FMX.Options.fmx. }

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.StrUtils, System.Rtti, FMX.Types,
  FMX.Controls, FMX.Forms, FMX.Graphics, FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts, FMX.Grid,
  FMX.Grid.Style, FMX.ScrollBox, Hasten.Project, Hasten.FMX.Text;

type
  TOptionsForm = class(TForm)
    BuildGroup: TGroupBox;
    ThisSystemRadio: TRadioButton;
    OtherRadio: TRadioButton;
    TargetsGroup: TGroupBox;
    WindowsCheck: TCheckBox;
    MacCheck: TCheckBox;
    MacIntelCheck: TCheckBox;
    LinuxCheck: TCheckBox;
    Grid: TStringGrid;
    SwitchColumn: TStringColumn;
    DefaultColumn: TStringColumn;
    ValueColumn: TStringColumn;
    HelpLabel: TLabel;
    ButtonBar: TLayout;
    OKButton: TButton;
    CancelButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure BuildChange(Sender: TObject);
    procedure GridSelectCell(Sender: TObject; const ACol, ARow: Integer; var CanSelect: Boolean);
  private
    FSwitches: TArray<TSwitchInfo>;
    function Checks: TArray<TCheckBox>;
    procedure ShowHelp(Row: Integer);
    function GetTargets: string;
    procedure SetTargets(const Value: string);
    function GetValue(const Name: string): string;
    procedure SetValue(const Name, Value: string);
    function GetSwitchCount: Integer;
    function GetSwitch(Index: Integer): TSwitchInfo;
  public
    procedure LoadSwitches(Source: TStrings);
    function Execute(const Name: string; IsProject: Boolean): Boolean;
    property Targets: string read GetTargets write SetTargets;    // '' for this system, else windows,linux ...
    property Values[const Name: string]: string read GetValue write SetValue;   // '' for the default
    property SwitchCount: Integer read GetSwitchCount;
    property Switches[Index: Integer]: TSwitchInfo read GetSwitch;
  end;

implementation

{$R *.fmx}

const
  TargetNames: array[0..3] of string = ('windows', 'macos', 'macos-x64', 'linux');

function TOptionsForm.Checks: TArray<TCheckBox>;
begin
  Result := [WindowsCheck, MacCheck, MacIntelCheck, LinuxCheck];    // in the order of TargetNames
end;

procedure TOptionsForm.LoadSwitches(Source: TStrings);
var
  I: Integer;
begin
  FSwitches := ReadSwitches(Source);
  Grid.RowCount := Length(FSwitches);
  for I := 0 to High(FSwitches) do
  begin
    Grid.Cells[0, I] := '--' + FSwitches[I].Name.ToLower;
    Grid.Cells[1, I] := FSwitches[I].Default;
    Grid.Cells[2, I] := '';
  end;
  Grid.Enabled := Length(FSwitches) > 0;
  if Length(FSwitches) = 0 then
    HelpLabel.Text := 'This program has no switches. Declare one with: switch Width = 640   // help'
  else
    ShowHelp(0);
end;

function TOptionsForm.Execute(const Name: string; IsProject: Boolean): Boolean;
begin
  if IsProject then Caption := 'Project Options - ' + Name else Caption := 'Module Options - ' + Name;
  Result := ShowModal = mrOk;
end;

procedure TOptionsForm.FormCreate(Sender: TObject);
begin
  UseTextSizes(Self);
end;

procedure TOptionsForm.BuildChange(Sender: TObject);
begin
  TargetsGroup.Enabled := OtherRadio.IsChecked;
end;

procedure TOptionsForm.GridSelectCell(Sender: TObject; const ACol, ARow: Integer; var CanSelect: Boolean);
begin
  ShowHelp(ARow);
end;

procedure TOptionsForm.ShowHelp(Row: Integer);
var
  S: TSwitchInfo;
  Text: string;
begin
  if (Row < 0) or (Row > High(FSwitches)) then Exit;
  S := FSwitches[Row];
  Text := S.Help;
  if S.Rule <> '' then
  begin
    if Text <> '' then Text := Text + '. ';
    Text := Text + 'Must satisfy: ' + S.Rule;
  end;
  if Text = '' then Text := 'Leave the value empty to use the default, ' + S.Default + '.';
  HelpLabel.Text := '--' + S.Name.ToLower + ': ' + Text;
end;

function TOptionsForm.GetTargets: string;
var
  I: Integer;
  Boxes: TArray<TCheckBox>;
begin
  Result := '';
  if ThisSystemRadio.IsChecked then Exit;
  Boxes := Checks;
  for I := 0 to High(TargetNames) do
    if Boxes[I].IsChecked then
    begin
      if Result <> '' then Result := Result + ',';
      Result := Result + TargetNames[I];
    end;
end;

procedure TOptionsForm.SetTargets(const Value: string);
var
  I: Integer;
  Names: TArray<string>;
  Boxes: TArray<TCheckBox>;
begin
  Names := Value.Split([',']);
  Boxes := Checks;
  for I := 0 to High(TargetNames) do
    Boxes[I].IsChecked := MatchText(TargetNames[I], Names);
  OtherRadio.IsChecked := Value <> '';
  ThisSystemRadio.IsChecked := Value = '';
  BuildChange(nil);
end;

function TOptionsForm.GetValue(const Name: string): string;
var
  I: Integer;
begin
  for I := 0 to High(FSwitches) do
    if SameText(FSwitches[I].Name, Name) then
      Exit(Grid.Cells[2, I].Trim);
  Result := '';
end;

procedure TOptionsForm.SetValue(const Name, Value: string);
var
  I: Integer;
begin
  for I := 0 to High(FSwitches) do
    if SameText(FSwitches[I].Name, Name) then
      Grid.Cells[2, I] := Value;
end;

function TOptionsForm.GetSwitchCount: Integer;
begin
  Result := Length(FSwitches);
end;

function TOptionsForm.GetSwitch(Index: Integer): TSwitchInfo;
begin
  Result := FSwitches[Index];
end;

end.
