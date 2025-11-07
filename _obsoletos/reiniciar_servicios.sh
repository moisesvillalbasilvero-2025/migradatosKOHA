#!/bin/bash
###############################################################################
# SCRIPT DE REINICIO RÁPIDO DE SERVICIOS KOHA
# Universidad Nacional de Asunción
#
# Reinicia todos los servicios necesarios para Koha de forma ordenada
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

# Función para imprimir con color
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}=====================================================================${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}=====================================================================${NC}"
    echo ""
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
║          REINICIO DE SERVICIOS KOHA                                   ║
║          Universidad Nacional de Asunción                             ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
${NC}

EOF

# Función para reiniciar un servicio
reiniciar_servicio() {
    local servicio=$1
    local nombre=$2

    print_info "Reiniciando ${nombre}..."

    if systemctl restart "$servicio" 2>/dev/null; then
        sleep 2
        if systemctl is-active --quiet "$servicio"; then
            print_success "${nombre} reiniciado correctamente"
            return 0
        else
            print_error "${nombre} no está corriendo después del reinicio"
            return 1
        fi
    else
        print_warning "${nombre} no está instalado o no se pudo reiniciar"
        return 1
    fi
}

# Función para reiniciar Zebra
reiniciar_zebra() {
    print_info "Reiniciando Zebra para ${INSTANCIA}..."

    koha-zebra --stop "$INSTANCIA" 2>/dev/null
    sleep 2
    koha-zebra --start "$INSTANCIA" 2>/dev/null
    sleep 2

    if koha-zebra --status "$INSTANCIA" 2>/dev/null | grep -q "running"; then
        print_success "Zebra reiniciado correctamente"
        return 0
    else
        print_error "Zebra no está corriendo después del reinicio"
        return 1
    fi
}

# Función para reiniciar Plack
reiniciar_plack() {
    print_info "Reiniciando Plack para ${INSTANCIA}..."

    if koha-plack --restart "$INSTANCIA" 2>/dev/null; then
        sleep 2
        print_success "Plack reiniciado correctamente"
        return 0
    else
        print_warning "No se pudo reiniciar Plack"
        return 1
    fi
}

# Función para reinicio completo
reinicio_completo() {
    print_header "REINICIO COMPLETO DE TODOS LOS SERVICIOS"

    local errores=0

    # 1. MySQL
    reiniciar_servicio "mysql" "MySQL" || ((errores++))

    # 2. Apache
    reiniciar_servicio "apache2" "Apache2" || ((errores++))

    # 3. Memcached (opcional)
    if systemctl list-unit-files | grep -q memcached; then
        reiniciar_servicio "memcached" "Memcached" || ((errores++))
    else
        print_warning "Memcached no está instalado (opcional)"
    fi

    # 4. Zebra
    reiniciar_zebra || ((errores++))

    # 5. Plack
    reiniciar_plack || ((errores++))

    echo ""
    if [ $errores -eq 0 ]; then
        print_success "Todos los servicios reiniciados correctamente"
    else
        print_warning "Algunos servicios tuvieron problemas ($errores errores)"
    fi

    return $errores
}

# Función para reinicio rápido (solo Apache y Zebra)
reinicio_rapido() {
    print_header "REINICIO RÁPIDO (Apache + Zebra)"

    local errores=0

    # Apache
    reiniciar_servicio "apache2" "Apache2" || ((errores++))

    # Zebra
    reiniciar_zebra || ((errores++))

    echo ""
    if [ $errores -eq 0 ]; then
        print_success "Reinicio rápido completado"
    else
        print_warning "Algunos servicios tuvieron problemas"
    fi

    return $errores
}

# Función para reinicio de caché
reinicio_cache() {
    print_header "REINICIO DE CACHÉ Y PLACK"

    local errores=0

    # Memcached
    if systemctl list-unit-files | grep -q memcached; then
        reiniciar_servicio "memcached" "Memcached" || ((errores++))
    else
        print_warning "Memcached no está instalado"
    fi

    # Plack
    reiniciar_plack || ((errores++))

    # Reload Apache (más ligero que restart)
    print_info "Recargando configuración de Apache..."
    systemctl reload apache2
    print_success "Apache recargado"

    echo ""
    if [ $errores -eq 0 ]; then
        print_success "Caché reiniciado correctamente"
    else
        print_warning "Algunos servicios tuvieron problemas"
    fi

    return $errores
}

