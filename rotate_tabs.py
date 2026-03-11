#!/usr/bin/env python3

"""
Script para rotação automática de abas do Firefox
Usa a API do sistema para alternar entre abas abertas
"""

import time
import subprocess
import json
import requests
import os
import signal
import sys

class TabRotator:
    def __init__(self, config_url="http://localhost:5000/api/config"):
        self.config_url = config_url
        self.current_tab = 0
        self.tabs = []
        self.running = True
        self.rotation_interval = 300  # 5 minutos padrão
        
        # Configurar handler para sinal de parada
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def signal_handler(self, signum, frame):
        print(f"Recebido sinal {signum}, parando rotação...")
        self.running = False
    
    def load_config(self):
        """Carregar configuração das abas"""
        try:
            response = requests.get(self.config_url, timeout=10)
            if response.status_code == 200:
                data = response.json()
                self.tabs = [tab for tab in data.get('tabs', []) if tab.get('active', True)]
                print(f"Carregadas {len(self.tabs)} abas ativas")
                return True
            else:
                print(f"Erro ao carregar configuração: {response.status_code}")
                return False
        except Exception as e:
            print(f"Erro ao conectar com API: {e}")
            return False
    
    def switch_to_tab(self, index):
        """Alternar para aba específica usando xdotool"""
        try:
            # Obter lista de janelas do Firefox
            result = subprocess.run(['xdotool', 'search', '--class', 'firefox'], 
                                  capture_output=True, text=True)
            
            if result.returncode != 0:
                print("Nenhuma janela Firefox encontrada")
                return False
            
            window_ids = result.stdout.strip().split('\n')
            if not window_ids or window_ids[0] == '':
                print("Nenhuma janela Firefox encontrada")
                return False
            
            # Focar na primeira janela Firefox
            window_id = window_ids[0]
            subprocess.run(['xdotool', 'windowactivate', window_id])
            
            # Alternar para aba usando Ctrl+Tab
            for i in range(index + 1):
                subprocess.run(['xdotool', 'key', 'Ctrl+Tab'])
                time.sleep(0.1)
            
            return True
            
        except Exception as e:
            print(f"Erro ao alternar aba: {e}")
            return False
    
    def show_notification(self, message):
        """Mostrar notificação na tela"""
        try:
            subprocess.run(['notify-send', 'CrediVision', message], 
                         capture_output=True)
        except:
            pass  # Ignorar se notify-send não estiver disponível
    
    def rotate(self):
        """Executar rotação de abas"""
        if not self.tabs:
            print("Nenhuma aba para rotacionar")
            return
        
        if len(self.tabs) == 1:
            print("Apenas uma aba, não é necessário rotacionar")
            return
        
        tab = self.tabs[self.current_tab]
        print(f"Rotacionando para: {tab['name']}")
        
        # Alternar para aba
        if self.switch_to_tab(self.current_tab):
            self.show_notification(f"Aba: {tab['name']}")
        
        # Avançar para próxima aba
        self.current_tab = (self.current_tab + 1) % len(self.tabs)
    
    def run(self):
        """Executar rotação contínua"""
        print("Iniciando rotador de abas CrediVision")
        print("Pressione Ctrl+C para parar")
        
        # Carregar configuração inicial
        if not self.load_config():
            print("Falha ao carregar configuração inicial")
            return
        
        # Aguardar um momento antes de começar
        time.sleep(5)
        
        # Loop de rotação
        while self.running:
            try:
                # Recarregar configuração periodicamente
                if int(time.time()) % 60 == 0:  # A cada minuto
                    self.load_config()
                
                # Executar rotação
                self.rotate()
                
                # Aguardar próximo ciclo
                time.sleep(self.rotation_interval)
                
            except KeyboardInterrupt:
                break
            except Exception as e:
                print(f"Erro durante rotação: {e}")
                time.sleep(5)
        
        print("Rotador de abas parado")

if __name__ == "__main__":
    # Verificar dependências
    try:
        subprocess.run(['xdotool', '--version'], 
                      capture_output=True, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("ERRO: xdotool não está instalado!")
        print("Instale com: sudo apt install xdotool")
        sys.exit(1)
    
    # Verificar argumentos
    interval = 300  # padrão 5 minutos
    if len(sys.argv) > 1:
        try:
            interval = int(sys.argv[1])
            print(f"Usando intervalo de {interval} segundos")
        except ValueError:
            print("Intervalo inválido, usando 300 segundos")
    
    # Criar e executar rotador
    rotator = TabRotator()
    rotator.rotation_interval = interval
    rotator.run()
