@echo off
setlocal
set "MAVEN_VERSION=3.9.12"
set "MAVEN_CACHE=%USERPROFILE%\.m2\wrapper\dists\apache-maven-%MAVEN_VERSION%"
set "MAVEN_HOME=%MAVEN_CACHE%\apache-maven-%MAVEN_VERSION%"
if exist "%JAVA_HOME%\bin\java.exe" goto java_ready
for /f "usebackq delims=" %%J in (`powershell.exe -NoProfile -Command "Split-Path (Split-Path (Get-Command java).Source)"`) do set "JAVA_HOME=%%J"
:java_ready
if exist "%MAVEN_HOME%\bin\mvn.cmd" goto run

if not exist "%MAVEN_CACHE%" mkdir "%MAVEN_CACHE%"
echo Downloading Apache Maven %MAVEN_VERSION%...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $zip=Join-Path $env:TEMP 'lovespace-maven-%MAVEN_VERSION%.zip'; Invoke-WebRequest -UseBasicParsing -Uri 'https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/%MAVEN_VERSION%/apache-maven-%MAVEN_VERSION%-bin.zip' -OutFile $zip; Expand-Archive -LiteralPath $zip -DestinationPath '%MAVEN_CACHE%' -Force; Remove-Item -LiteralPath $zip -Force"
if errorlevel 1 exit /b 1

:run
call "%MAVEN_HOME%\bin\mvn.cmd" %*
exit /b %ERRORLEVEL%
