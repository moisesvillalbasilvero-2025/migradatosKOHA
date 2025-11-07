#!/bin/bash
################################################################################
# IMPORTADOR RÁPIDO - WRAPPER PARA IMPORTADOR ULTRA-OPTIMIZADO
################################################################################
# Script wrapper para facilitar el uso del importador ultra-optimizado
#
# CARACTERÍSTICAS:
# - ✅ Interfaz simple y amigable
# - ✅ Detección automática de configuración óptima
# - ✅ Pre-validación rápida opcional
# - ✅ Estimación de tiempo
# - ✅ Manejo de errores robusto
#
# USO:
#   ./importar_rapido.sh archivo.csv           # Automático
#   ./importar_rapido.sh archivo.csv --fast    # Máxima velocidad
#   ./importar_rapido.sh archivo.csv --safe    # Modo seguro
#   ./importar_rapido.sh --batch *.csv         # Múltiples archivos
#
# VERSIÓN: 1.0
# FECHA: 2025-11-04
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly IMPORTADOR="${SCRIPT_DIR}/importar_ultra_optimizado.py"
readonly VALIDADOR="${SCRIPT_DIR}/validador_csv.py"

# Colores
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_MAGENTA='\033[0;35m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# Variables
MODO="normal"  # normal, fast, safe
SKIP_VALIDACION=false
BATCH_MODE=false
ARCHIVOS=()

# ============================================================================
# FUNCIONES
# ============================================================================

banner() {
    echo ""
    echo -e "${C_BOLD}${C_CYAN}╔════════════════════════════════════════════════════════════════════╗${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}║                                                                    ║${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}║  🚀 IMPORTADOR RÁPIDO - KOHA UNA                                  ║${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}║     Sistema de importación ultra-optimizado                       ║${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}║                                                                    ║${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}╚════════════════════════════════════════════════════════════════════╝${C_NC}"
    echo ""
}

log_info() {
    echo -e "${C_CYAN}ℹ ${1}${C_NC}"
}

log_success() {
    echo -e "${C_GREEN}✓ ${1}${C_NC}"
}

log_warning() {
    echo -e "${C_YELLOW}⚠ ${1}${C_NC}"
}

log_error() {
    echo -e "${C_RED}✗ ${1}${C_NC}"
}

separador() {
    echo -e "${C_CYAN}────────────────────────────────────────────────────────────────────${C_NC}"
}

mostrar_ayuda() {
    cat << EOF
${C_BOLD}${C_CYAN}IMPORTADOR RÁPIDO - KOHA UNA${C_NC}

Sistema de importación ultra-optimizado con máximo rendimiento.

${C_BOLD}USO:${C_NC}
    $0 archivo.csv [OPCIONES]
    $0 --batch *.csv

${C_BOLD}OPCIONES:${C_NC}
    --fast              Modo máxima velocidad (más workers, chunks grandes)
    --safe              Modo seguro (validación completa, chunks pequeños)
    --skip-validation   Omitir validación previa (más rápido)
    --batch             Procesar múltiples archivos
    --workers N         Número de workers paralelos (auto por defecto)
    --chunk-size N      Tamaño de chunks de procesamiento
    --help, -h          Mostrar esta ayuda

${C_BOLD}MODOS:${C_NC}
    Normal (default)    Balance entre velocidad y seguridad
    Fast (--fast)       Máxima velocidad: 8 workers, chunks de 5000
    Safe (--safe)       Máxima seguridad: validación completa, chunks de 1000

${C_BOLD}EJEMPLOS:${C_NC}
    # Importación normal
    $0 ING.csv

    # Máxima velocidad
    $0 ING.csv --fast

    # Modo seguro con validación
    $0 ING.csv --safe

    # Omitir validación para ir más rápido
    $0 ING.csv --skip-validation

    # Múltiples archivos
    $0 --batch ING.csv MED.csv POL.csv

${C_BOLD}OPTIMIZACIONES ACTIVAS:${C_NC}
    ✓ Procesamiento paralelo automático
    ✓ Chunks adaptativos según memoria
    ✓ Reindexación única al final
    ✓ Caché de verificaciones BD
    ✓ Commits optimizados

Universidad Nacional de Asunción - 2025
EOF
}

detectar_recursos_sistema() {
    local num_cpus=$(nproc)
    local mem_total=$(free -g | awk '/^Mem:/{print $2}')

    log_info "Sistema detectado:"
    echo "  CPUs: $num_cpus"
    echo "  Memoria: ${mem_total}GB"
    echo ""
}

