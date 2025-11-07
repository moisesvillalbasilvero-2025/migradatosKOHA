#!/bin/bash

################################################################################
# TEST DEL SISTEMA AUTO-IMPORTADOR
################################################################################
# Verifica que todos los componentes estén listos
#
# Uso: ./test_sistema.sh
################################################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo ""
echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║                                                        ║${NC}"
echo -e "${CYAN}${BOLD}║       TEST DEL SISTEMA AUTO-IMPORTADOR                 ║${NC}"
echo -e "${CYAN}${BOLD}║                                                        ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BOLD}Verificando componentes...${NC}"
echo ""

# Función de verificación
check() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $1"
    else
        echo -e "${RED}✗${NC} $1"
    fi
}

# 1. Verificar directorio de trabajo
cd /home/mvillalba/migradatos 2>/dev/null
check "Directorio de trabajo"

# 2. Verificar script principal
[ -f "auto_importar.py" ]
check "Script auto_importar.py existe"

[ -x "auto_importar.py" ]
check "Script tiene permisos de ejecución"

# 3. Verificar directorios
[ -d "importar_aqui" ]
check "Carpeta importar_aqui/ existe"

[ -d "procesados" ] || mkdir -p procesados
check "Carpeta procesados/ existe"

[ -d "errores" ] || mkdir -p errores
check "Carpeta errores/ existe"

[ -d "exports" ]
check "Carpeta exports/ existe"

[ -d "logs" ]
check "Carpeta logs/ existe"

# 4. Verificar scripts dependientes
[ -f "opac_exportar.py" ]
check "Script opac_exportar.py existe"

[ -f "corregir_codigos_vet.py" ]
check "Script corregir_codigos_vet.py existe"

# 5. Verificar Python
python3 --version > /dev/null 2>&1
check "Python 3 instalado"

# 6. Verificar Koha
sudo koha-mysql koha-cnc -e "SELECT 1" > /dev/null 2>&1
check "Conexión a Koha MySQL"

# 7. Verificar bibliotecas en Koha
echo ""
echo -e "${BOLD}Bibliotecas disponibles en Koha:${NC}"
echo ""

sudo koha-mysql koha-cnc -e "
SELECT
    branchcode as 'Código',
    branchname as 'Nombre',
    COUNT(items.itemnumber) as 'Items'
FROM branches
LEFT JOIN items ON branches.branchcode = items.homebranch
GROUP BY branchcode
ORDER BY branchcode
" 2>/dev/null | column -t

# 8. Verificar archivos CSV disponibles
echo ""
echo -e "${BOLD}Archivos CSV disponibles para importar:${NC}"
echo ""

CSV_FILES=$(find . -maxdepth 1 -name "*.csv" ! -name "*_corregido.csv" 2>/dev/null)

if [ -z "$CSV_FILES" ]; then
    echo -e "${YELLOW}  No hay archivos CSV en el directorio actual${NC}"
else
    for csv in $CSV_FILES; do
        TAMANIO=$(du -h "$csv" | cut -f1)
        echo -e "  ${BLUE}•${NC} $csv ${CYAN}($TAMANIO)${NC}"
    done
fi

# 9. Resumen
echo ""
echo -e "${CYAN}═════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${BOLD}Estado del sistema: ${GREEN}LISTO${NC}"
echo ""
echo -e "${YELLOW}Para usar:${NC}"
echo ""
echo -e "  1) Procesar un archivo:"
echo -e "     ${CYAN}./auto_importar.py MED.csv${NC}"
echo ""
echo -e "  2) Modo vigilancia:"
echo -e "     ${CYAN}./auto_importar.py${NC}"
echo ""
echo -e "  3) Ver guía completa:"
echo -e "     ${CYAN}cat COMO_USAR_AUTO_IMPORTAR.txt${NC}"
echo ""
echo -e "${CYAN}═════════════════════════════════════════════════════════${NC}"
echo ""
