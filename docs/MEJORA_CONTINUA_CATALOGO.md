# 📈 GUÍA DE MEJORA CONTINUA DEL CATÁLOGO KOHA OPAC

**Objetivo:** Mejorar día a día la calidad de los datos para ofrecer la mejor experiencia en el OPAC

---

## 🎯 Niveles de Calidad de Datos

### ⭐ Nivel 1: BÁSICO (Mínimo funcional)
El registro existe y se puede encontrar.

**Campos mínimos:**
- ✅ title
- ✅ barcode
- ✅ homebranch
- ✅ itemtype

**Resultado OPAC:** El usuario puede encontrar el libro, pero poca información.

---

### ⭐⭐ Nivel 2: ESTÁNDAR (Catalogación aceptable)
Información suficiente para búsqueda y descripción básica.

**Agregar a Nivel 1:**
- ✅ author
- ✅ isbn
- ✅ publicationyear
- ✅ publisher
- ✅ itemcallnumber
- ✅ location

**Resultado OPAC:** El usuario puede:
- Buscar por autor
- Identificar edición por ISBN
- Ubicar el libro físicamente
- Ver año de publicación

---

### ⭐⭐⭐ Nivel 3: COMPLETO (Catalogación profesional)
Experiencia de usuario rica y profesional.

**Agregar a Nivel 2:**
- ✅ abstract (resumen)
- ✅ subject (materias/temas)
- ✅ dewey (clasificación)
- ✅ pages
- ✅ ccode (colección)
- ✅ copyrightdate

**Resultado OPAC:** El usuario puede:
- Leer resumen antes de decidir
- Filtrar por materia
- Descubrir libros relacionados
- Ver clasificación temática

---

### ⭐⭐⭐⭐ Nivel 4: PREMIUM (Catalogación excepcional)
Máxima calidad, comparado con bibliotecas universitarias top.

**Agregar a Nivel 3:**
- ✅ Tabla de contenidos (TOC)
- ✅ URL a vista previa (Google Books, Amazon)
- ✅ Portada del libro
- ✅ Notas editoriales
- ✅ Múltiples materias jerarquizadas
- ✅ Serie/colección completa
- ✅ Ediciones relacionadas

**Resultado OPAC:** El usuario tiene experiencia comparable a Amazon/Google Books.

---

## 📊 Plan de Mejora Progresiva

### Semana 1-2: Asegurar Nivel BÁSICO
**Objetivo:** 100% de registros con campos mínimos

```sql
-- Encontrar registros sin autor
SELECT b.biblionumber, b.title, i.barcode
FROM biblio b
JOIN items i ON b.biblionumber = i.biblionumber
WHERE b.author IS NULL OR b.author = '';

-- Encontrar registros sin ISBN
SELECT b.biblionumber, b.title, b.author
FROM biblio b
JOIN biblioitems bi ON b.biblionumber = bi.biblionumber
WHERE bi.isbn IS NULL OR bi.isbn = '';
```

**Acción:** Completar campos faltantes prioritarios.

---

### Semana 3-4: Alcanzar Nivel ESTÁNDAR
**Objetivo:** 80% de registros con información completa

**Campos a mejorar:**
1. **itemcallnumber** - Signatura para ubicación física
2. **location** - Ubicación específica en biblioteca
3. **publisher + publicationyear** - Datos de edición

```bash
# Exportar registros sin signatura
koha-mysql koha-cnc -e "
SELECT
    b.title AS 'Título',
    b.author AS 'Autor',
    i.barcode AS 'Código',
    i.itemcallnumber AS 'Signatura'
FROM biblio b
JOIN items i ON b.biblionumber = i.biblionumber
WHERE i.itemcallnumber IS NULL OR i.itemcallnumber = ''
" > registros_sin_signatura.txt
```

**Acción:** Asignar signaturas según clasificación Dewey.

---

### Mes 2: Lograr Nivel COMPLETO
**Objetivo:** 60% con resúmenes y materias

**Priorizar:**
1. **abstract** - Resúmenes atractivos
2. **subject** - Materias normalizadas
3. **dewey** - Clasificación correcta

#### Fuentes para Resúmenes (abstract):

