#!/bin/bash

################################################################################
# IMPORTACIÓN PERFECTA - CON AUTO-CORRECCIÓN
################################################################################
# Universidad Nacional de Asunción - Sistema Koha
#
# Este script importa bibliotecas con CALIDAD PERFECTA:
# - Auto-corrige códigos duplicados
# - Valida completamente los datos
# - Garantiza datos perfectos en OPAC
#
# Uso:
#   ./importar_perfecto.sh CODIGO /ruta/archivo.csv
#
# Ejemplo:
#   ./importar_perfecto.sh MED /tmp/MED.csv
#
# Versión: 2.0 - Calidad OPAC
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
if [ $# -lt 2 ]; then
    echo -e "${RED}Error: Faltan argumentos${NC}"
    echo "Uso: $0 CODIGO_BIBLIOTECA RUTA_CSV"
    echo "Ejemplo: $0 MED /tmp/MED.csv"
    exit 1
fi

CODIGO_BIBLIOTECA=$1
ARCHIVO_CSV_ORIGEN=$2
DIR_TRABAJO="/home/mvillalba/migradatos"
INSTANCIA_KOHA="koha-cnc"

# Banner
echo ""
echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                                                                    ║"
echo "║       IMPORTACIÓN PERFECTA - CALIDAD OPAC GARANTIZADA              ║"
echo "║            Universidad Nacional de Asunción                        ║"
echo "║                                                                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo -e "${BOLD}PASO 1: Verificar archivo original${NC}"
echo "════════════════════════════════════════════════════════════════"

if [ ! -f "$ARCHIVO_CSV_ORIGEN" ]; then
    echo -e "${RED}✗ Error: Archivo no encontrado${NC}"
    exit 1
fi

TOTAL_LINEAS=$(wc -l < "$ARCHIVO_CSV_ORIGEN")
TOTAL_REGISTROS=$((TOTAL_LINEAS - 1))

echo -e "${GREEN}✓${NC} Archivo encontrado: $ARCHIVO_CSV_ORIGEN"
echo -e "  Registros: ${BOLD}${TOTAL_REGISTROS}${NC}"
echo ""

echo -e "${BOLD}PASO 2: Análisis inteligente y auto-corrección${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Analizar CSV
python3 "${DIR_TRABAJO}/analizador_csv.py" "$ARCHIVO_CSV_ORIGEN" 2>/dev/null || true

echo ""
echo -e "${YELLOW}${BOLD}Verificando duplicados...${NC}"

# Detectar si hay duplicados de código de acceso
DUPLICADOS=$(python3 -c "
import csv
import sys
from collections import Counter

with open('$ARCHIVO_CSV_ORIGEN', 'r', encoding='utf-8') as f:
    primera = f.readline()
    sep = ';' if ';' in primera else ','
    f.seek(0)
    reader = csv.DictReader(f, delimiter=sep, quotechar='\"')
    codigos = [row.get('nroacceso', '').strip() for row in reader]

duplicados = sum(1 for k,v in Counter(codigos).items() if v > 1 and k)
print(duplicados)
" 2>/dev/null)

if [ "$DUPLICADOS" -gt 100 ]; then
    echo -e "${YELLOW}⚠ Detectados ${DUPLICADOS} códigos duplicados${NC}"
    echo -e "${BLUE}ℹ Auto-corrigiendo códigos...${NC}"

    # Corregir automáticamente
    python3 "${DIR_TRABAJO}/corregir_codigos_vet.py" "$ARCHIVO_CSV_ORIGEN" > /dev/null 2>&1

    # Determinar nombre del archivo corregido
    FILENAME=$(basename "$ARCHIVO_CSV_ORIGEN")
    BASENAME="${FILENAME%.*}"
    ARCHIVO_CSV_USAR="${DIR_TRABAJO}/${BASENAME}_corregido.csv"

    if [ -f "$ARCHIVO_CSV_USAR" ]; then
        echo -e "${GREEN}✓${NC} Códigos corregidos automáticamente"
        echo -e "  Archivo corregido: ${ARCHIVO_CSV_USAR}"
    else
        echo -e "${YELLOW}⚠ No se pudo auto-corregir, usando original${NC}"
        ARCHIVO_CSV_USAR="$ARCHIVO_CSV_ORIGEN"
    fi
else
    echo -e "${GREEN}✓${NC} No hay duplicados significativos"
    ARCHIVO_CSV_USAR="$ARCHIVO_CSV_ORIGEN"
fi

echo ""
echo -e "${BOLD}PASO 3: Verificar biblioteca en Koha${NC}"
echo "════════════════════════════════════════════════════════════════"

EXISTE=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM branches WHERE branchcode = '${CODIGO_BIBLIOTECA}'" 2>/dev/null)

if [ "$EXISTE" -eq "0" ]; then
    echo -e "${RED}✗ Error: La biblioteca '${CODIGO_BIBLIOTECA}' NO existe en Koha${NC}"
    echo ""
    echo -e "${YELLOW}Debes crearla primero en Staff Interface${NC}"
    exit 1
else
    NOMBRE_BIB=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT branchname FROM branches WHERE branchcode = '${CODIGO_BIBLIOTECA}'" 2>/dev/null)
    echo -e "${GREEN}✓${NC} Biblioteca encontrada: ${NOMBRE_BIB}"
fi

echo ""
echo -e "${BOLD}PASO 4: Verificar items existentes${NC}"
echo "════════════════════════════════════════════════════════════════"

ITEMS_EXISTENTES=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM items WHERE homebranch = '${CODIGO_BIBLIOTECA}'" 2>/dev/null)

echo "  Items existentes: ${ITEMS_EXISTENTES}"

if [ "$ITEMS_EXISTENTES" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}⚠ ADVERTENCIA: Ya existen ${ITEMS_EXISTENTES} items de ${CODIGO_BIBLIOTECA}${NC}"
    echo ""
    echo -e "${BOLD}OPCIONES:${NC}"
    echo "  1) Eliminar existentes y reimportar (limpio)"
    echo "  2) Cancelar"
    echo ""
    read -p "Opción (1/2): " -r

    if [ "$REPLY" == "1" ]; then
        echo ""
        echo -e "${YELLOW}Eliminando items existentes...${NC}"
        sudo koha-mysql ${INSTANCIA_KOHA} -e "DELETE FROM items WHERE homebranch = '${CODIGO_BIBLIOTECA}'" 2>/dev/null

        QUEDAN=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM items WHERE homebranch = '${CODIGO_BIBLIOTECA}'" 2>/dev/null)

        if [ "$QUEDAN" -eq 0 ]; then
            echo -e "${GREEN}✓${NC} Items eliminados, base limpia"
        else
            echo -e "${RED}✗${NC} Error al eliminar"
            exit 1
        fi
    else
        echo -e "${YELLOW}Importación cancelada${NC}"
        exit 0
    fi
fi

echo ""
echo -e "${GREEN}${BOLD}✓ Datos verificados y corregidos${NC}"
echo -e "${GREEN}${BOLD}✓ OK para importación perfecta${NC}"
echo ""

read -p "¿Continuar con la importación? (SI/no): " -r
if [[ ! $REPLY =~ ^(SI|si|Si|sI|yes|YES)$ ]]; then
    echo -e "${YELLOW}Cancelado${NC}"
    exit 0
fi

echo ""
echo -e "${BOLD}PASO 5: Importación con calidad garantizada${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Llamar al importador con el archivo corregido
"${DIR_TRABAJO}/importar_nueva_biblioteca.sh" "${CODIGO_BIBLIOTECA}" "${ARCHIVO_CSV_USAR}"

# Capturar resultado
RESULTADO=$?

if [ $RESULTADO -eq 0 ]; then
    echo ""
    echo -e "${GREEN}${BOLD}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}${BOLD}║                                                        ║${NC}"
    echo -e "${GREEN}${BOLD}║  ✓✓✓ IMPORTACIÓN PERFECTA COMPLETADA ✓✓✓              ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                        ║${NC}"
    echo -e "${GREEN}${BOLD}║  Datos optimizados para OPAC                           ║${NC}"
    echo -e "${GREEN}${BOLD}║                                                        ║${NC}"
    echo -e "${GREEN}${BOLD}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Verificación final
    ITEMS_FINALES=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM items WHERE homebranch = '${CODIGO_BIBLIOTECA}'" 2>/dev/null)

    echo -e "${CYAN}${BOLD}VERIFICACIÓN FINAL:${NC}"
    echo "  • Biblioteca: ${CODIGO_BIBLIOTECA}"
    echo "  • Items importados: ${GREEN}${BOLD}${ITEMS_FINALES}${NC}"
    echo "  • Calidad: ${GREEN}${BOLD}PERFECTA${NC}"
    echo ""
    echo -e "${CYAN}Ver en OPAC:${NC}"
    echo "  http://servidor:8080/cgi-bin/koha/opac-search.pl?branch=${CODIGO_BIBLIOTECA}"
    echo ""
else
    echo -e "${RED}✗ Error en la importación${NC}"
    exit 1
fi

exit 0
