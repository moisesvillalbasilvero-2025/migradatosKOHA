#!/bin/bash
################################################################################
# EJEMPLO DE USO COMPLETO - SISTEMA ULTRA-OPTIMIZADO
################################################################################
# Este script demuestra el flujo completo de una importación
# desde la validación hasta la verificación final.
#
# NOTA: Este es un ejemplo educativo. Ajusta según tus necesidades.
#
# VERSIÓN: 1.0
# FECHA: 2025-11-04
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

# Archivo CSV a importar (cambia esto)
ARCHIVO_CSV="ING.csv"

# Código de biblioteca esperado
CODIGO_BIBLIOTECA="ING"

# Colores
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_CYAN='\033[0;36m'
readonly C_RED='\033[0;31m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# ============================================================================
# FUNCIONES
# ============================================================================

banner() {
    echo ""
    echo -e "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════════════${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}  $1${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════════════${C_NC}"
    echo ""
}

paso() {
    echo ""
    echo -e "${C_BOLD}${C_CYAN}➤ PASO $1: $2${C_NC}"
    echo ""
}

success() {
    echo -e "${C_GREEN}✓ $1${C_NC}"
}

info() {
    echo -e "${C_CYAN}ℹ $1${C_NC}"
}

warning() {
    echo -e "${C_YELLOW}⚠ $1${C_NC}"
}

error() {
    echo -e "${C_RED}✗ $1${C_NC}"
}

pause_continue() {
    echo ""
    read -p "Presiona ENTER para continuar o Ctrl+C para cancelar..."
    echo ""
}

# ============================================================================
# FLUJO PRINCIPAL
# ============================================================================

