#!/bin/bash
################################################################################
# VIGILANTE PERMANENTE - Importador Automático Continuo con TMUX
################################################################################
# Servicio permanente que monitorea el directorio importar_aqui/ y procesa
# automáticamente cualquier archivo CSV nuevo que aparezca
#
# CARACTERÍSTICAS:
#   ✓ Monitoreo continuo 24/7
#   ✓ Procesamiento automático de archivos nuevos
#   ✓ Ejecución en tmux para persistencia total
#   ✓ Detección de archivos por inotify (instantáneo)
#   ✓ Cola de procesamiento inteligente
#   ✓ Reintentos automáticos en caso de error
#   ✓ Logs detallados de actividad
#   ✓ Control de carga del sistema
#   ✓ Notificaciones de estado
#
# USO:
#   ./vigilante_permanente.sh start      # Iniciar vigilante en tmux
#   ./vigilante_permanente.sh stop       # Detener vigilante
#   ./vigilante_permanente.sh status     # Ver estado del vigilante
#   ./vigilante_permanente.sh restart    # Reiniciar vigilante
#   ./vigilante_permanente.sh logs       # Ver logs del vigilante
#   ./vigilante_permanente.sh attach     # Conectar a sesión del vigilante
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
readonly DIR_PROCESADOS="${DIR_TRABAJO}/procesados"
readonly DIR_ERRORES="${DIR_TRABAJO}/errores"
readonly DIR_LOGS="${DIR_TRABAJO}/logs"
readonly DIR_VIGILANTE="${DIR_LOGS}/vigilante"

# Configuración del vigilante
readonly SESION_VIGILANTE="koha-vigilante-permanente"
readonly LOG_VIGILANTE="${DIR_VIGILANTE}/vigilante.log"
readonly PID_FILE="${DIR_TRABAJO}/.vigilante.pid"
readonly STATE_FILE="${DIR_TRABAJO}/.vigilante.state"

# Configuración de comportamiento
readonly INTERVALO_ESCANEO=30          # Segundos entre escaneos si no hay inotify
readonly MAX_IMPORTACIONES_SIMULTANEAS=3
readonly TIEMPO_ESPERA_ENTRE_ARCHIVOS=10  # Segundos de espera entre procesar archivos
readonly REINTENTOS_ERROR=2
readonly TIEMPO_REINTENTO=300          # 5 minutos entre reintentos

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
    echo "  VIGILANTE PERMANENTE - IMPORTADOR AUTOMÁTICO CONTINUO"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${C_NC}"
}

crear_directorios() {
    mkdir -p "$DIR_VIGILANTE" "$DIR_IMPORTAR" "$DIR_PROCESADOS" "$DIR_ERRORES"
}

# ============================================================================
# FUNCIONES DE GESTIÓN DE SESIÓN
# ============================================================================

sesion_existe() {
    tmux has-session -t "$SESION_VIGILANTE" 2>/dev/null
}

obtener_pid_vigilante() {
    if [ -f "$PID_FILE" ]; then
        cat "$PID_FILE"
    fi
}

vigilante_corriendo() {
    local pid=$(obtener_pid_vigilante)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        return 0
    fi
    return 1
}

# ============================================================================
# FUNCIÓN PRINCIPAL DEL VIGILANTE (SE EJECUTA EN TMUX)
# ============================================================================

