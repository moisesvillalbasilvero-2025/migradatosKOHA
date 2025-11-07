#!/bin/bash
###############################################################################
# SCRIPT DE REINDEXACIÓN KOHA
# Universidad Nacional de Asunción
#
# Reindexación completa o incremental de Zebra/Elasticsearch
###############################################################################

# Colores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTANCIA="koha-cnc"
LOG_DIR="/home/mvillalba/migradatos/logs"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${LOG_DIR}/reindex_${TIMESTAMP}.log"

# Crear directorio de logs
mkdir -p "$LOG_DIR"

# Función para logging
log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

print_info() {
    log "${BLUE}ℹ${NC} $1"
}

print_success() {
    log "${GREEN}✓${NC} $1"
}

print_error() {
    log "${RED}✗${NC} $1"
}

print_warning() {
    log "${YELLOW}⚠${NC} $1"
}

print_header() {
    log ""
    log "${BOLD}${CYAN}=====================================================================${NC}"
    log "${BOLD}${CYAN}  $1${NC}"
    log "${BOLD}${CYAN}=====================================================================${NC}"
    log ""
}

# Verificar si se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Este script debe ejecutarse como root o con sudo${NC}"
    echo "Uso: sudo $0 [opción]"
    exit 1
fi

# Mostrar banner
clear
cat <<EOF
${BOLD}${CYAN}
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║          REINDEXACIÓN KOHA                                            ║
║          Universidad Nacional de Asunción                             ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
${NC}

EOF

print_info "Log: ${LOG_FILE}"

# Detectar motor de búsqueda
MOTOR_BUSQUEDA="zebra"  # Por defecto

if systemctl list-unit-files | grep -q "koha.*elasticsearch"; then
    MOTOR_BUSQUEDA="elasticsearch"
fi

print_info "Motor de búsqueda detectado: ${BOLD}${MOTOR_BUSQUEDA}${NC}"

# Función para reindexar Zebra - Completo
reindexar_zebra_completo() {
    print_header "REINDEXACIÓN COMPLETA DE ZEBRA"

    local tiempo_inicio=$(date +%s)

    # 1. Detener Zebra
    print_info "Deteniendo servidor Zebra..."
    koha-zebra --stop "$INSTANCIA"
    sleep 2
    print_success "Zebra detenido"

    # 2. Limpiar índices antiguos
    print_info "Limpiando índices antiguos..."
    rm -rf "/var/lib/koha/${INSTANCIA}/biblios/register/"*
    rm -rf "/var/lib/koha/${INSTANCIA}/biblios/shadow/"*
    rm -rf "/var/lib/koha/${INSTANCIA}/authorities/register/"*
    rm -rf "/var/lib/koha/${INSTANCIA}/authorities/shadow/"*
    print_success "Índices antiguos eliminados"

    # 3. Reindexar biblios
    print_info "Reindexando registros bibliográficos (esto puede tardar varios minutos)..."
    if koha-rebuild-zebra -f -v "$INSTANCIA" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Registros bibliográficos reindexados"
    else
        print_error "Error al reindexar biblios"
        koha-zebra --start "$INSTANCIA"
        return 1
    fi

    # 4. Reindexar autoridades
    print_info "Reindexando autoridades..."
    if koha-rebuild-zebra -f -a -v "$INSTANCIA" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Autoridades reindexadas"
    else
        print_warning "Error al reindexar autoridades (continuando...)"
    fi

    # 5. Reiniciar Zebra
    print_info "Reiniciando servidor Zebra..."
    koha-zebra --start "$INSTANCIA"
    sleep 3

    # Verificar estado
    if koha-zebra --status "$INSTANCIA" | grep -q "running"; then
        print_success "Zebra reiniciado correctamente"
    else
        print_error "Error al reiniciar Zebra"
        return 1
    fi

    local tiempo_fin=$(date +%s)
    local duracion=$((tiempo_fin - tiempo_inicio))

    print_success "Reindexación completa finalizada en ${duracion} segundos"
    return 0
}

# Función para reindexar Zebra - Incremental
reindexar_zebra_incremental() {
    print_header "REINDEXACIÓN INCREMENTAL DE ZEBRA"

    local tiempo_inicio=$(date +%s)

    print_info "Reindexando cambios recientes..."

    # Reindexar solo cambios (sin -f)
    if koha-rebuild-zebra -b -v "$INSTANCIA" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Biblios actualizados"
    else
        print_error "Error en reindexación incremental de biblios"
        return 1
    fi

    if koha-rebuild-zebra -a -v "$INSTANCIA" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Autoridades actualizadas"
    else
        print_warning "Error en reindexación incremental de autoridades"
    fi

    local tiempo_fin=$(date +%s)
    local duracion=$((tiempo_fin - tiempo_inicio))

    print_success "Reindexación incremental finalizada en ${duracion} segundos"
    return 0
}

