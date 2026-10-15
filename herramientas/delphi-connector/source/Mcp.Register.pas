unit Mcp.Register;

interface

procedure Register;

implementation

uses
   System.Classes, Mcp.FormBridge, Mcp.IdeBridge;

{$R Mcp.Register.dcr}

procedure Register;
begin
   RegisterComponents('MCP2Delphi', [TMcpFormBridge]);
   RegisterIdeMcpBridge;
end;

end.
