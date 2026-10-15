unit Mcp.JsonRpc;

interface

uses
   System.SysUtils, System.JSON, Mcp.Types;

function McpJsonRpcResult(const Id: TJSONValue; const ResultValue: TJSONValue): TJSONObject;
function McpJsonRpcError(const Id: TJSONValue; const MessageText: string; const Code: integer = -32000): TJSONObject;
function McpJsonRpcMethod(const Request: TJSONObject): string;
function McpJsonRpcParams(const Request: TJSONObject): TJSONObject;

implementation

function McpJsonRpcResult(const Id: TJSONValue; const ResultValue: TJSONValue): TJSONObject;
begin
   result := TJSONObject.Create;
   result.AddPair('jsonrpc', '2.0');
   result.AddPair('id', McpCloneJson(Id));
   result.AddPair('result', ResultValue);
end;

function McpJsonRpcError(const Id: TJSONValue; const MessageText: string; const Code: integer = -32000): TJSONObject;
var
   ErrorObj: TJSONObject;
begin
   result := TJSONObject.Create;
   result.AddPair('jsonrpc', '2.0');
   if Id <> nil then begin
      result.AddPair('id', McpCloneJson(Id));
   end
   else begin
      result.AddPair('id', TJSONNull.Create);
   end;
   ErrorObj := TJSONObject.Create;
   ErrorObj.AddPair('code', TJSONNumber.Create(Code));
   ErrorObj.AddPair('message', MessageText);
   result.AddPair('error', ErrorObj);
end;

function McpJsonRpcMethod(const Request: TJSONObject): string;
begin
   result := McpJsonString(Request, 'method', '');
end;

function McpJsonRpcParams(const Request: TJSONObject): TJSONObject;
begin
   result := nil;
   if (Request <> nil) and (Request.Values['params'] is TJSONObject) then begin
      result := TJSONObject(Request.Values['params']);
   end;
end;

end.
