# 🔧 MEJORAS AVANZADAS DEL IMPORTADOR - Basadas en Experiencia

**Fecha:** 25 de Octubre de 2025
**Nivel:** Avanzado
**Objetivo:** Optimizar el proceso de importación al máximo

---

## 🎯 Problemas Comunes y Soluciones

### 1. RENDIMIENTO EN IMPORTACIONES GRANDES

#### Problema:
```
Importar 10,000+ registros puede tardar horas
El servidor se queda sin memoria
Zebra se retrasa en la indexación
```

#### Solución:
```bash
# IMPORTACIÓN POR LOTES (Batch Processing)

#!/bin/bash
# importar_por_lotes.sh

CSV_FILE=$1
BATCH_SIZE=500  # Registros por lote
TOTAL_LINES=$(wc -l < "$CSV_FILE")
BATCHES=$(( (TOTAL_LINES - 1) / BATCH_SIZE + 1 ))

echo "Total registros: $((TOTAL_LINES - 1))"
echo "Procesando en $BATCHES lotes de $BATCH_SIZE"

# Guardar encabezado
head -1 "$CSV_FILE" > /tmp/header.csv

for i in $(seq 1 $BATCHES); do
    START=$(( (i - 1) * BATCH_SIZE + 2 ))  # +2 por encabezado
    END=$(( i * BATCH_SIZE + 1 ))

    echo "Lote $i/$BATCHES (líneas $START-$END)"

    # Extraer lote
    head -1 "$CSV_FILE" > /tmp/batch_$i.csv
    sed -n "${START},${END}p" "$CSV_FILE" >> /tmp/batch_$i.csv

    # Importar lote
    ./importar_biblioteca.sh batch_$i

    # Pausa para que Zebra procese
    echo "Esperando indexación..."
    sleep 30

    # Limpiar
    rm /tmp/batch_$i.csv
done

echo "✓ Importación completa"
```

**Beneficios:**
- ✅ Menor uso de memoria
- ✅ Indexación incremental
- ✅ Recuperación ante errores (solo re-importar lote fallido)
- ✅ Progreso visible

---

### 2. MANEJO DE ERRORES Y RECUPERACIÓN

#### Problema:
```
Si falla un registro, se detiene todo
No hay rollback parcial
Difícil identificar el registro problemático
```

#### Solución:
```bash
# MODO TOLERANTE A ERRORES

#!/bin/bash
# importar_tolerante.sh

CSV_FILE=$1
SUCCESS_LOG="logs/success_$(date +%Y%m%d).log"
ERROR_LOG="logs/errors_$(date +%Y%m%d).log"
ERROR_CSV="errores/failed_$(date +%Y%m%d).csv"

# Guardar encabezado en archivo de errores
head -1 "$CSV_FILE" > "$ERROR_CSV"

# Procesar línea por línea
tail -n +2 "$CSV_FILE" | while IFS= read -r line; do
    LINENO=$((LINENO + 1))

    # Intentar importar este registro
    echo "$line" | importar_registro_individual.sh

    if [ $? -eq 0 ]; then
        echo "Línea $LINENO: OK" >> "$SUCCESS_LOG"
    else
        echo "Línea $LINENO: ERROR" >> "$ERROR_LOG"
        echo "$line" >> "$ERROR_CSV"
    fi

    # Barra de progreso
    echo -ne "Procesados: $LINENO\r"
done

echo ""
echo "Importación finalizada"
echo "Exitosos: $(wc -l < $SUCCESS_LOG)"
echo "Errores: $(wc -l < $ERROR_LOG)"
echo "Registros con errores en: $ERROR_CSV"
```

**Beneficios:**
- ✅ Continúa aunque falle un registro
- ✅ Log detallado de éxitos y errores
- ✅ CSV con registros fallidos para corrección
- ✅ Fácil re-importación de solo los errores

---

### 3. VALIDACIÓN EN TIEMPO REAL

#### Problema:
```
Validación separada del importador
Hay que ejecutar 2 scripts
Posibles cambios entre validación e importación
```

