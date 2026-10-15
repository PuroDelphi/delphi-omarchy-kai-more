unit HolaMundo.Main;

interface

uses
  System.SysUtils, System.Classes, FMX.Types, FMX.Controls, FMX.Forms,
  FMX.StdCtrls, FMX.Controls.Presentation, FMX.Dialogs;

type
  TfrmHolaMundo = class(TForm)
    btnHolaMundo: TButton;
    procedure btnHolaMundoClick(Sender: TObject);
  end;

var
  frmHolaMundo: TfrmHolaMundo;

implementation

{$R *.fmx}

procedure TfrmHolaMundo.btnHolaMundoClick(Sender: TObject);
begin
  ShowMessage('Hola mundo');
end;

end.
