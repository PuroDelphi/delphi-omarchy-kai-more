program HolaMundo;

uses
  System.StartUpCopy,
  FMX.Forms,
  HolaMundo.Main in 'HolaMundo.Main.pas' {frmHolaMundo};

begin
  Application.Initialize;
  Application.CreateForm(TfrmHolaMundo, frmHolaMundo);
  Application.Run;
end.
