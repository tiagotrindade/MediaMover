#!/bin/bash

# ==============================================================================
# Script de Criação de DMG (Inteligente)
# ==============================================================================

# Cores para o output
echo_info() { echo -e "\033[1;34m$1\033[0m"; }
echo_success() { echo -e "\033[1;32m$1\033[0m"; }
echo_error() { echo -e "\033[1;31m$1\033[0m" >&2; }

# --- Lógica Inteligente para Detetar o Nome da App ---
APP_CANDIDATE=$(find ./build/Release -maxdepth 1 -name "*.app" | head -n 1)
if [ -z "${APP_CANDIDATE}" ]; then
    echo_error "Nenhuma aplicação .app encontrada em ./build/Release. Execute ./build.sh primeiro."
    exit 1
fi

APP_NAME=$(basename "${APP_CANDIDATE}" .app)
APP_PATH="./build/Release/${APP_NAME}.app"
DMG_NAME="${APP_NAME}_v1.0.0.dmg"
# ... (restante do script igual)

echo_info "📦 Iniciando a criação do DMG para ${APP_NAME}..."

# ... (resto do script como antes, usando as variáveis detetadas)
