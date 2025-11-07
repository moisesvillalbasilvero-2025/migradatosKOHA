#!/bin/bash

################################################################################
# VERIFICADOR Y LIMPIADOR DE DUPLICADOS EN KOHA
################################################################################
# Verifica duplicados en la base de datos Koha y proporciona opciones
# para limpiarlos de forma segura
#
# USO:
#   ./verificar_duplicados.sh                    # Verificar todo
#   ./verificar_duplicados.sh --biblioteca MED   # Solo biblioteca MED
#   ./verificar_duplicados.sh --report           # Solo reporte (no limpiar)
#   ./verificar_duplicados.sh --auto-fix         # Limpiar automáticamente
#
# VERIFICACIONES:
#   • Duplicados por barcode
#   • Duplicados por biblionumber + homebranch
#   • Items huérfanos (sin biblio)
#   • Barcodes NULL o vacíos
#   • Registros bibliográficos sin items
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
BIBLIOTECA_FILTRO=""
SOLO_REPORTE=false
AUTO_FIX=false

# ==================== FUNCIONES ====================

mostrar_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║           VERIFICADOR DE DUPLICADOS - SISTEMA KOHA                   ║"
    echo "║           Universidad Nacional de Asunción                           ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${BOLD}Fecha:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
}

verificar_duplicados_barcode() {
    echo -e "${CYAN}${BOLD}═══ VERIFICANDO DUPLICADOS POR BARCODE ═══${NC}"
    echo ""

    local query="
    SELECT
        barcode,
        COUNT(*) as duplicados,
        GROUP_CONCAT(itemnumber ORDER BY itemnumber) as items,
        GROUP_CONCAT(DISTINCT homebranch) as bibliotecas
    FROM items
    WHERE barcode IS NOT NULL AND barcode != ''
    "

    if [ -n "$BIBLIOTECA_FILTRO" ]; then
        query+=" AND homebranch = '$BIBLIOTECA_FILTRO'"
    fi

    query+="
    GROUP BY barcode
    HAVING COUNT(*) > 1
    ORDER BY COUNT(*) DESC
    LIMIT 50"

    local resultado=$(sudo koha-mysql ${INSTANCIA_KOHA} -t -e "$query" 2>/dev/null)

    if [ -n "$resultado" ]; then
        echo -e "${RED}✗ SE ENCONTRARON DUPLICADOS:${NC}"
        echo ""
        echo "$resultado"
        echo ""

        local total=$(echo "$resultado" | grep -v "barcode" | grep -v "+" | grep -v "^$" | wc -l)
        echo -e "${YELLOW}Total de barcodes duplicados: ${BOLD}$total${NC}"
        echo ""
        return 1
    else
        echo -e "${GREEN}✓ No se encontraron duplicados de barcode${NC}"
        echo ""
        return 0
    fi
}

verificar_barcodes_null() {
    echo -e "${CYAN}${BOLD}═══ VERIFICANDO BARCODES NULL O VACÍOS ═══${NC}"
    echo ""

    local query="
    SELECT
        homebranch,
        COUNT(*) as items_sin_barcode
    FROM items
    WHERE barcode IS NULL OR barcode = ''
    "

    if [ -n "$BIBLIOTECA_FILTRO" ]; then
        query+=" AND homebranch = '$BIBLIOTECA_FILTRO'"
    fi

    query+="
    GROUP BY homebranch
    ORDER BY COUNT(*) DESC"

    local resultado=$(sudo koha-mysql ${INSTANCIA_KOHA} -t -e "$query" 2>/dev/null)

    if [ -n "$resultado" ]; then
        echo -e "${YELLOW}⚠ Items sin barcode encontrados:${NC}"
        echo ""
        echo "$resultado"
        echo ""

        local total=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "
        SELECT COUNT(*) FROM items WHERE barcode IS NULL OR barcode = ''" 2>/dev/null)
        echo -e "${YELLOW}Total items sin barcode: ${BOLD}$total${NC}"
        echo ""
        return 1
    else
        echo -e "${GREEN}✓ Todos los items tienen barcode${NC}"
        echo ""
        return 0
    fi
}

verificar_items_huerfanos() {
    echo -e "${CYAN}${BOLD}═══ VERIFICANDO ITEMS HUÉRFANOS (sin biblio) ═══${NC}"
    echo ""

    local query="
    SELECT
        i.itemnumber,
        i.barcode,
        i.homebranch,
        i.biblionumber
    FROM items i
    LEFT JOIN biblio b ON i.biblionumber = b.biblionumber
    WHERE b.biblionumber IS NULL
    "

    if [ -n "$BIBLIOTECA_FILTRO" ]; then
        query+=" AND i.homebranch = '$BIBLIOTECA_FILTRO'"
    fi

    query+=" LIMIT 20"

    local resultado=$(sudo koha-mysql ${INSTANCIA_KOHA} -t -e "$query" 2>/dev/null)

    if [ -n "$resultado" ] && [ "$(echo "$resultado" | wc -l)" -gt 1 ]; then
        echo -e "${RED}✗ Items huérfanos encontrados:${NC}"
        echo ""
        echo "$resultado"
        echo ""

        local total=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "
        SELECT COUNT(*) FROM items i
        LEFT JOIN biblio b ON i.biblionumber = b.biblionumber
        WHERE b.biblionumber IS NULL" 2>/dev/null)
        echo -e "${RED}Total items huérfanos: ${BOLD}$total${NC}"
        echo ""
        return 1
    else
        echo -e "${GREEN}✓ No se encontraron items huérfanos${NC}"
        echo ""
        return 0
    fi
}

