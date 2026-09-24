@echo off
setlocal

set BUILD_MODE=release
if /I "%~1"=="debug" set BUILD_MODE=debug
if /I "%~1"=="release" set BUILD_MODE=release

where cmake >nul 2>nul
if errorlevel 1 (
	echo cmake executable not found, unable to build SDL3 library.
	exit /b 1
)

set SCRIPT_DIR=%~dp0
set SDL_DIR=%SCRIPT_DIR%..\..\Source\3rdParty\SDL3

if /I "%BUILD_MODE%"=="debug" (
	set CMAKE_BUILD_TYPE=Debug
	set OUT_DIR=Lib\Windows\Debug
) else (
	set CMAKE_BUILD_TYPE=Release
	set OUT_DIR=Lib\Windows\Release
)

set BUILD_DIR=%SDL_DIR%\build\cmake-windows-x86-%BUILD_MODE%

cmake -S "%SDL_DIR%" -B "%BUILD_DIR%" ^
	-DCMAKE_BUILD_TYPE=%CMAKE_BUILD_TYPE% ^
	-DCMAKE_POSITION_INDEPENDENT_CODE=ON ^
	-DSDL_SHARED=OFF ^
	-DSDL_STATIC=ON ^
	-DSDL_TEST_LIBRARY=OFF ^
	-DSDL_TESTS=OFF ^
	-DSDL_EXAMPLES=OFF
if errorlevel 1 exit /b %errorlevel%

cmake --build "%BUILD_DIR%" --config %CMAKE_BUILD_TYPE% -j 8
if errorlevel 1 exit /b %errorlevel%

if not exist "%SDL_DIR%\%OUT_DIR%" mkdir "%SDL_DIR%\%OUT_DIR%"

rem SDL3 names its static import library SDL3-static.lib
copy /Y "%BUILD_DIR%\SDL3-static.%CMAKE_BUILD_TYPE%.lib" "%SDL_DIR%\%OUT_DIR%\SDL3.lib" >nul 2>nul
if errorlevel 1 copy /Y "%BUILD_DIR%\SDL3-static.lib" "%SDL_DIR%\%OUT_DIR%\SDL3.lib" >nul
if errorlevel 1 exit /b %errorlevel%

echo Built SDL3 library in Source\3rdParty\SDL3\%OUT_DIR%
