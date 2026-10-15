unit Mcp.VclBridge;

interface

uses
   System.SysUtils, System.Classes, System.SyncObjs, System.JSON;

type
   TMcpMainThreadFunc = reference to function: TJSONValue;

   TMcpVclBridge = class(TComponent)
   private
      FTimeoutMs: Cardinal;
   public
      constructor Create(AOwner: TComponent); override;
      function ExecuteOnMainThread(const ToolName: string; Func: TMcpMainThreadFunc): TJSONValue;
   published
      property TimeoutMs: Cardinal read FTimeoutMs write FTimeoutMs default 30000;
   end;

implementation

constructor TMcpVclBridge.Create(AOwner: TComponent);
begin
   inherited Create(AOwner);
   FTimeoutMs := 30000;
end;

function TMcpVclBridge.ExecuteOnMainThread(const ToolName: string; Func: TMcpMainThreadFunc): TJSONValue;
var
   Done: TEvent;
   ToolResult: TJSONValue;
   ErrorText: string;
begin
   if not Assigned(Func) then begin
      raise Exception.CreateFmt('MCP tool "%s" hat keinen Handler.', [ToolName]);
   end;

   ToolResult := nil;
   ErrorText := '';
   Done := TEvent.Create(nil, true, false, '');
   try
      TThread.Queue(nil,
         procedure
         begin
            try
               ToolResult := Func;
            except
               on E: Exception do begin
                  ErrorText := E.Message;
               end;
            end;
            Done.SetEvent;
         end);
      if Done.WaitFor(FTimeoutMs) <> wrSignaled then begin
         raise Exception.CreateFmt('Timeout beim Aufruf des MCP UI tools "%s".', [ToolName]);
      end;
   finally
      Done.Free;
   end;

   if ErrorText <> '' then begin
      raise Exception.Create(ErrorText);
   end;
   result := ToolResult;
end;

end.
