param([string]$Device = 'emulator-5554')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
Push-Location $projectRoot
try {
    # Prefer a project-local JDK 17 over Android Studio's potentially newer JBR.
    $localJdk = Get-ChildItem (Join-Path $projectRoot '.dart_tool/jdk') -Directory -ErrorAction SilentlyContinue |
        Where-Object { Test-Path (Join-Path $_.FullName 'bin/java.exe') } |
        Select-Object -First 1
    if ($localJdk) { $env:JAVA_HOME = $localJdk.FullName }
    if (-not $env:JAVA_HOME -or -not (Test-Path (Join-Path $env:JAVA_HOME 'bin/java.exe'))) {
        throw 'Install JDK 17 and set JAVA_HOME, or extract it into .dart_tool/jdk/<jdk-folder>. Gradle 8.14.4 cannot run with Java 25.'
    }
    $javaVersion = (& (Join-Path $env:JAVA_HOME 'bin/java.exe') --version 2>&1 | Out-String)
    if ($javaVersion -notmatch '(?:openjdk|java) 17\.') {
        throw "This launcher requires JDK 17. JAVA_HOME is $env:JAVA_HOME"
    }
    $sdkLine = Get-Content android/local.properties | Where-Object { $_ -match '^flutter.sdk=' } | Select-Object -First 1
    if (-not $sdkLine) { throw 'Set flutter.sdk in android/local.properties first.' }
    $flutterRoot = $sdkLine.Substring('flutter.sdk='.Length).Replace('\\', '\').Replace('\:', ':')
    $dart = Join-Path $flutterRoot 'bin/cache/dart-sdk/bin/dart.exe'
    $snapshot = Join-Path $flutterRoot 'bin/cache/flutter_tools.snapshot'
    if (-not (Test-Path $snapshot)) { throw 'Run flutter --version once to initialize the Flutter SDK.' }
    $env:TEMP = Join-Path $projectRoot 'build/task-temp'
    $env:TMP = $env:TEMP
    New-Item -ItemType Directory -Force $env:TEMP | Out-Null
    $env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
    $env:DART_SUPPRESS_ANALYTICS = 'true'
    & $dart $snapshot run --no-pub -d $Device
    if ($LASTEXITCODE -ne 0) { throw "Flutter exited with code $LASTEXITCODE" }
} finally {
    Pop-Location
}
