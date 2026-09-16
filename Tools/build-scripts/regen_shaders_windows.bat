@echo off
rem 用与主构建一致的 xmake 配置构建 shaderc-cli，再生成全部嵌入着色器
rem （含 dxbc/dxil；wgsl 需 tint，跳过）。
setlocal

set SCRIPT_DIR=%~dp0
set BUILD_MODE=%~1
if "%BUILD_MODE%"=="" set BUILD_MODE=release
if /I "%BUILD_MODE%"=="--debug" set BUILD_MODE=debug
if /I "%BUILD_MODE%"=="-d" set BUILD_MODE=debug
if /I "%BUILD_MODE%"=="--release" set BUILD_MODE=release
if /I "%BUILD_MODE%"=="-r" set BUILD_MODE=release

pushd "%SCRIPT_DIR%..\..\Tools\bgfx"
xmake f -c -p windows -a x64 -m release -y
if errorlevel 1 exit /b 1
xmake -j8 shaderc-cli
if errorlevel 1 exit /b 1
for /f "delims=" %%i in ('dir /s /b "%SCRIPT_DIR%..\..\Source\3rdParty\bgfx\build\windows\shaderc-cli.exe" 2^>nul') do set TOOL=%%i
popd

if "%TOOL%"=="" (
	echo shaderc-cli.exe not found >&2
	exit /b 1
)

bash "%SCRIPT_DIR%..\ShaderGen\buildShaderWindows.sh" "%TOOL%"
if errorlevel 1 exit /b 1
exit /b 0
