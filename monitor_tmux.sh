#!/bin/bash
################################################################################
# MONITOR DE SESIONES TMUX - Dashboard en Tiempo Real
################################################################################
# Monitorea todas las sesiones de importación activas y muestra
# estadísticas en tiempo real con actualización automática
#
# USO:
#   ./monitor_tmux.sh                   # Monitor interactivo (actualiza cada 5s)
#   ./monitor_tmux.sh --once            # Mostrar una vez y salir
#   ./monitor_tmux.sh --interval 10     # Actualizar cada 10 segundos
#   ./monitor_tmux.sh --json            # Salida en formato JSON
#
# CONTROLES INTERACTIVOS:
#   - q: Salir
#   - r: Refrescar ahora
#   - l: Ver lista de logs
#   - c: Limpiar sesiones finalizadas
#
# VERSIÓN: 1.0
# FECHA: 2025-11-05
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

readonly DIR_TRABAJO="/home/mvillalba/migradatos"
readonly DIR_LOGS="${DIR_TRABAJO}/logs/tmux"
readonly DIR_SESSIONS="${DIR_TRABAJO}/.sessions"
readonly TMUX_PREFIX="koha-import"

# Intervalo de actualización por defecto (segundos)
INTERVALO=5
MODO_CONTINUO=true
MODO_JSON=false

# Colores
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_MAGENTA='\033[0;35m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'
readonly C_NC='\033[0m'

# Símbolos
readonly SYM_RUNNING="●"
readonly SYM_FINISHED="○"
readonly SYM_ERROR="✗"
readonly SYM_SUCCESS="✓"

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

limpiar_pantalla() {
    clear
    tput cup 0 0
}

obtener_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

formatear_duracion() {
    local segundos=$1
    local horas=$((segundos / 3600))
    local minutos=$(((segundos % 3600) / 60))
    local segs=$((segundos % 60))

    if [ $horas -gt 0 ]; then
        printf "%02dh %02dm %02ds" $horas $minutos $segs
    elif [ $minutos -gt 0 ]; then
        printf "%02dm %02ds" $minutos $segs
    else
        printf "%02ds" $segs
    fi
}

formatear_bytes() {
    local bytes=$1
    if command -v numfmt &> /dev/null; then
        numfmt --to=iec-i --suffix=B $bytes 2>/dev/null || echo "${bytes}B"
    else
        if [ $bytes -gt 1073741824 ]; then
            echo "$(( bytes / 1073741824 ))GB"
        elif [ $bytes -gt 1048576 ]; then
            echo "$(( bytes / 1048576 ))MB"
        elif [ $bytes -gt 1024 ]; then
            echo "$(( bytes / 1024 ))KB"
        else
            echo "${bytes}B"
        fi
    fi
}

# ============================================================================
# RECOPILACIÓN DE DATOS
# ============================================================================

obtener_sesiones_activas() {
    tmux list-sessions 2>/dev/null | grep "^${TMUX_PREFIX}-" | awk -F: '{print $1}' || true
}

obtener_info_sesion_completa() {
    local nombre="$1"
    local info_file="${DIR_SESSIONS}/${nombre}.info"
    local log_file="${DIR_LOGS}/${nombre}.log"

    local archivo="N/A"
    local pid="N/A"
    local inicio="N/A"
    local duracion=0
    local status="RUNNING"
    local log_size=0
    local ultima_linea=""
    local progreso=""

    # Leer archivo de info
    if [ -f "$info_file" ]; then
        source "$info_file"
        archivo="${ARCHIVO_CSV:-N/A}"
        pid="${PID_PROCESO:-N/A}"
        inicio="${TIMESTAMP_INICIO:-N/A}"
        status="${STATUS:-RUNNING}"

        # Calcular duración
        if [ "$inicio" != "N/A" ]; then
            local inicio_epoch=$(date -d "$inicio" +%s 2>/dev/null || echo "0")
            local ahora_epoch=$(date +%s)
            duracion=$((ahora_epoch - inicio_epoch))
        fi
    fi

    # Leer log
    if [ -f "$log_file" ]; then
        log_size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")

        # Obtener última línea significativa (no vacía)
        ultima_linea=$(grep -v '^[[:space:]]*$' "$log_file" 2>/dev/null | tail -1 | cut -c 1-100 || echo "")

        # Buscar indicadores de progreso
        if grep -q "IMPORTACIÓN COMPLETADA" "$log_file" 2>/dev/null; then
            status="COMPLETADO"
        elif grep -q "ERROR\|FALLÓ\|FAILED" "$log_file" 2>/dev/null; then
            status="ERROR"
        fi

        # Extraer progreso si hay
        progreso=$(grep -oP 'Importando.*\[\K[^\]]+' "$log_file" 2>/dev/null | tail -1 || echo "")
    fi

    # Formato: NOMBRE|ARCHIVO|PID|INICIO|DURACION|STATUS|LOG_SIZE|ULTIMA_LINEA|PROGRESO
    echo "${nombre}|${archivo}|${pid}|${inicio}|${duracion}|${status}|${log_size}|${ultima_linea}|${progreso}"
}

