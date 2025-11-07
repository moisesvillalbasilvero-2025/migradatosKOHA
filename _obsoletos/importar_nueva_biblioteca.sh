#!/bin/bash

################################################################################
# IMPORTACIÓN AUTOMÁTICA DE NUEVA BIBLIOTECA
################################################################################
# Universidad Nacional de Asunción - Sistema Koha
#
# Este script importa automáticamente una nueva biblioteca completa
#
# Uso:
#   ./importar_nueva_biblioteca.sh CODIGO /ruta/al/archivo.csv
#
# Ejemplo:
#   ./importar_nueva_biblioteca.sh FACEN /tmp/FACEN_20251021.csv
#
# El script hace:
#   1. Copia el CSV al directorio de trabajo
#   2. Analiza el CSV
#   3. Verifica que la biblioteca exista en Koha
#   4. Genera MARCXML
#   5. Valida XML
#   6. Importa a Koha
#   7. Reconstruye índices
#   8. Verifica importación
#   9. Genera reporte
#
# Versión: 2.0
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
    echo ""
    echo "Uso: $0 CODIGO_BIBLIOTECA RUTA_CSV"
    echo ""
    echo "Ejemplo:"
    echo "  $0 FACEN /tmp/FACEN_20251021.csv"
    echo "  $0 MED datos/MED_20251021.csv"
    echo ""
    exit 1
fi

CODIGO_BIBLIOTECA=$1
ARCHIVO_CSV_ORIGEN=$2

# Configuración
INSTANCIA_KOHA="koha-cnc"
DIR_TRABAJO="/home/mvillalba/migradatos"
DIR_EXPORTS="${DIR_TRABAJO}/exports"
DIR_LOGS="${DIR_TRABAJO}/logs"
LOC_DEFAULT="SALA"
COMMIT_SIZE=1000
MAX_RECORDS_PER_FILE=5000

# Generar timestamp
FECHA=$(date +%Y%m%d)
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Nombre del archivo destino
ARCHIVO_CSV_DESTINO="${CODIGO_BIBLIOTECA}_${FECHA}.csv"

# Banner
echo ""
echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                                                                    ║"
echo "║       IMPORTACIÓN AUTOMÁTICA DE NUEVA BIBLIOTECA                   ║"
echo "║            Universidad Nacional de Asunción                        ║"
echo "║                                                                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

echo -e "${BOLD}INFORMACIÓN:${NC}"
echo "────────────────────────────────────────────────────────────────"
echo "  Código biblioteca: ${BOLD}${CODIGO_BIBLIOTECA}${NC}"
echo "  Archivo origen: ${ARCHIVO_CSV_ORIGEN}"
echo "  Archivo destino: ${ARCHIVO_CSV_DESTINO}"
echo "  Fecha: ${TIMESTAMP}"
echo ""

# PASO 1: Verificar que existe el archivo origen
echo -e "${BOLD}PASO 1: Verificar archivo CSV${NC}"
echo "────────────────────────────────────────────────────────────────"

if [ ! -f "${ARCHIVO_CSV_ORIGEN}" ]; then
    echo -e "${RED}✗ Error: No se encuentra el archivo ${ARCHIVO_CSV_ORIGEN}${NC}"
    exit 1
fi

TOTAL_LINEAS=$(wc -l < "${ARCHIVO_CSV_ORIGEN}")
TOTAL_REGISTROS=$((TOTAL_LINEAS - 1))

echo -e "${GREEN}✓${NC} Archivo encontrado"
echo "  Total de líneas: ${TOTAL_LINEAS}"
echo "  Total de registros: ${BOLD}${TOTAL_REGISTROS}${NC}"
echo ""

# PASO 2: Copiar archivo al directorio de trabajo
echo -e "${BOLD}PASO 2: Copiar CSV al directorio de trabajo${NC}"
echo "────────────────────────────────────────────────────────────────"

cp "${ARCHIVO_CSV_ORIGEN}" "${DIR_TRABAJO}/${ARCHIVO_CSV_DESTINO}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Archivo copiado: ${ARCHIVO_CSV_DESTINO}"
else
    echo -e "${RED}✗${NC} Error al copiar archivo"
    exit 1
fi
echo ""

# PASO 3: Analizar CSV (si existe el analizador)
echo -e "${BOLD}PASO 3: Analizar estructura del CSV${NC}"
echo "────────────────────────────────────────────────────────────────"