#### Solución:
```bash
# IMPORTADOR CON VALIDACIÓN INTEGRADA

#!/bin/bash
# importar_con_validacion.sh

CSV_FILE=$1

# PRE-VALIDACIÓN
echo "=== PRE-VALIDACIÓN ==="
./validar_antes_importar.sh "$CSV_FILE" > /tmp/validacion.txt

SCORE=$(grep "PUNTUACIÓN DE CALIDAD:" /tmp/validacion.txt | awk '{print $4}' | cut -d'/' -f1)

echo "Score de calidad: $SCORE/100"

if [ "$SCORE" -lt 50 ]; then
    echo "❌ Score muy bajo. Corrija errores antes de importar."
    cat /tmp/validacion.txt
    exit 1
fi

if [ "$SCORE" -lt 70 ]; then
    echo "⚠ Score bajo. ¿Desea continuar? (s/n)"
    read -r RESPUESTA
    [ "$RESPUESTA" != "s" ] && exit 0
fi

# VALIDACIÓN DE CADA REGISTRO DURANTE IMPORTACIÓN
echo ""
echo "=== IMPORTACIÓN CON VALIDACIÓN ==="

tail -n +2 "$CSV_FILE" | while IFS=, read -r title author isbn publisher year copyright pages type dewey callnum barcode branch holding location price replace notforloan ccode materials abstract subject notes; do

    # Validaciones en tiempo real
    ERRORS=""

    # Validar campos obligatorios
    [ -z "$title" ] && ERRORS="${ERRORS}Sin título. "
    [ -z "$barcode" ] && ERRORS="${ERRORS}Sin código de barras. "
    [ -z "$branch" ] && ERRORS="${ERRORS}Sin biblioteca. "

    # Validar formato ISBN
    if [ -n "$isbn" ]; then
        # Remover guiones
        ISBN_CLEAN=$(echo "$isbn" | tr -d '-')

        # Validar longitud (10 o 13 dígitos)
        if [[ ! "$ISBN_CLEAN" =~ ^[0-9]{10}$ ]] && [[ ! "$ISBN_CLEAN" =~ ^[0-9]{13}$ ]]; then
            ERRORS="${ERRORS}ISBN inválido ($isbn). "
        fi
    fi

    # Validar código de biblioteca existe en Koha
    BRANCH_EXISTS=$(koha-mysql koha-cnc -sN -e "SELECT COUNT(*) FROM branches WHERE branchcode='$branch'")
    [ "$BRANCH_EXISTS" -eq 0 ] && ERRORS="${ERRORS}Biblioteca '$branch' no existe. "

    # Validar código de barras único
    BARCODE_EXISTS=$(koha-mysql koha-cnc -sN -e "SELECT COUNT(*) FROM items WHERE barcode='$barcode'")
    [ "$BARCODE_EXISTS" -gt 0 ] && ERRORS="${ERRORS}Código de barras '$barcode' duplicado. "

    # Si hay errores, registrar y saltar
    if [ -n "$ERRORS" ]; then
        echo "❌ $barcode: $ERRORS" >> logs/validation_errors.log
        continue
    fi

    # Importar registro
    importar_registro "$title" "$author" "$isbn" ...

    echo "✓ $barcode importado"
done
```

**Beneficios:**
- ✅ Validación pre-importación automática
- ✅ Validación por registro durante importación
- ✅ Detección de ISBNs inválidos
- ✅ Verificación de códigos de biblioteca
- ✅ Prevención de duplicados en tiempo real

---

### 4. ENRIQUECIMIENTO AUTOMÁTICO

#### Problema:
```
Datos incompletos (sin ISBN, autor, resumen)
Proceso manual de completar información
Calidad inconsistente
```

#### Solución:
```bash
# AUTO-ENRIQUECIMIENTO CON APIs

#!/bin/bash
# enriquecer_automatico.sh

ISBN=$1

# Buscar en Google Books API
GOOGLE_DATA=$(curl -s "https://www.googleapis.com/books/v1/volumes?q=isbn:$ISBN")

# Extraer datos
TITLE=$(echo "$GOOGLE_DATA" | jq -r '.items[0].volumeInfo.title')
AUTHOR=$(echo "$GOOGLE_DATA" | jq -r '.items[0].volumeInfo.authors[0]')
PUBLISHER=$(echo "$GOOGLE_DATA" | jq -r '.items[0].volumeInfo.publisher')
YEAR=$(echo "$GOOGLE_DATA" | jq -r '.items[0].volumeInfo.publishedDate' | cut -d'-' -f1)
PAGES=$(echo "$GOOGLE_DATA" | jq -r '.items[0].volumeInfo.pageCount')
ABSTRACT=$(echo "$GOOGLE_DATA" | jq -r '.items[0].volumeInfo.description')
COVER_URL=$(echo "$GOOGLE_DATA" | jq -r '.items[0].volumeInfo.imageLinks.thumbnail')

# Si Google Books no tiene datos, probar Open Library
if [ "$TITLE" = "null" ]; then
    OL_DATA=$(curl -s "https://openlibrary.org/api/books?bibkeys=ISBN:$ISBN&format=json&jscmd=data")

    TITLE=$(echo "$OL_DATA" | jq -r ".\"ISBN:$ISBN\".title")
    AUTHOR=$(echo "$OL_DATA" | jq -r ".\"ISBN:$ISBN\".authors[0].name")
    # ... extraer más campos
fi

# Devolver datos en CSV
echo "$TITLE,$AUTHOR,$ISBN,$PUBLISHER,$YEAR,$PAGES,$ABSTRACT,$COVER_URL"
```

