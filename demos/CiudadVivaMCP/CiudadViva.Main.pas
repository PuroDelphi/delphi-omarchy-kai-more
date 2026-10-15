unit CiudadViva.Main;

interface

uses System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.JSON, System.IOUtils, System.Math, System.Net.HttpClient,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Objects,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Layouts,
  MCPConnect.Transport.Indy, CiudadViva.Model;

type
  TMainForm = class(TForm)
  private
    FServer: TJRPCIndyServer;
    FPaint: TPaintBox;
    FTimer: TTimer;
    FBusy: Boolean;
    FPort: Integer;
    FBridge, FLastRequest, FReply: string;
    procedure PaintScene(Sender: TObject; Canvas: TCanvas);
    procedure Tick(Sender: TObject);
    procedure StormClick(Sender: TObject);
    procedure NormalClick(Sender: TObject);
    procedure DemoClick(Sender: TObject);
    procedure RulesClick(Sender: TObject);
    procedure CanClose(Sender: TObject; var CanClose: Boolean);
    procedure StartServer;
    function HTTP(const Body: string): string;
    procedure Demo;
    procedure PollBridge;
    function AddButton(ParentControl: TControl; const Text: string;
      X, Width: Single; Handler: TNotifyEvent): TButton;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var MainForm: TMainForm;

implementation

uses MCPConnect.JRPC.Server, MCPConnect.MCP.Server.Api,
  MCPConnect.Configuration.MCP;

const
  CBackground = $FF0B1220;
  CPanel = $FF142237;
  CMuted = $FF91A7C0;
  CWhite = $FFF0F6FF;
  CGreen = $FF44E0BA;
  CAmber = $FFFFCA6A;
  CRed = $FFFF718A;

constructor TMainForm.Create(AOwner: TComponent);
var Bar: TLayout;
begin
  inherited CreateNew(AOwner);
  Caption := 'Ciudad Viva | MCPConnect en accion';
  Width := 1260; Height := 880;
  Constraints.MinWidth := 1050; Constraints.MinHeight := 800;
  Fill.Kind := TBrushKind.Solid;
  Fill.Color := CBackground;
  OnCloseQuery := CanClose;
  City := TCityModel.Create;
  FReply := 'Consulta → decision → herramienta → validacion → cambio visible';
  FPaint := TPaintBox.Create(Self);
  FPaint.Parent := Self;
  FPaint.Align := TAlignLayout.Client;
  FPaint.OnPaint := PaintScene;
  Bar := TLayout.Create(Self);
  Bar.Parent := Self; Bar.Align := TAlignLayout.Bottom; Bar.Height := 62;
  AddButton(Bar, '1. Provocar tormenta', 24, 205, StormClick);
  AddButton(Bar, '2. Rescatar via MCP', 242, 220, DemoClick);
  AddButton(Bar, 'Ver reglas MCP', 475, 180, RulesClick);
  AddButton(Bar, 'Reiniciar', 668, 130, NormalClick);
  StartServer;
  FBridge := System.IOUtils.TPath.Combine(ExtractFilePath(ParamStr(0)), 'DemoBridge');
  TDirectory.CreateDirectory(FBridge);
  TFile.WriteAllText(System.IOUtils.TPath.Combine(FBridge, 'request.json'), '{"idle":true}', TEncoding.UTF8);
  TFile.WriteAllText(System.IOUtils.TPath.Combine(FBridge, 'response.json'), '{"idle":true}', TEncoding.UTF8);
  TFile.WriteAllText(System.IOUtils.TPath.Combine(FBridge, 'endpoint.json'),
    Format('{"url":"http://127.0.0.1:%d/mcp","simulation":true}', [FPort]), TEncoding.UTF8);
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 300; FTimer.OnTimer := Tick; FTimer.Enabled := True;
end;

destructor TMainForm.Destroy;
begin
  if Assigned(FTimer) then FTimer.Enabled := False;
  if Assigned(FServer) then FServer.Active := False;
  FreeAndNil(FServer);
  FreeAndNil(City);
  inherited;
end;

