#!/usr/bin/env python3
"""
kiosk_runner.py
Script de automação do Firefox em modo kiosk.
Lê a configuração do servidor Flask e controla o navegador via selenium.
"""

import time
import json
import logging
import os
import subprocess
import signal
import sys
import urllib.request

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [KIOSK] %(levelname)s — %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/data/kiosk.log')
    ]
)
log = logging.getLogger(__name__)

ADMIN_URL = os.environ.get('ADMIN_URL', 'http://localhost:5000')
CONFIG_ENDPOINT = f"{ADMIN_URL}/api/config"
STATUS_ENDPOINT = f"{ADMIN_URL}/api/status"
DISPLAY = os.environ.get('DISPLAY', ':0')
REFRESH_INTERVAL = int(os.environ.get('CONFIG_REFRESH', '300'))  # seconds


def fetch_config() -> list:
    try:
        with urllib.request.urlopen(CONFIG_ENDPOINT, timeout=10) as r:
            data = json.loads(r.read())
            return data.get('tabs', [])
    except Exception as e:
        log.warning(f"Erro ao buscar configuração: {e}")
        return []


def report_status(tab_name: str, index: int, total: int):
    try:
        payload = json.dumps({
            'current_tab': tab_name,
            'index': index,
            'total': total,
            'timestamp': time.time()
        }).encode()
        req = urllib.request.Request(
            STATUS_ENDPOINT,
            data=payload,
            headers={'Content-Type': 'application/json'},
            method='POST'
        )
        urllib.request.urlopen(req, timeout=5)
    except Exception:
        pass


def launch_firefox_kiosk(url: str) -> subprocess.Popen:
    """Inicia Firefox em modo kiosk."""
    cmd = [
        'firefox',
        '--kiosk',
        '--no-first-run',
        '--disable-pinch',
        f'--display={DISPLAY}',
        url
    ]
    log.info(f"Abrindo Firefox kiosk: {url}")
    return subprocess.Popen(cmd, env={**os.environ, 'DISPLAY': DISPLAY})


def run_with_selenium():
    """Controla o Firefox via Selenium para alternância de abas."""
    try:
        from selenium import webdriver
        from selenium.webdriver.firefox.options import Options
        from selenium.webdriver.firefox.service import Service
    except ImportError:
        log.error("Selenium não instalado. Use: pip install selenium")
        run_without_selenium()
        return

    options = Options()
    options.add_argument('--kiosk')
    options.add_argument('--no-first-run')

    try:
        driver = webdriver.Firefox(options=options)
        driver.maximize_window()
    except Exception as e:
        log.error(f"Falha ao iniciar WebDriver: {e}")
        run_without_selenium()
        return

    log.info("Firefox Selenium iniciado com sucesso.")
    current_config_time = 0
    tabs = []

    def handle_signal(sig, frame):
        log.info("Encerrando kiosk...")
        driver.quit()
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    tab_index = 0

    while True:
        now = time.time()

        # Atualiza configuração periodicamente
        if now - current_config_time > REFRESH_INTERVAL:
            new_tabs = fetch_config()
            if new_tabs:
                tabs = new_tabs
                log.info(f"Configuração atualizada: {len(tabs)} abas.")
            current_config_time = now

        if not tabs:
            log.warning("Nenhuma aba configurada. Aguardando...")
            time.sleep(10)
            continue

        tab = tabs[tab_index % len(tabs)]
        log.info(f"[{tab_index % len(tabs) + 1}/{len(tabs)}] Exibindo: {tab['name']} → {tab['url']}")

        try:
            driver.get(tab['url'])
        except Exception as e:
            log.warning(f"Erro ao carregar {tab['url']}: {e}")

        report_status(tab['name'], tab_index % len(tabs), len(tabs))
        time.sleep(tab.get('duration', 300))
        tab_index += 1


def run_without_selenium():
    """Fallback: usa subprocess para controlar Firefox via xdotool."""
    log.info("Iniciando modo sem Selenium (xdotool fallback).")
    tabs = []
    tab_index = 0
    proc = None
    last_refresh = 0

    def handle_signal(sig, frame):
        if proc:
            proc.terminate()
        sys.exit(0)

    signal.signal(signal.SIGTERM, handle_signal)
    signal.signal(signal.SIGINT, handle_signal)

    while True:
        now = time.time()

        if now - last_refresh > REFRESH_INTERVAL or not tabs:
            new_tabs = fetch_config()
            if new_tabs:
                tabs = new_tabs
            last_refresh = now

        if not tabs:
            time.sleep(10)
            continue

        tab = tabs[tab_index % len(tabs)]
        url = tab['url']
        duration = tab.get('duration', 300)

        if proc is None or proc.poll() is not None:
            proc = launch_firefox_kiosk(url)
            time.sleep(3)
        else:
            # Muda URL via xdotool
            try:
                subprocess.run(['xdotool', 'key', '--clearmodifiers', 'ctrl+l'], check=False)
                time.sleep(0.3)
                subprocess.run(['xdotool', 'type', '--clearmodifiers', url], check=False)
                subprocess.run(['xdotool', 'key', 'Return'], check=False)
            except FileNotFoundError:
                log.warning("xdotool não encontrado. Reiniciando Firefox.")
                proc.terminate()
                proc = launch_firefox_kiosk(url)

        report_status(tab['name'], tab_index % len(tabs), len(tabs))
        log.info(f"Exibindo '{tab['name']}' por {duration}s.")
        time.sleep(duration)
        tab_index += 1


def wait_for_server(max_attempts=30):
    """Aguarda o servidor Flask estar disponível."""
    log.info(f"Aguardando servidor em {ADMIN_URL}...")
    for i in range(max_attempts):
        try:
            urllib.request.urlopen(f"{ADMIN_URL}/api/config", timeout=3)
            log.info("Servidor disponível!")
            return True
        except Exception:
            time.sleep(2)
    log.error("Servidor não disponível após timeout.")
    return False


if __name__ == '__main__':
    log.info("=== Sistema Kiosk Iniciando ===")

    if not wait_for_server():
        sys.exit(1)

    # Tenta usar Selenium; cai para modo simples se não disponível
    try:
        import selenium
        run_with_selenium()
    except ImportError:
        run_without_selenium()
