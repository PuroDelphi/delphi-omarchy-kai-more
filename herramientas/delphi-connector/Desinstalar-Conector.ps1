$ErrorActionPreference = 'Stop'
$info = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'instalacion.json') -Raw | ConvertFrom-Json
$key = 'HKCU:\Software\Embarcadero\BDS\37.0\Known Packages'
Remove-ItemProperty -Path $key -Name $info.package -ErrorAction Stop
Write-Host 'Registro del conector retirado. Reinicia Delphi para descargarlo. Se conservan el codigo y el respaldo.'
