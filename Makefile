# Makefile para construir e empacotar a aplicação MediaMover
# Este ficheiro substitui os scripts build.sh e create_dmg.sh

# --- Variáveis ---
APP_NAME = MediaMover
CONFIGURATION = release
BUILD_DIR = .build/$(CONFIGURATION)
FINAL_APP_PATH = $(BUILD_DIR)/$(APP_NAME).app
DMG_NAME = $(APP_NAME).dmg
VOLUME_NAME = "$(APP_NAME)"

# --- Comandos ---

# Phony targets não representam ficheiros
.PHONY: all build clean dmg

# Alvo por defeito: construir a aplicação
all: build

# Constrói a aplicação em modo release
build:
	@echo "🚀 A construir $(APP_NAME) em modo de produção..."
	@swift build -c $(CONFIGURATION)
	@echo "✅ Build concluído. A aplicação está em: $(FINAL_APP_PATH)"

# Cria o ficheiro .dmg
dmg: build
	@echo "📦 A criar o ficheiro .dmg..."
	@if [ ! -d "$(FINAL_APP_PATH)" ]; then \
		echo "❌ Erro: Aplicação não encontrada em $(FINAL_APP_PATH)."; \
		exit 1; \
	fi
	@rm -f "$(DMG_NAME)"
	@hdiutil create -volname $(VOLUME_NAME) -srcfolder "$(FINAL_APP_PATH)" -ov -format UDZO "$(DMG_NAME)"
	@echo "✅ DMG criado com sucesso: $(DMG_NAME)"

# Limpa os artefactos de build
clean:
	@echo "🧹 A limpar builds anteriores..."
	@rm -rf .build
	@rm -f "$(DMG_NAME)"
	@echo "✅ Limpeza concluída."

