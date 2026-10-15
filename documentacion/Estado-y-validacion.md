# Estado de la configuración y las pruebas

Esta publicación recoge el trabajo realizado el 14 y 15 de octubre de 2026 en el equipo de referencia con Omarchy, Delphi Studio 37.0 y MCPConnect 1.0.1 de GetIt.

| Parte | Resultado observado |
| --- | --- |
| Windows en `/data/windows-vm` | Arranque comprobado usando la ruta esperada por el lanzador |
| Ampliación del disco virtual | Imagen de 112 GiB, C de aproximadamente 111 GiB y partición de recuperación conservada |
| PAServer | Servicio de usuario y conexión desde Delphi operativos |
| SDK de Linux | Ejemplos compilaron después de importar las bibliotecas y objetos necesarios |
| Paquete del conector | Compiló con `dcc32` 37.0 y quedó registrado en el IDE |
| Puente Linux a Delphi | Consulta real `ide_status` recibida y respondida; 51 herramientas anunciadas |
| Ciudad Viva inicial | Ejecutable Win32 generado y aplicación abierta en Windows |
| Prueba guiada MCP | El registro indicó descubrimiento y llamadas correctas, plan inválido rechazado, asignaciones conservadas y plan seguro aplicado |
| Corrección del fondo | Incluida en los fuentes; recompilación y verificación visual pendientes |

## Último cambio visual

La captura de la primera versión mostró texto claro sobre un fondo casi blanco fuera de los paneles. Se añadió `Fill.Kind := TBrushKind.Solid` al formulario y un relleno explícito del fondo en `PaintScene`. Esta corrección está incluida en los fuentes publicados.

Al intentar recompilar apareció un error interno de Delphi en `delphicoreide370.bpl`, con lectura de una dirección nula. No se confirmó que ese error lo causara el código de la aplicación. La siguiente verificación requiere cerrar la demo, reiniciar el IDE, compilar y abrir el ejecutable nuevo. No se distribuye un binario que pudiera confundirse con la versión corregida.

## Repetir las comprobaciones

1. Instalar MCPConnect y comprobar la ruta `MCPRoot` del proyecto.
2. Abrir `demos/CiudadVivaMCP/CiudadViva.dproj` en Delphi 37.0 y compilar para Windows Win32.
3. Ejecutar y comprobar que el fondo es oscuro y el título blanco se lee claramente.
4. Pulsar **Rescatar vía MCP** y comprobar que `DemoBridge/selftest.json` contiene `passed: true`.
5. Con la app abierta, ejecutar el cliente Python `demo_client.py tour` desde Linux para comprobar también el buzón de archivos de la demo.
6. Si se usa el conector del IDE, enviar `ide_status` desde Linux; no basta con un archivo de estado guardado de una sesión anterior.

La prueba guiada se ejecutó mediante el botón de la aplicación. La secuencia `tour` del cliente Linux forma parte de las herramientas de reproducción y no se presenta como una prueba ya completada en el equipo de referencia.

Las 51 herramientas anunciadas por el conector no se probaron individualmente. La simulación de energía tampoco modela tiempo, estado de carga de batería ni una red física: sus reglas están acotadas al ejemplo didáctico.

## Cambios en el sistema

El hook de Pacman vuelve a aplicar dos ajustes específicos del lanzador de Windows y rechaza versiones desconocidas. Los cambios de Samba se hicieron dentro del contenedor y pueden perderse al recrearlo. Las rutas de bibliotecas de GCC pueden cambiar al actualizar Arch; compruébalas con `gcc -print-file-name=libgcc_s.so` y actualiza después la caché del SDK en Delphi.
