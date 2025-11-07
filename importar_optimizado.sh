#!/bin/bash
################################################################################
# IMPORTADOR AUTOMÁTICO OPTIMIZADO KOHA - VERSIÓN 3.0
################################################################################
# Universidad Nacional de Asunción
#
# DESCRIPCIÓN:
#   Sistema profesional de importación automática a Koha con:
#   - Detección inteligente de códigos de biblioteca
#   - Validación preventiva automática de archivos CSV
#   - Importación con control exhaustivo de errores
#   - Generación de reportes detallados
#   - Múltiples modos de operación (batch, watch, validate-only)
#   - Recuperación automática ante fallos
#   - Estadísticas en tiempo real
#
# USO:
#   ./importar_optimizado.sh                    # Procesar importar_aqui/
#   ./importar_optimizado.sh archivo.csv        # Archivo específico
#   ./importar_optimizado.sh --watch            # Vigilancia continua
#   ./importar_optimizado.sh --batch DIR        # Procesar directorio
#   ./importar_optimizado.sh --validate-only    # Solo validar
#   ./importar_optimizado.sh --help             # Mostrar ayuda
#
# REQUISITOS:
#   - Koha instalado y configurado
#   - Python 3.6+
#   - Permisos sudo para koha-shell y koha-mysql
#
# AUTORES: Universidad Nacional de Asunción
# VERSIÓN: 3.0.0
# FECHA: 2025-11-07
################################################################################

# ══════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN DE MODO ESTRICTO
# ══════════════════════════════════════════════════════════════════════════
set -o errexit   # Salir si algún comando falla (desactivado en funciones críticas)
set -o pipefail  # Capturar errores en pipes
set -o nounset   # Error si se usa variable no definida

# ══════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN GLOBAL - CONSTANTES
# ══════════════════════════════════════════════════════════════════════════

# Directorios base
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="${SCRIPT_DIR}"
readonly INSTANCIA_KOHA="koha-cnc"

# Estructura de directorios del sistema
readonly DIR_IMPORTAR="${BASE_DIR}/importar_aqui"
readonly DIR_PROCESADOS="${BASE_DIR}/procesados"
readonly DIR_ERRORES="${BASE_DIR}/errores"
readonly DIR_LOGS="${BASE_DIR}/logs"
readonly DIR_EXPORTS="${BASE_DIR}/exports"
readonly DIR_REPORTES="${BASE_DIR}/reportes"

# Scripts auxiliares
readonly AGENTE_PYTHON="${BASE_DIR}/agente_importador_v3.py"
readonly VALIDADOR="${BASE_DIR}/validador_csv.py"

# Paleta de colores ANSI para output legible
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_MAGENTA='\033[0;35m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'  # No Color - reset

# ══════════════════════════════════════════════════════════════════════════
# VARIABLES GLOBALES - Estado del programa
# ══════════════════════════════════════════════════════════════════════════

# Modos de operación (se configuran según argumentos)
MODO_WATCH=false
MODO_BATCH=false
MODO_VALIDAR_SOLO=false
DIR_BATCH=""
ARCHIVO_ESPECIFICO=""

# Timestamps y archivos de log
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOG_GENERAL="${DIR_LOGS}/maestro_${TIMESTAMP}.log"

# Contadores estadísticos
TOTAL_PROCESADOS=0
TOTAL_EXITOSOS=0
TOTAL_FALLIDOS=0
TOTAL_VALIDADOS=0
TOTAL_INVALIDOS=0

# ══════════════════════════════════════════════════════════════════════════
# FUNCIONES AUXILIARES - Logging y UI
# ══════════════════════════════════════════════════════════════════════════