1. **Google Books API**
   ```bash
   # Buscar por ISBN
   curl "https://www.googleapis.com/books/v1/volumes?q=isbn:9788437604947"
   ```

2. **Open Library API**
   ```bash
   curl "https://openlibrary.org/api/books?bibkeys=ISBN:9788437604947&format=json&jscmd=details"
   ```

3. **WorldCat/OCLC** (si tienes acceso)

4. **Contratapa del libro físico**

5. **Wikipedia** (para obras clásicas)

#### Plantilla de Resumen Óptimo:

```
[2-3 oraciones sobre la trama/contenido principal]
[1 oración sobre el autor o contexto]
[1 frase destacando por qué es importante/interesante]
```

**Ejemplo:**
```
"Cien años de soledad narra la historia de la familia Buendía a lo largo de siete
generaciones en el pueblo ficticio de Macondo. Gabriel García Márquez entrelaza
realidad y fantasía creando un universo mágico que refleja la historia de América
Latina. Obra cumbre del realismo mágico, ganadora del Premio Nobel de Literatura 1982."
```

---

### Mes 3-4: Avanzar hacia Nivel PREMIUM

**Enriquecimiento de datos:**

1. **Portadas de libros**
   - Google Books
   - Open Library
   - Amazon
   - Libros físicos (escanear)

2. **Tabla de contenidos**
   ```sql
   UPDATE biblio
   SET notes = CONCAT(notes, '\n\nÍNDICE:\n',
       '1. Introducción\n',
       '2. Desarrollo\n',
       '3. Conclusiones')
   WHERE biblionumber = 123;
   ```

3. **Enlaces a recursos**
   ```sql
   UPDATE biblioitems
   SET url = 'https://books.google.com/books?id=xxxxx'
   WHERE biblionumber = 123;
   ```

---

## 🔍 Queries de Auditoría de Calidad

### Dashboard de Calidad General

```sql
-- RESUMEN DE CALIDAD DEL CATÁLOGO
SELECT
    'Total Registros' AS Métrica,
    COUNT(DISTINCT biblionumber) AS Cantidad,
    '100%' AS Porcentaje
FROM biblio

UNION ALL

SELECT
    'Con Autor',
    COUNT(DISTINCT biblionumber),
    CONCAT(ROUND(COUNT(DISTINCT biblionumber) * 100.0 / (SELECT COUNT(*) FROM biblio), 1), '%')
FROM biblio
WHERE author IS NOT NULL AND author != ''

UNION ALL

SELECT
    'Con ISBN',
    COUNT(DISTINCT biblionumber),
    CONCAT(ROUND(COUNT(DISTINCT biblionumber) * 100.0 / (SELECT COUNT(*) FROM biblio), 1), '%')
FROM biblioitems
WHERE isbn IS NOT NULL AND isbn != ''

UNION ALL

SELECT
    'Con Resumen',
    COUNT(DISTINCT biblionumber),
    CONCAT(ROUND(COUNT(DISTINCT biblionumber) * 100.0 / (SELECT COUNT(*) FROM biblio), 1), '%')
FROM biblio
WHERE abstract IS NOT NULL AND abstract != ''

UNION ALL

SELECT
    'Con Materias',
    COUNT(DISTINCT biblionumber),
    CONCAT(ROUND(COUNT(DISTINCT biblionumber) * 100.0 / (SELECT COUNT(*) FROM biblio), 1), '%')
FROM biblioitems
WHERE notes IS NOT NULL AND notes != ''

UNION ALL

SELECT
    'Con Signatura',
    COUNT(DISTINCT biblionumber),
    CONCAT(ROUND(COUNT(DISTINCT biblionumber) * 100.0 / (SELECT COUNT(DISTINCT biblionumber) FROM items), 1), '%')
FROM items
WHERE itemcallnumber IS NOT NULL AND itemcallnumber != '';
```

### Registros por Nivel de Calidad

