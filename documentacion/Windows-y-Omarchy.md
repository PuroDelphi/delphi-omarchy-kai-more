# Windows y Delphi sobre Omarchy

El equipo de referencia ejecuta Delphi 37.0 dentro de Windows virtualizado con Dockur y administrado por el menú de Omarchy. Omarchy conserva sus particiones raíz y `/data`; los archivos de la máquina virtual se alojan en `/data` para aprovechar su capacidad disponible.

## Discos y almacenamiento

| Elemento | Configuración del equipo de referencia |
| --- | --- |
| Raíz de Omarchy | Aproximadamente 98 GiB |
| Partición `/data` | Aproximadamente 129 GiB |
| Almacenamiento de Windows | `/data/windows-vm` |
| Ruta esperada por el lanzador | `~/.windows`, enlace a `/data/windows-vm` |
| Imagen de disco de Windows | `/data/windows-vm/data.img` |
| Tamaño virtual ampliado | 112 GiB |
| Unidad C de Windows | Aproximadamente 111 GiB, con partición de recuperación conservada |
| Carpeta compartida | `~/Windows`, visible como `Z:` dentro de Windows |

La solución aplicada no fusionó `/data` con la raíz de Omarchy. Se trasladó el almacenamiento de Windows a `/data`, manteniendo la ruta del lanzador mediante un enlace simbólico. El espacio de C pertenece al disco virtual; no crece solo porque quede espacio libre en Linux. Por eso se amplió después la imagen y la partición de Windows.

Para consultar las rutas y la capacidad, sin modificar discos:

```bash
df -h / /data
ls -ld ~/.windows ~/Windows
readlink -f ~/.windows
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
```

Antes de trasladar una instalación a otra partición, apaga Windows y detén el contenedor. Copia el almacenamiento completo, verifica la copia y adapta el enlace y el montaje utilizado por el lanzador. Conserva un respaldo antes de cambiar la imagen o sus particiones. Los tamaños y dispositivos del equipo de referencia no deben utilizarse como parámetros de particionado en otro equipo.

## Inicio y administración de Windows

En esta instalación, el menú de Windows utiliza `/usr/bin/omarchy-windows-vm`. Para consultar los comandos de la versión instalada:

```bash
omarchy windows vm --help
```

Las operaciones disponibles en el lanzador del equipo de referencia son:

```bash
omarchy windows vm status
omarchy windows vm launch --keep-alive
omarchy windows vm stop
```

El comando subyacente es `omarchy-windows-vm`, por ejemplo `omarchy-windows-vm status`. `--keep-alive` deja la VM encendida al cerrar la ventana RDP; sin esa opción el lanzador puede detenerla al desconectar. El contenedor se llama `omarchy-windows`.

El archivo Compose administrado por el lanzador está en `/var/lib/omarchy/windows/docker-compose.yml`. Puede contener datos privados de la instalación y no se publica en este repositorio. Para identificar el almacenamiento y los puertos efectivos sin mostrar variables de entorno o contraseñas:

```bash
sudo docker inspect --format '{{json .Mounts}}' omarchy-windows
sudo docker port omarchy-windows
sudo docker inspect --format '{{range .NetworkSettings.Networks}}{{.Gateway}} {{.IPAddress}}{{end}}' omarchy-windows
```

## Red y carpeta compartida

En la red Docker del equipo de referencia, Omarchy usa `172.18.0.1` como puerta de enlace y el contenedor `172.18.0.2`. Windows tiene además su red interna de virtualización. Estas direcciones corresponden a esta configuración y pueden cambiar.

El invitado usa NAT. No se configuró una IP independiente en la LAN mediante un puente de la interfaz física. Los servicios publicados de la VM son el visor web en `127.0.0.1:8006` y RDP en `127.0.0.1:3389`, accesibles desde el anfitrión.

Delphi se conecta a PAServer a través de `172.18.0.1:64211`. El [manual de PAServer](PAServer-instalacion-y-administracion.md) contiene el perfil de conexión y la regla de UFW. El conector del IDE y Ciudad Viva escuchan solo en localhost de Windows y utilizan puentes de archivos para comunicarse con este Omarchy.

La carpeta `~/Windows` se comparte mediante Samba dentro del contenedor y aparece como `Z:` en Windows. No publiques el contenido completo de esa carpeta: puede contener credenciales, registros y solicitudes de las demostraciones.

Si un archivo escrito desde Linux no se actualiza dentro de Windows, consulta el apartado de caché de Samba del manual. En este equipo se desactivaron `oplocks` y `level2 oplocks` del recurso `[Data]` y se reinició el puente. Ese ajuste se hizo dentro del contenedor y necesita revisión si se recrea; no está incluido en el hook de Pacman.

## Rendimiento de Windows

La VM usa aceleración de virtualización de CPU mediante KVM. La configuración de referencia asignó seis CPU virtuales y 16 GiB de RAM. Esto acelera la ejecución del sistema invitado, pero no equivale a pasarle la tarjeta gráfica física.

Para mejorar la sesión remota se cambió FreeRDP de AVC444 a AVC420 y se añadieron estas opciones:

```text
/gfx:AVC420 /network:lan -wallpaper -menu-anims -window-drag
```

Se conserva la resolución dinámica. Estos ajustes reducen trabajo de composición y transmisión de RDP. No proporcionan aceleración OpenGL por la GPU física dentro de Windows. No se configuró passthrough de GPU; una aplicación que lo necesite debe evaluar por separado los requisitos del dispositivo y de virtualización.

## Permisos y persistencia tras actualizaciones

El lanzador valida permisos de las carpetas de almacenamiento y compartición. Samba podía dejar activado el bit setgid en un directorio. El ajuste local cambia el `chmod 0700` de una operación concreta a `chmod 00700`, para limpiar también los bits especiales que interferían con esa validación.

El [script y el hook de Pacman](../herramientas/omarchy/README.md) conservan ese ajuste y las opciones RDP cuando el paquete vuelve a instalar `/usr/bin/omarchy-windows-vm`. El script comprueba el texto esperado y rechaza una versión desconocida; no garantiza compatibilidad con cualquier actualización futura. No se modifican archivos de `/usr/share/omarchy`.

## Relación entre Delphi, Kai y MCP

| Componente | Función en este entorno |
| --- | --- |
| Delphi en Windows | Edita, compila y depura los proyectos |
| PAServer en Omarchy | Recibe despliegues y permite depurar en Linux |
| SDK de Linux en Windows | Copia local de bibliotecas y encabezados usada al compilar para Linux |
| Kai | Integración de agentes dentro del IDE; no participa en el puente publicado |
| MCP2Delphi | Extensión que permite al cliente externo operar el IDE |
| MCPConnect | Framework con el que Ciudad Viva expone operaciones de su propia aplicación |

Se exploraron las herramientas internas de Kai y las configuraciones de agentes, pero la conexión externa que funcionó fue MCP2Delphi con el puente de archivos. Los scripts de diagnóstico y los intentos previos de conexión a Kai no forman parte del procedimiento reproducible de este repositorio.

El servidor del IDE requiere token y escucha en localhost. No quedó expuesto a la LAN ni a Internet. Para acceder desde otra máquina, diseña un acceso autenticado, por ejemplo con un túnel SSH o una VPN, teniendo en cuenta que las operaciones se ejecutan con los permisos del usuario de Delphi. Esta instalación no incluye ese acceso remoto.
