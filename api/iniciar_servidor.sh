#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
# SCRIPT DE INICIO - SERVIDOR API REST KOHA
# ════════════════════════════════════════════════════════════════════════════
#
# Script para iniciar el servidor API de importación Koha de forma simple.
#
# USO:
#   ./iniciar_servidor.sh [puerto] [host]
#
# EJEMPLOS:
#   ./iniciar_servidor.sh              # Puerto 8000, localhost
#   ./iniciar_servidor.sh 9000         # Puerto 9000, localhost
#   ./iniciar_servidor.sh 8000 0.0.0.0 # Puerto 8000, todas las interfaces
#
# AUTORES: Universidad Nacional de Asunción
# VERSIÓN: 1.0.0
# FECHA: 2025-11-07
# ════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ════════════════════════════════════════════════════════════════════════════

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$(dirname "$SCRIPT_DIR")"

# Parámetros (con valores por defecto)
readonly PORT="${1:-8000}"
readonly HOST="${2:-127.0.0.1}"

# ════════════════════════════════════════════════════════════════════════════
# FUNCIONES
# ════════════════════════════════════════════════════════════════════════════

print_banner() {
    echo "════════════════════════════════════════════════════════════════════════════"
    echo "  SERVIDOR API REST - SISTEMA DE IMPORTACIÓN KOHA"
    echo "════════════════════════════════════════════════════════════════════════════"
    echo ""
}

verificar_dependencias() {
    echo "🔍 Verificando dependencias..."

    # Verificar Python 3
    if ! command -v python3 &> /dev/null; then
        echo "❌ Error: Python 3 no está instalado"
        exit 1
    fi

    # Verificar uvicorn
    if ! python3 -c "import uvicorn" 2>/dev/null; then
        echo "⚠️  uvicorn no está instalado. Instalando dependencias..."
        pip3 install -r "${SCRIPT_DIR}/requirements.txt"
    fi

    # Verificar FastAPI
    if ! python3 -c "import fastapi" 2>/dev/null; then
        echo "⚠️  FastAPI no está instalado. Instalando dependencias..."
        pip3 install -r "${SCRIPT_DIR}/requirements.txt"
    fi

    echo "✓ Dependencias verificadas"
    echo ""
}

crear_directorios() {
    echo "📁 Creando directorios necesarios..."

    mkdir -p "${SCRIPT_DIR}/uploads"
    mkdir -p "${SCRIPT_DIR}/logs"

    echo "✓ Directorios creados"
    echo ""
}

mostrar_info() {
    echo "═══════════════════════════════════════════════════════════════════════════"
    echo "  SERVIDOR INICIADO EXITOSAMENTE"
    echo "═══════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "  🌐 URL del servidor:  http://${HOST}:${PORT}"
    echo "  📚 Documentación:     http://${HOST}:${PORT}/docs"
    echo "  📊 API alternativa:   http://${HOST}:${PORT}/redoc"
    echo "  💚 Health check:      http://${HOST}:${PORT}/api/v1/health"
    echo ""
    echo "  🔑 API Key (por defecto): una-koha-api-key-segura-2025"
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "  EJEMPLO DE USO:"
    echo ""
    echo "  # Validar archivo"
    echo "  curl -X POST \"http://${HOST}:${PORT}/api/v1/validate\" \\"
    echo "       -H \"X-API-Key: una-koha-api-key-segura-2025\" \\"
    echo "       -F \"file=@MED.csv\""
    echo ""
    echo "  # Importar archivo"
    echo "  curl -X POST \"http://${HOST}:${PORT}/api/v1/import\" \\"
    echo "       -H \"X-API-Key: una-koha-api-key-segura-2025\" \\"
    echo "       -F \"file=@MED.csv\""
    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════"
    echo ""
    echo "Presiona Ctrl+C para detener el servidor"
    echo ""
}

iniciar_servidor() {
    echo "🚀 Iniciando servidor en ${HOST}:${PORT}..."
    echo ""

    # Cambiar al directorio del script
    cd "$SCRIPT_DIR"

    # Iniciar con uvicorn
    python3 -m uvicorn servidor_api:app \
        --host "$HOST" \
        --port "$PORT" \
        --reload \
        --log-level info
}

# ════════════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════════════

main() {
    print_banner
    verificar_dependencias
    crear_directorios
    mostrar_info
    iniciar_servidor
}

# Trap para cleanup
trap 'echo ""; echo "👋 Servidor detenido"; exit 0' INT TERM

main "$@"
