# ── Base ──────────────────────────────────────────────────────────────────────
FROM ubuntu:22.04

LABEL maintainer="Sistema Kiosk"
LABEL description="Kiosk display system with Flask admin interface"

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV DISPLAY=:0

# ── System packages ───────────────────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-dev \
    firefox \
    xvfb \
    x11vnc \
    openbox \
    xdotool \
    wget curl ca-certificates \
    fonts-liberation fonts-noto \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Python dependencies ───────────────────────────────────────────────────────
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir -r /tmp/requirements.txt

# ── GeckoDriver (Selenium) ────────────────────────────────────────────────────
RUN GECKO_VER=$(curl -s https://api.github.com/repos/mozilla/geckodriver/releases/latest \
      | grep tag_name | cut -d'"' -f4) \
    && wget -q "https://github.com/mozilla/geckodriver/releases/download/${GECKO_VER}/geckodriver-${GECKO_VER}-linux64.tar.gz" \
    && tar -xzf geckodriver-*.tar.gz -C /usr/local/bin/ \
    && rm geckodriver-*.tar.gz \
    || echo "GeckoDriver download failed — Selenium fallback will be used"

# ── App files ─────────────────────────────────────────────────────────────────
WORKDIR /app
COPY app/ /app/
COPY scripts/ /scripts/

# ── Data directory ────────────────────────────────────────────────────────────
RUN mkdir -p /data /media
VOLUME ["/data", "/media"]

# ── Entrypoint ────────────────────────────────────────────────────────────────
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["/entrypoint.sh"]
