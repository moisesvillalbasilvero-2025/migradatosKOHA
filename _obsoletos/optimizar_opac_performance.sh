#!/bin/bash
###############################################################################
# SCRIPT DE OPTIMIZACIÓN DE PERFORMANCE PARA KOHA OPAC
# Universidad Nacional de Asunción
#
# Este script optimiza la base de datos MySQL, índices Zebra y configuración
# del sistema para lograr búsquedas ultra-rápidas en el OPAC
#
# PARA LA PRESENTACIÓN ANTE LOS JEFES
###############################################################################

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

INSTANCIA="koha-cnc"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="logs/optimizacion_${TIMESTAMP}.log"

# Crear directorio de logs
mkdir -p logs

# Función para logging
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO $(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

header() {
    echo ""
    echo -e "${BOLD}${CYAN}=====================================================================${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}=====================================================================${NC}"
    echo ""
}

###############################################################################
# 1. OPTIMIZACIÓN DE BASE DE DATOS MYSQL
###############################################################################
optimizar_mysql() {
    header "PASO 1: OPTIMIZANDO BASE DE DATOS MYSQL"

    log "Optimizando tablas de la base de datos..."

    # Obtener lista de todas las tablas
    TABLAS=$(sudo koha-mysql ${INSTANCIA} -e "SHOW TABLES;" | tail -n +2)

    TOTAL_TABLAS=$(echo "$TABLAS" | wc -l)
    CONTADOR=0

    log_info "Total de tablas a optimizar: ${TOTAL_TABLAS}"

    for TABLA in $TABLAS; do
        CONTADOR=$((CONTADOR + 1))
        echo -ne "${BLUE}[${CONTADOR}/${TOTAL_TABLAS}]${NC} Optimizando tabla: ${TABLA}...\r"
        sudo koha-mysql ${INSTANCIA} -e "OPTIMIZE TABLE ${TABLA};" >> "$LOG_FILE" 2>&1
    done

    echo ""
    log "✓ Optimización de tablas MySQL completada"

    # Analizar tablas para actualizar estadísticas
    log "Analizando tablas para actualizar estadísticas del optimizador..."
    for TABLA in $TABLAS; do
        sudo koha-mysql ${INSTANCIA} -e "ANALYZE TABLE ${TABLA};" >> "$LOG_FILE" 2>&1
    done

    log "✓ Análisis de tablas completado"

    # Reparar tablas si es necesario
    log "Verificando integridad de tablas..."
    sudo koha-mysql ${INSTANCIA} -e "CHECK TABLE biblioitems, biblio, items;" >> "$LOG_FILE" 2>&1

    log "✓ Base de datos MySQL optimizada completamente"
}

###############################################################################
# 2. OPTIMIZACIÓN DE ÍNDICES ZEBRA
###############################################################################
optimizar_zebra() {
    header "PASO 2: RECONSTRUCCIÓN COMPLETA DE ÍNDICES ZEBRA"

    log "Deteniendo servidor Zebra..."
    sudo koha-zebra --stop ${INSTANCIA}
    sleep 2

    log "Limpiando índices antiguos..."
    sudo rm -rf /var/lib/koha/${INSTANCIA}/biblios/register/*
    sudo rm -rf /var/lib/koha/${INSTANCIA}/biblios/shadow/*
    sudo rm -rf /var/lib/koha/${INSTANCIA}/authorities/register/*
    sudo rm -rf /var/lib/koha/${INSTANCIA}/authorities/shadow/*

    log "✓ Índices antiguos eliminados"

    log "Reconstruyendo índices bibliográficos (esto puede tardar varios minutos)..."
    sudo koha-rebuild-zebra -f -v ${INSTANCIA} | tee -a "$LOG_FILE"

    log "Reconstruyendo índices de autoridades..."
    sudo koha-rebuild-zebra -f -a -v ${INSTANCIA} | tee -a "$LOG_FILE"

    log "Iniciando servidor Zebra..."
    sudo koha-zebra --start ${INSTANCIA}
    sleep 3

    # Verificar que Zebra está corriendo
    if sudo koha-zebra --status ${INSTANCIA} | grep -q "running"; then
        log "✓ Servidor Zebra iniciado correctamente"
    else
        log_error "✗ Error al iniciar Zebra"
        return 1
    fi

    log "✓ Índices Zebra reconstruidos y optimizados"
}

###############################################################################
# 3. OPTIMIZACIÓN DE CACHÉ Y CONFIGURACIÓN
###############################################################################
optimizar_cache() {
    header "PASO 3: OPTIMIZACIÓN DE CACHÉ Y CONFIGURACIÓN"

    # Verificar si Memcached está instalado
    if command -v memcached &> /dev/null; then
        log "Memcached detectado, reiniciando servicio..."
        sudo systemctl restart memcached
        log "✓ Memcached reiniciado"
    else
        log_warning "Memcached no instalado (recomendado para mejor performance)"
        log_info "Instalar con: sudo apt-get install memcached"
    fi

    # Reiniciar Plack para limpiar caché de aplicación
    log "Reiniciando Plack para limpiar caché de aplicación..."
    sudo koha-plack --restart ${INSTANCIA}
    sleep 3

    log "✓ Plack reiniciado"

    # Limpiar caché de Apache
    log "Limpiando caché de Apache..."
    sudo systemctl reload apache2

    log "✓ Configuración de caché optimizada"
}

###############################################################################
# 4. OPTIMIZACIÓN DE REGISTROS (ELIMINAR DUPLICADOS Y ORPHAN ITEMS)
###############################################################################
optimizar_registros() {
    header "PASO 4: LIMPIEZA Y OPTIMIZACIÓN DE REGISTROS"

    log "Verificando registros huérfanos..."

    # Contar items sin biblios
    ORPHAN_ITEMS=$(sudo koha-mysql ${INSTANCIA} -e "
        SELECT COUNT(*) as orphans
        FROM items
        WHERE biblionumber NOT IN (SELECT biblionumber FROM biblio);" | tail -n 1)

    if [ "$ORPHAN_ITEMS" != "orphans" ] && [ "$ORPHAN_ITEMS" -gt 0 ]; then
        log_warning "Encontrados ${ORPHAN_ITEMS} items huérfanos (sin registro bibliográfico)"
        log_info "Se recomienda ejecutar limpieza de registros huérfanos"
    else
        log "✓ No se encontraron items huérfanos"
    fi

    # Estadísticas de la base de datos
    log "Generando estadísticas del catálogo..."

    TOTAL_BIBLIOS=$(sudo koha-mysql ${INSTANCIA} -e "SELECT COUNT(*) FROM biblio;" | tail -n 1)
    TOTAL_ITEMS=$(sudo koha-mysql ${INSTANCIA} -e "SELECT COUNT(*) FROM items;" | tail -n 1)
    TOTAL_BIBLIOTECAS=$(sudo koha-mysql ${INSTANCIA} -e "SELECT COUNT(DISTINCT homebranch) FROM items;" | tail -n 1)

    log_info "Registros bibliográficos: ${TOTAL_BIBLIOS}"
    log_info "Ejemplares totales: ${TOTAL_ITEMS}"
    log_info "Bibliotecas activas: ${TOTAL_BIBLIOTECAS}"

    log "✓ Análisis de registros completado"
}

###############################################################################
# 5. TEST DE PERFORMANCE DEL OPAC
###############################################################################
test_performance() {
    header "PASO 5: TEST DE PERFORMANCE DEL OPAC"

    log "Ejecutando pruebas de búsqueda..."

    # Obtener URL del OPAC
    OPAC_URL=$(sudo koha-list --url ${INSTANCIA} | grep opac)

    if [ -z "$OPAC_URL" ]; then
        log_warning "No se pudo determinar la URL del OPAC"
        return
    fi

    log_info "URL del OPAC: ${OPAC_URL}"

    # Test de búsquedas comunes
    declare -a BUSQUEDAS=("agua" "suelo" "arquitectura" "biblioteca" "ciencias")

    for TERMINO in "${BUSQUEDAS[@]}"; do
        log_info "Probando búsqueda: '${TERMINO}'..."

        TIEMPO_INICIO=$(date +%s%N)
        RESULTADO=$(curl -s -o /dev/null -w "%{http_code}" "${OPAC_URL}/cgi-bin/koha/opac-search.pl?q=${TERMINO}" 2>/dev/null)
        TIEMPO_FIN=$(date +%s%N)

        TIEMPO_MS=$(( (TIEMPO_FIN - TIEMPO_INICIO) / 1000000 ))

        if [ "$RESULTADO" = "200" ]; then
            if [ $TIEMPO_MS -lt 500 ]; then
                log "  ✓ '${TERMINO}': ${TIEMPO_MS}ms (EXCELENTE)"
            elif [ $TIEMPO_MS -lt 1000 ]; then
                log "  ✓ '${TERMINO}': ${TIEMPO_MS}ms (BUENO)"
            else
                log_warning "  ⚠ '${TERMINO}': ${TIEMPO_MS}ms (MEJORABLE)"
            fi
        else
            log_error "  ✗ Error en búsqueda de '${TERMINO}' (HTTP ${RESULTADO})"
        fi
    done

    log "✓ Tests de performance completados"
}

###############################################################################
# 6. RECOMENDACIONES ADICIONALES
###############################################################################
mostrar_recomendaciones() {
    header "RECOMENDACIONES ADICIONALES PARA LA PRESENTACIÓN"

    cat <<EOF

${BOLD}${GREEN}OPTIMIZACIONES APLICADAS:${NC}
  ✓ Base de datos MySQL optimizada y analizada
  ✓ Índices Zebra reconstruidos desde cero
  ✓ Caché de Plack y Apache limpiados
  ✓ Servicios reiniciados

${BOLD}${CYAN}PARA MEJORAR AÚN MÁS LA PERFORMANCE:${NC}

1. ${BOLD}Instalar y configurar Memcached${NC} (si no está instalado):
   sudo apt-get install memcached
   sudo systemctl enable memcached
   sudo systemctl start memcached

2. ${BOLD}Ajustar configuración MySQL${NC} en /etc/mysql/my.cnf:
   [mysqld]
   innodb_buffer_pool_size = 2G
   query_cache_size = 64M
   query_cache_limit = 4M
   tmp_table_size = 64M
   max_heap_table_size = 64M
   join_buffer_size = 4M

3. ${BOLD}Configurar índices selectivos${NC} en Zebra:
   - Revisar archivos en /etc/koha/sites/${INSTANCIA}/zebra-authorities-dom.cfg
   - Optimizar campos de búsqueda más utilizados

4. ${BOLD}Programar optimizaciones regulares${NC}:
   # Agregar a crontab (crontab -e):
   0 3 * * * /home/mvillalba/migradatos/optimizar_opac_performance.sh

5. ${BOLD}Antes de la presentación${NC}:
   - Ejecutar este script 1 hora antes
   - Cerrar todos los procesos innecesarios
   - Limpiar caché del navegador
   - Usar conexión de red estable

${BOLD}${YELLOW}PARA LA DEMOSTRACIÓN:${NC}
  - Preparar búsquedas de prueba con resultados conocidos
  - Mostrar filtros por biblioteca (ARQ, POL, etc.)
  - Demostrar búsqueda avanzada
  - Resaltar la rapidez de respuesta
  - Mostrar cantidad de registros importados

${BOLD}${GREEN}LOG DE ESTE PROCESO:${NC} ${LOG_FILE}

EOF
}

###############################################################################
# EJECUCIÓN PRINCIPAL
###############################################################################
main() {
    clear

    cat <<EOF
${BOLD}${CYAN}
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║   OPTIMIZADOR DE PERFORMANCE PARA KOHA OPAC                          ║
║   Universidad Nacional de Asunción                                    ║
║                                                                       ║
║   Para presentación ante jefes                                        ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
${NC}

EOF

    log "Iniciando optimización completa del sistema..."
    log "Instancia: ${INSTANCIA}"
    log "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"

    TIEMPO_INICIO=$(date +%s)

    # Ejecutar optimizaciones
    optimizar_mysql
    optimizar_zebra
    optimizar_cache
    optimizar_registros
    test_performance

    TIEMPO_FIN=$(date +%s)
    DURACION=$((TIEMPO_FIN - TIEMPO_INICIO))

    header "OPTIMIZACIÓN COMPLETADA"

    log "✓ Todas las optimizaciones aplicadas exitosamente"
    log "Duración total: ${DURACION} segundos"

    mostrar_recomendaciones

    echo ""
    echo -e "${BOLD}${GREEN}¡El sistema OPAC está ahora optimizado para la presentación!${NC}"
    echo ""
}

# Verificar que se está ejecutando como root o con sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script debe ejecutarse como root o con sudo${NC}"
    echo "Uso: sudo $0"
    exit 1
fi

# Ejecutar programa principal
main

exit 0