**Uso integrado:**
```bash
# Durante la importación
while read -r line; do
    ISBN=$(echo "$line" | cut -d',' -f3)

    # Si falta información, auto-completar
    if [ -z "$(echo "$line" | cut -d',' -f2)" ]; then  # Sin autor
        echo "Buscando datos para ISBN $ISBN..."
        ENRICHED=$(./enriquecer_automatico.sh "$ISBN")

        # Fusionar datos
        line=$(merge_csv_data "$line" "$ENRICHED")
    fi

    # Importar con datos enriquecidos
    importar_registro "$line"
done
```

**Beneficios:**
- ✅ Completar campos faltantes automáticamente
- ✅ Resúmenes de calidad
- ✅ Portadas automáticas
- ✅ Datos normalizados

---

### 5. IMPORTACIÓN INCREMENTAL (UPDATES)

#### Problema:
```
¿Cómo actualizar registros existentes?
¿Cómo agregar nuevos ejemplares a libros existentes?
Importación duplica registros
```

#### Solución:
```bash
# IMPORTACIÓN INCREMENTAL INTELIGENTE

#!/bin/bash
# importar_incremental.sh

while IFS=, read -r title author isbn barcode branch ...; do

    # Buscar si el libro ya existe (por ISBN o título+autor)
    if [ -n "$isbn" ]; then
        BIBLIONUMBER=$(koha-mysql koha-cnc -sN -e "
            SELECT biblionumber FROM biblioitems WHERE isbn='$isbn' LIMIT 1
        ")
    fi

    if [ -z "$BIBLIONUMBER" ]; then
        # Buscar por título + autor
        BIBLIONUMBER=$(koha-mysql koha-cnc -sN -e "
            SELECT biblionumber FROM biblio
            WHERE title='$title' AND author='$author' LIMIT 1
        ")
    fi

    if [ -n "$BIBLIONUMBER" ]; then
        # REGISTRO EXISTE: Agregar nuevo ejemplar o actualizar
        echo "Libro ya existe (biblionumber=$BIBLIONUMBER)"

        # Verificar si el barcode ya existe
        ITEM_EXISTS=$(koha-mysql koha-cnc -sN -e "
            SELECT COUNT(*) FROM items WHERE barcode='$barcode'
        ")

        if [ "$ITEM_EXISTS" -eq 0 ]; then
            # Agregar nuevo ejemplar
            echo "Agregando nuevo ejemplar: $barcode"

            koha-mysql koha-cnc -e "
                INSERT INTO items (biblionumber, biblioitemnumber, barcode, homebranch, ...)
                SELECT $BIBLIONUMBER, biblioitemnumber, '$barcode', '$branch', ...
                FROM biblioitems WHERE biblionumber=$BIBLIONUMBER LIMIT 1
            "
        else
            # Actualizar ejemplar existente
            echo "Actualizando ejemplar: $barcode"

            koha-mysql koha-cnc -e "
                UPDATE items SET
                    location='$location',
                    price=$price,
                    ...
                WHERE barcode='$barcode'
            "
        fi

        # Actualizar información bibliográfica si es mejor
        if [ -n "$abstract" ]; then
            koha-mysql koha-cnc -e "
                UPDATE biblio SET abstract='$abstract'
                WHERE biblionumber=$BIBLIONUMBER AND (abstract IS NULL OR abstract='')
            "
        fi

    else
        # REGISTRO NUEVO: Crear completo
        echo "Nuevo libro: $title"
        importar_registro_nuevo "$title" "$author" ...
    fi

done < "$CSV_FILE"
```

**Beneficios:**
- ✅ No duplica registros
- ✅ Agrega copias adicionales automáticamente
- ✅ Actualiza información mejorada
- ✅ Flexible para re-importaciones

---

### 6. NORMALIZACIÓN AUTOMÁTICA

#### Problema:
```
Autores en diferentes formatos ("García Márquez, Gabriel" vs "Gabriel García Márquez")
ISBNs con/sin guiones
Inconsistencia en datos
```

