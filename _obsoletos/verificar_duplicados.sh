#!/bin/bash

################################################################################
# VERIFICADOR DE DUPLICADOS - CONTROL UNIVOCO
################################################################################
# Universidad Nacional de Asunción - Sistema Koha
#
# Este script verifica si una biblioteca ya fue importada
# y previene duplicaciones automáticamente
#
# Uso:
#   ./verificar_duplicados.sh CODIGO
#
# Ejemplo:
#   ./verificar_duplicados.sh VET
#
# Retorna:
#   0 = No hay duplicados, OK para importar
#   1 = Ya existe, NO importar
#
# Versión: 1.0
# Fecha: 2025-10-21
################################################################################

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Verificar argumentos
if [ $# -lt 1 ]; then
    echo -e "${RED}Error: Falta el código de biblioteca${NC}"
    echo "Uso: $0 CODIGO"
    echo "Ejemplo: $0 VET"
    exit 2
fi

CODIGO=$1
INSTANCIA="koha-cnc"
DB_REGISTRO="/home/mvillalba/migradatos/.importaciones_registradas.db"

# Banner
echo ""
echo -e "${CYAN}${BOLD}VERIFICADOR DE DUPLICADOS${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo -e "Biblioteca: ${BOLD}${CODIGO}${NC}"
echo ""

# MÉTODO 1: Verificar en Koha (base de datos)
echo -e "${BOLD}1. Verificando en base de datos Koha...${NC}"

ITEMS_COUNT=$(sudo koha-mysql ${INSTANCIA} -N -e "SELECT COUNT(*) FROM items WHERE homebranch = '${CODIGO}'" 2>/dev/null)

if [ -z "$ITEMS_COUNT" ]; then
    echo -e "${YELLOW}⚠ No se pudo conectar a Koha${NC}"
    ITEMS_COUNT=0
fi

echo -e "   Items encontrados: ${BOLD}${ITEMS_COUNT}${NC}"

if [ "$ITEMS_COUNT" -gt 0 ]; then
    echo -e "   ${RED}✗ La biblioteca YA tiene items en Koha${NC}"

    # Mostrar detalles
    echo ""
    echo -e "${BOLD}Detalles de items existentes:${NC}"
    sudo koha-mysql ${INSTANCIA} -e "
    SELECT
        homebranch,
        COUNT(*) as total_items,
        MIN(dateaccessioned) as primera_importacion,
        MAX(dateaccessioned) as ultima_importacion
    FROM items
    WHERE homebranch = '${CODIGO}'
    GROUP BY homebranch" 2>/dev/null

    echo ""
    echo -e "${YELLOW}${BOLD}OPCIONES:${NC}"
    echo "  A) Eliminar items existentes y reimportar"
    echo "  B) Cancelar importación"
    echo "  C) Importar de todas formas (duplicará registros)"
    echo ""

    read -p "¿Qué deseas hacer? (A/B/C): " -r

    case $REPLY in
        A|a)
            echo ""
            echo -e "${YELLOW}⚠ ADVERTENCIA: Esto eliminará TODOS los items de ${CODIGO}${NC}"
            read -p "¿Estás SEGURO? (escribe 'ELIMINAR' para confirmar): " -r

            if [ "$REPLY" == "ELIMINAR" ]; then
                echo ""
                echo "Eliminando items de ${CODIGO}..."
                sudo koha-mysql ${INSTANCIA} -e "DELETE FROM items WHERE homebranch = '${CODIGO}'"

                REMAINING=$(sudo koha-mysql ${INSTANCIA} -N -e "SELECT COUNT(*) FROM items WHERE homebranch = '${CODIGO}'")

                if [ "$REMAINING" -eq 0 ]; then
                    echo -e "${GREEN}✓ Items eliminados. OK para importar${NC}"
                    exit 0
                else
                    echo -e "${RED}✗ Error al eliminar items${NC}"
                    exit 1
                fi
            else
                echo -e "${YELLOW}Operación cancelada${NC}"
                exit 1
            fi
            ;;
        B|b)
            echo -e "${YELLOW}Importación cancelada${NC}"
            exit 1
            ;;
        C|c)
            echo -e "${YELLOW}Continuando (se duplicarán registros)${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opción inválida. Cancelando.${NC}"
            exit 1
            ;;
    esac
else
    echo -e "   ${GREEN}✓ No hay items existentes${NC}"
fi

# MÉTODO 2: Verificar en registro de importaciones
echo ""
echo -e "${BOLD}2. Verificando registro de importaciones...${NC}"

# Crear DB si no existe
if [ ! -f "$DB_REGISTRO" ]; then
    echo "# Base de datos de importaciones registradas" > "$DB_REGISTRO"
    echo "# Formato: CODIGO|FECHA|ITEMS|HASH_CSV" >> "$DB_REGISTRO"
fi

REGISTRO_PREVIO=$(grep "^${CODIGO}|" "$DB_REGISTRO" 2>/dev/null)

if [ -n "$REGISTRO_PREVIO" ]; then
    FECHA_PREV=$(echo "$REGISTRO_PREVIO" | cut -d'|' -f2)
    ITEMS_PREV=$(echo "$REGISTRO_PREVIO" | cut -d'|' -f3)

    echo -e "   ${YELLOW}⚠ Importación previa detectada${NC}"
    echo -e "   Fecha: ${FECHA_PREV}"
    echo -e "   Items: ${ITEMS_PREV}"
    echo ""
    echo -e "${YELLOW}Esta biblioteca ya fue importada anteriormente${NC}"
else
    echo -e "   ${GREEN}✓ Sin registros previos${NC}"
fi

# MÉTODO 3: Verificar hash de CSV (si se proporciona)
if [ $# -ge 2 ]; then
    CSV_FILE=$2

    echo ""
    echo -e "${BOLD}3. Verificando huella digital del CSV...${NC}"

    if [ -f "$CSV_FILE" ]; then
        CSV_HASH=$(md5sum "$CSV_FILE" | cut -d' ' -f1)
        echo -e "   Hash del archivo: ${CSV_HASH}"

        HASH_PREVIO=$(echo "$REGISTRO_PREVIO" | cut -d'|' -f4)

        if [ "$CSV_HASH" == "$HASH_PREVIO" ]; then
            echo -e "   ${RED}✗ MISMO ARCHIVO ya fue importado${NC}"
            echo ""
            echo -e "${RED}${BOLD}DUPLICADO DETECTADO${NC}"
            echo -e "Este archivo CSV exacto ya fue procesado anteriormente"
            exit 1
        else
            echo -e "   ${GREEN}✓ Archivo diferente, OK para importar${NC}"
        fi
    fi
fi

echo ""
echo "════════════════════════════════════════════════════════════════"
echo -e "${GREEN}${BOLD}✓ VERIFICACIÓN COMPLETADA - OK PARA IMPORTAR${NC}"
echo ""

exit 0
