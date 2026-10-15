# Ciudad Viva con Delphi FMX y MCPConnect

Una ciudad simulada pierde generación durante una tormenta. Un asistente puede consultar el estado, leer las reglas y redistribuir potencia mediante MCP. Delphi protege al hospital y rechaza de forma atómica los planes que incumplen las reglas. El tablero refleja el estado real del modelo de la aplicación.

FMX permite mostrar un tablero visual durante la conferencia. Esta primera configuración compila para Windows Win32 con Delphi 37.0 y MCPConnect 1.0.1 de GetIt. No requiere un LLM ni claves de API para ejecutar la demostración guiada. Un cliente de IA externo puede descubrir y utilizar las mismas operaciones.

## Estado de esta versión

La primera versión Win32 compiló y su prueba guiada MCP terminó correctamente. Los fuentes publicados incluyen además la corrección del fondo para mejorar el contraste; su recompilación quedó pendiente por un error interno del IDE. Consulta [Estado y validación](../../documentacion/Estado-y-validacion.md) para reproducir las comprobaciones. No se distribuye un ejecutable.

## Ejecutar

Abre `CiudadViva.dproj` en Delphi, selecciona Windows de 32 bits y compila. Las rutas de MCPConnect en el proyecto corresponden a:

```text
C:\Users\Public\Documents\Embarcadero\Studio\37.0\CatalogRepository\MCPConnect\1.0.1
```

La copia publicada usa `$(BDSCOMMONDIR)\CatalogRepository\MCPConnect\1.0.1` como `MCPRoot`. En otro equipo comprueba esa ruta y las de Neon y Logify en las opciones del proyecto. La aplicación usa fuentes del framework instalado; no necesita cargar sus paquetes de diseño en el ejecutable.

Ejecuta el proyecto y pulsa **Provocar tormenta**. La potencia disponible baja a 75 MW, mientras la demanda es 105 MW y el plan anterior queda sobrecargado. **Rescatar vía MCP** ejecuta una secuencia determinista de solicitudes HTTP reales: inicialización, descubrimiento de herramientas, escenario, consulta, intento inválido, plan seguro y verificación. El resultado se muestra en el tablero y se guarda en `DemoBridge/selftest.json`.

Esta demo guiada no simula una conversación con IA ni atribuye decisiones a un modelo. Sirve para demostrar el protocolo y las reglas sin depender de Internet. El agente externo aporta la interpretación del lenguaje natural.

## Herramientas, recurso y prompt

| Tipo | Nombre | Función |
| --- | --- | --- |
| Tool | `city_status` | Generación, batería disponible, demanda, asignación y sobrecarga |
| Tool | `city_scenario` | Cambia a `normal`, `storm` o `festival` |
| Tool | `city_apply_plan` | Redistribuye potencia con validaciones atómicas |
| Tool | `city_reset` | Restablece la simulación |
| Resource | `city://rules` | Reglas de negocio, unidades y límites del modelo |
| Prompt | `save-the-city` | Guía al asistente para consultar, proponer, pedir confirmación y verificar |

`city_apply_plan` recibe enteros `hospital_mw`, `homes_mw` e `industry_mw`. El hospital necesita al menos 30 MW, los hogares 20 MW y la industria 10 MW. La suma no puede superar generación más potencia disponible de la batería. La validación vive en `TCityModel.Plan`, con bloqueo de exclusión mutua: ni una petición equivocada del agente ni otro cliente pueden saltarse esas reglas mediante la herramienta.

Los valores son una simulación didáctica de potencia en MW. La batería representa potencia de descarga disponible; no modelamos tiempo, energía almacenada ni estado de carga. En la tormenta hay que recortar 30 MW de demanda para evitar sobrecarga: el tablero muestra el recorte en lugar de afirmar que toda la demanda quedó abastecida.

## Conectar un cliente MCP

La aplicación escucha solo en `127.0.0.1`, dentro de Windows. La URL habitual es `http://127.0.0.1:9091/mcp`; si el puerto está ocupado prueba hasta 9099. El tablero y `DemoBridge/endpoint.json`, junto al ejecutable, muestran la URL elegida. Configura esa URL en un cliente compatible con el transporte HTTP de MCPConnect. Desde otra máquina, su propio `localhost` no apunta a Windows.

Una petición de ejemplo al endpoint es:

```json
{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"city_apply_plan","arguments":{"hospital_mw":30,"homes_mw":30,"industry_mw":15}}}
```

Para controlar la demo desde este Omarchy se incluye además un buzón de archivos en `DemoBridge`. `demo_client.py` escribe la solicitud; la app la reenvía mediante HTTP a su propio servidor MCPConnect y devuelve la respuesta. Esta parte es una adaptación para la máquina virtual y no una función del framework MCPConnect.

Con la app ejecutándose en Windows:

```bash
python ~/Work/delphi-omarchy-kai-more/demos/CiudadVivaMCP/demo_client.py tools
python ~/Work/delphi-omarchy-kai-more/demos/CiudadVivaMCP/demo_client.py status
python ~/Work/delphi-omarchy-kai-more/demos/CiudadVivaMCP/demo_client.py tour
```

El cliente busca `~/Windows/CiudadVivaMCP/Win32/Debug/DemoBridge`. Si cambia la carpeta del ejecutable, usa `--bridge /ruta/a/DemoBridge`. `tour` comprueba el rechazo del plan peligroso, que las asignaciones no cambiaron y que el plan seguro se aplicó y pudo consultarse después.

## Guion para la conferencia

1. Mostrar el tablero en estado normal y explicar qué representa cada valor.
2. Provocar la tormenta y mostrar el exceso de asignación.
3. Mostrar el atributo `[McpTool]` y su registro mediante `.Tools.RegisterClass(TCityTools)`.
4. Enumerar las herramientas desde un cliente y leer `city://rules`.
5. Pedir al asistente: «Analiza la tormenta, protege el hospital y propón una distribución. Antes de cambiarla, explícame los recortes».
6. Tras la confirmación, aplicar 30/30/15 MW y verificar el estado.
7. Intentar asignar 0 MW al hospital: Delphi debe rechazar la operación sin alterar el plan.
8. Explicar que el mismo patrón puede usarse para inventario, reservas, fabricación o análisis de datos reales.

El conector del IDE y MCPConnect tienen funciones distintas: MCP2Delphi permitió crear, abrir y compilar este proyecto desde el asistente. MCPConnect hace que la aplicación resultante exponga su lógica de negocio. Kai y PAServer no intervienen en la ejecución Windows de esta demo.

## Archivos y distribución

`CiudadViva.Model.pas` contiene el modelo, las reglas y los atributos MCP; `CiudadViva.Main.pas` contiene la vista FMX, el servidor y el cliente de demostración. La interfaz se construye en código, sin archivo `.fmx` ni dependencias visuales de terceros.

El servidor local de esta demo no usa autenticación y el buzón permite operaciones a quien pueda escribir en su carpeta. Está preparado para una demostración local. Para un producto con acceso de red, añade autenticación y autorización adecuadas y elimina el buzón si no lo necesitas.

Los ejemplos originales del framework y su documentación están en [MCPConnect](https://github.com/delphi-blocks/MCPConnect) y en su [documentación de herramientas](https://mcpconnect.delphiblocks.dev/tools.html). No se incluyen bibliotecas propietarias de Delphi ni copias de la instalación GetIt. Comparte los fuentes y las instrucciones; omite ejecutables, DCU, archivos del buzón y rutas o registros privados.
