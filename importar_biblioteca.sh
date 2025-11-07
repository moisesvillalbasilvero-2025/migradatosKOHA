#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
# Script Optimizado de Importación Bibliográfica - Koha UNA
# ════════════════════════════════════════════════════════════════════════════
# Versión: 3.0 - Con prevención de duplicados
# Fecha: 25 de Octubre de 2025
# Uso: ./importar_biblioteca.sh CODIGO_BIBLIOTECA
# ════════════════════════════════════════════════════════════════════════════

set -e  # Detener en caso de error

# Cargar funciones de prevención de duplicados
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/prevenir_duplicados.sh"

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════════════════

CODIGO=$1
BASE_DIR="/home/mvillalba/migradatos"
CSV_PATH="${BASE_DIR}/importar_aqui/${CODIGO}.csv"
EXPORT_DIR="${BASE_DIR}/exports"
LOG_DIR="${BASE_DIR}/logs"
ERROR_DIR="${BASE_DIR}/errores"
FECHA=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="${LOG_DIR}/import_${CODIGO}_${FECHA}.log"

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIONES
# ═══════════════════════════════════════════════════════════════════════════

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

mostrar_header() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  IMPORTACIÓN AUTOMÁTICA DE BIBLIOTECA: $CODIGO"
    echo "  Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "════════════════════════════════════════════════════════════════"
    echo "" | tee "$LOG_FILE"
}

mostrar_footer() {
    echo ""
    echo "════════════════════════════════════════════════════════════════"
    echo "  ✅ IMPORTACIÓN COMPLETADA EXITOSAMENTE"
    echo "  Log: $LOG_FILE"
    echo "════════════════════════════════════════════════════════════════"
    echo ""
}

