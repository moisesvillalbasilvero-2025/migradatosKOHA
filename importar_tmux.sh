#!/bin/bash
################################################################################
# IMPORTADOR CON TMUX - Sistema Persistente de Importación
################################################################################
# Ejecuta importaciones en sesiones tmux persistentes que sobreviven
# desconexiones SSH y garantizan la finalización de cada tarea
#
# USO:
#   ./importar_tmux.sh archivo.csv              # Importa un archivo
#   ./importar_tmux.sh --all                    # Importa todos los CSV
#   ./importar_tmux.sh --status                 # Ver estado de sesiones
#   ./importar_tmux.sh --attach NOMBRE          # Reconectar a sesión
#   ./importar_tmux.sh --kill NOMBRE            # Detener sesión
#   ./importar_tmux.sh --cleanup                # Limpiar sesiones finalizadas
#
# CARACTERÍSTICAS:
#   ✓ Sesiones persistentes con tmux
#   ✓ Logs en tiempo real compartidos
#   ✓ Recuperación automática ante desconexión
#   ✓ Control de múltiples importaciones concurrentes
#   ✓ Estado detallado de cada proceso
#   ✓ Notificaciones de finalización
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
readonly DIR_TMUX_LOGS="${DIR_LOGS}/tmux"
readonly DIR_SESSIONS="${DIR_TRABAJO}/.sessions"

# Prefijo para sesiones tmux
readonly TMUX_PREFIX="koha-import"

# Colores
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_MAGENTA='\033[0;35m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

log_info() {
    echo -e "${C_CYAN}ℹ ${1}${C_NC}"
}

log_success() {
    echo -e "${C_GREEN}✓ ${1}${C_NC}"
}

log_warning() {
    echo -e "${C_YELLOW}⚠ ${1}${C_NC}"
}

log_error() {
    echo -e "${C_RED}✗ ${1}${C_NC}"
}

separador() {
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
}

banner() {
    echo -e "${C_BOLD}${C_CYAN}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  SISTEMA DE IMPORTACIÓN PERSISTENTE CON TMUX - KOHA UNA"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${C_NC}"
}

# ============================================================================
# GESTIÓN DE DIRECTORIOS
# ============================================================================

crear_directorios() {
    mkdir -p "$DIR_TMUX_LOGS" "$DIR_SESSIONS" "$DIR_LOGS"
}

# ============================================================================
# FUNCIONES DE TMUX
# ============================================================================

verificar_tmux() {
    if ! command -v tmux &> /dev/null; then
        log_error "tmux no está instalado"
        log_info "Instala con: sudo apt install tmux"
        exit 1
    fi
}

generar_nombre_sesion() {
    local archivo="$1"
    local codigo=$(basename "$archivo" .csv)
    local timestamp=$(date +%Y%m%d_%H%M%S)
    echo "${TMUX_PREFIX}-${codigo}-${timestamp}"
}

sesion_existe() {
    local nombre="$1"
    tmux has-session -t "$nombre" 2>/dev/null
}

listar_sesiones() {
    tmux list-sessions 2>/dev/null | grep "^${TMUX_PREFIX}-" || true
}

contar_sesiones_activas() {
    listar_sesiones | wc -l
}

obtener_info_sesion() {
    local nombre="$1"
    local info_file="${DIR_SESSIONS}/${nombre}.info"

    if [ -f "$info_file" ]; then
        cat "$info_file"
    fi
}

guardar_info_sesion() {
    local nombre="$1"
    local archivo="$2"
    local pid="$3"
    local timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    local info_file="${DIR_SESSIONS}/${nombre}.info"

    cat > "$info_file" << EOF
NOMBRE_SESION=$nombre
ARCHIVO_CSV=$archivo
PID_PROCESO=$pid
TIMESTAMP_INICIO=$timestamp
LOG_FILE=${DIR_TMUX_LOGS}/${nombre}.log
STATUS=RUNNING
EOF
}

actualizar_status_sesion() {
    local nombre="$1"
    local nuevo_status="$2"
    local info_file="${DIR_SESSIONS}/${nombre}.info"

    if [ -f "$info_file" ]; then
        sed -i "s/^STATUS=.*/STATUS=$nuevo_status/" "$info_file"
        echo "TIMESTAMP_FIN=$(date +'%Y-%m-%d %H:%M:%S')" >> "$info_file"
    fi
}