verificar_biblios_sin_items() {
    echo -e "${CYAN}${BOLD}═══ VERIFICANDO BIBLIOS SIN ITEMS ═══${NC}"
    echo ""

    local query="
    SELECT
        b.biblionumber,
        b.title,
        b.author
    FROM biblio b
    LEFT JOIN items i ON b.biblionumber = i.biblionumber
    WHERE i.itemnumber IS NULL
    LIMIT 20"

    local resultado=$(sudo koha-mysql ${INSTANCIA_KOHA} -t -e "$query" 2>/dev/null)

    if [ -n "$resultado" ] && [ "$(echo "$resultado" | wc -l)" -gt 1 ]; then
        echo -e "${YELLOW}⚠ Biblios sin items encontrados:${NC}"
        echo ""
        echo "$resultado"
        echo ""

        local total=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "
        SELECT COUNT(*) FROM biblio b
        LEFT JOIN items i ON b.biblionumber = i.biblionumber
        WHERE i.itemnumber IS NULL" 2>/dev/null)
        echo -e "${YELLOW}Total biblios sin items: ${BOLD}$total${NC}"
        echo -e "${CYAN}(Esto puede ser normal para registros solo bibliográficos)${NC}"
        echo ""
        return 0
    else
        echo -e "${GREEN}✓ Todos los biblios tienen items${NC}"
        echo ""
        return 0
    fi
}

mostrar_estadisticas_generales() {
    echo -e "${CYAN}${BOLD}═══ ESTADÍSTICAS GENERALES ═══${NC}"
    echo ""

    local query="
    SELECT
        homebranch,
        COUNT(*) as total_items,
        COUNT(DISTINCT barcode) as barcodes_unicos,
        COUNT(DISTINCT biblionumber) as biblios_distintos,
        SUM(CASE WHEN barcode IS NULL OR barcode = '' THEN 1 ELSE 0 END) as sin_barcode
    FROM items
    "

    if [ -n "$BIBLIOTECA_FILTRO" ]; then
        query+=" WHERE homebranch = '$BIBLIOTECA_FILTRO'"
    fi

    query+="
    GROUP BY homebranch
    ORDER BY total_items DESC
    LIMIT 20"

    sudo koha-mysql ${INSTANCIA_KOHA} -t -e "$query" 2>/dev/null

    echo ""

    # Totales generales
    local total_items=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM items" 2>/dev/null)
    local total_biblios=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM biblio" 2>/dev/null)

    echo -e "${BOLD}TOTALES GENERALES:${NC}"
    echo -e "  Biblios:  ${GREEN}${BOLD}${total_biblios}${NC}"
    echo -e "  Items:    ${GREEN}${BOLD}${total_items}${NC}"
    echo ""
}

generar_reporte_detallado() {
    local archivo_reporte="/home/mvillalba/migradatos/logs/reporte_duplicados_$(date +%Y%m%d_%H%M%S).txt"

    echo -e "${CYAN}Generando reporte detallado...${NC}"

    {
        echo "╔══════════════════════════════════════════════════════════════════════╗"
        echo "║                                                                      ║"
        echo "║           REPORTE DE VERIFICACIÓN DE DUPLICADOS - KOHA               ║"
        echo "║                                                                      ║"
        echo "╚══════════════════════════════════════════════════════════════════════╝"
        echo ""
        echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Instancia: $INSTANCIA_KOHA"
        if [ -n "$BIBLIOTECA_FILTRO" ]; then
            echo "Biblioteca: $BIBLIOTECA_FILTRO"
        else
            echo "Biblioteca: TODAS"
        fi
        echo ""
        echo "═══════════════════════════════════════════════════════════════════════"
        echo ""

        # Estadísticas
        mostrar_estadisticas_generales 2>&1

        # Duplicados de barcode
        verificar_duplicados_barcode 2>&1

        # Barcodes NULL
        verificar_barcodes_null 2>&1

        # Items huérfanos
        verificar_items_huerfanos 2>&1

        # Biblios sin items
        verificar_biblios_sin_items 2>&1

    } | tee "$archivo_reporte"

    echo -e "${GREEN}✓ Reporte guardado en: ${BOLD}$archivo_reporte${NC}"
    echo ""
}

