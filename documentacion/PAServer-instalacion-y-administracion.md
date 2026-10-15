# PAServer, SDK de Linux y control externo de Delphi desde Omarchy

PAServer permite que Delphi, instalado en la máquina virtual Windows, despliegue y depure aplicaciones en Linux. En este equipo se ejecuta como servicio del usuario `macondo`, con contraseña y acceso desde la red interna de Docker.

Esta guía reproduce la instalación de PAServer 37, la configuración del SDK de Linux en Delphi y los comandos para administrar el servicio. Incluye las correcciones con las que se consiguió compilar el ejemplo en este equipo. La instalación ya está realizada: para iniciar o detener PAServer, usa directamente la sección de administración. Repetir la instalación sobrescribiría la configuración y la contraseña.

El apartado **Controlar Delphi desde esta conversación** explica además la conexión independiente de Kai que permite al asistente consultar y enviar instrucciones al IDE de Windows desde Omarchy. Incluye los archivos utilizados, su instalación, su uso diario y las consideraciones para compartir la adaptación con la comunidad.

Omarchy está basado en Arch Linux. Esta preparación adapta sus rutas de bibliotecas al SDK de Delphi; Omarchy no figura entre los destinos Linux oficialmente soportados por Embarcadero. Para un entorno basado en una distribución soportada, consulta Ubuntu 22 o 24 en la documentación de plataformas al final de la guía.

## Configuración del equipo

| Elemento | Valor |
| --- | --- |
| Usuario de Omarchy | `macondo` |
| Origen descargado | `~/Downloads/PAServer/LinuxPAServer37.0/PAServer-37.0` |
| Instalación | `~/.local/share/paserver/37.0` |
| Configuración privada | `~/.config/paserver/paserver.config` |
| Archivos de despliegue | `~/PAServer/scratch-dir` |
| Servicio de usuario | `paserver.service` |
| Dirección para Delphi en Windows | `172.18.0.1` |
| Puerto TCP | `64211` |
| SDK local en Windows | `C:\Users\macondo\Documents\Embarcadero\Studio\SDKs\omarchy4.0.4.sdk` |
| Bibliotecas de GCC en este equipo | `/usr/lib/gcc/x86_64-pc-linux-gnu/16` |

Los ejemplos usan Bash, Python 3 y systemd. Ejecuta los pasos de instalación desde una terminal de tu sesión de Omarchy, sin `sudo`, salvo los comandos indicados para el firewall y el enlace de biblioteca.

## Comprobar el ejecutable y sus dependencias

```bash
file ~/Downloads/PAServer/LinuxPAServer37.0/PAServer-37.0/paserver

ldd ~/Downloads/PAServer/LinuxPAServer37.0/PAServer-37.0/paserver

~/Downloads/PAServer/LinuxPAServer37.0/PAServer-37.0/paserver -help

~/Downloads/PAServer/LinuxPAServer37.0/PAServer-37.0/lldb/bin/lldb --version
```

En la instalación de este equipo, el servidor y el depurador incluidos pudieron ejecutarse. Si `ldd` muestra `not found` en otro equipo, hay que resolver esas dependencias antes de continuar.

## Copiar PAServer fuera de Descargas

```bash
install -d -m 0700 ~/.local/share/paserver
install -d -m 0700 ~/.config/paserver
install -d -m 0700 ~/PAServer/scratch-dir
mkdir -p ~/.config/systemd/user

cp -a ~/Downloads/PAServer/LinuxPAServer37.0/PAServer-37.0 \
      ~/.local/share/paserver/37.0
```

La copia supone que `~/.local/share/paserver/37.0` todavía no existe. El servidor queda separado de Descargas para que limpiar esa carpeta no elimine la instalación.

## Configurar el puerto y la contraseña

Introduce la contraseña sin mostrarla en pantalla ni escribirla en el historial de comandos:

```bash
read -r -s -p "Contraseña para PAServer: " PASERVER_PASSWORD
printf '\n'

(
  umask 077
  printf 'port=64211\nscratchdir=%s/PAServer/scratch-dir\npassword=%s\n' \
    "$HOME" "$PASERVER_PASSWORD" \
    > ~/.config/paserver/paserver.config
)

unset PASERVER_PASSWORD
chmod 600 ~/.config/paserver/paserver.config
```

La contraseña se guarda en el archivo de configuración, legible únicamente por el usuario. En una conferencia, utiliza una contraseña de demostración y evita mostrar el contenido del archivo real.