#### Solución:
```bash
# NORMALIZACIÓN AUTOMÁTICA

#!/bin/bash
# normalizar_datos.sh

normalizar_autor() {
    local autor=$1

    # Si tiene coma, ya está en formato correcto
    if [[ "$autor" == *","* ]]; then
        echo "$autor"
        return
    fi

    # Intentar convertir "Nombre Apellido" a "Apellido, Nombre"
    # Ejemplo: "Gabriel García Márquez" → "García Márquez, Gabriel"

    # Dividir en palabras
    IFS=' ' read -ra PALABRAS <<< "$autor"
    NUM_PALABRAS=${#PALABRAS[@]}

    if [ "$NUM_PALABRAS" -ge 2 ]; then
        # Asumir que la última palabra es apellido (simple)
        # O las últimas 2 palabras si hay 3+ palabras
        if [ "$NUM_PALABRAS" -ge 3 ]; then
            # "Gabriel García Márquez" → "García Márquez, Gabriel"
            NOMBRE="${PALABRAS[0]}"
            APELLIDO="${PALABRAS[@]:1}"
            echo "$APELLIDO, $NOMBRE"
        else
            # "Gabriel García" → "García, Gabriel"
            echo "${PALABRAS[1]}, ${PALABRAS[0]}"
        fi
    else
        echo "$autor"
    fi
}

normalizar_isbn() {
    local isbn=$1

    # Remover guiones, espacios
    ISBN_CLEAN=$(echo "$isbn" | tr -d '- ')

    # Si es ISBN-10, convertir a ISBN-13
    if [ ${#ISBN_CLEAN} -eq 10 ]; then
        # Algoritmo de conversión ISBN-10 a ISBN-13
        # (Simplificado, implementación completa requiere cálculo de checksum)
        echo "978$ISBN_CLEAN"
    else
        echo "$ISBN_CLEAN"
    fi
}

normalizar_titulo() {
    local titulo=$1

    # Capitalizar primera letra de cada palabra importante
    # Remover espacios extra
    echo "$titulo" | sed 's/  */ /g' | sed 's/^ //;s/ $//'
}

# Aplicar durante importación
while IFS=, read -r title author isbn ...; do
    title=$(normalizar_titulo "$title")
    author=$(normalizar_autor "$author")
    isbn=$(normalizar_isbn "$isbn")

    # Importar con datos normalizados
    importar_registro "$title" "$author" "$isbn" ...
done
```

**Beneficios:**
- ✅ Consistencia en formato de autores
- ✅ ISBNs estandarizados
- ✅ Mejor búsqueda y deduplicación
- ✅ Calidad profesional

---

### 7. PREVIEW ANTES DE IMPORTAR

#### Problema:
```
No se puede ver cómo quedarán los registros
Sorpresas después de importar
```

#### Solución:
```bash
# MODO PREVIEW (DRY-RUN)

#!/bin/bash
# importar_preview.sh

CSV_FILE=$1
DRY_RUN=true  # No insertar en BD, solo mostrar

echo "=== PREVIEW DE IMPORTACIÓN ==="
echo "Primeros 5 registros:"
echo ""

head -6 "$CSV_FILE" | tail -5 | while IFS=, read -r title author isbn ...; do
    echo "─────────────────────────────────────────"
    echo "Título: $title"
    echo "Autor: $author"
    echo "ISBN: $isbn"
    echo ""
    echo "SQL que se ejecutará:"
    echo "  INSERT INTO biblio (title, author, ...) VALUES ('$title', '$author', ...)"
    echo "  INSERT INTO biblioitems (isbn, ...) VALUES ('$isbn', ...)"
    echo "  INSERT INTO items (barcode, ...) VALUES ('$barcode', ...)"
    echo ""
done

echo "─────────────────────────────────────────"
echo ""
echo "Total de registros a importar: $(($(wc -l < $CSV_FILE) - 1))"
echo ""
echo "¿Proceder con la importación real? (s/n)"
read -r RESPUESTA

if [ "$RESPUESTA" = "s" ]; then
    ./importar_biblioteca.sh "$CSV_FILE"
fi
```

**Beneficios:**
- ✅ Ver antes de hacer cambios irreversibles
- ✅ Detectar problemas de formato
- ✅ Confirmar que los datos se verán correctamente

---

### 8. REPORTE POST-IMPORTACIÓN

#### Problema:
```
No hay feedback detallado después de importar
Difícil saber qué se importó exactamente
```

