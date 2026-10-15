# Hola mundo con FireMonkey

Segundo proyecto de la conferencia: una ventana con un botón que muestra el mensaje «Hola mundo» al pulsarlo.

Abre `HolaMundo.dproj` en Delphi, selecciona Windows Win32 y pulsa F9. El formulario está en `HolaMundo.Main.fmx` y puede editarse con el diseñador visual. El evento `btnHolaMundoClick` de `HolaMundo.Main.pas` contiene la llamada a `ShowMessage`.

La copia de trabajo de Windows está en `Z:\HolaMundoFMX\HolaMundo.dproj`. La salida de compilación es `Win32\Debug\HolaMundo.exe`. Utiliza únicamente componentes estándar de FMX y no requiere MCPConnect.
