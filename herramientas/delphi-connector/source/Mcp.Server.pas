unit Mcp.Server;

interface

uses
   System.SysUtils, System.Classes, System.JSON, System.Generics.Collections, IdCustomHTTPServer, IdHTTPServer,
   IdContext, IdSocketHandle, Mcp.Types, Mcp.ToolRegistry, Mcp.VclBridge;

type
   TMcpServer = class;
   TMcpListResourcesHandler = function: TJSONArray of object;
   TMcpReadResourceHandler = function(const Uri: string): TJSONObject of object;
   TMcpListPromptsHandler = function: TJSONArray of object;
   TMcpGetPromptHandler = function(const PromptName: string): TJSONObject of object;

   TMcpServerEvents = class
   private
      FServer: TMcpServer;
   public
      constructor Create(AServer: TMcpServer);
      procedure CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
         AResponseInfo: TIdHTTPResponseInfo);
   end;

   TMcpServer = class(TComponent)
   private
      FHttpServer: TIdHTTPServer;
      FEvents: TMcpServerEvents;
      FRegistry: TMcpToolRegistry;
      FVclBridge: TMcpVclBridge;
      FPort: integer;
      FActivePort: integer;
      FBindHost: string;
      FServerName: string;
      FServerVersion: string;
      FAllowInIdeProcess: boolean;
      FOnListResources: TMcpListResourcesHandler;
      FOnReadResource: TMcpReadResourceHandler;
      FOnListPrompts: TMcpListPromptsHandler;
      FOnGetPrompt: TMcpGetPromptHandler;
      FResourceOwnerId: string;
      FPromptOwnerId: string;
      FStartedAt: TDateTime;
      FLastRequestAt: TDateTime;
      FRequestCount: Int64;
      FGetCount: Int64;
      FPostCount: Int64;
      FOptionsCount: Int64;
      FBytesRead: Int64;
      FBytesWritten: Int64;
      FCountStatusRequests: boolean;
      FRequireAuthorization: boolean;
      FAccessToken: string;
      FAccessTokenFile: string;
      function GetActive: boolean;
      function GetUrl: string;
      function GetAccessTokenFile: string;
      procedure TrackRequest(const Method: string; BytesRead: Int64);
      procedure SetUtf8Response(AResponseInfo: TIdHTTPResponseInfo; const Text: string;
         const ContentType: string = 'application/json'; CountTraffic: boolean = true);
      procedure EnsureAccessToken;
      procedure WriteAccessTokenFile;
      procedure DeleteAccessTokenFile;
      function IsAuthorizedRequest(ARequestInfo: TIdHTTPRequestInfo): boolean;
      procedure SetUnauthorizedResponse(AResponseInfo: TIdHTTPResponseInfo);
      procedure PublishDiscovery(Active: boolean);
      function BuildDiscoveryJson: TJSONArray;
      function BuildCapabilitiesJson: TJSONObject;
      function BuildServerDiscoverJson: TJSONObject;
      function BuildStatusJson: string;
      function BuildOverviewHtml: string;
      function HandleRequest(const RequestText, ProtocolVersion, HeaderMethod,
         HeaderName: string): string;
      function ExecuteTool(const ToolName: string; Args: TJSONObject): TJSONValue;
   public
      constructor Create(AOwner: TComponent); override;
      destructor Destroy; override;
      procedure Start;
      procedure Stop;
      procedure RegisterTool(const Name, Description: string; const Required, Properties: array of string;
         Handler: TMcpToolHandler; RunInMainThread: boolean = false; const OwnerId: string = ''); overload;
      procedure RegisterTool(const Name, Description: string; Schema: TJSONObject;
         Handler: TMcpToolHandler; RunInMainThread: boolean = false; const OwnerId: string = ''); overload;
      procedure RegisterResourceHandlers(ListHandler: TMcpListResourcesHandler; ReadHandler: TMcpReadResourceHandler;
         const OwnerId: string = '');
      procedure RegisterPromptHandlers(ListHandler: TMcpListPromptsHandler; GetHandler: TMcpGetPromptHandler;
         const OwnerId: string = '');
      procedure UnregisterOwner(const OwnerId: string);
      property Registry: TMcpToolRegistry read FRegistry;
      property Url: string read GetUrl;
      property Active: boolean read GetActive;
      property ActivePort: integer read FActivePort;
      property AccessToken: string read FAccessToken write FAccessToken;
      property AccessTokenFile: string read GetAccessTokenFile;
   published
      property Port: integer read FPort write FPort default 8765;
      property BindHost: string read FBindHost write FBindHost;
      property ServerName: string read FServerName write FServerName;
      property ServerVersion: string read FServerVersion write FServerVersion;
      property AllowInIdeProcess: boolean read FAllowInIdeProcess write FAllowInIdeProcess default false;
      property CountStatusRequests: boolean read FCountStatusRequests write FCountStatusRequests default false;
      property RequireAuthorization: boolean read FRequireAuthorization write FRequireAuthorization default true;
   end;

function GlobalMcpServer: TMcpServer;
procedure FreeGlobalMcpServer;
function McpRunningInIdeProcess: boolean;

implementation

uses
   System.IOUtils, System.NetEncoding, System.Win.Registry, Winapi.Windows, Mcp.JsonRpc;

var
   FGlobalMcpServer: TMcpServer = nil;

const
   BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;
   CMcpLegacyProtocolVersion = '2024-11-05';
   CMcpNextProtocolVersion = '2026-07-28';

function BCryptGenRandom(hAlgorithm: THandle; pbBuffer: PByte; cbBuffer: Cardinal; dwFlags: Cardinal): LongInt; stdcall;
   external 'bcrypt.dll';

function GlobalMcpServer: TMcpServer;
begin
   if FGlobalMcpServer = nil then begin
      FGlobalMcpServer := TMcpServer.Create(nil);
   end;
   result := FGlobalMcpServer;
end;

function McpRunningInIdeProcess: boolean;
var
   ExeName: string;
begin
   ExeName := LowerCase(ExtractFileName(ParamStr(0)));
   result := (ExeName = 'bds.exe') or (ExeName = 'bds32.exe');
end;

procedure FreeGlobalMcpServer;
begin
   FreeAndNil(FGlobalMcpServer);
end;

constructor TMcpServerEvents.Create(AServer: TMcpServer);
begin
   inherited Create;
   FServer := AServer;
end;

procedure TMcpServerEvents.CommandGet(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
   AResponseInfo: TIdHTTPResponseInfo);
var
   Body, HeaderMethod, HeaderName, ProtocolVersion, ResponseText: string;
   TextStream: TStringStream;
   BytesRead: Int64;
   IsStatusRequest: boolean;
