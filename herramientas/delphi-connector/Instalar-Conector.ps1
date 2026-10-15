$ErrorActionPreference = 'Stop'
$shared = $PSScriptRoot
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$target = Join-Path $env:LOCALAPPDATA "OmarchyIDEConnector\$stamp"
New-Item -ItemType Directory -Path $target -Force | Out-Null
$log = Join-Path $shared 'instalacion.log'
Start-Transcript -Path $log -Force | Out-Null
try {
    # Compile locally; never load packages from the network share.
    Copy-Item -LiteralPath (Join-Path $shared 'source') -Destination $target -Recurse
    $src = Join-Path $target 'source'
    # Embedded resource avoids SMB directory caching of newly added files.
    [System.IO.File]::WriteAllBytes((Join-Path $src 'McpIdeBridgeIcon.res'), [Convert]::FromBase64String('AAAAACAAAAD//wAA//8AAAAAAAAAAAAAAAAAAAAAAABEAQAAPAAAAP//CgBNAEMAUABfAEkARABFAF8AUwBQAEwAQQBTAEgAAAAAAAAAAAAwAAcEAAAAAAAAAACJUE5HDQoaCgAAAA1JSERSAAAAGAAAABgIBgAAAOB3PfgAAAABc1JHQgCuzhzpAAAABGdBTUEAALGPC/xhBQAAAAlwSFlzAAAOwwAADsMBx2+oZAAAANlJREFUSEu9lbsOwjAQBF1S8xl8br40PUUiR3K0Ht86B0EUK7GHPZOHwOX5eG2a7b3eCnnlV2CmE/DLKMuyHOF8lrSglNIlKzoEHDIN6vpVpgIHi2YuVkC49tuCGVx7y+ydDAIHy3amE3DxVde5u4tTwM3ZvkoIPwVu86wrmBkEvD3C2COYkwwvucoaMIKrgHB+vhRoMnDtbTYIFBb16GrdzAoUShkB0TwlqOFfNB/TTHLuIdQlekyERbOvBIQx3b7MgeMkFHF9+kTTVAF/mC7/O/Q1XPhpyNsBiVHuZbSjGQoAAAAASUVORK5CYII='))
    if (-not (Test-Path -LiteralPath (Join-Path $src 'McpIdeBridgeIcon.res'))) { throw 'No se pudo generar el recurso del conector.' }
    $bin = Join-Path $target 'bin'
    $dcu = Join-Path $target 'dcu'
    New-Item -ItemType Directory -Path $bin,$dcu -Force | Out-Null
    $bds = 'C:\Program Files (x86)\Embarcadero\Studio\37.0'
    $dcc = Join-Path $bds 'bin\dcc32.exe'
    if (-not (Test-Path -LiteralPath $dcc)) { throw "No se encuentra el compilador: $dcc" }
    $lib = Join-Path $bds 'lib\win32\release'
    $ota = Join-Path $bds 'source\ToolsAPI'
    Push-Location $src
    try {
        & $dcc '-B' '-Q' '--no-config' "-LE$bin" "-LN$bin" "-NU$dcu" "-U$lib;$ota" "-I$lib;$ota" '-NSSystem;System.Win;Winapi;Vcl;Vcl.Imaging;Data;Xml;Web;Soap' 'OmarchyIDEConnector.dpk'
        if ($LASTEXITCODE -ne 0) { throw "La compilacion fallo ($LASTEXITCODE). No se ha registrado ningun paquete. Revisa instalacion.log." }
    } finally { Pop-Location }
    $bpl = Join-Path $bin 'OmarchyIDEConnector.bpl'
    if (-not (Test-Path -LiteralPath $bpl)) { throw 'No se genero el paquete esperado.' }
    $key = 'HKCU:\Software\Embarcadero\BDS\37.0\Known Packages'
    if (-not (Test-Path $key)) { throw 'No se encuentra la configuracion de Delphi 37.0 del usuario actual.' }
    $backup = Join-Path $target 'Known-Packages.reg'
    & reg.exe export 'HKCU\Software\Embarcadero\BDS\37.0\Known Packages' $backup /y | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'No se pudo respaldar el registro; instalacion cancelada.' }
    New-ItemProperty -Path $key -Name $bpl -Value 'Omarchy external IDE connector' -PropertyType String -Force | Out-Null
    @{package=$bpl;backup=$backup;installed=(Get-Date -Format o);source='MCP2Delphi e19680c37fba49a04311db7411147401cd018ba4'} |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $shared 'instalacion.json') -Encoding UTF8
    Write-Host 'Compilado y registrado. Guarda tus proyectos y cierra y vuelve a abrir Delphi.'
    Write-Host 'El servidor escucha solo dentro de Windows y exige un token.'
    Read-Host 'Cuando hayas cerrado y vuelto a abrir Delphi, presiona Enter aqui' | Out-Null
    & (Join-Path $shared 'Iniciar-Conector.ps1')
} finally { Stop-Transcript | Out-Null }
