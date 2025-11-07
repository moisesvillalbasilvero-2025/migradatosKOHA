#!/bin/bash
################################################################################
# IMPORTADOR AUTOMÁTICO OPTIMIZADO KOHA - VERSIÓN 3.0
################################################################################
# Universidad Nacional de Asunción
# Sistema de importación automática optimizado con:
# - Detección inteligente de archivos
# - Validación preventiva automática
# - Importación con control de errores
# - Notificaciones y reportes
# - Modo batch y modo watch
# - Recuperación ante fallos
# - Estadísticas en tiempo real
#
# USO:
#   ./importar_optimizado.sh                    # Procesar todos los CSV en importar_aqui/
#   ./importar_optimizado.sh archivo.csv        # Procesar archivo específico
#   ./importar_optimizado.sh --watch            # Modo vigilancia continua
#   ./importar_optimizado.sh --batch DIR        # Procesar directorio completo
#   ./importar_optimizado.sh --validate-only    # Solo validar sin importar
#
# VERSIÓN: 3.0
# FECHA: 2025-10-31
################################################################################

set -o pipefail  # Capturar errores en pipes

# ============================================================================
# CONFIGURACIÓN GLOBAL
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="${SCRIPT_DIR}"
readonly INSTANCIA_KOHA="koha-cnc"

# Directorios
readonly DIR_IMPORTAR="${BASE_DIR}/importar_aqui"
readonly DIR_PROCESADOS="${BASE_DIR}/procesados"
readonly DIR_ERRORES="${BASE_DIR}/errores"
readonly DIR_LOGS="${BASE_DIR}/logs"
readonly DIR_EXPORTS="${BASE_DIR}/exports"
readonly DIR_REPORTES="${BASE_DIR}/reportes"

# Scripts
readonly AGENTE_PYTHON="${BASE_DIR}/agente_importador_v2.py"
readonly VALIDADOR="${BASE_DIR}/validador_csv.py"

# Colores
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_MAGENTA='\033[0;35m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# Variables globales
MODO_WATCH=false
MODO_BATCH=false
MODO_VALIDAR_SOLO=false
DIR_BATCH=""
ARCHIVO_ESPECIFICO=""
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_GENERAL="${DIR_LOGS}/maestro_${TIMESTAMP}.log"

# Estadísticas
TOTAL_PROCESADOS=0
TOTAL_EXITOSOS=0
TOTAL_FALLIDOS=0
TOTAL_VALIDADOS=0
TOTAL_INVALIDOS=0

# ============================================================================
# FUNCIONES DE LOGGING
# ============================================================================

log() {
    local nivel="$1"
    shift
    local mensaje="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[${timestamp}] [${nivel}] ${mensaje}" >> "$LOG_GENERAL"

    case "$nivel" in
        INFO)
            echo -e "${C_CYAN}ℹ ${mensaje}${C_NC}"
            ;;
        SUCCESS)
            echo -e "${C_GREEN}✓ ${mensaje}${C_NC}"
            ;;
        WARNING)
            echo -e "${C_YELLOW}⚠ ${mensaje}${C_NC}"
            ;;
        ERROR)
            echo -e "${C_RED}✗ ${mensaje}${C_NC}"
            ;;
        HEADER)
            echo -e "\n${C_BOLD}${C_CYAN}${mensaje}${C_NC}"
            ;;
        *)
            echo -e "${mensaje}"
            ;;
    esac
}

banner() {
    local mensaje="$1"
    echo ""
    echo -e "${C_BOLD}${C_CYAN}╔════════════════════════════════════════════════════════════════════╗${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}║$(printf '%68s' | tr ' ' ' ')║${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}║  ${mensaje}$(printf '%*s' $((64 - ${#mensaje})) '')║${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}║$(printf '%68s' | tr ' ' ' ')║${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}╚════════════════════════════════════════════════════════════════════╝${C_NC}"
    echo ""
}

separador() {
    echo -e "${C_CYAN}────────────────────────────────────────────────────────────────────${C_NC}"
}

