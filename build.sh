#!/bin/bash

# ==============================================================================
# Script de Compilação e Arquivo para MediaMover
# ==============================================================================
# Este script limpa, constrói e arquiva o projeto MediaMover, preparando-o
# para a criação de um DMG ou para distribuição.
#
# Uso:
#   ./build.sh
#
# Requisitos:
#   - Xcode Command Line Tools instalados (xcode-select --install)
#   - Estar na raiz do projeto ao executar.
# ==============================================================================

# Definições
PROJECT_NAME="MediaMover"
SCHEME_NAME="MediaMover"
CONFIGURATION="Release"

# Onde os artefactos de build serão colocados
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
APP_PATH="${BUILD_DIR}/${CONFIGURATION}/${PROJECT_NAME}.app"

# Cores para o output
echo_info() {
    echo -e "\033[1;34m$1\033[0m"
}
echo_success() {
    echo -e "\033[1;32m$1\033[0m"
}
echo_error() {
    echo -e "\033[1;31m$1\033[0m" >&2
}

# Início do Script
echo_info "🚀 Iniciando o processo de build para ${PROJECT_NAME}..."

# Limpar builds anteriores para garantir um estado limpo
echo_info "🧹 Limpando artefactos de builds anteriores..."
rm -rf "${BUILD_DIR}"
xcodebuild clean -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -configuration "${CONFIGURATION}" || {
    echo_error "Falha na limpeza. Abortando."
    exit 1
}

# Construir a aplicação
echo_info "🛠️  Construindo a aplicação (Configuration: ${CONFIGURATION})..."
xcodebuild build \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME_NAME}" \
    -configuration "${CONFIGURATION}" \
    -derivedDataPath "${BUILD_DIR}" || {
    echo_error "A compilação falhou. Verifique os erros acima."
    exit 1
}

# Verificar se a app foi criada
if [ ! -d "${APP_PATH}" ]; then
    echo_error "O ficheiro da aplicação (${APP_PATH}) não foi encontrado após a compilação."
    exit 1
fi

echo_success "✅ Compilação da aplicação concluída com sucesso!"
echo_info "Aplicação disponível em: ${APP_PATH}"

# Arquivar o projeto (necessário para notarização e distribuição na App Store)
echo_info "📦 Arquivando o projeto..."
xcodebuild archive \
    -project "${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME_NAME}" \
    -configuration "${CONFIGURATION}" \
    -archivePath "${ARCHIVE_PATH}" || {
    echo_error "O arquivamento falhou."
    exit 1
}

echo_success "✅ Projeto arquivado com sucesso!"
echo_info "Arquivo disponível em: ${ARCHIVE_PATH}"

echo_info "🏁 Processo de build concluído."