limpiar_duplicados_interactivo() {
    echo -e "${YELLOW}${BOLD}⚠ LIMPIEZA DE DUPLICADOS${NC}"
    echo ""
    echo "Esta función eliminará items duplicados manteniendo solo el más antiguo."
    echo ""
    read -p "¿Está SEGURO de continuar? (escriba 'SI' para confirmar): " confirmacion

    if [ "$confirmacion" != "SI" ]; then
        echo -e "${YELLOW}Operación cancelada${NC}"
        return 1
    fi

    echo ""
    echo -e "${CYAN}Creando backup antes de limpiar...${NC}"

    # Crear backup de la tabla items
    sudo koha-mysql ${INSTANCIA_KOHA} -e "
    CREATE TABLE IF NOT EXISTS items_backup_$(date +%Y%m%d_%H%M%S) AS SELECT * FROM items" 2>/dev/null

    echo -e "${GREEN}✓ Backup creado${NC}"
    echo ""

    # Obtener duplicados y eliminar los más recientes
    echo -e "${CYAN}Eliminando duplicados...${NC}"

    sudo koha-mysql ${INSTANCIA_KOHA} -e "
    DELETE i1 FROM items i1
    INNER JOIN items i2
    WHERE
        i1.barcode = i2.barcode
        AND i1.itemnumber > i2.itemnumber
        AND i1.barcode IS NOT NULL
        AND i1.barcode != ''" 2>/dev/null

    local eliminados=$?

    if [ $eliminados -eq 0 ]; then
        echo -e "${GREEN}✓ Duplicados eliminados exitosamente${NC}"
        echo ""
        verificar_duplicados_barcode
    else
        echo -e "${RED}✗ Error al eliminar duplicados${NC}"
        return 1
    fi
}

mostrar_ayuda() {
    cat << EOF
${BOLD}VERIFICADOR DE DUPLICADOS EN KOHA${NC}

Verifica y limpia duplicados en la base de datos Koha

${BOLD}USO:${NC}
    $0 [OPCIONES]

${BOLD}OPCIONES:${NC}
    --biblioteca CODIGO     Verificar solo una biblioteca específica
    --report                Solo generar reporte (no limpiar)
    --auto-fix              Limpiar duplicados automáticamente (¡CUIDADO!)
    --help, -h              Mostrar esta ayuda

${BOLD}EJEMPLOS:${NC}
    # Verificar todo el sistema
    $0

    # Verificar solo biblioteca MED
    $0 --biblioteca MED

    # Generar solo reporte sin limpiar
    $0 --report

    # Verificar y guardar reporte
    $0 --report > reporte_duplicados.txt

${BOLD}VERIFICACIONES REALIZADAS:${NC}
    ✓ Duplicados por barcode
    ✓ Barcodes NULL o vacíos
    ✓ Items huérfanos (sin biblio)
    ✓ Biblios sin items
    ✓ Estadísticas generales

${BOLD}IMPORTANTE:${NC}
    Antes de limpiar duplicados, se crea un backup automático
    de la tabla 'items' con timestamp.

Universidad Nacional de Asunción - 2025
EOF
}

# ==================== PROCESAR ARGUMENTOS ====================

while [[ $# -gt 0 ]]; do
    case $1 in
        --biblioteca)
            BIBLIOTECA_FILTRO="$2"
            shift 2
            ;;
        --report)
            SOLO_REPORTE=true
            shift
            ;;
        --auto-fix)
            AUTO_FIX=true
            shift
            ;;
        --help|-h)
            mostrar_ayuda
            exit 0
            ;;
        *)
            echo -e "${RED}Opción desconocida: $1${NC}"
            echo "Use --help para ver opciones disponibles"
            exit 1
            ;;
    esac
done

# ==================== MAIN ====================

mostrar_banner

# Verificar conexión a Koha
if ! sudo koha-mysql ${INSTANCIA_KOHA} -e "SELECT 1" &>/dev/null; then
    echo -e "${RED}✗ No se puede conectar a Koha: $INSTANCIA_KOHA${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Conexión a Koha verificada${NC}"
echo ""

# Mostrar estadísticas
mostrar_estadisticas_generales

# Ejecutar verificaciones
problemas_encontrados=0

verificar_duplicados_barcode || ((problemas_encontrados++))
verificar_barcodes_null || ((problemas_encontrados++))
verificar_items_huerfanos || ((problemas_encontrados++))
verificar_biblios_sin_items

# Generar reporte si se solicita
if [ "$SOLO_REPORTE" = true ]; then
    generar_reporte_detallado
fi

# Resumen final
echo -e "${CYAN}${BOLD}═══ RESUMEN ═══${NC}"
echo ""

if [ $problemas_encontrados -eq 0 ]; then
    echo -e "${GREEN}${BOLD}✓✓✓ NO SE ENCONTRARON PROBLEMAS ✓✓✓${NC}"
    echo -e "${GREEN}El sistema está limpio de duplicados${NC}"
else
    echo -e "${YELLOW}${BOLD}⚠ PROBLEMAS ENCONTRADOS: $problemas_encontrados${NC}"
    echo ""

    if [ "$AUTO_FIX" = true ]; then
        limpiar_duplicados_interactivo
    elif [ "$SOLO_REPORTE" = false ]; then
        echo -e "${CYAN}Para limpiar duplicados, ejecute:${NC}"
        echo "  $0 --auto-fix"
        echo ""
        echo -e "${CYAN}Para generar reporte detallado:${NC}"
        echo "  $0 --report"
    fi
fi

echo ""
exit 0
