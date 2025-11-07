#!/bin/bash

################################################################################
# SCRIPT DE IMPORTACIÓN COMPLETA - FACULTAD DE INGENIERÍA
################################################################################
# Universidad Nacional de Asunción
#
# Este script importa TODOS los registros de ING_corregido.csv
#
# Uso:
#   ./importar_ing_completo.sh
#
# Autor: Sistema Automatizado UNA
# Versión: 1.0
# Fecha: 2025-10-20
################################################################################

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuración
INSTANCIA_KOHA="koha-cnc"
CODIGO_BIBLIOTECA="ING"
ARCHIVO_ORIGINAL="ING_corregido.csv"
DIR_TRABAJO="/home/mvillalba/migradatos"
DIR_EXPORTS="${DIR_TRABAJO}/exports"
COMMIT_SIZE=1000
MAX_RECORDS_PER_FILE=5000

# Banner
echo ""
echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                                                                    ║"
echo "║     IMPORTACIÓN COMPLETA - FACULTAD DE INGENIERÍA                 ║"
echo "║            Universidad Nacional de Asunción                        ║"
echo "║                                                                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Verificar que existe el archivo corregido
if [ ! -f "${DIR_TRABAJO}/${ARCHIVO_ORIGINAL}" ]; then
    echo -e "${RED}✗ Error: No se encuentra el archivo ${ARCHIVO_ORIGINAL}${NC}"
    echo -e "${YELLOW}  Ejecute primero: python3 corregir_codigos_ing.py ING.csv${NC}"
    exit 1
fi

# Contar registros totales
TOTAL_REGISTROS=$(wc -l < "${DIR_TRABAJO}/${ARCHIVO_ORIGINAL}")
TOTAL_REGISTROS=$((TOTAL_REGISTROS - 1)) # Restar header

echo -e "${BOLD}INFORMACIÓN DEL ARCHIVO:${NC}"
echo "────────────────────────────────────────────────────────────────"
echo -e "  Archivo: ${ARCHIVO_ORIGINAL}"
echo -e "  Total de registros: ${BOLD}${TOTAL_REGISTROS}${NC}"
echo -e "  Biblioteca: ${CODIGO_BIBLIOTECA} (Facultad de Ingeniería)"
echo ""

# Confirmación
echo -e "${YELLOW}${BOLD}⚠  ADVERTENCIA: Esta es una importación COMPLETA${NC}"
echo -e "${YELLOW}   Se importarán ${TOTAL_REGISTROS} registros a Koha${NC}"
echo -e "${YELLOW}   Este proceso puede tomar varios minutos${NC}"
echo ""

read -p "¿Está SEGURO de continuar? (escriba 'SI' para confirmar): " -r
echo
if [[ ! $REPLY == "SI" ]]; then
    echo -e "${YELLOW}Importación cancelada por el usuario${NC}"
    exit 0
fi

echo ""
echo -e "${BOLD}PASO 1: Generar MARCXML desde CSV${NC}"
echo "────────────────────────────────────────────────────────────────"

# Generar MARCXML
cd "${DIR_EXPORTS}"
python3 "${DIR_TRABAJO}/opac_exportar.py" \
    -i "${DIR_TRABAJO}/${ARCHIVO_ORIGINAL}" \
    --codbiblio ${CODIGO_BIBLIOTECA} \
    --loc-default SALA \
    --stream \
    --split-by ${MAX_RECORDS_PER_FILE}

