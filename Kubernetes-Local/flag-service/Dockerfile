# -----------------------------
# STAGE 1: Build environment
# -----------------------------
FROM python:3.11-slim AS builder

WORKDIR /app

# Instala dependências necessárias para compilar psycopg2
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copia requirements primeiro (para aproveitar cache)
COPY requirements.txt .

# Instala dependências no builder
RUN pip install --prefix=/install -r requirements.txt


# -----------------------------
# STAGE 2: Runtime Image
# -----------------------------
FROM python:3.11-slim

WORKDIR /app

# Instalar dependências mínimas do sistema
RUN apt-get update && apt-get install -y \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar dependências já instaladas
COPY --from=builder /install /usr/local

# Copiar o código da aplicação
COPY . .

# Cria grupo e usuário restrito sem shell de login (Debian style)
RUN groupadd appgroup \
    && useradd -r -g appgroup -d /app -s /usr/sbin/nologin appuser

USER appuser

# Porta padrão do serviço
EXPOSE 8002

# ================
# HEALTHCHECK
# ================
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -fs http://127.0.0.1:8002/health || exit 1

# Comando de execução em produção
CMD ["gunicorn", "--bind", "0.0.0.0:8002", "app:app"]
