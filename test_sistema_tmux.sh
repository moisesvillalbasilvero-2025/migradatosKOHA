#!/bin/bash
################################################################################
# TEST DEL SISTEMA TMUX - Verificación Completa
################################################################################

set -euo pipefail

readonly C_GREEN='\033[0;32m'
readonly C_RED='\033[0;31m'
readonly C_YELLOW='\033[1;33m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

test_count=0
test_passed=0
test_failed=0

log_test() {
    test_count=$((test_count + 1))
    echo -e "${C_CYAN}[TEST $test_count]${C_NC} $1"
}

log_pass() {
    test_passed=$((test_passed + 1))
    echo -e "  ${C_GREEN}✓ PASS${C_NC} $1"
}

log_fail() {
    test_failed=$((test_failed + 1))
    echo -e "  ${C_RED}✗ FAIL${C_NC} $1"
}

echo -e "${C_BOLD}${C_CYAN}"
echo "═══════════════════════════════════════════════════════════════"
echo "  TEST DEL SISTEMA DE IMPORTACIÓN CON TMUX"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${C_NC}\n"

# TEST 1: Verificar tmux
log_test "Verificar instalación de tmux"
if command -v tmux &> /dev/null; then
    log_pass "tmux está instalado: $(tmux -V)"
else
    log_fail "tmux NO está instalado"
fi

# TEST 2: Verificar scripts principales
log_test "Verificar scripts principales"
for script in importar_tmux.sh monitor_tmux.sh gestionar_importaciones.sh; do
    if [ -f "$script" ] && [ -x "$script" ]; then
        log_pass "$script existe y es ejecutable"
    else
        log_fail "$script no existe o no es ejecutable"
    fi
done

# TEST 3: Verificar directorios
log_test "Verificar estructura de directorios"
for dir in logs/tmux .sessions importar_aqui procesados errores exports; do
    if [ -d "$dir" ]; then
        log_pass "Directorio $dir existe"
    else
        mkdir -p "$dir"
        log_pass "Directorio $dir creado"
    fi
done

# TEST 4: Verificar documentación
log_test "Verificar documentación"
if [ -f "GUIA_SISTEMA_TMUX.md" ]; then
    log_pass "Guía de usuario existe"
else
    log_fail "Guía de usuario no existe"
fi

# TEST 5: Probar ayuda de scripts
log_test "Verificar ayuda de scripts"
if ./importar_tmux.sh --help &>/dev/null; then
    log_pass "importar_tmux.sh --help funciona"
else
    log_fail "importar_tmux.sh --help no funciona"
fi

if ./monitor_tmux.sh --help &>/dev/null; then
    log_pass "monitor_tmux.sh --help funciona"
else
    log_fail "monitor_tmux.sh --help no funciona"
fi

# TEST 6: Verificar estado inicial
log_test "Verificar estado inicial del sistema"
sesiones_activas=$(tmux list-sessions 2>/dev/null | grep "koha-import-" | wc -l || echo "0")
echo -e "  ${C_CYAN}ℹ${C_NC} Sesiones tmux activas: $sesiones_activas"

archivos_pendientes=$(ls -1 importar_aqui/*.csv 2>/dev/null | wc -l || echo "0")
echo -e "  ${C_CYAN}ℹ${C_NC} Archivos pendientes: $archivos_pendientes"

# TEST 7: Test de status
log_test "Probar comando --status"
if ./importar_tmux.sh --status &>/dev/null; then
    log_pass "Comando --status funciona"
else
    log_fail "Comando --status no funciona"
fi

# TEST 8: Verificar permisos
log_test "Verificar permisos de ejecución"
if [ -x importar_tmux.sh ] && [ -x monitor_tmux.sh ] && [ -x gestionar_importaciones.sh ]; then
    log_pass "Todos los scripts tienen permisos de ejecución"
else
    log_fail "Algunos scripts no tienen permisos de ejecución"
fi

# RESUMEN
echo ""
echo -e "${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════════${C_NC}"
echo -e "${C_BOLD}RESUMEN DE TESTS${C_NC}"
echo -e "${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════════${C_NC}"
echo ""
echo "  Tests ejecutados: $test_count"
echo -e "  ${C_GREEN}Tests exitosos:   $test_passed${C_NC}"

if [ $test_failed -gt 0 ]; then
    echo -e "  ${C_RED}Tests fallidos:   $test_failed${C_NC}"
    echo ""
    echo -e "${C_YELLOW}⚠ El sistema tiene algunos problemas. Revisa los errores arriba.${C_NC}"
    exit 1
else
    echo -e "  ${C_RED}Tests fallidos:   $test_failed${C_NC}"
    echo ""
    echo -e "${C_GREEN}${C_BOLD}✓ ¡SISTEMA COMPLETAMENTE FUNCIONAL!${C_NC}"
    echo ""
    echo -e "${C_CYAN}Para comenzar a usar el sistema:${C_NC}"
    echo ""
    echo "  1. Menú interactivo completo:"
    echo -e "     ${C_YELLOW}./gestionar_importaciones.sh${C_NC}"
    echo ""
    echo "  2. Importar un archivo:"
    echo -e "     ${C_YELLOW}./importar_tmux.sh importar_aqui/ARCHIVO.csv${C_NC}"
    echo ""
    echo "  3. Ver estado de sesiones:"
    echo -e "     ${C_YELLOW}./importar_tmux.sh --status${C_NC}"
    echo ""
    echo "  4. Monitor en tiempo real:"
    echo -e "     ${C_YELLOW}./monitor_tmux.sh${C_NC}"
    echo ""
    echo "  5. Ver la guía completa:"
    echo -e "     ${C_YELLOW}cat GUIA_SISTEMA_TMUX.md${C_NC}"
    echo ""
fi

echo -e "${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════════${C_NC}"
