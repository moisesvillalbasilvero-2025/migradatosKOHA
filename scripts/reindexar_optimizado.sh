#!/bin/bash

################################################################################
# REINDEXACIÓN OPTIMIZADA PARA RECURSOS LIMITADOS
################################################################################
# Universidad Nacional de Asunción - Sistema Koha
#
# Este script reindexa Koha de manera optimizada para servidores con
# recursos limitados (RAM < 4GB)
#
# OPTIMIZACIONES:
# - Libera caché del sistema antes de reindexar
# - Reindexa solo biblios (no autoridades innecesariamente)
# - Usa modo secuencial (no paralelo) para controlar uso de memoria
# - Opción de reindexación incremental
# - Monitoreo de recursos durante el proceso
#
# USO:
#   ./reindexar_optimizado.sh                    # Reindexación completa optimizada
#   ./reindexar_optimizado.sh --incremental      # Solo registros nuevos
#   ./reindexar_optimizado.sh --monitor          # Con monitoreo de recursos
#   ./reindexar_optimizado.sh --authorities      # Solo autoridades
#
# VERSIÓN: 1.0
# FECHA: 2025-10-24
################################################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTANCIA_KOHA="koha-cnc"
MODO="completo"
MONITOR=false

# ==================== FUNCIONES ====================

mostrar_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║                                                                    ║${NC}"
    echo -e "${CYAN}${BOLD}║           REINDEXACIÓN OPTIMIZADA - RECURSOS LIMITADOS            ║${NC}"
    echo -e "${CYAN}${BOLD}║           Universidad Nacional de Asunción                         ║${NC}"
    echo -e "${CYAN}${BOLD}║                                                                    ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

mostrar_ayuda() {
    cat << EOF
${BOLD}REINDEXACIÓN OPTIMIZADA PARA RECURSOS LIMITADOS${NC}

Reindexa Koha de manera eficiente en servidores con poca RAM

${BOLD}USO:${NC}
    $0 [OPCIONES]

${BOLD}OPCIONES:${NC}
    (sin opción)        Reindexación completa optimizada
    --incremental, -i   Solo registros nuevos desde última reindexación
    --monitor, -m       Activar monitoreo de recursos durante proceso
    --authorities, -a   Reindexar solo autoridades
    --help, -h          Mostrar esta ayuda

${BOLD}EJEMPLOS:${NC}
    # Reindexación completa optimizada
    $0

    # Reindexación incremental (más rápida)
    $0 --incremental

    # Con monitoreo de recursos
    $0 --monitor

    # Solo autoridades
    $0 --authorities

${BOLD}OPTIMIZACIONES APLICADAS:${NC}
    ✓ Limpieza de caché antes de reindexar
    ✓ Modo secuencial (no paralelo)
    ✓ Solo biblios por defecto (más eficiente)
    ✓ Sin salida verbose (reduce uso de memoria)
    ✓ Reindexación incremental disponible

${BOLD}RECURSOS DEL SISTEMA:${NC}
    Recomendado: RAM > 2GB libre
    Mínimo:      RAM > 500MB libre
    Espacio:     > 1GB disponible en /var

Universidad Nacional de Asunción - 2025
EOF
}

