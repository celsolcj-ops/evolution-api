# Estágio 1: Builder - Usa uma imagem Debian completa para garantir as dependências
FROM node:20-bookworm AS builder

# Instala as dependências de sistema essenciais, incluindo as para o Chromium/Baileys
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    git \
    curl \
    bash \
    dos2unix \
    ffmpeg \
    # Dependências do motor do WhatsApp (headless browser)
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libc6 \
    libcairo2 \
    libcups2 \
    libdbus-1-3 \
    libexpat1 \
    libfontconfig1 \
    libgbm1 \
    libgcc1 \
    libglib2.0-0 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libstdc++6 \
    libx11-6 \
    libx11-xcb1 \
    libxcb1 \
    libxcomposite1 \
    libxcursor1 \
    libxdamage1 \
    libxext6 \
    libxfixes3 \
    libxi6 \
    libxrandr2 \
    libxrender1 \
    libxss1 \
    libxtst6 \
    lsb-release \
    xdg-utils

WORKDIR /evolution

COPY ./package.json ./tsconfig.json ./
RUN npm install --legacy-peer-deps

COPY . .

RUN npm run build


# Estágio 2: Final - Usa uma imagem slim para manter o tamanho reduzido, mas herda o necessário
FROM node:20-bookworm-slim AS final

# Instala apenas as dependências de runtime necessárias
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    bash \
    openssl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV TZ=America/Sao_Paulo
WORKDIR /evolution

# Copia os artefatos do estágio de build
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/.chromium ./.chromium 

# --- A CONFIGURAÇÃO DEFINITIVA ---
# Embutindo todas as variáveis de conexão para contornar o problema da Railway.
# A aplicação agora nascerá sabendo onde encontrar o Postgres e o Redis.
ENV DATABASE_URL="postgresql://postgres:rSaBjTGSCzGctqabjulrWRwmmUVudUzV@postgres-d2dp.railway.internal:5432/railway"
ENV DATABASE_PROVIDER=postgresql
ENV CACHE_REDIS_URI="redis://default:chRsbo~z5gpQDWvDnFIJUo2a0xjzQiTf@redis.railway.internal:6379"
ENV CACHE_REDIS_ENABLED=true
ENV CACHE_REDIS_SAVE_INSTANCES=true

EXPOSE 8080

CMD ["npm", "run", "start:prod"]
