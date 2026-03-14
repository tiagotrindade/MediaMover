#!/bin/bash

# ==============================================================================
# Script de Compilação Inteligente para Projetos Xcode
# ==============================================================================
# Este script deteta automaticamente o ficheiro .xcodeproj, compila o projeto
# e coloca a aplicação final (.app) num diretório `build/Release`.
# ==============================================================================

# Funções de cor para um output mais legível
echo_info() { echo -e "\033[1;34m$1\033[0m"; }
echo_success() { echo -e "\033[1;32m$1\033[0m"; }
echo_error() { echo -e "\033[1;31m$1\033[0m" >&2; }

# --- Deteção do Projeto ---
echo_info "🔎 A procurar o ficheiro do projeto Xcode (.xcodeproj)..."
# Procura no diretório atual e um nível abaixo
PROJECT_FILE_PATH=$(find . -name "*.xcodeproj" -maxdepth 2 | head -n 1)

if [ -z "${PROJECT_FILE_PATH}" ]; then
    echo_error "Nenhum ficheiro .xcodeproj encontrado neste diretório ou nos seus subdiretórios imediatos."
    exit 1
fi

# Extrai o nome do esquema a partir do caminho do ficheiro (ex: ./MediaMover/MediaMover.xcodeproj -> MediaMover)
SCHEME_NAME=$(basename "${PROJECT_FILE_PATH}" .xcodeproj)
CONFIGURATION="Release"
BUILD_DIR="build"

echo_info "✅ Projeto encontrado: ${PROJECT_FILE_PATH}"
echo_info "🚀 A iniciar o processo de build para o esquema '${SCHEME_NAME}'..."

# --- Limpeza ---
echo_info "🧹 A limpar artefactos de builds anteriores..."
rm -rf "${BUILD_DIR}"
xcodebuild clean -project "${PROJECT_FILE_PATH}" -scheme "${SCHEME_NAME}" -configuration "${CONFIGURATION}" >/dev/null || {
    echo_error "A limpeza falhou. A abortar."
    exit 1
}

# --- Compilação ---
echo_info "🛠️  A compilar o projeto (isto pode demorar um momento)..."
# Usamos SYMROOT para forçar a saída de todos os produtos para o nosso diretório de build
xcodebuild build -project "${PROJECT_FILE_PATH}" -scheme "${SCHEME_NAME}" -configuration "${CONFIGURATION}" SYMROOT="${PWD}/${BUILD_DIR}" -quiet || {
    echo_error "A compilação falhou. Tente executar o comando xcodebuild manualmente para ver os erros detalhados."
    exit 1
}

# --- Organização Final ---
echo_info "🚚 A mover a aplicação (.app) para um diretório final..."
# O .app compilado estará em build/Release/AppName.app
APP_SOURCE_PATH=$(find "${BUILD_DIR}/${CONFIGURATION}" -name "*.app" -maxdepth 1)

if [ ! -d "${APP_SOURCE_PATH}" ]; then
    echo_error "Não foi possível encontrar a aplicação compilada. A build pode ter falhado silenciosamente."
    exit 1
fi

# Garante que o diretório de destino existe e move a aplicação
mkdir -p "${BUILD_DIR}/Release"
mv "${APP_SOURCE_PATH}" "${BUILD_DIR}/Release/"

echo_success "✅ Build concluído com sucesso!"
echo_info "A sua aplicação está pronta em: ${BUILD_DIR}/Release/${SCHEME_NAME}.app"
