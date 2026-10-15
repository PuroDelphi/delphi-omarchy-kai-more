program CiudadViva;

uses
  System.StartUpCopy,
  FMX.Forms,
  CiudadViva.Main in 'CiudadViva.Main.pas',
  CiudadViva.Model in 'CiudadViva.Model.pas';

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
