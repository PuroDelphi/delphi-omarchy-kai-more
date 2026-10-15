# Delphi en Omarchy con PAServer y MCP

Configuración de un entorno Delphi en una máquina virtual Windows sobre Omarchy, preparada para una conferencia de PuroDelphi. Incluye PAServer para desplegar aplicaciones en Linux, las correcciones del SDK y un ejemplo FMX que expone su lógica de negocio mediante MCPConnect.

**El puente que controla el IDE funciona sin Kai.** MCP2Delphi expone funciones de Delphi; MCPConnect expone funciones de la aplicación que construimos. Kai y MCPConnect son productos distintos y no sustituyen a PAServer.

## Por dónde empezar

| Contenido | Qué encontrarás |
| --- | --- |
| [Guía del entorno Windows y Omarchy](documentacion/Windows-y-Omarchy.md) | Discos, almacenamiento de la VM, red, RDP y persistencia de ajustes |
| [Manual de PAServer, SDK y conexión al IDE](documentacion/PAServer-instalacion-y-administracion.md) | Instalación, administración, errores resueltos y explicación del puente |
| [Conector externo del IDE](herramientas/delphi-connector/README.md) | Instalar, usar y retirar MCP2Delphi con el puente de archivos |
| [Ciudad Viva con MCPConnect](demos/CiudadVivaMCP/README.md) | Ejemplo FMX, herramientas, recurso, prompt y guion de conferencia |
| [PAServer para systemd](herramientas/paserver/README.md) | Lanzador y plantilla del servicio de usuario |
| [Ajustes del lanzador de Windows](herramientas/omarchy/README.md) | Parche acotado de permisos y RDP, con hook de Pacman |
| [Validación y pendientes](documentacion/Estado-y-validacion.md) | Qué se comprobó y qué necesita revisión al reproducirlo |
| [Créditos y licencias](THIRD_PARTY_NOTICES.md) | Origen del código y condiciones de redistribución |

## Descargar y abrir el ejemplo

```bash
mkdir -p ~/Work
cd ~/Work
git clone https://github.com/PuroDelphi/delphi-omarchy-kai-more.git
cd delphi-omarchy-kai-more
```

La copia local usada en la conferencia está en `~/Work/delphi-omarchy-kai-more`. Las rutas `macondo`, las direcciones Docker y Studio `37.0` del manual describen el equipo de referencia; adáptalas a tu instalación.

Para llevar el ejemplo a la carpeta compartida de la VM, **la primera vez y con la carpeta de destino aún inexistente**:

```bash
cp -a demos/CiudadVivaMCP ~/Windows/CiudadVivaMCP
```

Si el destino ya existe, conserva tus cambios y compara las copias antes de actualizar. Dentro de Windows abre `Z:\CiudadVivaMCP\CiudadViva.dproj` en Delphi. Instala MCPConnect desde GetIt y revisa `MCPRoot` en el proyecto: esta copia usa `$(BDSCOMMONDIR)\CatalogRepository\MCPConnect\1.0.1`. El ejemplo está configurado para Windows Win32.

## Qué muestra Ciudad Viva

Una tormenta reduce la generación de una ciudad simulada. El cliente MCP consulta el estado y las reglas, propone una redistribución y solicita aplicarla. La lógica Delphi impide dejar sin potencia mínima al hospital o exceder el presupuesto. El tablero FMX refleja el resultado y la demanda que queda sin atender.

Incluye una demo guiada con solicitudes HTTP MCP reales, sin un modelo de IA ni claves de API, y un cliente Python para operar desde Linux mediante la carpeta compartida. Un agente externo puede utilizar las mismas herramientas a partir de instrucciones en lenguaje natural.

La primera versión compiló y pasó la prueba guiada del protocolo. Los fuentes incluyen la posterior corrección del fondo; su recompilación quedó pendiente tras un error interno del IDE. Consulta el [estado de validación](documentacion/Estado-y-validacion.md) antes de presentar o adaptar el ejemplo.

## Alcance de esta publicación

Se incluyen fuentes, scripts y documentación. Cada participante utiliza su instalación de Delphi, PAServer y los componentes correspondientes. El repositorio no contiene contraseñas, tokens, máquinas virtuales, ejecutables ni bibliotecas propietarias de Embarcadero. No es un instalador automático de todo Omarchy ni una distribución oficial de Embarcadero.
