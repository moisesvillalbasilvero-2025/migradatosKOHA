#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
# VALIDADOR DE CALIDAD DE CSV ANTES DE IMPORTAR
# ════════════════════════════════════════════════════════════════════════════
# Versión: 2.0 - Con prevención de duplicados
# Uso: ./validar_antes_importar.sh archivo.csv
# ════════════════════════════════════════════════════════════════════════════

set -e

# Cargar funciones de prevención de duplicados
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/prevenir_duplicados.sh"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuración
CSV_FILE="$1"
REPORT_FILE="/tmp/validacion_$(date +%Y%m%d_%H%M%S).txt"

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIONES
# ═══════════════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# ═══════════════════════════════════════════════════════════════════════════
# VALIDACIONES
# ═══════════════════════════════════════════════════════════════════════════

if [ -z "$CSV_FILE" ]; then
    echo -e "${RED}Error: Debe proporcionar el archivo CSV${NC}"
    echo "Uso: $0 archivo.csv"
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}Error: El archivo $CSV_FILE no existe${NC}"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════
# INICIO DE VALIDACIÓN
# ═══════════════════════════════════════════════════════════════════════════

clear
print_header "VALIDADOR DE CALIDAD CSV - KOHA UNA"

echo -e "${CYAN}Archivo:${NC} $CSV_FILE"
echo -e "${CYAN}Fecha:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Iniciar reporte
{
    echo "════════════════════════════════════════════════════════════════"
    echo "  REPORTE DE VALIDACIÓN CSV - KOHA UNA"
    echo "════════════════════════════════════════════════════════════════"
    echo "Archivo: $CSV_FILE"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
} > "$REPORT_FILE"

# ═══════════════════════════════════════════════════════════════════════════
# 1. VALIDACIONES BÁSICAS
# ═══════════════════════════════════════════════════════════════════════════

print_header "1. VALIDACIONES BÁSICAS"

# Contar líneas totales
TOTAL_LINES=$(wc -l < "$CSV_FILE")
TOTAL_RECORDS=$((TOTAL_LINES - 1))  # Menos encabezado

print_info "Total de líneas: $TOTAL_LINES"
print_info "Total de registros: $TOTAL_RECORDS"
echo ""

# Verificar encabezado
HEADER=$(head -1 "$CSV_FILE")
EXPECTED_HEADER="title,author,isbn,publisher,publicationyear,copyrightdate,pages,itemtype,dewey,itemcallnumber,barcode,homebranch,holdingbranch,location,price,replacementprice,notforloan,ccode,materials,abstract,subject,notes"

if [ "$HEADER" = "$EXPECTED_HEADER" ]; then
    print_success "Encabezado correcto"
else
    print_warning "Encabezado no coincide con el esperado"
    echo -e "${YELLOW}Esperado:${NC}"
    echo "$EXPECTED_HEADER"
    echo -e "${YELLOW}Encontrado:${NC}"
    echo "$HEADER"
    echo ""
fi

# Verificar líneas vacías
EMPTY_LINES=$(grep -c '^$' "$CSV_FILE" || true)
if [ "$EMPTY_LINES" -eq 0 ]; then
    print_success "No hay líneas vacías"
else
    print_warning "Se encontraron $EMPTY_LINES líneas vacías"
fi

# ═══════════════════════════════════════════════════════════════════════════
# 2. VALIDACIÓN DE CAMPOS OBLIGATORIOS
# ═══════════════════════════════════════════════════════════════════════════

print_header "2. CAMPOS OBLIGATORIOS"

# Función para contar campos vacíos en una columna
count_empty_field() {
    local field_num=$1
    tail -n +2 "$CSV_FILE" | awk -F',' -v col="$field_num" '{
        gsub(/"/, "", $col);
        if ($col == "" || $col ~ /^[[:space:]]*$/) count++
    } END {print count+0}'
}

# title (columna 1)
EMPTY_TITLE=$(count_empty_field 1)
if [ "$EMPTY_TITLE" -eq 0 ]; then
    print_success "Todos los registros tienen TÍTULO"
else
    print_error "$EMPTY_TITLE registros SIN título (campo obligatorio)"
fi