if [ -f "${DIR_TRABAJO}/analizador_csv.py" ]; then
    python3 "${DIR_TRABAJO}/analizador_csv.py" "${DIR_TRABAJO}/${ARCHIVO_CSV_DESTINO}"
    echo ""
else
    echo -e "${YELLOW}⚠${NC} Analizador no encontrado (continuando...)"
    echo ""
fi

# PASO 4: Verificar que la biblioteca existe en Koha
echo -e "${BOLD}PASO 4: Verificar que biblioteca existe en Koha${NC}"
echo "────────────────────────────────────────────────────────────────"

EXISTE=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM branches WHERE branchcode = '${CODIGO_BIBLIOTECA}'")

if [ "$EXISTE" -eq "0" ]; then
    echo -e "${RED}✗ Error: La biblioteca '${CODIGO_BIBLIOTECA}' NO existe en Koha${NC}"
    echo ""
    echo -e "${YELLOW}Debe crear la biblioteca primero:${NC}"
    echo "  1. Ir a Staff Interface"
    echo "  2. Administración → Bibliotecas"
    echo "  3. Agregar nueva biblioteca"
    echo "  4. Código: ${CODIGO_BIBLIOTECA}"
    echo "  5. Guardar"
    echo ""
    exit 1
else
    NOMBRE_BIB=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT branchname FROM branches WHERE branchcode = '${CODIGO_BIBLIOTECA}'")
    echo -e "${GREEN}✓${NC} Biblioteca encontrada en Koha: ${NOMBRE_BIB}"
fi
echo ""

# PASO 5: Verificar duplicados
echo -e "${BOLD}PASO 5: Verificar registros existentes${NC}"
echo "────────────────────────────────────────────────────────────────"

ITEMS_EXISTENTES=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM items WHERE homebranch = '${CODIGO_BIBLIOTECA}'")

echo "  Items existentes en Koha para ${CODIGO_BIBLIOTECA}: ${ITEMS_EXISTENTES}"

if [ "$ITEMS_EXISTENTES" -gt "0" ]; then
    echo -e "${YELLOW}⚠ ADVERTENCIA: Ya existen ${ITEMS_EXISTENTES} items de esta biblioteca en Koha${NC}"
    echo -e "${YELLOW}  La importación agregará NUEVOS registros${NC}"
    echo ""
    read -p "¿Desea continuar de todas formas? (escriba SI): " -r
    if [[ ! $REPLY == "SI" ]]; then
        echo -e "${YELLOW}Importación cancelada${NC}"
        exit 0
    fi
fi
echo ""

# PASO 6: Generar MARCXML
echo -e "${BOLD}PASO 6: Generar MARCXML desde CSV${NC}"
echo "────────────────────────────────────────────────────────────────"

cd "${DIR_EXPORTS}"

python3 "${DIR_TRABAJO}/opac_exportar.py" \
    -i "${DIR_TRABAJO}/${ARCHIVO_CSV_DESTINO}" \
    --codbiblio ${CODIGO_BIBLIOTECA} \
    --loc-default ${LOC_DEFAULT} \
    --stream \
    --split-by ${MAX_RECORDS_PER_FILE}

if [ $? -eq 0 ]; then
    ARCHIVOS_XML=($(ls -t ${CODIGO_BIBLIOTECA}_*_marcxml*.xml 2>/dev/null | head -10))
    NUM_ARCHIVOS=${#ARCHIVOS_XML[@]}

    if [ $NUM_ARCHIVOS -gt 0 ]; then
        echo -e "${GREEN}✓${NC} MARCXML generado: ${NUM_ARCHIVOS} archivo(s)"
        for xml in "${ARCHIVOS_XML[@]}"; do
            NUM_RECORDS=$(grep -c "<record>" "${xml}")
            echo -e "  - ${xml}: ${NUM_RECORDS} registros"
        done
    else
        echo -e "${RED}✗ No se generaron archivos MARCXML${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Error al generar MARCXML${NC}"
    exit 1
fi
echo ""

# PASO 7: Validar XML
echo -e "${BOLD}PASO 7: Validar archivos MARCXML${NC}"
echo "────────────────────────────────────────────────────────────────"

VALIDACION_OK=true
for xml in "${ARCHIVOS_XML[@]}"; do
    xmllint --noout "${xml}" 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} ${xml} válido"
    else
        echo -e "${RED}✗${NC} ${xml} tiene errores"
        VALIDACION_OK=false
    fi