# ============================================================================
# FUNCIÓN DE IMPORTACIÓN EN TMUX
# ============================================================================

importar_en_tmux() {
    local archivo="$1"
    local nombre_sesion=$(generar_nombre_sesion "$archivo")
    local log_file="${DIR_TMUX_LOGS}/${nombre_sesion}.log"

    if ! [ -f "$archivo" ]; then
        log_error "Archivo no encontrado: $archivo"
        return 1
    fi

    separador
    log_info "Iniciando importación en sesión tmux persistente"
    separador

    echo -e "${C_BOLD}Archivo:${C_NC}        $(basename "$archivo")"
    echo -e "${C_BOLD}Sesión tmux:${C_NC}    $nombre_sesion"
    echo -e "${C_BOLD}Log:${C_NC}            $log_file"
    separador

    # Crear sesión tmux con logging automático
    tmux new-session -d -s "$nombre_sesion" \
        "bash -c 'set -o pipefail; echo \"═══════════════════════════════════════════════════════════\" | tee -a \"$log_file\"; \
         echo \"[$(date +\"%Y-%m-%d %H:%M:%S\")]\" | tee -a \"$log_file\"; \
         echo \"Sesión: $nombre_sesion\" | tee -a \"$log_file\"; \
         echo \"Archivo: $archivo\" | tee -a \"$log_file\"; \
         echo \"═══════════════════════════════════════════════════════════\" | tee -a \"$log_file\"; \
         echo \"\" | tee -a \"$log_file\"; \
         cd \"$DIR_TRABAJO\" && \
         ./importador_automatico_completo.sh \"$archivo\" 2>&1 | tee -a \"$log_file\"; \
         EXITCODE=\${PIPESTATUS[0]}; \
         echo \"\" | tee -a \"$log_file\"; \
         echo \"═══════════════════════════════════════════════════════════\" | tee -a \"$log_file\"; \
         echo \"[$(date +\"%Y-%m-%d %H:%M:%S\")]\" | tee -a \"$log_file\"; \
         if [ \$EXITCODE -eq 0 ]; then \
             echo \"✓ IMPORTACIÓN COMPLETADA EXITOSAMENTE\" | tee -a \"$log_file\"; \
         else \
             echo \"✗ IMPORTACIÓN FINALIZADA CON ERRORES (código: \$EXITCODE)\" | tee -a \"$log_file\"; \
         fi; \
         echo \"═══════════════════════════════════════════════════════════\" | tee -a \"$log_file\"; \
         echo \"\" | tee -a \"$log_file\"; \
         echo \"Presiona ENTER para cerrar esta sesión tmux...\" | tee -a \"$log_file\"; \
         read; \
         exit \$EXITCODE'"

    # Esperar a que la sesión esté activa
    sleep 1

    if sesion_existe "$nombre_sesion"; then
        # Obtener PID del proceso tmux
        local tmux_pane_pid=$(tmux list-panes -t "$nombre_sesion" -F '#{pane_pid}' 2>/dev/null | head -1)

        # Guardar información de la sesión
        guardar_info_sesion "$nombre_sesion" "$archivo" "$tmux_pane_pid"

        log_success "Sesión iniciada correctamente"
        echo ""
        log_info "Para ver el progreso en tiempo real, ejecuta:"
        echo -e "  ${C_YELLOW}tmux attach-session -t $nombre_sesion${C_NC}"
        echo ""
        log_info "O monitorea el log:"
        echo -e "  ${C_YELLOW}tail -f $log_file${C_NC}"
        echo ""
        log_info "Para desconectarte sin detener: ${C_YELLOW}Ctrl+B luego D${C_NC}"
        separador

        return 0
    else
        log_error "Error al crear sesión tmux"
        return 1
    fi
}

# ============================================================================
# FUNCIÓN DE MONITOREO DE ESTADO
# ============================================================================