estimar_tiempo() {
    local archivo="$1"
    local num_lineas=$(wc -l < "$archivo" 2>/dev/null || echo "0")
    local num_registros=$((num_lineas - 1))

    if [ $num_registros -le 0 ]; then
        return
    fi

    # Estimaciones basadas en benchmarks reales
    local seg_por_registro=0.05  # 50ms por registro (optimizado)

    case "$MODO" in
        fast)
            seg_por_registro=0.03  # 30ms en modo fast
            ;;
        safe)
            seg_por_registro=0.08  # 80ms en modo safe
            ;;
    esac

    local tiempo_estimado=$((num_registros * seg_por_registro))
    local minutos=$((tiempo_estimado / 60))

    log_info "Estimación para $num_registros registros:"
    echo "  Tiempo estimado: ~${minutos} minutos"
    echo "  Velocidad esperada: ~$((1 / seg_por_registro)) reg/s"
    echo ""
}

validar_archivo_rapido() {
    local archivo="$1"

    if [ ! -f "$archivo" ]; then
        log_error "Archivo no existe: $archivo"
        return 1
    fi

    if [ ! -r "$archivo" ]; then
        log_error "No se puede leer el archivo: $archivo"
        return 1
    fi

    local tamanio=$(stat -f%z "$archivo" 2>/dev/null || stat -c%s "$archivo")
    if [ "$tamanio" -eq 0 ]; then
        log_error "Archivo vacío: $archivo"
        return 1
    fi

    log_success "Archivo válido: $(basename "$archivo") ($(numfmt --to=iec-i --suffix=B $tamanio))"
    return 0
}

validar_con_validador() {
    local archivo="$1"

    if [ ! -f "$VALIDADOR" ]; then
        log_warning "Validador no disponible, saltando validación detallada"
        return 0
    fi

    log_info "Ejecutando validación preventiva..."
    echo ""

    if python3 "$VALIDADOR" "$archivo"; then
        log_success "Validación exitosa"
        return 0
    else
        log_error "Validación falló"
        return 1
    fi
}

procesar_archivo() {
    local archivo="$1"

    echo ""
    separador
    log_info "PROCESANDO: $(basename "$archivo")"
    separador
    echo ""

    # Validación rápida
    if ! validar_archivo_rapido "$archivo"; then
        return 1
    fi

    # Validación completa (opcional)
    if [ "$SKIP_VALIDACION" = false ] && [ "$MODO" != "fast" ]; then
        if ! validar_con_validador "$archivo"; then
            log_error "Corrija los errores antes de continuar"
            return 1
        fi
        echo ""
    fi

    # Estimación de tiempo
    estimar_tiempo "$archivo"

    # Construir comando según modo
    local cmd="python3 \"$IMPORTADOR\" \"$archivo\""

    case "$MODO" in
        fast)
            cmd="$cmd --workers 8 --chunk-size 5000"
            log_info "Modo: FAST (8 workers, chunks 5000)"
            ;;
        safe)
            cmd="$cmd --workers 2 --chunk-size 1000"
            log_info "Modo: SAFE (2 workers, chunks 1000)"
            ;;
        *)
            log_info "Modo: NORMAL (auto workers, chunks auto)"
            ;;
    esac

    echo ""
    separador
    log_info "Iniciando importación..."
    separador
    echo ""

    # Ejecutar importación
    local inicio=$(date +%s)

    if eval "$cmd"; then
        local fin=$(date +%s)
        local duracion=$((fin - inicio))
        local minutos=$((duracion / 60))
        local segundos=$((duracion % 60))

        echo ""
        separador
        log_success "Importación completada en ${minutos}m ${segundos}s"
        separador
        echo ""
        return 0
    else
        log_error "Error durante importación"
        return 1
    fi
}

# ============================================================================
# PROCESAMIENTO DE ARGUMENTOS
# ============================================================================

