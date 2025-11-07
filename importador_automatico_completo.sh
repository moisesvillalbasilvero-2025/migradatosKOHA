#!/bin/bash
################################################################################
# IMPORTADOR AUTOMÁTICO COMPLETO - KOHA UNA
################################################################################
# Importa archivos CSV a Koha de forma completamente automatizada y transparente
#
# USO:
#   ./importador_automatico_completo.sh archivo.csv
#   ./importador_automatico_completo.sh --all    # Importa todos los CSV en importar_aqui/
#
# CARACTERÍSTICAS:
#   ✓ Detección automática de biblioteca
#   ✓ Generación de MARCXML con parámetros corregidos
#   ✓ Limpieza automática de namespaces
#   ✓ Importación con items (ejemplares)
#   ✓ Reindexación automática
#   ✓ Logs detallados
#   ✓ Movimiento automático de archivos procesados
#
# VERSIÓN: 3.0
# FECHA: 2025-11-04
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DIR_TRABAJO="/home/mvillalba/migradatos"
readonly DIR_IMPORTAR="${DIR_TRABAJO}/importar_aqui"
readonly DIR_EXPORTS="${DIR_TRABAJO}/exports"
readonly DIR_LOGS="${DIR_TRABAJO}/logs"
readonly DIR_PROCESADOS="${DIR_TRABAJO}/procesados"
readonly DIR_ERRORES="${DIR_TRABAJO}/errores"

readonly INSTANCIA_KOHA="koha-cnc"
readonly LOC_DEFAULT="SALA"
readonly COMMIT_SIZE="500"
readonly SPLIT_SIZE="2000"

# Colores
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# Variables globales
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${DIR_LOGS}/importacion_${TIMESTAMP}.log"
REINDEX_AL_FINAL=false

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${C_CYAN}ℹ ${1}${C_NC}" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${C_GREEN}✓ ${1}${C_NC}" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${C_YELLOW}⚠ ${1}${C_NC}" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${C_RED}✗ ${1}${C_NC}" | tee -a "$LOG_FILE"
}

separador() {
    echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
}

banner() {
    echo -e "${C_BOLD}${C_CYAN}"
    echo "═══════════════════════════════════════════════════════════════"
    echo "  IMPORTADOR AUTOMÁTICO COMPLETO - KOHA UNA"
    echo "═══════════════════════════════════════════════════════════════"
    echo -e "${C_NC}"
}

# ============================================================================
# FUNCIONES DE VALIDACIÓN
# ============================================================================

verificar_dependencias() {
    local deps=("python3" "sed" "koha-shell" "koha-mysql")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Dependencia no encontrada: $dep"
            exit 1
        fi
    done
}

crear_directorios() {
    mkdir -p "$DIR_EXPORTS" "$DIR_LOGS" "$DIR_PROCESADOS" "$DIR_ERRORES"
}

# ============================================================================
# FUNCIÓN PRINCIPAL DE IMPORTACIÓN
# ============================================================================

