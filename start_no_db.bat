@echo off
REM Script de Inicialização - CrediVision SEM BANCO DE DADOS

echo 🚀 Iniciando CrediVision (SEM BANCO DE DADOS)
echo ==========================================

REM Criar diretórios
echo [INFO] Criando estrutura de diretórios...
if not exist "%USERPROFILE%\Documents\kiosk-data" mkdir "%USERPROFILE%\Documents\kiosk-data"
if not exist "%USERPROFILE%\Documents\kiosk-media" mkdir "%USERPROFILE%\Documents\kiosk-media"

echo [INFO] Diretórios criados:
echo    📁 %USERPROFILE%\Documents\kiosk-data - Dados do sistema
echo    📁 %USERPROFILE%\Documents\kiosk-media - Arquivos de mídia

REM Verificar Python
echo [INFO] Verificando Python...
python --version >nul 2>&1
if %errorlevel% == 0 (
    echo [INFO] Python encontrado
    set PYTHON_CMD=python
) else (
    py --version >nul 2>&1
    if %errorlevel% == 0 (
        echo [INFO] Python encontrado
        set PYTHON_CMD=py
    ) else (
        echo [ERROR] Python não encontrado. Instale Python primeiro.
        pause
        exit /b 1
    )
)

REM Instalar dependências
echo [INFO] Instalando dependências Python...
if exist requirements.txt (
    %PYTHON_CMD% -m pip install -r requirements.txt
    echo [INFO] Dependências instaladas
) else (
    echo [WARNING] requirements.txt não encontrado
)

REM Iniciar aplicação
echo [INFO] Iniciando aplicação...
echo [INFO] Acessível em: http://localhost:5000
echo [INFO] Login: admin / admin123
echo.

%PYTHON_CMD% app_no_db.py

pause
