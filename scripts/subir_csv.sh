#!/bin/bash

################################################################################
# SCRIPT PARA SUBIR CSV A LA CARPETA DE IMPORTACIÓN
################################################################################
# Uso:
#   ./subir_csv.sh archivo.csv
#   ./subir_csv.sh /ruta/completa/archivo.csv CODIGO
#
# Ejemplos:
#   ./subir_csv.sh medicina.csv MED
#   ./subir_csv.sh /tmp/datos.csv VET
################################################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DIR_IMPORTAR="/home/mvillalba/migradatos/importar_aqui"

mostrar_ayuda() {
    echo ""
    echo -e "${CYAN}${BOLD}SUBIR CSV A CARPETA DE IMPORTACIÓN${NC}"
    echo ""
    echo -e "${BOLD}USO:${NC}"
    echo "  $0 archivo.csv [CODIGO]"
    echo ""
    echo -e "${BOLD}EJEMPLOS:${NC}"
    echo "  $0 medicina.csv MED        # Copia y renombra a MED.csv"
    echo "  $0 MED.csv                 # Copia directamente"
    echo "  $0 /tmp/datos.csv QUI      # Copia desde otra ubicación"
    echo ""
    echo -e "${BOLD}CARPETA DESTINO:${NC}"
    echo "  $DIR_IMPORTAR"
    echo ""
}

# Verificar argumentos
if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    mostrar_ayuda
    exit 0
fi

ARCHIVO_ORIGEN="$1"
CODIGO=""

# Si se proporciona código, usarlo
if [ $# -eq 2 ]; then
    CODIGO="$2"
fi

# Verificar que el archivo existe
if [ ! -f "$ARCHIVO_ORIGEN" ]; then
    echo -e "${RED}✗ Error: Archivo no encontrado: $ARCHIVO_ORIGEN${NC}"
    exit 1
fi

# Determinar nombre de destino
if [ -n "$CODIGO" ]; then
    # Si se proporcionó código, renombrar
    NOMBRE_DESTINO="${CODIGO}.csv"
else
    # Usar nombre original
    NOMBRE_DESTINO=$(basename "$ARCHIVO_ORIGEN")
fi

RUTA_DESTINO="${DIR_IMPORTAR}/${NOMBRE_DESTINO}"

# Copiar archivo
echo ""
echo -e "${CYAN}Copiando archivo...${NC}"
echo "  Origen:  $ARCHIVO_ORIGEN"
echo "  Destino: $RUTA_DESTINO"
echo ""

cp "$ARCHIVO_ORIGEN" "$RUTA_DESTINO"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Archivo copiado exitosamente${NC}"

    # Mostrar información
    TAMANIO=$(du -h "$RUTA_DESTINO" | cut -f1)
    LINEAS=$(wc -l < "$RUTA_DESTINO")

    echo ""
    echo -e "${BOLD}INFORMACIÓN:${NC}"
    echo "  Archivo: $NOMBRE_DESTINO"
    echo "  Tamaño:  $TAMANIO"
    echo "  Líneas:  $LINEAS"

    # Intentar detectar código
    if [ -z "$CODIGO" ]; then
        CODIGO_DETECTADO=$(echo "$NOMBRE_DESTINO" | grep -o -E '[A-Z]{3,6}' | head -1)
        if [ -n "$CODIGO_DETECTADO" ]; then
            echo "  Código:  $CODIGO_DETECTADO"
        else
            echo -e "  ${YELLOW}⚠ No se detectó código de biblioteca${NC}"
            echo -e "    ${YELLOW}Renombra el archivo para incluir el código (ej: MED.csv)${NC}"
        fi
    else
        echo "  Código:  $CODIGO"
    fi

    echo ""
    echo -e "${CYAN}¿Procesar ahora?${NC}"
    echo "  Opción 1: ./importar_automatico.sh"
    echo "  Opción 2: ./agente_importador_v2.py importar_aqui/$NOMBRE_DESTINO"
    echo ""
else
    echo -e "${RED}✗ Error al copiar archivo${NC}"
    exit 1
fi

exit 0
