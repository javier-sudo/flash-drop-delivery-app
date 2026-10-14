param(
    [ValidateSet('android-emulator', 'android-device', 'web')]
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
            if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
                throw 'ADB no esta disponible. Conecta el telefono por USB y abre Android SDK Platform-Tools.'
            }
            adb reverse "tcp:$GatewayPort" "tcp:$GatewayPort"
            flutter run "--dart-define=API_BASE_URL=http://127.0.0.1:$GatewayPort"
        }
        'web' {
            flutter run -d chrome "--dart-define=API_BASE_URL=http://127.0.0.1:$GatewayPort"
        }
    }
}
finally {
    Stop-Process -Id $tunnel.Id -ErrorAction SilentlyContinue
}
