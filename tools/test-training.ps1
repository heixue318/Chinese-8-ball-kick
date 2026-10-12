$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$bundledJdk = Get-ChildItem .tools/jdk -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if ($bundledJdk) { $env:JAVA_HOME = $bundledJdk.FullName }
if (-not $env:JAVA_HOME) { throw '请安装 Java 17 并设置 JAVA_HOME。' }
$source = 'app/src/main/java/com/zhongbaijieshu/app'
& "$env:JAVA_HOME/bin/javac.exe" -encoding UTF-8 -d .tools/training-test-classes "$source/PracticePhysics.java" "$source/TrainingModel.java" "$source/AimGeometry.java" "$source/TrainingSession.java" "$source/PracticeTrainingAdapter.java" tools/TrainingTest.java
if ($LASTEXITCODE -ne 0) { throw '训练测试编译失败。' }
& "$env:JAVA_HOME/bin/java.exe" -cp .tools/training-test-classes com.zhongbaijieshu.app.TrainingTest
if ($LASTEXITCODE -ne 0) { throw '训练测试失败。' }
