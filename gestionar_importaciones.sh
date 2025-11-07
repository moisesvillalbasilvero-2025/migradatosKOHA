#!/bin/bash
################################################################################
# GESTOR DE IMPORTACIONES - Utilidad de Administración Completa
################################################################################
# Herramienta centralizada para gestionar todas las importaciones
# Proporciona una interfaz unificada para control total del sistema
#
# USO:
#   ./gestionar_importaciones.sh                    # Menú interactivo
#   ./gestionar_importaciones.sh listar             # Listar sesiones
#   ./gestionar_importaciones.sh conectar NOMBRE    # Conectar a sesión
#   ./gestionar_importaciones.sh logs NOMBRE        # Ver log de sesión
#   ./gestionar_importaciones.sh detener NOMBRE     # Detener sesión
#   ./gestionar_importaciones.sh detener-todas      # Detener todas
#   ./gestionar_importaciones.sh resumen            # Resumen del sistema
#   ./gestionar_importaciones.sh exportar           # Exportar estadísticas
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
readonly DIR_LOGS="${DIR_TRABAJO}/logs"
readonly DIR_TMUX_LOGS="${DIR_LOGS}/tmux"
readonly DIR_SESSIONS="${DIR_TRABAJO}/.sessions"
readonly DIR_PROCESADOS="${DIR_TRABAJO}/procesados"
readonly DIR_ERRORES="${DIR_TRABAJO}/errores"
readonly DIR_IMPORTAR="${DIR_TRABAJO}/importar_aqui"
readonly INSTANCIA_KOHA="koha-cnc"
readonly TMUX_PREFIX="koha-import"

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
    clear
    echo -e "${C_BOLD}${C_CYAN}"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo "  GESTOR DE IMPORTACIONES KOHA - CONTROL CENTRALIZADO"
    echo "═══════════════════════════════════════════════════════════════════════════════"
    echo -e "${C_NC}"
}

pausar() {
    echo ""
    echo -e "${C_DIM}Presiona ENTER para continuar...${C_NC}"
    read
}

# ============================================================================
# FUNCIONES DE DATOS
# ============================================================================

obtener_sesiones_activas() {
    tmux list-sessions 2>/dev/null | grep "^${TMUX_PREFIX}-" | awk -F: '{print $1}' || true
}

contar_sesiones_activas() {
    obtener_sesiones_activas | wc -l
}

obtener_estadisticas_koha() {
    local biblios=$(sudo koha-mysql "$INSTANCIA_KOHA" -N -e "SELECT COUNT(*) FROM biblio" 2>/dev/null || echo "0")
    local items=$(sudo koha-mysql "$INSTANCIA_KOHA" -N -e "SELECT COUNT(*) FROM items" 2>/dev/null || echo "0")
    local bibliotecas=$(sudo koha-mysql "$INSTANCIA_KOHA" -N -e "SELECT COUNT(*) FROM branches" 2>/dev/null || echo "0")

    echo "$biblios|$items|$bibliotecas"
}

contar_archivos_pendientes() {
    find "$DIR_IMPORTAR" -maxdepth 1 -name "*.csv" 2>/dev/null | wc -l
}

contar_archivos_procesados() {
    find "$DIR_PROCESADOS" -maxdepth 1 -name "*.csv" 2>/dev/null | wc -l
}

contar_archivos_con_errores() {
    find "$DIR_ERRORES" -maxdepth 1 -name "*.csv" 2>/dev/null | wc -l
}

# ============================================================================
# MENÚ PRINCIPAL
# ============================================================================

