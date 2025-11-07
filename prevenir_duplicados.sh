#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
# SISTEMA DE PREVENCIÓN DE DUPLICADOS - KOHA UNA
# ════════════════════════════════════════════════════════════════════════════
# Versión: 1.0
# Fecha: 25 de Octubre de 2025
# Uso: source prevenir_duplicados.sh  (se incluye en otros scripts)
#
# Funciones para detectar y prevenir duplicados antes de importar
# ════════════════════════════════════════════════════════════════════════════

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIÓN 1: Verificar si un código de barras ya existe en la BD
# ═══════════════════════════════════════════════════════════════════════════
barcode_existe_en_bd() {
    local barcode=$1

    local count=$(koha-mysql koha-cnc -sN -e "
        SELECT COUNT(*)
        FROM items
        WHERE barcode='$barcode'
    " 2>/dev/null || echo "0")

    [ "$count" -gt 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIÓN 2: Verificar si un ISBN ya existe en la BD
# ═══════════════════════════════════════════════════════════════════════════
isbn_existe_en_bd() {
    local isbn=$1

    # Limpiar ISBN (remover guiones y espacios)
    isbn=$(echo "$isbn" | tr -d '- ')

    local count=$(koha-mysql koha-cnc -sN -e "
        SELECT COUNT(*)
        FROM biblioitems
        WHERE REPLACE(REPLACE(isbn, '-', ''), ' ', '') = '$isbn'
    " 2>/dev/null || echo "0")

    [ "$count" -gt 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIÓN 3: Verificar si título + autor ya existe en la BD
# ═══════════════════════════════════════════════════════════════════════════
titulo_autor_existe_en_bd() {
    local titulo=$1
    local autor=$2

    local count=$(koha-mysql koha-cnc -sN -e "
        SELECT COUNT(*)
        FROM biblio
        WHERE LOWER(title) = LOWER('$titulo')
        AND LOWER(author) = LOWER('$autor')
    " 2>/dev/null || echo "0")

    [ "$count" -gt 0 ]
}

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIÓN 4: Obtener biblionumber existente por ISBN
# ═══════════════════════════════════════════════════════════════════════════
obtener_biblionumber_por_isbn() {
    local isbn=$1

    # Limpiar ISBN
    isbn=$(echo "$isbn" | tr -d '- ')

    koha-mysql koha-cnc -sN -e "
        SELECT biblionumber
        FROM biblioitems
        WHERE REPLACE(REPLACE(isbn, '-', ''), ' ', '') = '$isbn'
        LIMIT 1
    " 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIÓN 5: Obtener biblionumber existente por título + autor
# ═══════════════════════════════════════════════════════════════════════════
obtener_biblionumber_por_titulo_autor() {
    local titulo=$1
    local autor=$2

    koha-mysql koha-cnc -sN -e "
        SELECT biblionumber
        FROM biblio
        WHERE LOWER(title) = LOWER('$titulo')
        AND LOWER(author) = LOWER('$autor')
        LIMIT 1
    " 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIÓN 6: Verificar duplicados en CSV antes de importar
# ═══════════════════════════════════════════════════════════════════════════
verificar_duplicados_en_csv() {
    local csv_file=$1
    local log_file="${2:-/tmp/duplicados_csv.log}"

    echo "════════════════════════════════════════════════════════════" > "$log_file"
    echo "  VERIFICACIÓN DE DUPLICADOS EN CSV" >> "$log_file"
    echo "════════════════════════════════════════════════════════════" >> "$log_file"
    echo "Archivo: $csv_file" >> "$log_file"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')" >> "$log_file"
    echo "" >> "$log_file"

    # Verificar duplicados de barcode en el CSV
    echo "1. Códigos de barras duplicados en CSV:" >> "$log_file"
    local duplicados_barcode=$(tail -n +2 "$csv_file" | cut -d',' -f11 | sed 's/"//g' | sort | uniq -d)

    if [ -z "$duplicados_barcode" ]; then
        echo "   ✓ No hay códigos de barras duplicados" >> "$log_file"
    else
        echo "   ✗ ENCONTRADOS:" >> "$log_file"
        echo "$duplicados_barcode" | while read -r barcode; do
            echo "     - $barcode" >> "$log_file"
        done
        echo "" >> "$log_file"
        return 1
    fi

    echo "" >> "$log_file"

    # Verificar duplicados de ISBN en el CSV
    echo "2. ISBNs duplicados en CSV:" >> "$log_file"
    local duplicados_isbn=$(tail -n +2 "$csv_file" | cut -d',' -f3 | sed 's/"//g' | grep -v '^$' | sort | uniq -d)

    if [ -z "$duplicados_isbn" ]; then
        echo "   ✓ No hay ISBNs duplicados" >> "$log_file"
    else
        echo "   ⚠ ENCONTRADOS (pueden ser ediciones diferentes):" >> "$log_file"
        echo "$duplicados_isbn" | while read -r isbn; do
            echo "     - $isbn" >> "$log_file"
        done
    fi

    echo "" >> "$log_file"
    cat "$log_file"

    return 0
}

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIÓN 7: Verificar si registros del CSV ya existen en BD
# ═══════════════════════════════════════════════════════════════════════════
verificar_duplicados_csv_vs_bd() {
    local csv_file=$1
    local log_file="${2:-/tmp/duplicados_bd.log}"

    echo "════════════════════════════════════════════════════════════" > "$log_file"
    echo "  VERIFICACIÓN: CSV vs BASE DE DATOS" >> "$log_file"
    echo "════════════════════════════════════════════════════════════" >> "$log_file"
    echo "Archivo: $csv_file" >> "$log_file"
    echo "Fecha: $(date '+%Y-%m-%d %H:%M:%S')" >> "$log_file"
    echo "" >> "$log_file"

    local total_registros=0
    local duplicados_barcode=0
    local duplicados_isbn=0
    local duplicados_titulo=0

    echo "Analizando registros..." >> "$log_file"
    echo "" >> "$log_file"

    # Analizar cada línea del CSV
    tail -n +2 "$csv_file" | while IFS=, read -r title author isbn publisher year copyright pages itemtype dewey callnum barcode branch holding location price replace notforloan ccode materials abstract subject notes; do
        total_registros=$((total_registros + 1))

        # Limpiar comillas
        barcode=$(echo "$barcode" | sed 's/"//g')
        isbn=$(echo "$isbn" | sed 's/"//g')
        title=$(echo "$title" | sed 's/"//g')
        author=$(echo "$author" | sed 's/"//g')

        # Verificar barcode
        if [ -n "$barcode" ] && barcode_existe_en_bd "$barcode"; then
            echo "✗ DUPLICADO - Barcode: $barcode" >> "$log_file"
            echo "  Título: $title" >> "$log_file"
            echo "" >> "$log_file"
            duplicados_barcode=$((duplicados_barcode + 1))
        fi

        # Verificar ISBN
        if [ -n "$isbn" ] && isbn_existe_en_bd "$isbn"; then
            echo "⚠ POSIBLE DUPLICADO - ISBN: $isbn" >> "$log_file"
            echo "  Título: $title" >> "$log_file"
            echo "  (Puede ser nuevo ejemplar de libro existente)" >> "$log_file"
            echo "" >> "$log_file"
            duplicados_isbn=$((duplicados_isbn + 1))
        fi

        # Verificar título + autor
        if [ -n "$title" ] && [ -n "$author" ] && titulo_autor_existe_en_bd "$title" "$author"; then
            echo "⚠ POSIBLE DUPLICADO - Título+Autor:" >> "$log_file"
            echo "  $title / $author" >> "$log_file"
            echo "" >> "$log_file"
            duplicados_titulo=$((duplicados_titulo + 1))
        fi
    done

    echo "════════════════════════════════════════════════════════════" >> "$log_file"
    echo "  RESUMEN" >> "$log_file"
    echo "════════════════════════════════════════════════════════════" >> "$log_file"
    echo "Total registros analizados: $total_registros" >> "$log_file"
    echo "Códigos de barras duplicados: $duplicados_barcode" >> "$log_file"
    echo "ISBNs que ya existen: $duplicados_isbn" >> "$log_file"
    echo "Títulos+Autores que ya existen: $duplicados_titulo" >> "$log_file"
    echo "" >> "$log_file"

    if [ "$duplicados_barcode" -gt 0 ]; then
        echo "❌ CRÍTICO: Hay códigos de barras duplicados" >> "$log_file"
        echo "   Acción: CORREGIR antes de importar" >> "$log_file"
        cat "$log_file"
        return 1
    elif [ "$duplicados_isbn" -gt 0 ] || [ "$duplicados_titulo" -gt 0 ]; then
        echo "⚠ ADVERTENCIA: Hay posibles duplicados" >> "$log_file"
        echo "  Revisar si son nuevos ejemplares o registros duplicados" >> "$log_file"
        cat "$log_file"
        return 2
    else
        echo "✓ No se encontraron duplicados" >> "$log_file"
        cat "$log_file"
        return 0
    fi
}

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIÓN 8: Modo INTELIGENTE - Agregar ejemplar o crear nuevo
# ═══════════════════════════════════════════════════════════════════════════
importar_inteligente() {
    local title=$1
    local author=$2
    local isbn=$3
    local barcode=$4
    local homebranch=$5
    # ... otros parámetros

    local biblionumber=""
    local accion=""

    # 1. Verificar si el barcode ya existe (ERROR CRÍTICO)
    if barcode_existe_en_bd "$barcode"; then
        echo -e "${RED}✗ ERROR: Código de barras $barcode ya existe${NC}"
        return 1
    fi

    # 2. Buscar por ISBN
    if [ -n "$isbn" ]; then
        biblionumber=$(obtener_biblionumber_por_isbn "$isbn")
        if [ -n "$biblionumber" ]; then
            accion="AGREGAR_EJEMPLAR"
            echo -e "${YELLOW}📚 Libro existe (ISBN). Agregando nuevo ejemplar...${NC}"
        fi
    fi

    # 3. Si no encontró por ISBN, buscar por título + autor
    if [ -z "$biblionumber" ] && [ -n "$title" ] && [ -n "$author" ]; then
        biblionumber=$(obtener_biblionumber_por_titulo_autor "$title" "$author")
        if [ -n "$biblionumber" ]; then
            accion="AGREGAR_EJEMPLAR"
            echo -e "${YELLOW}📚 Libro existe (Título+Autor). Agregando nuevo ejemplar...${NC}"
        fi
    fi

    # 4. Si no existe, crear nuevo registro completo
    if [ -z "$biblionumber" ]; then
        accion="CREAR_NUEVO"
        echo -e "${GREEN}✨ Libro nuevo. Creando registro completo...${NC}"
        # Aquí iría la lógica de crear biblio, biblioitem e item
    else
        # Solo agregar nuevo item al biblionumber existente
        echo -e "${BLUE}Biblionumber existente: $biblionumber${NC}"
        # Aquí iría la lógica de agregar solo item
    fi

    echo "$accion:$biblionumber"
    return 0
}

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIÓN 9: Generar reporte de duplicados antes de importar
# ═══════════════════════════════════════════════════════════════════════════
generar_reporte_duplicados() {
    local csv_file=$1
    local reporte_html="${2:-/tmp/reporte_duplicados.html}"

    cat > "$reporte_html" <<'EOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Reporte de Duplicados</title>
    <style>
        body { font-family: Arial; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; }
        h1 { color: #2c3e50; border-bottom: 3px solid #e74c3c; padding-bottom: 10px; }
        .alerta { background: #fee; border-left: 4px solid #e74c3c; padding: 15px; margin: 20px 0; }
        .advertencia { background: #ffc; border-left: 4px solid #f39c12; padding: 15px; margin: 20px 0; }
        .exito { background: #efe; border-left: 4px solid #27ae60; padding: 15px; margin: 20px 0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #e74c3c; color: white; }
        .badge { padding: 4px 8px; border-radius: 4px; font-size: 12px; font-weight: 600; }
        .badge-error { background: #e74c3c; color: white; }
        .badge-warning { background: #f39c12; color: white; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 Reporte de Verificación de Duplicados</h1>
        <p><strong>Archivo:</strong> CSV_FILE_PLACEHOLDER</p>
        <p><strong>Fecha:</strong> FECHA_PLACEHOLDER</p>
EOF

    # Aquí se agregarían los datos reales
    echo "        <p>Ver logs para detalles completos</p>" >> "$reporte_html"

    cat >> "$reporte_html" <<'EOF'
    </div>
</body>
</html>
EOF

    echo "$reporte_html"
}

# ═══════════════════════════════════════════════════════════════════════════
# EXPORTAR FUNCIONES
# ═══════════════════════════════════════════════════════════════════════════

export -f barcode_existe_en_bd
export -f isbn_existe_en_bd
export -f titulo_autor_existe_en_bd
export -f obtener_biblionumber_por_isbn
export -f obtener_biblionumber_por_titulo_autor
export -f verificar_duplicados_en_csv
export -f verificar_duplicados_csv_vs_bd
export -f importar_inteligente
export -f generar_reporte_duplicados

echo -e "${GREEN}✓ Funciones de prevención de duplicados cargadas${NC}"