## Crear el lanzador para systemd

PAServer tiene una consola interactiva. Durante la instalación comprobamos que, con la entrada estándar cerrada, repetía su indicador de consola y consumía CPU. Este lanzador mantiene abierta la entrada mientras systemd administra el proceso.

```bash
cat > ~/.local/share/paserver/run.py <<'PY'
#!/usr/bin/python3
import subprocess
import sys
from pathlib import Path

home = Path.home()

with subprocess.Popen([
    str(home / ".local/share/paserver/37.0/paserver"),
    "-config=" + str(home / ".config/paserver/paserver.config"),
], stdin=subprocess.PIPE) as server:
    sys.exit(server.wait())
PY

chmod 700 ~/.local/share/paserver/run.py
```

## Crear y activar el servicio

```bash
cat > ~/.config/systemd/user/paserver.service <<'EOF'
[Unit]
Description=Embarcadero PAServer 37 for Delphi Linux development
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
WorkingDirectory=%h/.local/share/paserver/37.0
ExecStart=/usr/bin/python3 %h/.local/share/paserver/run.py
Restart=on-failure
RestartSec=5
UMask=0077

[Install]
WantedBy=graphical-session.target
EOF

systemd-analyze --user verify ~/.config/systemd/user/paserver.service
systemctl --user daemon-reload
systemctl --user enable --now paserver
systemctl --user status paserver --no-pager
```

`%h` representa el directorio personal del usuario. El servicio arranca al iniciar la sesión gráfica de Omarchy y se detiene cuando esa sesión se cierra. PAServer funciona con los permisos del usuario y dispone del entorno gráfico de su sesión para las aplicaciones que despliegue.

Si ya abriste PAServer manualmente, cierra esas instancias antes de iniciar el servicio para evitar que varias usen el mismo puerto. En este equipo se cerraron dos instancias duplicadas de Descargas durante la instalación.

## Permitir la conexión desde Windows

Windows usa una red virtual con NAT. La dirección `172.18.0.1` es la del equipo Omarchy en el puente Docker de esta máquina.

Para identificar la interfaz y las direcciones:

```bash
ip -4 -br addr
ip -4 route

sudo docker inspect \
  --format '{{range .NetworkSettings.Networks}}{{.Gateway}} {{.IPAddress}}{{end}}' \
  omarchy-windows
```

La regla instalada en este equipo permite el puerto únicamente desde la red interna de Windows:

```bash
sudo ufw allow from 172.18.0.0/16 \
  to 172.18.0.1 \
  port 64211 proto tcp \
  comment "Delphi Windows to PAServer"

sudo ufw status
```

La regla usa las direcciones internas y no el nombre de una interfaz `br-...`: el ciclo de cierre y arranque de Windows puede recrear la red Docker y cambiar ese nombre. Si cambia la subred o la dirección del puente, actualiza la regla y el perfil de Delphi. Esta regla se aplica a UFW cuando está activo; no es necesario abrir el puerto en el router.

## Configurar Delphi

En Delphi abre **Tools → Options → Deployment → Connection Profile Manager** y crea un perfil:

| Campo | Valor |
| --- | --- |
| Nombre | `Omarchy Linux` |
| Plataforma | Linux de 64 bits |
| Host | `172.18.0.1` |
| Puerto | `64211` |
| Contraseña | La configurada en PAServer |

Pulsa **Test Connection**. Después agrega o importa el SDK de Linux desde **SDK Manager**.

Los datos reales de conexión de este equipo se guardaron en `~/Windows/PAServer-Omarchy.txt`, dentro de la carpeta compartida con Windows. Si cambias la contraseña del servidor, actualiza también el perfil de Delphi y ese archivo.

## Preparar las bibliotecas de Omarchy para el SDK

PAServer funcionando y **Test Connection** correcto confirman la conexión. Para compilar, Delphi necesita además una copia local de las bibliotecas de Linux en Windows. El enlazador consulta esa copia del SDK, no directamente los archivos de Omarchy.

### Comprobar y añadir el nombre de enlace de libgcc

En este equipo existía `/usr/lib/libgcc_s.so.1`, pero faltaba `/usr/lib/libgcc_s.so`. El archivo de desarrollo de GCC estaba en una ruta privada del compilador. Al enlazar con `-lgcc_s`, Delphi necesita encontrar el nombre `libgcc_s.so` en las rutas de su SDK.

Comprueba los archivos desde Omarchy:

```bash
ls -l /usr/lib/libgcc_s.so*
ls -l /usr/lib/gcc/x86_64-pc-linux-gnu/16/libgcc_s.so
```

Este fue el enlace añadido, sin sustituir archivos existentes:

```bash
if [[ -f /usr/lib/libgcc_s.so.1 ]] && \
   [[ ! -e /usr/lib/libgcc_s.so && ! -L /usr/lib/libgcc_s.so ]]; then
  sudo ln -s libgcc_s.so.1 /usr/lib/libgcc_s.so
fi

ls -l /usr/lib/libgcc_s.so
```

El resultado esperado es:

```text
/usr/lib/libgcc_s.so -> libgcc_s.so.1
```

Esta modificación en Linux debe ir acompañada de una actualización del SDK en Delphi. El enlace por sí solo no actualiza la copia de Windows.

### Comprobar los archivos de desarrollo de glibc

```bash
ls -l /usr/lib/libc_nonshared.a
ls -l /usr/lib/libc.so.6
ls -l /usr/lib/ld-linux-x86-64.so.2
cat /usr/lib/libc.so
```

En este sistema `libc.so` es un script del enlazador y contiene:

```text
GROUP ( /usr/lib/libc.so.6 /usr/lib/libc_nonshared.a  AS_NEEDED ( /usr/lib/ld-linux-x86-64.so.2 ) )
```

El SDK debe incluir también los archivos que referencia ese script, conservando sus rutas. No es necesario editar `libc.so` ni eliminar sus referencias.

## Configurar las rutas del SDK en Delphi

Abre **Tools → Options → Deployment → SDK Manager**, selecciona el SDK de Linux de Omarchy y revisa sus rutas remotas. Conserva las entradas existentes de encabezados y añade estas entradas de tipo **Library**, sin incluir subdirectorios:

| Ruta remota | Máscara | Contenido |
| --- | --- | --- |
| `/usr/lib` | `*.so*` | Bibliotecas compartidas, scripts de enlace y cargador dinámico |
| `/usr/lib` | `*.a` | Bibliotecas estáticas, incluida `libc_nonshared.a` |
| `/usr/lib` | `*.o` | Archivos objeto de arranque, como `crt1.o`, `crti.o` y `crtn.o` |
| `/usr/lib/gcc/x86_64-pc-linux-gnu/16` | `*` | Archivos de desarrollo de la versión instalada de GCC |

La máscara `lib*.so*` es insuficiente: no incluye las bibliotecas `.a`, los objetos `.o` ni `ld-linux-x86-64.so.2`. La entrada `*.so*` incluye también ese cargador.

La ruta de GCC corresponde a este equipo. Para localizarla en otro sistema o después de actualizar GCC:

```bash
gcc -print-file-name=libgcc_s.so
```

Después de configurar las entradas:

1. Pulsa **Update Local File Cache**.
2. Selecciona el perfil de conexión de Omarchy y deja terminar la transferencia.
3. Revisa los archivos importados en la carpeta local del SDK.
4. Compila nuevamente el proyecto con destino **Linux 64-bit**.

Actualizar la caché solo copia los archivos de las rutas y máscaras configuradas. Si una máscara omite un tipo de archivo, repetir la actualización no lo incorpora.

### Verificar los archivos en Windows

En este equipo la raíz del SDK es:

```text
C:\Users\macondo\Documents\Embarcadero\Studio\SDKs\omarchy4.0.4.sdk
```

Desde PowerShell puedes comprobar los archivos principales:

```powershell
$sdkRoot = Join-Path $env:USERPROFILE 'Documents\Embarcadero\Studio\SDKs\omarchy4.0.4.sdk'

'usr\lib\libgcc_s.so',
'usr\lib\libgcc_s.so.1',
'usr\lib\libc_nonshared.a',
'usr\lib\libc.so.6',
'usr\lib\ld-linux-x86-64.so.2' | ForEach-Object {
    $file = Join-Path $sdkRoot $_
    [PSCustomObject]@{ Archivo = $file; Existe = Test-Path -LiteralPath $file }
}
```

Aunque `libc.so` se haya importado en `usr\lib64`, su referencia absoluta a `/usr/lib/libc_nonshared.a` requiere que este último archivo esté dentro de `usr\lib` en la raíz del SDK. Copiarlo únicamente a `usr\lib64` no resuelve esa referencia.

## Errores de compilación resueltos