mostrar_estado() {
    banner

    local sesiones=$(listar_sesiones)
    local total=$(echo "$sesiones" | grep -c "^" || echo "0")

    if [ "$total" -eq 0 ]; then
        log_info "No hay sesiones de importación activas"
        echo ""
        log_info "Sesiones finalizadas recientes:"
        separador

        # Mostrar últimas 5 sesiones finalizadas
        ls -1t "${DIR_SESSIONS}"/*.info 2>/dev/null | head -5 | while read info_file; do
            if [ -f "$info_file" ]; then
                source "$info_file"

                if [ "${STATUS:-RUNNING}" != "RUNNING" ]; then
                    echo -e "${C_BOLD}Sesión:${C_NC} $NOMBRE_SESION"
                    echo -e "${C_BOLD}Archivo:${C_NC} $(basename "$ARCHIVO_CSV")"
                    echo -e "${C_BOLD}Estado:${C_NC} $STATUS"
                    echo -e "${C_BOLD}Inicio:${C_NC} $TIMESTAMP_INICIO"
                    [ -n "${TIMESTAMP_FIN:-}" ] && echo -e "${C_BOLD}Fin:${C_NC} $TIMESTAMP_FIN"
                    echo -e "${C_BOLD}Log:${C_NC} $LOG_FILE"
                    separador
                fi
            fi
        done
        return 0
    fi

    log_success "Sesiones activas: $total"
    separador

    echo "$sesiones" | while IFS=: read -r session_info rest; do
        local nombre=$(echo "$session_info" | awk '{print $1}')
        local info_file="${DIR_SESSIONS}/${nombre}.info"

        echo -e "\n${C_BOLD}${C_CYAN}Sesión: $nombre${C_NC}"

        if [ -f "$info_file" ]; then
            source "$info_file"

            echo -e "${C_BOLD}Archivo:${C_NC}     $(basename "${ARCHIVO_CSV}")"
            echo -e "${C_BOLD}PID:${C_NC}         ${PID_PROCESO}"
            echo -e "${C_BOLD}Inicio:${C_NC}      ${TIMESTAMP_INICIO}"

            # Calcular tiempo transcurrido
            local inicio_epoch=$(date -d "$TIMESTAMP_INICIO" +%s 2>/dev/null || echo "0")
            local ahora_epoch=$(date +%s)
            local duracion=$((ahora_epoch - inicio_epoch))
            local horas=$((duracion / 3600))
            local minutos=$(((duracion % 3600) / 60))
            local segundos=$((duracion % 60))

            echo -e "${C_BOLD}Duración:${C_NC}    ${horas}h ${minutos}m ${segundos}s"
            echo -e "${C_BOLD}Log:${C_NC}         ${LOG_FILE}"

            # Mostrar últimas líneas del log
            if [ -f "$LOG_FILE" ]; then
                local size=$(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo "0")
                echo -e "${C_BOLD}Tamaño log:${C_NC}  $(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "$size bytes")"

                echo -e "\n${C_BOLD}Últimas 3 líneas:${C_NC}"
                tail -3 "$LOG_FILE" 2>/dev/null | sed 's/^/  │ /'
            fi

            echo ""
            echo -e "${C_YELLOW}Comandos:${C_NC}"
            echo -e "  Conectar:    tmux attach-session -t $nombre"
            echo -e "  Ver log:     tail -f $LOG_FILE"
            echo -e "  Detener:     ./importar_tmux.sh --kill $nombre"
        else
            echo -e "${C_YELLOW}(Sin información de sesión)${C_NC}"
        fi

        separador
    done
}

# ============================================================================
# FUNCIÓN DE RECONEXIÓN
# ============================================================================

reconectar_sesion() {
    local nombre="$1"

    if sesion_existe "$nombre"; then
        log_info "Reconectando a sesión: $nombre"
        log_info "Para desconectar sin detener: Ctrl+B luego D"
        sleep 2
        tmux attach-session -t "$nombre"
    else
        log_error "La sesión '$nombre' no existe o ya finalizó"
        echo ""
        log_info "Sesiones disponibles:"
        listar_sesiones
    fi
}

# ============================================================================
# FUNCIÓN DE DETENER SESIÓN
# ============================================================================

detener_sesion() {
    local nombre="$1"

    if sesion_existe "$nombre"; then
        log_warning "Deteniendo sesión: $nombre"

        # Actualizar estado antes de matar
        actualizar_status_sesion "$nombre" "DETENIDO_MANUALMENTE"

        tmux kill-session -t "$nombre"
        log_success "Sesión detenida"
    else
        log_error "La sesión '$nombre' no existe"
    fi
}

# ============================================================================
# FUNCIÓN DE LIMPIEZA
# ============================================================================

limpiar_sesiones() {
    log_info "Limpiando sesiones finalizadas..."

    local limpiadas=0

    # Limpiar archivos .info de sesiones que ya no existen
    for info_file in "${DIR_SESSIONS}"/*.info; do
        if [ -f "$info_file" ]; then
            local nombre=$(basename "$info_file" .info)

            if ! sesion_existe "$nombre"; then
                # Actualizar status si aún dice RUNNING
                source "$info_file"
                if [ "${STATUS:-RUNNING}" = "RUNNING" ]; then
                    actualizar_status_sesion "$nombre" "FINALIZADO"
                fi

                limpiadas=$((limpiadas + 1))
            fi
        fi
    done

    log_success "Sesiones actualizadas: $limpiadas"

    # Mostrar logs antiguos (más de 7 días)
    log_info "Logs antiguos (>7 días):"
    find "$DIR_TMUX_LOGS" -name "*.log" -mtime +7 -ls 2>/dev/null | wc -l
}

# ============================================================================
# FUNCIÓN DE IMPORTACIÓN MÚLTIPLE
# ============================================================================

importar_todos() {
    banner

    local archivos=("$DIR_IMPORTAR"/*.csv)
    local total=${#archivos[@]}

    if [ ! -f "${archivos[0]}" ]; then
        log_warning "No hay archivos CSV en $DIR_IMPORTAR"
        return 0
    fi

    log_info "Archivos encontrados: $total"
    separador

    # Listar archivos
    for archivo in "${archivos[@]}"; do
        echo "  • $(basename "$archivo")"
    done

    separador
    echo -e "${C_YELLOW}¿Iniciar $total importación(es) en sesiones tmux separadas? [y/N]${C_NC}"
    read -r respuesta

    if [[ ! "$respuesta" =~ ^[Yy]$ ]]; then
        log_info "Cancelado por el usuario"
        return 0
    fi

    separador

    local exitosos=0
    local fallidos=0

    for archivo in "${archivos[@]}"; do
        if importar_en_tmux "$archivo"; then
            exitosos=$((exitosos + 1))
            sleep 2  # Esperar entre sesiones
        else
            fallidos=$((fallidos + 1))
        fi
    done

    echo ""
    separador
    log_success "Sesiones iniciadas: $exitosos"
    if [ $fallidos -gt 0 ]; then
        log_warning "Sesiones fallidas: $fallidos"
    fi
    separador

    echo ""
    log_info "Para monitorear todas las sesiones:"
    echo -e "  ${C_YELLOW}./importar_tmux.sh --status${C_NC}"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    verificar_tmux
    crear_directorios

    # Procesar argumentos
    case "${1:-}" in
        --status|-s)
            mostrar_estado
            ;;

        --attach|-a)
            if [ -z "${2:-}" ]; then
                log_error "Especifica el nombre de la sesión"
                log_info "Sesiones disponibles:"
                listar_sesiones
                exit 1
            fi
            reconectar_sesion "$2"
            ;;

        --kill|-k)
            if [ -z "${2:-}" ]; then
                log_error "Especifica el nombre de la sesión"
                exit 1
            fi
            detener_sesion "$2"
            ;;

        --cleanup|-c)
            limpiar_sesiones
            ;;

        --all)
            importar_todos
            ;;

        --help|-h)
            banner
            cat << EOF
USO:
    $(basename "$0") archivo.csv              Importa un archivo en sesión tmux
    $(basename "$0") --all                    Importa todos los CSV en importar_aqui/
    $(basename "$0") --status                 Ver estado de todas las sesiones
    $(basename "$0") --attach NOMBRE          Reconectar a una sesión existente
    $(basename "$0") --kill NOMBRE            Detener una sesión
    $(basename "$0") --cleanup                Limpiar sesiones finalizadas

EJEMPLOS:
    # Importar un archivo
    ./importar_tmux.sh importar_aqui/BFIA.csv

    # Ver estado de importaciones
    ./importar_tmux.sh --status

    # Reconectar a sesión
    ./importar_tmux.sh --attach koha-import-BFIA-20251105_143022

    # Importar todos los CSV
    ./importar_tmux.sh --all

CARACTERÍSTICAS:
    ✓ Las sesiones tmux persisten incluso si se cierra SSH
    ✓ Logs en tiempo real guardados automáticamente
    ✓ Puedes reconectarte en cualquier momento
    ✓ Múltiples importaciones pueden correr simultáneamente
    ✓ Control total sobre cada proceso

EOF
            ;;

        "")
            log_error "Especifica un archivo o usa --help"
            exit 1
            ;;

        *)
            # Importar archivo específico
            importar_en_tmux "$1"
            ;;
    esac
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

main "$@"
