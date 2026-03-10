@echo off
REM Script para Criar/Resetar Usuário Admin - CrediVision (Windows)
REM Uso: create_admin.bat [nome_usuario] [senha]

setlocal enabledelayedexpansion

echo ╔══════════════════════════════════════════════════════════════╗
echo ║               CRIAÇÃO DE USUÁRIO ADMIN - CREDIVISION               ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.

REM Configurar variáveis
set DEFAULT_USER=admin
set DEFAULT_PASSWORD=admin123
set DATA_DIR=%USERPROFILE%\Documents\kiosk-data
set USERS_FILE=%DATA_DIR%\users.json

REM Parâmetros de entrada
set USERNAME=%1
if "%USERNAME%"=="" set USERNAME=%DEFAULT_USER%

set PASSWORD=%2
if "%PASSWORD%"=="" set PASSWORD=%DEFAULT_PASSWORD%

echo [INFO] Configuração:
echo    👤 Usuário: %USERNAME%
echo    🔑 Senha: %PASSWORD%
echo    📁 Arquivo: %USERS_FILE%
echo.

REM Verificar se Python está disponível
python --version >nul 2>&1
if %errorlevel% neq 0 (
    py --version >nul 2>&1
    if %errorlevel% neq 0 (
        echo [ERROR] Python não encontrado. Instale Python primeiro.
        pause
        exit /b 1
    ) else (
        set PYTHON_CMD=py
    )
) else (
    set PYTHON_CMD=python
)

echo [INFO] Python encontrado: %PYTHON_CMD%

REM Verificar se o diretório de dados existe
if not exist "%DATA_DIR%" (
    echo [WARNING] Diretório de dados não encontrado. Criando...
    mkdir "%DATA_DIR%"
)

REM Verificar se o arquivo users.json existe
if not exist "%USERS_FILE%" (
    echo [WARNING] Arquivo users.json não encontrado. Criando...
    echo [] > "%USERS_FILE%"
)

REM Função para criar usuário admin
echo [INFO] Criando usuário admin: %USERNAME%

REM Criar script Python temporário
echo import json > temp_create_admin.py
echo import sys >> temp_create_admin.py
echo. >> temp_create_admin.py
echo # Ler arquivo atual >> temp_create_admin.py
echo try: >> temp_create_admin.py
echo     with open(r'%USERS_FILE%', 'r') as f: >> temp_create_admin.py
echo         users = json.load(f) >> temp_create_admin.py
echo except (FileNotFoundError, json.JSONDecodeError): >> temp_create_admin.py
echo     users = [] >> temp_create_admin.py
echo. >> temp_create_admin.py
echo # Remover usuário admin existente (se houver) >> temp_create_admin.py
echo users = [u for u in users if u.get('username') != '%USERNAME%'] >> temp_create_admin.py
echo. >> temp_create_admin.py
echo # Gerar hash da senha >> temp_create_admin.py
echo import hashlib >> temp_create_admin.py
echo password_hash = hashlib.sha256(f"kiosk_salt_2024%PASSWORD%".encode()).hexdigest() >> temp_create_admin.py
echo. >> temp_create_admin.py
echo # Gerar timestamp >> temp_create_admin.py
echo from datetime import datetime >> temp_create_admin.py
echo timestamp = datetime.utcnow().isoformat() + 'Z' >> temp_create_admin.py
echo. >> temp_create_admin.py
echo # Adicionar novo usuário admin >> temp_create_admin.py
echo new_user = { >> temp_create_admin.py
echo     "id": max([u.get('id', 0) for u in users] + [0]) + 1, >> temp_create_admin.py
echo     "username": "%USERNAME%", >> temp_create_admin.py
echo     "password_hash": password_hash, >> temp_create_admin.py
echo     "role": "admin", >> temp_create_admin.py
echo     "created_at": timestamp >> temp_create_admin.py
echo } >> temp_create_admin.py
echo users.append(new_user) >> temp_create_admin.py
echo. >> temp_create_admin.py
echo # Salvar arquivo >> temp_create_admin.py
echo with open(r'%USERS_FILE%', 'w') as f: >> temp_create_admin.py
echo     json.dump(users, f, indent=2, ensure_ascii=False) >> temp_create_admin.py
echo. >> temp_create_admin.py
echo print(f"✅ Usuário '{%USERNAME%}' criado com sucesso!") >> temp_create_admin.py
echo print(f"📊 Total de usuários: {len(users)}") >> temp_create_admin.py

REM Executar script Python
%PYTHON_CMD% temp_create_admin.py

if %errorlevel% equ 0 (
    echo [INFO] ✅ Usuário admin criado com sucesso!
    echo [INFO] 📊 Arquivo atualizado: %USERS_FILE%
) else (
    echo [ERROR] ❌ Falha ao criar usuário admin
    del temp_create_admin.py
    pause
    exit /b 1
)

REM Limpar arquivo temporário
del temp_create_admin.py

echo.
echo 🎉 Operação concluída!
echo.
echo 📋 Acesso ao sistema:
echo    🌐 URL: http://localhost:5000
echo    👤 Usuário: %USERNAME%
echo    🔑 Senha: %PASSWORD%
echo.
echo ⚠️  Lembre-se de trocar a senha após o primeiro acesso!

pause
