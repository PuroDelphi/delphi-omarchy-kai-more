unit Mcp.Types;

interface

uses
   System.SysUtils, System.JSON;

type
   TMcpToolHandler = function(const Arguments: TJSONObject): TJSONValue of object;

   TMcpToolDefinition = class
   private
      FName: string;
      FDescription: string;
      FInputSchema: TJSONObject;
      FHandler: TMcpToolHandler;
      FRunInMainThread: boolean;
      FOwnerId: string;
   public
      constructor Create(const AName, ADescription: string; AInputSchema: TJSONObject;
         AHandler: TMcpToolHandler; ARunInMainThread: boolean = false; const AOwnerId: string = '');
      destructor Destroy; override;
      function ToJson: TJSONObject;
      property Name: string read FName;
      property OwnerId: string read FOwnerId;
      property Handler: TMcpToolHandler read FHandler;
      property RunInMainThread: boolean read FRunInMainThread write FRunInMainThread;
   end;

function McpCloneJson(const Value: TJSONValue): TJSONValue;
function McpBoolValue(const Value: boolean): TJSONValue;
function McpJsonString(const Obj: TJSONObject; const Name, Default: string): string;
function McpJsonBool(const Obj: TJSONObject; const Name: string; const Default: boolean): boolean;
function McpJsonNumber(const Obj: TJSONObject; const Name: string; const Default: double): double;
function McpPropertySchema(const Name: string): TJSONObject;
function McpToolSchema(const Required, Properties: array of string): TJSONObject;
function McpTextContentResult(const Value: TJSONValue): TJSONObject;

implementation

function McpCloneJson(const Value: TJSONValue): TJSONValue;
begin
   if Value = nil then begin
      result := TJSONNull.Create;
   end
   else begin
      result := TJSONObject.ParseJSONValue(Value.ToJSON);
   end;
end;

function McpBoolValue(const Value: boolean): TJSONValue;
begin
   if Value then begin
      result := TJSONTrue.Create;
   end
   else begin
      result := TJSONFalse.Create;
   end;
end;

function McpJsonString(const Obj: TJSONObject; const Name, Default: string): string;
var
   Value: TJSONValue;
begin
   result := Default;
   if Obj = nil then begin
      exit;
   end;
   Value := Obj.Values[Name];
   if Value <> nil then begin
      result := Value.Value;
   end;
end;

function McpJsonBool(const Obj: TJSONObject; const Name: string; const Default: boolean): boolean;
var
   Value: TJSONValue;
begin
   result := Default;
   if Obj = nil then begin
      exit;
   end;
   Value := Obj.Values[Name];
   if Value <> nil then begin
      result := SameText(Value.Value, 'true');
   end;
end;

function McpJsonNumber(const Obj: TJSONObject; const Name: string; const Default: double): double;
var
   Value: TJSONValue;
   Fmt: TFormatSettings;
begin
   result := Default;
   if Obj = nil then begin
      exit;
   end;
   Value := Obj.Values[Name];
   if Value = nil then begin
      exit;
   end;
   Fmt := TFormatSettings.Create;
   Fmt.DecimalSeparator := '.';
   Fmt.ThousandSeparator := ',';
   if not TryStrToFloat(Trim(Value.Value), result, Fmt) then begin
      result := StrToFloatDef(StringReplace(Value.Value, '.', FormatSettings.DecimalSeparator, []), Default);
   end;
end;

function McpPropertySchema(const Name: string): TJSONObject;
begin
   if SameText(Name, 'names') or SameText(Name, 'items') or SameText(Name, 'channels') then begin
      result := TJSONObject.Create.AddPair('type', 'array');
   end
   else if SameText(Name, 'limit') or SameText(Name, 'count') or SameText(Name, 'line') then begin
      result := TJSONObject.Create.AddPair('type', 'integer');
   end
   else if SameText(Name, 'includeValues') or SameText(Name, 'includeScript') or SameText(Name, 'includeLog') then begin
      result := TJSONObject.Create.AddPair('type', 'boolean');
   end
   else if SameText(Name, 'centerNm') or SameText(Name, 'widthNm') or SameText(Name, 'dicke') then begin
      result := TJSONObject.Create.AddPair('type', 'number');
   end
   else if SameText(Name, 'arguments') or SameText(Name, 'stack') or SameText(Name, 'options') then begin
      result := TJSONObject.Create.AddPair('type', 'object');
   end
   else begin
      result := TJSONObject.Create.AddPair('type', 'string');
   end;
end;

function McpToolSchema(const Required, Properties: array of string): TJSONObject;
var
   Props: TJSONObject;
   RequiredArray: TJSONArray;
   S: string;
begin
   result := TJSONObject.Create;
   result.AddPair('type', 'object');
   Props := TJSONObject.Create;
   for S in Properties do begin
      Props.AddPair(S, McpPropertySchema(S));
   end;
   result.AddPair('properties', Props);
   RequiredArray := TJSONArray.Create;
   for S in Required do begin
      RequiredArray.Add(S);
   end;
   result.AddPair('required', RequiredArray);
end;

function McpTextContentResult(const Value: TJSONValue): TJSONObject;
var
   Content: TJSONArray;
   Item: TJSONObject;
begin
   result := TJSONObject.Create;
   Content := TJSONArray.Create;
   Item := TJSONObject.Create;
   Item.AddPair('type', 'text');
   if Value <> nil then begin
      Item.AddPair('text', Value.ToJSON);
   end
   else begin
      Item.AddPair('text', '{}');
   end;
   Content.AddElement(Item);
   result.AddPair('content', Content);
end;

constructor TMcpToolDefinition.Create(const AName, ADescription: string; AInputSchema: TJSONObject;
   AHandler: TMcpToolHandler; ARunInMainThread: boolean = false; const AOwnerId: string = '');
begin
   inherited Create;
   FName := AName;
   FDescription := ADescription;
   FInputSchema := AInputSchema;
   FHandler := AHandler;
   FRunInMainThread := ARunInMainThread;
   FOwnerId := AOwnerId;
end;

destructor TMcpToolDefinition.Destroy;
begin
   FInputSchema.Free;
   inherited Destroy;
end;

function TMcpToolDefinition.ToJson: TJSONObject;
begin
   result := TJSONObject.Create;
   result.AddPair('name', FName);
   result.AddPair('description', FDescription);
   result.AddPair('inputSchema', McpCloneJson(FInputSchema));
end;

end.