| Error | Causa identificada | Solución aplicada |
| --- | --- | --- |
| `E2597: unable to find library -lgcc_s` | Faltaba el nombre de enlace en `/usr/lib` y era necesario importar las rutas correctas al SDK de Windows | Añadir `libgcc_s.so → libgcc_s.so.1`, configurar las entradas **Library** y actualizar la caché |
| `libc.so:5: cannot find /usr/lib/libc_nonshared.a inside ...omarchy4.0.4.sdk` | El SDK no había importado los archivos estáticos de `/usr/lib` | Añadir `/usr/lib` con máscara `*.a` y actualizar la caché, conservando la ruta `usr\lib` |

Tras completar estas correcciones, el ejemplo compiló correctamente. Las dependencias adicionales de cada aplicación, como bibliotecas de interfaz gráfica o bases de datos, dependen del proyecto.

### Rutas de salida del ejemplo PDFCanvas

Otro proyecto produjo `E2597: cannot open \\Lib\\37.0\\Debug\\PDFCanvas.o: no such file or directory`. Su línea de compilación incluía `-NU\Lib\37.0\Debug` y `-NO\Lib\37.0\Debug`, además de avisos por directorios inexistentes `\Source` y `\Source\37.0`.

La barra inicial hace que esas rutas partan de la raíz de la unidad de Windows, en vez de la carpeta del proyecto. El problema se resolvió corrigiendo las rutas del proyecto. Para una compilación Linux64 Debug, una salida relativa como `.\Linux64\Debug` permite mantener los archivos generados junto al proyecto. Revisa las opciones que producen `-NU` y `-NO` y crea o selecciona un directorio válido y escribible. Los directorios de código fuente deben apuntar a las carpetas reales de la biblioteca usada por el ejemplo, sin conservar entradas `\Source` inexistentes.

Este error corresponde a las rutas de archivos objeto del proyecto en Windows; no requiere copiar otra biblioteca de Linux al SDK ni modificar PAServer.

## Administrar PAServer

Estos comandos se ejecutan en Omarchy, sin `sudo`:

```bash
# Iniciar
systemctl --user start paserver

# Detener
systemctl --user stop paserver

# Reiniciar y aplicar cambios de contraseña o configuración
systemctl --user restart paserver

# Consultar el estado
systemctl --user status paserver --no-pager

# Ver registros recientes
journalctl --user -u paserver -n 30 --no-pager

# Seguir los registros en tiempo real; salir con Ctrl+C
journalctl --user -u paserver -f
```

Para controlar el inicio automático:

```bash
# Desactivar el inicio automático, sin detener el proceso actual
systemctl --user disable paserver

# Desactivar el inicio automático y detenerlo ahora
systemctl --user disable --now paserver

# Activar el inicio automático y arrancarlo ahora
systemctl --user enable --now paserver

# Consultar si está habilitado
systemctl --user is-enabled paserver

# Consultar si está ejecutándose
systemctl --user is-active paserver
```

Tras modificar el archivo `paserver.service`, recarga systemd y reinicia:

```bash
systemctl --user daemon-reload
systemctl --user restart paserver
```

## Verificar la conexión y diagnosticar problemas

Comprueba el puerto y el consumo del servidor:

```bash
ss -ltn | grep 64211
ps -C paserver -o pid,%cpu,etime,comm
```

Desde PowerShell dentro de Windows:

```powershell
Test-NetConnection -ComputerName 172.18.0.1 -Port 64211
```

`TcpTestSucceeded: True` confirma conectividad TCP. **Test Connection** en Delphi comprueba además la comunicación con PAServer y la contraseña.

Si falla la conexión, verifica que el servicio esté activo, que el perfil tenga la dirección y contraseña correctas y que la regla de UFW coincida con la red Docker actual. Si el servicio no inicia, consulta sus registros y comprueba que no haya otra instancia utilizando el puerto.

## Secuencia para la demostración en conferencia

1. Mostrar dónde se instaló PAServer y explicar su carpeta de trabajo.
2. Iniciar el servicio y consultar su estado con `systemctl --user`.
3. Probar la conexión desde Delphi al puerto `64211`.
4. Mostrar el enlace `libgcc_s.so` y el contenido de `libc.so` en Omarchy.
5. Mostrar las cuatro entradas **Library** en SDK Manager y explicar las máscaras `.so`, `.a` y `.o`.
6. Actualizar la caché local y verificar `usr\lib\libc_nonshared.a` en Windows.
7. Compilar y ejecutar el ejemplo con destino Linux.
8. Detener PAServer al terminar con `systemctl --user stop paserver`.

