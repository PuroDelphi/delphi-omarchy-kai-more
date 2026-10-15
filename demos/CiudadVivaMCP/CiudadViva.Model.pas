unit CiudadViva.Model;

interface

uses System.SysUtils, System.JSON, System.SyncObjs, System.Classes,
  MCPConnect.MCP.Attributes;

type
  TCitySnapshot = record
    Scenario, LastAction: string;
    Generation, Demand, Battery, Hospital, Homes, Industry: Integer;
    Revision, Calls, Rejected: Integer;
  end;

  TCityModel = class
  private
    FLock: TCriticalSection;
    FState: TCitySnapshot;
    FLog: TStringList;
    procedure AddLog(const Text: string);
  public
    constructor Create;
    destructor Destroy; override;
    function Snapshot: TCitySnapshot;
    function Status: string;
    function Logs: string;
    function Scenario(const Name: string): string;
    function Plan(Hospital, Homes, Industry: Integer): string;
    function Reset: string;
  end;

  // Only these public business operations are exposed to MCP clients.
  TCityTools = class
  public
    [McpTool('city_status', 'Read simulated generation, demand, battery and allocation. Always consult before planning.')]
    function Status: string;
    [McpTool('city_scenario', 'Change the SIMULATION scenario: normal, storm or festival. Not a real electrical system.')]
    function Scenario([McpParam('scenario', 'normal, storm or festival')] const Name: string): string;
    [McpTool('city_apply_plan', 'Apply an energy allocation in MW. Hospital must receive at least 30, homes at least 20, industry at least 10. Total must not exceed generation plus battery. Invalid plans leave all allocations unchanged.')]
    function ApplyPlan(
      [McpParam('hospital_mw', 'Hospital allocation, integer MW, minimum 30')] Hospital: Integer;
      [McpParam('homes_mw', 'Homes allocation, integer MW, minimum 20')] Homes: Integer;
      [McpParam('industry_mw', 'Industry allocation, integer MW, minimum 10')] Industry: Integer): string;
    [McpTool('city_reset', 'Reset the local simulation to its initial state.')]
    function Reset: string;
  end;

  TCityResources = class
  public
    [McpResource('city-rules', 'city://rules', 'text/plain', 'Business rules and units of this simulation')]
    function Rules: string;
  end;

  TCityPrompts = class
  public
    [MCPPrompt('save-the-city', 'Evitar un apagon', 'Plan energy allocation while protecting the hospital')]
    function SaveCity: string;
  end;

var City: TCityModel;

implementation

constructor TCityModel.Create;
begin
  inherited;
  FLock := TCriticalSection.Create;
  FLog := TStringList.Create;
  Reset;
end;

destructor TCityModel.Destroy;
begin
  FLog.Free;
  FLock.Free;
  inherited;
end;

procedure TCityModel.AddLog(const Text: string);
begin
  FState.LastAction := Text;
  Inc(FState.Revision);
  FLog.Insert(0, FormatDateTime('hh:nn:ss', Now) + '  ' + Text);
  while FLog.Count > 10 do FLog.Delete(FLog.Count - 1);
end;

function TCityModel.Snapshot: TCitySnapshot;
begin
  FLock.Enter;
  try Result := FState; finally FLock.Leave; end;
end;

function TCityModel.Logs: string;
begin
  FLock.Enter;
  try Result := FLog.Text; finally FLock.Leave; end;
end;

function TCityModel.Status: string;
var S: TCitySnapshot; J, Allocation: TJSONObject;
begin
  S := Snapshot;
  J := TJSONObject.Create;
  try
    J.AddPair('simulation', TJSONBool.Create(True));
    J.AddPair('scenario', S.Scenario);
    J.AddPair('unit', 'MW');
    J.AddPair('generation_mw', TJSONNumber.Create(S.Generation));
    J.AddPair('battery_available_mw', TJSONNumber.Create(S.Battery));
    J.AddPair('demand_mw', TJSONNumber.Create(S.Demand));
    J.AddPair('available_mw', TJSONNumber.Create(S.Generation + S.Battery));
    Allocation := TJSONObject.Create;
    Allocation.AddPair('hospital', TJSONNumber.Create(S.Hospital));
    Allocation.AddPair('homes', TJSONNumber.Create(S.Homes));
    Allocation.AddPair('industry', TJSONNumber.Create(S.Industry));
    J.AddPair('allocation_mw', Allocation);
    J.AddPair('overload', TJSONBool.Create(S.Hospital + S.Homes + S.Industry > S.Generation + S.Battery));
    J.AddPair('rules', 'hospital >= 30; homes >= 20; industry >= 10; sum <= available_mw; integers only');
    Result := J.ToJSON;
  finally J.Free; end;
