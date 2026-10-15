# Rutas actuales del entorno de conferencia

La carpeta principal de fuentes y documentación es `~/Work/delphi-omarchy-kai-more`. Las carpetas compartidas de Windows se mantienen como copias de trabajo para no cambiar el proyecto abierto ni la ruta del puente instalado.

| Uso | Ruta vigente |
| --- | --- |
| Repositorio y documentación | `~/Work/delphi-omarchy-kai-more` |
| Fuentes del ejemplo en el repositorio | `~/Work/delphi-omarchy-kai-more/demos/CiudadVivaMCP` |
| Proyecto que se abre en Delphi | `Z:\CiudadVivaMCP\CiudadViva.dproj` |
| Ejecutable del ejemplo | `Z:\CiudadVivaMCP\Win32\Debug\CiudadViva.exe` |
| Arranque diario del puente | `Z:\Delphi-Connector\Iniciar-Conector.ps1` |
| Fuentes del puente en el repositorio | `~/Work/delphi-omarchy-kai-more/herramientas/delphi-connector` |

Para usar el conector, abre Delphi y ejecuta en PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "Z:\Delphi-Connector\Iniciar-Conector.ps1"
```

No necesitas ejecutar `Instalar-Conector.ps1` de nuevo por haber publicado el repositorio. La instalación del paquete permanece en `%LOCALAPPDATA%\OmarchyIDEConnector`, fuera de estas carpetas de preparación. El puente actualizado prueba las conexiones de descubrimiento disponibles y descarta las que respondan con un token antiguo.

Después de actualizar `relay.cjs`, pulsa Ctrl+C en el puente anterior y vuelve a ejecutar el comando de inicio para cargar el nuevo código. Esto también es necesario al reiniciar Delphi. Una prueba local con servidor simulado confirmó que la selección descarta un token que produce HTTP 401; la conexión real se verifica mediante una consulta nueva al IDE después de reiniciar el puente.

Se retiraron las copias de preparación de `~/Work/demos`, `~/Work/herramientas` y el manual suelto de `~/Work/documentacion`. También se retiraron `Z:\Kai-Bridge`, `Z:\Diagnosticar-Kai.ps1` y su diagnóstico generado. No son rutas que deban utilizarse en este procedimiento. La limpieza no desinstala Kai del IDE.

La carpeta `Z:\Delphi-Connector` conserva los datos de su instalación y su buzón. `Z:\CiudadVivaMCP` conserva el proyecto y sus archivos de ejecución. El archivo privado de conexión a PAServer tampoco se retira: pertenece a otro servicio del entorno.

Las copias compartidas y el repositorio son directorios distintos, no una sincronización automática. Si modificas el ejemplo en Delphi, compara y lleva los cambios de los fuentes al repositorio antes de publicar. No copies ejecutables, DCU, tokens, registros ni buzones al repositorio.