begin
   try
      BytesRead := 0;
      if ARequestInfo.PostStream <> nil then begin
         BytesRead := ARequestInfo.PostStream.Size;
      end;
      IsStatusRequest := SameText(ARequestInfo.Command, 'GET') and SameText(ARequestInfo.Document, '/status.json');
      if (not IsStatusRequest) or FServer.FCountStatusRequests then begin
         FServer.TrackRequest(ARequestInfo.Command, BytesRead);
      end;

      AResponseInfo.CustomHeaders.Values['Access-Control-Allow-Origin'] := '*';
      AResponseInfo.CustomHeaders.Values['Access-Control-Allow-Methods'] := 'GET, POST, OPTIONS';
      AResponseInfo.CustomHeaders.Values['Access-Control-Allow-Headers'] :=
         'content-type, x-mcp2delphi-token, mcp-protocol-version, mcp-method, mcp-name';

      if SameText(ARequestInfo.Command, 'OPTIONS') then begin
         AResponseInfo.ResponseNo := 204;
         exit;
      end;

      if SameText(ARequestInfo.Command, 'GET') then begin
         if IsStatusRequest then begin
            FServer.SetUtf8Response(AResponseInfo, FServer.BuildStatusJson, 'application/json',
               FServer.FCountStatusRequests);
         end
         else begin
            FServer.SetUtf8Response(AResponseInfo, FServer.BuildOverviewHtml, 'text/html');
         end;
         exit;
      end;

      if not SameText(ARequestInfo.Document, '/mcp') then begin
         AResponseInfo.ResponseNo := 404;
         AResponseInfo.ContentText := 'Not found';
         exit;
      end;

      if not FServer.IsAuthorizedRequest(ARequestInfo) then begin
         FServer.SetUnauthorizedResponse(AResponseInfo);
         exit;
      end;

      Body := '';
      if ARequestInfo.PostStream <> nil then begin
         ARequestInfo.PostStream.Position := 0;
         TextStream := TStringStream.Create('', TEncoding.UTF8);
         try
            TextStream.CopyFrom(ARequestInfo.PostStream, 0);
            Body := TextStream.DataString;
         finally
            TextStream.Free;
         end;
      end;

      ProtocolVersion := Trim(ARequestInfo.RawHeaders.Values['MCP-Protocol-Version']);
      if ProtocolVersion = '' then begin
         ProtocolVersion := Trim(ARequestInfo.RawHeaders.Values['Mcp-Protocol-Version']);
      end;

      HeaderMethod := Trim(ARequestInfo.RawHeaders.Values['Mcp-Method']);
      HeaderName := Trim(ARequestInfo.RawHeaders.Values['Mcp-Name']);

      ResponseText := FServer.HandleRequest(Body, ProtocolVersion, HeaderMethod,
         HeaderName);
      if ResponseText = '' then begin
         AResponseInfo.ResponseNo := 202;
         exit;
      end;
      FServer.SetUtf8Response(AResponseInfo, ResponseText);
   except
      on E: Exception do begin
         AResponseInfo.ResponseNo := 500;
         FServer.SetUtf8Response(AResponseInfo, McpJsonRpcError(nil, E.Message).ToJSON);
      end;
   end;
end;

constructor TMcpServer.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FPort := 8765;
   FActivePort := 0;
   FBindHost := '127.0.0.1';
   FServerName := 'delphi-mcp';
   FServerVersion := '0.1.0';
   FRequireAuthorization := true;
   FStartedAt := Now;
   FRegistry := TMcpToolRegistry.Create;
   FVclBridge := TMcpVclBridge.Create(Self);
end;

destructor TMcpServer.Destroy;
begin
   Stop;
   FVclBridge.Free;
   FRegistry.Free;
   inherited Destroy;
end;

function TMcpServer.GetActive: boolean;
begin
   result := (FHttpServer <> nil) and FHttpServer.Active;
end;

function TMcpServer.GetUrl: string;
begin
   if FActivePort > 0 then begin
      result := Format('http://%s:%d/mcp', [FBindHost, FActivePort]);
   end
   else begin
      result := Format('http://%s:%d/mcp', [FBindHost, FPort]);
   end;
end;

function TMcpServer.GetAccessTokenFile: string;
begin
   result := FAccessTokenFile;
end;

procedure TMcpServer.TrackRequest(const Method: string; BytesRead: Int64);
begin
   Inc(FRequestCount);
   FLastRequestAt := Now;
   if BytesRead > 0 then begin
      Inc(FBytesRead, BytesRead);
   end;

   if SameText(Method, 'GET') then begin
      Inc(FGetCount);
   end
   else if SameText(Method, 'POST') then begin
      Inc(FPostCount);
   end
   else if SameText(Method, 'OPTIONS') then begin
      Inc(FOptionsCount);
   end;
end;

procedure TMcpServer.SetUtf8Response(AResponseInfo: TIdHTTPResponseInfo; const Text: string;
   const ContentType: string = 'application/json'; CountTraffic: boolean = true);
var
   Stream: TStringStream;
begin
   Stream := TStringStream.Create(Text, TEncoding.UTF8);
   if CountTraffic then begin
      Inc(FBytesWritten, Stream.Size);
   end;
   AResponseInfo.ContentType := ContentType;
   AResponseInfo.CharSet := 'utf-8';
   AResponseInfo.ContentStream := Stream;
   AResponseInfo.FreeContentStream := true;
end;

function DiscoveryKeyName(ProcessId: Cardinal; Port: integer): string; forward;

function GenerateBearerToken: string;
var
   Bytes: TBytes;
   Status: LongInt;
begin
   SetLength(Bytes, 32);
   Status := BCryptGenRandom(0, @Bytes[0], Length(Bytes), BCRYPT_USE_SYSTEM_PREFERRED_RNG);
   if Status <> 0 then begin
      raise Exception.CreateFmt('MCP-Zugriffstoken konnte nicht erzeugt werden. BCryptGenRandom Status: %d', [Status]);
   end;

   result := TNetEncoding.Base64.EncodeBytesToString(Bytes);
   result := StringReplace(result, '+', '-', [rfReplaceAll]);
   result := StringReplace(result, '/', '_', [rfReplaceAll]);
   result := StringReplace(result, '=', '', [rfReplaceAll]);
end;

function TokenBaseDirectory: string;
begin
   result := GetEnvironmentVariable('LOCALAPPDATA');
   if result = '' then begin
      result := GetEnvironmentVariable('TEMP');
   end;
   if result = '' then begin
      result := TPath.GetTempPath;
   end;
   result := TPath.Combine(TPath.Combine(result, 'MCP2Delphi'), 'Servers');
end;

procedure TMcpServer.EnsureAccessToken;
begin
   if not FRequireAuthorization then begin
      exit;
   end;
   if FAccessToken = '' then begin
      FAccessToken := GenerateBearerToken;
   end;
end;

procedure TMcpServer.WriteAccessTokenFile;
var
   Root: TJSONObject;
   DirectoryName: string;