main() {
    banner "EJEMPLO DE FLUJO COMPLETO DE IMPORTACIÓN"

    info "Este script te guiará por todo el proceso de importación optimizada"
    info "Archivo a procesar: ${ARCHIVO_CSV}"
    echo ""

    pause_continue

    # ────────────────────────────────────────────────────────────────────────
    paso "1" "VERIFICAR ARCHIVO CSV EXISTE"
    # ────────────────────────────────────────────────────────────────────────

    if [ ! -f "$ARCHIVO_CSV" ]; then
        error "Archivo no encontrado: $ARCHIVO_CSV"
        info "Por favor, coloca tu archivo CSV en el directorio actual"
        exit 1
    fi

    success "Archivo encontrado: $ARCHIVO_CSV"
    info "Tamaño: $(du -h "$ARCHIVO_CSV" | cut -f1)"
    info "Líneas: $(wc -l < "$ARCHIVO_CSV")"

    pause_continue

    # ────────────────────────────────────────────────────────────────────────
    paso "2" "VALIDAR ESTRUCTURA DEL CSV"
    # ────────────────────────────────────────────────────────────────────────

    info "Ejecutando validador preventivo..."
    echo ""

    if python3 validador_csv.py "$ARCHIVO_CSV"; then
        success "Archivo CSV válido"
    else
        error "El archivo tiene errores de validación"
        warning "Debes corregir los errores antes de continuar"
        exit 1
    fi

    pause_continue

    # ────────────────────────────────────────────────────────────────────────
    paso "3" "ANALIZAR Y OBTENER RECOMENDACIONES"
    # ────────────────────────────────────────────────────────────────────────

    info "Analizando archivo y generando recomendaciones..."
    echo ""

    ./benchmark_comparacion.sh "$ARCHIVO_CSV"

    pause_continue

    # ────────────────────────────────────────────────────────────────────────
    paso "4" "VERIFICAR RECURSOS DEL SISTEMA"
    # ────────────────────────────────────────────────────────────────────────

    info "Recursos disponibles:"
    echo ""
    echo "CPUs:"
    nproc
    echo ""
    echo "Memoria:"
    free -h | grep "Mem:"
    echo ""
    echo "Disco:"
    df -h . | tail -1
    echo ""

    NUM_CPUS=$(nproc)
    MEM_GB=$(free -g | awk '/^Mem:/{print $2}')

    if [ $NUM_CPUS -ge 4 ] && [ $MEM_GB -ge 8 ]; then
        success "Recursos suficientes para modo optimizado"
        MODO_RECOMENDADO="normal"
    elif [ $NUM_CPUS -ge 8 ] && [ $MEM_GB -ge 16 ]; then
        success "Recursos excelentes para modo FAST"
        MODO_RECOMENDADO="fast"
    else
        warning "Recursos limitados - usar modo seguro"
        MODO_RECOMENDADO="safe"
    fi

    info "Modo recomendado: $MODO_RECOMENDADO"

    pause_continue

    # ────────────────────────────────────────────────────────────────────────
    paso "5" "VERIFICAR BIBLIOTECA EN KOHA"
    # ────────────────────────────────────────────────────────────────────────

    info "Verificando que la biblioteca '$CODIGO_BIBLIOTECA' existe en Koha..."
    echo ""

    NOMBRE_BIBLIOTECA=$(sudo koha-mysql koha-cnc -N -e \
        "SELECT branchname FROM branches WHERE branchcode = '$CODIGO_BIBLIOTECA'" 2>/dev/null || echo "")

    if [ -z "$NOMBRE_BIBLIOTECA" ]; then
        error "La biblioteca '$CODIGO_BIBLIOTECA' NO existe en Koha"
        warning "Debes crearla primero en: Staff Interface → Administración → Bibliotecas"
        exit 1
    fi

    success "Biblioteca encontrada: $NOMBRE_BIBLIOTECA"

    # Contar items actuales
    ITEMS_ANTES=$(sudo koha-mysql koha-cnc -N -e \
        "SELECT COUNT(*) FROM items WHERE homebranch = '$CODIGO_BIBLIOTECA'" 2>/dev/null || echo "0")

    info "Items actuales en la biblioteca: $ITEMS_ANTES"

    pause_continue

    # ────────────────────────────────────────────────────────────────────────
    paso "6" "BACKUP PREVENTIVO (RECOMENDADO)"
    # ────────────────────────────────────────────────────────────────────────

    warning "Se recomienda hacer un backup antes de importar datos"
    echo ""
    info "Comando para backup:"
    echo "  sudo koha-dump koha-cnc"
    echo ""

    read -p "¿Ya hiciste el backup? (s/n): " -r BACKUP_HECHO

    if [[ ! $BACKUP_HECHO =~ ^[Ss]$ ]]; then
        warning "Considera hacer un backup antes de continuar"
        warning "Especialmente si es la primera importación a esta biblioteca"
    else
        success "Backup confirmado"
    fi

    pause_continue

    # ────────────────────────────────────────────────────────────────────────
    paso "7" "EJECUTAR IMPORTACIÓN OPTIMIZADA"
    # ────────────────────────────────────────────────────────────────────────

    banner "INICIANDO IMPORTACIÓN"

    info "Modo: $MODO_RECOMENDADO"
    info "Archivo: $ARCHIVO_CSV"
    info "Biblioteca: $CODIGO_BIBLIOTECA ($NOMBRE_BIBLIOTECA)"
    echo ""

    warning "La importación comenzará ahora..."
    warning "Puedes monitorear el progreso en otra terminal con:"
    echo "    tail -f logs/importacion_ultra_*.log"
    echo ""

    pause_continue

    # Construir comando según modo
    case "$MODO_RECOMENDADO" in
        fast)
            COMANDO="./importar_rapido.sh \"$ARCHIVO_CSV\" --fast"
            ;;
        safe)
            COMANDO="./importar_rapido.sh \"$ARCHIVO_CSV\" --safe"
            ;;
        *)
            COMANDO="./importar_rapido.sh \"$ARCHIVO_CSV\""
            ;;
    esac

    info "Ejecutando: $COMANDO"
    echo ""

    TIMESTAMP_INICIO=$(date +%s)

    # Ejecutar importación
    if eval "$COMANDO"; then
        TIMESTAMP_FIN=$(date +%s)
        DURACION=$((TIMESTAMP_FIN - TIMESTAMP_INICIO))

        success "Importación completada exitosamente"
        info "Duración: $((DURACION / 60))m $((DURACION % 60))s"
    else
        error "La importación falló"
        warning "Revisa los logs en logs/importacion_ultra_*.log"
        exit 1
    fi

    pause_continue

    # ────────────────────────────────────────────────────────────────────────
    paso "8" "VERIFICAR RESULTADOS"
    # ────────────────────────────────────────────────────────────────────────

    info "Contando items importados..."
    echo ""

    ITEMS_DESPUES=$(sudo koha-mysql koha-cnc -N -e \
        "SELECT COUNT(*) FROM items WHERE homebranch = '$CODIGO_BIBLIOTECA'" 2>/dev/null || echo "0")

    ITEMS_NUEVOS=$((ITEMS_DESPUES - ITEMS_ANTES))

    echo "Items antes:   $ITEMS_ANTES"
    echo "Items después: $ITEMS_DESPUES"

    if [ $ITEMS_NUEVOS -gt 0 ]; then
        success "Items nuevos importados: $ITEMS_NUEVOS"
    else
        warning "No se importaron nuevos items (o hubo un error)"
    fi

    pause_continue

    # ────────────────────────────────────────────────────────────────────────
    paso "9" "VERIFICAR EN OPAC (OPCIONAL)"
    # ────────────────────────────────────────────────────────────────────────

    info "Puedes verificar los registros en el OPAC:"
    echo ""
    echo "  URL: http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=$CODIGO_BIBLIOTECA"
    echo ""

    info "O desde línea de comandos:"
    echo "  sudo koha-mysql koha-cnc -e \"SELECT COUNT(*) FROM biblioitems WHERE datecreated = CURDATE()\""
    echo ""

    pause_continue

    # ────────────────────────────────────────────────────────────────────────
    paso "10" "REVISAR LOGS (RECOMENDADO)"
    # ────────────────────────────────────────────────────────────────────────

    info "Se generaron logs detallados en:"
    echo ""
    ls -lht logs/importacion_ultra_* 2>/dev/null | head -3
    echo ""

    info "Para revisar el log más reciente:"
    ULTIMO_LOG=$(ls -t logs/importacion_ultra_*.log 2>/dev/null | head -1)
    if [ -n "$ULTIMO_LOG" ]; then
        echo "  less \"$ULTIMO_LOG\""
        echo ""
        read -p "¿Quieres ver el log ahora? (s/n): " -r VER_LOG
        if [[ $VER_LOG =~ ^[Ss]$ ]]; then
            less "$ULTIMO_LOG"
        fi
    fi

    echo ""

    # ────────────────────────────────────────────────────────────────────────
    banner "PROCESO COMPLETADO"
    # ────────────────────────────────────────────────────────────────────────

    success "¡Flujo de importación completado exitosamente!"
    echo ""

    info "Resumen:"
    echo "  • Archivo procesado: $ARCHIVO_CSV"
    echo "  • Biblioteca: $CODIGO_BIBLIOTECA ($NOMBRE_BIBLIOTECA)"
    echo "  • Items nuevos: $ITEMS_NUEVOS"
    echo "  • Duración: $((DURACION / 60))m $((DURACION % 60))s"
    echo ""

    info "Próximos pasos recomendados:"
    echo "  1. Verificar registros en OPAC"
    echo "  2. Revisar logs detallados"
    echo "  3. Documentar importación para referencia futura"
    echo "  4. Si hubo errores: revisar y corregir CSV"
    echo ""

    success "¡Gracias por usar el sistema ultra-optimizado!"
    echo ""
}

# ============================================================================
# MANEJO DE SEÑALES
# ============================================================================

trap 'echo ""; warning "Proceso interrumpido por usuario"; exit 130' INT TERM

# ============================================================================
# EJECUTAR
# ============================================================================

main "$@"