if [ $? -eq 0 ]; then
    # Buscar archivos XML generados
    ARCHIVOS_XML=($(ls -t ${CODIGO_BIBLIOTECA}_*_marcxml*.xml 2>/dev/null))
    NUM_ARCHIVOS=${#ARCHIVOS_XML[@]}

    if [ $NUM_ARCHIVOS -gt 0 ]; then
        echo -e "${GREEN}✓${NC} MARCXML generado: ${NUM_ARCHIVOS} archivo(s)"
        for xml in "${ARCHIVOS_XML[@]}"; do
            NUM_RECORDS=$(grep -c "<record>" "${xml}")
            echo -e "  - ${xml}: ${NUM_RECORDS} registros"
        done
    else
        echo -e "${RED}✗ No se encontraron archivos MARCXML generados${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Error al generar MARCXML${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}PASO 2: Importar a Koha${NC}"
echo "────────────────────────────────────────────────────────────────"
echo "Iniciando importación..."
echo ""

# Importar cada archivo XML
TOTAL_IMPORTADOS=0
ARCHIVOS_EXITOSOS=0

for xml in "${ARCHIVOS_XML[@]}"; do
    echo -e "${CYAN}Importando: ${xml}${NC}"

    sudo koha-shell ${INSTANCIA_KOHA} -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
        -b \
        -m MARCXML \
        -file ${DIR_EXPORTS}/${xml} \
        -commit ${COMMIT_SIZE}"

    if [ $? -eq 0 ]; then
        NUM_RECORDS=$(grep -c "<record>" "${xml}")
        TOTAL_IMPORTADOS=$((TOTAL_IMPORTADOS + NUM_RECORDS))
        ARCHIVOS_EXITOSOS=$((ARCHIVOS_EXITOSOS + 1))
        echo -e "${GREEN}✓${NC} ${xml} importado exitosamente"
    else
        echo -e "${RED}✗${NC} Error importando ${xml}"
    fi
    echo ""
done

echo ""
echo -e "${BOLD}PASO 3: Reconstruir índices de búsqueda${NC}"
echo "────────────────────────────────────────────────────────────────"
echo "Reconstruyendo índices Zebra (esto puede tomar varios minutos)..."
echo ""

sudo koha-rebuild-zebra -f -v ${INSTANCIA_KOHA}

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓${NC} Índices reconstruidos exitosamente"
else
    echo ""
    echo -e "${YELLOW}⚠${NC} Advertencia: Error al reconstruir índices"
    echo -e "  Ejecute manualmente: sudo koha-rebuild-zebra -f -v ${INSTANCIA_KOHA}"
fi

# Generar timestamp
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Guardar log de importación
LOG_FILE="${DIR_TRABAJO}/logs/importacion_ing_${TIMESTAMP//[: -]/_}.log"
mkdir -p "${DIR_TRABAJO}/logs"

echo "Importación completada: ${TIMESTAMP}" > "${LOG_FILE}"
echo "Total registros importados: ${TOTAL_IMPORTADOS}" >> "${LOG_FILE}"
echo "Archivos procesados: ${ARCHIVOS_EXITOSOS}/${NUM_ARCHIVOS}" >> "${LOG_FILE}"
echo "Biblioteca: ${CODIGO_BIBLIOTECA}" >> "${LOG_FILE}"

# Resumen final
echo ""
echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}RESUMEN DE IMPORTACIÓN COMPLETA:${NC}"
echo -e "  • Biblioteca: ${CODIGO_BIBLIOTECA} (Facultad de Ingeniería)"
echo -e "  • Registros importados: ${GREEN}${BOLD}${TOTAL_IMPORTADOS}${NC}"
echo -e "  • Archivos MARCXML procesados: ${ARCHIVOS_EXITOSOS}/${NUM_ARCHIVOS}"
echo -e "  • Fecha: ${TIMESTAMP}"
echo -e "  • Log guardado en: ${LOG_FILE}"
echo -e "  • Estado: ${GREEN}${BOLD}COMPLETADO${NC}"
echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Instrucciones de verificación
echo -e "${CYAN}${BOLD}VERIFICACIÓN EN EL OPAC:${NC}"
echo ""
echo "1. Acceder al OPAC: http://[servidor-koha]:8080"
echo "2. Búsqueda avanzada → Filtrar por biblioteca: ${CODIGO_BIBLIOTECA}"
echo "3. Verificar cantidad de resultados"
echo "4. Revisar algunos registros aleatorios"
echo ""

echo -e "${CYAN}${BOLD}CÓMO FILTRAR POR FACULTAD DE INGENIERÍA:${NC}"
echo ""
echo "Opción 1: Desde el OPAC (usuarios finales)"
echo "  • Ir a Búsqueda avanzada"
echo "  • En 'Biblioteca' seleccionar: ING - Facultad de Ingeniería"
echo "  • Realizar la búsqueda"
echo ""
echo "Opción 2: Desde el Staff Interface (bibliotecarios)"
echo "  • Búsqueda → Filtros → Biblioteca: ING"
echo "  • O usar la búsqueda por signatura que comience con ING-"
echo ""
echo "Opción 3: URL directa"
echo "  • http://[servidor]/cgi-bin/koha/opac-search.pl?branch=ING"
echo ""

echo -e "${GREEN}${BOLD}✓✓✓ IMPORTACIÓN DE INGENIERÍA COMPLETADA EXITOSAMENTE ✓✓✓${NC}"
echo ""

exit 0