# ============================================================================
# FUNCIONES DE INICIALIZACIÓN
# ============================================================================

crear_directorios() {
    mkdir -p "$DIR_IMPORTAR" "$DIR_PROCESADOS" "$DIR_ERRORES" \
             "$DIR_LOGS" "$DIR_EXPORTS" "$DIR_REPORTES"
}

verificar_dependencias() {
    log HEADER "Verificando dependencias del sistema..."

    local dependencias_ok=true

    # Python 3
    if ! command -v python3 &> /dev/null; then
        log ERROR "Python3 no está instalado"
        dependencias_ok=false
    fi

    # Scripts requeridos
    if [ ! -f "$AGENTE_PYTHON" ]; then
        log ERROR "Agente Python no encontrado: $AGENTE_PYTHON"
        dependencias_ok=false
    fi

    if [ ! -x "$AGENTE_PYTHON" ]; then
        log WARNING "Agente Python no es ejecutable, corrigiendo..."
        chmod +x "$AGENTE_PYTHON"
    fi

    # Koha
    if ! command -v koha-shell &> /dev/null; then
        log ERROR "Koha no está instalado o no accesible"
        dependencias_ok=false
    fi

    # MySQL
    if ! sudo koha-mysql ${INSTANCIA_KOHA} -e "SELECT 1" &>/dev/null; then
        log ERROR "No se puede conectar a MySQL de Koha"
        dependencias_ok=false
    fi

    if [ "$dependencias_ok" = true ]; then
        log SUCCESS "Todas las dependencias están disponibles"
        return 0
    else
        log ERROR "Faltan dependencias críticas"
        return 1
    fi
}

# ============================================================================
# FUNCIONES DE VALIDACIÓN
# ============================================================================

validar_archivo() {
    local archivo="$1"

    log INFO "Validando: $(basename "$archivo")"

    if [ ! -f "$VALIDADOR" ]; then
        log WARNING "Validador no disponible, saltando validación preventiva"
        return 0
    fi

    if python3 "$VALIDADOR" "$archivo" &>> "$LOG_GENERAL"; then
        log SUCCESS "Validación exitosa: $(basename "$archivo")"
        ((TOTAL_VALIDADOS++))
        return 0
    else
        log ERROR "Validación fallida: $(basename "$archivo")"
        ((TOTAL_INVALIDOS++))

        # Mover a errores
        local dest="${DIR_ERRORES}/$(basename "$archivo" .csv)_INVALIDO_${TIMESTAMP}.csv"
        mv "$archivo" "$dest" 2>/dev/null || true
        log INFO "Archivo movido a: $dest"

        return 1
    fi
}

# ============================================================================
# FUNCIONES DE DETECCIÓN
# ============================================================================

detectar_codigo_biblioteca() {
    local archivo="$1"
    local nombre=$(basename "$archivo" .csv)

    # Extraer código de biblioteca (3-6 letras mayúsculas)
    local codigo=$(echo "$nombre" | grep -oE '[A-Z]{3,6}' | head -1)

    if [ -n "$codigo" ]; then
        echo "$codigo"
        return 0
    fi

    return 1
}

verificar_biblioteca_existe() {
    local codigo="$1"

    local existe=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e \
        "SELECT COUNT(*) FROM branches WHERE branchcode = '${codigo}'" 2>/dev/null)

    [ "$existe" = "1" ]
}

# ============================================================================
# FUNCIONES DE PROCESAMIENTO
# ============================================================================

