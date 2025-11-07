#!/bin/bash

################################################################################
# SCRIPT DE IMPORTACIÓN DE PRUEBA - FACULTAD DE INGENIERÍA
################################################################################
# Universidad Nacional de Asunción
#
# Este script importa un subset de 100 registros de ING.csv como prueba
# antes de realizar la importación completa.
#
# Uso:
#   ./importar_ing_prueba.sh
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
ARCHIVO_PRUEBA="ING_prueba_100.csv"
DIR_TRABAJO="/home/mvillalba/migradatos"
DIR_EXPORTS="${DIR_TRABAJO}/exports"
NUM_REGISTROS_PRUEBA=100

# Banner
echo ""
echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                                                                    ║"
echo "║     IMPORTACIÓN DE PRUEBA - FACULTAD DE INGENIERÍA                ║"
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

echo -e "${BOLD}PASO 1: Crear subset de prueba (${NUM_REGISTROS_PRUEBA} registros)${NC}"
echo "────────────────────────────────────────────────────────────────"

# Crear archivo de prueba con los primeros N registros
cd "${DIR_TRABAJO}"
head -n $((NUM_REGISTROS_PRUEBA + 1)) "${ARCHIVO_ORIGINAL}" > "${ARCHIVO_PRUEBA}"

if [ $? -eq 0 ]; then
    REGISTROS_CREADOS=$(wc -l < "${ARCHIVO_PRUEBA}")
    REGISTROS_DATOS=$((REGISTROS_CREADOS - 1))
    echo -e "${GREEN}✓${NC} Archivo de prueba creado: ${ARCHIVO_PRUEBA}"
    echo -e "  ${REGISTROS_DATOS} registros para importar"
else
    echo -e "${RED}✗ Error al crear archivo de prueba${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}PASO 2: Generar MARCXML desde CSV${NC}"
echo "────────────────────────────────────────────────────────────────"

# Generar MARCXML
cd "${DIR_EXPORTS}"
python3 "${DIR_TRABAJO}/opac_exportar.py" \
    -i "${DIR_TRABAJO}/${ARCHIVO_PRUEBA}" \
    --codbiblio ${CODIGO_BIBLIOTECA} \
    --loc-default SALA \
    --stream

if [ $? -eq 0 ]; then
    # Buscar el archivo XML más reciente
    ARCHIVO_XML=$(ls -t ${CODIGO_BIBLIOTECA}_*_marcxml*.xml 2>/dev/null | head -1)

    if [ -n "$ARCHIVO_XML" ]; then
        echo -e "${GREEN}✓${NC} MARCXML generado: ${ARCHIVO_XML}"

        # Contar registros en el XML
        NUM_RECORDS=$(grep -c "<record>" "${ARCHIVO_XML}")
        echo -e "  ${NUM_RECORDS} registros en el archivo MARCXML"
    else
        echo -e "${RED}✗ No se encontró el archivo MARCXML generado${NC}"
        exit 1
    fi
else
    echo -e "${RED}✗ Error al generar MARCXML${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}PASO 3: Importar a Koha (Prueba)${NC}"
echo "────────────────────────────────────────────────────────────────"
echo -e "${YELLOW}IMPORTANTE: Esta es una importación de PRUEBA${NC}"
echo -e "${YELLOW}Si todo funciona bien, ejecute la importación completa${NC}"
echo ""

read -p "¿Continuar con la importación de prueba? (s/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[SsYy]$ ]]; then
    echo -e "${YELLOW}Importación cancelada por el usuario${NC}"
    exit 0
fi

# Importar a Koha
echo ""
echo "Importando a Koha..."
sudo koha-shell ${INSTANCIA_KOHA} -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
    -b \
    -m MARCXML \
    -file ${DIR_EXPORTS}/${ARCHIVO_XML} \
    -commit 100"

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓${NC} Importación completada"
else
    echo ""
    echo -e "${RED}✗ Error en la importación${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}PASO 4: Reconstruir índices de búsqueda${NC}"
echo "────────────────────────────────────────────────────────────────"

sudo koha-rebuild-zebra -f -v ${INSTANCIA_KOHA}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Índices reconstruidos"
else
    echo -e "${YELLOW}⚠${NC} Advertencia: Error al reconstruir índices"
fi

# Resumen final
echo ""
echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}RESUMEN DE IMPORTACIÓN DE PRUEBA:${NC}"
echo -e "  • Biblioteca: ${CODIGO_BIBLIOTECA} (Facultad de Ingeniería)"
echo -e "  • Registros importados: ${NUM_REGISTROS_PRUEBA}"
echo -e "  • Archivo MARCXML: ${ARCHIVO_XML}"
echo -e "  • Estado: ${GREEN}${BOLD}COMPLETADO${NC}"
echo -e "${BLUE}${BOLD}═══════════════════════════════════════════════════════════════════${NC}"
echo ""

# Instrucciones de verificación
echo -e "${CYAN}${BOLD}VERIFICACIÓN EN EL OPAC:${NC}"
echo ""
echo "1. Acceder al OPAC de Koha"
echo "2. Buscar por biblioteca: ${CODIGO_BIBLIOTECA}"
echo "3. Filtrar por Facultad de Ingeniería"
echo "4. Verificar que los registros se vean correctamente"
echo ""

# Próximos pasos
echo -e "${YELLOW}${BOLD}PRÓXIMOS PASOS:${NC}"
echo ""
echo "Si la prueba fue exitosa:"
echo "  1. Revisar algunos registros en el OPAC"
echo "  2. Verificar que los datos estén correctos"
echo "  3. Ejecutar importación completa con:"
echo ""
echo -e "     ${BOLD}./importar_ing_completo.sh${NC}"
echo ""
echo "Si hay problemas:"
echo "  1. Revisar los logs en /home/mvillalba/migradatos/logs"
echo "  2. Ajustar el mapeo de campos si es necesario"
echo "  3. Eliminar registros de prueba antes de reimportar"
echo ""

exit 0