verificar_recursos() {
    echo -e "${CYAN}${BOLD}VERIFICACIÓN DE RECURSOS${NC}"
    echo "────────────────────────────────────────────────────────────────────"

    # Memoria
    MEM_TOTAL=$(free -m | awk 'NR==2 {print $2}')
    MEM_LIBRE=$(free -m | awk 'NR==2 {print $4}')
    MEM_DISPONIBLE=$(free -m | awk 'NR==2 {print $7}')

    echo -e "Memoria total:      ${BOLD}${MEM_TOTAL} MB${NC}"
    echo -e "Memoria libre:      ${BOLD}${MEM_LIBRE} MB${NC}"
    echo -e "Memoria disponible: ${BOLD}${MEM_DISPONIBLE} MB${NC}"

    # Advertencia si poca memoria
    if [ "$MEM_DISPONIBLE" -lt 500 ]; then
        echo -e "${RED}⚠ ADVERTENCIA: Poca memoria disponible (<500MB)${NC}"
        echo -e "${YELLOW}Se recomienda cerrar aplicaciones innecesarias${NC}"
        read -p "¿Continuar de todas formas? (SI/no): " respuesta
        if [[ ! $respuesta =~ ^(SI|si|S|s|YES|yes|Y|y|)$ ]]; then
            echo -e "${YELLOW}Operación cancelada${NC}"
            exit 0
        fi
    elif [ "$MEM_DISPONIBLE" -lt 1000 ]; then
        echo -e "${YELLOW}⚠ Memoria disponible limitada (<1GB)${NC}"
        echo -e "${YELLOW}El proceso puede ser lento${NC}"
    else
        echo -e "${GREEN}✓ Memoria disponible suficiente${NC}"
    fi

    # Espacio en disco
    ESPACIO_VAR=$(df -m /var | awk 'NR==2 {print $4}')
    echo -e "Espacio en /var:    ${BOLD}${ESPACIO_VAR} MB${NC}"

    if [ "$ESPACIO_VAR" -lt 1000 ]; then
        echo -e "${RED}⚠ ADVERTENCIA: Poco espacio en /var (<1GB)${NC}"
        echo -e "${YELLOW}La reindexación puede fallar${NC}"
    else
        echo -e "${GREEN}✓ Espacio en disco suficiente${NC}"
    fi

    echo ""
}

liberar_memoria() {
    echo -e "${CYAN}Liberando memoria caché...${NC}"

    # Sincronizar buffers
    sync

    # Liberar caché de página, dentries e inodes
    echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1

    sleep 2

    MEM_LIBRE_DESPUES=$(free -m | awk 'NR==2 {print $4}')
    echo -e "${GREEN}✓ Memoria liberada. Memoria libre ahora: ${MEM_LIBRE_DESPUES} MB${NC}"
    echo ""
}

monitorear_recursos() {
    # Monitorear recursos en segundo plano
    while true; do
        MEM=$(free -m | awk 'NR==2 {printf "%.1f%%", ($3/$2)*100}')
        CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
        echo -e "${CYAN}[$(date '+%H:%M:%S')] CPU: ${CPU}% | RAM: ${MEM}${NC}"
        sleep 5
    done
}

