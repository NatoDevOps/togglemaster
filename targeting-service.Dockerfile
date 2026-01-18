# ====== STAGE 1: BUILD ======
FROM python:3.11-slim AS builder

WORKDIR /app

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copiar requirements
COPY requirements.txt .

# Instalar dependências Python em um diretório específico
RUN pip install --no-cache-dir --user -r requirements.txt

# ====== STAGE 2: RUNTIME ======
FROM python:3.11-slim

WORKDIR /app

# Instalar apenas ferramentas de runtime necessárias
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copiar dependências do estágio anterior
COPY --from=builder /root/.local /home/appuser/.local

# Copiar código da aplicação
COPY db/ ./db/
COPY app.py .

# Criar usuário não-root
RUN groupadd -g 1000 appuser && \
    useradd -m -u 1000 -g appuser appuser && \
    chown -R appuser:appuser /app

USER appuser

# Adicionar diretório local ao PATH
ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

EXPOSE 8003

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8003/health || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:8003", "--workers", "4", "--timeout", "30", "--access-logfile", "-", "--error-logfile", "-", "app:app"]
