#!/bin/bash

# ==============================================================================
# Script de Criação de DMG para MediaMover
# ==============================================================================
# Este script pega na aplicação .app compilada e cria uma imagem de disco (.dmg)
# bonita e pronta para distribuição.
#
# Uso:
#   ./create_dmg.sh [CodeSignIdentity]
#
# O argumento CodeSignIdentity é opcional. Se fornecido, o DMG será assinado.
#
# Requisitos:
#   - A aplicação já deve ter sido compilada (usar ./build.sh)
#   - create-dmg (brew install create-dmg)
# ==============================================================================

# Definições
APP_NAME="MediaMover"
BUILD_DIR="build"
APP_PATH="${BUILD_DIR}/Release/${APP_NAME}.app"
DMG_NAME="${APP_NAME}_v1.0.0.dmg"
FINAL_DMG_PATH="${BUILD_DIR}/${DMG_NAME}"

# Identidade de assinatura (passada como argumento opcional)
CODE_SIGN_IDENTITY="$1"

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
echo_info "📦 Iniciando a criação do DMG para ${APP_NAME}..."

# Verificar se create-dmg está instalado
if ! command -v create-dmg &> /dev/null; then
    echo_error "Erro: O utilitário 'create-dmg' não foi encontrado."
    echo_info "Por favor, instale-o com: brew install create-dmg"
    exit 1
fi

# Verificar se a aplicação existe
if [ ! -d "${APP_PATH}" ]; then
    echo_error "Erro: A aplicação não foi encontrada em ${APP_PATH}."
    echo_info "Por favor, execute o script ./build.sh primeiro."
    exit 1
fi

# Remover DMG antigo se existir
rm -f "${FINAL_DMG_PATH}"

# Criar o DMG
echo_info "🖼️  Construindo a imagem de disco..."
create-dmg \
    --volname "${APP_NAME} Installer" \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --icon "${APP_PATH}" 200 190 \
    --hide-extension "${APP_PATH}" \
    --app-drop-link 600 185 \
    "${FINAL_DMG_PATH}" \
    "${APP_PATH}" || {
    echo_error "A criação do DMG falhou."
    exit 1
}

echo_success "✅ DMG criado com sucesso em ${FINAL_DMG_PATH}"

# Assinar o DMG se uma identidade foi fornecida
if [ -n "${CODE_SIGN_IDENTITY}" ]; then
    echo_info "✍️  Assinando o DMG com a identidade: ${CODE_SIGN_IDENTITY}..."
    codesign --sign "${CODE_SIGN_IDENTITY}" --keychain ~/Library/Keychains/login.keychain-db "${FINAL_DMG_PATH}" || {
        echo_error "A assinatura do DMG falhou."
        exit 1
    }
    echo_success "✅ DMG assinado com sucesso."
else
    echo_info "⚠️  Aviso: O DMG não foi assinado. Para distribuição, forneça uma identidade de Developer ID."
fi

echo_info "🏁 Processo de criação de DMG concluído."