reindexar_completo() {
    echo -e "${BOLD}REINDEXACIÓN COMPLETA${NC}"
    echo "────────────────────────────────────────────────────────────────────"
    echo ""

    # Liberar memoria primero
    liberar_memoria

    # Iniciar monitoreo si está activo
    if [ "$MONITOR" = true ]; then
        echo -e "${CYAN}Iniciando monitoreo de recursos...${NC}"
        monitorear_recursos &
        MONITOR_PID=$!
    fi

    echo -e "${CYAN}Iniciando reindexación...${NC}"
    TIEMPO_INICIO=$(date +%s)

    # Reindexar solo biblios (más eficiente)
    # -b = solo biblios
    # -z = modo secuencial (no daemon)
    # Sin -v para reducir salida y uso de memoria
    sudo koha-rebuild-zebra -b -z ${INSTANCIA_KOHA}
    RESULTADO=$?

    # Detener monitoreo
    if [ "$MONITOR" = true ] && [ -n "$MONITOR_PID" ]; then
        kill $MONITOR_PID 2>/dev/null
    fi

    TIEMPO_FIN=$(date +%s)
    DURACION=$((TIEMPO_FIN - TIEMPO_INICIO))

    echo ""
    if [ $RESULTADO -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✓✓✓ REINDEXACIÓN COMPLETADA EXITOSAMENTE ✓✓✓${NC}"
        echo -e "${GREEN}Tiempo total: ${DURACION} segundos${NC}"
    else
        echo -e "${RED}✗ Error en la reindexación${NC}"
        return 1
    fi

    echo ""
}

reindexar_incremental() {
    echo -e "${BOLD}REINDEXACIÓN INCREMENTAL${NC}"
    echo "────────────────────────────────────────────────────────────────────"
    echo ""
    echo -e "${YELLOW}Reindexando solo registros modificados desde última vez...${NC}"
    echo ""

    # Liberar memoria
    liberar_memoria

    TIEMPO_INICIO=$(date +%s)

    # Reindexación incremental (solo cambios recientes)
    # -r = reset (necesario para incremental)
    # -b = solo biblios
    sudo koha-rebuild-zebra -r -b ${INSTANCIA_KOHA}
    RESULTADO=$?

    TIEMPO_FIN=$(date +%s)
    DURACION=$((TIEMPO_FIN - TIEMPO_INICIO))

    echo ""
    if [ $RESULTADO -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✓ Reindexación incremental completada${NC}"
        echo -e "${GREEN}Tiempo: ${DURACION} segundos${NC}"
    else
        echo -e "${RED}✗ Error en la reindexación incremental${NC}"
        return 1
    fi

    echo ""
}

reindexar_autoridades() {
    echo -e "${BOLD}REINDEXACIÓN DE AUTORIDADES${NC}"
    echo "────────────────────────────────────────────────────────────────────"
    echo ""

    liberar_memoria

    TIEMPO_INICIO=$(date +%s)

    # Solo autoridades
    sudo koha-rebuild-zebra -a -z ${INSTANCIA_KOHA}
    RESULTADO=$?

    TIEMPO_FIN=$(date +%s)
    DURACION=$((TIEMPO_FIN - TIEMPO_INICIO))

    echo ""
    if [ $RESULTADO -eq 0 ]; then
        echo -e "${GREEN}✓ Autoridades reindexadas${NC}"
        echo -e "${GREEN}Tiempo: ${DURACION} segundos${NC}"
    else
        echo -e "${RED}✗ Error reindexando autoridades${NC}"
        return 1
    fi

    echo ""
}

verificar_estado_zebra() {
    echo -e "${CYAN}ESTADO DE ZEBRA${NC}"
    echo "────────────────────────────────────────────────────────────────────"

    # Verificar proceso Zebra
    if pgrep -f "zebrasrv.*${INSTANCIA_KOHA}" > /dev/null; then
        echo -e "${GREEN}✓ Zebra está corriendo${NC}"
    else
        echo -e "${RED}✗ Zebra NO está corriendo${NC}"
        echo -e "${YELLOW}Iniciando Zebra...${NC}"
        sudo koha-start-zebra ${INSTANCIA_KOHA}
    fi

    # Verificar número de registros indexados
    BIBLIOS=$(sudo koha-shell ${INSTANCIA_KOHA} -c \
        "zebraidx-biblios -c /etc/koha/sites/${INSTANCIA_KOHA}/zebra-biblios.cfg select database | grep ^term" \
        2>/dev/null | wc -l)

    echo -e "Términos indexados: ${BOLD}${BIBLIOS}${NC}"
    echo ""
}

# ==================== PROCESAR ARGUMENTOS ====================

while [[ $# -gt 0 ]]; do
    case $1 in
        --incremental|-i)
            MODO="incremental"
            shift
            ;;
        --monitor|-m)
            MONITOR=true
            shift
            ;;
        --authorities|-a)
            MODO="authorities"
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

# ==================== INICIO ====================

mostrar_banner

# Verificar permisos sudo
if ! sudo -n true 2>/dev/null; then
    echo -e "${RED}Este script requiere permisos sudo${NC}"
    exit 1
fi

# Verificar recursos
verificar_recursos

# Verificar estado de Zebra
verificar_estado_zebra

# Ejecutar según modo
case $MODO in
    completo)
        reindexar_completo
        ;;
    incremental)
        reindexar_incremental
        ;;
    authorities)
        reindexar_autoridades
        ;;
esac

# Verificar estado final
echo -e "${CYAN}VERIFICACIÓN FINAL${NC}"
echo "────────────────────────────────────────────────────────────────────"
verificar_estado_zebra

# Mostrar uso de recursos final
MEM_FINAL=$(free -m | awk 'NR==2 {print $7}')
echo -e "Memoria disponible: ${BOLD}${MEM_FINAL} MB${NC}"
echo ""

echo -e "${GREEN}${BOLD}✓ Proceso completado${NC}"
echo ""

exit 0
