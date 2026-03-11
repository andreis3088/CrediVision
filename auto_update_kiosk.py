#!/usr/bin/env python3

"""
Sistema de Atualização Automática do Kiosk
Monitora mudanças nas abas e atualiza o kiosk em tempo real
"""

import json
import time
import subprocess
import signal
import sys
import os
import requests
from datetime import datetime
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

class KioskAutoUpdater:
    def __init__(self, config_url="http://localhost:5000/api/config", data_dir=None):
        self.config_url = config_url
        self.data_dir = data_dir or "/home/informa/Documents/kiosk-data"
        self.running = True
        self.last_config = None
        self.kiosk_process = None
        self.update_cooldown = 10  # segundos entre atualizações
        self.last_update = 0
        
        # Configurar handlers para sinais
        signal.signal(signal.SIGTERM, self.signal_handler)
        signal.signal(signal.SIGINT, self.signal_handler)
    
    def signal_handler(self, signum, frame):
        print(f"Recebido sinal {signum}, parando atualizador...")
        self.running = False
        if self.kiosk_process:
            self.kiosk_process.terminate()
    
    def get_current_config(self):
        """Obter configuração atual da API"""
        try:
            response = requests.get(self.config_url, timeout=5)
            if response.status_code == 200:
                return response.json()
        except Exception as e:
            print(f"Erro ao obter configuração: {e}")
        return None
    
    def config_changed(self, new_config):
        """Verificar se a configuração mudou"""
        if not new_config:
            return False
        
        if not self.last_config:
            self.last_config = new_config
            return False
        
        # Comparar abas ativas
        old_tabs = sorted([tab for tab in self.last_config.get('tabs', []) if tab.get('active', True)], 
                          key=lambda x: x.get('id', 0))
        new_tabs = sorted([tab for tab in new_config.get('tabs', []) if tab.get('active', True)], 
                          key=lambda x: x.get('id', 0))
        
        # Verificar se número de abas mudou
        if len(old_tabs) != len(new_tabs):
            return True
        
        # Verificar se alguma aba mudou
        for i, (old_tab, new_tab) in enumerate(zip(old_tabs, new_tabs)):
            if (old_tab.get('name') != new_tab.get('name') or
                old_tab.get('url') != new_tab.get('url') or
                old_tab.get('duration') != new_tab.get('duration') or
                old_tab.get('content_type') != new_tab.get('content_type')):
                return True
        
        return False
    
    def show_notification(self, message):
        """Mostrar notificação do sistema"""
        try:
            subprocess.run(['notify-send', 'CrediVision', message], 
                         capture_output=True, timeout=5)
        except:
            pass  # Ignorar se notify-send não estiver disponível
    
    def log_change(self, change_type, details):
        """Registrar mudança no log"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {change_type}: {details}"
        print(log_entry)
        
        # Salvar em arquivo de log
        log_file = "/tmp/credivision_auto_update.log"
        with open(log_file, "a") as f:
            f.write(log_entry + "\n")
    
    def restart_kiosk(self):
        """Reiniciar o kiosk com nova configuração"""
        current_time = time.time()
        if current_time - self.last_update < self.update_cooldown:
            print("Aguardando cooldown de atualização...")
            return
        
        self.last_update = current_time
        
        try:
            print("Reiniciando kiosk devido a mudanças...")
            self.log_change("RESTART_KIOSK", "Atualização automática")
            
            # Parar kiosk atual
            subprocess.run(['pkill', '-f', 'simple_kiosk'], 
                         capture_output=True, timeout=10)
            
            # Aguardar um momento
            time.sleep(2)
            
            # Iniciar novo kiosk - detectar script disponível
            project_dir = "/home/informa/Documentos/CrediVision"
            kiosk_scripts = [
                "simple_kiosk_enhanced.sh",
                "simple_kiosk.sh",
                "start_kiosk.sh"
            ]
            
            kiosk_script = None
            for script in kiosk_scripts:
                script_path = os.path.join(project_dir, script)
                if os.path.exists(script_path):
                    kiosk_script = script_path
                    break
            
            if kiosk_script:
                print(f"Usando script: {kiosk_script}")
                self.kiosk_process = subprocess.Popen([
                    'sudo', '-u', 'informa', kiosk_script, 'fullscreen'
                ])
                self.show_notification("Kiosk atualizado automaticamente")
            else:
                print("Nenhum script kiosk encontrado")
                print("Scripts procurados:")
                for script in kiosk_scripts:
                    print(f"  - {os.path.join(project_dir, script)}")
                
        except Exception as e:
            print(f"Erro ao reiniciar kiosk: {e}")
    
    def check_api_changes(self):
        """Verificar mudanças via API polling"""
        while self.running:
            try:
                new_config = self.get_current_config()
                if new_config and self.config_changed(new_config):
                    self.restart_kiosk()
                
                # Aguardar antes da próxima verificação
                time.sleep(5)  # Verificar a cada 5 segundos
                
            except Exception as e:
                print(f"Erro na verificação: {e}")
                time.sleep(10)
    
    def start_file_monitoring(self):
        """Iniciar monitoramento de arquivos"""
        class TabsFileHandler(FileSystemEventHandler):
            def __init__(self, updater):
                self.updater = updater
            
            def on_modified(self, event):
                if event.is_directory:
                    return
                
                if event.src_path.endswith('tabs.json'):
                    print("Detectada mudança em tabs.json")
                    self.updater.log_change("FILE_CHANGE", "tabs.json modificado")
                    # Aguardar um momento para o arquivo ser completamente escrito
                    time.sleep(1)
                    self.updater.restart_kiosk()
        
        # Configurar observer
        event_handler = TabsFileHandler(self)
        observer = Observer()
        observer.schedule(event_handler, self.data_dir, recursive=False)
        observer.start()
        
        print(f"Monitorando arquivos em: {self.data_dir}")
        
        try:
            while self.running:
                time.sleep(1)
        except KeyboardInterrupt:
            observer.stop()
        
        observer.join()
    
    def run(self):
        """Executar o atualizador automático"""
        print("Iniciando atualizador automático do CrediVision Kiosk")
        print("Pressione Ctrl+C para parar")
        print("")
        
        # Verificar configuração inicial
        initial_config = self.get_current_config()
        if initial_config:
            self.last_config = initial_config
            active_tabs = [tab for tab in initial_config.get('tabs', []) if tab.get('active', True)]
            print(f"Configuração inicial: {len(active_tabs)} abas ativas")
        else:
            print("Não foi possível obter configuração inicial")
            return
        
        print("Métodos de detecção:")
        print("  1. API polling (a cada 5 segundos)")
        print("  2. Monitoramento de arquivos (tabs.json)")
        print("")
        
        # Iniciar monitoramento de arquivos em uma thread
        import threading
        file_thread = threading.Thread(target=self.start_file_monitoring)
        file_thread.daemon = True
        file_thread.start()
        
        # Iniciar verificação via API na thread principal
        try:
            self.check_api_changes()
        except KeyboardInterrupt:
            print("\nParando atualizador...")
        
        print("Atualizador parado")

def main():
    import argparse
    
    parser = argparse.ArgumentParser(description='Atualizador automático do CrediVision Kiosk')
    parser.add_argument('--config-url', default='http://localhost:5000/api/config',
                       help='URL da API de configuração')
    parser.add_argument('--data-dir', default='/home/informa/Documents/kiosk-data',
                       help='Diretório de dados')
    parser.add_argument('--test', action='store_true',
                       help='Modo teste - simula mudanças')
    
    args = parser.parse_args()
    
    if args.test:
        print("Modo teste - simulando mudanças...")
        updater = KioskAutoUpdater(args.config_url, args.data_dir)
        
        # Simular mudanças
        for i in range(3):
            print(f"Simulando mudança {i+1}...")
            updater.restart_kiosk()
            time.sleep(5)
        
        print("Teste concluído")
        return
    
    # Verificar dependências
    try:
        import watchdog
    except ImportError:
        print("ERRO: watchdog não está instalado!")
        print("Instale com: pip install watchdog")
        sys.exit(1)
    
    # Criar e executar atualizador
    updater = KioskAutoUpdater(args.config_url, args.data_dir)
    updater.run()

if __name__ == "__main__":
    main()
