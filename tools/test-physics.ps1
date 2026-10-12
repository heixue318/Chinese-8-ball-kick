$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
$bundledJdk = Get-ChildItem .tools/jdk -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if ($bundledJdk) { $env:JAVA_HOME = $bundledJdk.FullName }
if (-not $env:JAVA_HOME) { throw '请安装 Java 17 并设置 JAVA_HOME。' }
& "$env:JAVA_HOME/bin/javac.exe" -encoding UTF-8 -d .tools/test-classes app/src/main/java/com/zhongbaijieshu/app/PracticePhysics.java tools/PracticePhysicsTest.java
if ($LASTEXITCODE -ne 0) { throw '物理测试编译失败。' }
& "$env:JAVA_HOME/bin/java.exe" -cp .tools/test-classes com.zhongbaijieshu.app.PracticePhysicsTest
if ($LASTEXITCODE -ne 0) { throw '物理测试失败。' }
