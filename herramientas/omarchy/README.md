# Conservar los ajustes de Windows en Omarchy

`windows-vm-ajustes.py` reproduce el parche acotado utilizado en este equipo para el lanzador `/usr/bin/omarchy-windows-vm`: limpieza del bit setgid al validar directorios y opciones FreeRDP que mejoraron la fluidez.

El script es idempotente y rechaza el lanzador si ya no encuentra los fragmentos de código esperados. El hook de Pacman vuelve a ejecutarlo después de instalar o actualizar el archivo del lanzador. No modifica `/usr/share/omarchy` ni las opciones de Samba dentro del contenedor.

Desde la raíz del repositorio, primero comprueba la lógica del parche:

```bash
python herramientas/omarchy/windows-vm-ajustes.py --self-test
```

Para instalarlo en un equipo que use la misma versión compatible del lanzador:

```bash
sudo install -D -m 0755 herramientas/omarchy/windows-vm-ajustes.py \
  /usr/local/sbin/omarchy-windows-permissions-fix
sudo install -D -m 0644 herramientas/omarchy/99-zz-omarchy-windows-permissions.hook \
  /etc/pacman.d/hooks/99-zz-omarchy-windows-permissions.hook
sudo /usr/local/sbin/omarchy-windows-permissions-fix
```

Si el último comando rechaza una versión desconocida, revisa el lanzador actualizado antes de adaptar el parche. Para dejar de reaplicarlo automáticamente, retira el hook; eso no revierte un parche ya aplicado al lanzador.
