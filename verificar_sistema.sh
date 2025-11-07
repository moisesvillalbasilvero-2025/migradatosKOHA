#!/bin/bash
################################################################################
# VERIFICADOR DE SISTEMA - V3.0
################################################################################
# Universidad Nacional de Asunción
# Verifica que el sistema de importación esté correctamente instalado
# y configurado
#
# USO:
#   ./verificar_sistema.sh
#
# VERSIÓN: 1.0
# FECHA: 2025-10-31
################################################################################

# Colores
readonly C_GREEN='\033[0;32m'
readonly C_RED='\033[0;31m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# Contadores
CHECKS_OK=0
CHECKS_WARNING=0
CHECKS_FAIL=0
TOTAL_CHECKS=0

# ============================================================================
# FUNCIONES
# ============================================================================

check_ok() {
    echo -e "${C_GREEN}✓${C_NC} $1"
    ((CHECKS_OK++))
    ((TOTAL_CHECKS++))
}

check_warning() {
    echo -e "${C_YELLOW}⚠${C_NC} $1"
    ((CHECKS_WARNING++))
    ((TOTAL_CHECKS++))
}

check_fail() {
    echo -e "${C_RED}✗${C_NC} $1"
    ((CHECKS_FAIL++))
    ((TOTAL_CHECKS++))
}

header() {
    echo ""
    echo -e "${C_CYAN}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
    echo -e "${C_CYAN}${C_BOLD}$1${C_NC}"
    echo -e "${C_CYAN}${C_BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
}

# ============================================================================
# VERIFICACIONES
# ============================================================================

banner() {
    echo ""
    echo -e "${C_BOLD}${C_CYAN}"
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                      ║"
    echo "║           VERIFICADOR DE SISTEMA - IMPORTACIÓN KOHA V3.0            ║"
    echo "║                                                                      ║"
    echo "║              Universidad Nacional de Asunción                        ║"
    echo "║                                                                      ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo -e "${C_NC}"
}

verificar_scripts() {
    header "1. SCRIPTS PRINCIPALES"

    # Script maestro
    if [ -f "importar_optimizado.sh" ] && [ -x "importar_optimizado.sh" ]; then
        check_ok "importar_optimizado.sh - Presente y ejecutable"
    elif [ -f "importar_optimizado.sh" ]; then
        check_warning "importar_optimizado.sh - Presente pero no ejecutable"
        echo "   Ejecutar: chmod +x importar_optimizado.sh"
    else
        check_fail "importar_optimizado.sh - NO ENCONTRADO"
    fi

    # Agente Python V3
    if [ -f "agente_importador_v3.py" ] && [ -x "agente_importador_v3.py" ]; then
        check_ok "agente_importador_v3.py - Presente y ejecutable"
    elif [ -f "agente_importador_v3.py" ]; then
        check_warning "agente_importador_v3.py - Presente pero no ejecutable"
        echo "   Ejecutar: chmod +x agente_importador_v3.py"
    else
        check_fail "agente_importador_v3.py - NO ENCONTRADO"
    fi

    # Validador
    if [ -f "validador_csv.py" ] && [ -x "validador_csv.py" ]; then
        check_ok "validador_csv.py - Presente y ejecutable"
    elif [ -f "validador_csv.py" ]; then
        check_warning "validador_csv.py - Presente pero no ejecutable"
        echo "   Ejecutar: chmod +x validador_csv.py"
    else
        check_fail "validador_csv.py - NO ENCONTRADO"
    fi

    # Dashboard
    if [ -f "dashboard.py" ] && [ -x "dashboard.py" ]; then
        check_ok "dashboard.py - Presente y ejecutable"
    elif [ -f "dashboard.py" ]; then
        check_warning "dashboard.py - Presente pero no ejecutable"
        echo "   Ejecutar: chmod +x dashboard.py"
    else
        check_fail "dashboard.py - NO ENCONTRADO"
    fi
}

verificar_directorios() {
    header "2. DIRECTORIOS DEL SISTEMA"

    directorios=(
        "importar_aqui"
        "procesados"
        "errores"
        "logs"
        "reportes"
        "exports"
    )

    for dir in "${directorios[@]}"; do
        if [ -d "$dir" ]; then
            check_ok "$dir/ - Existe"
        else
            check_warning "$dir/ - No existe (se creará automáticamente)"
        fi
    done
}

