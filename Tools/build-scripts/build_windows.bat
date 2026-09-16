set SCRIPT_DIR=%~dp0
set BUILD_MODE=%~1
if "%BUILD_MODE%"=="" set BUILD_MODE=debug
if /I "%BUILD_MODE%"=="--debug" set BUILD_MODE=debug
if /I "%BUILD_MODE%"=="-d" set BUILD_MODE=debug
if /I "%BUILD_MODE%"=="--release" set BUILD_MODE=release
if /I "%BUILD_MODE%"=="-r" set BUILD_MODE=release
if /I "%BUILD_MODE%"=="release" (
	set MSBUILD_CONFIGURATION=Release
) else if /I "%BUILD_MODE%"=="debug" (
	set MSBUILD_CONFIGURATION=Debug
) else (
	echo Usage: %~nx0 [debug^|release]
	exit /b 1
)

call "%SCRIPT_DIR%build_lib_windows.bat" %BUILD_MODE%
if errorlevel 1 exit /b %errorlevel%

call "%SCRIPT_DIR%regen_shaders_windows.bat" %BUILD_MODE%
if errorlevel 1 exit /b %errorlevel%

rem 应用目标由 xmake 构建（取代 Dora.vcxproj/Dora.sln）
pushd "%SCRIPT_DIR%..\..\Projects\Windows"
xmake f -c -p windows -a x86 -m %BUILD_MODE% -y
if errorlevel 1 exit /b 1
xmake -j8 dora
if errorlevel 1 exit /b 1
popd

echo Built APP in 'Projects\Windows\build\%BUILD_MODE%'
if errorlevel 1 exit /b %errorlevel%

echo Built APP in 'Projects\Windows\build\%MSBUILD_CONFIGURATION%'
