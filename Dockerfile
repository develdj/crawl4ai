FROM nvcr.io/nvidia/l4t-base:r36.2.0
#FROM dustynv/cuda-python:r36.4.0-cu128-24.04

ARG C4AI_VER=0.6.0
ARG APP_HOME=/app
ARG GITHUB_REPO=https://github.com/unclecode/crawl4ai.git
ARG GITHUB_BRANCH=main
ARG USE_LOCAL=true
ARG PYTHON_VERSION=3.10
ARG INSTALL_TYPE=default
ARG ENABLE_GPU=true
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
        pip install https://pypi.jetson-ai-lab.io/root/pypi/+f/a10/3b5d782af5bd1/torch-2.7.1-cp310-cp310-manylinux_2_28_aarch64.whl#sha256=a103b5d782af5bd119b81dbcc7ffc6fa09904c423ff8db397a1e6ea8fd71508f \
        pip install https://pypi.jetson-ai-lab.io/root/pypi/+f/990/de4d657a41ed7/torchvision-0.22.1-cp310-cp310-manylinux_2_28_aarch64.whl#sha256=990de4d657a41ed71680cd8be2e98ebcab55371f30993dc9bd2e676441f7180e \
        pip install https://pypi.jetson-ai-lab.io/root/pypi/+f/c08/9dbfc14c5f470/torchaudio-2.7.1-cp310-cp310-manylinux_2_28_aarch64.whl#sha256=c089dbfc14c5f47091b7bf3f6bf2bbac93b86619299d04d9c102f4ad53758990 \
        pip install https://pypi.jetson-ai-lab.io/root/pypi/+f/b62/b76ad408a8214/scikit_learn-1.7.1-cp310-cp310-manylinux_2_27_aarch64.manylinux_2_28_aarch64.whl#sha256=b62b76ad408a821475b43b7bb90a9b1c9a4d8d125d505c2df0539f06d6e631b1 \
        pip install https://pypi.jetson-ai-lab.io/root/pypi/+f/4fa/26829c5b00715/nltk-3.9.1-py3-none-any.whl#sha256=4fa26829c5b00715afe3061398a8989dc643b92ce7dd93fb4585a70930d168a1 \
        pip install https://pypi.jetson-ai-lab.io/root/pypi/+f/5ab/a81c92095806b/transformers-4.53.3-py3-none-any.whl#sha256=5aba81c92095806b6baf12df35d756cf23b66c356975fb2a7fa9e536138d7c75 \
        pip install https://pypi.jetson-ai-lab.io/root/pypi/+f/834/8601d6dda43a8/tokenizers-0.21.4.dev0-cp39-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl#sha256=8348601d6dda43a8878f48f07ef356070317f24c58984deb946c3789df99563c && \
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
#RUN pip install https://pypi.jetson-ai-lab.io/root/pypi/+f/927/6c9c935fc062f/playwright-1.53.0-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl#sha256=9276c9c935fc062f51f4f5107e56420afd6d9a524348dc437793dc2e34c742e3 && playwright install --with-deps
RUN pip install https://pypi.jetson-ai-lab.io/root/pypi/+f/13a/e206c55737e8e/playwright-1.54.0-py3-none-manylinux_2_17_aarch64.manylinux2014_aarch64.whl#sha256=13ae206c55737e8e3eae51fb385d61c0312eeef31535643bb6232741b41b6fdc && playwright install --with-deps
# RUN pip install playwright

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