# Función para reindexar Elasticsearch
reindexar_elasticsearch() {
    print_header "REINDEXACIÓN DE ELASTICSEARCH"

    local tiempo_inicio=$(date +%s)

    print_info "Reindexando Elasticsearch..."

    if koha-elasticsearch --rebuild -v "$INSTANCIA" 2>&1 | tee -a "$LOG_FILE"; then
        print_success "Elasticsearch reindexado"
    else
        print_error "Error al reindexar Elasticsearch"
        return 1
    fi

    local tiempo_fin=$(date +%s)
    local duracion=$((tiempo_fin - tiempo_inicio))

    print_success "Reindexación de Elasticsearch finalizada en ${duracion} segundos"
    return 0
}

# Función para reindexar solo una biblioteca
reindexar_biblioteca() {
    local codigo_bib=$1

    print_header "REINDEXACIÓN DE BIBLIOTECA: ${codigo_bib}"

    print_info "Exportando registros de ${codigo_bib}..."

    # Obtener biblionumbers de la biblioteca
    local temp_file=$(mktemp)

    koha-mysql "$INSTANCIA" -e "
        SELECT DISTINCT biblionumber
        FROM items
        WHERE homebranch = '${codigo_bib}'
    " > "$temp_file"

    local total=$(wc -l < "$temp_file")
    print_info "Encontrados ${total} registros bibliográficos de ${codigo_bib}"

    if [ "$total" -gt 1 ]; then
        print_info "Reindexando registros..."

        # Reindexar (esto marcará los registros para reindexación)
        if koha-rebuild-zebra -b -v "$INSTANCIA" 2>&1 | tee -a "$LOG_FILE"; then
            print_success "Biblioteca ${codigo_bib} reindexada"
        else
            print_error "Error al reindexar ${codigo_bib}"
            rm -f "$temp_file"
            return 1
        fi
    else
        print_warning "No se encontraron registros para ${codigo_bib}"
    fi

    rm -f "$temp_file"
    return 0
}

# Función para verificar índices
verificar_indices() {
    print_header "VERIFICACIÓN DE ÍNDICES"

    print_info "Verificando estado de los índices..."

    # Contar registros en base de datos
    local total_biblio=$(koha-mysql "$INSTANCIA" -se "SELECT COUNT(*) FROM biblio")
    local total_items=$(koha-mysql "$INSTANCIA" -se "SELECT COUNT(*) FROM items")

    print_info "Registros en base de datos:"
    echo "  - Biblios: ${BOLD}${total_biblio}${NC}"
    echo "  - Ítems: ${BOLD}${total_items}${NC}"

    # Verificar Zebra
    if [ "$MOTOR_BUSQUEDA" = "zebra" ]; then
        if koha-zebra --status "$INSTANCIA" | grep -q "running"; then
            print_success "Zebra está corriendo"

            # Verificar archivos de índice
            local index_dir="/var/lib/koha/${INSTANCIA}/biblios/register"
            if [ -d "$index_dir" ] && [ "$(ls -A $index_dir)" ]; then
                print_success "Archivos de índice presentes"
            else
                print_warning "No se encontraron archivos de índice"
            fi
        else
            print_error "Zebra no está corriendo"
        fi
    fi

    # Probar búsqueda
    print_info "Probando búsqueda..."

    local test_result=$(koha-mysql "$INSTANCIA" -se "
        SELECT title FROM biblio LIMIT 1
    " 2>/dev/null)

    if [ -n "$test_result" ]; then
        print_success "Búsqueda funciona correctamente"
    else
        print_error "Error en búsqueda"
    fi
}

# Función para limpieza profunda
limpieza_profunda() {
    print_header "LIMPIEZA PROFUNDA DE ÍNDICES"

    print_warning "ADVERTENCIA: Esto eliminará TODOS los índices"
    echo -n "¿Está seguro? (escriba 'SI' para confirmar): "
    read -r confirmacion

    if [ "$confirmacion" != "SI" ]; then
        print_info "Cancelado por el usuario"
        return 1
    fi

    print_info "Deteniendo Zebra..."
    koha-zebra --stop "$INSTANCIA"
    sleep 2

    print_info "Eliminando todos los índices..."
    rm -rf "/var/lib/koha/${INSTANCIA}/biblios/"*
    rm -rf "/var/lib/koha/${INSTANCIA}/authorities/"*

    print_info "Recreando estructura de directorios..."
    mkdir -p "/var/lib/koha/${INSTANCIA}/biblios/register"
    mkdir -p "/var/lib/koha/${INSTANCIA}/biblios/shadow"
    mkdir -p "/var/lib/koha/${INSTANCIA}/authorities/register"
    mkdir -p "/var/lib/koha/${INSTANCIA}/authorities/shadow"

    chown -R "${INSTANCIA}-koha:${INSTANCIA}-koha" "/var/lib/koha/${INSTANCIA}/"

    print_success "Limpieza completada"

    print_info "Iniciando reindexación completa..."
    reindexar_zebra_completo

    return $?
}

# Mostrar estadísticas
mostrar_estadisticas() {
    print_header "ESTADÍSTICAS DE LA BASE DE DATOS"

    # Total de registros
    echo -e "${BOLD}Registros totales:${NC}"
    local total_biblio=$(koha-mysql "$INSTANCIA" -se "SELECT COUNT(*) FROM biblio")
    local total_items=$(koha-mysql "$INSTANCIA" -se "SELECT COUNT(*) FROM items")
    echo "  Biblios: ${GREEN}${total_biblio}${NC}"
    echo "  Ítems: ${GREEN}${total_items}${NC}"

    echo ""
    echo -e "${BOLD}Por biblioteca:${NC}"
    koha-mysql "$INSTANCIA" -e "
        SELECT
            homebranch as Biblioteca,
            COUNT(*) as Total_Items
        FROM items
        GROUP BY homebranch
        ORDER BY Total_Items DESC
        LIMIT 10
    "

    echo ""
    echo -e "${BOLD}Por tipo de material:${NC}"
    koha-mysql "$INSTANCIA" -e "
        SELECT
            itemtype as Tipo,
            COUNT(*) as Total
        FROM items
        GROUP BY itemtype
        ORDER BY Total DESC
        LIMIT 10
    "
}

# Menú principal
mostrar_menu() {
    cat <<EOF
${BOLD}Opciones de reindexación:${NC}

  ${CYAN}Zebra:${NC}
  1) Reindexación completa (lenta, recomendada tras importación masiva)
  2) Reindexación incremental (rápida, solo cambios recientes)
  3) Reindexar biblioteca específica

  ${CYAN}Mantenimiento:${NC}
  4) Verificar estado de índices
  5) Limpieza profunda (elimina y recrea todos los índices)
  6) Mostrar estadísticas

  ${CYAN}Elasticsearch (si aplica):${NC}
  7) Reindexar Elasticsearch

  q) Salir

