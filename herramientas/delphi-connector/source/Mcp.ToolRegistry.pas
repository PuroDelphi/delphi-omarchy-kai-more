unit Mcp.ToolRegistry;

interface

uses
   System.SysUtils, System.JSON, System.Generics.Collections, Mcp.Types;

type
   TMcpToolRegistry = class
   private
      FTools: TObjectList<TMcpToolDefinition>;
      function FindTool(const Name: string): TMcpToolDefinition;
   public
      constructor Create;
      destructor Destroy; override;
      procedure Clear;
      procedure RegisterTool(const Name, Description: string; const Required, Properties: array of string;
         Handler: TMcpToolHandler; RunInMainThread: boolean = false; const OwnerId: string = ''); overload;
      procedure RegisterTool(const Name, Description: string; Schema: TJSONObject;
         Handler: TMcpToolHandler; RunInMainThread: boolean = false; const OwnerId: string = ''); overload;
      procedure UnregisterOwner(const OwnerId: string);
      function ListTools: TJSONArray;
      function CallTool(const Name: string; Arguments: TJSONObject): TJSONValue;
      function ToolRunsInMainThread(const Name: string): boolean;
      function ContainsTool(const Name: string): boolean;
   end;

implementation

constructor TMcpToolRegistry.Create;
begin
   inherited Create;
   FTools := TObjectList<TMcpToolDefinition>.Create(true);
end;

destructor TMcpToolRegistry.Destroy;
begin
   FTools.Free;
   inherited Destroy;
end;

procedure TMcpToolRegistry.Clear;
begin
   FTools.Clear;
end;

function TMcpToolRegistry.FindTool(const Name: string): TMcpToolDefinition;
var
   Tool: TMcpToolDefinition;
begin
   result := nil;
   for Tool in FTools do begin
      if SameText(Tool.Name, Name) then begin
         result := Tool;
         exit;
      end;
   end;
end;

procedure TMcpToolRegistry.RegisterTool(const Name, Description: string; const Required, Properties: array of string;
   Handler: TMcpToolHandler; RunInMainThread: boolean = false; const OwnerId: string = '');
begin
   RegisterTool(Name, Description, McpToolSchema(Required, Properties), Handler, RunInMainThread, OwnerId);
end;

procedure TMcpToolRegistry.RegisterTool(const Name, Description: string; Schema: TJSONObject;
   Handler: TMcpToolHandler; RunInMainThread: boolean = false; const OwnerId: string = '');
var
   Existing: TMcpToolDefinition;
begin
   if Name = '' then begin
      raise Exception.Create('MCP tool name darf nicht leer sein.');
   end;
   if not Assigned(Handler) then begin
      raise Exception.CreateFmt('MCP tool "%s" hat keinen Handler.', [Name]);
   end;
   Existing := FindTool(Name);
   if Existing <> nil then begin
      FTools.Remove(Existing);
   end;
   FTools.Add(TMcpToolDefinition.Create(Name, Description, Schema, Handler, RunInMainThread, OwnerId));
end;

procedure TMcpToolRegistry.UnregisterOwner(const OwnerId: string);
var
   i: integer;
begin
   if OwnerId = '' then begin
      exit;
   end;
   for i := FTools.Count - 1 downto 0 do begin
      if SameText(FTools[i].OwnerId, OwnerId) then begin
         FTools.Delete(i);
      end;
   end;
end;

function TMcpToolRegistry.ListTools: TJSONArray;
var
   Tool: TMcpToolDefinition;
begin
   result := TJSONArray.Create;
   for Tool in FTools do begin
      result.AddElement(Tool.ToJson);
   end;
end;

function TMcpToolRegistry.CallTool(const Name: string; Arguments: TJSONObject): TJSONValue;
var
   Tool: TMcpToolDefinition;
begin
   Tool := FindTool(Name);
   if Tool = nil then begin
      raise Exception.CreateFmt('Unbekanntes MCP tool: %s', [Name]);
   end;
   result := Tool.Handler(Arguments);
end;

function TMcpToolRegistry.ToolRunsInMainThread(const Name: string): boolean;
var
   Tool: TMcpToolDefinition;
begin
   Tool := FindTool(Name);
   result := (Tool <> nil) and Tool.RunInMainThread;
end;

function TMcpToolRegistry.ContainsTool(const Name: string): boolean;
begin
   result := FindTool(Name) <> nil;
end;

end.