# ============================================================================
# RENDERIZADO
# ============================================================================

renderizar_cabecera() {
    local num_sesiones=$1
    local timestamp=$(obtener_timestamp)

    echo -e "${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════════════════════════${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}  MONITOR DE IMPORTACIONES KOHA - SESIONES TMUX ACTIVAS${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════════════════════════${C_NC}"
    echo ""
    echo -e "${C_BOLD}Actualizado:${C_NC} $timestamp    ${C_BOLD}Sesiones activas:${C_NC} $num_sesiones    ${C_BOLD}Intervalo:${C_NC} ${INTERVALO}s"
    echo -e "${C_DIM}Controles: [q] Salir | [r] Refrescar | [l] Ver logs | [c] Limpiar${C_NC}"
    echo -e "${C_CYAN}───────────────────────────────────────────────────────────────────────────────${C_NC}"
}

renderizar_sesion() {
    local datos="$1"

    IFS='|' read -r nombre archivo pid inicio duracion status log_size ultima_linea progreso <<< "$datos"

    local nombre_corto=$(echo "$nombre" | sed "s/${TMUX_PREFIX}-//")
    local archivo_base=$(basename "$archivo" 2>/dev/null || echo "N/A")
    local duracion_fmt=$(formatear_duracion $duracion)
    local size_fmt=$(formatear_bytes $log_size)

    # Color según status
    local color_status=""
    local simbolo=""
    case "$status" in
        RUNNING)
            color_status="${C_YELLOW}"
            simbolo="${SYM_RUNNING}"
            ;;
        COMPLETADO)
            color_status="${C_GREEN}"
            simbolo="${SYM_SUCCESS}"
            ;;
        ERROR)
            color_status="${C_RED}"
            simbolo="${SYM_ERROR}"
            ;;
        *)
            color_status="${C_CYAN}"
            simbolo="${SYM_RUNNING}"
            ;;
    esac

    echo -e "\n${C_BOLD}${color_status}${simbolo} ${nombre_corto}${C_NC}"
    echo -e "${C_BOLD}├─ Archivo:${C_NC}     $archivo_base"
    echo -e "${C_BOLD}├─ PID:${C_NC}         $pid"
    echo -e "${C_BOLD}├─ Inicio:${C_NC}      $inicio"
    echo -e "${C_BOLD}├─ Duración:${C_NC}    $duracion_fmt"
    echo -e "${C_BOLD}├─ Status:${C_NC}      ${color_status}$status${C_NC}"
    echo -e "${C_BOLD}├─ Log size:${C_NC}    $size_fmt"

    if [ -n "$progreso" ]; then
        echo -e "${C_BOLD}├─ Progreso:${C_NC}    $progreso"
    fi

    if [ -n "$ultima_linea" ]; then
        # Limpiar colores ANSI de la línea
        local linea_limpia=$(echo "$ultima_linea" | sed 's/\x1b\[[0-9;]*m//g')
        echo -e "${C_BOLD}└─ Última:${C_NC}      ${C_DIM}${linea_limpia}${C_NC}"
    fi

    echo -e "${C_DIM}   tmux attach-session -t $nombre${C_NC}"
    echo -e "${C_CYAN}───────────────────────────────────────────────────────────────────────────────${C_NC}"
}