# barcode (columna 11)
EMPTY_BARCODE=$(count_empty_field 11)
if [ "$EMPTY_BARCODE" -eq 0 ]; then
    print_success "Todos los registros tienen CÓDIGO DE BARRAS"
else
    print_error "$EMPTY_BARCODE registros SIN código de barras (campo obligatorio)"
fi

# homebranch (columna 12)
EMPTY_BRANCH=$(count_empty_field 12)
if [ "$EMPTY_BRANCH" -eq 0 ]; then
    print_success "Todos los registros tienen BIBLIOTECA"
else
    print_error "$EMPTY_BRANCH registros SIN biblioteca (campo obligatorio)"
fi

# itemtype (columna 8)
EMPTY_TYPE=$(count_empty_field 8)
if [ "$EMPTY_TYPE" -eq 0 ]; then
    print_success "Todos los registros tienen TIPO DE MATERIAL"
else
    print_error "$EMPTY_TYPE registros SIN tipo de material (campo obligatorio)"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# 3. VALIDACIÓN DE CÓDIGOS DE BARRAS ÚNICOS
# ═══════════════════════════════════════════════════════════════════════════

print_header "3. CÓDIGOS DE BARRAS ÚNICOS"

# Extraer barcodes y buscar duplicados
DUPLICATES=$(tail -n +2 "$CSV_FILE" | awk -F',' '{
    gsub(/"/, "", $11);
    if ($11 != "") print $11
}' | sort | uniq -d)

if [ -z "$DUPLICATES" ]; then
    print_success "No hay códigos de barras duplicados"
else
    DUPLICATE_COUNT=$(echo "$DUPLICATES" | wc -l)
    print_error "Se encontraron $DUPLICATE_COUNT códigos de barras duplicados:"
    echo "$DUPLICATES" | head -10
    if [ "$DUPLICATE_COUNT" -gt 10 ]; then
        echo -e "${YELLOW}... y $((DUPLICATE_COUNT - 10)) más${NC}"
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# 4. CALIDAD DE DATOS (CAMPOS RECOMENDADOS)
# ═══════════════════════════════════════════════════════════════════════════

print_header "4. CALIDAD DE DATOS"

# author (columna 2)
EMPTY_AUTHOR=$(count_empty_field 2)
AUTHOR_PERCENT=$(( (TOTAL_RECORDS - EMPTY_AUTHOR) * 100 / TOTAL_RECORDS ))
if [ "$AUTHOR_PERCENT" -ge 80 ]; then
    print_success "AUTOR: $AUTHOR_PERCENT% ($((TOTAL_RECORDS - EMPTY_AUTHOR))/$TOTAL_RECORDS)"
else
    print_warning "AUTOR: $AUTHOR_PERCENT% ($((TOTAL_RECORDS - EMPTY_AUTHOR))/$TOTAL_RECORDS) - Recomendado >80%"
fi

# isbn (columna 3)
EMPTY_ISBN=$(count_empty_field 3)
ISBN_PERCENT=$(( (TOTAL_RECORDS - EMPTY_ISBN) * 100 / TOTAL_RECORDS ))
if [ "$ISBN_PERCENT" -ge 70 ]; then
    print_success "ISBN: $ISBN_PERCENT% ($((TOTAL_RECORDS - EMPTY_ISBN))/$TOTAL_RECORDS)"
else
    print_warning "ISBN: $ISBN_PERCENT% ($((TOTAL_RECORDS - EMPTY_ISBN))/$TOTAL_RECORDS) - Recomendado >70%"
fi

# itemcallnumber (columna 10)
EMPTY_CALLNUM=$(count_empty_field 10)
CALLNUM_PERCENT=$(( (TOTAL_RECORDS - EMPTY_CALLNUM) * 100 / TOTAL_RECORDS ))
if [ "$CALLNUM_PERCENT" -ge 85 ]; then
    print_success "SIGNATURA: $CALLNUM_PERCENT% ($((TOTAL_RECORDS - EMPTY_CALLNUM))/$TOTAL_RECORDS)"
else
    print_warning "SIGNATURA: $CALLNUM_PERCENT% ($((TOTAL_RECORDS - EMPTY_CALLNUM))/$TOTAL_RECORDS) - Recomendado >85%"
fi

# abstract (columna 20)
EMPTY_ABSTRACT=$(count_empty_field 20)
ABSTRACT_PERCENT=$(( (TOTAL_RECORDS - EMPTY_ABSTRACT) * 100 / TOTAL_RECORDS ))
if [ "$ABSTRACT_PERCENT" -ge 60 ]; then
    print_success "RESUMEN: $ABSTRACT_PERCENT% ($((TOTAL_RECORDS - EMPTY_ABSTRACT))/$TOTAL_RECORDS)"
elif [ "$ABSTRACT_PERCENT" -ge 30 ]; then
    print_warning "RESUMEN: $ABSTRACT_PERCENT% ($((TOTAL_RECORDS - EMPTY_ABSTRACT))/$TOTAL_RECORDS) - Óptimo >60%"
else
    print_error "RESUMEN: $ABSTRACT_PERCENT% ($((TOTAL_RECORDS - EMPTY_ABSTRACT))/$TOTAL_RECORDS) - Muy bajo, mejorar"
fi

# subject (columna 21)
EMPTY_SUBJECT=$(count_empty_field 21)
SUBJECT_PERCENT=$(( (TOTAL_RECORDS - EMPTY_SUBJECT) * 100 / TOTAL_RECORDS ))
if [ "$SUBJECT_PERCENT" -ge 70 ]; then
    print_success "MATERIAS: $SUBJECT_PERCENT% ($((TOTAL_RECORDS - EMPTY_SUBJECT))/$TOTAL_RECORDS)"
elif [ "$SUBJECT_PERCENT" -ge 40 ]; then
    print_warning "MATERIAS: $SUBJECT_PERCENT% ($((TOTAL_RECORDS - EMPTY_SUBJECT))/$TOTAL_RECORDS) - Óptimo >70%"
else
    print_error "MATERIAS: $SUBJECT_PERCENT% ($((TOTAL_RECORDS - EMPTY_SUBJECT))/$TOTAL_RECORDS) - Muy bajo, mejorar"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# 5. CLASIFICACIÓN POR NIVEL DE CALIDAD
# ═══════════════════════════════════════════════════════════════════════════

print_header "5. CLASIFICACIÓN POR NIVEL"

# Calcular nivel de cada registro
tail -n +2 "$CSV_FILE" | awk -F',' '
BEGIN {
    basico = 0
    estandar = 0
    completo = 0
    premium = 0
}
{
    # Limpiar comillas
    for (i=1; i<=NF; i++) gsub(/"/, "", $i)

    # Nivel BÁSICO: title, barcode, homebranch, itemtype
    if ($1 != "" && $11 != "" && $12 != "" && $8 != "") {
        # Nivel COMPLETO: + author, isbn, abstract, subject, callnumber
        if ($2 != "" && $3 != "" && $20 != "" && $21 != "" && $10 != "") {
            completo++
        }
        # Nivel ESTÁNDAR: + author, isbn, callnumber
        else if ($2 != "" && $3 != "" && $10 != "") {
            estandar++
        }
        else {
            basico++
        }
    }
}
END {
    total = basico + estandar + completo
    if (total > 0) {
        print "BÁSICO=" basico
        print "ESTÁNDAR=" estandar
        print "COMPLETO=" completo
        print "TOTAL=" total
    }
}
' > /tmp/niveles_$$.txt

# Leer resultados
source /tmp/niveles_$$.txt
rm /tmp/niveles_$$.txt

NIVEL_TOTAL=$((BASICO + ESTANDAR + COMPLETO))

if [ "$NIVEL_TOTAL" -gt 0 ]; then
    BASICO_PERCENT=$((BASICO * 100 / NIVEL_TOTAL))
    ESTANDAR_PERCENT=$((ESTANDAR * 100 / NIVEL_TOTAL))
    COMPLETO_PERCENT=$((COMPLETO * 100 / NIVEL_TOTAL))

    echo -e "${CYAN}⭐ BÁSICO:${NC}    $BASICO registros ($BASICO_PERCENT%)"
    echo -e "${BLUE}⭐⭐ ESTÁNDAR:${NC}  $ESTANDAR registros ($ESTANDAR_PERCENT%)"
    echo -e "${GREEN}⭐⭐⭐ COMPLETO:${NC} $COMPLETO registros ($COMPLETO_PERCENT%)"

    echo ""

    if [ "$COMPLETO_PERCENT" -ge 60 ]; then
        print_success "Excelente calidad de catálogo!"
    elif [ "$COMPLETO_PERCENT" -ge 40 ]; then
        print_success "Buena calidad, seguir mejorando"
    elif [ "$ESTANDAR_PERCENT" -ge 60 ]; then
        print_warning "Calidad aceptable, agregar más resúmenes y materias"
    else
        print_warning "Calidad básica, se recomienda enriquecer datos"
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# 6. VALIDACIÓN DE CÓDIGOS
# ═══════════════════════════════════════════════════════════════════════════

print_header "6. VALIDACIÓN DE CÓDIGOS"

# Códigos de biblioteca válidos
VALID_BRANCHES="ING ODO QUI ARQ DER MED FCA CENTRAL"

INVALID_BRANCHES=$(tail -n +2 "$CSV_FILE" | awk -F',' -v valid="$VALID_BRANCHES" '{
    gsub(/"/, "", $12);
    if ($12 != "") {
        found = 0
        split(valid, arr, " ")
        for (i in arr) {
            if ($12 == arr[i]) found = 1
        }
        if (!found) print $12
    }
}' | sort -u)

if [ -z "$INVALID_BRANCHES" ]; then
    print_success "Todos los códigos de biblioteca son válidos"
else
    print_warning "Códigos de biblioteca no reconocidos:"
    echo "$INVALID_BRANCHES"
fi

# Tipos de material válidos
VALID_TYPES="BK DVD CD MAG NEWS MAP SCORE REF EBOOK"

INVALID_TYPES=$(tail -n +2 "$CSV_FILE" | awk -F',' -v valid="$VALID_TYPES" '{
    gsub(/"/, "", $8);
    if ($8 != "") {
        found = 0
        split(valid, arr, " ")
        for (i in arr) {
            if ($8 == arr[i]) found = 1
        }
        if (!found) print $8
    }
}' | sort -u)

if [ -z "$INVALID_TYPES" ]; then
    print_success "Todos los tipos de material son válidos"
else
    print_warning "Tipos de material no reconocidos:"
    echo "$INVALID_TYPES"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# 7. VERIFICACIÓN DE DUPLICADOS vs BASE DE DATOS
# ═══════════════════════════════════════════════════════════════════════════

print_header "7. DUPLICADOS vs BASE DE DATOS"

log_info "Verificando duplicados contra base de datos..."
echo ""

# Verificar duplicados en el CSV mismo
log_info "7.1 - Duplicados DENTRO del CSV:"
verificar_duplicados_en_csv "$CSV_FILE" "/tmp/dup_csv_$$" > /dev/null 2>&1 || true

# Mostrar resultado
if grep -q "✗ ENCONTRADOS:" "/tmp/dup_csv_$$" 2>/dev/null; then
    print_error "Hay códigos de barras duplicados DENTRO del CSV"
    cat "/tmp/dup_csv_$$" | grep -A 20 "Códigos de barras duplicados"
else
    print_success "No hay duplicados internos en el CSV"
fi

echo ""

# Verificar duplicados CSV vs BD
log_info "7.2 - Duplicados CSV vs BASE DE DATOS:"
verificar_duplicados_csv_vs_bd "$CSV_FILE" "/tmp/dup_bd_$$"
DUP_RESULT=$?

# Interpretar resultado
if [ $DUP_RESULT -eq 1 ]; then
    print_error "CRÍTICO: Hay códigos de barras que ya existen en la BD"
    SCORE=$((SCORE - 30))  # Penalización severa
elif [ $DUP_RESULT -eq 2 ]; then
    print_warning "Hay ISBNs/Títulos que ya existen (pueden ser nuevos ejemplares)"
    SCORE=$((SCORE - 5))   # Penalización menor
else
    print_success "No se encontraron duplicados con la base de datos"
fi

# Limpiar archivos temporales
rm -f "/tmp/dup_csv_$$" "/tmp/dup_bd_$$" 2>/dev/null || true

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# 8. RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════════════════

print_header "RESUMEN Y RECOMENDACIONES"

# Calcular puntuación de calidad (0-100)
SCORE=0

# Campos obligatorios completos (40 puntos)
[ "$EMPTY_TITLE" -eq 0 ] && SCORE=$((SCORE + 10))
[ "$EMPTY_BARCODE" -eq 0 ] && SCORE=$((SCORE + 10))
[ "$EMPTY_BRANCH" -eq 0 ] && SCORE=$((SCORE + 10))
[ "$EMPTY_TYPE" -eq 0 ] && SCORE=$((SCORE + 10))

# Calidad de datos (40 puntos)
SCORE=$((SCORE + AUTHOR_PERCENT * 10 / 100))
SCORE=$((SCORE + ISBN_PERCENT * 10 / 100))
SCORE=$((SCORE + ABSTRACT_PERCENT * 10 / 100))
SCORE=$((SCORE + SUBJECT_PERCENT * 10 / 100))

# Sin duplicados (20 puntos)
[ -z "$DUPLICATES" ] && SCORE=$((SCORE + 20))

echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}  PUNTUACIÓN DE CALIDAD: $SCORE/100${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

if [ "$SCORE" -ge 85 ]; then
    echo -e "${GREEN}✓ EXCELENTE${NC} - Catálogo de alta calidad"
    echo "  ➤ Listo para importar sin problemas"
elif [ "$SCORE" -ge 70 ]; then
    echo -e "${GREEN}✓ BUENO${NC} - Catálogo con calidad aceptable"
    echo "  ➤ Se puede importar, pero se recomienda mejorar campos opcionales"
elif [ "$SCORE" -ge 50 ]; then
    echo -e "${YELLOW}⚠ REGULAR${NC} - Catálogo funcional pero mejorable"
    echo "  ➤ Completar campos obligatorios faltantes antes de importar"
else
    echo -e "${RED}✗ BAJO${NC} - Catálogo con problemas"
    echo "  ➤ Corregir errores críticos antes de importar"
fi

echo ""
echo -e "${CYAN}RECOMENDACIONES:${NC}"

# Recomendaciones específicas
[ "$EMPTY_TITLE" -gt 0 ] && echo "  • Completar títulos faltantes ($EMPTY_TITLE registros)"
[ "$EMPTY_AUTHOR" -gt 50 ] && echo "  • Agregar autores ($EMPTY_AUTHOR registros sin autor)"
[ "$EMPTY_ISBN" -gt 50 ] && echo "  • Buscar ISBNs faltantes ($EMPTY_ISBN registros)"
[ "$ABSTRACT_PERCENT" -lt 60 ] && echo "  • Agregar resúmenes para mejorar OPAC (actual: $ABSTRACT_PERCENT%)"
[ "$SUBJECT_PERCENT" -lt 70 ] && echo "  • Asignar materias para mejor búsqueda (actual: $SUBJECT_PERCENT%)"
[ -n "$DUPLICATES" ] && echo "  • Eliminar códigos de barras duplicados"
[ -n "$INVALID_BRANCHES" ] && echo "  • Verificar códigos de biblioteca inválidos"
[ $DUP_RESULT -eq 1 ] && echo "  • ⚠️ CRÍTICO: Corregir códigos de barras que ya existen en BD"
[ $DUP_RESULT -eq 2 ] && echo "  • ℹ️ INFO: Hay ISBNs/Títulos existentes, el sistema agregará ejemplares automáticamente"

echo ""
echo -e "${CYAN}Reporte completo guardado en:${NC} $REPORT_FILE"
echo ""

# Preguntar si desea continuar con la importación
if [ "$SCORE" -ge 70 ]; then
    echo -e "${GREEN}¿Desea proceder con la importación? (s/n)${NC}"
    read -r RESPUESTA
    if [ "$RESPUESTA" = "s" ] || [ "$RESPUESTA" = "S" ]; then
        echo -e "${GREEN}Ejecute:${NC} ./importar_biblioteca.sh $(basename $CSV_FILE .csv)"
    fi
else
    echo -e "${YELLOW}Se recomienda mejorar el archivo antes de importar.${NC}"
fi

echo ""