end;

function TCityModel.Reset: string;
begin
  FLock.Enter;
  try
    FState.Scenario := 'normal';
    FState.Generation := 120;
    FState.Battery := 15;
    FState.Demand := 105;
    FState.Hospital := 35;
    FState.Homes := 45;
    FState.Industry := 25;
    FState.Calls := 0;
    FState.Rejected := 0;
    FLog.Clear;
    AddLog('Simulacion reiniciada. Hospital protegido.');
  finally FLock.Leave; end;
  Result := Status;
end;

function TCityModel.Scenario(const Name: string): string;
begin
  if not (SameText(Name, 'normal') or SameText(Name, 'storm') or SameText(Name, 'festival')) then
    raise EArgumentException.Create('Escenario desconocido: usa normal, storm o festival.');
  FLock.Enter;
  try
    FState.Scenario := LowerCase(Name);
    if SameText(Name, 'storm') then begin
      FState.Generation := 55; FState.Battery := 20; FState.Demand := 105;
    end else if SameText(Name, 'festival') then begin
      FState.Generation := 100; FState.Battery := 15; FState.Demand := 145;
      FState.Hospital := 35; FState.Homes := 70; FState.Industry := 40;
    end else begin
      FState.Generation := 120; FState.Battery := 15; FState.Demand := 105;
    end;
    Inc(FState.Calls);
    AddLog('Escenario: ' + FState.Scenario + '. Consulta el estado antes de actuar.');
  finally FLock.Leave; end;
  Result := Status;
end;

function TCityModel.Plan(Hospital, Homes, Industry: Integer): string;
var Error: string; Total: Int64;
begin
  FLock.Enter;
  try
    Inc(FState.Calls);
    Total := Int64(Hospital) + Homes + Industry;
    Error := '';
    if Hospital < 30 then Error := 'El hospital requiere al menos 30 MW.'
    else if Homes < 20 then Error := 'Los hogares requieren al menos 20 MW.'
    else if Industry < 10 then Error := 'La industria requiere al menos 10 MW.'
    else if Total > FState.Generation + FState.Battery then
      Error := Format('Plan de %d MW: solo hay %d MW disponibles.', [Total, FState.Generation + FState.Battery]);
    if Error <> '' then begin
      Inc(FState.Rejected);
      AddLog('RECHAZADO: ' + Error);
      raise EArgumentException.Create(Error + ' No se modifico ninguna asignacion.');
    end;
    FState.Hospital := Hospital;
    FState.Homes := Homes;
    FState.Industry := Industry;
    AddLog(Format('MCP: plan aplicado %d / %d / %d MW. Hospital protegido.', [Hospital, Homes, Industry]));
  finally FLock.Leave; end;
  Result := Status;
end;

function TCityTools.Status: string;
begin Result := City.Status; end;
function TCityTools.Scenario(const Name: string): string;
begin Result := City.Scenario(Name); end;
function TCityTools.ApplyPlan(Hospital, Homes, Industry: Integer): string;
begin Result := City.Plan(Hospital, Homes, Industry); end;
function TCityTools.Reset: string;
begin Result := City.Reset; end;
function TCityResources.Rules: string;
begin
  Result := 'Ciudad Viva is a local SIMULATION. MW means power, not stored energy. ' +
    'The battery value is available discharge power; time and state of charge are outside this simplified model. ' +
    'Hospital >=30 MW; homes >=20 MW; industry >=10 MW. Sum <= generation + battery. ' +
    'All changes are validated atomically by the Delphi business layer. Invalid plans leave allocation unchanged. ' +
    'Unserved demand = max(0, demand - allocated power). Prioritize essential services; explain any curtailment.';
end;
function TCityPrompts.SaveCity: string;
begin
  Result := 'Ayudame a evitar un apagon en Ciudad Viva. Lee city://rules y consulta city_status. ' +
    'Propone una asignacion que conserve el hospital y los servicios minimos sin exceder la potencia disponible. ' +
    'Explica los recortes y pide confirmacion antes de aplicar city_apply_plan. Verifica el resultado con city_status.';
end;

end.
