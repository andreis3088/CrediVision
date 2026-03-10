#!/usr/bin/env python3
"""
Script de teste para validar todas as funcionalidades admin do CrediVision
"""

import requests
import json
import time
from datetime import datetime

BASE_URL = "http://localhost:5000"
session = requests.Session()

def test_login():
    """Testa login do admin"""
    print("🔐 Testando login...")
    
    # Get login page
    response = session.get(f"{BASE_URL}/login")
    assert response.status_code == 200, "Página de login não carregou"
    
    # Submit login
    login_data = {
        "username": "admin",
        "password": "admin123"
    }
    response = session.post(f"{BASE_URL}/login", data=login_data)
    
    # Should redirect to dashboard
    assert response.status_code == 302, "Login falhou"
    assert "dashboard" in response.headers.get("location", ""), "Redirecionamento incorreto"
    
    print("✅ Login bem-sucedido")
    return True

def test_dashboard():
    """Testa carregamento do dashboard"""
    print("📊 Testando dashboard...")
    
    response = session.get(f"{BASE_URL}/dashboard")
    assert response.status_code == 200, "Dashboard não carregou"
    
    # Verifica conteúdo
    content = response.text
    assert "Dashboard" in content, "Título não encontrado"
    assert "Total de Abas" in content, "Estatísticas não encontradas"
    
    print("✅ Dashboard carregado")
    return True

def test_tabs_page():
    """Testa página de abas"""
    print("📑 Testando página de abas...")
    
    response = session.get(f"{BASE_URL}/tabs")
    assert response.status_code == 200, "Página de abas não carregou"
    
    content = response.text
    assert "Lista de Abas" in content, "Título não encontrado"
    assert "Nova Aba" in content, "Botão adicionar não encontrado"
    
    print("✅ Página de abas carregada")
    return True

def test_add_tab():
    """Testa adicionar nova aba"""
    print("➕ Testando adicionar aba...")
    
    tab_data = {
        "name": "Test Tab",
        "url": "https://example.com",
        "duration": 120
    }
    
    response = session.post(f"{BASE_URL}/tabs/add", data=tab_data)
    assert response.status_code == 302, "Falha ao adicionar aba"
    
    print("✅ Aba adicionada com sucesso")
    return True

def test_api_config():
    """Testa API de configuração"""
    print("🔌 Testando API /api/config...")
    
    response = requests.get(f"{BASE_URL}/api/config")
    assert response.status_code == 200, "API não respondeu"
    
    data = response.json()
    assert "tabs" in data, "Chave 'tabs' não encontrada"
    assert isinstance(data["tabs"], list), "Tabs deve ser uma lista"
    
    print(f"✅ API funcionando - {len(data['tabs'])} abas encontradas")
    return True

def test_users_page():
    """Testa página de usuários"""
    print("👥 Testando página de usuários...")
    
    response = session.get(f"{BASE_URL}/users")
    assert response.status_code == 200, "Página de usuários não carregou"
    
    content = response.text
    assert "Usuários Cadastrados" in content, "Título não encontrado"
    assert "admin" in content, "Usuário admin não encontrado"
    
    print("✅ Página de usuários carregada")
    return True

def test_logs_page():
    """Testa página de logs"""
    print("📋 Testando página de logs...")
    
    response = session.get(f"{BASE_URL}/logs")
    assert response.status_code == 200, "Página de logs não carregou"
    
    content = response.text
    assert "Logs de Auditoria" in content, "Título não encontrado"
    assert "Histórico de Ações" in content, "Subtítulo não encontrado"
    
    print("✅ Página de logs carregada")
    return True

def test_display_page():
    """Testa página de display"""
    print("📺 Testando página de display...")
    
    response = requests.get(f"{BASE_URL}/display")
    assert response.status_code == 200, "Página de display não carregou"
    
    content = response.text
    assert "CrediVision Kiosk" in content, "Título não encontrado"
    
    print("✅ Página de display carregada")
    return True

def run_all_tests():
    """Executa todos os testes"""
    print("🚀 Iniciando testes do CrediVision Admin")
    print("=" * 50)
    
    tests = [
        test_login,
        test_dashboard,
        test_tabs_page,
        test_add_tab,
        test_api_config,
        test_users_page,
        test_logs_page,
        test_display_page
    ]
    
    passed = 0
    failed = 0
    
    for test in tests:
        try:
            if test():
                passed += 1
            else:
                failed += 1
                print(f"❌ {test.__name__} falhou")
        except Exception as e:
            failed += 1
            print(f"❌ {test.__name__} erro: {e}")
        
        time.sleep(0.5)  # Pequena pausa entre testes
    
    print("=" * 50)
    print(f"📊 Resultados: {passed} passaram, {failed} falharam")
    
    if failed == 0:
        print("🎉 Todos os testes passaram! Sistema funcionando perfeitamente!")
    else:
        print("⚠️ Alguns testes falharam. Verifique os erros acima.")
    
    return failed == 0

if __name__ == "__main__":
    run_all_tests()