renderizar_dashboard() {
    limpiar_pantalla

    local sesiones=($(obtener_sesiones_activas))
    local num_sesiones=${#sesiones[@]}

    renderizar_cabecera $num_sesiones

    if [ $num_sesiones -eq 0 ]; then
        echo -e "\n${C_DIM}   No hay sesiones de importación activas${C_NC}\n"
        echo -e "${C_CYAN}───────────────────────────────────────────────────────────────────────────────${C_NC}"
        return 0
    fi

    for sesion in "${sesiones[@]}"; do
        local info=$(obtener_info_sesion_completa "$sesion")
        renderizar_sesion "$info"
    done

    # Pie de página
    echo ""
    echo -e "${C_DIM}Esperando $INTERVALO segundos antes de actualizar...${C_NC}"
}

# ============================================================================
# SALIDA JSON
# ============================================================================

generar_json() {
    local sesiones=($(obtener_sesiones_activas))

    echo "{"
    echo "  \"timestamp\": \"$(obtener_timestamp)\","
    echo "  \"total_sesiones\": ${#sesiones[@]},"
    echo "  \"sesiones\": ["

    local primera=true
    for sesion in "${sesiones[@]}"; do
        local info=$(obtener_info_sesion_completa "$sesion")
        IFS='|' read -r nombre archivo pid inicio duracion status log_size ultima_linea progreso <<< "$info"

        [ "$primera" = true ] && primera=false || echo ","

        cat << EOF
    {
      "nombre": "$nombre",
      "archivo": "$archivo",
      "pid": "$pid",
      "inicio": "$inicio",
      "duracion_segundos": $duracion,
      "status": "$status",
      "log_size_bytes": $log_size,
      "progreso": "$progreso",
      "ultima_linea": "$(echo "$ultima_linea" | sed 's/"/\\"/g')"
    }
EOF
    done

    echo ""
    echo "  ]"
    echo "}"
}

# ============================================================================
# MODO INTERACTIVO
# ============================================================================

modo_interactivo() {
    # Configurar terminal para lectura no bloqueante
    if [ -t 0 ]; then
        stty -echo -icanon time 0 min 0
    fi

    trap 'stty sane; exit 0' EXIT INT TERM

    while true; do
        renderizar_dashboard

        # Esperar INTERVALO segundos, pero revisar input cada 0.5s
        local contador=0
        while [ $contador -lt $((INTERVALO * 2)) ]; do
            # Leer input si hay disponible
            read -t 0.5 -n 1 tecla 2>/dev/null || true

            case "$tecla" in
                q|Q)
                    stty sane
                    echo -e "\n${C_GREEN}Monitor detenido${C_NC}"
                    exit 0
                    ;;
                r|R)
                    break 2  # Romper ambos loops para refrescar inmediatamente
                    ;;
                l|L)
                    stty sane
                    limpiar_pantalla
                    echo -e "${C_BOLD}LOGS DISPONIBLES:${C_NC}\n"
                    ls -lhtr "$DIR_LOGS"/*.log 2>/dev/null | tail -10 || echo "No hay logs"
                    echo -e "\n${C_DIM}Presiona ENTER para volver al monitor...${C_NC}"
                    read
                    stty -echo -icanon time 0 min 0
                    break 2
                    ;;
                c|C)
                    stty sane
                    limpiar_pantalla
                    echo -e "${C_BOLD}Limpiando sesiones finalizadas...${C_NC}\n"
                    "${DIR_TRABAJO}/importar_tmux.sh" --cleanup
                    echo -e "\n${C_DIM}Presiona ENTER para volver al monitor...${C_NC}"
                    read
                    stty -echo -icanon time 0 min 0
                    break 2
                    ;;
            esac

            contador=$((contador + 1))
        done
    done
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    # Procesar argumentos
    while [ $# -gt 0 ]; do
        case "$1" in
            --once)
                MODO_CONTINUO=false
                shift
                ;;
            --interval|-i)
                INTERVALO="$2"
                shift 2
                ;;
            --json|-j)
                MODO_JSON=true
                MODO_CONTINUO=false
                shift
                ;;
            --help|-h)
                cat << EOF
USO: $(basename "$0") [OPCIONES]

OPCIONES:
    --once                 Mostrar una vez y salir
    --interval N, -i N     Actualizar cada N segundos (por defecto: 5)
    --json, -j             Salida en formato JSON
    --help, -h             Mostrar esta ayuda

CONTROLES INTERACTIVOS:
    q    Salir del monitor
    r    Refrescar ahora
    l    Ver lista de logs
    c    Limpiar sesiones finalizadas

EJEMPLOS:
    # Monitor continuo
    ./monitor_tmux.sh

    # Actualizar cada 10 segundos
    ./monitor_tmux.sh --interval 10

    # Ver una vez y salir
    ./monitor_tmux.sh --once

    # Salida JSON para scripts
    ./monitor_tmux.sh --json

EOF
                exit 0
                ;;
            *)
                echo "Opción desconocida: $1"
                exit 1
                ;;
        esac
    done

    # Crear directorios si no existen
    mkdir -p "$DIR_SESSIONS" "$DIR_LOGS"

    # Ejecutar modo correspondiente
    if [ "$MODO_JSON" = true ]; then
        generar_json
    elif [ "$MODO_CONTINUO" = true ]; then
        modo_interactivo
    else
        renderizar_dashboard
    fi
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

main "$@"