procesar_archivo() {
    local archivo="$1"
    local nombre=$(basename "$archivo")

    ((TOTAL_PROCESADOS++))

    banner "PROCESANDO: $nombre"

    # Paso 1: Detectar código
    log HEADER "1. Detección de biblioteca"
    separador

    local codigo=$(detectar_codigo_biblioteca "$archivo")
    if [ -z "$codigo" ]; then
        log ERROR "No se detectó código de biblioteca en: $nombre"
        log INFO "El nombre debe contener 3-6 letras mayúsculas (ej: MED.csv)"
        ((TOTAL_FALLIDOS++))
        return 1
    fi

    log SUCCESS "Código detectado: $codigo"

    # Paso 2: Verificar que existe en Koha
    log HEADER "2. Verificación en Koha"
    separador

    if ! verificar_biblioteca_existe "$codigo"; then
        log ERROR "La biblioteca '$codigo' NO existe en Koha"
        log INFO "Créela en: Staff Interface → Administración → Bibliotecas"
        ((TOTAL_FALLIDOS++))

        local dest="${DIR_ERRORES}/${nombre%.csv}_NO_EXISTE_${TIMESTAMP}.csv"
        mv "$archivo" "$dest" 2>/dev/null || true
        return 1
    fi

    local nombre_bib=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e \
        "SELECT branchname FROM branches WHERE branchcode = '${codigo}'" 2>/dev/null)
    log SUCCESS "Biblioteca verificada: $nombre_bib"

    # Paso 3: Validar archivo (si no es modo validar solo)
    if [ "$MODO_VALIDAR_SOLO" = false ]; then
        log HEADER "3. Validación del archivo"
        separador

        if ! validar_archivo "$archivo"; then
            log ERROR "Archivo no válido, no se puede importar"
            ((TOTAL_FALLIDOS++))
            return 1
        fi
    fi

    # Paso 4: Importar con agente Python
    if [ "$MODO_VALIDAR_SOLO" = false ]; then
        log HEADER "4. Importación a Koha"
        separador

        log INFO "Ejecutando agente de importación..."
        echo ""

        if python3 "$AGENTE_PYTHON" "$archivo"; then
            log SUCCESS "Importación completada: $codigo"
            ((TOTAL_EXITOSOS++))

            # Generar reporte
            generar_reporte_exitoso "$codigo" "$archivo"
            return 0
        else
            log ERROR "Error durante importación de: $nombre"
            ((TOTAL_FALLIDOS++))
            return 1
        fi
    else
        log SUCCESS "Validación completada (modo solo-validar)"
        return 0
    fi
}

# ============================================================================
# FUNCIONES DE REPORTES
# ============================================================================