La distinción clave de la demostración es que PAServer atiende la conexión, el despliegue y la depuración en Linux, mientras Delphi compila y enlaza en Windows usando su copia local del SDK de Linux.

## Controlar Delphi desde esta conversación

La conexión permite que el asistente de esta conversación, ejecutado en Omarchy, envíe instrucciones al Delphi instalado en la máquina virtual Windows. **No utiliza Kai, ACP, los agentes Codex u OpenCode configurados dentro de Kai, ni MCPConnect.** Kai puede seguir instalado, pero no interviene en este recorrido.

Usamos [MCP2Delphi, de Thomas Bornhaupt](https://github.com/ThomasBornhaupt/MCP2Delphi), y preparamos un paquete de instalación y un puente de archivos para este equipo. MCP significa *Model Context Protocol*: permite describir herramientas y solicitar su ejecución mediante mensajes estructurados. El código del conector no contiene un modelo de IA; el asistente decide qué operación solicitar y el conector la ejecuta dentro del IDE.

### Qué hace cada componente

| Componente | Función en esta conexión |
| --- | --- |
| Asistente en Omarchy | Interpreta la petición y prepara llamadas a las herramientas del IDE |
| `client.py` | Escribe una solicitud JSON y espera la respuesta en la carpeta compartida |
| `relay.cjs` y Node.js en Windows | Reciben la solicitud, añaden el token local y llaman al servidor del IDE |
| `OmarchyIDEConnector.bpl` dentro de Delphi | Expone las herramientas mediante MCP y accede al IDE usando ToolsAPI |
| PAServer en Omarchy | Permite desplegar y depurar aplicaciones con destino Linux cuando Delphi usa ese perfil |

El recorrido de una instrucción es:

```text
Asistente en Omarchy
  → client.py
  → carpeta compartida: request.json
  → relay.cjs en Windows
  → HTTP autenticado a 127.0.0.1:8776/mcp dentro de Windows
  → OmarchyIDEConnector.bpl
  → ToolsAPI de Delphi

La respuesta regresa por relay.cjs → response.json → client.py.
```

`127.0.0.1` corresponde aquí al Windows invitado. No se abrió ese puerto en la red local ni se publicó a través de Docker. El servidor puede elegir otro puerto libre entre `8776` y `8786`; el puente lee su información de descubrimiento para localizarlo.

El puente utiliza la carpeta `~/Windows/Delphi-Connector` de Omarchy, visible como `Z:\Delphi-Connector` dentro de Windows. No hay un servidor de red adicional en el puente. En esta conversación las llamadas se realizan con el cliente Python y las herramientas de ejecución disponibles; no se registró automáticamente un servidor MCP nuevo en la configuración de todos los clientes Codex.

### Qué descargamos de Git y qué adaptamos

Se descargó MCP2Delphi en la revisión `e19680c37fba49a04311db7411147401cd018ba4`. Las unidades `Mcp.Server.pas`, `Mcp.JsonRpc.pas`, `Mcp.ToolRegistry.pas` y `Mcp.Types.pas` implementan el servidor HTTP, los mensajes JSON-RPC y el registro de herramientas. `Mcp.IdeBridge.pas` implementa el acceso al IDE mediante ToolsAPI y otras funciones de inspección de Windows y VCL. El proyecto original también incluye infraestructura para exponer aplicaciones VCL.

Para esta instalación conservamos las unidades originales y su licencia, y añadimos:

- `source/OmarchyIDEConnector.dpk`: reúne las unidades en un único paquete de diseño, con las dependencias de Delphi e Indy.
- `Instalar-Conector.ps1`: copia los fuentes al disco local de Windows, compila con `dcc32.exe`, respalda el registro y registra el paquete si la compilación termina correctamente.
- `Iniciar-Conector.ps1` y `relay.cjs`: arrancan el puente y comprueban la comunicación autenticada con el IDE.
- `client.py`: permite enviar solicitudes desde Linux y evita que dos llamadas del cliente escriban simultáneamente en el mismo buzón.
- `Desinstalar-Conector.ps1`: retira la entrada del paquete del registro de Delphi, conservando los archivos y el respaldo.

El servidor genera un token y lo guarda bajo `%LOCALAPPDATA%\MCP2Delphi\Servers`. El puente lo lee dentro de Windows y lo añade a la cabecera `X-MCP2Delphi-Token`; no necesita copiar ese token a la carpeta compartida.

### Para qué sirve y qué comprobamos

El conector instalado anunció **51 herramientas**. Entre ellas están:

| Objetivo | Herramientas de ejemplo |
| --- | --- |
| Comprobar la conexión y consultar proyectos | `ide_ping`, `ide_status`, `ide_get_active_project`, `ide_list_projects` |
| Abrir archivos o proyectos y guardar | `ide_open_file`, `ide_set_active_project`, `ide_save_all` |
| Solicitar compilación y consultar diagnósticos | `ide_build_project`, `ide_get_build_messages`, `ide_get_diagnostics` |
| Ejecutar y operar el depurador | `ide_run_program`, `ide_stop`, `ide_step_over`, `ide_add_source_breakpoint` |
| Inspeccionar el IDE | `ide_list_windows`, `ide_list_vcl_forms`, `ide_inspect_vcl_control` |

La compilación del paquete y una llamada real a `ide_status`, enviada desde Linux a través del puente, funcionaron en este equipo. La respuesta confirmó que el servidor estaba activo y que no había proyecto ni módulo abiertos. Esto comprueba la comunicación de extremo a extremo; las 51 herramientas anunciadas no equivalen a 51 operaciones probadas. Algunas funciones de depuración del proyecto original tienen limitaciones según las interfaces disponibles en Delphi.

Para preparar una aplicación de conferencia, el asistente puede generar los archivos del proyecto en una carpeta compartida, pedir al IDE que abra el proyecto y solicitar la compilación. Los archivos deben tener una ruta válida dentro de Windows. Esta adaptación no incorpora una herramienta específica equivalente a `Kai_applyEdit`: la creación y modificación de código se puede hacer sobre archivos compartidos, coordinando el cierre y la reapertura de los módulos para conservar los cambios sin guardar del IDE.

PAServer sigue teniendo una función distinta: si el proyecto se compila para Linux, Delphi usa el SDK de Linux y su perfil de PAServer para desplegar y depurar en Omarchy. El conector controla Delphi; PAServer atiende el destino Linux.

### Instalar el conector una sola vez

Esta instalación se comprobó con Delphi 37.0 y su IDE de 32 bits. Requiere el compilador Win32, las unidades y paquetes de diseño de Delphi, Node.js en Windows y Python 3 en Linux. Las rutas del instalador y del cliente corresponden a este equipo.

Los archivos de la adaptación están en:

```text
Omarchy: /home/macondo/Work/delphi-omarchy-kai-more/herramientas/delphi-connector
Carpeta compartida: /home/macondo/Windows/Delphi-Connector
Windows: Z:\Delphi-Connector
```

Con los archivos completos en la carpeta compartida, ejecuta en PowerShell de Windows, con el usuario habitual de Delphi:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "Z:\Delphi-Connector\Instalar-Conector.ps1"
```

El instalador usa el compilador de `C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc32.exe`. Copia y compila localmente en `%LOCALAPPDATA%\OmarchyIDEConnector\<fecha-hora>`, de modo que Delphi carga el paquete desde su disco local.

Después de compilar, exporta un respaldo de `HKCU\Software\Embarcadero\BDS\37.0\Known Packages` a `Known-Packages.reg` dentro de esa instalación y agrega la ruta de `OmarchyIDEConnector.bpl` a esa clave. Si la compilación falla, no registra el paquete.

Cuando aparezca el mensaje de instalación correcta:

1. Guarda tus proyectos y cierra Delphi.
2. Abre Delphi nuevamente para cargar el paquete.
3. Regresa al PowerShell del instalador y pulsa Enter.
4. Deja la ventana abierta mientras se use la conexión.

El puente solicita `tools/list`, guarda el resultado en `herramientas.json` y consulta `ide_status`, cuya respuesta deja en `consulta-ide.json`. `estado.json` indica si el puente quedó listo. El registro del instalador es `instalacion.log`.

La instalación ya está hecha en este equipo. No repitas el instalador para iniciar cada sesión: cada ejecución crea una carpeta nueva y puede dejar varias entradas del paquete registradas.

### Iniciar y detener la conexión en el uso diario

Abre Delphi y ejecuta en PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "Z:\Delphi-Connector\Iniciar-Conector.ps1"
```

Cuando confirme la conexión, deja la ventana abierta. El asistente puede entonces enviar las operaciones desde Omarchy. Para detener el puente, pulsa **Ctrl+C**. Esto detiene el transporte por archivos; el paquete sigue cargado en Delphi y su servidor local sigue activo mientras el IDE lo mantenga iniciado.

Si reinicias Delphi, reinicia también el puente para que vuelva a leer el puerto y el token del servidor. Para retirar el paquete de esta instalación:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "Z:\Delphi-Connector\Desinstalar-Conector.ps1"
```

Después reinicia Delphi para descargarlo. El desinstalador conserva los fuentes, el paquete y el respaldo; elimina la entrada registrada por la instalación descrita en `instalacion.json`.

### Consultar Delphi desde Linux

Para listar las herramientas disponibles, con el puente activo:

```bash
python /home/macondo/Work/delphi-omarchy-kai-more/herramientas/delphi-connector/client.py
```

Para repetir la consulta de estado que comprobó la conexión:

```bash
cd /home/macondo/Work/delphi-omarchy-kai-more/herramientas/delphi-connector

python - <<'PY'
from client import request
import json

reply = request('tools/call', {'name': 'ide_status', 'arguments': {}})
print(json.dumps(reply, ensure_ascii=False, indent=2))
PY
```

La respuesta MCP contiene el resultado de la herramienta dentro de `result.content`. Si no hay proyecto abierto, `activeProject.available` será `false`; esto es un estado válido, no un fallo de conexión.

### Correcciones necesarias en este equipo

Durante la compilación apareció `E1026 File not found: 'McpIdeBridgeIcon.res'`. Faltaba copiar un recurso del proyecto original. Se incluyó ese recurso y el instalador actual también lo genera desde una copia integrada antes de compilar. Así evita depender de que Windows descubra un archivo recién agregado en la carpeta compartida.

El servidor respondía dentro de Windows, pero las primeras solicitudes escritas desde Linux no llegaban al puente. Tras ajustar la caché oportunista de Samba y reiniciar el puente de PowerShell, la consulta de extremo a extremo funcionó. El ajuste aplicado al recurso `[Data]` del contenedor fue:

```ini
[Data]
    oplocks = no
    level2 oplocks = no
```

Se guardó un respaldo en `/etc/samba/smb.conf.before-ide-connector`, dentro del contenedor, y se recargó su configuración con `smbcontrol all reload-config`. Se conservaron las demás opciones existentes del recurso compartido. Estos cambios dentro del contenedor no forman parte del instalador de Windows y pueden perderse si se recrea el contenedor; al reproducir la demostración, verifica otra vez una consulta desde Linux. La [documentación de Samba sobre bloqueo y caché](https://www.samba.org/samba/docs/current/man-html/smb.conf.5.html) describe estas opciones.

Si Windows sigue viendo una versión anterior de un archivo compartido, cierra y vuelve a abrir PowerShell antes de repetir el comando. Para diagnosticar el puente, revisa `estado.json`, `consulta-ide.json` y una llamada nueva a `ide_status`; un archivo de estado antiguo por sí solo no confirma una conexión activa.

### Compartir la adaptación con la comunidad

El proyecto original tiene licencia MIT y conserva el aviso `Copyright (c) 2026 Thomas Bornhaupt`. Al distribuir sus fuentes o partes sustanciales, incluye el archivo `source/LICENSE` y atribuye el origen. La adaptación local debe identificarse por separado del proyecto original y de los productos de Embarcadero. El repositorio y la revisión utilizada permiten que otros revisen el código exacto.

Para distribuir una copia reproducible, comparte los fuentes de `herramientas/delphi-connector`, sus scripts y estas instrucciones. Omite `__pycache__` y los archivos generados durante la sesión, como `request.json`, `response.json`, `.client.lock`, `estado.json`, `herramientas.json`, `consulta-ide.json`, `instalacion.json` e `instalacion.log`. No incluyas tokens de `%LOCALAPPDATA%\MCP2Delphi\Servers`, contraseñas de PAServer, respaldos del registro ni configuraciones privadas de Kai. Los scripts añadidos de esta publicación se distribuyen bajo la [licencia MIT del repositorio](../LICENSE); los archivos originales de MCP2Delphi conservan su aviso y licencia propios.

En otro equipo habrá que adaptar la versión y las rutas de Delphi, la arquitectura del IDE, la ruta `ROOT` de `client.py` y la carpeta compartida. El paquete se compila con el Delphi instalado por cada participante; esta distribución no necesita incluir bibliotecas propietarias de Embarcadero.

Mientras el puente está activo, quien pueda escribir en sus archivos compartidos puede solicitar acciones al IDE con los permisos del usuario de Windows. El token protege el servidor HTTP, pero el puente lo utiliza para las solicitudes del buzón. Por eso la carpeta debe quedar bajo el control de los participantes autorizados y el puente debe detenerse al terminar la demostración.

### Demostración de la conexión en la conferencia

1. Abrir Delphi y arrancar `Iniciar-Conector.ps1` en Windows.
2. Mostrar el recorrido de la solicitud y explicar que Kai no interviene.
3. Ejecutar `client.py` en Omarchy para enumerar las herramientas.
4. Consultar `ide_status` y contrastar su respuesta con el proyecto visible en Delphi.
5. Como siguiente demostración, generar un proyecto de ejemplo, abrirlo mediante el conector y solicitar su compilación. Elegir el destino y revisar los diagnósticos antes de ejecutarlo.
6. Si el destino es Linux, mostrar cómo PAServer completa el despliegue hacia Omarchy.
7. Detener el puente con Ctrl+C al terminar.

## Ejemplo práctico de MCPConnect con Ciudad Viva

El proyecto [Ciudad Viva](../demos/CiudadVivaMCP/README.md) muestra cómo una aplicación propia expone sus operaciones a un cliente MCP. Es un tablero FMX con una ciudad simulada: durante una tormenta baja la generación eléctrica y hay que redistribuir la potencia disponible, manteniendo el hospital y los servicios mínimos.

Los fuentes están en `~/Work/delphi-omarchy-kai-more/demos/CiudadVivaMCP` y su copia para Delphi en `Z:\CiudadVivaMCP`. Abre `CiudadViva.dproj` para revisar el código. Se generó un ejecutable Win32 en `Z:\CiudadVivaMCP\Win32\Debug\CiudadViva.exe`; las pruebas de ejecución y del protocolo se realizan con los botones de la aplicación o con `demo_client.py`, según el guion incluido en su README.

La clase `TCityTools` declara cuatro métodos con atributos `[McpTool]`: consultar el estado, cambiar el escenario, aplicar un plan y reiniciar la simulación. `TCityResources` expone `city://rules` y `TCityPrompts` proporciona el prompt `save-the-city`. El servidor registra esas clases mediante la configuración fluida de MCPConnect.

El ejemplo separa las decisiones del agente de las reglas de la aplicación. `TCityModel.Plan` valida todas las asignaciones antes de cambiarlas: hospital mínimo de 30 MW, hogares de 20 MW, industria de 10 MW y suma dentro de la potencia disponible. Una petición inválida produce un error y conserva las asignaciones anteriores. La interfaz FMX consulta el modelo y refleja su estado; los hilos HTTP no modifican directamente los controles visuales.

El botón **Rescatar vía MCP** usa un cliente HTTP real con una secuencia fija para demostrar descubrimiento, consulta, rechazo de un plan peligroso y aplicación de un plan válido. Esta secuencia no utiliza IA. Un asistente externo puede elegir las operaciones a partir de una petición en lenguaje natural y llamar al mismo servidor MCPConnect.

La [tabla de validación y pendientes](Estado-y-validacion.md) distingue la prueba guiada que se completó de la última corrección visual, pendiente de recompilar tras un error interno del IDE.

Esta demostración permite explicar dos conexiones distintas: MCP2Delphi da acceso al **IDE** para desarrollar el proyecto; MCPConnect da acceso a la **aplicación creada** y su lógica de negocio. El README del ejemplo contiene los comandos, el guion para presentarlo y las limitaciones de la simulación.

## Documentación oficial

- [Ejecutar PAServer en Linux](https://docwiki.embarcadero.com/RADStudio/Sydney/en/Running_the_Platform_Assistant_on_Linux)
- [Opciones de configuración de PAServer](https://docwiki.embarcadero.com/RADStudio/Alexandria/en/Setting_Options_for_the_Platform_Assistant)
- [PAServer y ayuda de la línea de comandos](https://docwiki.embarcadero.com/RADStudio/Florence/en/Paserver)
- [SDK Manager y actualización de la caché local](https://docwiki.embarcadero.com/RADStudio/Florence/en/SDK_Manager)
- [Añadir o editar rutas remotas del SDK](https://docwiki.embarcadero.com/RADStudio/Florence/en/Add_Remote_Path_Item_or_Edit_Remote_Path_Item)
- [Plataformas de destino soportadas](https://docwiki.embarcadero.com/RADStudio/Florence/en/Supported_Target_Platforms)

El lanzador Python, el servicio systemd y las rutas de bibliotecas son la adaptación local usada en Omarchy; los enlaces anteriores describen el funcionamiento y las opciones del producto.
