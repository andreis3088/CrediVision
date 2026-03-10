#!/usr/bin/env python3
"""
Teste simples das funcionalidades admin
"""

import requests
import json

BASE_URL = "http://localhost:5000"

def test_basic_access():
    """Testa acesso básico às páginas"""
    
    print("🔍 Testando acesso às páginas...")
    
    # Testar página de login
    try:
        response = requests.get(f"{BASE_URL}/login")
        print(f"✅ Login page: {response.status_code}")
    except Exception as e:
        print(f"❌ Login page error: {e}")
        return False
    
    # Testar página de display
    try:
        response = requests.get(f"{BASE_URL}/display")
        print(f"✅ Display page: {response.status_code}")
    except Exception as e:
        print(f"❌ Display page error: {e}")
        return False
    
    # Testar API
    try:
        response = requests.get(f"{BASE_URL}/api/config")
        print(f"✅ API config: {response.status_code}")
        if response.status_code == 200:
            data = response.json()
            print(f"   📊 Abas encontradas: {len(data.get('tabs', []))}")
    except Exception as e:
        print(f"❌ API error: {e}")
        return False
    
    return True

def test_manual_login():
    """Testa login manual via sessão"""
    
    print("\n🔐 Testando login manual...")
    
    session = requests.Session()
    
    # Obter página de login
    try:
        response = session.get(f"{BASE_URL}/login")
        print(f"✅ Página de login carregada: {response.status_code}")
    except Exception as e:
        print(f"❌ Erro ao carregar login: {e}")
        return False
    
    # Tentar login
    try:
        login_data = {
            "username": "admin",
            "password": "admin123"
        }
        response = session.post(f"{BASE_URL}/login", data=login_data)
        print(f"📝 Login POST: {response.status_code}")
        print(f"📍 Location: {response.headers.get('location', 'N/A')}")
        
        # Verificar se foi redirecionado
        if response.status_code == 302:
            # Seguir redirecionamento
            dashboard_response = session.get(f"{BASE_URL}/dashboard")
            print(f"✅ Dashboard após login: {dashboard_response.status_code}")
            
            if "Dashboard" in dashboard_response.text:
                print("✅ Dashboard carregado com sucesso!")
                return True
            else:
                print("❌ Dashboard não contém conteúdo esperado")
                return False
        else:
            print(f"❌ Login não redirecionou. Status: {response.status_code}")
            print("Resposta:", response.text[:200])
            return False
            
    except Exception as e:
        print(f"❌ Erro no login: {e}")
        return False

if __name__ == "__main__":
    print("🚀 Teste Simples do CrediVision")
    print("=" * 40)
    
    # Teste básico
    if test_basic_access():
        print("\n✅ Testes básicos passaram")
    else:
        print("\n❌ Testes básicos falharam")
    
    # Teste de login
    if test_manual_login():
        print("\n✅ Login funcionando")
    else:
        print("\n❌ Login com problemas")
    
    print("\n🏁 Testes concluídos")
