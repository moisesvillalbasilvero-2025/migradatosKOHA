#!/bin/bash

################################################################################
# MONITOR DE IMPORTACIÓN EN TIEMPO REAL
################################################################################
# Monitorea el progreso de importaciones, estado de Koha y uso de recursos
#
# USO:
#   ./monitor_importacion.sh              # Vista única
#   ./monitor_importacion.sh --watch      # Actualización continua (5s)
#   ./monitor_importacion.sh --compact    # Vista compacta
#
# VERSIÓN: 1.0
# FECHA: 2025-10-24
################################################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

INSTANCIA_KOHA="koha-cnc"
DIR_TRABAJO="/home/mvillalba/migradatos"
DIR_EXPORTS="${DIR_TRABAJO}/exports"
DIR_LOGS="${DIR_TRABAJO}/logs"

MODO_WATCH=false
MODO_COMPACT=false
INTERVALO=5

# ==================== FUNCIONES ====================

mostrar_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║              MONITOR DE IMPORTACIÓN - SISTEMA KOHA                   ║"
    echo "║              Universidad Nacional de Asunción                        ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${BOLD}Actualizado:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

mostrar_sesiones_tmux() {
    echo -e "${CYAN}${BOLD}═══ SESIONES TMUX ACTIVAS ═══${NC}"
    echo ""

    if tmux ls 2>/dev/null | grep -q "importacion"; then
        echo -e "${GREEN}✓ Sesiones de importación activas:${NC}"
        tmux ls 2>/dev/null | grep "importacion" | while read linea; do
            echo -e "  ${BOLD}→${NC} $linea"
        done
    else
        echo -e "${YELLOW}⚠ No hay sesiones de importación activas${NC}"
    fi

    # Mostrar todas las sesiones si hay
    local total_sesiones=$(tmux ls 2>/dev/null | wc -l)
    if [ $total_sesiones -gt 0 ]; then
        echo ""
        echo -e "${BOLD}Total de sesiones tmux:${NC} $total_sesiones"
    fi
    echo ""
}

mostrar_procesos_activos() {
    echo -e "${CYAN}${BOLD}═══ PROCESOS DE IMPORTACIÓN ACTIVOS ═══${NC}"
    echo ""

    local proc_python=$(ps aux | grep -E 'opac_exportar|agente_importador' | grep -v grep | wc -l)
    local proc_import=$(ps aux | grep 'bulkmarcimport' | grep -v grep | wc -l)
    local proc_zebra=$(ps aux | grep 'rebuild_zebra' | grep -v grep | wc -l)

    if [ $proc_python -gt 0 ]; then
        echo -e "${GREEN}✓ Conversión CSV→XML:${NC} $proc_python proceso(s)"
    fi

    if [ $proc_import -gt 0 ]; then
        echo -e "${GREEN}✓ Importación a Koha:${NC} $proc_import proceso(s)"
    fi

    if [ $proc_zebra -gt 0 ]; then
        echo -e "${GREEN}✓ Reindexación Zebra:${NC} $proc_zebra proceso(s)"
    fi

    if [ $proc_python -eq 0 ] && [ $proc_import -eq 0 ] && [ $proc_zebra -eq 0 ]; then
        echo -e "${YELLOW}⚠ No hay procesos de importación activos${NC}"
    fi
    echo ""
}

mostrar_estadisticas_koha() {
    echo -e "${CYAN}${BOLD}═══ ESTADÍSTICAS DE BIBLIOTECAS EN KOHA ═══${NC}"
    echo ""

    if [ "$MODO_COMPACT" = true ]; then
        # Versión compacta
        sudo koha-mysql ${INSTANCIA_KOHA} -N -e "
        SELECT
            CONCAT('  ', b.branchcode, ': ', LPAD(COUNT(i.itemnumber), 6, ' '), ' items')
        FROM branches b
        LEFT JOIN items i ON b.branchcode = i.homebranch
        GROUP BY b.branchcode
        HAVING COUNT(i.itemnumber) > 0
        ORDER BY COUNT(i.itemnumber) DESC
        LIMIT 15;" 2>/dev/null
    else
        # Versión completa con tabla
        sudo koha-mysql ${INSTANCIA_KOHA} -t -e "
        SELECT
            b.branchcode AS 'Código',
            LEFT(b.branchname, 35) AS 'Nombre',
            COUNT(i.itemnumber) AS 'Items',
            DATE(MAX(i.dateaccessioned)) AS 'Última Importación'
        FROM branches b
        LEFT JOIN items i ON b.branchcode = i.homebranch
        GROUP BY b.branchcode, b.branchname
        HAVING COUNT(i.itemnumber) > 0
        ORDER BY COUNT(i.itemnumber) DESC
        LIMIT 15;" 2>/dev/null
    fi

    echo ""

    # Totales
    local total_items=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM items" 2>/dev/null)
    local total_biblios=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM biblio" 2>/dev/null)

    echo -e "${BOLD}Total general:${NC}"
    echo -e "  Registros bibliográficos: ${GREEN}${BOLD}${total_biblios}${NC}"
    echo -e "  Items:                    ${GREEN}${BOLD}${total_items}${NC}"
    echo ""
}

