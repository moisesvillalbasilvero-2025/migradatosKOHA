#!/bin/bash
################################################################################
# VIGILANTE DE IMPORTACIÓN AUTOMÁTICA - KOHA UNA
################################################################################
# Monitorea el directorio importar_aqui/ y procesa automáticamente
# cualquier archivo CSV que se coloque ahí.
#
# USO:
#   ./vigilante_importador.sh              # Modo interactivo
#   ./vigilante_importador.sh --daemon     # Modo demonio (segundo plano)
#   ./vigilante_importador.sh --stop       # Detener demonio
#   ./vigilante_importador.sh --status     # Ver estado
#
# CARACTERÍSTICAS:
#   ✓ Monitoreo continuo de directorio importar_aqui/
#   ✓ Procesamiento automático de archivos nuevos
#   ✓ Intervalo configurable (30 segundos por defecto)
#   ✓ Logs automáticos
#   ✓ Modo demonio para ejecución en segundo plano
#
# VERSIÓN: 1.0
# FECHA: 2025-11-05
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIR_TRABAJO="/home/mvillalba/migradatos"
readonly DIR_IMPORTAR="${DIR_TRABAJO}/importar_aqui"
readonly DIR_LOGS="${DIR_TRABAJO}/logs"
readonly IMPORTADOR="${DIR_TRABAJO}/importador_automatico_completo.sh"

readonly PID_FILE="${DIR_TRABAJO}/.vigilante.pid"
readonly LOG_FILE="${DIR_LOGS}/vigilante.log"
readonly INTERVALO=30  # segundos entre verificaciones

# Colores
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# ============================================================================
# FUNCIONES
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${C_CYAN}[INFO]${C_NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${C_GREEN}[OK]${C_NC} $*" | tee -a "$LOG_FILE"
}

banner() {
    echo -e "${C_BOLD}${C_CYAN}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  VIGILANTE DE IMPORTACIÓN AUTOMÁTICA - KOHA UNA"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${C_NC}"
}

# ============================================================================
# FUNCIONES DE CONTROL
# ============================================================================

esta_corriendo() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
            return 1
        fi
    fi
    return 1
}

detener_vigilante() {
    if esta_corriendo; then
        local pid=$(cat "$PID_FILE")
        log_info "Deteniendo vigilante (PID: $pid)..."
        kill "$pid"
        rm -f "$PID_FILE"
        log_success "Vigilante detenido"
        return 0
    else
        log_info "El vigilante no está corriendo"
        return 1
    fi
}

mostrar_estado() {
    banner
    if esta_corriendo; then
        local pid=$(cat "$PID_FILE")
        echo -e "${C_GREEN}✓ Vigilante ACTIVO${C_NC}"
        echo "  PID: $pid"
        echo "  Monitoreando: $DIR_IMPORTAR"
        echo "  Intervalo: ${INTERVALO}s"
        echo "  Log: $LOG_FILE"
    else
        echo -e "${C_YELLOW}○ Vigilante INACTIVO${C_NC}"
    fi
    echo ""
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE VIGILANCIA
# ============================================================================

vigilar() {
    log_info "Iniciando vigilante de importación"
    log_info "Monitoreando: $DIR_IMPORTAR"
    log_info "Intervalo: ${INTERVALO}s"

    # Array para rastrear archivos ya procesados
    declare -A archivos_procesados

    while true; do
        # Buscar archivos CSV en importar_aqui/
        local archivos_encontrados=false

        while IFS= read -r -d '' archivo; do
            local nombre=$(basename "$archivo")

            # Verificar si ya fue procesado en esta sesión
            if [[ -n "${archivos_procesados[$nombre]:-}" ]]; then
                continue
            fi

            # Verificar que el archivo tenga más de 5 segundos
            # (para asegurar que terminó de copiarse)
            local archivo_edad=$(($(date +%s) - $(stat -c %Y "$archivo")))
            if [ "$archivo_edad" -lt 5 ]; then
                continue
            fi

            archivos_encontrados=true
            log_info "Archivo detectado: $nombre"

            # Procesar archivo
            if "$IMPORTADOR" "$archivo" >> "$LOG_FILE" 2>&1; then
                log_success "Importación exitosa: $nombre"
                archivos_procesados[$nombre]=1
            else
                log_info "Error al procesar: $nombre (ver log para detalles)"
                archivos_procesados[$nombre]=1
            fi

        done < <(find "$DIR_IMPORTAR" -maxdepth 1 -name "*.csv" -print0)

        if [ "$archivos_encontrados" = false ]; then
            log "Esperando archivos... (verificación cada ${INTERVALO}s)"
        fi

        sleep "$INTERVALO"
    done
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    case "${1:-}" in
        --daemon)
            if esta_corriendo; then
                echo "El vigilante ya está corriendo (PID: $(cat $PID_FILE))"
                exit 1
            fi

            banner
            log_info "Iniciando en modo demonio..."

            # Iniciar en segundo plano
            nohup "$0" --run >> "$LOG_FILE" 2>&1 &
            local pid=$!
            echo "$pid" > "$PID_FILE"

            log_success "Vigilante iniciado (PID: $pid)"
            log_info "Monitoreando: $DIR_IMPORTAR"
            log_info "Log: $LOG_FILE"
            echo ""
            echo -e "${C_CYAN}Usa: $0 --status  para ver el estado${C_NC}"
            echo -e "${C_CYAN}Usa: $0 --stop   para detener${C_NC}"
            echo -e "${C_CYAN}Usa: tail -f $LOG_FILE  para ver logs en vivo${C_NC}"
            ;;

        --stop)
            detener_vigilante
            ;;

        --status)
            mostrar_estado
            ;;

        --run)
            # Modo interno - no llamar directamente
            vigilar
            ;;

        "")
            banner
            log_info "Iniciando en modo interactivo..."
            log_info "Presiona Ctrl+C para detener"
            echo ""
            trap 'log_info "Deteniendo vigilante..."; exit 0' INT
            vigilar
            ;;

        *)
            echo "Uso: $0 [--daemon|--stop|--status]"
            echo ""
            echo "Opciones:"
            echo "  (sin opciones)  Modo interactivo"
            echo "  --daemon        Iniciar en segundo plano"
            echo "  --stop          Detener demonio"
            echo "  --status        Ver estado actual"
            exit 1
            ;;
    esac
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

# Crear directorios si no existen
mkdir -p "$DIR_LOGS"

main "$@"