begin
   if not FRequireAuthorization then begin
      FAccessTokenFile := '';
      exit;
   end;

   EnsureAccessToken;
   DirectoryName := TokenBaseDirectory;
   ForceDirectories(DirectoryName);
   FAccessTokenFile := TPath.Combine(DirectoryName,
      DiscoveryKeyName(GetCurrentProcessId, FActivePort) + '.token.json');

   Root := TJSONObject.Create;
   try
      Root.AddPair('serverName', FServerName);
      Root.AddPair('url', Url);
      Root.AddPair('tokenHeader', 'X-MCP2Delphi-Token: ' + FAccessToken);
      Root.AddPair('token', FAccessToken);
      Root.AddPair('processId', TJSONNumber.Create(GetCurrentProcessId));
      Root.AddPair('activePort', TJSONNumber.Create(FActivePort));
      Root.AddPair('createdAt', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
      TFile.WriteAllText(FAccessTokenFile, Root.ToJSON, TEncoding.UTF8);
   finally
      Root.Free;
   end;
end;

procedure TMcpServer.DeleteAccessTokenFile;
begin
   if FAccessTokenFile = '' then begin
      exit;
   end;
   try
      if TFile.Exists(FAccessTokenFile) then begin
         TFile.Delete(FAccessTokenFile);
      end;
   except
      { Token cleanup must not block server shutdown. }
   end;
   FAccessTokenFile := '';
end;

function TMcpServer.IsAuthorizedRequest(ARequestInfo: TIdHTTPRequestInfo): boolean;
const
   BearerPrefix = 'Bearer ';
var
   Header, TokenHeader: string;
begin
   result := true;
   if not FRequireAuthorization then begin
      exit;
   end;

   result := false;
   if FAccessToken = '' then begin
      exit;
   end;

   Header := Trim(ARequestInfo.RawHeaders.Values['Authorization']);
   if SameText(Copy(Header, 1, Length(BearerPrefix)), BearerPrefix) and
      (Copy(Header, Length(BearerPrefix) + 1, MaxInt) = FAccessToken) then begin
      result := true;
      exit;
   end;

   TokenHeader := ARequestInfo.RawHeaders.Values['X-MCP2Delphi-Token'];
   result := TokenHeader = FAccessToken;
end;

procedure TMcpServer.SetUnauthorizedResponse(AResponseInfo: TIdHTTPResponseInfo);
begin
   AResponseInfo.ResponseNo := 401;
   SetUtf8Response(AResponseInfo,
      '{"error":"unauthorized","message":"POST /mcp requires X-MCP2Delphi-Token."}');
end;

function HtmlEncode(const Value: string): string; forward;
function JsonField(const Obj: TJSONObject; const Name: string): string; forward;

function FormatBytes(Value: Int64): string;
const
   KB = 1024;
   MB = KB * 1024;
begin
   if Value >= MB then begin
      result := FormatFloat('0.0', Value / MB) + ' MB';
   end
   else if Value >= KB then begin
      result := FormatFloat('0.0', Value / KB) + ' KB';
   end
   else begin
      result := IntToStr(Value) + ' B';
   end;
end;

function DiscoveryKeyName(ProcessId: Cardinal; Port: integer): string;
begin
   result := Format('%d_%d', [ProcessId, Port]);
end;

function ProcessIsRunning(ProcessId: Cardinal): boolean;
var
   Handle: THandle;
begin
   result := false;
   if ProcessId = 0 then begin
      exit;
   end;

   if ProcessId = GetCurrentProcessId then begin
      result := true;
      exit;
   end;

   Handle := OpenProcess(SYNCHRONIZE, false, ProcessId);
   if Handle = 0 then begin
      exit;
   end;
   try
      result := WaitForSingleObject(Handle, 0) = WAIT_TIMEOUT;
   finally
      CloseHandle(Handle);
   end;
end;

procedure TMcpServer.PublishDiscovery(Active: boolean);
var
   Registry: TRegistry;
   KeyName: string;
begin
   if FActivePort <= 0 then begin
      exit;
   end;

   Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
   try
      try
         Registry.RootKey := HKEY_CURRENT_USER;
         KeyName := '\Software\MCP2Delphi\Servers\' + DiscoveryKeyName(GetCurrentProcessId, FActivePort);
         if Registry.OpenKey(KeyName, true) then begin
            Registry.WriteBool('Active', Active);
            Registry.WriteString('ServerName', FServerName);
            Registry.WriteString('Url', Url);
            Registry.WriteString('BindHost', FBindHost);
            Registry.WriteInteger('ConfiguredPort', FPort);
            Registry.WriteInteger('ActivePort', FActivePort);
            Registry.WriteInteger('ProcessId', GetCurrentProcessId);
            Registry.WriteBool('RequiresAuthorization', FRequireAuthorization);
            Registry.WriteString('ProcessName', ExtractFileName(ParamStr(0)));
            if Active and not Registry.ValueExists('StartedAt') then begin
               Registry.WriteString('StartedAt', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
            end;
            Registry.WriteString('UpdatedAt', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));
         end;
      except
         { Discovery is helpful, but the HTTP server must still start without registry access. }
      end;
   finally
      Registry.Free;
   end;
end;

function TMcpServer.BuildDiscoveryJson: TJSONArray;
const
   BaseKey = '\Software\MCP2Delphi\Servers';
var
   Registry: TRegistry;
   Keys: TStringList;
   i: integer;
   KeyName, ServerName, UrlValue, ProcessName, UpdatedAt, StatusText: string;
   Active, SelfEntry, RequiresAuthorization: boolean;
   ProcessId, ActivePort: integer;
   Item: TJSONObject;

   function ReadStringValue(const Name: string): string;
   begin
      result := '';
      if Registry.ValueExists(Name) then begin
         result := Registry.ReadString(Name);
      end;
   end;

   function ReadIntegerValue(const Name: string): integer;
   begin
      result := 0;
      if Registry.ValueExists(Name) then begin
         result := Registry.ReadInteger(Name);
      end;
   end;

   function ReadBoolValue(const Name: string): boolean;
   begin
      result := false;
      if Registry.ValueExists(Name) then begin
         result := Registry.ReadBool(Name);
      end;
   end;

begin
   result := TJSONArray.Create;
   Registry := TRegistry.Create(KEY_READ);
   Keys := TStringList.Create;
   try
      Registry.RootKey := HKEY_CURRENT_USER;
      if not Registry.OpenKeyReadOnly(BaseKey) then begin
         exit;
      end;

      Registry.GetKeyNames(Keys);
      Registry.CloseKey;

      for i := 0 to Keys.Count - 1 do begin
         KeyName := BaseKey + '\' + Keys[i];
         if not Registry.OpenKeyReadOnly(KeyName) then begin
            continue;
         end;
         try
            Active := ReadBoolValue('Active');
            ServerName := ReadStringValue('ServerName');
            UrlValue := ReadStringValue('Url');
            ProcessName := ReadStringValue('ProcessName');
            UpdatedAt := ReadStringValue('UpdatedAt');
            ProcessId := ReadIntegerValue('ProcessId');
            ActivePort := ReadIntegerValue('ActivePort');
            RequiresAuthorization := ReadBoolValue('RequiresAuthorization');

            SelfEntry := SameText(UrlValue, Url) and (ProcessId = Integer(GetCurrentProcessId));
            if SelfEntry then begin
               StatusText := 'diese Seite';
            end
            else if Active and ProcessIsRunning(ProcessId) then begin
               StatusText := 'aktiv gemeldet';
            end
            else begin
               continue;
            end;

            Item := TJSONObject.Create;
            Item.AddPair('status', StatusText);
            Item.AddPair('serverName', ServerName);
            Item.AddPair('url', UrlValue);
            Item.AddPair('statusUrl', StringReplace(UrlValue, '/mcp', '/status.json', [rfIgnoreCase]));
            Item.AddPair('pageUrl', StringReplace(UrlValue, '/mcp', '/', [rfIgnoreCase]));
            Item.AddPair('processName', ProcessName);
            Item.AddPair('processId', TJSONNumber.Create(ProcessId));
            Item.AddPair('activePort', TJSONNumber.Create(ActivePort));
            Item.AddPair('requiresAuthorization', TJSONBool.Create(RequiresAuthorization));
            Item.AddPair('updatedAt', UpdatedAt);
            Item.AddPair('self', TJSONBool.Create(SelfEntry));
            result.AddElement(Item);
         finally
            Registry.CloseKey;
         end;
      end;
   finally
      Keys.Free;
      Registry.Free;
   end;
end;

function HtmlEncode(const Value: string): string;
begin
   result := StringReplace(Value, '&', '&amp;', [rfReplaceAll]);
   result := StringReplace(result, '<', '&lt;', [rfReplaceAll]);
   result := StringReplace(result, '>', '&gt;', [rfReplaceAll]);
   result := StringReplace(result, '"', '&quot;', [rfReplaceAll]);
end;

function JsonField(const Obj: TJSONObject; const Name: string): string;
var
   Value: TJSONValue;
begin
   result := '';
   if Obj = nil then begin
      exit;
   end;
   Value := Obj.Values[Name];
   if Value <> nil then begin
      result := Value.Value;
   end;
end;

function GermanUmlautText(const Value: string): string;
begin
   result := Value;
   result := StringReplace(result, 'Ueber', #$00DC + 'ber', [rfReplaceAll]);
   result := StringReplace(result, 'ueber', #$00FC + 'ber', [rfReplaceAll]);
   result := StringReplace(result, 'Aehn', #$00C4 + 'hn', [rfReplaceAll]);
   result := StringReplace(result, 'aehn', #$00E4 + 'hn', [rfReplaceAll]);
   result := StringReplace(result, 'Stoer', 'St' + #$00F6 + 'r', [rfReplaceAll]);
   result := StringReplace(result, 'stoer', 'st' + #$00F6 + 'r', [rfReplaceAll]);
   result := StringReplace(result, 'Kanael', 'Kan' + #$00E4 + 'l', [rfReplaceAll]);
   result := StringReplace(result, 'kanael', 'kan' + #$00E4 + 'l', [rfReplaceAll]);
   result := StringReplace(result, 'pruef', 'pr' + #$00FC + 'f', [rfReplaceAll]);
   result := StringReplace(result, 'Pruef', 'Pr' + #$00FC + 'f', [rfReplaceAll]);
   result := StringReplace(result, 'Kataloguebersicht', 'Katalog' + #$00FC + 'bersicht', [rfReplaceAll]);
   result := StringReplace(result, 'erklaer', 'erkl' + #$00E4 + 'r', [rfReplaceAll]);
   result := StringReplace(result, 'Erklaer', 'Erkl' + #$00E4 + 'r', [rfReplaceAll]);
   result := StringReplace(result, 'Oberflaeche', 'Oberfl' + #$00E4 + 'che', [rfReplaceAll]);
   result := StringReplace(result, 'auswaehl', 'ausw' + #$00E4 + 'hl', [rfReplaceAll]);
   result := StringReplace(result, 'Auswaehl', 'Ausw' + #$00E4 + 'hl', [rfReplaceAll]);
end;

function RenderJsonTable(Items: TJSONArray; const Columns: array of string): string;
var
   i, c: integer;
   Obj: TJSONObject;
   CellValue: string;
begin
   if (Items = nil) or (Items.Count = 0) then begin
      result := '<p class="empty">Keine Eintr' + #$00E4 + 'ge.</p>';
      exit;
   end;

   result := '<table><thead><tr>';
   for c := 0 to high(Columns) do begin
      result := result + '<th>' + HtmlEncode(Columns[c]) + '</th>';
   end;
   result := result + '</tr></thead><tbody>';

   for i := 0 to Items.Count - 1 do begin
      if Items.Items[i] is TJSONObject then begin
         Obj := TJSONObject(Items.Items[i]);
         result := result + '<tr>';
         for c := 0 to high(Columns) do begin
            CellValue := JsonField(Obj, Columns[c]);
            if SameText(Columns[c], 'description') then begin
               CellValue := GermanUmlautText(CellValue);
            end;
            result := result + '<td>' + HtmlEncode(CellValue) + '</td>';
         end;
         result := result + '</tr>';
      end;
   end;
   result := result + '</tbody></table>';
end;

function TMcpServer.BuildCapabilitiesJson: TJSONObject;
begin
   result := TJSONObject.Create;
   result.AddPair('tools', TJSONObject.Create);
   result.AddPair('resources', TJSONObject.Create);
   result.AddPair('prompts', TJSONObject.Create);
end;

function TMcpServer.BuildServerDiscoverJson: TJSONObject;
var
   SupportedVersions, PlannedVersions: TJSONArray;
   MetaObj, CompatibilityObj: TJSONObject;
begin
   result := TJSONObject.Create;
   result.AddPair('resultType', 'complete');

   SupportedVersions := TJSONArray.Create;
   SupportedVersions.Add(CMcpLegacyProtocolVersion);
   SupportedVersions.Add(CMcpNextProtocolVersion);
   result.AddPair('supportedVersions', SupportedVersions);

   result.AddPair('capabilities', BuildCapabilitiesJson);
   result.AddPair('serverInfo', TJSONObject.Create.AddPair('name', FServerName).AddPair('version', FServerVersion));
   result.AddPair('instructions',
      'Use JSON-RPC on /mcp. The legacy initialize/tools flow is active; MCP 2026-07-28 is prepared as a parallel compatibility path.');
   result.AddPair('ttlMs', TJSONNumber.Create(60000));
   result.AddPair('cacheScope', 'public');

   MetaObj := TJSONObject.Create;
   MetaObj.AddPair('io.modelcontextprotocol/serverInfo',
      TJSONObject.Create.AddPair('name', FServerName).AddPair('version', FServerVersion));
   CompatibilityObj := TJSONObject.Create;
   PlannedVersions := TJSONArray.Create;
   PlannedVersions.Add(CMcpNextProtocolVersion);
   CompatibilityObj.AddPair('legacyActive', TJSONBool.Create(true));
   CompatibilityObj.AddPair('legacyVersion', CMcpLegacyProtocolVersion);
   CompatibilityObj.AddPair('discoverMethod', 'server/discover');
   CompatibilityObj.AddPair('statelessHttpActive', TJSONBool.Create(true));
   CompatibilityObj.AddPair('plannedVersions', PlannedVersions);
   MetaObj.AddPair('mcp2delphi/compatibility', CompatibilityObj);
   result.AddPair('_meta', MetaObj);
end;

function TMcpServer.BuildStatusJson: string;
var
   Root, ServerObj, MetricsObj, CountsObj, SecurityObj, ProtocolObj: TJSONObject;
   Tools, Resources, Prompts: TJSONArray;
begin
   Root := TJSONObject.Create;
   try
      ServerObj := TJSONObject.Create;
      ServerObj.AddPair('name', FServerName);
      ServerObj.AddPair('version', FServerVersion);
      ServerObj.AddPair('url', Url);
      ServerObj.AddPair('startedAt', FormatDateTime('yyyy-mm-dd hh:nn:ss', FStartedAt));
      ServerObj.AddPair('lastRequestAt', FormatDateTime('yyyy-mm-dd hh:nn:ss', FLastRequestAt));
      Root.AddPair('server', ServerObj);

      MetricsObj := TJSONObject.Create;
      MetricsObj.AddPair('requests', TJSONNumber.Create(FRequestCount));
      MetricsObj.AddPair('get', TJSONNumber.Create(FGetCount));
      MetricsObj.AddPair('post', TJSONNumber.Create(FPostCount));
      MetricsObj.AddPair('options', TJSONNumber.Create(FOptionsCount));
      MetricsObj.AddPair('bytesRead', TJSONNumber.Create(FBytesRead));
      MetricsObj.AddPair('bytesReadText', FormatBytes(FBytesRead));
      MetricsObj.AddPair('bytesWritten', TJSONNumber.Create(FBytesWritten));
      MetricsObj.AddPair('bytesWrittenText', FormatBytes(FBytesWritten));
      Root.AddPair('metrics', MetricsObj);

      CountsObj := TJSONObject.Create;
      Tools := FRegistry.ListTools;
      try
         CountsObj.AddPair('tools', TJSONNumber.Create(Tools.Count));
      finally
         Tools.Free;
      end;

      if Assigned(FOnListResources) then begin
         Resources := FOnListResources;
         try
            CountsObj.AddPair('resources', TJSONNumber.Create(Resources.Count));
         finally
            Resources.Free;
         end;
      end
      else begin
         CountsObj.AddPair('resources', TJSONNumber.Create(0));
      end;

      if Assigned(FOnListPrompts) then begin
         Prompts := FOnListPrompts;
         try
            CountsObj.AddPair('prompts', TJSONNumber.Create(Prompts.Count));
         finally
            Prompts.Free;
         end;
      end
      else begin
         CountsObj.AddPair('prompts', TJSONNumber.Create(0));
      end;
      Root.AddPair('counts', CountsObj);

      SecurityObj := TJSONObject.Create;
      SecurityObj.AddPair('requiresAuthorization', TJSONBool.Create(FRequireAuthorization));
      SecurityObj.AddPair('tokenHeader', 'X-MCP2Delphi-Token');
      SecurityObj.AddPair('tokenFile', FAccessTokenFile);
      Root.AddPair('security', SecurityObj);

      ProtocolObj := TJSONObject.Create;
      ProtocolObj.AddPair('legacyActive', TJSONBool.Create(true));
      ProtocolObj.AddPair('legacyVersion', CMcpLegacyProtocolVersion);
      ProtocolObj.AddPair('discoverMethod', 'server/discover');
      ProtocolObj.AddPair('nextVersion', CMcpNextProtocolVersion);
      ProtocolObj.AddPair('nextActive', TJSONBool.Create(true));
      ProtocolObj.AddPair('nextStatus', 'active-parallel-path');
      Root.AddPair('protocol', ProtocolObj);

      Root.AddPair('activeServers', BuildDiscoveryJson);
      result := Root.ToJSON;
   finally
      Root.Free;
   end;
end;

function TMcpServer.BuildOverviewHtml: string;
var
   Tools, Resources, Prompts: TJSONArray;
   ToolCount: integer;
   ResourceStatus, PromptStatus: string;
   ToolRows, ResourceRows, PromptRows: string;
   IsIdeServer: boolean;
   PowerShellExample, IdeGuideHtml, SecurityHtml: string;
begin
   IsIdeServer := SameText(FServerName, 'delphi-ide');

   Tools := FRegistry.ListTools;
   try
      ToolCount := Tools.Count;
      ToolRows := RenderJsonTable(Tools, ['name', 'description']);
   finally
      Tools.Free;
   end;

   ResourceStatus := 'nicht registriert';
   ResourceRows := '<p class="empty">Keine Resource-Handler registriert.</p>';
   if Assigned(FOnListResources) then begin
      Resources := FOnListResources;
      try
         ResourceStatus := IntToStr(Resources.Count);
         ResourceRows := RenderJsonTable(Resources, ['uri', 'name', 'mimeType']);
      finally
         Resources.Free;
      end;
   end;

   PromptStatus := 'nicht registriert';
   PromptRows := '<p class="empty">Keine Prompt-Handler registriert.</p>';
   if Assigned(FOnListPrompts) then begin
      Prompts := FOnListPrompts;
      try
         PromptStatus := IntToStr(Prompts.Count);
         PromptRows := RenderJsonTable(Prompts, ['name', 'description']);
      finally
         Prompts.Free;
      end;
   end;

   if FRequireAuthorization then begin
      PowerShellExample :=
         '$tokenInfo = Get-Content ''' + FAccessTokenFile + ''' -Encoding UTF8 | ConvertFrom-Json'#13#10 +
         '$headers = @{ "X-MCP2Delphi-Token" = $tokenInfo.token }'#13#10 +
         '$body = @{jsonrpc=''2.0''; id=1; method=''tools/list''; params=@{}} | ConvertTo-Json -Depth 10'#13#10 +
         'Invoke-RestMethod -Uri ''' + Url + ''' -Method Post -ContentType ''application/json'' -Headers $headers -Body $body';
      SecurityHtml :=
         '<h2>Sicherheit</h2>' +
         '<div class="steps">' +
         '<div><b>POST /mcp gesch' + #$00FC + 'tzt</b><br><code>X-MCP2Delphi-Token: &lt;token&gt;</code></div>' +
         '<div><b>Token-Datei</b><br><code>' + HtmlEncode(FAccessTokenFile) + '</code></div>' +
         '<div><b>Browser-Status</b><br>GET-Statusseiten bleiben ohne Token lesbar.</div>' +
         '</div>';
   end
   else begin
      PowerShellExample :=
         '$body = @{jsonrpc=''2.0''; id=1; method=''tools/list''; params=@{}} | ConvertTo-Json -Depth 10'#13#10 +
         'Invoke-RestMethod -Uri ''' + Url + ''' -Method Post -ContentType ''application/json'' -Body $body';
      SecurityHtml :=
         '<h2>Sicherheit</h2>' +
         '<p class="hint">Token-Schutz ist f' + #$00FC + 'r diesen Server deaktiviert.</p>';
   end;

   IdeGuideHtml := '';
   if IsIdeServer then begin
      IdeGuideHtml :=
         '<h2>Delphi IDE steuern</h2>' +
         '<p>Dieser MCP-Server l' + #$00E4 + 'uft direkt in RAD Studio. Ein Agent nutzt JSON-RPC per POST; ' +
         'diese Browser-Seite ist die schnelle Status- und Einstiegshilfe f' + #$00FC + 'r Entwickler.</p>' +
         '<div class="steps">' +
         '<div><b>1. Verbindung pr' + #$00FC + 'fen</b><br><code>ide_ping</code> oder <code>ide_status</code> aufrufen.</div>' +
         '<div><b>2. Projekt vorbereiten</b><br><code>ide_open_file</code>, <code>ide_close_file</code> und <code>ide_set_active_project</code> verwenden.</div>' +
         '<div><b>3. Build ausf' + #$00FC + 'hren</b><br><code>ide_build_project</code> mit <code>method=action</code> starten und offene Build-Dialoge mit <code>ide_close_build_dialogs</code> schlie' + #$00DF + 'en.</div>' +
         '<div><b>4. Debugging automatisieren</b><br><code>debug_add_breakpoint</code>, <code>debug_run</code>, <code>debug_get_current_source_location</code>, <code>debug_step_over</code> und <code>debug_evaluate_expression</code> nutzen.</div>' +
         '</div>' +
         '<p class="hint">Ausf' + #$00FC + 'hrliche Agenten-Hinweise liefert dieser Server selbst als MCP-Resources und Prompt.</p>' +
         '<pre>{"jsonrpc":"2.0","id":5,"method":"resources/read","params":{"uri":"mcp2delphi://ide/how-to-control-delphi"}}</pre>' +
         '<pre>{"jsonrpc":"2.0","id":6,"method":"resources/read","params":{"uri":"mcp2delphi://ide/debug-workflow"}}</pre>' +
         '<pre>{"jsonrpc":"2.0","id":7,"method":"prompts/get","params":{"name":"delphi-ide-control-guide"}}</pre>';
   end;

   result :=
      '<!doctype html><html lang="de"><head><meta charset="utf-8">' +
      '<meta name="viewport" content="width=device-width,initial-scale=1">' +
      '<title>' + HtmlEncode(FServerName) + ' MCP</title>' +
      '<style>' +
      'body{font-family:Segoe UI,Arial,sans-serif;margin:32px;line-height:1.45;color:#1f2933;background:#f7f8fa}' +
      'main{max-width:1120px;margin:auto;background:white;border:1px solid #d9dee7;padding:16px 24px 24px}' +
      'h1{margin:36px 0 0;font-size:26px}h2{font-size:18px;margin:28px 0 14px}h2:first-child{margin-top:0}' +
      'code,pre{font-family:Consolas,monospace}pre{background:#111827;color:#e5e7eb;padding:14px;overflow:auto}' +
      '.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px}' +
      '.box{border:1px solid #d9dee7;padding:12px;background:#fafafa}.n{font-size:24px;font-weight:600}' +
      '.lead{max-width:780px;color:#334155}.hint{color:#475569}.steps{display:grid;grid-template-columns:repeat(auto-fit,minmax(230px,1fr));gap:10px}.steps div{border:1px solid #d9dee7;background:#fafafa;padding:10px}' +
      '.server-grid{display:grid;gap:14px;margin-top:12px}.server-card{border:2px solid #84cc16;background:#f7fee7;padding:12px;box-shadow:0 0 0 2px #dcfce7}.server-card.self{background:#ecfeff}.server-card.stale{border-color:#cbd5e1;background:#f8fafc;box-shadow:none;opacity:.72}.server-card b{display:block;margin-bottom:4px}.server-head{display:flex;flex-wrap:wrap;gap:8px 18px;align-items:baseline;margin-bottom:10px}.server-metrics{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:10px}.metric{border:1px solid #d9dee7;background:#fff;padding:10px}.metric .value{font-size:20px;font-weight:600}.small{font-size:12px;color:#64748b}.err{color:#b91c1c}' +
      '.self{background:#ecfeff}' +
      'table{border-collapse:collapse;width:100%;margin-top:8px;font-size:13px}th,td{border:1px solid #d9dee7;padding:6px 8px;text-align:left;vertical-align:top}th{background:#f1f5f9}.empty{color:#64748b}' +
      'a{color:#075985}' +
      '</style></head><body><main>' +
      '<h2>Status und Monitoring</h2>' +
      '<div id="activeServers" class="server-grid"></div>' +
      '<h1>' + HtmlEncode(FServerName) + ' MCP Server</h1>' +
      '<p class="lead">Diese Seite ist f' + #$00FC + 'r den schnellen Blick im Browser gedacht. Die eigentliche MCP-API liegt auf demselben Endpoint und verarbeitet JSON-RPC-Anfragen per HTTP POST.</p>' +
      '<div class="grid">' +
      '<div class="box"><div>Endpoint</div><div><code>' + HtmlEncode(Url) + '</code></div></div>' +
      '<div class="box"><div>Version</div><div class="n">' + HtmlEncode(FServerVersion) + '</div></div>' +
      '<div class="box"><div>Tools</div><div class="n">' + IntToStr(ToolCount) + '</div></div>' +
      '<div class="box"><div>Resources</div><div class="n">' + HtmlEncode(ResourceStatus) + '</div></div>' +
      '<div class="box"><div>Prompts</div><div class="n">' + HtmlEncode(PromptStatus) + '</div></div>' +
      '</div>' +
      '<h2>Erste Schritte</h2>' +
      '<div class="steps">' +
      '<div><b>Browser</b><br>Statusseite ' + #$00F6 + 'ffnen und Endpoint kopieren.</div>' +
      '<div><b>Client oder Agent</b><br>JSON-RPC per POST an <code>' + HtmlEncode(Url) + '</code> senden.</div>' +
      '<div><b>Funktionen entdecken</b><br><code>tools/list</code>, <code>resources/list</code> und <code>prompts/list</code> abfragen.</div>' +
      '</div>' +
      SecurityHtml +
      IdeGuideHtml +
      '<h2>Erste MCP-Aufrufe</h2>' +
      '<p class="hint">Beispiel mit PowerShell:</p>' +
      '<pre>' + HtmlEncode(PowerShellExample) + '</pre>' +
      '<p class="hint">Rohdaten f' + #$00FC + 'r beliebige JSON-RPC-Clients:</p>' +
      '<pre>{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}</pre>' +
      '<pre>{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}</pre>' +
      '<pre>{"jsonrpc":"2.0","id":3,"method":"resources/list","params":{}}</pre>' +
      '<pre>{"jsonrpc":"2.0","id":4,"method":"prompts/list","params":{}}</pre>' +
      '<h2>Verf' + #$00FC + 'gbare Tools</h2>' + ToolRows +
      '<h2>Verf' + #$00FC + 'gbare Resources</h2>' + ResourceRows +
      '<h2>Verf' + #$00FC + 'gbare Prompts</h2>' + PromptRows +
      '<script>' +
      '(function(){' +
      'function key(s){return (s.serverName||"")+"|"+(s.url||"");}' +
      'function txt(e,v){if(e){e.textContent=v==null?"":v;}}' +
      'function makeMetric(grid,name,label){var box=document.createElement("div");box.className="metric";var l=document.createElement("div");l.textContent=label;var v=document.createElement("div");v.className="value";v.dataset.metric=name;box.appendChild(l);box.appendChild(v);grid.appendChild(box);}' +
      'function findCard(host,k){for(var i=0;i<host.children.length;i++){if(host.children[i].dataset.key===k){return host.children[i];}}return null;}' +
      'function ensureCard(host,s){var k=key(s),card=findCard(host,k);if(card){return card;}card=document.createElement("div");card.dataset.key=k;card.className="server-card";var head=document.createElement("div");head.className="server-head";var title=document.createElement("b");title.dataset.role="title";head.appendChild(title);var link=document.createElement("a");link.dataset.role="link";head.appendChild(link);var info=document.createElement("span");info.className="small";info.dataset.role="info";head.appendChild(info);card.appendChild(head);var grid=document.createElement("div");grid.className="server-metrics";makeMetric(grid,"started","Gestartet");makeMetric(grid,"last","Letzter Aufruf");makeMetric(grid,"requests","Aufrufe gesamt");makeMetric(grid,"methods","GET / POST / OPTIONS");makeMetric(grid,"read","Gelesene Daten");makeMetric(grid,"written","Geschriebene Daten");card.appendChild(grid);host.appendChild(card);return card;}' +
      'function updateCard(card,s,server,metrics,stale){card.className="server-card"+(s.self?" self":"")+(stale?" stale":"");txt(card.querySelector("[data-role=title]"),s.serverName||"MCP Server");var link=card.querySelector("[data-role=link]");if(link){link.href=s.pageUrl||s.url||"#";link.textContent=s.url||"";}txt(card.querySelector("[data-role=info]"),(stale?"nicht erreichbar":(s.status||""))+" - PID "+(s.processId||"")+" - Port "+(s.activePort||"")+(s.requiresAuthorization?" - POST geschuetzt":""));var m=metrics||{},srv=server||{};txt(card.querySelector("[data-metric=started]"),srv.startedAt||s.updatedAt||"");txt(card.querySelector("[data-metric=last]"),srv.lastRequestAt||"");txt(card.querySelector("[data-metric=requests]"),m.requests||0);txt(card.querySelector("[data-metric=methods]"),(m.get||0)+" / "+(m.post||0)+" / "+(m.options||0));txt(card.querySelector("[data-metric=read]"),m.bytesReadText||"0 B");txt(card.querySelector("[data-metric=written]"),m.bytesWrittenText||"0 B");}' +
      'function renderServers(list,own){var host=document.getElementById("activeServers");if(!host){return;}var sorted=(list||[]).slice().sort(function(a,b){return (b.self?1:0)-(a.self?1:0)||(a.serverName||"").localeCompare(b.serverName||"");});var seen={};sorted.forEach(function(s){var card=ensureCard(host,s);seen[key(s)]=true;host.appendChild(card);if(s.self){updateCard(card,s,(own||{}).server,(own||{}).metrics,false);}else if(s.statusUrl){fetch(s.statusUrl,{cache:"no-store"}).then(function(r){return r.json();}).then(function(x){updateCard(card,s,x.server,x.metrics,false);}).catch(function(){updateCard(card,s,null,null,true);});}else{updateCard(card,s,null,null,false);}});Array.prototype.slice.call(host.children).forEach(function(card){if(!seen[card.dataset.key]){card.remove();}});}' +
      'function refresh(){fetch("status.json",{cache:"no-store"}).then(function(r){return r.json();}).then(function(s){renderServers(s.activeServers||[],s);}).catch(function(){});}' +
      'refresh();setInterval(refresh,2000);' +
      '})();' +
      '</script>' +
      '</main></body></html>';
end;

procedure TMcpServer.Start;
var
   Binding: TIdSocketHandle;
   TryPort: integer;
begin
   if McpRunningInIdeProcess and not FAllowInIdeProcess then begin
      exit;
   end;

   if Active then begin
      exit;
   end;

   FStartedAt := Now;
   for TryPort := FPort to FPort + 10 do begin
      FHttpServer := TIdHTTPServer.Create(nil);
      FEvents := TMcpServerEvents.Create(Self);
      try
         FActivePort := TryPort;
         FHttpServer.DefaultPort := TryPort;
         Binding := FHttpServer.Bindings.Add;
         Binding.IP := FBindHost;
         Binding.Port := TryPort;
         FHttpServer.OnCommandGet := FEvents.CommandGet;
         FHttpServer.OnCommandOther := FEvents.CommandGet;
         FHttpServer.Active := true;
         WriteAccessTokenFile;
         PublishDiscovery(true);
         exit;
      except
         DeleteAccessTokenFile;
         FreeAndNil(FHttpServer);
         FreeAndNil(FEvents);
      end;
   end;
   FActivePort := 0;
   raise Exception.CreateFmt('Kein freier MCP-Port im Bereich %d..%d.', [FPort, FPort + 10]);
end;

procedure TMcpServer.Stop;
begin
   if FActivePort > 0 then begin
      PublishDiscovery(false);
   end;
   DeleteAccessTokenFile;
   if FHttpServer <> nil then begin
      FHttpServer.Active := false;
      FreeAndNil(FHttpServer);
      FreeAndNil(FEvents);
   end;
   FActivePort := 0;
end;

procedure TMcpServer.RegisterTool(const Name, Description: string; const Required, Properties: array of string;
   Handler: TMcpToolHandler; RunInMainThread: boolean = false; const OwnerId: string = '');
begin
   FRegistry.RegisterTool(Name, Description, Required, Properties, Handler, RunInMainThread, OwnerId);
end;

procedure TMcpServer.RegisterTool(const Name, Description: string; Schema: TJSONObject;
   Handler: TMcpToolHandler; RunInMainThread: boolean = false; const OwnerId: string = '');
begin
   FRegistry.RegisterTool(Name, Description, Schema, Handler, RunInMainThread, OwnerId);
end;

procedure TMcpServer.RegisterResourceHandlers(ListHandler: TMcpListResourcesHandler; ReadHandler: TMcpReadResourceHandler;
   const OwnerId: string = '');
begin
   FResourceOwnerId := OwnerId;
   FOnListResources := ListHandler;
   FOnReadResource := ReadHandler;
end;

procedure TMcpServer.RegisterPromptHandlers(ListHandler: TMcpListPromptsHandler; GetHandler: TMcpGetPromptHandler;
   const OwnerId: string = '');
begin
   FPromptOwnerId := OwnerId;
   FOnListPrompts := ListHandler;
   FOnGetPrompt := GetHandler;
end;

procedure TMcpServer.UnregisterOwner(const OwnerId: string);
begin
   if OwnerId = '' then begin
      exit;
   end;
   FRegistry.UnregisterOwner(OwnerId);
   if SameText(FResourceOwnerId, OwnerId) then begin
      FResourceOwnerId := '';
      FOnListResources := nil;
      FOnReadResource := nil;
   end;
   if SameText(FPromptOwnerId, OwnerId) then begin
      FPromptOwnerId := '';
      FOnListPrompts := nil;
      FOnGetPrompt := nil;
   end;
end;

function TMcpServer.ExecuteTool(const ToolName: string; Args: TJSONObject): TJSONValue;
begin
   if FRegistry.ToolRunsInMainThread(ToolName) then begin
      if FRegistry.ContainsTool(ToolName) then begin
         result := FVclBridge.ExecuteOnMainThread(ToolName,
            function: TJSONValue
            begin
               result := FRegistry.CallTool(ToolName, Args);
            end);
      end
      else begin
         raise Exception.CreateFmt('Unbekanntes MCP tool: %s', [ToolName]);
      end;
   end
   else begin
      result := FRegistry.CallTool(ToolName, Args);
   end;
end;

function TMcpServer.HandleRequest(const RequestText, ProtocolVersion, HeaderMethod,
   HeaderName: string): string;
var
   Root: TJSONValue;
   Req, Params, Args, ResultObj, ReadObj, PromptObj, Msg, ContentObj: TJSONObject;
   IdValue, ToolResult: TJSONValue;
   MethodName, RequestedHeaderMethod, RequestedHeaderName, RequestedProtocolVersion,
      ToolName, Uri, PromptName: string;
   Tools, Resources, Prompts, Contents, Messages: TJSONArray;
   IsNextProtocol: boolean;
begin
   Root := TJSONObject.ParseJSONValue(RequestText);
   try
      if not (Root is TJSONObject) then begin
         result := McpJsonRpcError(nil, 'Ungueltige JSON-RPC-Anfrage.').ToJSON;
         exit;
      end;

      Req := TJSONObject(Root);
      IdValue := Req.Values['id'];
      MethodName := McpJsonRpcMethod(Req);
      Params := McpJsonRpcParams(Req);
      RequestedHeaderMethod := Trim(HeaderMethod);
      RequestedHeaderName := Trim(HeaderName);
      RequestedProtocolVersion := Trim(ProtocolVersion);
      IsNextProtocol := SameText(RequestedProtocolVersion, CMcpNextProtocolVersion);

      try
         if RequestedHeaderMethod <> '' then begin
            if not SameText(RequestedHeaderMethod, MethodName) then begin
               result := McpJsonRpcError(IdValue,
                  'Mcp-Method passt nicht zur JSON-RPC-Methode: ' +
                  RequestedHeaderMethod + ' <> ' + MethodName).ToJSON;
               exit;
            end;
         end;

         if RequestedHeaderName <> '' then begin
            if not SameText(MethodName, 'tools/call') then begin
               result := McpJsonRpcError(IdValue,
                  'Mcp-Name ist nur fuer tools/call zulaessig.').ToJSON;
               exit;
            end;
            if not Assigned(Params) or
               (not SameText(RequestedHeaderName, McpJsonString(Params, 'name', ''))) then begin
               result := McpJsonRpcError(IdValue,
                  'Mcp-Name passt nicht zu params.name: ' + RequestedHeaderName).ToJSON;
               exit;
            end;
         end;

         if (RequestedProtocolVersion <> '') and
            (not SameText(RequestedProtocolVersion, CMcpLegacyProtocolVersion)) and
            (not (IsNextProtocol and
            (SameText(MethodName, 'server/discover') or SameText(MethodName, 'tools/list') or
            SameText(MethodName, 'tools/call') or SameText(MethodName, 'resources/list') or
            SameText(MethodName, 'resources/read') or SameText(MethodName, 'prompts/list') or
            SameText(MethodName, 'prompts/get')))) then begin
            result := McpJsonRpcError(IdValue,
               'Nicht unterstuetzte MCP-Protokollversion: ' + RequestedProtocolVersion).ToJSON;
            exit;
         end;

         if IsNextProtocol and (not SameText(MethodName, 'server/discover')) and
            (RequestedHeaderMethod = '') then begin
            result := McpJsonRpcError(IdValue,
               'Mcp-Method ist fuer MCP 2026-07-28 erforderlich.').ToJSON;
            exit;
         end;

         if IsNextProtocol and SameText(MethodName, 'tools/call') and
            (RequestedHeaderName = '') then begin
            result := McpJsonRpcError(IdValue,
               'Mcp-Name ist fuer tools/call mit MCP 2026-07-28 erforderlich.').ToJSON;
            exit;
         end;

         if SameText(MethodName, 'server/discover') then begin
            result := McpJsonRpcResult(IdValue, BuildServerDiscoverJson).ToJSON;
         end
         else if SameText(MethodName, 'initialize') then begin
            ResultObj := TJSONObject.Create;
            ResultObj.AddPair('protocolVersion', CMcpLegacyProtocolVersion);
            ResultObj.AddPair('serverInfo', TJSONObject.Create.AddPair('name', FServerName).AddPair('version', FServerVersion));
            ResultObj.AddPair('capabilities', BuildCapabilitiesJson);
            result := McpJsonRpcResult(IdValue, ResultObj).ToJSON;
         end
         else if SameText(MethodName, 'tools/list') then begin
            Tools := FRegistry.ListTools;
            ResultObj := TJSONObject.Create;
            ResultObj.AddPair('tools', Tools);
            if IsNextProtocol then begin
               ResultObj.AddPair('ttlMs', TJSONNumber.Create(60000));
               ResultObj.AddPair('cacheScope', 'private');
            end;
            result := McpJsonRpcResult(IdValue, ResultObj).ToJSON;
         end
         else if SameText(MethodName, 'tools/call') then begin
            ToolName := McpJsonString(Params, 'name', '');
            if ToolName = '' then begin
               result := McpJsonRpcError(IdValue, 'tools/call benoetigt params.name.').ToJSON;
               exit;
            end;
            if (Params <> nil) and (Params.Values['arguments'] is TJSONObject) then begin
               Args := TJSONObject(Params.Values['arguments']).Clone as TJSONObject;
            end
            else begin
               Args := TJSONObject.Create;
            end;
            try
               ToolResult := ExecuteTool(ToolName, Args);
               try
                  result := McpJsonRpcResult(IdValue, McpTextContentResult(ToolResult)).ToJSON;
               finally
                  ToolResult.Free;
               end;
            finally
               Args.Free;
            end;
         end
         else if SameText(MethodName, 'resources/list') then begin
            if not Assigned(FOnListResources) then begin
               if IsNextProtocol then begin
                  ResultObj := TJSONObject.Create;
                  ResultObj.AddPair('resources', TJSONArray.Create);
                  ResultObj.AddPair('ttlMs', TJSONNumber.Create(60000));
                  ResultObj.AddPair('cacheScope', 'private');
                  result := McpJsonRpcResult(IdValue, ResultObj).ToJSON;
                  exit;
               end;
               result := McpJsonRpcError(IdValue, 'resources/list ist nicht registriert.').ToJSON;
               exit;
            end;
            Resources := FOnListResources;
            ResultObj := TJSONObject.Create;
            ResultObj.AddPair('resources', Resources);
            if IsNextProtocol then begin
               ResultObj.AddPair('ttlMs', TJSONNumber.Create(60000));
               ResultObj.AddPair('cacheScope', 'private');
            end;
            result := McpJsonRpcResult(IdValue, ResultObj).ToJSON;
         end
         else if SameText(MethodName, 'resources/read') then begin
            if not Assigned(FOnReadResource) then begin
               result := McpJsonRpcError(IdValue, 'resources/read ist nicht registriert.').ToJSON;
               exit;
            end;
            Uri := McpJsonString(Params, 'uri', '');
            if Uri = '' then begin
               result := McpJsonRpcError(IdValue, 'resources/read benoetigt params.uri.').ToJSON;
               exit;
            end;
            Contents := TJSONArray.Create;
            ReadObj := FOnReadResource(Uri);
            Contents.AddElement(ReadObj);
            ResultObj := TJSONObject.Create;
            ResultObj.AddPair('contents', Contents);
            if IsNextProtocol then begin
               ResultObj.AddPair('ttlMs', TJSONNumber.Create(60000));
               ResultObj.AddPair('cacheScope', 'private');
            end;
            result := McpJsonRpcResult(IdValue, ResultObj).ToJSON;
         end
         else if SameText(MethodName, 'prompts/list') then begin
            if not Assigned(FOnListPrompts) then begin
               if IsNextProtocol then begin
                  ResultObj := TJSONObject.Create;
                  ResultObj.AddPair('prompts', TJSONArray.Create);
                  ResultObj.AddPair('ttlMs', TJSONNumber.Create(60000));
                  ResultObj.AddPair('cacheScope', 'private');
                  result := McpJsonRpcResult(IdValue, ResultObj).ToJSON;
                  exit;
               end;
               result := McpJsonRpcError(IdValue, 'prompts/list ist nicht registriert.').ToJSON;
               exit;
            end;
            Prompts := FOnListPrompts;
            ResultObj := TJSONObject.Create;
            ResultObj.AddPair('prompts', Prompts);
            if IsNextProtocol then begin
               ResultObj.AddPair('ttlMs', TJSONNumber.Create(60000));
               ResultObj.AddPair('cacheScope', 'private');
            end;
            result := McpJsonRpcResult(IdValue, ResultObj).ToJSON;
         end
         else if SameText(MethodName, 'prompts/get') then begin
            if not Assigned(FOnGetPrompt) then begin
               result := McpJsonRpcError(IdValue, 'prompts/get ist nicht registriert.').ToJSON;
               exit;
            end;
            PromptName := McpJsonString(Params, 'name', '');
            if PromptName = '' then begin
               result := McpJsonRpcError(IdValue, 'prompts/get benoetigt params.name.').ToJSON;
               exit;
            end;
            PromptObj := FOnGetPrompt(PromptName);
            Messages := TJSONArray.Create;
            Msg := TJSONObject.Create;
            Msg.AddPair('role', 'user');
            ContentObj := TJSONObject.Create;
            ContentObj.AddPair('type', 'text');
            ContentObj.AddPair('text', PromptObj.Values['text'].Value);
            Msg.AddPair('content', ContentObj);
            Messages.AddElement(Msg);
            PromptObj.Free;
            ResultObj := TJSONObject.Create;
            ResultObj.AddPair('messages', Messages);
            result := McpJsonRpcResult(IdValue, ResultObj).ToJSON;
         end
         else if SameText(MethodName, 'notifications/initialized') then begin
            result := '';
         end
         else begin
            result := McpJsonRpcError(IdValue, 'Nicht unterstuetzte Methode: ' + MethodName).ToJSON;
         end;
      except
         on E: Exception do begin
            result := McpJsonRpcError(IdValue, E.Message).ToJSON;
         end;
      end;
   finally
      Root.Free;
   end;
end;

initialization

finalization
   FreeGlobalMcpServer;

end.