verificar_requisitos() {
    log_info "Verificando requisitos previos..."

    # Verificar que se proporcionó código
    if [ -z "$CODIGO" ]; then
        log_error "Debe especificar el código de biblioteca"
        echo ""
        echo "Uso: $0 CODIGO_BIBLIOTECA"
        echo ""
        echo "Ejemplos:"
        echo "  $0 BC      # Biblioteca Central"
        echo "  $0 FACEN   # Facultad de Ciencias Exactas"
        echo "  $0 MED     # Medicina"
        echo ""
        exit 1
    fi

    # Verificar que existe el archivo CSV
    if [ ! -f "$CSV_PATH" ]; then
        log_error "No existe el archivo: $CSV_PATH"
        echo ""
        echo "Asegúrate de copiar el archivo CSV a:"
        echo "  /home/mvillalba/migradatos/importar_aqui/${CODIGO}.csv"
        echo ""
        exit 1
    fi

    # Verificar biblioteca en Koha
    BIBLIOTECA_EXISTE=$(sudo koha-mysql koha-cnc -N -e \
        "SELECT COUNT(*) FROM branches WHERE branchcode = '$CODIGO'" 2>/dev/null || echo "0")

    if [ "$BIBLIOTECA_EXISTE" = "0" ]; then
        log_error "El código '$CODIGO' no existe en Koha"
        echo ""
        echo "Bibliotecas disponibles:"
        sudo koha-mysql koha-cnc -e "SELECT branchcode, branchname FROM branches LIMIT 10"
        echo ""
        exit 1
    fi

    # Verificar espacio en disco (mínimo 1GB)
    ESPACIO_LIBRE=$(df -BG "$BASE_DIR" | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$ESPACIO_LIBRE" -lt 1 ]; then
        log_warning "Espacio en disco bajo: ${ESPACIO_LIBRE}GB"
    fi

    # Verificar servicios
    if ! systemctl is-active --quiet mysql; then
        log_error "MySQL no está activo"
        exit 1
    fi

    log_success "Requisitos verificados"
}

contar_registros_csv() {
    log_info "Analizando archivo CSV..."

    TOTAL_CSV=$(($(wc -l < "$CSV_PATH") - 1))
    TAMANO_MB=$(du -m "$CSV_PATH" | cut -f1)

    log_info "  Archivo: $(basename $CSV_PATH)"
    log_info "  Tamaño: ${TAMANO_MB}MB"
    log_info "  Registros: $TOTAL_CSV"

    # Verificar formato
    PRIMERA_LINEA=$(head -1 "$CSV_PATH")
    if [[ ! $PRIMERA_LINEA =~ "codbiblio" ]]; then
        log_warning "El archivo CSV podría no tener el formato correcto"
    fi
}

verificar_duplicados_antes_importar() {
    log_info "Verificando duplicados antes de importar..."

    # Verificar duplicados en el CSV
    log_info "  1. Verificando duplicados internos en CSV..."
    verificar_duplicados_en_csv "$CSV_PATH" "/tmp/dup_internal_$$.log"
    if [ $? -ne 0 ]; then
        log_error "Se encontraron códigos de barras duplicados en el CSV"
        cat "/tmp/dup_internal_$$.log"
        rm -f "/tmp/dup_internal_$$.log"
        exit 1
    fi
    log_success "  No hay duplicados internos"

    # Verificar duplicados contra BD
    log_info "  2. Verificando duplicados contra base de datos..."
    verificar_duplicados_csv_vs_bd "$CSV_PATH" "/tmp/dup_bd_$$.log"
    DUP_RESULT=$?

    if [ $DUP_RESULT -eq 1 ]; then
        log_error "CRÍTICO: Hay códigos de barras que ya existen en la BD"
        cat "/tmp/dup_bd_$$.log" | tail -20
        rm -f "/tmp/dup_bd_$$.log" "/tmp/dup_internal_$$.log"

        echo ""
        log_error "No se puede continuar. Corrige los códigos de barras duplicados."
        exit 1
    elif [ $DUP_RESULT -eq 2 ]; then
        log_warning "Se encontraron ISBNs/Títulos existentes"
        log_info "  El sistema agregará ejemplares automáticamente (no creará duplicados)"
        echo ""
        echo -ne "${YELLOW}¿Continuar con importación inteligente? (s/n): ${NC}"
        read -r RESPUESTA
        if [ "$RESPUESTA" != "s" ] && [ "$RESPUESTA" != "S" ]; then
            log_info "Importación cancelada por el usuario"
            rm -f "/tmp/dup_bd_$$.log" "/tmp/dup_internal_$$.log"
            exit 0
        fi
    else
        log_success "  No se encontraron duplicados"
    fi

    # Limpiar logs temporales
    rm -f "/tmp/dup_bd_$$.log" "/tmp/dup_internal_$$.log"
}

generar_marcxml() {
    log_info "Generando archivos MARCXML..."

    cd "$EXPORT_DIR"

    # Limpiar archivos XML anteriores de esta biblioteca
    if ls ${CODIGO}_*_marcxml*.xml 1> /dev/null 2>&1; then
        log_warning "Eliminando archivos XML anteriores..."
        rm ${CODIGO}_*_marcxml*.xml
    fi

    # Generar MARCXML
    python3 ${BASE_DIR}/scripts/opac_exportar.py \
        -i "$CSV_PATH" \
        --codbiblio "$CODIGO" \
        --loc-default "$CODIGO" \
        --stream \
        --split-by 1000 2>&1 | tee -a "$LOG_FILE"

    # Verificar generación
    ARCHIVOS_XML=$(ls -1 ${CODIGO}_*_marcxml*.xml 2>/dev/null | wc -l)

    if [ $ARCHIVOS_XML -eq 0 ]; then
        log_error "No se generaron archivos MARCXML"
        mv "$CSV_PATH" "${ERROR_DIR}/${CODIGO}_ERROR_MARCXML_${FECHA}.csv"
        log_error "CSV movido a: ${ERROR_DIR}/"
        exit 1
    fi

    log_success "Archivos XML generados: $ARCHIVOS_XML"
}

verificar_marcxml() {
    log_info "Verificando archivos MARCXML..."

    TOTAL_XML=$(grep -c '<ns0:record' ${EXPORT_DIR}/${CODIGO}_*_marcxml*.xml | \
                awk -F: '{sum+=$2} END {print sum}')

    log_info "  Total registros en XML: $TOTAL_XML"

    # Comparar con CSV
    DIFERENCIA=$((TOTAL_CSV - TOTAL_XML))
    if [ $DIFERENCIA -ne 0 ]; then
        log_warning "Diferencia entre CSV ($TOTAL_CSV) y XML ($TOTAL_XML): $DIFERENCIA registros"
    fi

    # Verificar integridad de primer archivo
    PRIMER_XML=$(ls ${EXPORT_DIR}/${CODIGO}_*_marcxml*.xml | head -1)
    if ! grep -q '</collection>' "$PRIMER_XML"; then
        log_warning "El archivo XML podría estar incompleto"
    fi
}

consultar_estado_actual() {
    log_info "Consultando estado actual en base de datos..."

    ITEMS_ANTES=$(sudo koha-mysql koha-cnc -N -e \
        "SELECT COUNT(DISTINCT biblionumber) FROM items WHERE homebranch = '$CODIGO'" 2>/dev/null || echo "0")

    EJEMPLARES_ANTES=$(sudo koha-mysql koha-cnc -N -e \
        "SELECT COUNT(*) FROM items WHERE homebranch = '$CODIGO'" 2>/dev/null || echo "0")

    log_info "  Títulos existentes: $ITEMS_ANTES"
    log_info "  Ejemplares existentes: $EJEMPLARES_ANTES"

    if [ "$ITEMS_ANTES" != "0" ]; then
        log_warning "Ya existen registros. Se agregarán nuevos títulos."
    fi
}

importar_a_koha() {
    log_info "Iniciando importación a Koha..."

    ARCHIVOS=(${EXPORT_DIR}/${CODIGO}_*_marcxml*.xml)
    TOTAL_ARCHIVOS=${#ARCHIVOS[@]}
    CONTADOR=0

    for xml in "${ARCHIVOS[@]}"; do
        CONTADOR=$((CONTADOR + 1))
        NOMBRE=$(basename "$xml")

        log_info "  [$CONTADOR/$TOTAL_ARCHIVOS] Importando: $NOMBRE"

        # Importar con bulkmarcimport
        sudo koha-shell koha-cnc -c \
            "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
             -b -m MARCXML -file $xml -commit 1000" 2>&1 | \
            tee -a "$LOG_FILE" | tail -3

        # Verificar éxito
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            log_error "Error importando $NOMBRE"
            exit 1
        fi
    done

    log_success "Importación completada"
}

verificar_resultado() {
    log_info "Verificando resultado de importación..."

    ITEMS_DESPUES=$(sudo koha-mysql koha-cnc -N -e \
        "SELECT COUNT(DISTINCT biblionumber) FROM items WHERE homebranch = '$CODIGO'" 2>/dev/null || echo "0")

    EJEMPLARES_DESPUES=$(sudo koha-mysql koha-cnc -N -e \
        "SELECT COUNT(*) FROM items WHERE homebranch = '$CODIGO'" 2>/dev/null || echo "0")

    IMPORTADOS=$((ITEMS_DESPUES - ITEMS_ANTES))
    NUEVOS_EJEMPLARES=$((EJEMPLARES_DESPUES - EJEMPLARES_ANTES))

    echo ""
    log_success "═══ RESUMEN DE IMPORTACIÓN ═══"
    log_info "  Títulos antes:      $ITEMS_ANTES"
    log_info "  Títulos después:    $ITEMS_DESPUES"
    log_success "  Títulos importados: $IMPORTADOS"
    echo ""
    log_info "  Ejemplares antes:      $EJEMPLARES_ANTES"
    log_info "  Ejemplares después:    $EJEMPLARES_DESPUES"
    log_success "  Ejemplares importados: $NUEVOS_EJEMPLARES"
    echo ""

    # Mostrar algunos registros importados
    if [ $IMPORTADOS -gt 0 ]; then
        log_info "Últimos registros importados:"
        sudo koha-mysql koha-cnc -t -e \
            "SELECT biblio.biblionumber, LEFT(biblio.title, 50) as titulo, items.barcode
             FROM biblio
             JOIN items ON biblio.biblionumber = items.biblionumber
             WHERE items.homebranch = '$CODIGO'
             ORDER BY biblio.biblionumber DESC
             LIMIT 5" | tee -a "$LOG_FILE"
    fi
}

reindexar_zebra() {
    log_info "Reindexando Zebra..."

    echo ""
    read -p "¿Desea reindexar ahora? (s/N): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Ss]$ ]]; then
        log_info "Iniciando reindexación..."
        sudo koha-rebuild-zebra -v koha-cnc 2>&1 | tee -a "$LOG_FILE"
        log_success "Reindexación completada"
    else
        log_warning "Reindexación omitida"
        log_warning "No olvides ejecutar: sudo koha-rebuild-zebra -v koha-cnc"
    fi
}

guardar_resumen() {
    cat >> "$LOG_FILE" <<RESUMEN

════════════════════════════════════════════════════════════════
RESUMEN DE IMPORTACIÓN
════════════════════════════════════════════════════════════════
Fecha:                  $(date '+%Y-%m-%d %H:%M:%S')
Biblioteca:             $CODIGO
Archivo CSV:            $CSV_PATH
Registros CSV:          $TOTAL_CSV
Archivos XML:           ${#ARCHIVOS[@]}
Registros XML:          $TOTAL_XML
Títulos antes:          $ITEMS_ANTES
Títulos después:        $ITEMS_DESPUES
Títulos importados:     $IMPORTADOS
Ejemplares antes:       $EJEMPLARES_ANTES
Ejemplares después:     $EJEMPLARES_DESPUES
Ejemplares importados:  $NUEVOS_EJEMPLARES
Estado:                 ÉXITO ✅
════════════════════════════════════════════════════════════════
RESUMEN

    log_success "Resumen guardado en: $LOG_FILE"
}

limpiar_temporales() {
    log_info "Limpiando archivos temporales..."

    # Mover CSV procesado
    PROCESADOS_DIR="${BASE_DIR}/procesados"
    mkdir -p "$PROCESADOS_DIR"
    mv "$CSV_PATH" "${PROCESADOS_DIR}/${CODIGO}_${FECHA}.csv"
    log_success "CSV movido a: ${PROCESADOS_DIR}/"

    # Opcional: eliminar XMLs
    echo ""
    read -p "¿Desea eliminar los archivos XML temporales? (s/N): " -n 1 -r
    echo ""

    if [[ $REPLY =~ ^[Ss]$ ]]; then
        rm ${EXPORT_DIR}/${CODIGO}_*_marcxml*.xml
        log_success "Archivos XML eliminados"
    else
        log_info "Archivos XML conservados en: $EXPORT_DIR"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# PROGRAMA PRINCIPAL
# ═══════════════════════════════════════════════════════════════════════════

# Crear directorios si no existen
mkdir -p "$LOG_DIR" "$ERROR_DIR" "${BASE_DIR}/procesados"

# Mostrar header
mostrar_header

# Ejecutar proceso
verificar_requisitos
contar_registros_csv
verificar_duplicados_antes_importar
generar_marcxml
verificar_marcxml
consultar_estado_actual
importar_a_koha
verificar_resultado
guardar_resumen
reindexar_zebra
limpiar_temporales

# Mostrar footer
mostrar_footer

# URL del OPAC
echo ""
log_info "Verificar en OPAC:"
echo "  http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=$CODIGO"
echo ""

exit 0