verificar_dependencias() {
    header "3. DEPENDENCIAS DEL SISTEMA"

    # Python 3
    if command -v python3 &> /dev/null; then
        version=$(python3 --version 2>&1 | awk '{print $2}')
        check_ok "Python 3 - Instalado (versión $version)"
    else
        check_fail "Python 3 - NO INSTALADO"
        echo "   Ejecutar: sudo apt install python3"
    fi

    # Koha shell
    if command -v koha-shell &> /dev/null; then
        check_ok "koha-shell - Disponible"
    else
        check_fail "koha-shell - NO DISPONIBLE"
    fi

    # MySQL client
    if command -v mysql &> /dev/null; then
        check_ok "mysql client - Instalado"
    else
        check_fail "mysql client - NO INSTALADO"
    fi

    # koha-mysql
    if command -v koha-mysql &> /dev/null; then
        check_ok "koha-mysql - Disponible"
    else
        check_fail "koha-mysql - NO DISPONIBLE"
    fi
}

verificar_koha() {
    header "4. CONEXIÓN A KOHA"

    # Verificar conexión
    if sudo koha-mysql koha-cnc -e "SELECT 1" &>/dev/null; then
        check_ok "Conexión a base de datos - Exitosa"

        # Obtener estadísticas
        total_biblios=$(sudo koha-mysql koha-cnc -N -e "SELECT COUNT(*) FROM biblio" 2>/dev/null || echo "0")
        total_items=$(sudo koha-mysql koha-cnc -N -e "SELECT COUNT(*) FROM items" 2>/dev/null || echo "0")
        total_bibliotecas=$(sudo koha-mysql koha-cnc -N -e "SELECT COUNT(*) FROM branches" 2>/dev/null || echo "0")

        echo "   📊 Biblios: $total_biblios | Items: $total_items | Bibliotecas: $total_bibliotecas"
    else
        check_fail "Conexión a base de datos - FALLO"
    fi

    # Verificar servicio MySQL
    if systemctl is-active --quiet mysql || systemctl is-active --quiet mariadb; then
        check_ok "Servicio MySQL/MariaDB - Activo"
    else
        check_fail "Servicio MySQL/MariaDB - Inactivo"
    fi
}

