#!/bin/bash

################################################################################
# IMPORTACIÓN SIMULTÁNEA DE MÚLTIPLES BIBLIOTECAS
################################################################################
# Universidad Nacional de Asunción - Sistema Koha
#
# Este script permite importar VARIAS bibliotecas en PARALELO
#
# Uso:
#   ./importar_multiples.sh
#
# Luego sigue las instrucciones en pantalla
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

# Banner
echo ""
echo -e "${CYAN}${BOLD}"
echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                                                                    ║"
echo "║     IMPORTACIÓN SIMULTÁNEA DE MÚLTIPLES BIBLIOTECAS                ║"
echo "║            Universidad Nacional de Asunción                        ║"
echo "║                                                                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

DIR_TRABAJO="/home/mvillalba/migradatos"

echo -e "${BOLD}BIBLIOTECAS DISPONIBLES:${NC}"
echo "────────────────────────────────────────────────────────────────"
echo ""
echo "Archivos CSV encontrados:"
ls -1 ${DIR_TRABAJO}/*.csv 2>/dev/null | while read file; do
    filename=$(basename "$file")
    lines=$(wc -l < "$file")
    echo "  • $filename ($lines registros)"
done
echo ""

echo -e "${YELLOW}${BOLD}INSTRUCCIONES:${NC}"
echo "────────────────────────────────────────────────────────────────"
echo "1. Ingresa los códigos de biblioteca y rutas CSV separados por coma"
echo "2. Formato: CODIGO1:/ruta/archivo1.csv,CODIGO2:/ruta/archivo2.csv"
echo ""
echo "Ejemplos:"
echo "  FACEN:/tmp/FACEN.csv,MED:/tmp/MED.csv,DER:/tmp/DER.csv"
echo "  ODONT:./ODONT.csv,FARM:./FARM.csv"
echo ""

read -p "Ingresa las bibliotecas a importar: " INPUT

# Convertir input en array
IFS=',' read -ra BIBLIOTECAS <<< "$INPUT"

TOTAL=${#BIBLIOTECAS[@]}

if [ $TOTAL -eq 0 ]; then
    echo -e "${RED}✗ No se ingresaron bibliotecas${NC}"
    exit 1
fi

echo ""
echo -e "${BOLD}BIBLIOTECAS A IMPORTAR:${NC}"
echo "────────────────────────────────────────────────────────────────"

# Validar todas las bibliotecas primero
VALIDAS=()
for bib in "${BIBLIOTECAS[@]}"; do
    CODIGO=$(echo "$bib" | cut -d':' -f1)
    ARCHIVO=$(echo "$bib" | cut -d':' -f2)

    echo -e "  • ${CODIGO}: ${ARCHIVO}"

    if [ ! -f "$ARCHIVO" ]; then
        echo -e "    ${RED}✗ Archivo no encontrado${NC}"
    else
        VALIDAS+=("$bib")
        echo -e "    ${GREEN}✓ Archivo encontrado${NC}"
    fi
done

echo ""
TOTAL_VALIDAS=${#VALIDAS[@]}

if [ $TOTAL_VALIDAS -eq 0 ]; then
    echo -e "${RED}✗ No hay bibliotecas válidas para importar${NC}"
    exit 1
fi

echo -e "${GREEN}Total a importar: ${TOTAL_VALIDAS} biblioteca(s)${NC}"
echo ""

read -p "¿Continuar con la importación? (SI/no): " -r
if [[ ! $REPLY =~ ^(SI|si|Si|sI|s|S|yes|YES)$ ]]; then
    echo -e "${YELLOW}Importación cancelada${NC}"
    exit 0
fi

echo ""
echo -e "${BOLD}INICIANDO IMPORTACIONES EN PARALELO${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Array para guardar PIDs de procesos
PIDS=()
LOGS=()

# Iniciar todas las importaciones en paralelo
for bib in "${VALIDAS[@]}"; do
    CODIGO=$(echo "$bib" | cut -d':' -f1)
    ARCHIVO=$(echo "$bib" | cut -d':' -f2)

    TIMESTAMP=$(date "+%Y%m%d_%H%M%S")
    LOG_FILE="${DIR_TRABAJO}/logs/importacion_${CODIGO}_${TIMESTAMP}.log"

    echo -e "${CYAN}▶ Iniciando importación de ${BOLD}${CODIGO}${NC}"

    # Ejecutar en background y guardar PID
    (
        echo "SI" | ${DIR_TRABAJO}/importar_nueva_biblioteca.sh "$CODIGO" "$ARCHIVO" > "$LOG_FILE" 2>&1
        echo $? > "${DIR_TRABAJO}/logs/.exit_${CODIGO}_${TIMESTAMP}"
    ) &

    PID=$!
    PIDS+=($PID)
    LOGS+=("$CODIGO:$LOG_FILE")

    echo -e "  ${GREEN}✓${NC} Proceso iniciado (PID: $PID)"
    echo -e "  ${BLUE}ℹ${NC} Log: $LOG_FILE"
    echo ""

    # Pequeña pausa entre inicios
    sleep 2
done

echo ""
echo -e "${BOLD}MONITOREANDO PROCESOS${NC}"
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "Importaciones en progreso: ${#PIDS[@]}"
echo ""
echo "Puedes:"
echo "  • Dejar corriendo y cerrar terminal (procesos en background)"
echo "  • Ver logs en tiempo real: tail -f logs/importacion_CODIGO_*.log"
echo "  • Esperar aquí hasta que terminen todas"
echo ""

read -p "¿Esperar hasta que terminen? (S/n): " -r
if [[ $REPLY =~ ^(S|s|SI|si|yes|YES|)$ ]]; then
    echo ""
    echo "Esperando a que terminen todas las importaciones..."
    echo ""

    # Esperar a que todos los procesos terminen
    for i in "${!PIDS[@]}"; do
        PID=${PIDS[$i]}
        INFO=${LOGS[$i]}
        CODIGO=$(echo "$INFO" | cut -d':' -f1)

        echo -e "${YELLOW}⏳${NC} Esperando a ${CODIGO} (PID: $PID)..."

        wait $PID
        EXIT_CODE=$?

        if [ $EXIT_CODE -eq 0 ]; then
            echo -e "${GREEN}✓${NC} ${CODIGO} completado exitosamente"
        else
            echo -e "${RED}✗${NC} ${CODIGO} falló (código: $EXIT_CODE)"
        fi
    done

    echo ""
    echo -e "${BOLD}RESUMEN FINAL${NC}"
    echo "════════════════════════════════════════════════════════════════"
    echo ""

    # Mostrar resumen de cada biblioteca
    for info in "${LOGS[@]}"; do
        CODIGO=$(echo "$info" | cut -d':' -f1)
        LOG=$(echo "$info" | cut -d':' -f2)

        echo -e "${BOLD}${CODIGO}:${NC}"

        if [ -f "$LOG" ]; then
            # Extraer líneas clave del log
            grep -E "(Registros importados|Items nuevos|COMPLETADO|ERROR)" "$LOG" | head -5
        else
            echo "  Log no encontrado"
        fi
        echo ""
    done

    # Mostrar estadísticas globales
    echo -e "${BOLD}ESTADÍSTICAS GLOBALES:${NC}"
    sudo koha-mysql koha-cnc -e "
    SELECT homebranch, COUNT(*) as total_items
    FROM items
    GROUP BY homebranch
    ORDER BY total_items DESC
    LIMIT 20"

    echo ""
    echo -e "${GREEN}${BOLD}✓✓✓ IMPORTACIONES COMPLETADAS ✓✓✓${NC}"
else
    echo ""
    echo -e "${YELLOW}Procesos ejecutándose en background${NC}"
    echo ""
    echo "Para monitorear el progreso:"
    echo ""
    for info in "${LOGS[@]}"; do
        CODIGO=$(echo "$info" | cut -d':' -f1)
        LOG=$(echo "$info" | cut -d':' -f2)
        echo "  tail -f $LOG"
    done
    echo ""
    echo "Para ver procesos activos:"
    echo "  ps aux | grep importar_nueva_biblioteca"
fi

echo ""

exit 0
