# Captura para Omarchy

Plugin nativo de la barra de Omarchy con una galería de capturas, animaciones y arrastre de archivos hacia otras aplicaciones. La interfaz usa QML/Quickshell, que es el formato de plugins del shell de esta versión de Omarchy. El catálogo de archivos es un ejecutable escrito y compilado con Delphi para Linux64.

## Funciones

- Botón de cámara en la barra que abre la galería; clic derecho para capturar.
- Captura de región, pantalla o ventana mediante las herramientas de Omarchy.
- La galería se oculta antes de capturar y reaparece al terminar o cancelar.
- PNG originales en `~/Pictures/Capturas`, con miniaturas, dimensiones, fecha y tamaño.
- Arrastre nativo con `text/uri-list` y acción de copia para aplicaciones compatibles.
- Copiar imagen al portapapeles, abrir en Pinta, buscar y enviar a la papelera.
- Entrada animada, miniaturas progresivas, transiciones de selección y respuesta al pasar el cursor.

## Compilar e instalar

Abre `backend/CapturaBackend.dproj` en Delphi 37.0, selecciona Linux64 y compila con un SDK Linux configurado. El backend solo utiliza la biblioteca estándar de Delphi: no requiere FMX ni MCPConnect. En el equipo de referencia la copia para compilar está en `Z:\CapturaBackend` y el binario resultante en `Linux64\Debug\CapturaBackend`.

En Omarchy, desde esta carpeta:

```bash
chmod +x /ruta/al/CapturaBackend
./install.sh /ruta/al/CapturaBackend
```

Si el ejecutable ya está en `bin/CapturaBackend`, basta con `./install.sh`. Se instala en `~/.config/omarchy/plugins/purodelphi.captura` y se habilita su botón en la barra, sin modificar `/usr/share/omarchy`. El instalador conserva un respaldo de `shell.json` en `~/.local/state/captura`. Usa los comandos del Omarchy instalado; otras versiones del shell podrían necesitar adaptar el manifiesto o la interfaz.

Dependencias del escritorio: Omarchy con Quickshell y soporte de plugins, `grim`, `slurp`, `wl-copy` y `gio`. El botón Pinta requiere tener Pinta instalado. El binario Delphi compilado y las capturas personales no se publican en Git.

## Uso

Pulsa el icono de cámara, elige **Región**, **Pantalla** o **Ventana** y pulsa **Nueva captura**. Para compartir una imagen, arrastra el área de su miniatura hacia una aplicación que acepte archivos; el original permanece en la galería. Doble clic abre la imagen en Pinta. Los botones de cada tarjeta permiten copiarla o abrirla; selecciona una tarjeta para enviarla a la papelera desde el pie de la galería. Escape cierra la ventana.

El catálogo muestra hasta 200 PNG, ordenados por fecha de modificación. No borra archivos al alcanzar ese número. Al abrir la galería y cada cinco segundos mientras esté visible se vuelve a consultar el catálogo Delphi.

Comandos para abrir y capturar:

```bash
omarchy shell purodelphi.captura open
omarchy shell purodelphi.captura capture fullscreen
omarchy shell purodelphi.captura capture region
omarchy shell purodelphi.captura status
```

Para usar otra carpeta puede configurarse `directory` en la entrada de este widget en `~/.config/omarchy/shell.json`. Las imágenes se quedan en el equipo; no hay servicios web ni subida automática.

## Desinstalar

```bash
./uninstall.sh
```

Retira el plugin mediante Omarchy y conserva las imágenes. El código fuente queda en este repositorio para la conferencia.

## Comprobaciones realizadas

En el equipo de referencia se compiló el backend con Delphi 37.0 para Linux64 y se ejecutó en Omarchy. Se comprobaron los metadatos PNG, los nombres con espacios y acentos, una captura real de pantalla y la carga del plugin en la barra. El usuario confirmó que arrastrar la miniatura desde el panel Wayland a Pinta abre correctamente la imagen.

El arrastre utiliza una lista de URI de archivo y semántica de copia; cada aplicación de destino decide qué formatos acepta. No se afirma compatibilidad con aplicaciones que no admitan soltar archivos.
