# ==========================
#   Stage 1 — Builder
# ==========================
FROM alpine:3.19 AS builder

WORKDIR /app

# Dependências necessárias para compilar libs Python
RUN apk add --no-cache \
    python3 \
    python3-dev \
    py3-pip \
    build-base \
    postgresql-dev

COPY requirements.txt .

# instala libs já compiladas dentro de /usr/local
RUN pip install --no-cache-dir --prefix=/usr/local -r requirements.txt


# ==========================
#   Stage 2 — Runtime
# ==========================
FROM alpine:3.19

WORKDIR /app

# Apenas runtime — sem ferramentas de build
RUN apk add --no-cache \
    python3 \
    py3-pip \
    curl \
    libpq

# 🔥 ESSENCIAL: faz Python enxergar libs instaladas no build
ENV PYTHONPATH="/usr/local/lib/python3.11/site-packages"

# Copia o Python + libs do builder
COPY --from=builder /usr/local /usr/local

# Copia o código da aplicação
COPY . .

# Cria grupo e usuário restrito sem shell de login
RUN addgroup -S appgroup \
    && adduser -S -G appgroup -h /app -s /sbin/nologin appuser

USER appuser

EXPOSE 8003

# ================
# HEALTHCHECK
# ================
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -fs http://127.0.0.1:8003/health || exit 1

CMD ["gunicorn", "-b", "0.0.0.0:8003", "app:app"]