verificar_recursos() {
    header "5. RECURSOS DEL SISTEMA"

    # Espacio en disco
    espacio_libre=$(df -BG "$(pwd)" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$espacio_libre" -gt 10 ]; then
        check_ok "Espacio en disco - ${espacio_libre}GB disponible"
    elif [ "$espacio_libre" -gt 1 ]; then
        check_warning "Espacio en disco - ${espacio_libre}GB disponible (bajo)"
    else
        check_fail "Espacio en disco - ${espacio_libre}GB disponible (CRÍTICO)"
    fi

    # Memoria RAM
    memoria_libre=$(free -g | awk '/^Mem:/ {print $7}')
    if [ "$memoria_libre" -gt 2 ]; then
        check_ok "Memoria RAM - ${memoria_libre}GB disponible"
    elif [ "$memoria_libre" -gt 1 ]; then
        check_warning "Memoria RAM - ${memoria_libre}GB disponible (justa)"
    else
        check_warning "Memoria RAM - ${memoria_libre}GB disponible (limitada)"
    fi

    # Carga del sistema
    load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    check_ok "Carga del sistema - $load"
}

verificar_documentacion() {
    header "6. DOCUMENTACIÓN"

    # README principal
    if [ -f "README_SISTEMA_V3.md" ]; then
        check_ok "README_SISTEMA_V3.md - Disponible"
    else
        check_warning "README_SISTEMA_V3.md - No encontrado"
    fi

    # Guía completa
    if [ -f "GUIA_COMPLETA_OPTIMIZADA.md" ]; then
        check_ok "GUIA_COMPLETA_OPTIMIZADA.md - Disponible"
    else
        check_warning "GUIA_COMPLETA_OPTIMIZADA.md - No encontrada"
    fi

    # Guía rápida
    if [ -f "INICIO_RAPIDO_V3.txt" ]; then
        check_ok "INICIO_RAPIDO_V3.txt - Disponible"
    else
        check_warning "INICIO_RAPIDO_V3.txt - No encontrado"
    fi
}

verificar_permisos() {
    header "7. PERMISOS"

    # Permiso de escritura en directorios clave
    for dir in logs reportes procesados errores; do
        if [ -w "$dir" ] 2>/dev/null || [ ! -e "$dir" ]; then
            check_ok "Permisos de escritura en $dir/ - OK"
        else
            check_fail "Permisos de escritura en $dir/ - NO"
        fi
    done

    # Permisos sudo
    if sudo -n true 2>/dev/null; then
        check_ok "Permisos sudo - Disponibles sin password"
    elif sudo -v &>/dev/null; then
        check_warning "Permisos sudo - Requieren password"
    else
        check_fail "Permisos sudo - NO disponibles"
    fi
}

generar_resumen() {
    echo ""
    echo -e "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════════════${C_NC}"
    echo -e "${C_BOLD}                          RESUMEN DE VERIFICACIÓN${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════════════${C_NC}"
    echo ""
    echo -e "  Total de verificaciones:  ${C_BOLD}$TOTAL_CHECKS${C_NC}"
    echo -e "  ${C_GREEN}Exitosas:${C_NC}                 ${C_BOLD}$CHECKS_OK${C_NC}"

    if [ $CHECKS_WARNING -gt 0 ]; then
        echo -e "  ${C_YELLOW}Advertencias:${C_NC}             ${C_BOLD}$CHECKS_WARNING${C_NC}"
    fi

    if [ $CHECKS_FAIL -gt 0 ]; then
        echo -e "  ${C_RED}Fallidas:${C_NC}                 ${C_BOLD}$CHECKS_FAIL${C_NC}"
    fi

    echo ""

    # Veredicto final
    if [ $CHECKS_FAIL -eq 0 ] && [ $CHECKS_WARNING -eq 0 ]; then
        echo -e "${C_GREEN}${C_BOLD}╔════════════════════════════════════════════════════════════════════╗${C_NC}"
        echo -e "${C_GREEN}${C_BOLD}║                                                                    ║${C_NC}"
        echo -e "${C_GREEN}${C_BOLD}║          ✓✓✓ SISTEMA COMPLETAMENTE FUNCIONAL ✓✓✓                  ║${C_NC}"
        echo -e "${C_GREEN}${C_BOLD}║                                                                    ║${C_NC}"
        echo -e "${C_GREEN}${C_BOLD}╚════════════════════════════════════════════════════════════════════╝${C_NC}"
        echo ""
        echo "¡El sistema está listo para importar!"
        echo ""
        echo "Próximos pasos:"
        echo "  1. Leer: cat INICIO_RAPIDO_V3.txt"
        echo "  2. Colocar CSV en: importar_aqui/"
        echo "  3. Ejecutar: ./importar_optimizado.sh"
        echo ""
        exit 0
    elif [ $CHECKS_FAIL -eq 0 ]; then
        echo -e "${C_YELLOW}${C_BOLD}╔════════════════════════════════════════════════════════════════════╗${C_NC}"
        echo -e "${C_YELLOW}${C_BOLD}║                                                                    ║${C_NC}"
        echo -e "${C_YELLOW}${C_BOLD}║       ⚠ SISTEMA FUNCIONAL CON ADVERTENCIAS ⚠                      ║${C_NC}"
        echo -e "${C_YELLOW}${C_BOLD}║                                                                    ║${C_NC}"
        echo -e "${C_YELLOW}${C_BOLD}╚════════════════════════════════════════════════════════════════════╝${C_NC}"
        echo ""
        echo "El sistema puede funcionar, pero revisa las advertencias arriba."
        echo ""
        exit 0
    else
        echo -e "${C_RED}${C_BOLD}╔════════════════════════════════════════════════════════════════════╗${C_NC}"
        echo -e "${C_RED}${C_BOLD}║                                                                    ║${C_NC}"
        echo -e "${C_RED}${C_BOLD}║            ✗✗✗ PROBLEMAS DETECTADOS ✗✗✗                            ║${C_NC}"
        echo -e "${C_RED}${C_BOLD}║                                                                    ║${C_NC}"
        echo -e "${C_RED}${C_BOLD}╚════════════════════════════════════════════════════════════════════╝${C_NC}"
        echo ""
        echo "Revisa los errores marcados con ✗ arriba y corrígelos."
        echo ""
        exit 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

# Cambiar al directorio del script
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

# Banner
banner

# Ejecutar verificaciones
verificar_scripts
verificar_directorios
verificar_dependencias
verificar_koha
verificar_recursos
verificar_documentacion
verificar_permisos

# Resumen
generar_resumen