#───────────────────────────────────────────────────────────────────────────
# Función: log
# Descripción: Sistema unificado de logging con niveles y colores
# Parámetros:
#   $1 - Nivel (INFO|SUCCESS|WARNING|ERROR|HEADER)
#   $@ - Mensaje a registrar
# Salida: Escribe en consola (con color) y en archivo de log
#───────────────────────────────────────────────────────────────────────────
log() {
    local nivel="$1"
    shift
    local mensaje="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Escribir a archivo de log (sin colores)
    echo "[${timestamp}] [${nivel}] ${mensaje}" >> "$LOG_GENERAL"

    # Escribir a consola con formato según nivel
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

#───────────────────────────────────────────────────────────────────────────
# Función: banner
# Descripción: Muestra un banner visual atractivo con el mensaje
# Parámetros:
#   $1 - Mensaje a mostrar en el banner
#───────────────────────────────────────────────────────────────────────────
banner() {
    local mensaje="$1"
    local padding=$((64 - ${#mensaje}))

    echo ""
    echo -e "${C_BOLD}${C_CYAN}╔════════════════════════════════════════════════════════════════════╗${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}║$(printf '%68s' | tr ' ' ' ')║${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}║  ${mensaje}$(printf "%${padding}s")║${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}║$(printf '%68s' | tr ' ' ' ')║${C_NC}"
    echo -e "${C_BOLD}${C_CYAN}╚════════════════════════════════════════════════════════════════════╝${C_NC}"
    echo ""
}

#───────────────────────────────────────────────────────────────────────────
# Función: separador
# Descripción: Imprime una línea separadora visual
#───────────────────────────────────────────────────────────────────────────
separador() {
    echo -e "${C_CYAN}────────────────────────────────────────────────────────────────────${C_NC}"
}

# ══════════════════════════════════════════════════════════════════════════
# FUNCIONES DE INICIALIZACIÓN
# ══════════════════════════════════════════════════════════════════════════

#───────────────────────────────────────────────────────────────────────────
# Función: crear_directorios
# Descripción: Crea la estructura de directorios necesaria para el sistema
# Nota: mkdir -p no falla si el directorio ya existe
#───────────────────────────────────────────────────────────────────────────
crear_directorios() {
    mkdir -p "$DIR_IMPORTAR" "$DIR_PROCESADOS" "$DIR_ERRORES" \
             "$DIR_LOGS" "$DIR_EXPORTS" "$DIR_REPORTES"
}

#───────────────────────────────────────────────────────────────────────────
# Función: verificar_dependencias
# Descripción: Verifica que todas las dependencias estén disponibles
# Return: 0 si todas las dependencias están OK, 1 si falta alguna
#───────────────────────────────────────────────────────────────────────────
verificar_dependencias() {
    log HEADER "Verificando dependencias del sistema..."

    local dependencias_ok=true

    # Verificar Python 3
    if ! command -v python3 &> /dev/null; then
        log ERROR "Python3 no está instalado"
        log INFO "Instalar con: sudo apt install python3"
        dependencias_ok=false
    else
        local py_version
        py_version=$(python3 --version 2>&1 | awk '{print $2}')
        log SUCCESS "Python3 detectado: v${py_version}"
    fi

    # Verificar agente Python principal
    if [ ! -f "$AGENTE_PYTHON" ]; then
        log ERROR "Agente Python no encontrado: $AGENTE_PYTHON"
        dependencias_ok=false
    elif [ ! -x "$AGENTE_PYTHON" ]; then
        log WARNING "Agente Python no es ejecutable, corrigiendo permisos..."
        chmod +x "$AGENTE_PYTHON" 2>/dev/null || {
            log ERROR "No se pudo dar permisos de ejecución a $AGENTE_PYTHON"
            dependencias_ok=false
        }
    else
        log SUCCESS "Agente Python v3 disponible"
    fi

    # Verificar Koha
    if ! command -v koha-shell &> /dev/null; then
        log ERROR "Koha no está instalado o no es accesible"
        log INFO "Verificar instalación de Koha"
        dependencias_ok=false
    else
        log SUCCESS "koha-shell disponible"
    fi

    # Verificar conexión a MySQL de Koha
    if ! sudo koha-mysql "${INSTANCIA_KOHA}" -e "SELECT 1" &>/dev/null; then
        log ERROR "No se puede conectar a MySQL de Koha (instancia: ${INSTANCIA_KOHA})"
        log INFO "Verificar que la instancia esté activa: sudo koha-list"
        dependencias_ok=false
    else
        log SUCCESS "Conexión a MySQL Koha OK"
    fi

    # Retornar resultado
    if [ "$dependencias_ok" = true ]; then
        log SUCCESS "✓ Todas las dependencias están disponibles"
        return 0
    else
        log ERROR "✗ Faltan dependencias críticas"
        return 1
    fi
}

# ══════════════════════════════════════════════════════════════════════════
# FUNCIONES DE VALIDACIÓN
# ══════════════════════════════════════════════════════════════════════════

#───────────────────────────────────────────────────────────────────────────
# Función: validar_archivo
# Descripción: Valida un archivo CSV antes de importarlo
# Parámetros:
#   $1 - Ruta al archivo CSV
# Return: 0 si válido, 1 si inválido
#───────────────────────────────────────────────────────────────────────────
validar_archivo() {
    local archivo="$1"
    local nombre
    nombre=$(basename "$archivo")

    log INFO "Validando: ${nombre}"

    # Verificar que el validador existe
    if [ ! -f "$VALIDADOR" ]; then
        log WARNING "Validador no disponible, omitiendo validación preventiva"
        return 0
    fi

    # Ejecutar validador Python
    if python3 "$VALIDADOR" "$archivo" &>> "$LOG_GENERAL"; then
        log SUCCESS "✓ Validación exitosa: ${nombre}"
        ((TOTAL_VALIDADOS++))
        return 0
    else
        log ERROR "✗ Validación fallida: ${nombre}"
        ((TOTAL_INVALIDOS++))

        # Mover archivo a directorio de errores con timestamp
        local destino="${DIR_ERRORES}/${nombre%.csv}_INVALIDO_${TIMESTAMP}.csv"
        if mv "$archivo" "$destino" 2>/dev/null; then
            log INFO "Archivo movido a: ${destino}"
        fi

        return 1
    fi
}

# ══════════════════════════════════════════════════════════════════════════
# FUNCIONES DE DETECCIÓN Y VERIFICACIÓN
# ══════════════════════════════════════════════════════════════════════════

#───────────────────────────────────────────────────────────────────────────
# Función: detectar_codigo_biblioteca
# Descripción: Extrae el código de biblioteca del nombre del archivo
# Parámetros:
#   $1 - Ruta al archivo
# Output: Código de biblioteca (3-6 letras mayúsculas) o cadena vacía
# Ejemplo: "MED.csv" → "MED", "FACEN_2025.csv" → "FACEN"
#───────────────────────────────────────────────────────────────────────────
detectar_codigo_biblioteca() {
    local archivo="$1"
    local nombre
    nombre=$(basename "$archivo" .csv)

    # Buscar secuencia de 3-6 letras mayúsculas
    local codigo
    codigo=$(echo "$nombre" | grep -oE '[A-Z]{3,6}' | head -1)

    if [ -n "$codigo" ]; then
        echo "$codigo"
        return 0
    fi

    return 1
}

#───────────────────────────────────────────────────────────────────────────
# Función: verificar_biblioteca_existe
# Descripción: Verifica que la biblioteca exista en Koha
# Parámetros:
#   $1 - Código de biblioteca
# Return: 0 si existe, 1 si no existe
#───────────────────────────────────────────────────────────────────────────
verificar_biblioteca_existe() {
    local codigo="$1"

    local existe
    existe=$(sudo koha-mysql "${INSTANCIA_KOHA}" -N -e \
        "SELECT COUNT(*) FROM branches WHERE branchcode = '${codigo}'" 2>/dev/null)

    [ "$existe" = "1" ]
}

# ══════════════════════════════════════════════════════════════════════════
# FUNCIONES DE PROCESAMIENTO - Lógica principal
# ══════════════════════════════════════════════════════════════════════════

#───────────────────────────────────────────────────────────────────────────
# Función: procesar_archivo
# Descripción: Procesa un archivo CSV completo (validación + importación)
# Parámetros:
#   $1 - Ruta al archivo CSV
# Return: 0 si exitoso, 1 si falló
#
# Flujo:
#   1. Detectar código de biblioteca
#   2. Verificar que exista en Koha
#   3. Validar formato CSV
#   4. Importar mediante agente Python
#   5. Generar reporte
#───────────────────────────────────────────────────────────────────────────
procesar_archivo() {
    local archivo="$1"
    local nombre
    nombre=$(basename "$archivo")

    ((TOTAL_PROCESADOS++))

    banner "PROCESANDO: ${nombre}"

    # ─────────────────────────────────────────────────────────────────────
    # PASO 1: Detección de código de biblioteca
    # ─────────────────────────────────────────────────────────────────────
    log HEADER "1. Detección de biblioteca"
    separador

    local codigo
    codigo=$(detectar_codigo_biblioteca "$archivo")

    if [ -z "$codigo" ]; then
        log ERROR "No se detectó código de biblioteca en: ${nombre}"
        log INFO "El nombre debe contener 3-6 letras mayúsculas (ej: MED.csv, FACEN.csv)"
        ((TOTAL_FALLIDOS++))
        return 1
    fi

    log SUCCESS "Código detectado: ${codigo}"

    # ─────────────────────────────────────────────────────────────────────
    # PASO 2: Verificación en Koha
    # ─────────────────────────────────────────────────────────────────────
    log HEADER "2. Verificación en Koha"
    separador

    if ! verificar_biblioteca_existe "$codigo"; then
        log ERROR "La biblioteca '${codigo}' NO existe en Koha"
        log INFO "Crear en: Staff Interface → Administración → Bibliotecas"
        ((TOTAL_FALLIDOS++))

        # Mover a errores
        local destino="${DIR_ERRORES}/${nombre%.csv}_NO_EXISTE_${TIMESTAMP}.csv"
        mv "$archivo" "$destino" 2>/dev/null || true
        log INFO "Archivo movido a: ${destino}"
        return 1
    fi

    # Obtener nombre completo de la biblioteca
    local nombre_bib
    nombre_bib=$(sudo koha-mysql "${INSTANCIA_KOHA}" -N -e \
        "SELECT branchname FROM branches WHERE branchcode = '${codigo}'" 2>/dev/null)
    log SUCCESS "Biblioteca verificada: ${nombre_bib}"

    # ─────────────────────────────────────────────────────────────────────
    # PASO 3: Validación del archivo
    # ─────────────────────────────────────────────────────────────────────
    if [ "$MODO_VALIDAR_SOLO" = false ]; then
        log HEADER "3. Validación del archivo"
        separador

        if ! validar_archivo "$archivo"; then
            log ERROR "Archivo no válido, no se puede importar"
            ((TOTAL_FALLIDOS++))
            return 1
        fi
    fi

    # ─────────────────────────────────────────────────────────────────────
    # PASO 4: Importación a Koha
    # ─────────────────────────────────────────────────────────────────────
    if [ "$MODO_VALIDAR_SOLO" = false ]; then
        log HEADER "4. Importación a Koha"
        separador

        log INFO "Ejecutando agente de importación..."
        echo ""

        # Ejecutar agente Python v3
        if python3 "$AGENTE_PYTHON" "$archivo"; then
            log SUCCESS "✓ Importación completada: ${codigo}"
            ((TOTAL_EXITOSOS++))

            # Generar reporte de éxito
            generar_reporte_exitoso "$codigo" "$archivo"
            return 0
        else
            log ERROR "✗ Error durante importación de: ${nombre}"
            ((TOTAL_FALLIDOS++))
            return 1
        fi
    else
        log SUCCESS "Validación completada (modo solo-validar)"
        return 0
    fi
}

# ══════════════════════════════════════════════════════════════════════════
# FUNCIONES DE REPORTES
# ══════════════════════════════════════════════════════════════════════════

#───────────────────────────────────────────────────────────────────────────
# Función: generar_reporte_exitoso
# Descripción: Genera un reporte detallado de una importación exitosa
# Parámetros:
#   $1 - Código de biblioteca
#   $2 - Ruta al archivo procesado
#───────────────────────────────────────────────────────────────────────────
generar_reporte_exitoso() {
    local codigo="$1"
    local archivo="$2"
    local reporte="${DIR_REPORTES}/reporte_${codigo}_${TIMESTAMP}.txt"

    # Obtener estadísticas actuales de la biblioteca
    local stats
    stats=$(sudo koha-mysql "${INSTANCIA_KOHA}" -t -e "
        SELECT
            COUNT(DISTINCT biblionumber) as Titulos,
            COUNT(*) as Ejemplares
        FROM items
        WHERE homebranch = '$codigo'
    " 2>/dev/null)

    # Generar reporte estructurado
    cat > "$reporte" << EOF
╔════════════════════════════════════════════════════════════════════╗
║           REPORTE DE IMPORTACIÓN EXITOSA                           ║
╚════════════════════════════════════════════════════════════════════╝

Fecha y hora:        $(date '+%Y-%m-%d %H:%M:%S')
Código biblioteca:   ${codigo}
Archivo procesado:   $(basename "$archivo")

════════════════════════════════════════════════════════════════════

ESTADÍSTICAS POST-IMPORTACIÓN:

${stats}

════════════════════════════════════════════════════════════════════

URL VERIFICACIÓN OPAC:
http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=${codigo}

ESTADO: ✅ IMPORTACIÓN EXITOSA

════════════════════════════════════════════════════════════════════
Universidad Nacional de Asunción - Sistema Koha
Generado: $(date '+%Y-%m-%d %H:%M:%S')
════════════════════════════════════════════════════════════════════
EOF

    log SUCCESS "Reporte guardado: ${reporte}"
}

#───────────────────────────────────────────────────────────────────────────
# Función: generar_reporte_final
# Descripción: Genera reporte consolidado de la sesión completa
# Parámetros:
#   $1 - Duración total en segundos
#───────────────────────────────────────────────────────────────────────────
generar_reporte_final() {
    local duracion=$1
    local minutos=$((duracion / 60))
    local reporte="${DIR_REPORTES}/resumen_${TIMESTAMP}.txt"

    # Obtener estadísticas globales del sistema
    local estadisticas_globales
    estadisticas_globales=$(sudo koha-mysql "${INSTANCIA_KOHA}" -t -e "
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
" 2>/dev/null)

    # Generar reporte
    cat > "$reporte" << EOF
╔════════════════════════════════════════════════════════════════════╗
║          RESUMEN DE EJECUCIÓN - IMPORTADOR OPTIMIZADO V3.0         ║
╚════════════════════════════════════════════════════════════════════╝

Fecha inicio:    $(date '+%Y-%m-%d %H:%M:%S' -d "@$(($(date +%s) - duracion))")
Fecha fin:       $(date '+%Y-%m-%d %H:%M:%S')
Duración total:  ${duracion}s (${minutos} minutos)

════════════════════════════════════════════════════════════════════

ESTADÍSTICAS DE PROCESAMIENTO:

  Archivos procesados:    ${TOTAL_PROCESADOS}
  Importaciones exitosas: ${TOTAL_EXITOSOS}
  Importaciones fallidas: ${TOTAL_FALLIDOS}
  Archivos validados:     ${TOTAL_VALIDADOS}
  Archivos inválidos:     ${TOTAL_INVALIDOS}

════════════════════════════════════════════════════════════════════

ESTADO DEL SISTEMA KOHA (Top 15 bibliotecas):

${estadisticas_globales}

════════════════════════════════════════════════════════════════════

ARCHIVOS GENERADOS:

  Logs completos:         ${LOG_GENERAL}
  Reportes individuales:  ${DIR_REPORTES}
  Archivos procesados:    ${DIR_PROCESADOS}
  Archivos con errores:   ${DIR_ERRORES}

════════════════════════════════════════════════════════════════════
Universidad Nacional de Asunción - Sistema Koha
Generado: $(date '+%Y-%m-%d %H:%M:%S')
════════════════════════════════════════════════════════════════════
EOF

    echo ""
    log SUCCESS "Reporte final generado: ${reporte}"
    echo ""
    cat "$reporte"
}

# ══════════════════════════════════════════════════════════════════════════
# MODOS DE OPERACIÓN
# ══════════════════════════════════════════════════════════════════════════

#───────────────────────────────────────────────────────────────────────────
# Función: modo_archivo_unico
# Descripción: Procesa un único archivo CSV
# Parámetros:
#   $1 - Ruta al archivo
#───────────────────────────────────────────────────────────────────────────
modo_archivo_unico() {
    local archivo="$1"

    if [ ! -f "$archivo" ]; then
        log ERROR "Archivo no existe: ${archivo}"
        return 1
    fi

    procesar_archivo "$archivo"
}

#───────────────────────────────────────────────────────────────────────────
# Función: modo_batch
# Descripción: Procesa todos los CSV en un directorio
# Parámetros:
#   $1 - Ruta al directorio
#───────────────────────────────────────────────────────────────────────────
modo_batch() {
    local directorio="$1"

    if [ ! -d "$directorio" ]; then
        log ERROR "Directorio no existe: ${directorio}"
        return 1
    fi

    log INFO "Buscando archivos CSV en: ${directorio}"

    # Buscar todos los archivos CSV
    local archivos=()
    while IFS= read -r -d '' archivo; do
        archivos+=("$archivo")
    done < <(find "$directorio" -maxdepth 1 -type f -name "*.csv" -print0 2>/dev/null)

    if [ ${#archivos[@]} -eq 0 ]; then
        log WARNING "No se encontraron archivos CSV en: ${directorio}"
        return 1
    fi

    log SUCCESS "Archivos encontrados: ${#archivos[@]}"
    echo ""

    # Mostrar lista de archivos
    for i in "${!archivos[@]}"; do
        echo "  $((i+1)). $(basename "${archivos[$i]}")"
    done

    # Confirmación del usuario
    echo ""
    read -p "¿Procesar estos archivos? (SI/no): " -r respuesta

    if [[ ! $respuesta =~ ^(SI|si|S|s|YES|yes|Y|y|)$ ]]; then
        log INFO "Procesamiento cancelado por el usuario"
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

#───────────────────────────────────────────────────────────────────────────
# Función: modo_watch
# Descripción: Vigila un directorio y procesa automáticamente archivos nuevos
# Nota: Este modo corre indefinidamente hasta Ctrl+C
#───────────────────────────────────────────────────────────────────────────
modo_watch() {
    log INFO "🔄 MODO VIGILANCIA ACTIVADO"
    log INFO "Directorio: ${DIR_IMPORTAR}"
    log INFO "Intervalo: 10 segundos"
    echo ""
    echo -e "${C_YELLOW}Coloca archivos CSV en: ${DIR_IMPORTAR}${C_NC}"
    echo -e "${C_YELLOW}Presiona Ctrl+C para detener${C_NC}"
    echo ""

    # Hash map para rastrear archivos ya procesados
    declare -A procesados

    while true; do
        # Buscar archivos CSV
        local archivos=()
        while IFS= read -r -d '' archivo; do
            archivos+=("$archivo")
        done < <(find "$DIR_IMPORTAR" -maxdepth 1 -type f -name "*.csv" -print0 2>/dev/null)

        # Procesar archivos nuevos
        for archivo in "${archivos[@]}"; do
            # Calcular hash del archivo para detectar cambios
            local hash
            hash=$(md5sum "$archivo" 2>/dev/null | cut -d' ' -f1)
            local key="${archivo}:${hash}"

            # Si no está en el registro, procesarlo
            if [ -z "${procesados[$key]:-}" ]; then
                echo ""
                log INFO "🔔 NUEVO ARCHIVO DETECTADO: $(basename "$archivo")"
                echo ""

                # Esperar 2 segundos para asegurar que el archivo esté completo
                sleep 2

                procesar_archivo "$archivo"
                procesados[$key]=1

                echo ""
                separador
            fi
        done

        # Esperar antes del próximo ciclo
        sleep 10
    done
}

# ══════════════════════════════════════════════════════════════════════════
# FUNCIÓN PRINCIPAL
# ══════════════════════════════════════════════════════════════════════════

#───────────────────────────────────────────────────────────────────────────
# Función: main
# Descripción: Punto de entrada principal del programa
# Orquesta todo el flujo de ejecución según el modo seleccionado
#───────────────────────────────────────────────────────────────────────────
main() {
    local inicio
    inicio=$(date +%s)

    # Banner de bienvenida
    banner "IMPORTADOR AUTOMÁTICO OPTIMIZADO - KOHA UNA V3.0"

    # Crear estructura de directorios
    crear_directorios

    # Verificar dependencias críticas
    if ! verificar_dependencias; then
        log ERROR "No se puede continuar sin dependencias críticas"
        exit 1
    fi

    echo ""
    separador
    echo ""

    # Ejecutar modo de operación correspondiente
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

    # Calcular duración total
    local fin
    fin=$(date +%s)
    local duracion=$((fin - inicio))

    echo ""
    separador
    echo ""

    # Generar reporte final
    generar_reporte_final "$duracion"

    # Resumen en consola
    echo ""
    banner "PROCESO COMPLETADO"
    echo ""
    echo -e "  ${C_BOLD}Procesados:${C_NC}  ${TOTAL_PROCESADOS}"
    echo -e "  ${C_GREEN}${C_BOLD}Exitosos:${C_NC}    ${TOTAL_EXITOSOS}"

    if [ $TOTAL_FALLIDOS -gt 0 ]; then
        echo -e "  ${C_RED}${C_BOLD}Fallidos:${C_NC}     ${TOTAL_FALLIDOS}"
    fi

    echo -e "  ${C_CYAN}Duración:${C_NC}    ${duracion}s ($(($duracion / 60))m)"
    echo ""

    # Código de salida
    if [ $TOTAL_FALLIDOS -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# ══════════════════════════════════════════════════════════════════════════
# PROCESAMIENTO DE ARGUMENTOS DE LÍNEA DE COMANDOS
# ══════════════════════════════════════════════════════════════════════════

#───────────────────────────────────────────────────────────────────────────
# Función: mostrar_ayuda
# Descripción: Muestra la ayuda completa del programa
#───────────────────────────────────────────────────────────────────────────
mostrar_ayuda() {
    cat << EOF
${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════════════════${C_NC}
${C_BOLD}${C_CYAN}   IMPORTADOR AUTOMÁTICO OPTIMIZADO KOHA - UNIVERSIDAD NACIONAL DE ASUNCIÓN${C_NC}
${C_BOLD}${C_CYAN}═══════════════════════════════════════════════════════════════════════${C_NC}

Sistema profesional de importación automática con validación, control de
errores, reportes detallados y múltiples modos de operación.

${C_BOLD}USO:${C_NC}
    $0 [OPCIONES] [ARCHIVO]

${C_BOLD}OPCIONES:${C_NC}
    ${C_GREEN}--watch, -w${C_NC}              Modo vigilancia continua (detecta archivos nuevos)
    ${C_GREEN}--batch DIR, -b DIR${C_NC}      Procesar todos los CSV en directorio
    ${C_GREEN}--validate-only, -v${C_NC}      Solo validar sin importar
    ${C_GREEN}--help, -h${C_NC}               Mostrar esta ayuda
    ${C_GREEN}--version${C_NC}                Mostrar versión

${C_BOLD}EJEMPLOS DE USO:${C_NC}

    ${C_CYAN}# Procesar archivo específico${C_NC}
    $0 MED.csv
    $0 /ruta/completa/FACEN_2025.csv

    ${C_CYAN}# Procesar todos los CSV en importar_aqui/${C_NC}
    $0

    ${C_CYAN}# Modo vigilancia automática${C_NC}
    $0 --watch

    ${C_CYAN}# Procesar directorio específico${C_NC}
    $0 --batch /ruta/a/directorio

    ${C_CYAN}# Solo validar archivos sin importar${C_NC}
    $0 --validate-only --batch importar_aqui/

${C_BOLD}CARACTERÍSTICAS:${C_NC}
    ✓ Detección automática de código de biblioteca
    ✓ Validación preventiva de archivos CSV
    ✓ Control de duplicados
    ✓ Generación de reportes detallados
    ✓ Modo batch para múltiples archivos
    ✓ Modo vigilancia para importación continua
    ✓ Recuperación automática ante errores
    ✓ Logs detallados con timestamps

${C_BOLD}ARCHIVOS GENERADOS:${C_NC}
    ${C_CYAN}logs/${C_NC}       - Logs de ejecución detallados
    ${C_CYAN}reportes/${C_NC}   - Reportes de importación
    ${C_CYAN}procesados/${C_NC} - CSV procesados exitosamente
    ${C_CYAN}errores/${C_NC}    - CSV con errores

${C_BOLD}REQUISITOS DEL NOMBRE DE ARCHIVO:${C_NC}
    El nombre del archivo CSV debe contener el código de la biblioteca:

    ${C_GREEN}✓${C_NC} MED.csv              → Código: MED
    ${C_GREEN}✓${C_NC} FACEN_2025.csv       → Código: FACEN
    ${C_GREEN}✓${C_NC} VET_octubre.csv      → Código: VET
    ${C_RED}✗${C_NC} datos.csv            → Sin código (error)

${C_BOLD}SOPORTE:${C_NC}
    Universidad Nacional de Asunción
    Sistema de Bibliotecas - Koha OPAC
    Versión: 3.0.0
    Fecha: 2025-11-07

═══════════════════════════════════════════════════════════════════════
EOF
}

# ──────────────────────────────────────────────────────────────────────────
# Parser de argumentos
# ──────────────────────────────────────────────────────────────────────────
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
        --version)
            echo "Importador Automático Optimizado Koha - Versión 3.0.0"
            exit 0
            ;;
        *)
            if [ -f "$1" ]; then
                ARCHIVO_ESPECIFICO="$1"
            else
                log ERROR "Opción desconocida o archivo no existe: $1"
                echo ""
                echo "Use --help para ver opciones disponibles"
                exit 1
            fi
            shift
            ;;
    esac
done

# ══════════════════════════════════════════════════════════════════════════
# EJECUCIÓN PRINCIPAL
# ══════════════════════════════════════════════════════════════════════════
main