mostrar_menu_principal() {
    banner

    # Recopilar información del sistema
    local sesiones_activas=$(contar_sesiones_activas)
    local archivos_pendientes=$(contar_archivos_pendientes)
    local archivos_procesados=$(contar_archivos_procesados)
    local archivos_errores=$(contar_archivos_con_errores)

    IFS='|' read -r biblios items bibliotecas <<< "$(obtener_estadisticas_koha)"

    # Panel de estado
    echo -e "${C_BOLD}ESTADO DEL SISTEMA${C_NC}"
    separador
    echo -e "${C_BOLD}Importaciones:${C_NC}"
    echo -e "  Sesiones activas:       ${C_YELLOW}$sesiones_activas${C_NC}"
    echo -e "  Archivos pendientes:    ${C_CYAN}$archivos_pendientes${C_NC}"
    echo -e "  Archivos procesados:    ${C_GREEN}$archivos_procesados${C_NC}"
    echo -e "  Archivos con errores:   ${C_RED}$archivos_errores${C_NC}"
    echo ""
    echo -e "${C_BOLD}Base de Datos Koha:${C_NC}"
    echo -e "  Registros bibliográficos: ${C_GREEN}$biblios${C_NC}"
    echo -e "  Items (ejemplares):       ${C_GREEN}$items${C_NC}"
    echo -e "  Bibliotecas:              ${C_GREEN}$bibliotecas${C_NC}"
    separador

    # Opciones del menú
    echo ""
    echo -e "${C_BOLD}OPCIONES DISPONIBLES${C_NC}"
    separador
    echo "  1) Iniciar nueva importación"
    echo "  2) Ver sesiones activas"
    echo "  3) Conectar a sesión existente"
    echo "  4) Monitoreo en tiempo real"
    echo "  5) Ver logs de sesión"
    echo "  6) Detener sesión"
    echo "  7) Detener todas las sesiones"
    echo "  8) Limpiar sesiones finalizadas"
    echo "  9) Ver archivos pendientes"
    echo " 10) Ver resumen detallado del sistema"
    echo " 11) Exportar estadísticas"
    echo " 12) Ver logs de Koha"
    echo ""
    echo -e "${C_BOLD}${C_MAGENTA}VIGILANTE PERMANENTE:${C_NC}"
    echo " 13) Iniciar vigilante permanente (importación automática continua)"
    echo " 14) Detener vigilante permanente"
    echo " 15) Ver estado del vigilante"
    echo "  0) Salir"
    separador
    echo ""
}

# ============================================================================
# OPCIÓN 1: INICIAR NUEVA IMPORTACIÓN
# ============================================================================

