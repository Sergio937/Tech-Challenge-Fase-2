# ============================
# Stage 1 — Builder
# ============================
FROM alpine:3.19 AS builder

WORKDIR /app

# Instala Python + pip + dependências de compilação
RUN apk add --no-cache \
    python3 \
    py3-pip \
    gcc \
    musl-dev \
    libffi-dev \
    openssl-dev \
    postgresql-dev

# Copia apenas requirements
COPY requirements.txt .

# Instala dependências no diretório /install
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ============================
# Stage 2 — Final
# ============================
FROM alpine:3.19

WORKDIR /app

# Instala Python de runtime e libpq + curl (necessário para o healthcheck)
RUN apk add --no-cache \
    python3 \
    py3-pip \
    libpq \
    curl

    
# 🔥 ESSENCIAL: faz Python enxergar libs instaladas no build
ENV PYTHONPATH="/usr/local/lib/python3.11/site-packages"

# Copia libs instaladas
COPY --from=builder /install /usr/local

# Copia código da aplicação
COPY . .

# Cria grupo e usuário restrito sem shell de login
RUN addgroup -S appgroup \
    && adduser -S -G appgroup -h /app -s /sbin/nologin appuser

USER appuser

EXPOSE 8005

# ================
# HEALTHCHECK
# ================
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -fs http://127.0.0.1:8005/health || exit 1

CMD ["gunicorn", "-b", "0.0.0.0:8005", "app:app"]