mostrar_uso_recursos() {
    echo -e "${CYAN}${BOLD}═══ USO DE RECURSOS ═══${NC}"
    echo ""

    # Disco
    local uso_disco=$(df -h /home/mvillalba/migradatos | tail -1 | awk '{print $5}')
    local espacio_libre=$(df -h /home/mvillalba/migradatos | tail -1 | awk '{print $4}')

    echo -e "${BOLD}Disco (/home/mvillalba):${NC}"
    echo -e "  Uso:          $uso_disco"
    echo -e "  Disponible:   $espacio_libre"

    # Tamaño de exports/
    if [ -d "$DIR_EXPORTS" ]; then
        local tam_exports=$(du -sh "$DIR_EXPORTS" 2>/dev/null | cut -f1)
        local num_xml=$(find "$DIR_EXPORTS" -name "*.xml" 2>/dev/null | wc -l)
        echo -e "  Exports/:     $tam_exports ($num_xml archivos XML)"
    fi

    # Memoria
    local mem_total=$(free -h | grep Mem | awk '{print $2}')
    local mem_usada=$(free -h | grep Mem | awk '{print $3}')
    local mem_libre=$(free -h | grep Mem | awk '{print $4}')

    echo ""
    echo -e "${BOLD}Memoria:${NC}"
    echo -e "  Total:        $mem_total"
    echo -e "  Usada:        $mem_usada"
    echo -e "  Libre:        $mem_libre"

    echo ""
}

mostrar_ultimos_logs() {
    echo -e "${CYAN}${BOLD}═══ ÚLTIMOS LOGS ═══${NC}"
    echo ""

    # Buscar log más reciente
    local ultimo_log=$(ls -t ${DIR_LOGS}/importacion_*.log 2>/dev/null | head -1)

    if [ -n "$ultimo_log" ]; then
        echo -e "${BOLD}Archivo:${NC} $(basename $ultimo_log)"
        echo ""
        tail -8 "$ultimo_log" | sed 's/^/  /'
    else
        echo -e "${YELLOW}⚠ No hay logs de importación recientes${NC}"
    fi

    echo ""
}

mostrar_archivos_pendientes() {
    echo -e "${CYAN}${BOLD}═══ ARCHIVOS PENDIENTES ═══${NC}"
    echo ""

    local dir_importar="${DIR_TRABAJO}/importar_aqui"

    if [ -d "$dir_importar" ]; then
        local num_csv=$(find "$dir_importar" -name "*.csv" -type f 2>/dev/null | wc -l)

        if [ $num_csv -gt 0 ]; then
            echo -e "${YELLOW}⚠ Archivos CSV pendientes: ${BOLD}$num_csv${NC}"
            echo ""
            find "$dir_importar" -name "*.csv" -type f -printf "  • %f (%s bytes)\n" 2>/dev/null | head -5
            if [ $num_csv -gt 5 ]; then
                echo "  ... y $((num_csv - 5)) más"
            fi
        else
            echo -e "${GREEN}✓ No hay archivos CSV pendientes${NC}"
        fi
    fi

    echo ""
}

mostrar_ayuda_comandos() {
    echo -e "${CYAN}${BOLD}═══ COMANDOS ÚTILES ═══${NC}"
    echo ""
    echo -e "${BOLD}Tmux:${NC}"
    echo "  ./importar_con_tmux.sh --attach    # Conectar a sesión"
    echo "  ./importar_con_tmux.sh --status    # Ver estado de sesiones"
    echo "  tmux attach -t importacion-koha    # Conectar directamente"
    echo ""
    echo -e "${BOLD}Logs:${NC}"
    echo "  tail -f logs/importacion_*.log     # Ver log en tiempo real"
    echo "  ls -lht logs/ | head -10           # Listar logs recientes"
    echo ""
}

# ==================== MAIN ====================

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --watch|-w)
            MODO_WATCH=true
            shift
            ;;
        --compact|-c)
            MODO_COMPACT=true
            shift
            ;;
        --intervalo|-i)
            INTERVALO="$2"
            shift 2
            ;;
        --help|-h)
            echo "MONITOR DE IMPORTACIÓN"
            echo ""
            echo "USO:"
            echo "  $0 [OPCIONES]"
            echo ""
            echo "OPCIONES:"
            echo "  --watch, -w           Actualización continua"
            echo "  --compact, -c         Vista compacta"
            echo "  --intervalo N, -i N   Intervalo de actualización (segundos)"
            echo "  --help, -h            Mostrar esta ayuda"
            echo ""
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1"
            echo "Use --help para ver opciones"
            exit 1
            ;;
    esac
done

# Función para mostrar todo
mostrar_todo() {
    mostrar_banner
    mostrar_sesiones_tmux
    mostrar_procesos_activos
    mostrar_estadisticas_koha
    mostrar_uso_recursos
    mostrar_archivos_pendientes
    mostrar_ultimos_logs

    if [ "$MODO_WATCH" = true ]; then
        echo -e "${YELLOW}Actualizando cada ${INTERVALO}s... (Ctrl+C para salir)${NC}"
    else
        mostrar_ayuda_comandos
    fi
}

# Ejecutar
if [ "$MODO_WATCH" = true ]; then
    while true; do
        mostrar_todo
        sleep $INTERVALO
    done
else
    mostrar_todo
fi

exit 0
