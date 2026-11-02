param(
    [ValidateSet('android-emulator', 'android-device', 'windows')]
    [string]$Target = 'android-emulator',
    [string]$Server = 'dev@76.13.168.23',
    [int]$GatewayPort = 3000
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
    throw 'OpenSSH no esta disponible en este equipo.'
}

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter no esta disponible en este equipo.'
}

$adbCommand = Get-Command adb -ErrorAction SilentlyContinue
if (-not $adbCommand) {
    $sdkRoots = @($env:ANDROID_SDK_ROOT, $env:ANDROID_HOME, (Join-Path $env:LOCALAPPDATA 'Android\Sdk')) |
        Where-Object { $_ }
    $adbPath = $sdkRoots |
        ForEach-Object { Join-Path $_ 'platform-tools\adb.exe' } |
        Where-Object { Test-Path $_ } |
        Select-Object -First 1
    if ($adbPath) {
        $env:Path = "$(Split-Path $adbPath);$env:Path"
        $adbCommand = Get-Command adb -ErrorAction SilentlyContinue
    }
}

if ($Target -eq 'android-device') {
    if (-not $adbCommand) {
        throw 'ADB no esta disponible. Instala Android SDK Platform-Tools o configura ANDROID_SDK_ROOT.'
    }
    $deviceList = & $adbCommand.Source devices
    if (-not ($deviceList | Where-Object { $_ -match '^\S+\s+device$' })) {
        throw 'No se detecta un telefono autorizado. Conectalo por USB, activa Depuracion USB y acepta el permiso en el telefono.'
    }
}

$tunnel = Start-Process ssh -NoNewWindow -PassThru -ArgumentList @(
    '-N', '-L', "$GatewayPort`:127.0.0.1:3000", $Server
)

Write-Host 'Ingresa la contrasena SSH si se solicita. Esperando el tunel a FloCI...'
for ($attempt = 0; $attempt -lt 15; $attempt++) {
    if (Test-NetConnection 127.0.0.1 -Port $GatewayPort -InformationLevel Quiet) {
        break
    }
    Start-Sleep -Seconds 1
}

if (-not (Test-NetConnection 127.0.0.1 -Port $GatewayPort -InformationLevel Quiet)) {
    Stop-Process -Id $tunnel.Id -ErrorAction SilentlyContinue
    throw "No se pudo abrir el tunel al Gateway de FloCI en el puerto $GatewayPort."
}

try {
    switch ($Target) {
        'android-emulator' {
            flutter run "--dart-define=API_BASE_URL=http://10.0.2.2:$GatewayPort"
        }
        'android-device' {
            & $adbCommand.Source reverse "tcp:$GatewayPort" "tcp:$GatewayPort"
            if ($LASTEXITCODE -ne 0) {
                throw 'No se pudo crear adb reverse. Revisa la conexion USB y autoriza el equipo en Android.'
            }
            flutter run "--dart-define=API_BASE_URL=http://127.0.0.1:$GatewayPort"
        }
        'windows' {
            flutter run -d windows "--dart-define=API_BASE_URL=http://127.0.0.1:$GatewayPort"
        }
    }
}
finally {
    Stop-Process -Id $tunnel.Id -ErrorAction SilentlyContinue
}
