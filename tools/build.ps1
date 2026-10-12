$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$bundledJdk = Get-ChildItem .tools/jdk -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if ($bundledJdk) { $env:JAVA_HOME = $bundledJdk.FullName }
if (Test-Path .tools/android/platforms/android-35) { $env:ANDROID_HOME = Join-Path (Get-Location) '.tools/android' }
if (-not $env:JAVA_HOME) { throw '请安装 Java 17 并设置 JAVA_HOME。' }
if (-not $env:ANDROID_HOME) { throw '请安装 Android SDK 35 并设置 ANDROID_HOME。' }
$sdkLocation = $env:ANDROID_HOME.Replace('\', '/')
Set-Content local.properties "sdk.dir=$sdkLocation"
if (Test-Path .tools/gradle-8.9/bin/gradle.bat) {
    & .tools/gradle-8.9/bin/gradle.bat --gradle-user-home .tools/gradle-home --no-daemon --console=plain assembleDebug lintDebug
} else {
    & gradle --no-daemon --console=plain assembleDebug lintDebug
}
if ($LASTEXITCODE -ne 0) { throw 'Android 构建或检查失败。' }