menu_iniciar_importacion() {
    banner
    echo -e "${C_BOLD}INICIAR NUEVA IMPORTACIÓN${C_NC}"
    separador

    local archivos=("$DIR_IMPORTAR"/*.csv)

    if [ ! -f "${archivos[0]}" ]; then
        log_warning "No hay archivos CSV en $DIR_IMPORTAR"
        pausar
        return
    fi

    echo -e "${C_BOLD}Archivos disponibles:${C_NC}\n"

    local i=1
    for archivo in "${archivos[@]}"; do
        local size=$(stat -c%s "$archivo" 2>/dev/null || echo "0")
        local size_fmt=$(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "${size}B")
        echo -e "  $i) $(basename "$archivo")  ${C_DIM}($size_fmt)${C_NC}"
        i=$((i + 1))
    done

    echo ""
    echo -e "  A) Importar TODOS los archivos"
    echo -e "  0) Volver"

    separador
    echo -ne "${C_YELLOW}Selecciona una opción: ${C_NC}"
    read opcion

    case "$opcion" in
        0)
            return
            ;;
        [Aa])
            log_info "Iniciando importación de todos los archivos..."
            "${SCRIPT_DIR}/importar_tmux.sh" --all
            pausar
            ;;
        [1-9]|[1-9][0-9])
            local idx=$((opcion - 1))
            if [ $idx -lt ${#archivos[@]} ]; then
                local archivo="${archivos[$idx]}"
                log_info "Iniciando importación de: $(basename "$archivo")"
                "${SCRIPT_DIR}/importar_tmux.sh" "$archivo"
                pausar
            else
                log_error "Opción inválida"
                pausar
            fi
            ;;
        *)
            log_error "Opción inválida"
            pausar
            ;;
    esac
}

# ============================================================================
# OPCIÓN 2: VER SESIONES ACTIVAS
# ============================================================================

menu_listar_sesiones() {
    banner
    echo -e "${C_BOLD}SESIONES ACTIVAS${C_NC}"
    separador

    "${SCRIPT_DIR}/importar_tmux.sh" --status

    pausar
}

# ============================================================================
# OPCIÓN 3: CONECTAR A SESIÓN
# ============================================================================

menu_conectar_sesion() {
    banner
    echo -e "${C_BOLD}CONECTAR A SESIÓN EXISTENTE${C_NC}"
    separador

    local sesiones=($(obtener_sesiones_activas))

    if [ ${#sesiones[@]} -eq 0 ]; then
        log_warning "No hay sesiones activas"
        pausar
        return
    fi

    echo -e "${C_BOLD}Sesiones disponibles:${C_NC}\n"

    local i=1
    for sesion in "${sesiones[@]}"; do
        local nombre_corto=$(echo "$sesion" | sed "s/${TMUX_PREFIX}-//")
        echo "  $i) $nombre_corto"
        i=$((i + 1))
    done

    echo ""
    echo "  0) Volver"

    separador
    echo -ne "${C_YELLOW}Selecciona una sesión: ${C_NC}"
    read opcion

    if [ "$opcion" = "0" ]; then
        return
    fi

    if [ "$opcion" -ge 1 ] && [ "$opcion" -le ${#sesiones[@]} ]; then
        local idx=$((opcion - 1))
        local sesion="${sesiones[$idx]}"

        log_info "Conectando a: $sesion"
        log_info "Para desconectar sin detener: Ctrl+B luego D"
        sleep 2

        tmux attach-session -t "$sesion"
    else
        log_error "Opción inválida"
        pausar
    fi
}

# ============================================================================
# OPCIÓN 4: MONITOREO EN TIEMPO REAL
# ============================================================================

menu_monitor() {
    "${SCRIPT_DIR}/monitor_tmux.sh"
}

# ============================================================================
# OPCIÓN 5: VER LOGS
# ============================================================================

menu_ver_logs() {
    banner
    echo -e "${C_BOLD}VER LOGS DE SESIÓN${C_NC}"
    separador

    local logs=($(ls -1t "$DIR_TMUX_LOGS"/*.log 2>/dev/null | head -20))

    if [ ${#logs[@]} -eq 0 ]; then
        log_warning "No hay logs disponibles"
        pausar
        return
    fi

    echo -e "${C_BOLD}Logs disponibles (últimos 20):${C_NC}\n"

    local i=1
    for log in "${logs[@]}"; do
        local nombre=$(basename "$log" .log)
        local size=$(stat -c%s "$log" 2>/dev/null || echo "0")
        local size_fmt=$(numfmt --to=iec-i --suffix=B $size 2>/dev/null || echo "${size}B")
        local fecha=$(stat -c%y "$log" 2>/dev/null | cut -d' ' -f1)

        echo -e "  $i) $nombre  ${C_DIM}($size_fmt, $fecha)${C_NC}"
        i=$((i + 1))
    done

    echo ""
    echo "  0) Volver"

    separador
    echo -ne "${C_YELLOW}Selecciona un log para ver: ${C_NC}"
    read opcion

    if [ "$opcion" = "0" ]; then
        return
    fi

    if [ "$opcion" -ge 1 ] && [ "$opcion" -le ${#logs[@]} ]; then
        local idx=$((opcion - 1))
        local log="${logs[$idx]}"

        clear
        echo -e "${C_BOLD}${C_CYAN}LOG: $(basename "$log")${C_NC}"
        separador
        less -R "$log"
    else
        log_error "Opción inválida"
        pausar
    fi
}

# ============================================================================
# OPCIÓN 6: DETENER SESIÓN
# ============================================================================

menu_detener_sesion() {
    banner
    echo -e "${C_BOLD}DETENER SESIÓN${C_NC}"
    separador

    local sesiones=($(obtener_sesiones_activas))

    if [ ${#sesiones[@]} -eq 0 ]; then
        log_warning "No hay sesiones activas"
        pausar
        return
    fi

    echo -e "${C_BOLD}Sesiones activas:${C_NC}\n"

    local i=1
    for sesion in "${sesiones[@]}"; do
        local nombre_corto=$(echo "$sesion" | sed "s/${TMUX_PREFIX}-//")
        echo "  $i) $nombre_corto"
        i=$((i + 1))
    done

    echo ""
    echo "  0) Volver"

    separador
    echo -ne "${C_YELLOW}Selecciona una sesión para detener: ${C_NC}"
    read opcion

    if [ "$opcion" = "0" ]; then
        return
    fi

    if [ "$opcion" -ge 1 ] && [ "$opcion" -le ${#sesiones[@]} ]; then
        local idx=$((opcion - 1))
        local sesion="${sesiones[$idx]}"

        echo ""
        echo -ne "${C_RED}¿Confirmas detener '$sesion'? [y/N]: ${C_NC}"
        read confirmacion

        if [[ "$confirmacion" =~ ^[Yy]$ ]]; then
            "${SCRIPT_DIR}/importar_tmux.sh" --kill "$sesion"
            log_success "Sesión detenida"
        else
            log_info "Cancelado"
        fi

        pausar
    else
        log_error "Opción inválida"
        pausar
    fi
}

# ============================================================================
# OPCIÓN 7: DETENER TODAS LAS SESIONES
# ============================================================================

menu_detener_todas() {
    banner
    echo -e "${C_BOLD}DETENER TODAS LAS SESIONES${C_NC}"
    separador

    local sesiones=($(obtener_sesiones_activas))

    if [ ${#sesiones[@]} -eq 0 ]; then
        log_warning "No hay sesiones activas"
        pausar
        return
    fi

    log_warning "Se detendrán ${#sesiones[@]} sesión(es) activa(s)"
    echo ""

    for sesion in "${sesiones[@]}"; do
        echo "  • $sesion"
    done

    echo ""
    echo -ne "${C_RED}¿Confirmas detener TODAS las sesiones? [y/N]: ${C_NC}"
    read confirmacion

    if [[ "$confirmacion" =~ ^[Yy]$ ]]; then
        for sesion in "${sesiones[@]}"; do
            log_info "Deteniendo: $sesion"
            "${SCRIPT_DIR}/importar_tmux.sh" --kill "$sesion"
        done
        log_success "Todas las sesiones han sido detenidas"
    else
        log_info "Cancelado"
    fi

    pausar
}

# ============================================================================
# OPCIÓN 10: RESUMEN DETALLADO
# ============================================================================

menu_resumen_detallado() {
    banner
    echo -e "${C_BOLD}RESUMEN DETALLADO DEL SISTEMA${C_NC}"
    separador

    # Estadísticas de archivos
    echo -e "\n${C_BOLD}1. ARCHIVOS${C_NC}"
    separador
    echo -e "${C_BOLD}Pendientes:${C_NC}    $(contar_archivos_pendientes)"
    echo -e "${C_BOLD}Procesados:${C_NC}    $(contar_archivos_procesados)"
    echo -e "${C_BOLD}Con errores:${C_NC}   $(contar_archivos_con_errores)"

    # Estadísticas de sesiones
    echo -e "\n${C_BOLD}2. SESIONES TMUX${C_NC}"
    separador
    echo -e "${C_BOLD}Activas:${C_NC}       $(contar_sesiones_activas)"

    # Base de datos Koha
    echo -e "\n${C_BOLD}3. BASE DE DATOS KOHA${C_NC}"
    separador

    IFS='|' read -r biblios items bibliotecas <<< "$(obtener_estadisticas_koha)"

    echo -e "${C_BOLD}Biblios:${C_NC}       $biblios"
    echo -e "${C_BOLD}Items:${C_NC}         $items"
    echo -e "${C_BOLD}Bibliotecas:${C_NC}   $bibliotecas"

    # Items por biblioteca (top 10)
    echo -e "\n${C_BOLD}4. ITEMS POR BIBLIOTECA (Top 10)${C_NC}"
    separador

    sudo koha-mysql "$INSTANCIA_KOHA" -e \
        "SELECT
            b.branchcode AS 'Código',
            LEFT(b.branchname, 40) AS 'Biblioteca',
            COUNT(i.itemnumber) AS 'Items'
        FROM branches b
        LEFT JOIN items i ON b.branchcode = i.homebranch
        GROUP BY b.branchcode, b.branchname
        HAVING COUNT(i.itemnumber) > 0
        ORDER BY COUNT(i.itemnumber) DESC
        LIMIT 10;" 2>/dev/null || log_warning "No se pudo consultar Koha"

    # Logs recientes
    echo -e "\n${C_BOLD}5. LOGS RECIENTES${C_NC}"
    separador

    ls -lht "$DIR_TMUX_LOGS"/*.log 2>/dev/null | head -5 | awk '{print "  " $9 "  (" $5 ")"}'

    # Espacio en disco
    echo -e "\n${C_BOLD}6. ESPACIO EN DISCO${C_NC}"
    separador

    df -h "$DIR_TRABAJO" | tail -1 | awk '{print "  Usado: " $3 " / " $2 "  (" $5 " ocupado)"}'

    separador
    pausar
}

# ============================================================================
# OPCIÓN 11: EXPORTAR ESTADÍSTICAS
# ============================================================================

menu_exportar_estadisticas() {
    banner
    echo -e "${C_BOLD}EXPORTAR ESTADÍSTICAS${C_NC}"
    separador

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local export_file="${DIR_LOGS}/estadisticas_${timestamp}.json"

    log_info "Generando estadísticas..."

    # Generar JSON
    cat > "$export_file" << EOF
{
  "timestamp": "$(date +'%Y-%m-%d %H:%M:%S')",
  "archivos": {
    "pendientes": $(contar_archivos_pendientes),
    "procesados": $(contar_archivos_procesados),
    "errores": $(contar_archivos_con_errores)
  },
  "sesiones": {
    "activas": $(contar_sesiones_activas)
  },
  "koha": {
    "biblios": $(sudo koha-mysql "$INSTANCIA_KOHA" -N -e "SELECT COUNT(*) FROM biblio" 2>/dev/null || echo "0"),
    "items": $(sudo koha-mysql "$INSTANCIA_KOHA" -N -e "SELECT COUNT(*) FROM items" 2>/dev/null || echo "0"),
    "bibliotecas": $(sudo koha-mysql "$INSTANCIA_KOHA" -N -e "SELECT COUNT(*) FROM branches" 2>/dev/null || echo "0")
  }
}
EOF

    log_success "Estadísticas exportadas a:"
    echo "  $export_file"

    pausar
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    # Verificar dependencias
    if ! command -v tmux &> /dev/null; then
        log_error "tmux no está instalado"
        exit 1
    fi

    # Modo comando directo
    if [ $# -gt 0 ]; then
        case "$1" in
            listar)
                menu_listar_sesiones
                ;;
            conectar)
                [ -n "${2:-}" ] && "${SCRIPT_DIR}/importar_tmux.sh" --attach "$2" || menu_conectar_sesion
                ;;
            logs)
                menu_ver_logs
                ;;
            detener)
                [ -n "${2:-}" ] && "${SCRIPT_DIR}/importar_tmux.sh" --kill "$2" || menu_detener_sesion
                ;;
            detener-todas)
                menu_detener_todas
                ;;
            resumen)
                menu_resumen_detallado
                ;;
            exportar)
                menu_exportar_estadisticas
                ;;
            *)
                log_error "Comando desconocido: $1"
                exit 1
                ;;
        esac
        exit 0
    fi

    # Modo interactivo
    while true; do
        mostrar_menu_principal

        echo -ne "${C_YELLOW}Selecciona una opción: ${C_NC}"
        read opcion

        case "$opcion" in
            1) menu_iniciar_importacion ;;
            2) menu_listar_sesiones ;;
            3) menu_conectar_sesion ;;
            4) menu_monitor ;;
            5) menu_ver_logs ;;
            6) menu_detener_sesion ;;
            7) menu_detener_todas ;;
            8)
                "${SCRIPT_DIR}/importar_tmux.sh" --cleanup
                pausar
                ;;
            9)
                clear
                echo -e "${C_BOLD}ARCHIVOS PENDIENTES${C_NC}"
                separador
                ls -lh "$DIR_IMPORTAR"/*.csv 2>/dev/null || log_info "No hay archivos pendientes"
                pausar
                ;;
            10) menu_resumen_detallado ;;
            11) menu_exportar_estadisticas ;;
            12)
                clear
                echo -e "${C_BOLD}LOGS DE KOHA${C_NC}"
                separador
                sudo tail -50 "/var/log/koha/${INSTANCIA_KOHA}/plack-error.log" 2>/dev/null || log_warning "No se pudo leer el log"
                pausar
                ;;
            13)
                clear
                "${SCRIPT_DIR}/vigilante_permanente.sh" start
                pausar
                ;;
            14)
                clear
                "${SCRIPT_DIR}/vigilante_permanente.sh" stop
                pausar
                ;;
            15)
                clear
                "${SCRIPT_DIR}/vigilante_permanente.sh" status
                pausar
                ;;
            0)
                clear
                log_success "¡Hasta luego!"
                exit 0
                ;;
            *)
                log_error "Opción inválida"
                pausar
                ;;
        esac
    done
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

main "$@"
