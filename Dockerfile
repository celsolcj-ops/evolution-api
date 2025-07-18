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
    ca-certificates fonts-liberation libasound2 libatk-bridge2.0-0 libatk1.0-0 \
    libc6 libcairo2 libcups2 libdbus-1-3 libexpat1 libfontconfig1 libgbm1 \
    libgcc1 libglib2.0-0 libgtk-3-0 libnspr4 libnss3 libpango-1.0-0 \
    libpangocairo-1.0-0 libstdc++6 libx11-6 libx11-xcb1 libxcb1 \
    libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 libxi6 \
    libxrandr2 libxrender1 libxss1 libxtst6 lsb-release xdg-utils

WORKDIR /evolution

COPY ./package.json ./tsconfig.json ./
RUN npm install --legacy-peer-deps

# Garante que a pasta de cache do puppeteer exista antes de copiar o código
ENV PUPPETEER_CACHE_DIR=/.cache/puppeteer
RUN npx @puppeteer/browsers install chromium

COPY . .

# Gera o cliente do Prisma antes de compilar a aplicação
# O caminho correto para o schema deve ser relativo à pasta copiada
RUN npx prisma generate --schema ./prisma/schema.prisma

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
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /.cache/puppeteer ./.cache/puppeteer

EXPOSE 8080

# Comando final e robusto para iniciar a aplicação
ENTRYPOINT ["/bin/bash", "-c", ". ./Docker/scripts/deploy_database.sh && npm run start:prod"]
