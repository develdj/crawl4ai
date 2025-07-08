FROM nvcr.io/nvidia/l4t-base:r36.2.0

ARG C4AI_VER=0.6.0
ARG APP_HOME=/app
ARG GITHUB_REPO=https://github.com/unclecode/crawl4ai.git
ARG GITHUB_BRANCH=main
ARG USE_LOCAL=true
ARG PYTHON_VERSION=3.10
ARG INSTALL_TYPE=default
ARG ENABLE_GPU=false
ARG TARGETARCH=arm64

ENV C4AI_VERSION=$C4AI_VER
ENV PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    DEBIAN_FRONTEND=noninteractive \
    REDIS_HOST=localhost \
    REDIS_PORT=6379 \
    PATH="/usr/local/bin:$PATH"

LABEL maintainer="unclecode" \
      description="🔥🕷️ Crawl4AI: Open-source LLM Friendly Web Crawler & Scraper" \
      version="1.0" \
      c4ai.version=$C4AI_VER

# ----------------------
# 🔧 System Dependencies
# ----------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3-pip python3-dev python3-venv \
    build-essential curl wget git cmake pkg-config \
    libjpeg-dev libglib2.0-0 libnss3 libnspr4 \
    libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 \
    libdbus-1-3 libxcb1 libxkbcommon0 libx11-6 \
    libxcomposite1 libxdamage1 libxext6 libxfixes3 \
    libxrandr2 libgbm1 libpango-1.0-0 libcairo2 \
    libasound2 libatspi2.0-0 redis-server supervisor \
    libopenblas-dev \
 && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN ln -s /usr/bin/python3 /usr/bin/python

# ----------------------
# 🧪 Python Setup
# ----------------------
RUN python3 -m pip install --upgrade pip setuptools wheel


# ----------------------
# 👤 Create Non-root User
# ----------------------
RUN groupadd -r appuser && useradd -r -g appuser -m appuser

WORKDIR ${APP_HOME}
COPY . /tmp/project/

# ----------------------
# 📦 Install Python Deps
# ----------------------
COPY deploy/docker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Optional: for specific install types
RUN if [ "$INSTALL_TYPE" = "all" ]; then \
        pip install torch torchvision torchaudio \
            scikit-learn nltk transformers tokenizers && \
        python -m nltk.downloader punkt stopwords ; \
    fi

# Project-specific install
RUN if [ "$INSTALL_TYPE" = "all" ]; then \
        pip install "/tmp/project/[all]" && \
        python -m crawl4ai.model_loader ; \
    elif [ "$INSTALL_TYPE" = "torch" ]; then \
        pip install "/tmp/project/[torch]" ; \
    elif [ "$INSTALL_TYPE" = "transformer" ]; then \
        pip install "/tmp/project/[transformer]" && \
        python -m crawl4ai.model_loader ; \
    else \
        pip install "/tmp/project" ; \
    fi

# ----------------------
# 🎭 Playwright Setup
# ----------------------
RUN pip install playwright && playwright install --with-deps

# Copy browser cache for non-root use
RUN mkdir -p /home/appuser/.cache/ms-playwright && \
    cp -r /root/.cache/ms-playwright/chromium-* /home/appuser/.cache/ms-playwright/ || true && \
    chown -R appuser:appuser /home/appuser/.cache

# ----------------------
# 🕵️ crawl4ai Doctor + Setup
# ----------------------
RUN python -c "import crawl4ai; print('✅ crawl4ai ready')" && \
    python -c "from playwright.sync_api import sync_playwright; print('✅ Playwright ready')" && \
    crawl4ai-setup && crawl4ai-doctor

# ----------------------
# 🧾 Supervisor + App Files
# ----------------------
COPY deploy/docker/supervisord.conf .
COPY deploy/docker/static ${APP_HOME}/static
COPY deploy/docker/* ${APP_HOME}/

# Redis persistence
RUN mkdir -p /var/lib/redis /var/log/redis && \
    chown -R appuser:appuser /var/lib/redis /var/log/redis

# Final permission set
RUN chown -R appuser:appuser ${APP_HOME}

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD bash -c '\
    MEM=$(free -m | awk "/^Mem:/{print \$2}"); \
    if [ $MEM -lt 2048 ]; then \
        echo "⚠️ Warning: Less than 2GB RAM available!"; exit 1; \
    fi && \
    redis-cli ping > /dev/null && \
    curl -f http://localhost:11235/health || exit 1'

EXPOSE 6379

USER appuser

ENV PYTHON_ENV=production

CMD ["supervisord", "-c", "supervisord.conf"]
