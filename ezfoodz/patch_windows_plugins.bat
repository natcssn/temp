@echo off
REM Patch generated_plugins.cmake to remove Firebase from Windows build
REM Firebase C++ SDK is incompatible with latest MSVC STL on Windows desktop
REM Firebase is conditionally skipped in main.dart on Windows anyway

set PLUGINS_FILE=windows\flutter\generated_plugins.cmake

if not exist "%PLUGINS_FILE%" (
    echo No generated_plugins.cmake found. Run 'flutter pub get' first.
    exit /b 0
)

REM Replace firebase_auth and firebase_core entries with empty lines
powershell -NoProfile -Command "(Get-Content '%PLUGINS_FILE%') -replace '^\s*firebase_auth\s*$', '' -replace '^\s*firebase_core\s*$', '' | Set-Content '%PLUGINS_FILE%'"

echo Patched %PLUGINS_FILE% — removed Firebase native plugins from Windows build.
