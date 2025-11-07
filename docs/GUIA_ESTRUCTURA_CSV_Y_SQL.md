# 📚 GUÍA COMPLETA: Estructura CSV y SQL para Catálogo Koha

**Fecha:** 25 de Octubre de 2025
**Sistema:** Koha UNA - Migración Bibliográfica
**Autor:** Asistente Claude Code

---

## 📋 Índice

1. [Archivos de Referencia](#archivos-de-referencia)
2. [Estructura del CSV](#estructura-del-csv)
3. [Campos Obligatorios vs Opcionales](#campos-obligatorios-vs-opcionales)
4. [Estructura SQL Didáctica](#estructura-sql-didáctica)
5. [Ejemplos Prácticos](#ejemplos-prácticos)
6. [Integración con Sistema Existente](#integración-con-sistema-existente)

---

## 📁 Archivos de Referencia

En el directorio `/home/mvillalba/migradatos/docs/` encontrarás:

- **`ejemplo-catalogo-completo.csv`** - CSV de ejemplo con 15 libros de diferentes tipos
- **`estructura-catalogo-didactica.sql`** - DDL completo con explicaciones de cada campo

---

## 📊 Estructura del CSV

### Columnas del CSV (en orden)

```csv
title,author,isbn,publisher,publicationyear,copyrightdate,pages,itemtype,dewey,itemcallnumber,barcode,homebranch,holdingbranch,location,price,replacementprice,notforloan,ccode,materials,abstract,subject,notes
```

### Descripción de Cada Columna

| Columna | Tipo | Obligatorio | Descripción | Ejemplo |
|---------|------|-------------|-------------|---------|
| **title** | Texto | ✅ SÍ | Título completo de la obra | "Cien años de soledad" |
| **author** | Texto | ⚠️ Recomendado | Autor (formato: Apellido, Nombre) | "García Márquez, Gabriel" |
| **isbn** | Texto | ⚠️ Recomendado | ISBN 10 o 13 dígitos | "978-84-376-0494-7" |
| **publisher** | Texto | 🔵 Opcional | Nombre de la editorial | "Editorial Sudamericana" |
| **publicationyear** | Número | 🔵 Opcional | Año de publicación | "1967" |
| **copyrightdate** | Número | 🔵 Opcional | Año de copyright | "1967" |
| **pages** | Texto | 🔵 Opcional | Número de páginas | "471" o "xxiv, 325 p." |
| **itemtype** | Código | ✅ SÍ | Tipo de material (ver catálogo abajo) | "BK" |
| **dewey** | Texto | ⚠️ Recomendado | Clasificación Dewey | "863" |
| **itemcallnumber** | Texto | ⚠️ Recomendado | Signatura topográfica | "863 GAR" |
| **barcode** | Texto | ✅ SÍ | Código de barras único | "LIBRO001" |
| **homebranch** | Código | ✅ SÍ | Biblioteca propietaria | "ING", "ODO", "QUI" |
| **holdingbranch** | Código | ✅ SÍ | Biblioteca actual | "ING", "ODO", "QUI" |
| **location** | Texto | ⚠️ Recomendado | Ubicación específica | "Estantería General" |
| **price** | Decimal | 🔵 Opcional | Precio de compra | "25.00" |
| **replacementprice** | Decimal | 🔵 Opcional | Precio de reemplazo | "35.00" |
| **notforloan** | Número | 🔵 Opcional | Estado préstamo (ver abajo) | "0" |
| **ccode** | Código | ⚠️ Recomendado | Código de colección | "FIC", "NF", "TEXTB" |
| **materials** | Texto | 🔵 Opcional | Materiales adicionales | "Tapa dura", "Incluye CD" |
| **abstract** | Texto largo | 🔵 Opcional | Resumen del contenido | "Historia de la familia Buendía..." |
| **subject** | Texto | ⚠️ Recomendado | Materias/temas | "Literatura latinoamericana" |
| **notes** | Texto | 🔵 Opcional | Notas adicionales | "Primera edición" |

---

## 📌 Campos Obligatorios vs Opcionales

### ✅ OBLIGATORIOS (El sistema no funciona sin estos)

1. **title** - Sin título no hay registro
2. **itemtype** - Koha necesita clasificar el tipo de material
3. **barcode** - Identificador único del ejemplar
4. **homebranch** - Debe existir la biblioteca en Koha
5. **holdingbranch** - Generalmente igual a homebranch

### ⚠️ ALTAMENTE RECOMENDADOS (Para catálogo óptimo en OPAC)

1. **author** - Permite búsqueda por autor
2. **isbn** - Identificación estándar
3. **dewey / itemcallnumber** - Organización física
4. **location** - Localización en biblioteca
5. **ccode** - Filtrado por colecciones
6. **subject** - Búsqueda por materia
7. **abstract** - Mejora experiencia de usuario

### 🔵 OPCIONALES (Mejoran pero no son críticos)

- publisher, publicationyear, copyrightdate
- pages, price, replacementprice
- materials, notes

---

## 📖 Catálogos de Valores Comunes

### ITEMTYPE (Tipo de Material)

```
BK      = Libro (Book)
DVD     = DVD/Video
CD      = CD/Audio
MAG     = Revista (Magazine)
NEWS    = Periódico (Newspaper)
MAP     = Mapa
SCORE   = Partitura musical
REF     = Material de referencia
EBOOK   = Libro electrónico
```

### CCODE (Código de Colección)

```
FIC     = Ficción
NF      = No Ficción
REF     = Referencia
JUV     = Juvenil
INF     = Infantil
TEXTB   = Libro de texto
TESIS   = Tesis
CS      = Ciencias de la Computación
BIOG    = Biografías
HIST    = Historia
```

### NOTFORLOAN (Estado de Préstamo)

```
0       = Prestable (disponible para llevar)
1       = No prestable (solo consulta en sala)
2       = En proceso técnico
-1      = En pedido/orden
```

### HOMEBRANCH (Códigos de Biblioteca UNA)

```
ING     = Facultad de Ingeniería
ODO     = Facultad de Odontología
QUI     = Facultad de Química
ARQ     = Facultad de Arquitectura
DER     = Facultad de Derecho
MED     = Facultad de Medicina
```

### CLASIFICACIÓN DEWEY (Primeros 3 dígitos)

```
000-099 = Informática, información y obras generales
  005     = Programación de computadoras

100-199 = Filosofía y psicología
  150     = Psicología

200-299 = Religión

300-399 = Ciencias sociales
  320     = Ciencia política
  330     = Economía

400-499 = Lenguas

500-599 = Ciencias naturales y matemáticas
  510     = Matemáticas
  515     = Cálculo
  540     = Química
  570     = Biología

600-699 = Tecnología
  610     = Medicina
  620     = Ingeniería

700-799 = Arte y recreación

800-899 = Literatura
  810     = Literatura estadounidense
  820     = Literatura inglesa
  830     = Literatura alemana
  840     = Literatura francesa
  850     = Literatura italiana
  860     = Literatura española
  863     = Ficción española
  870     = Literatura latina

900-999 = Historia y geografía
  910     = Geografía
  920     = Biografía
  930-990 = Historia por regiones
```

---

## 🔧 Estructura SQL Didáctica

### Las 3 Tablas Principales

```
┌─────────────────────────────────────────────┐
│           1. BIBLIO                         │
│  (Registro bibliográfico base)              │
│  - biblionumber (ID único)                  │
│  - title, author                            │
│  - abstract, notes                          │
└─────────────┬───────────────────────────────┘
              │ 1:1
              ▼
┌─────────────────────────────────────────────┐
│           2. BIBLIOITEMS                    │
│  (Detalles de publicación)                  │
│  - biblioitemnumber (ID único)              │
│  - isbn, publisher, pages                   │
│  - itemtype, dewey                          │
└─────────────┬───────────────────────────────┘
              │ 1:N
              ▼
┌─────────────────────────────────────────────┐
│           3. ITEMS                          │
│  (Ejemplares físicos)                       │
│  - itemnumber (ID único)                    │
│  - barcode, homebranch, location            │
│  - price, notforloan                        │
└─────────────────────────────────────────────┘
```

**Relación:**
- 1 BIBLIO (obra) → 1 BIBLIOITEM (edición) → N ITEMS (copias físicas)

### Ejemplo:
- BIBLIO: "Don Quijote" de Cervantes
- BIBLIOITEM: Edición de Editorial Planeta, 2005, ISBN 978-xxx
- ITEMS:
  - Copia 1 (barcode: LIBRO001) en Ingeniería
  - Copia 2 (barcode: LIBRO002) en Odontología
  - Copia 3 (barcode: LIBRO003) en Química

**Consulta el archivo `estructura-catalogo-didactica.sql` para:**
- DDL completo con comentarios en cada campo
- Ejemplos de INSERT para cada tabla
- Consultas útiles de verificación
- Procedimientos de importación

---

## 💡 Ejemplos Prácticos

### Ejemplo 1: Libro de Ficción Simple

```csv
"Cien años de soledad","García Márquez, Gabriel","978-84-376-0494-7","Sudamericana","1967","1967","471","BK","863","863 GAR","LIBRO001","ING","ING","Estantería General","25.00","35.00","0","FIC","Tapa dura","Historia de la familia Buendía","Literatura latinoamericana","Primera edición"
```

### Ejemplo 2: Libro de Texto Universitario

```csv
"Cálculo con geometría analítica","Larson, Ron","978-968-18-6186-8","McGraw-Hill","2006","2006","1024","BK","515","515 LAR","TEXTO001","ING","ING","Matemáticas","65.00","80.00","0","TEXTB","Tapa dura","Texto universitario de cálculo","Matemáticas -- Cálculo","9na edición"
```

### Ejemplo 3: Material de Referencia (No Prestable)

```csv
"Enciclopedia Britannica Vol. 5","Britannica Editorial","","Britannica","2020","2020","856","BK","030","REF 030 ENC v.5","REF001","ING","ING","Sala Referencia","120.00","150.00","1","REF","Tapa dura","Volumen 5: E-F","Enciclopedias","No prestable - Solo consulta"
```

### Ejemplo 4: Tesis

```csv
"Análisis de estructuras metálicas","Pérez González, María","","UNA","2023","2023","186","BK","624","624 PER","TESIS001","ING","ING","Sala Tesis","0.00","0.00","1","TESIS","Anillado","Tesis de grado en Ingeniería Civil","Ingeniería Civil -- Estructuras","Tesis de grado"
```

---

## 🔗 Integración con Sistema Existente

### Uso con tu Script Actual

Tu script `importar_biblioteca.sh` ya está optimizado. Para usar los ejemplos:

```bash
# 1. Coloca tu CSV en el directorio correcto
cp mi-catalogo.csv /home/mvillalba/migradatos/importar_aqui/ING.csv

# 2. Ejecuta el script de importación
cd /home/mvillalba/migradatos
./importar_biblioteca.sh ING

# 3. El script se encarga de todo automáticamente
```

### Validación Previa

Antes de importar un CSV grande, valida con una muestra pequeña:

```bash
# Crear CSV de prueba con 10 registros
head -11 ING.csv > ING_prueba.csv  # 1 línea de encabezado + 10 registros

# Importar prueba
./importar_biblioteca.sh ING_prueba

# Verificar en el OPAC
# Si todo está bien, importar el CSV completo
```

### Verificación Post-Importación

```bash
# Ver estadísticas de la importación
koha-mysql koha-cnc -e "
SELECT
    homebranch AS 'Biblioteca',
    COUNT(DISTINCT biblionumber) AS 'Títulos',
    COUNT(*) AS 'Ejemplares'
FROM items
WHERE dateaccessioned = CURDATE()
GROUP BY homebranch;
"

# Ver últimos 10 libros importados
koha-mysql koha-cnc -e "
SELECT
    b.title AS 'Título',
    b.author AS 'Autor',
    i.barcode AS 'Código',
    i.homebranch AS 'Biblioteca'
FROM biblio b
JOIN items i ON b.biblionumber = i.biblionumber
WHERE b.datecreated = CURDATE()
ORDER BY b.biblionumber DESC
LIMIT 10;
"
```

---

## 🎯 Checklist para CSV Óptimo

### Antes de Importar

- [ ] El archivo tiene extensión .csv
- [ ] La primera línea es el encabezado con nombres de columnas
- [ ] Todos los registros tienen **title**
- [ ] Todos los códigos de barras (**barcode**) son únicos
- [ ] Los códigos de biblioteca (**homebranch**) existen en Koha
- [ ] El **itemtype** es válido (BK, DVD, CD, etc.)
- [ ] Los campos de texto con comas están entrecomillados
- [ ] No hay líneas vacías al final del archivo

### Para OPAC Óptimo

- [ ] Incluye **author** en la mayoría de registros
- [ ] Incluye **isbn** cuando está disponible
- [ ] Incluye **abstract** para mejor descripción
- [ ] Incluye **subject** para búsqueda por materia
- [ ] Incluye **itemcallnumber** para organización
- [ ] Incluye **location** para ubicación física
- [ ] Incluye **ccode** para filtrado por colecciones

---

## 📞 Soporte y Documentación

- **Estructura SQL completa:** `/home/mvillalba/migradatos/docs/estructura-catalogo-didactica.sql`
- **CSV de ejemplo:** `/home/mvillalba/migradatos/docs/ejemplo-catalogo-completo.csv`
- **Guías del sistema:** `/home/mvillalba/migradatos/docs/`
- **Logs de importación:** `/home/mvillalba/migradatos/logs/`

---

## 🚀 Comandos Rápidos

```bash
# Ver estructura de ejemplo
cat /home/mvillalba/migradatos/docs/ejemplo-catalogo-completo.csv | less

# Consultar DDL didáctico
less /home/mvillalba/migradatos/docs/estructura-catalogo-didactica.sql

# Contar registros en CSV
wc -l /home/mvillalba/migradatos/importar_aqui/ING.csv

# Validar formato CSV
head -5 /home/mvillalba/migradatos/importar_aqui/ING.csv

# Ver últimos logs
tail -50 /home/mvillalba/migradatos/logs/import_*_latest.log
```

---

**Última actualización:** 25 de Octubre de 2025
**Sistema:** Koha UNA - Biblioteca Digital