ejecutar_vigilante() {
    # Redirigir salida a log
    exec > >(tee -a "$LOG_VIGILANTE") 2>&1

    echo ""
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  VIGILANTE PERMANENTE INICIADO"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "Fecha/Hora:      $(date +'%Y-%m-%d %H:%M:%S')"
    echo "PID:             $$"
    echo "Directorio:      $DIR_IMPORTAR"
    echo "Max simultáneas: $MAX_IMPORTACIONES_SIMULTANEAS"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo ""

    # Guardar PID
    echo $$ > "$PID_FILE"

    # Inicializar estado
    cat > "$STATE_FILE" << EOF
{
    "estado": "ACTIVO",
    "pid": $$,
    "inicio": "$(date +'%Y-%m-%d %H:%M:%S')",
    "archivos_procesados": 0,
    "archivos_error": 0,
    "ultimo_archivo": "",
    "ultima_actividad": "$(date +'%Y-%m-%d %H:%M:%S')"
}
EOF

    # Verificar si inotify-tools está disponible
    local usar_inotify=false
    if command -v inotifywait &> /dev/null; then
        usar_inotify=true
        echo "[$(date +'%H:%M:%S')] ✓ inotify-tools detectado - Modo de monitoreo instantáneo"
    else
        echo "[$(date +'%H:%M:%S')] ⚠ inotify-tools no disponible - Modo de escaneo periódico (cada ${INTERVALO_ESCANEO}s)"
        echo "[$(date +'%H:%M:%S')]   Instala con: sudo apt install inotify-tools"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  VIGILANTE EN ESPERA - Monitoreando nuevos archivos..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Función para procesar un archivo
    procesar_archivo() {
        local archivo="$1"
        local intentos="${2:-1}"

        echo ""
        echo "[$(date +'%H:%M:%S')] ╔═══════════════════════════════════════════════════════════════════════════════╗"
        echo "[$(date +'%H:%M:%S')] ║  NUEVO ARCHIVO DETECTADO                                                      ║"
        echo "[$(date +'%H:%M:%S')] ╚═══════════════════════════════════════════════════════════════════════════════╝"
        echo "[$(date +'%H:%M:%S')] Archivo:  $(basename "$archivo")"
        echo "[$(date +'%H:%M:%S')] Intento:  $intentos de $((REINTENTOS_ERROR + 1))"
        echo "[$(date +'%H:%M:%S')] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        # Verificar importaciones activas
        local activas=$(tmux list-sessions 2>/dev/null | grep -c "koha-import-" || echo "0")
        echo "[$(date +'%H:%M:%S')] Importaciones activas: $activas/$MAX_IMPORTACIONES_SIMULTANEAS"

        # Esperar si hay demasiadas importaciones activas
        while [ $activas -ge $MAX_IMPORTACIONES_SIMULTANEAS ]; do
            echo "[$(date +'%H:%M:%S')] ⏳ Esperando... Hay $activas importaciones en curso"
            sleep 30
            activas=$(tmux list-sessions 2>/dev/null | grep -c "koha-import-" || echo "0")
        done

        # Intentar importar
        echo "[$(date +'%H:%M:%S')] 🚀 Iniciando importación en sesión tmux..."

        if "${SCRIPT_DIR}/importar_tmux.sh" "$archivo"; then
            echo "[$(date +'%H:%M:%S')] ✓ Sesión tmux creada exitosamente"

            # Actualizar estadísticas
            actualizar_estado "archivos_procesados" "$(($(jq -r '.archivos_procesados' "$STATE_FILE") + 1))"
            actualizar_estado "ultimo_archivo" "$(basename "$archivo")"
            actualizar_estado "ultima_actividad" "$(date +'%Y-%m-%d %H:%M:%S')"

            return 0
        else
            echo "[$(date +'%H:%M:%S')] ✗ Error al crear sesión tmux"

            # Reintentar si no se alcanzó el máximo
            if [ $intentos -le $REINTENTOS_ERROR ]; then
                echo "[$(date +'%H:%M:%S')] ⏰ Reintentando en $TIEMPO_REINTENTO segundos..."
                sleep $TIEMPO_REINTENTO
                procesar_archivo "$archivo" $((intentos + 1))
            else
                echo "[$(date +'%H:%M:%S')] ✗ Archivo falló después de $intentos intentos"

                # Mover a errores
                local timestamp=$(date +%Y%m%d_%H%M%S)
                mv "$archivo" "$DIR_ERRORES/$(basename "${archivo%.csv}_ERROR_VIGILANTE_${timestamp}.csv")"

                actualizar_estado "archivos_error" "$(($(jq -r '.archivos_error' "$STATE_FILE") + 1))"
                actualizar_estado "ultima_actividad" "$(date +'%Y-%m-%d %H:%M:%S')"

                return 1
            fi
        fi
    }

    # Función para actualizar estado
    actualizar_estado() {
        local campo="$1"
        local valor="$2"

        if [ -f "$STATE_FILE" ]; then
            jq ".$campo = \"$valor\"" "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
        fi
    }

    # Procesar archivos existentes al inicio
    echo "[$(date +'%H:%M:%S')] 🔍 Escaneando archivos existentes..."
    local archivos_existentes=("$DIR_IMPORTAR"/*.csv)

    if [ -f "${archivos_existentes[0]}" ]; then
        local count=0
        for archivo in "${archivos_existentes[@]}"; do
            count=$((count + 1))
        done

        echo "[$(date +'%H:%M:%S')] 📦 Encontrados $count archivo(s) pendiente(s)"

        for archivo in "${archivos_existentes[@]}"; do
            if [ -f "$archivo" ]; then
                procesar_archivo "$archivo"

                # Esperar entre archivos
                if [ -f "$DIR_IMPORTAR"/*.csv ] 2>/dev/null; then
                    echo "[$(date +'%H:%M:%S')] ⏸  Esperando ${TIEMPO_ESPERA_ENTRE_ARCHIVOS}s antes del siguiente archivo..."
                    sleep $TIEMPO_ESPERA_ENTRE_ARCHIVOS
                fi
            fi
        done
    else
        echo "[$(date +'%H:%M:%S')] 📭 No hay archivos pendientes"
    fi

    echo ""
    echo "[$(date +'%H:%M:%S')] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[$(date +'%H:%M:%S')] 👁  VIGILANCIA ACTIVA - Esperando nuevos archivos..."
    echo "[$(date +'%H:%M:%S')] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # Loop principal de monitoreo
    if [ "$usar_inotify" = true ]; then
        # Modo inotify (instantáneo)
        echo "[$(date +'%H:%M:%S')] 🔔 Modo instantáneo activado (inotify)"

        inotifywait -m -e close_write,moved_to --format '%w%f' "$DIR_IMPORTAR" 2>/dev/null | while read archivo; do
            if [[ "$archivo" == *.csv ]]; then
                echo "[$(date +'%H:%M:%S')] 🔔 ¡Nuevo archivo detectado!"

                # Esperar un poco para asegurar que el archivo está completo
                sleep 2

                if [ -f "$archivo" ]; then
                    procesar_archivo "$archivo"

                    echo ""
                    echo "[$(date +'%H:%M:%S')] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo "[$(date +'%H:%M:%S')] 👁  Vigilancia activa - Esperando nuevos archivos..."
                    echo "[$(date +'%H:%M:%S')] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
                    echo ""
                fi
            fi
        done
    else
        # Modo escaneo periódico
        echo "[$(date +'%H:%M:%S')] 🔄 Modo periódico activado (cada ${INTERVALO_ESCANEO}s)"

        while true; do
            local archivos=("$DIR_IMPORTAR"/*.csv)

            if [ -f "${archivos[0]}" ]; then
                for archivo in "${archivos[@]}"; do
                    if [ -f "$archivo" ]; then
                        echo "[$(date +'%H:%M:%S')] 🔍 Archivo detectado en escaneo periódico"
                        procesar_archivo "$archivo"

                        # Esperar entre archivos
                        if ls "$DIR_IMPORTAR"/*.csv 1> /dev/null 2>&1; then
                            sleep $TIEMPO_ESPERA_ENTRE_ARCHIVOS
                        fi
                    fi
                done
            fi

            # Heartbeat cada 5 minutos para mostrar que está vivo
            local minuto=$(date +%M)
            if [ $((minuto % 5)) -eq 0 ]; then
                echo "[$(date +'%H:%M:%S')] 💓 Vigilante activo - $(tmux list-sessions 2>/dev/null | grep -c "koha-import-" || echo "0") importaciones en curso"
            fi

            sleep $INTERVALO_ESCANEO
        done
    fi
}

# ============================================================================
# COMANDOS DE CONTROL
# ============================================================================

cmd_start() {
    banner

    if sesion_existe; then
        log_warning "El vigilante ya está ejecutándose"
        log_info "Usa './vigilante_permanente.sh status' para ver el estado"
        log_info "O './vigilante_permanente.sh attach' para conectar a la sesión"
        return 1
    fi

    crear_directorios

    log_info "Iniciando vigilante permanente en sesión tmux..."
    separador

    # Crear sesión tmux que ejecuta el vigilante
    tmux new-session -d -s "$SESION_VIGILANTE" \
        "cd '$DIR_TRABAJO' && bash -c 'source \"${BASH_SOURCE[0]}\" && ejecutar_vigilante'"

    sleep 2

    if sesion_existe; then
        log_success "Vigilante iniciado exitosamente"
        echo ""
        echo -e "${C_BOLD}Sesión tmux:${C_NC}  $SESION_VIGILANTE"
        echo -e "${C_BOLD}Log:${C_NC}          $LOG_VIGILANTE"
        echo ""
        separador
        echo ""
        log_info "El vigilante procesará automáticamente cualquier archivo CSV"
        log_info "que se copie en: ${C_YELLOW}$DIR_IMPORTAR${C_NC}"
        echo ""
        log_info "Comandos útiles:"
        echo -e "  ${C_YELLOW}./vigilante_permanente.sh status${C_NC}   - Ver estado"
        echo -e "  ${C_YELLOW}./vigilante_permanente.sh attach${C_NC}   - Conectar a la sesión"
        echo -e "  ${C_YELLOW}./vigilante_permanente.sh logs${C_NC}     - Ver logs en tiempo real"
        echo -e "  ${C_YELLOW}./vigilante_permanente.sh stop${C_NC}     - Detener vigilante"
        separador

        return 0
    else
        log_error "Error al iniciar el vigilante"
        return 1
    fi
}

cmd_stop() {
    banner

    if ! sesion_existe; then
        log_warning "El vigilante no está ejecutándose"
        return 1
    fi

    log_warning "Deteniendo vigilante permanente..."

    # Actualizar estado
    if [ -f "$STATE_FILE" ]; then
        jq '.estado = "DETENIDO"' "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
    fi

    tmux kill-session -t "$SESION_VIGILANTE"

    rm -f "$PID_FILE"

    log_success "Vigilante detenido"
}

cmd_status() {
    banner

    if sesion_existe; then
        log_success "Vigilante ACTIVO"
        separador

        echo -e "${C_BOLD}Sesión tmux:${C_NC}  $SESION_VIGILANTE"

        if [ -f "$PID_FILE" ]; then
            local pid=$(cat "$PID_FILE")
            echo -e "${C_BOLD}PID:${C_NC}          $pid"
        fi

        if [ -f "$STATE_FILE" ]; then
            echo -e "${C_BOLD}Estado:${C_NC}"
            jq -r 'to_entries | .[] | "  \(.key | ljust(20)) = \(.value)"' "$STATE_FILE"
        fi

        echo ""
        echo -e "${C_BOLD}Importaciones activas:${C_NC}"
        local activas=$(tmux list-sessions 2>/dev/null | grep -c "koha-import-" || echo "0")
        echo "  $activas sesión(es) de importación en curso"

        echo ""
        echo -e "${C_BOLD}Archivos pendientes:${C_NC}"
        local pendientes=$(ls -1 "$DIR_IMPORTAR"/*.csv 2>/dev/null | wc -l)
        echo "  $pendientes archivo(s) en cola"

        if [ -f "$LOG_VIGILANTE" ]; then
            echo ""
            echo -e "${C_BOLD}Últimas 5 líneas del log:${C_NC}"
            tail -5 "$LOG_VIGILANTE" | sed 's/^/  │ /'
        fi

        separador

    else
        log_warning "Vigilante NO está ejecutándose"
        echo ""
        log_info "Inicia el vigilante con: ${C_YELLOW}./vigilante_permanente.sh start${C_NC}"
    fi
}

cmd_logs() {
    if [ ! -f "$LOG_VIGILANTE" ]; then
        log_error "No hay logs disponibles"
        return 1
    fi

    log_info "Mostrando logs en tiempo real..."
    log_info "Presiona Ctrl+C para salir"
    echo ""
    sleep 2

    tail -f "$LOG_VIGILANTE"
}

cmd_attach() {
    if ! sesion_existe; then
        log_error "El vigilante no está ejecutándose"
        log_info "Inicia el vigilante con: ./vigilante_permanente.sh start"
        return 1
    fi

    log_info "Conectando a la sesión del vigilante..."
    log_info "Para desconectar sin detener: ${C_YELLOW}Ctrl+B luego D${C_NC}"
    sleep 2

    tmux attach-session -t "$SESION_VIGILANTE"
}

cmd_restart() {
    banner
    log_info "Reiniciando vigilante..."

    cmd_stop
    sleep 2
    cmd_start
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local comando="${1:-}"

    case "$comando" in
        start)
            cmd_start
            ;;
        stop)
            cmd_stop
            ;;
        status)
            cmd_status
            ;;
        restart)
            cmd_restart
            ;;
        logs)
            cmd_logs
            ;;
        attach)
            cmd_attach
            ;;
        "")
            banner
            cat << EOF
USO: $(basename "$0") COMANDO

COMANDOS:
    start      Iniciar el vigilante permanente
    stop       Detener el vigilante
    status     Ver estado del vigilante
    restart    Reiniciar el vigilante
    logs       Ver logs en tiempo real
    attach     Conectar a la sesión del vigilante

DESCRIPCIÓN:
    El vigilante permanente monitorea el directorio importar_aqui/
    y procesa automáticamente cualquier archivo CSV nuevo que aparezca.

    Características:
    • Monitoreo continuo 24/7
    • Ejecución en tmux (persiste desconexiones)
    • Procesamiento automático e instantáneo
    • Control de carga (max importaciones simultáneas)
    • Reintentos automáticos en caso de error
    • Logs detallados

EJEMPLOS:
    # Iniciar vigilante
    ./vigilante_permanente.sh start

    # Ver estado
    ./vigilante_permanente.sh status

    # Copiar archivo y el vigilante lo procesa automáticamente
    cp /origen/ARCHIVO.csv importar_aqui/

    # Ver logs en tiempo real
    ./vigilante_permanente.sh logs

    # Detener vigilante
    ./vigilante_permanente.sh stop

EOF
            ;;
        *)
            log_error "Comando desconocido: $comando"
            log_info "Usa './vigilante_permanente.sh' para ver la ayuda"
            exit 1
            ;;
    esac
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

# Si la función ejecutar_vigilante está definida y es llamada desde dentro
# del script, no ejecutar main
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
