#!/bin/bash

# ==============================================================================
# Script de Compilação e Arquivo (Inteligente)
# ==============================================================================

# Cores para o output
echo_info() { echo -e "\033[1;34m$1\033[0m"; }
echo_success() { echo -e "\033[1;32m$1\033[0m"; }
echo_error() { echo -e "\033[1;31m$1\033[0m" >&2; }

# --- Lógica Inteligente para Detetar o Nome do Projeto ---
PROJECT_FILE=$(find . -maxdepth 1 -name "*.xcodeproj")
if [ -z "${PROJECT_FILE}" ]; then
    echo_error "Nenhum ficheiro .xcodeproj encontrado no diretório atual."
    exit 1
fi

# Extrai o nome do ficheiro, ex: ./MediaMover.xcodeproj -> MediaMover
PROJECT_NAME=$(basename "${PROJECT_FILE}" .xcodeproj)
SCHEME_NAME=${PROJECT_NAME}
CONFIGURATION="Release"
BUILD_DIR="build"
# ... (restante do script igual)

echo_info "🚀 Iniciando o processo de build para ${PROJECT_NAME}..."

# Limpar builds anteriores
echo_info "🧹 Limpando artefactos de builds anteriores..."
rm -rf "${BUILD_DIR}"
xcodebuild clean -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -configuration "${CONFIGURATION}" #...

# ... (resto do script como antes, usando as variáveis detetadas)