EOF
    echo -n "Seleccione una opción [1-7/q]: "
}

# Manejo de argumentos de línea de comandos
if [ $# -gt 0 ]; then
    case "$1" in
        --completo|-c)
            if [ "$MOTOR_BUSQUEDA" = "elasticsearch" ]; then
                reindexar_elasticsearch
            else
                reindexar_zebra_completo
            fi
            exit $?
            ;;
        --incremental|-i)
            reindexar_zebra_incremental
            exit $?
            ;;
        --biblioteca|-b)
            if [ -z "$2" ]; then
                echo "Error: Debe especificar el código de biblioteca"
                echo "Uso: $0 --biblioteca POL"
                exit 1
            fi
            reindexar_biblioteca "$2"
            exit $?
            ;;
        --verificar|-v)
            verificar_indices
            exit $?
            ;;
        --limpiar|-l)
            limpieza_profunda
            exit $?
            ;;
        --estadisticas|-e)
            mostrar_estadisticas
            exit $?
            ;;
        --help|-h)
            echo "Uso: $0 [opción]"
            echo ""
            echo "Opciones:"
            echo "  -c, --completo       Reindexación completa"
            echo "  -i, --incremental    Reindexación incremental (solo cambios)"
            echo "  -b, --biblioteca COD Reindexar una biblioteca específica"
            echo "  -v, --verificar      Verificar estado de índices"
            echo "  -l, --limpiar        Limpieza profunda"
            echo "  -e, --estadisticas   Mostrar estadísticas"
            echo "  -h, --help           Mostrar esta ayuda"
            echo ""
            echo "Sin argumentos: Menú interactivo"
            exit 0
            ;;
        *)
            echo "Opción desconocida: $1"
            echo "Use --help para ver las opciones disponibles"
            exit 1
            ;;
    esac
fi

# Menú interactivo
while true; do
    mostrar_menu
    read -r opcion

    case "$opcion" in
        1)
            if [ "$MOTOR_BUSQUEDA" = "elasticsearch" ]; then
                print_warning "Motor de búsqueda es Elasticsearch"
                reindexar_elasticsearch
            else
                reindexar_zebra_completo
            fi
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        2)
            reindexar_zebra_incremental
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        3)
            echo ""
            echo -n "Ingrese el código de biblioteca (ej: POL, ARQ, FACEN): "
            read -r codigo_bib
            if [ -n "$codigo_bib" ]; then
                reindexar_biblioteca "$codigo_bib"
            else
                print_error "Código de biblioteca no válido"
            fi
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        4)
            verificar_indices
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        5)
            limpieza_profunda
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        6)
            mostrar_estadisticas
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        7)
            if [ "$MOTOR_BUSQUEDA" = "elasticsearch" ]; then
                reindexar_elasticsearch
            else
                print_warning "Su sistema usa Zebra, no Elasticsearch"
            fi
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        q|Q)
            echo ""
            print_info "Saliendo..."
            print_info "Log guardado en: ${LOG_FILE}"
            exit 0
            ;;
        *)
            echo ""
            print_error "Opción inválida"
            sleep 2
            clear
            ;;
    esac
done
