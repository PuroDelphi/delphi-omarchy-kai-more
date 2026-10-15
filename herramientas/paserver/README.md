# PAServer como servicio de usuario

Sigue primero el [manual de instalación](../../documentacion/PAServer-instalacion-y-administracion.md) para copiar PAServer y crear su configuración privada con contraseña. Estos archivos no incluyen el servidor de Embarcadero ni credenciales.

Desde la raíz del repositorio, después de completar esa preparación:

```bash
install -d -m 0700 ~/.local/share/paserver
mkdir -p ~/.config/systemd/user
install -m 0700 herramientas/paserver/run.py ~/.local/share/paserver/run.py
install -m 0644 herramientas/paserver/paserver.service ~/.config/systemd/user/paserver.service
systemd-analyze --user verify ~/.config/systemd/user/paserver.service
systemctl --user daemon-reload
systemctl --user enable --now paserver
```

`run.py` mantiene abierta la entrada estándar para evitar el bucle de consola observado con stdin cerrado. El servicio se vincula a la sesión gráfica. Usa `systemctl --user start paserver`, `stop paserver`, `restart paserver` y `status paserver` para administrarlo. Consulta registros con `journalctl --user -u paserver -n 30 --no-pager`.