# Función para mostrar estado
mostrar_estado() {
    print_header "ESTADO DE SERVICIOS KOHA"

    echo -e "${BOLD}Servicios del sistema:${NC}"

    # MySQL
    if systemctl is-active --quiet mysql; then
        echo -e "  ${GREEN}●${NC} MySQL: ${GREEN}corriendo${NC}"
    else
        echo -e "  ${RED}●${NC} MySQL: ${RED}detenido${NC}"
    fi

    # Apache
    if systemctl is-active --quiet apache2; then
        echo -e "  ${GREEN}●${NC} Apache2: ${GREEN}corriendo${NC}"
    else
        echo -e "  ${RED}●${NC} Apache2: ${RED}detenido${NC}"
    fi

    # Memcached
    if systemctl list-unit-files | grep -q memcached; then
        if systemctl is-active --quiet memcached; then
            echo -e "  ${GREEN}●${NC} Memcached: ${GREEN}corriendo${NC}"
        else
            echo -e "  ${RED}●${NC} Memcached: ${RED}detenido${NC}"
        fi
    else
        echo -e "  ${YELLOW}●${NC} Memcached: ${YELLOW}no instalado${NC}"
    fi

    echo ""
    echo -e "${BOLD}Servicios Koha (${INSTANCIA}):${NC}"

    # Zebra
    if koha-zebra --status "$INSTANCIA" 2>/dev/null | grep -q "running"; then
        echo -e "  ${GREEN}●${NC} Zebra: ${GREEN}corriendo${NC}"
    else
        echo -e "  ${RED}●${NC} Zebra: ${RED}detenido${NC}"
    fi

    # Plack
    if koha-plack --status "$INSTANCIA" 2>/dev/null | grep -q "running"; then
        echo -e "  ${GREEN}●${NC} Plack: ${GREEN}corriendo${NC}"
    else
        echo -e "  ${RED}●${NC} Plack: ${RED}detenido${NC}"
    fi

    echo ""
}

# Menú principal
mostrar_menu() {
    cat <<EOF
${BOLD}Opciones disponibles:${NC}

  1) ${CYAN}Reinicio completo${NC}        - Todos los servicios (MySQL, Apache, Zebra, Plack, Memcached)
  2) ${CYAN}Reinicio rápido${NC}          - Solo Apache y Zebra (más rápido)
  3) ${CYAN}Reinicio de caché${NC}        - Memcached y Plack
  4) ${CYAN}Solo Zebra${NC}               - Reiniciar solo el servidor de búsqueda
  5) ${CYAN}Solo Apache${NC}              - Reiniciar solo el servidor web
  6) ${CYAN}Mostrar estado${NC}           - Ver estado de todos los servicios

  q) Salir

EOF
    echo -n "Seleccione una opción [1-6/q]: "
}

# Manejo de argumentos de línea de comandos
if [ $# -gt 0 ]; then
    case "$1" in
        --completo|-c)
            reinicio_completo
            exit $?
            ;;
        --rapido|-r)
            reinicio_rapido
            exit $?
            ;;
        --cache)
            reinicio_cache
            exit $?
            ;;
        --zebra|-z)
            print_header "REINICIANDO ZEBRA"
            reiniciar_zebra
            exit $?
            ;;
        --apache|-a)
            print_header "REINICIANDO APACHE"
            reiniciar_servicio "apache2" "Apache2"
            exit $?
            ;;
        --estado|-s)
            mostrar_estado
            exit 0
            ;;
        --help|-h)
            echo "Uso: $0 [opción]"
            echo ""
            echo "Opciones:"
            echo "  -c, --completo    Reinicio completo de todos los servicios"
            echo "  -r, --rapido      Reinicio rápido (Apache + Zebra)"
            echo "  --cache           Reinicio de caché (Memcached + Plack)"
            echo "  -z, --zebra       Reiniciar solo Zebra"
            echo "  -a, --apache      Reiniciar solo Apache"
            echo "  -s, --estado      Mostrar estado de servicios"
            echo "  -h, --help        Mostrar esta ayuda"
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
            reinicio_completo
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        2)
            reinicio_rapido
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        3)
            reinicio_cache
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        4)
            print_header "REINICIANDO ZEBRA"
            reiniciar_zebra
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        5)
            print_header "REINICIANDO APACHE"
            reiniciar_servicio "apache2" "Apache2"
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        6)
            mostrar_estado
            echo ""
            read -p "Presione Enter para continuar..."
            clear
            ;;
        q|Q)
            echo ""
            print_info "Saliendo..."
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