done

if [ "$VALIDACION_OK" = false ]; then
    echo ""
    echo -e "${RED}✗ Errores de validación. Corrija el CSV y vuelva a intentar${NC}"
    exit 1
fi
echo ""

# PASO 8: Importar a Koha
echo -e "${BOLD}PASO 8: Importar a Koha${NC}"
echo "────────────────────────────────────────────────────────────────"

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
        echo -e "${GREEN}✓${NC} Importado exitosamente"
    else
        echo -e "${RED}✗${NC} Error en importación"
    fi
    echo ""
done

echo -e "${GREEN}${BOLD}Total importado: ${TOTAL_IMPORTADOS} registros${NC}"
echo ""

# PASO 9: Reconstruir índices
echo -e "${BOLD}PASO 9: Reconstruir índices de búsqueda${NC}"
echo "────────────────────────────────────────────────────────────────"

sudo koha-rebuild-zebra -f -v ${INSTANCIA_KOHA}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Índices reconstruidos"
else
    echo -e "${YELLOW}⚠${NC} Error al reconstruir índices"
fi
echo ""

# PASO 10: Verificar importación
echo -e "${BOLD}PASO 10: Verificar importación en Koha${NC}"
echo "────────────────────────────────────────────────────────────────"

ITEMS_FINALES=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM items WHERE homebranch = '${CODIGO_BIBLIOTECA}'")
ITEMS_NUEVOS=$((ITEMS_FINALES - ITEMS_EXISTENTES))

echo "  Items antes: ${ITEMS_EXISTENTES}"
echo "  Items después: ${ITEMS_FINALES}"
echo -e "  Items nuevos importados: ${GREEN}${BOLD}${ITEMS_NUEVOS}${NC}"
echo ""

# PASO 11: Generar reporte
mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/importacion_${CODIGO_BIBLIOTECA}_${FECHA}.log"

cat > "${LOG_FILE}" <<EOF
═══════════════════════════════════════════════════════════════════
REPORTE DE IMPORTACIÓN - ${CODIGO_BIBLIOTECA}
═══════════════════════════════════════════════════════════════════

Fecha: ${TIMESTAMP}
Biblioteca: ${CODIGO_BIBLIOTECA} - ${NOMBRE_BIB}

ARCHIVO CSV:
  Origen: ${ARCHIVO_CSV_ORIGEN}
  Destino: ${ARCHIVO_CSV_DESTINO}
  Registros en CSV: ${TOTAL_REGISTROS}

IMPORTACIÓN:
  Archivos MARCXML generados: ${NUM_ARCHIVOS}
  Archivos importados: ${ARCHIVOS_EXITOSOS}/${NUM_ARCHIVOS}
  Registros importados: ${TOTAL_IMPORTADOS}

VERIFICACIÓN:
  Items existentes antes: ${ITEMS_EXISTENTES}
  Items totales después: ${ITEMS_FINALES}
  Items nuevos: ${ITEMS_NUEVOS}

ESTADO: COMPLETADO

═══════════════════════════════════════════════════════════════════
EOF

echo -e "${GREEN}✓${NC} Reporte guardado: ${LOG_FILE}"
echo ""

# Resumen final
echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}RESUMEN FINAL:${NC}"
echo -e "  • Biblioteca: ${CODIGO_BIBLIOTECA} - ${NOMBRE_BIB}"
echo -e "  • Registros importados: ${GREEN}${BOLD}${ITEMS_NUEVOS}${NC}"
echo -e "  • Total items en biblioteca: ${ITEMS_FINALES}"
echo -e "  • Estado: ${GREEN}${BOLD}COMPLETADO EXITOSAMENTE${NC}"
echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Instrucciones de verificación
echo -e "${CYAN}${BOLD}VERIFICACIÓN EN OPAC:${NC}"
echo ""
echo "URL directa: http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=${CODIGO_BIBLIOTECA}"
echo ""
echo "O manualmente:"
echo "  1. Ir a OPAC"
echo "  2. Búsqueda avanzada"
echo "  3. Filtrar por biblioteca: ${CODIGO_BIBLIOTECA}"
echo ""

echo -e "${GREEN}${BOLD}✓✓✓ IMPORTACIÓN COMPLETADA ✓✓✓${NC}"
echo ""

exit 0
