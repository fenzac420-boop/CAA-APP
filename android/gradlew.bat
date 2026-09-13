@echo off
where gradle >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
  echo Gradle n'est pas installe sur ce poste. Utilisez GitHub Actions pour compiler CAA 1.0 Android.
  exit /b 1
)
gradle %*
