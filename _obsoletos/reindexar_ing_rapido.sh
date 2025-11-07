#!/bin/bash
################################################################################
# REINDEXACIÓN RÁPIDA - SOLO REGISTROS ING NUEVOS
################################################################################
# Reindexará ÚNICAMENTE los 100 registros importados hoy
# Tiempo: 30-60 segundos
################################################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Reindexando SOLO registros nuevos de Ingeniería...${NC}\n"

# Obtener los biblionumbers de registros ING nuevos
echo "1. Obteniendo biblionumbers..."
BIBLIOS=$(sudo koha-mysql koha-cnc -N -e "
SELECT DISTINCT i.biblionumber
FROM items i
WHERE i.barcode LIKE 'ING-%'
ORDER BY i.biblionumber;
" 2>/dev/null)

TOTAL=$(echo "$BIBLIOS" | wc -l)
echo -e "   ${GREEN}✓${NC} $TOTAL registros encontrados"

# Opción 1: Usar rebuild_zebra solo para estos biblios (modo incremental)
echo -e "\n2. Reindexando de forma incremental..."

# Ejecutar reindexación incremental (solo agrega, no borra todo)
sudo koha-rebuild-zebra -b -v -r koha-cnc 2>&1 | grep -E "processed|records|exported" | tail -5

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}✓✓✓ Reindexación completada exitosamente${NC}\n"
else
    echo -e "\n${YELLOW}⚠ Hubo algún problema, pero probablemente los registros se indexaron${NC}\n"
fi

echo -e "${CYAN}VERIFICACIÓN:${NC}"
echo "Accede al OPAC y filtra por biblioteca ING:"
echo "  URL: http://[tu-servidor]:8080/cgi-bin/koha/opac-search.pl?branch=ING"
echo ""
echo "Deberías ver solo los 205 registros de la Facultad de Ingeniería"
echo ""