procedure TMainForm.CanClose(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := not FBusy;
  if FBusy then FReply := 'Espera a que termine la llamada MCP para cerrar.';
end;

function TMainForm.AddButton(ParentControl: TControl; const Text: string;
  X, Width: Single; Handler: TNotifyEvent): TButton;
begin
  Result := TButton.Create(Self); Result.Parent := ParentControl;
  Result.Position.X := X; Result.Position.Y := 8;
  Result.Width := Width; Result.Height := 42;
  Result.Text := Text; Result.OnClick := Handler;
end;

procedure TMainForm.StartServer;
var P: Integer; LastError: string;
begin
  FServer := TJRPCIndyServer.CreateMCPServer(nil);
  FServer.JRPCServer.Plugin.Configure<IMCPConfig>
    .Server.SetName('ciudad-viva').SetVersion('1.0.0').BackToMCP
    .Tools.RegisterClass(TCityTools).BackToMCP
    .Resources.RegisterClass(TCityResources).BackToMCP
    .Prompts.RegisterClass(TCityPrompts).BackToMCP.ApplyConfig;
  LastError := '';
  for P := 9091 to 9099 do begin
    FServer.Bindings.Clear;
    with FServer.Bindings.Add do begin IP := '127.0.0.1'; Port := P; end;
    FServer.DefaultPort := P;
    try
      FServer.Active := True;
      FPort := P;
      Exit;
    except on E: Exception do begin LastError := E.Message; FServer.Active := False; end; end;
  end;
  raise Exception.Create('No se pudo iniciar MCPConnect: ' + LastError);
end;

function TMainForm.HTTP(const Body: string): string;
var Client: THTTPClient; Stream: TStringStream; Response: IHTTPResponse;
begin
  Client := THTTPClient.Create;
  Stream := TStringStream.Create(Body, TEncoding.UTF8);
  try
    Client.ConnectionTimeout := 3000; Client.ResponseTimeout := 10000;
    Client.ContentType := 'application/json';
    Client.Accept := 'application/json';
    Response := Client.Post(Format('http://127.0.0.1:%d/mcp', [FPort]), Stream);
    Result := Response.ContentAsString(TEncoding.UTF8);
    if Response.StatusCode <> 200 then
      raise Exception.CreateFmt('HTTP %d: %s', [Response.StatusCode, Result]);
  finally Stream.Free; Client.Free; end;
end;

procedure TMainForm.NormalClick(Sender: TObject);
begin if not FBusy then begin City.Reset; FReply := 'Simulacion reiniciada. Puedes conectar un cliente MCP externo.'; end; end;
procedure TMainForm.StormClick(Sender: TObject);
begin if not FBusy then begin City.Scenario('storm'); FReply := 'Hay 75 MW disponibles para 105 MW de demanda. Protege el hospital.'; end; end;

procedure TMainForm.RulesClick(Sender: TObject);
begin
  if FBusy then Exit;
  FBusy := True;
  TThread.CreateAnonymousThread(procedure
    var Text: string;
    begin
      try Text := HTTP('{"jsonrpc":"2.0","id":1,"method":"resources/read","params":{"uri":"city://rules"}}');
      except on E: Exception do Text := E.Message; end;
      System.Classes.TThread.Queue(nil, TThreadProcedure(procedure begin FReply := Text; FBusy := False; end));
    end).Start;
end;

procedure TMainForm.DemoClick(Sender: TObject);
begin
  if FBusy then Exit;
  FBusy := True;
  FReply := 'Demo guiada: cliente HTTP real → MCPConnect → reglas del negocio. No usa un LLM.';
  TThread.CreateAnonymousThread(procedure begin Demo; end).Start;
end;

procedure TMainForm.Demo;
var Text: string; Value: TJSONValue; Before, After: TCitySnapshot;
  procedure Call(const Body: string);
  var V: TJSONValue;
  begin
    Text := HTTP(Body); V := TJSONObject.ParseJSONValue(Text);
    try
      if (V = nil) or (V.FindValue('error') <> nil) or
        V.GetValue<Boolean>('result.isError', False) then
        raise Exception.Create('La llamada MCP fallo: ' + Text);
    finally V.Free; end;
  end;
begin
  try
    Call('{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"ciudad-viva-demo","version":"1.0"}}}');
    Call('{"jsonrpc":"2.0","id":2,"method":"tools/list"}');
    Call('{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"city_scenario","arguments":{"scenario":"storm"}}}');
    Call('{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"city_status","arguments":{}}}');
    Before := City.Snapshot;
    // Deliberately invalid: demonstrate that Delphi rejects unsafe AI requests.
    Text := HTTP('{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"city_apply_plan","arguments":{"hospital_mw":0,"homes_mw":45,"industry_mw":25}}}');
    Value := TJSONObject.ParseJSONValue(Text);
    try
      if (Value = nil) or ((Value.FindValue('error') = nil) and
        not Value.GetValue<Boolean>('result.isError', False)) then
        raise Exception.Create('El plan invalido no produjo el error MCP esperado.');
    finally Value.Free; end;
    After := City.Snapshot;
    if (Before.Hospital <> After.Hospital) or (Before.Homes <> After.Homes) or
      (Before.Industry <> After.Industry) then raise Exception.Create('Fallo de atomicidad.');
    Call('{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"city_apply_plan","arguments":{"hospital_mw":30,"homes_mw":30,"industry_mw":15}}}');
    Call('{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"city_status","arguments":{}}}');
    Text := 'MCP verificado: herramientas descubiertas; plan peligroso rechazado sin cambios; ' +
      'plan seguro aplicado: hospital 30, hogares 30, industria 15 MW. ' +
      'Se evita la sobrecarga con 30 MW de demanda no atendida. Demo guiada sin IA; un agente externo puede usar las mismas herramientas.';
    TFile.WriteAllText(System.IOUtils.TPath.Combine(FBridge, 'selftest.json'), '{"passed":true,"invalid_plan_rejected":true,"allocation_unchanged_on_error":true,"safe_plan_applied":true}', TEncoding.UTF8);
  except on E: Exception do begin
    Text := 'Error en la prueba MCP: ' + E.Message;
    TFile.WriteAllText(System.IOUtils.TPath.Combine(FBridge, 'selftest.json'), '{"passed":false}', TEncoding.UTF8);
  end; end;
  System.Classes.TThread.Queue(nil, TThreadProcedure(procedure begin FReply := Text; FBusy := False; end));
end;

procedure TMainForm.PollBridge;
var Value: TJSONValue; ID, Body: string;
begin
  if FBusy then Exit;
  Value := nil;
  try
   try
    Value := TJSONObject.ParseJSONValue(TFile.ReadAllText(System.IOUtils.TPath.Combine(FBridge, 'request.json'), TEncoding.UTF8));
    if Value = nil then Exit;
    ID := Value.GetValue<string>('id', '');
    if (ID = '') or (ID = FLastRequest) then Exit;
    Body := Value.GetValue<TJSONValue>('rpc').ToJSON;
    FLastRequest := ID;
    FBusy := True;
    TThread.CreateAnonymousThread(procedure
      var Reply: string; J: TJSONObject; V: TJSONValue;
      begin
        J := TJSONObject.Create;
        try
          J.AddPair('id', ID);
          try
            Reply := HTTP(Body); V := TJSONObject.ParseJSONValue(Reply);
            if V = nil then raise Exception.Create('Respuesta JSON invalida');
            J.AddPair('result', V);
          except on E: Exception do J.AddPair('error', E.Message); end;
          TFile.WriteAllText(System.IOUtils.TPath.Combine(FBridge, 'response.json'), J.ToJSON, TEncoding.UTF8);
        finally J.Free; end;
        System.Classes.TThread.Queue(nil, TThreadProcedure(procedure begin FBusy := False; FReply := 'Cliente externo: solicitud MCP procesada. Consulta el registro de operaciones.'; end));
      end).Start;
  except
    // A writer can be updating the mailbox; retry on the next timer tick.
  end;
   finally Value.Free; end;
end;

procedure TMainForm.Tick(Sender: TObject);
begin PollBridge; FPaint.Repaint; end;

procedure TMainForm.PaintScene(Sender: TObject; Canvas: TCanvas);
var S: TCitySnapshot; W, H, CardW, Y, X, BH: Single; I, J, Total, Available: Integer;
  Good: Boolean; Accent: TAlphaColor; Lines: TStringList;
  procedure Box(L, T, R, B: Single; Color: TAlphaColor; Radius: Single = 16);
  begin Canvas.Fill.Kind := TBrushKind.Solid; Canvas.Fill.Color := Color;
    Canvas.FillRect(RectF(L,T,R,B), Radius,Radius,AllCorners,1); end;
  procedure Text(const Value: string; L,T,R,B,Size: Single; Color: TAlphaColor; Bold: Boolean = False);
  begin
    Canvas.Fill.Color := Color; Canvas.Font.Family := 'Segoe UI'; Canvas.Font.Size := Size;
    if Bold then Canvas.Font.Style := [TFontStyle.fsBold] else Canvas.Font.Style := [];
    Canvas.FillText(RectF(L,T,R,B),Value,False,1,[],TTextAlign.Leading,TTextAlign.Center);
  end;
  procedure Metric(Index: Integer; const Caption, Value, Detail: string; Color: TAlphaColor);
  var L: Single;
  begin
    L := 24 + Index * (CardW+12);
    Box(L,105,L+CardW,210,CPanel);
    Text(Caption,L+18,112,L+CardW-12,140,12,CMuted);
    Text(Value,L+18,140,L+CardW-12,180,30,Color,True);
    Text(Detail,L+18,180,L+CardW-12,203,11,CMuted);
  end;
begin
  // Paint the background explicitly: FMX styles can override the form fill.
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := CBackground;
  Canvas.FillRect(RectF(0, 0, FPaint.Width, FPaint.Height), 0, 0, [], 1);
  S := City.Snapshot; W := FPaint.Width; H := FPaint.Height;
  Total := S.Hospital + S.Homes + S.Industry; Available := S.Generation + S.Battery;
  Good := Total <= Available;
  if Good then Accent := CGreen else Accent := CRed;
  Text('CIUDAD VIVA',24,16,W-250,55,32,CWhite,True);
  Text('Delphi + FireMonkey + MCPConnect  |  Una app que un asistente puede operar',26,58,W-30,84,14,CMuted);
  Box(W-235,22,W-24,58,CPanel,12);
  Text('SIMULACION / ' + UpperCase(S.Scenario),W-220,25,W-30,55,12,CAmber,True);
  CardW := (W-84)/4;
  Metric(0,'POTENCIA DISPONIBLE',IntToStr(Available)+' MW',Format('Generacion %d + bateria %d',[S.Generation,S.Battery]),CGreen);
  Metric(1,'POTENCIA ASIGNADA',IntToStr(Total)+' MW','La suma debe caber en el presupuesto',Accent);
  Metric(2,'DEMANDA NO ATENDIDA',IntToStr(Max(0,S.Demand-Total))+' MW','Recortes visibles, sin promesas magicas',CAmber);
  Metric(3,'REGLAS DEL NEGOCIO',IntToStr(S.Rejected)+' bloqueos','El hospital nunca baja de 30 MW',CGreen);
  Box(24,226,W*0.62,492,CPanel);
  Text('RED ELECTRICA / DATOS SIMULADOS',42,236,W*0.62-12,264,12,CMuted,True);
  for I := 0 to 2 do begin
    X := 52+I*(W*0.62-80)/3;
    case I of
      0: begin BH:=110; Accent:=CGreen; end;
      1: begin BH:=85; Accent:=$FF65AEFF; end;
      else begin BH:=130; Accent:=CAmber; end;
    end;
    Box(X,410-BH,X+85,410,$FF243B55,4);
    for J := 0 to 8 do Box(X+12+(J mod 3)*23,420-BH+(J div 3)*23,X+23+(J mod 3)*23,432-BH+(J div 3)*23,Accent,2);
    if I=0 then begin
      Box(X+34,296,X+49,333,CGreen,2); Box(X+23,307,X+60,322,CGreen,2);
      Text('HOSPITAL',X-4,420,X+130,441,12,CWhite,True);
      Text(IntToStr(S.Hospital)+' MW / protegido',X-4,442,X+155,468,12,CGreen);
    end else if I=1 then begin
      Text('HOGARES',X-4,420,X+130,441,12,CWhite,True);
      Text(IntToStr(S.Homes)+' MW',X-4,442,X+130,468,12,$FF65AEFF);
    end else begin
      Text('INDUSTRIA',X-4,420,X+130,441,12,CWhite,True);
      Text(IntToStr(S.Industry)+' MW',X-4,442,X+130,468,12,CAmber);
    end;
  end;
  if Good then Accent:=CGreen else Accent:=CRed;
  Box(W*0.62+14,226,W-24,492,CPanel);
  if Good then Text('RED ESTABLE',W*0.62+34,246,W-35,280,25,Accent,True)
  else Text('RIESGO DE APAGON',W*0.62+34,246,W-35,280,23,Accent,True);
  Text('1  Consultar estado y reglas',W*0.62+34,293,W-35,325,14,CWhite);
  Text('2  Proponer una distribucion',W*0.62+34,326,W-35,358,14,CWhite);
  Text('3  Validar y aplicar con Delphi',W*0.62+34,359,W-35,391,14,CWhite);
  Text('4  Verificar el resultado',W*0.62+34,392,W-35,424,14,CWhite);
  Text('MCP no es el modelo de IA: es su conexion a tu app.',W*0.62+34,438,W-36,481,12,CMuted);
  Box(24,508,W-24,594,$FF18354A);
  Text('LO QUE ACABA DE PASAR',40,514,W-40,539,11,CGreen,True);
  Canvas.Font.Size:=13;Canvas.Fill.Color:=CWhite;Canvas.Font.Style:=[];
  Canvas.FillText(RectF(40,541,W-40,585),FReply,True,1,[],TTextAlign.Leading,TTextAlign.Center);
  Y := 610;
  Text('OPERACIONES / VALIDACION EN EL SERVIDOR',26,Y,W-30,Y+25,11,CMuted,True);
  Lines := TStringList.Create;
  try
    Lines.Text := City.Logs;
    for I:=0 to Min(3,Lines.Count-1) do Text(Lines[I],28,Y+28+I*22,W-35,Y+50+I*22,12,CWhite);
  finally Lines.Free; end;
  Text(Format('MCP listo: http://127.0.0.1:%d/mcp  |  4 tools + 1 resource + 1 prompt  |  Demo local sin API key',[FPort]),26,H-27,W-25,H-3,11,CMuted);
end;

end.
