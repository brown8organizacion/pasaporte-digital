@echo off
setlocal
cd /d %~dp0

echo Iniciando servidor en: %cd%
echo Abre: http://localhost:8080/index.html

python -m http.server 8080
if errorlevel 1 (
  py -m http.server 8080
)