importar_csv() {
    local archivo_csv="$1"
    local nombre_archivo=$(basename "$archivo_csv")
    local codigo_biblioteca=$(basename "$archivo_csv" .csv)

    separador
    log_info "Procesando: ${nombre_archivo}"
    separador

    # 1. Verificar que el archivo existe
    if [ ! -f "$archivo_csv" ]; then
        log_error "Archivo no encontrado: $archivo_csv"
        return 1
    fi

    # 2. Verificar biblioteca en Koha
    log_info "Verificando biblioteca: $codigo_biblioteca"
    local nombre_biblioteca=$(sudo koha-mysql "$INSTANCIA_KOHA" -se \
        "SELECT branchname FROM branches WHERE branchcode='$codigo_biblioteca';" 2>/dev/null)

    if [ -z "$nombre_biblioteca" ]; then
        log_error "Biblioteca '$codigo_biblioteca' no existe en Koha"
        mv "$archivo_csv" "$DIR_ERRORES/${nombre_archivo%.csv}_NO_EXISTE_${TIMESTAMP}.csv"
        return 1
    fi

    log_success "Biblioteca: $nombre_biblioteca"

    # 3. Contar registros
    local total_registros=$(($(wc -l < "$archivo_csv") - 1))
    log_info "Total de registros a procesar: $total_registros"

    # 4. Generar MARCXML
    log_info "Generando MARCXML..."
    cd "$DIR_TRABAJO"

    if ! python3 scripts/opac_exportar.py \
        --input "$archivo_csv" \
        --codbiblio "$codigo_biblioteca" \
        --loc-default "$LOC_DEFAULT" \
        --stream \
        --split-by "$SPLIT_SIZE" >> "$LOG_FILE" 2>&1; then
        log_error "Error al generar MARCXML"
        mv "$archivo_csv" "$DIR_ERRORES/${nombre_archivo%.csv}_ERROR_MARCXML_${TIMESTAMP}.csv"
        return 1
    fi

    # 5. Buscar archivos XML generados (pueden estar en DIR_TRABAJO o DIR_EXPORTS)
    local archivos_xml=()
    for xml in "${codigo_biblioteca}_"*"_marcxml_"*.xml; do
        if [ -f "$xml" ]; then
            archivos_xml+=("$xml")
        fi
    done

    # Si no hay en DIR_TRABAJO, buscar en exports
    if [ ${#archivos_xml[@]} -eq 0 ]; then
        cd "$DIR_EXPORTS"
        for xml in "${codigo_biblioteca}_"*"_marcxml_"*.xml; do
            if [ -f "$xml" ]; then
                archivos_xml+=("$xml")
            fi
        done
        cd "$DIR_TRABAJO"
    fi

    if [ ${#archivos_xml[@]} -eq 0 ]; then
        log_error "No se generaron archivos MARCXML"
        mv "$archivo_csv" "$DIR_ERRORES/${nombre_archivo%.csv}_SIN_XML_${TIMESTAMP}.csv"
        return 1
    fi

    log_success "Generados ${#archivos_xml[@]} archivo(s) MARCXML"

    # 6. Procesar cada archivo XML
    local items_importados=0

    for xml in "${archivos_xml[@]}"; do
        local xml_basename=$(basename "$xml")
        local xml_path="$xml"

        # Mover a exports si no está ahí
        if [[ "$xml" != "$DIR_EXPORTS/"* ]]; then
            mv "$xml" "$DIR_EXPORTS/"
            xml_path="$DIR_EXPORTS/$xml_basename"
        fi

        log_info "Procesando: $xml_basename"

        # 6a. Limpiar namespace
        local xml_limpio="${xml_path%.xml}_limpio.xml"
        sed 's/<ns0:record/<record/g; s/<\/ns0:record/<\/record/g; s/xmlns:ns0=/xmlns=/g' \
            "$xml_path" > "$xml_limpio"

        # Verificar que se limpió correctamente
        local registros_xml=$(grep -c "<record" "$xml_limpio" 2>/dev/null || echo "0")
        log_info "Registros en XML limpio: $registros_xml"

        # 6b. Importar a Koha con items
        log_info "Importando a Koha..."

        local import_output=$(sudo koha-shell "$INSTANCIA_KOHA" -c \
            "/usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
            -m MARCXML \
            -file $xml_limpio \
            -commit $COMMIT_SIZE" 2>&1)

        echo "$import_output" >> "$LOG_FILE"

        if echo "$import_output" | grep -q "MARC records done"; then
            local records_imported=$(echo "$import_output" | grep "MARC records done" | tail -1 | awk '{print $1}')
            log_success "Importados: $records_imported registros MARC"
            items_importados=$((items_importados + registros_xml))
        else
            log_warning "Posible error en importación, revisar log"
        fi
    done

    # 7. Verificar items importados
    log_info "Verificando items en Koha..."
    local items_en_koha=$(sudo koha-mysql "$INSTANCIA_KOHA" -se \
        "SELECT COUNT(*) FROM items WHERE homebranch='$codigo_biblioteca';" 2>/dev/null)

    log_success "Items en biblioteca $codigo_biblioteca: $items_en_koha"

    # 8. Mover archivo procesado
    mv "$archivo_csv" "$DIR_PROCESADOS/${nombre_archivo%.csv}_OK_${TIMESTAMP}.csv"
    log_success "Archivo movido a: procesados/"

    # Marcar para reindexación
    REINDEX_AL_FINAL=true

    return 0
}

# ============================================================================
# FUNCIÓN DE REINDEXACIÓN
# ============================================================================

reindexar_koha() {
    if [ "$REINDEX_AL_FINAL" = true ]; then
        separador
        log_info "Reindexando Koha Zebra..."
        if sudo koha-rebuild-zebra -v -full "$INSTANCIA_KOHA" >> "$LOG_FILE" 2>&1; then
            log_success "Reindexación completada"
        else
            log_warning "Posibles advertencias en reindexación, revisar log"
        fi
    fi
}

# ============================================================================
# FUNCIÓN DE REPORTE FINAL
# ============================================================================

generar_reporte() {
    separador
    echo -e "${C_BOLD}${C_GREEN}REPORTE FINAL${C_NC}"
    separador

    # Contar archivos procesados
    local procesados=$(ls -1 "$DIR_PROCESADOS"/*_OK_${TIMESTAMP}.csv 2>/dev/null | wc -l)
    local errores=$(ls -1 "$DIR_ERRORES"/*_${TIMESTAMP}.csv 2>/dev/null | wc -l)

    log_info "Archivos procesados exitosamente: $procesados"
    log_info "Archivos con errores: $errores"

    # Mostrar totales del sistema
    log_info "Estado del sistema Koha:"
    sudo koha-mysql "$INSTANCIA_KOHA" -e \
        "SELECT 'Biblios totales' as Metrica, COUNT(*) as Total FROM biblio
         UNION ALL
         SELECT 'Items totales', COUNT(*) FROM items;" 2>/dev/null | tee -a "$LOG_FILE"

    # Reporte de libros por biblioteca (bibliotecas procesadas en esta sesión)
    if [ $procesados -gt 0 ]; then
        echo ""
        log_info "Libros por Biblioteca (importados en esta sesión):"

        # Obtener códigos de bibliotecas procesadas
        local codigos_procesados=$(ls -1 "$DIR_PROCESADOS"/*_OK_${TIMESTAMP}.csv 2>/dev/null | \
            sed 's|.*/||; s/_OK_.*//g' | tr '\n' ',' | sed 's/,$//')

        if [ -n "$codigos_procesados" ]; then
            sudo koha-mysql "$INSTANCIA_KOHA" -e \
                "SELECT
                    b.branchcode AS 'Código',
                    LEFT(b.branchname, 50) AS 'Biblioteca',
                    COUNT(i.itemnumber) AS 'Items'
                FROM branches b
                LEFT JOIN items i ON b.branchcode = i.homebranch
                WHERE b.branchcode IN ($(echo $codigos_procesados | sed 's/,/","/g; s/^/"/; s/$/"/'))
                GROUP BY b.branchcode, b.branchname
                ORDER BY COUNT(i.itemnumber) DESC;" 2>/dev/null | tee -a "$LOG_FILE"
        fi
    fi

    # Confirmar que archivos fueron movidos de importar_aqui/
    echo ""
    log_info "Archivos movidos de importar_aqui/ a procesados/"
    ls -1 "$DIR_PROCESADOS"/*_OK_${TIMESTAMP}.csv 2>/dev/null | while read archivo; do
        echo "  ✓ $(basename $archivo)" | tee -a "$LOG_FILE"
    done

    # Verificar si quedan archivos en importar_aqui/
    local archivos_restantes=$(ls -1 "$DIR_IMPORTAR"/*.csv 2>/dev/null | wc -l)
    if [ $archivos_restantes -gt 0 ]; then
        echo ""
        log_warning "Archivos restantes en importar_aqui/: $archivos_restantes"
        log_info "Estos archivos no fueron procesados en esta ejecución:"
        ls -1 "$DIR_IMPORTAR"/*.csv 2>/dev/null | while read archivo; do
            echo "  • $(basename $archivo)" | tee -a "$LOG_FILE"
        done
    else
        echo ""
        log_success "Directorio importar_aqui/ vacío - Todos los archivos fueron procesados"
    fi

    separador
    log_success "Log guardado en: $LOG_FILE"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

main() {
    banner

    # Verificar dependencias
    verificar_dependencias
    crear_directorios

    log "Iniciando importación automática"
    log "Timestamp: $TIMESTAMP"

    # Procesar argumentos
    if [ $# -eq 0 ]; then
        echo "Uso: $0 archivo.csv"
        echo "      $0 --all    # Procesa todos los CSV en importar_aqui/"
        exit 1
    fi

    local archivos_a_procesar=()

    if [ "$1" = "--all" ]; then
        log_info "Modo: Procesar todos los archivos CSV"
        while IFS= read -r -d '' archivo; do
            archivos_a_procesar+=("$archivo")
        done < <(find "$DIR_IMPORTAR" -maxdepth 1 -name "*.csv" -print0)

        if [ ${#archivos_a_procesar[@]} -eq 0 ]; then
            log_warning "No se encontraron archivos CSV en $DIR_IMPORTAR"
            exit 0
        fi
    else
        archivos_a_procesar=("$@")
    fi

    # Procesar cada archivo
    local exitosos=0
    local fallidos=0

    for archivo in "${archivos_a_procesar[@]}"; do
        if importar_csv "$archivo"; then
            exitosos=$((exitosos + 1))
        else
            fallidos=$((fallidos + 1))
        fi
    done

    # Reindexar si hubo importaciones exitosas
    reindexar_koha

    # Generar reporte final
    generar_reporte

    # Resultado final
    separador
    if [ $fallidos -eq 0 ]; then
        echo -e "${C_BOLD}${C_GREEN}✓ Importación completada exitosamente${C_NC}"
        echo -e "${C_GREEN}  Archivos procesados: $exitosos${C_NC}"
    else
        echo -e "${C_BOLD}${C_YELLOW}⚠ Importación completada con advertencias${C_NC}"
        echo -e "${C_GREEN}  Exitosos: $exitosos${C_NC}"
        echo -e "${C_RED}  Fallidos: $fallidos${C_NC}"
    fi
    separador

    return $([ $fallidos -eq 0 ] && echo 0 || echo 1)
}

# ============================================================================
# EJECUCIÓN
# ============================================================================

main "$@"