```sql
-- CLASIFICACIÓN POR NIVEL
SELECT
    CASE
        WHEN b.author IS NOT NULL
             AND bi.isbn IS NOT NULL
             AND b.abstract IS NOT NULL
             AND bi.notes IS NOT NULL
             AND i.itemcallnumber IS NOT NULL
             THEN '⭐⭐⭐ COMPLETO'
        WHEN b.author IS NOT NULL
             AND bi.isbn IS NOT NULL
             AND i.itemcallnumber IS NOT NULL
             THEN '⭐⭐ ESTÁNDAR'
        WHEN b.title IS NOT NULL
             THEN '⭐ BÁSICO'
        ELSE '❌ INCOMPLETO'
    END AS 'Nivel de Calidad',
    COUNT(DISTINCT b.biblionumber) AS 'Cantidad',
    CONCAT(ROUND(COUNT(DISTINCT b.biblionumber) * 100.0 / (SELECT COUNT(*) FROM biblio), 1), '%') AS 'Porcentaje'
FROM biblio b
LEFT JOIN biblioitems bi ON b.biblionumber = bi.biblionumber
LEFT JOIN items i ON b.biblionumber = i.biblionumber
GROUP BY
    CASE
        WHEN b.author IS NOT NULL
             AND bi.isbn IS NOT NULL
             AND b.abstract IS NOT NULL
             AND bi.notes IS NOT NULL
             AND i.itemcallnumber IS NOT NULL
             THEN '⭐⭐⭐ COMPLETO'
        WHEN b.author IS NOT NULL
             AND bi.isbn IS NOT NULL
             AND i.itemcallnumber IS NOT NULL
             THEN '⭐⭐ ESTÁNDAR'
        WHEN b.title IS NOT NULL
             THEN '⭐ BÁSICO'
        ELSE '❌ INCOMPLETO'
    END
ORDER BY 'Cantidad' DESC;
```

### Top 20 Registros a Mejorar Prioritarios

```sql
-- LIBROS MÁS PRESTADOS SIN RESUMEN (prioridad alta)
SELECT
    b.biblionumber,
    b.title AS 'Título',
    b.author AS 'Autor',
    SUM(i.issues) AS 'Total Préstamos',
    CASE WHEN b.abstract IS NULL THEN '❌ Sin resumen' ELSE '✓' END AS Resumen,
    CASE WHEN bi.notes IS NULL THEN '❌ Sin materias' ELSE '✓' END AS Materias
FROM biblio b
JOIN biblioitems bi ON b.biblionumber = bi.biblionumber
JOIN items i ON b.biblionumber = i.biblionumber
WHERE b.abstract IS NULL OR b.abstract = ''
GROUP BY b.biblionumber
ORDER BY SUM(i.issues) DESC
LIMIT 20;
```

---

## 📝 Plantillas de Trabajo Diario

### Template CSV para Mejoras Diarias

Exporta 10-20 registros por día para enriquecer:

```bash
#!/bin/bash
# exportar_registros_mejorar.sh

# Registros sin resumen - exportar para completar
koha-mysql koha-cnc -e "
SELECT
    b.biblionumber,
    b.title,
    b.author,
    bi.isbn,
    bi.publishercode,
    bi.publicationyear
FROM biblio b
JOIN biblioitems bi ON b.biblionumber = bi.biblionumber
WHERE b.abstract IS NULL OR b.abstract = ''
LIMIT 20
" > /home/mvillalba/migradatos/exports/mejorar_$(date +%Y%m%d).csv

echo "Archivo creado: mejorar_$(date +%Y%m%d).csv"
echo "Completa los resúmenes y reimporta con UPDATE"
```

### Script de Actualización Masiva

```bash
#!/bin/bash
# actualizar_resumenes.sh

# Lee un CSV con: biblionumber,abstract
# Actualiza los resúmenes en la BD

CSV_FILE=$1

while IFS=, read -r biblionumber abstract; do
    koha-mysql koha-cnc -e "
    UPDATE biblio
    SET abstract = '$abstract'
    WHERE biblionumber = $biblionumber;
    "
done < "$CSV_FILE"

echo "Resúmenes actualizados!"
```

---

## 🎨 Mejoras Visuales para OPAC

### 1. Agregar Portadas

```sql
-- Agregar URL de portada desde Open Library
UPDATE biblioitems
SET url = CONCAT('https://covers.openlibrary.org/b/isbn/', isbn, '-L.jpg')
WHERE isbn IS NOT NULL AND isbn != '';
```

### 2. Normalizar Autores

