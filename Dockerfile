# Bright DAST entrypoint Dockerfile
# Root-cause fix: the build system invokes `docker build .` and requires a root-level Dockerfile.
# Delegate to the maintained production-like runtime definition.
FROM python:3.13.1-slim-bookworm

LABEL org.opencontainers.image.title="Sentry"
LABEL org.opencontainers.image.description="Sentry production-like runtime image for DAST/security scanning"

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_NO_CACHE=1 \
    UV_PROJECT_ENVIRONMENT=/.venv \
    PATH="/.venv/bin:$PATH" \
    NODE_ENV=production \
    DJANGO_SETTINGS_MODULE=sentry.conf.server \
    SENTRY_CONF=/etc/sentry \
    GRPC_POLL_STRATEGY=epoll1

WORKDIR /usr/src/sentry

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    curl \
    git \
    gnupg \
    gcc \
    g++ \
    libc6-dev \
    libpq-dev \
    libxml2-dev \
    libxslt1-dev \
    libjpeg62-turbo-dev \
    zlib1g-dev \
    libmagic1 \
    libxmlsec1 \
    libxmlsec1-openssl \
    libssl-dev \
    libffi-dev \
    pkg-config \
    imagemagick \
    ghostscript \
    ffmpeg \
    poppler-utils \
    wkhtmltopdf \
    libmagic-mgc \
    tini \
  && rm -rf /var/lib/apt/lists/*

RUN python3 -m pip install --no-cache-dir uv \
 && python3 -m venv /.venv

COPY pyproject.toml uv.lock package.json pnpm-lock.yaml ./
RUN uv sync --frozen --no-install-project

RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get update && apt-get install -y --no-install-recommends nodejs \
  && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@10.30.2 --activate

COPY . .

RUN pnpm install --frozen-lockfile \
  && NODE_ENV=production pnpm run build

RUN python3 -m tools.fast_editable --path . \
 && python3 -m compileall -q src/

# Provide default self-hosted config files where Sentry expects them.
# The runtime can still override these via env vars or by mounting replacements.
RUN mkdir -p /etc/sentry \
 && cp /usr/src/sentry/self-hosted/config.yml /etc/sentry/config.yml \
 && cp /usr/src/sentry/self-hosted/sentry.conf.py /etc/sentry/sentry.conf.py

EXPOSE 9000
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["uv", "run", "granian", "--interface", "asgi", "--host", "0.0.0.0", "--port", "9000", "sentry.asgi:application"]
