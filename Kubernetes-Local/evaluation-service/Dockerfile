# ============================
# Stage 1 — Builder
# ============================
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Dependências para CGO off
RUN apk add --no-cache git

# Copia o projeto inteiro (incluindo go.mod quebrado)
COPY . .

# Limpa e ajusta dependências
RUN go mod tidy

# Compila binário estático
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o evaluation-service

# ============================
# Stage 2 — Final
# ============================
FROM alpine:3.19

WORKDIR /app

# Copia binário
COPY --from=builder /app/evaluation-service .

# Instala curl e cria usuário restrito sem shell de login
RUN apk add --no-cache curl \
    && addgroup -S appgroup \
    && adduser -S -G appgroup -h /app -s /sbin/nologin appuser

# Troca para usuário restrito
USER appuser

# Porta de execução
EXPOSE 8004

# ================
# HEALTHCHECK
# ================
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
  CMD curl -fs http://127.0.0.1:8004/health || exit 1

CMD ["./evaluation-service"]