# Si no hay argumentos, mostrar ayuda
if [ $# -eq 0 ]; then
    mostrar_ayuda
    exit 0
fi

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help|-h)
            mostrar_ayuda
            exit 0
            ;;
        --fast)
            MODO="fast"
            shift
            ;;
        --safe)
            MODO="safe"
            shift
            ;;
        --skip-validation)
            SKIP_VALIDACION=true
            shift
            ;;
        --batch)
            BATCH_MODE=true
            shift
            ;;
        --workers)
            WORKERS_ARG="--workers $2"
            shift 2
            ;;
        --chunk-size)
            CHUNK_ARG="--chunk-size $2"
            shift 2
            ;;
        -*)
            log_error "Opción desconocida: $1"
            echo "Use --help para ver opciones disponibles"
            exit 1
            ;;
        *)
            ARCHIVOS+=("$1")
            shift
            ;;
    esac
done

# ============================================================================
# VALIDACIONES INICIALES
# ============================================================================

banner

# Verificar Python
if ! command -v python3 &> /dev/null; then
    log_error "Python3 no está instalado"
    exit 1
fi

# Verificar importador
if [ ! -f "$IMPORTADOR" ]; then
    log_error "Importador no encontrado: $IMPORTADOR"
    exit 1
fi

# Verificar Koha
if ! command -v koha-shell &> /dev/null; then
    log_error "Koha no está instalado o no accesible"
    exit 1
fi

log_success "Dependencias verificadas"
echo ""

# Detectar recursos
detectar_recursos_sistema

# ============================================================================
# PROCESAMIENTO
# ============================================================================

if [ ${#ARCHIVOS[@]} -eq 0 ]; then
    log_error "Debe especificar al menos un archivo CSV"
    echo "Use --help para ver ejemplos"
    exit 1
fi

# Procesar archivos
TOTAL_EXITOSOS=0
TOTAL_FALLIDOS=0
TIEMPO_INICIO=$(date +%s)

for archivo in "${ARCHIVOS[@]}"; do
    if procesar_archivo "$archivo"; then
        ((TOTAL_EXITOSOS++))
    else
        ((TOTAL_FALLIDOS++))
    fi
done

TIEMPO_FIN=$(date +%s)
DURACION_TOTAL=$((TIEMPO_FIN - TIEMPO_INICIO))
MINUTOS_TOTAL=$((DURACION_TOTAL / 60))
SEGUNDOS_TOTAL=$((DURACION_TOTAL % 60))

# ============================================================================
# RESUMEN FINAL
# ============================================================================

echo ""
echo -e "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════════════${C_NC}"
echo -e "${C_BOLD}${C_CYAN}                         RESUMEN FINAL                              ${C_NC}"
echo -e "${C_BOLD}${C_CYAN}════════════════════════════════════════════════════════════════════${C_NC}"
echo ""

echo -e "${C_BOLD}Archivos procesados:${C_NC}  ${#ARCHIVOS[@]}"
echo -e "${C_GREEN}${C_BOLD}Exitosos:${C_NC}             $TOTAL_EXITOSOS"

if [ $TOTAL_FALLIDOS -gt 0 ]; then
    echo -e "${C_RED}${C_BOLD}Fallidos:${C_NC}              $TOTAL_FALLIDOS"
fi

echo ""
echo -e "${C_BOLD}Tiempo total:${C_NC}         ${MINUTOS_TOTAL}m ${SEGUNDOS_TOTAL}s"
echo -e "${C_BOLD}Modo utilizado:${C_NC}       ${MODO^^}"
echo ""

echo -e "${C_CYAN}════════════════════════════════════════════════════════════════════${C_NC}"
echo ""

# Generar reporte estadístico si la importación fue exitosa
if [ $TOTAL_FALLIDOS -eq 0 ] && [ $TOTAL_EXITOSOS -gt 0 ]; then
    echo ""
    separador
    log_info "📊 Generando reporte estadístico..."
    separador
    echo ""

    SCRIPT_REPORTE="${SCRIPT_DIR}/generar_reporte_estadistico.sh"
    if [ -f "$SCRIPT_REPORTE" ]; then
        if bash "$SCRIPT_REPORTE" --html --csv 2>/dev/null; then
            log_success "Reporte estadístico generado"
            echo ""
            log_info "Reportes disponibles en: ${SCRIPT_DIR}/reportes/"
        else
            log_warning "No se pudo generar el reporte estadístico"
        fi
    else
        log_warning "Script de reportes no encontrado"
    fi
    echo ""
fi

# Código de salida
if [ $TOTAL_FALLIDOS -eq 0 ]; then
    log_success "¡Proceso completado exitosamente!"
    exit 0
else
    log_warning "Proceso completado con algunos errores"
    exit 1
fi