#### Solución:
```bash
# REPORTE DETALLADO POST-IMPORTACIÓN

#!/bin/bash
# generar_reporte_importacion.sh

BIBLIOS_IMPORTADOS=$1  # Lista de biblionumbers importados
FECHA=$(date '+%Y-%m-%d %H:%M:%S')

cat > "reportes/importacion_${FECHA}.html" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Reporte de Importación - $FECHA</title>
    <style>
        body { font-family: Arial; margin: 20px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #4CAF50; color: white; }
        .stats { background: #f0f0f0; padding: 15px; margin: 20px 0; border-radius: 5px; }
    </style>
</head>
<body>
    <h1>Reporte de Importación</h1>
    <p><strong>Fecha:</strong> $FECHA</p>

    <div class="stats">
        <h2>Estadísticas</h2>
        <p>Total de registros importados: $(wc -l < $BIBLIOS_IMPORTADOS)</p>
        <p>Biblioteca: $(head -1 $CSV_FILE | cut -d',' -f12)</p>
    </div>

    <h2>Primeros 10 registros importados</h2>
    <table>
        <tr>
            <th>Título</th>
            <th>Autor</th>
            <th>ISBN</th>
            <th>Código</th>
            <th>Ver en OPAC</th>
        </tr>
EOF

# Agregar registros a la tabla
head -10 "$BIBLIOS_IMPORTADOS" | while read -r biblionumber; do
    koha-mysql koha-cnc -e "
        SELECT
            CONCAT('<tr>',
                '<td>', b.title, '</td>',
                '<td>', IFNULL(b.author, ''), '</td>',
                '<td>', IFNULL(bi.isbn, ''), '</td>',
                '<td>', i.barcode, '</td>',
                '<td><a href=\"http://opac.una.edu.py/cgi-bin/koha/opac-detail.pl?biblionumber=', b.biblionumber, '\">Ver</a></td>',
            '</tr>')
        FROM biblio b
        JOIN biblioitems bi ON b.biblionumber = bi.biblionumber
        JOIN items i ON b.biblionumber = i.biblionumber
        WHERE b.biblionumber = $biblionumber
    " -sN >> "reportes/importacion_${FECHA}.html"
done

cat >> "reportes/importacion_${FECHA}.html" <<EOF
    </table>
</body>
</html>
EOF

echo "Reporte generado: reportes/importacion_${FECHA}.html"
firefox "reportes/importacion_${FECHA}.html"
```

**Beneficios:**
- ✅ Reporte visual profesional
- ✅ Enlaces directos al OPAC
- ✅ Estadísticas claras
- ✅ Documentación del proceso

---

## 🚀 Implementación Sugerida

### Prioridad ALTA (Implementar YA)
1. ✅ Importación por lotes (mejor rendimiento)
2. ✅ Manejo de errores tolerante (no perder datos)
3. ✅ Validación integrada (prevenir problemas)

### Prioridad MEDIA (Próximo mes)
4. ✅ Normalización automática (mejor calidad)
5. ✅ Importación incremental (evitar duplicados)
6. ✅ Preview antes de importar (seguridad)

### Prioridad BAJA (Futuro)
7. ✅ Enriquecimiento automático con APIs
8. ✅ Reportes HTML post-importación

---

## 📊 Mejoras Adicionales Sugeridas

### A. Monitoreo en Tiempo Real
```bash
# Dashboard durante importación
watch -n 1 'koha-mysql koha-cnc -e "
    SELECT COUNT(*) as Importados
    FROM biblio
    WHERE datecreated = CURDATE()
"'
```

### B. Notificaciones
```bash
# Enviar email cuando termine
echo "Importación completada" | mail -s "Koha Import Done" admin@una.edu.py
```

### C. Backup Automático Antes de Importar
```bash
# Backup de BD antes de cada importación
koha-mysql koha-cnc --batch -e "
    SELECT * FROM biblio INTO OUTFILE '/tmp/biblio_backup.csv'
"
```

### D. Integración con Git
```bash
# Versionar CSVs importados
git add importar_aqui/*.csv
git commit -m "Import $(date +%Y-%m-%d): 150 nuevos registros ING"
git push
```

---

## 📈 Métricas de Éxito

| Métrica | Antes | Objetivo |
|---------|-------|----------|
| Tiempo importación 1000 registros | 45 min | 10 min |
| Tasa de errores | 15% | <2% |
| Registros completos (⭐⭐⭐) | 20% | 70% |
| Tiempo validación manual | 30 min | 0 min (automático) |
| Duplicados en BD | 5% | 0% |

---

**¡Con estas mejoras, el importador será de clase mundial!**