```sql
-- Listar autores para normalizar formato
SELECT DISTINCT author
FROM biblio
WHERE author IS NOT NULL
ORDER BY author;

-- Corregir formato (ejemplos)
UPDATE biblio SET author = 'García Márquez, Gabriel' WHERE author = 'Gabriel Garcia Marquez';
UPDATE biblio SET author = 'Cervantes Saavedra, Miguel de' WHERE author = 'Miguel de Cervantes';
```

### 3. Mejorar Materias (Subject Headings)

**Materias normalizadas por disciplina:**

```
INGENIERÍA:
- Ingeniería Civil
- Ingeniería Mecánica
- Ingeniería Eléctrica
- Ingeniería de Sistemas
- Estructuras
- Mecánica de Fluidos

QUÍMICA:
- Química Orgánica
- Química Inorgánica
- Fisicoquímica
- Química Analítica
- Bioquímica

ODONTOLOGÍA:
- Odontología General
- Ortodoncia
- Periodoncia
- Endodoncia
- Cirugía Oral

LITERATURA:
- Novela
- Poesía
- Teatro
- Ensayo
- Cuentos
- Literatura Latinoamericana
- Literatura Española
- Literatura Inglesa
```

---

## 📈 Métricas de Éxito

### KPIs Mensuales

| Métrica | Objetivo Mes 1 | Objetivo Mes 3 | Objetivo Mes 6 |
|---------|----------------|----------------|----------------|
| Registros con autor | 80% | 95% | 99% |
| Registros con ISBN | 70% | 85% | 95% |
| Registros con resumen | 30% | 60% | 80% |
| Registros con materias | 40% | 70% | 90% |
| Registros con signatura | 85% | 98% | 100% |
| Nivel COMPLETO (⭐⭐⭐) | 20% | 50% | 70% |

### Reporte Semanal

```bash
#!/bin/bash
# reporte_calidad_semanal.sh

echo "=== REPORTE DE CALIDAD - $(date +%Y-%m-%d) ==="
echo ""

koha-mysql koha-cnc < /home/mvillalba/migradatos/docs/query_calidad_dashboard.sql

echo ""
echo "Registros mejorados esta semana:"
koha-mysql koha-cnc -e "
SELECT COUNT(*)
FROM biblio
WHERE timestamp >= DATE_SUB(NOW(), INTERVAL 7 DAY)
      AND abstract IS NOT NULL;
"
```

---

## 🚀 Checklist Diario de Mejora

```
[ ] Exportar 10-20 registros prioritarios (más prestados sin resumen)
[ ] Buscar resúmenes en Google Books / Open Library
[ ] Completar campos faltantes (author, isbn, subject)
[ ] Normalizar nombres de autores
[ ] Asignar clasificación Dewey correcta
[ ] Revisar y corregir signaturas (itemcallnumber)
[ ] Actualizar registros en BD
[ ] Reindexar Zebra si hay cambios importantes
[ ] Verificar cambios en OPAC
[ ] Documentar mejoras realizadas
```

---

## 🔧 Herramientas Útiles

### APIs para Enriquecimiento

1. **Google Books API**
   - Resúmenes, portadas, TOC
   - https://developers.google.com/books

2. **Open Library**
   - Datos bibliográficos, portadas
   - https://openlibrary.org/developers/api

3. **WorldCat Search API**
   - Registros MARC completos
   - https://www.oclc.org/developer/api/oclc-apis/worldcat-search-api.en.html

### Scripts de Automatización

```bash
# Crear en /home/mvillalba/migradatos/scripts/

# 1. enriquecer_con_google_books.py
# 2. normalizar_autores.sh
# 3. generar_resumen_desde_pdf.py (OCR)
# 4. descargar_portadas.sh
```

---

## 📚 Recursos de Aprendizaje

- **Catalogación AACR2** - Reglas de catalogación
- **MARC21** - Formato bibliográfico estándar
- **Clasificación Dewey** - Sistema decimal
- **RDA** - Recursos, Descripción y Acceso

---

**¡La mejora continua es un viaje, no un destino!**
**Cada día, cada registro mejorado, hace la diferencia para los usuarios.**

🎯 **Meta:** Catálogo de clase mundial, comparable a las mejores bibliotecas universitarias.