generar_reporte_exitoso() {
    local codigo="$1"
    local archivo="$2"

    local reporte="${DIR_REPORTES}/reporte_${codigo}_${TIMESTAMP}.txt"

    cat > "$reporte" << EOF
╔════════════════════════════════════════════════════════════════════╗
║           REPORTE DE IMPORTACIÓN EXITOSA                           ║
╚════════════════════════════════════════════════════════════════════╝

Fecha y hora:        $(date '+%Y-%m-%d %H:%M:%S')
Código biblioteca:   $codigo
Archivo procesado:   $(basename "$archivo")

Items en Koha:
$(sudo koha-mysql ${INSTANCIA_KOHA} -t -e "
    SELECT
        COUNT(DISTINCT biblionumber) as Titulos,
        COUNT(*) as Ejemplares
    FROM items
    WHERE homebranch = '$codigo'
")

URL de verificación:
http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=$codigo

Estado: ✅ EXITOSO

════════════════════════════════════════════════════════════════════
EOF

    log SUCCESS "Reporte guardado: $reporte"
}

generar_reporte_final() {
    local duracion=$1

    local reporte="${DIR_REPORTES}/resumen_${TIMESTAMP}.txt"

    cat > "$reporte" << EOF
╔════════════════════════════════════════════════════════════════════╗
║              RESUMEN DE EJECUCIÓN - IMPORTADOR OPTIMIZADO          ║
╚════════════════════════════════════════════════════════════════════╝

Fecha y hora inicio:    $(date '+%Y-%m-%d %H:%M:%S' -d @$(($(date +%s) - duracion)))
Fecha y hora fin:       $(date '+%Y-%m-%d %H:%M:%S')
Duración total:         ${duracion} segundos ($(($duracion / 60)) minutos)

═══════════════════════════════════════════════════════════════════

ESTADÍSTICAS:

  Archivos procesados:    $TOTAL_PROCESADOS
  Importaciones exitosas: $TOTAL_EXITOSOS
  Importaciones fallidas: $TOTAL_FALLIDOS
  Archivos validados:     $TOTAL_VALIDADOS
  Archivos inválidos:     $TOTAL_INVALIDOS

═══════════════════════════════════════════════════════════════════

ESTADO DEL SISTEMA KOHA:

$(sudo koha-mysql ${INSTANCIA_KOHA} -t -e "
SELECT
    b.branchcode AS 'Código',
    b.branchname AS 'Biblioteca',
    COUNT(DISTINCT i.biblionumber) AS 'Títulos',
    COUNT(i.itemnumber) AS 'Ejemplares'
FROM branches b
LEFT JOIN items i ON b.branchcode = i.homebranch
GROUP BY b.branchcode, b.branchname
HAVING COUNT(i.itemnumber) > 0
ORDER BY COUNT(i.itemnumber) DESC
LIMIT 15
")

═══════════════════════════════════════════════════════════════════

Logs completos: $LOG_GENERAL
Reportes individuales: $DIR_REPORTES

Universidad Nacional de Asunción - Sistema Koha
════════════════════════════════════════════════════════════════════
EOF

    echo ""
    log SUCCESS "Reporte final generado: $reporte"
    echo ""
    cat "$reporte"
}

# ============================================================================
# MODOS DE OPERACIÓN
# ============================================================================

modo_archivo_unico() {
    local archivo="$1"

    if [ ! -f "$archivo" ]; then
        log ERROR "Archivo no existe: $archivo"
        return 1
    fi

    procesar_archivo "$archivo"
}

modo_batch() {
    local directorio="$1"

    if [ ! -d "$directorio" ]; then
        log ERROR "Directorio no existe: $directorio"
        return 1
    fi

    log INFO "Buscando archivos CSV en: $directorio"

    local archivos=($(find "$directorio" -maxdepth 1 -type f -name "*.csv" 2>/dev/null))

    if [ ${#archivos[@]} -eq 0 ]; then
        log WARNING "No se encontraron archivos CSV en: $directorio"
        return 1
    fi

    log SUCCESS "Archivos encontrados: ${#archivos[@]}"
    echo ""

    # Mostrar lista
    for i in "${!archivos[@]}"; do
        echo "  $((i+1)). $(basename "${archivos[$i]}")"
    done

    echo ""
    read -p "¿Procesar estos archivos? (SI/no): " -r respuesta

    if [[ ! $respuesta =~ ^(SI|si|S|s|YES|yes|Y|y|)$ ]]; then
        log INFO "Procesamiento cancelado"
        return 0
    fi

    # Procesar cada archivo
    for archivo in "${archivos[@]}"; do
        echo ""
        procesar_archivo "$archivo"
        echo ""
        separador
    done
}

modo_watch() {
    log INFO "🔄 MODO VIGILANCIA ACTIVADO"
    log INFO "Directorio: $DIR_IMPORTAR"
    log INFO "Intervalo: 10 segundos"
    echo ""
    echo -e "${C_YELLOW}Coloca archivos CSV en: $DIR_IMPORTAR${C_NC}"
    echo -e "${C_YELLOW}Presiona Ctrl+C para detener${C_NC}"
    echo ""

    declare -A procesados

    while true; do
        local archivos=($(find "$DIR_IMPORTAR" -maxdepth 1 -type f -name "*.csv" 2>/dev/null))

        for archivo in "${archivos[@]}"; do
            local hash=$(md5sum "$archivo" 2>/dev/null | cut -d' ' -f1)
            local key="$archivo:$hash"

            if [ -z "${procesados[$key]}" ]; then
                echo ""
                log INFO "🔔 NUEVO ARCHIVO DETECTADO: $(basename "$archivo")"
                echo ""

                sleep 2  # Esperar estabilidad

                procesar_archivo "$archivo"
                procesados[$key]=1

                echo ""
                separador
            fi
        done

        sleep 10
    done
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    local inicio=$(date +%s)

    # Banner inicial
    banner "IMPORTADOR AUTOMÁTICO OPTIMIZADO - KOHA UNA"

    # Inicialización
    crear_directorios

    if ! verificar_dependencias; then
        log ERROR "No se puede continuar sin dependencias"
        exit 1
    fi

    echo ""
    separador
    echo ""

    # Ejecutar modo correspondiente
    if [ "$MODO_WATCH" = true ]; then
        modo_watch
    elif [ "$MODO_BATCH" = true ]; then
        modo_batch "$DIR_BATCH"
    elif [ -n "$ARCHIVO_ESPECIFICO" ]; then
        modo_archivo_unico "$ARCHIVO_ESPECIFICO"
    else
        # Modo por defecto: procesar importar_aqui/
        modo_batch "$DIR_IMPORTAR"
    fi

    # Reporte final
    local fin=$(date +%s)
    local duracion=$((fin - inicio))

    echo ""
    separador
    echo ""

    generar_reporte_final "$duracion"

    # Resumen en consola
    echo ""
    banner "PROCESO COMPLETADO"
    echo ""
    echo -e "  ${C_BOLD}Procesados:${C_NC}  $TOTAL_PROCESADOS"
    echo -e "  ${C_GREEN}${C_BOLD}Exitosos:${C_NC}    $TOTAL_EXITOSOS"

    if [ $TOTAL_FALLIDOS -gt 0 ]; then
        echo -e "  ${C_RED}${C_BOLD}Fallidos:${C_NC}     $TOTAL_FALLIDOS"
    fi

    echo -e "  ${C_CYAN}Duración:${C_NC}    ${duracion}s"
    echo ""

    # Código de salida
    if [ $TOTAL_FALLIDOS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# ============================================================================
# PROCESAR ARGUMENTOS
# ============================================================================

mostrar_ayuda() {
    cat << EOF
${C_BOLD}${C_CYAN}IMPORTADOR AUTOMÁTICO OPTIMIZADO - KOHA UNA${C_NC}

Sistema de importación automática optimizado con validación,
control de errores, reportes y múltiples modos de operación.

${C_BOLD}USO:${C_NC}
    $0 [OPCIONES] [ARCHIVO]

${C_BOLD}OPCIONES:${C_NC}
    --watch, -w              Modo vigilancia continua
    --batch DIR, -b DIR      Procesar todos los CSV en directorio
    --validate-only, -v      Solo validar sin importar
    --help, -h               Mostrar esta ayuda

${C_BOLD}EJEMPLOS:${C_NC}
    # Procesar archivo específico
    $0 MED.csv

    # Procesar todos los CSV en importar_aqui/
    $0

    # Modo vigilancia
    $0 --watch

    # Procesar directorio específico
    $0 --batch /ruta/a/directorio

    # Solo validar archivos
    $0 --validate-only --batch importar_aqui/

${C_BOLD}CARACTERÍSTICAS:${C_NC}
    ✓ Detección automática de código de biblioteca
    ✓ Validación preventiva de archivos CSV
    ✓ Control de duplicados
    ✓ Generación de reportes detallados
    ✓ Modo batch para múltiples archivos
    ✓ Modo vigilancia para importación continua
    ✓ Recuperación ante errores
    ✓ Logs detallados

${C_BOLD}ARCHIVOS GENERADOS:${C_NC}
    logs/       - Logs de ejecución
    reportes/   - Reportes de importación
    procesados/ - CSV procesados exitosamente
    errores/    - CSV con errores

Universidad Nacional de Asunción - 2025
EOF
}

# Procesar argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --watch|-w)
            MODO_WATCH=true
            shift
            ;;
        --batch|-b)
            MODO_BATCH=true
            DIR_BATCH="$2"
            shift 2
            ;;
        --validate-only|-v)
            MODO_VALIDAR_SOLO=true
            shift
            ;;
        --help|-h)
            mostrar_ayuda
            exit 0
            ;;
        *)
            if [ -f "$1" ]; then
                ARCHIVO_ESPECIFICO="$1"
            else
                log ERROR "Opción desconocida o archivo no existe: $1"
                echo "Use --help para ver opciones disponibles"
                exit 1
            fi
            shift
            ;;
    esac
done

# Ejecutar
main
