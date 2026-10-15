# Control externo del IDE con MCP2Delphi

Esta adaptación instala un servidor MCP dentro de Delphi y permite enviarle solicitudes desde Omarchy a través de una carpeta compartida. Utiliza MCP2Delphi, no las herramientas internas de Kai ni MCPConnect. Consulta la [arquitectura y explicación completa](../../documentacion/PAServer-instalacion-y-administracion.md#controlar-delphi-desde-esta-conversación).

## Preparación e instalación

Requiere Delphi 37.0 con compilador Win32 y ToolsAPI, Node.js en Windows y Python 3 en Linux. El paquete se compiló para el IDE de 32 bits; otras versiones o arquitecturas necesitan adaptar el instalador.

Desde la raíz del repositorio, copia esta carpeta a `~/Windows/Delphi-Connector` la primera vez, si el destino no existe todavía:

```bash
cp -a herramientas/delphi-connector ~/Windows/Delphi-Connector
```

No crees una segunda instalación encima de otra sin revisar sus archivos y las entradas del registro. En PowerShell, con el usuario habitual de Delphi:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "Z:\Delphi-Connector\Instalar-Conector.ps1"
```

El instalador copia los fuentes a `%LOCALAPPDATA%\OmarchyIDEConnector\<fecha-hora>`, integra el recurso de icono y compila con `dcc32.exe`. Solo después de compilar respalda `Known Packages` y registra el nuevo paquete. Guarda tus proyectos, reinicia Delphi y pulsa Enter en el PowerShell del instalador. Deja esa ventana abierta mientras se use el puente.

## Sesiones posteriores

Con Delphi abierto:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "Z:\Delphi-Connector\Iniciar-Conector.ps1"
```

El puente descubre el endpoint local, lee el token dentro de Windows y verifica `tools/list` e `ide_status`. No añade servidores automáticamente a la configuración de un agente: el cliente de esta adaptación usa el buzón de archivos.

Desde Linux, en la raíz del repositorio:

```bash
python herramientas/delphi-connector/client.py
```

La copia publicada del cliente utiliza por defecto `~/Windows/Delphi-Connector`. Puedes elegir otra carpeta con:

```bash
DELPHI_BRIDGE_DIR=/ruta/al/puente python herramientas/delphi-connector/client.py
```

Para enviar una consulta de estado:

```bash
cd herramientas/delphi-connector
python - <<'PY'
from client import request
import json
print(json.dumps(request('tools/call', {
    'name': 'ide_status', 'arguments': {}
}), ensure_ascii=False, indent=2))
PY
```

Usa rutas nativas de Windows al llamar a `ide_open_file`, por ejemplo `r'Z:\CiudadVivaMCP\CiudadViva.dproj'` en Python. El IDE no interpretó correctamente las barras `/` de una ruta durante la primera apertura de este ejemplo.

## Detener y retirar

Ctrl+C detiene el puente. Reinícialo si reinicias Delphi para que lea el nuevo puerto y token. El servidor dentro del IDE sigue cargado mientras Delphi lo mantenga iniciado.

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "Z:\Delphi-Connector\Desinstalar-Conector.ps1"
```

El desinstalador retira la entrada indicada en `instalacion.json`. Reinicia Delphi para descargar el paquete. Si instalaste varias veces, revisa las entradas anteriores en vez de asumir que una sola desinstalación las retirará todas.

## Validación y límites

El paquete compiló y se recibió una respuesta real de `ide_status` desde Linux. Se anunciaron 51 herramientas y se utilizó el conector para abrir y compilar Ciudad Viva. Durante las pruebas hubo tiempos de espera por diálogos del IDE y un error interno en `delphicoreide370.bpl` al recompilar después de un cambio visual. Consulta [Estado y validación](../../documentacion/Estado-y-validacion.md).

El endpoint escucha en localhost de Windows y requiere un token. Quien pueda escribir en el buzón del puente puede solicitar operaciones al IDE, porque el puente añade ese token. Mantén la carpeta bajo control de los usuarios autorizados y detén el puente al terminar. Esta configuración no expone el IDE a Internet.

Origen y licencia: [MCP2Delphi](https://github.com/ThomasBornhaupt/MCP2Delphi), revisión `e19680c37fba49a04311db7411147401cd018ba4`. Se conserva su licencia en `source/LICENSE`; las unidades Pascal se incluyen sin cambios respecto de esa revisión.
