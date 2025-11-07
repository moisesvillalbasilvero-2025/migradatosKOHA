# 📘 GUÍA DIDÁCTICA: MIGRACIÓN DE DATOS BIBLIOGRÁFICOS A KOHA
## Para Desarrolladores e Informáticos

**Universidad Nacional de Asunción**
**Sistema:** Firebird 2.7.5 → Koha (MARC21)
**Nivel:** Intermedio
**Tiempo de lectura:** 20 minutos

---

## 🎯 OBJETIVO

Migrar datos bibliográficos desde múltiples bases de datos Firebird independientes (una por facultad) hacia un sistema unificado Koha usando el estándar internacional MARC21.

---

## 📚 CONCEPTOS BÁSICOS

### ¿Qué es MARC21?

**MARC** = **MA**chine-**R**eadable **C**ataloging (Catalogación Legible por Máquina)

Es un formato estándar internacional para representar información bibliográfica. Piensa en él como JSON pero para bibliotecas, creado en los años 60.

**Estructura básica:**
```
MARC Record
├── Leader (metadatos del registro)
├── Campos de control (001-009)
│   ├── 001: ID único
│   ├── 003: Código de institución
│   └── 008: Datos codificados
└── Campos de datos (010-999)
    ├── 100: Autor principal
    ├── 245: Título
    ├── 260/264: Editorial, lugar, año
    ├── 650/653: Materias/temas
    └── 952: Ejemplares físicos (específico Koha)
```

### ¿Qué es Koha?

Sistema de gestión bibliotecaria open-source. Es como un ERP pero para bibliotecas.

**Componentes:**
- **Catalogación:** Ingresar/editar registros bibliográficos
- **Circulación:** Préstamos, devoluciones
- **OPAC:** Catálogo público en línea (lo que ve el usuario final)
- **Adquisiciones:** Compras, presupuestos

---

## 🏗️ ARQUITECTURA DEL SISTEMA

### Situación Actual

```
┌──────────────────────────────────────────────────────────┐
│           BASES DE DATOS FIREBIRD (ACTUALES)              │
│                                                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  FACAGR DB  │  │  FACEN DB   │  │  FACMED DB  │     │
│  │             │  │             │  │             │     │
│  │ Servidor 1  │  │ Servidor 2  │  │ Servidor 3  │     │
│  │ 192.168.x.1 │  │ 192.168.x.2 │  │ 192.168.x.3 │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
│                                                           │
│  Cada facultad tiene:                                    │
│  - Su propia base de datos Firebird                      │
│  - Su propio servidor                                    │
│  - Estructura de tablas similar pero no idéntica         │
└──────────────────────────────────────────────────────────┘
```

### Objetivo Final

```
┌──────────────────────────────────────────────────────────┐
│              SISTEMA KOHA UNIFICADO                       │
│                                                           │
│  ┌───────────────────────────────────────────────────┐  │
│  │         Catálogo Único Multi-Biblioteca           │  │
│  │                                                   │  │
│  │  Biblioteca FACAGR ──┐                           │  │
│  │  Biblioteca FACEN   ───┼─── Base Datos Koha      │  │
│  │  Biblioteca FACMED  ──┘                           │  │
│  │                                                   │  │
│  │  Usuarios ven TODO desde un solo OPAC            │  │
│  └───────────────────────────────────────────────────┘  │
│                                                           │
│  Beneficios:                                             │
│  ✓ Búsqueda unificada en todas las bibliotecas          │
│  ✓ Préstamo interbibliotecario                          │
│  ✓ Estadísticas centralizadas                           │
│  ✓ Catálogo público profesional                         │
└──────────────────────────────────────────────────────────┘
```

---

## 🔄 FLUJO DE MIGRACIÓN

### Proceso Completo (3 Pasos)

```
┌─────────────┐      ┌─────────────┐      ┌─────────────┐
│  FIREBIRD   │ ───▶ │     CSV     │ ───▶ │   MARCXML   │ ───▶ ┌──────┐
│  Database   │      │  Intermedio │      │   Formato   │      │ KOHA │
└─────────────┘      └─────────────┘      └─────────────┘      └──────┘
   Origen             (Opcional)            Estándar            Destino

   Script:           Script:               Comando:
   firebird_         opac_                 bulkmarcimport.pl
   exporter.py       exportar.py
```

### Detalle de Cada Paso

#### PASO 1: Exportar desde Firebird

**Input:** Base de datos Firebird (.fdb)
**Output:** Archivo CSV con datos bibliográficos
**Script:** `firebird_exporter.py`

**¿Qué hace?**
1. Conecta al servidor Firebird remoto
2. Ejecuta query SQL adaptado a la estructura de esa biblioteca
3. Normaliza los datos (encoding, espacios, caracteres especiales)
4. Exporta a CSV con delimitador `;`

**Ejemplo de datos:**
```csv
codbiblio;titulo;autor;editorial;publicacion;isbn;ubicacion;nroacceso
FACAGR;El suelo;García, José;Editorial UNA;2023;978-xxx;631.4 G216s;AGR-0001
```

#### PASO 2: Convertir CSV a MARCXML

**Input:** Archivo CSV
**Output:** Archivo MARCXML (estándar internacional)
**Script:** `opac_exportar.py`

**¿Qué hace?**
1. Lee el CSV línea por línea
2. Mapea cada columna CSV a su campo MARC correspondiente
3. Genera XML válido según estándar MARC21
4. Valida que los campos obligatorios existan
5. Divide en archivos si es muy grande (streaming)

**Ejemplo de transformación:**

**CSV:**
```
titulo: El suelo y su formación
autor: García, José
```

**Se convierte en MARCXML:**
```xml
<datafield tag="100" ind1="1" ind2=" ">
  <subfield code="a">García, José</subfield>
  <subfield code="e">Autor</subfield>
</datafield>

<datafield tag="245" ind1="1" ind2="0">
  <subfield code="a">El suelo y su formación</subfield>
</datafield>
```

#### PASO 3: Importar a Koha

**Input:** Archivo MARCXML
**Output:** Registros en base de datos Koha
**Comando:** `bulkmarcimport.pl` (herramienta oficial de Koha)

**¿Qué hace?**
1. Lee el MARCXML
2. Valida contra esquema MARC21
3. Inserta en tablas de Koha:
   - `biblio` (registros bibliográficos)
   - `biblioitems` (datos físicos)
   - `items` (ejemplares)
4. Genera índices de búsqueda

---

## 📊 ESTRUCTURA DE DATOS

### Tablas en Firebird (Origen)

**Tabla BIBLIOGRAFICOS:**
```sql
CREATE TABLE BIBLIOGRAFICOS (
    ID_REGISTRO      INTEGER PRIMARY KEY,
    TITULO           VARCHAR(500),
    AUTOR            VARCHAR(200),
    EDITORIAL        VARCHAR(100),
    ANO_PUBLICACION  VARCHAR(4),
    ISBN             VARCHAR(20),
    CLASIFICACION    VARCHAR(50),
    RESUMEN          BLOB SUB_TYPE TEXT,
    MATERIAS         VARCHAR(500)
)
```

**Tabla EJEMPLARES:**
```sql
CREATE TABLE EJEMPLARES (
    ID_EJEMPLAR      INTEGER PRIMARY KEY,
    ID_BIBLIO        INTEGER REFERENCES BIBLIOGRAFICOS,
    CODIGO_BARRAS    VARCHAR(50),
    SIGNATURA        VARCHAR(50),
    UBICACION        VARCHAR(20),
    TIPO_MATERIAL    VARCHAR(30),
    FECHA_ADQUISICION DATE
)
```

### Tablas en Koha (Destino)

**Tabla `biblio`:**
```sql
CREATE TABLE biblio (
    biblionumber  INT AUTO_INCREMENT PRIMARY KEY,
    frameworkcode VARCHAR(4),
    author        TEXT,
    title         TEXT,
    abstract      TEXT
)
```

**Tabla `items`:**
```sql
CREATE TABLE items (
    itemnumber       INT AUTO_INCREMENT PRIMARY KEY,
    biblionumber     INT,
    homebranch       VARCHAR(10),    -- Biblioteca propietaria
    holdingbranch    VARCHAR(10),    -- Biblioteca física
    location         VARCHAR(80),    -- Ubicación dentro de biblioteca
    itemcallnumber   VARCHAR(255),   -- Signatura
    barcode          VARCHAR(20),    -- Código de barras ÚNICO
    itype            VARCHAR(10)     -- Tipo de ítem
)
```

---

## 🗺️ MAPEO DE DATOS

### Tabla de Mapeo Campo a Campo

| # | Firebird | CSV | MARC21 | Koha DB | Descripción |
|---|----------|-----|--------|---------|-------------|
| 1 | `ID_REGISTRO` | `analisis` | 001 | - | ID único del registro |
| 2 | - | `codbiblio` | 003, 952$a | `items.homebranch` | Código de biblioteca |
| 3 | `TITULO` | `titulo` | 245$a | `biblio.title` | **Título (OBLIGATORIO)** |
| 4 | `AUTOR` | `autor` | 100$a | `biblio.author` | Autor principal |
| 5 | `EDITORIAL` | `editorial` | 264$b | `biblioitems.publishercode` | Editorial |
| 6 | `ANO_PUBLICACION` | `publicacion` | 264$c | `biblioitems.publicationyear` | Año |
| 7 | `ISBN` | `isbn` | 020$a | `biblioitems.isbn` | ISBN |
| 8 | `CLASIFICACION` | `ubicacion` | 082$a | - | Dewey |
| 9 | `RESUMEN` | `sintesis` | 520$a | - | Resumen/Abstract |
| 10 | `MATERIAS` | `temas_descrip` | 653$a | - | Materias (separadas por ;) |
| 11 | `CODIGO_BARRAS` | `nroacceso` | 952$p | `items.barcode` | **Código barras (ÚNICO)** |
| 12 | `SIGNATURA` | `ubicacion` | 952$o | `items.itemcallnumber` | **Signatura/cota** |
| 13 | `UBICACION` | `loc` | 952$c | `items.location` | Ubicación física |
| 14 | `TIPO_MATERIAL` | `tipomaterial` | 952$y | `items.itype` | **Tipo de ítem** |

**Campos OBLIGATORIOS para Koha:**
- ✅ 245$a (Título)
- ✅ 952$a (Biblioteca propietaria)
- ✅ 952$b (Biblioteca física)
- ✅ 952$p (Código de barras)
- ✅ 952$y (Tipo de ítem)

---

## 💻 CÓDIGO EJEMPLO

### Ejemplo 1: Conectar a Firebird

```python
import fdb

# Configuración de conexión
config = {
    'host': '192.168.1.10',
    'port': 3050,
    'database': '/datos/biblio.fdb',
    'user': 'SYSDBA',
    'password': 'masterkey',
    'charset': 'UTF8'
}

# Conectar
conn = fdb.connect(**config)
cursor = conn.cursor()

# Ejecutar query
cursor.execute("""
    SELECT
        b.TITULO,
        b.AUTOR,
        e.CODIGO_BARRAS
    FROM BIBLIOGRAFICOS b
    LEFT JOIN EJEMPLARES e ON b.ID_REGISTRO = e.ID_BIBLIO
""")

# Procesar resultados
for row in cursor:
    titulo, autor, barcode = row
    print(f"{titulo} - {autor} [{barcode}]")

conn.close()
```

### Ejemplo 2: Generar MARCXML

```python
import xml.etree.ElementTree as ET

# Crear registro MARC
ns = "http://www.loc.gov/MARC21/slim"
record = ET.Element(f"{{{ns}}}record")

# Leader
leader = ET.SubElement(record, "leader")
leader.text = "00000nam a2200000 i 4500"

# Campo de control 001
cf001 = ET.SubElement(record, "controlfield", {"tag": "001"})
cf001.text = "000558"

# Campo de datos 245 (Título)
df245 = ET.SubElement(record, "datafield", {
    "tag": "245",
    "ind1": "1",
    "ind2": "0"
})
sf_a = ET.SubElement(df245, "subfield", {"code": "a"})
sf_a.text = "El suelo y su formación"

# Campo 952 (Ejemplar)
df952 = ET.SubElement(record, "datafield", {
    "tag": "952",
    "ind1": " ",
    "ind2": " "
})
sf_a = ET.SubElement(df952, "subfield", {"code": "a"})
sf_a.text = "FACAGR"  # homebranch
sf_p = ET.SubElement(df952, "subfield", {"code": "p"})
sf_p.text = "AGR-001234"  # barcode

# Convertir a string XML
xml_str = ET.tostring(record, encoding='unicode')
print(xml_str)
```

### Ejemplo 3: Importar a Koha

```bash
# Comando para importar MARCXML a Koha
sudo koha-shell koha-cnc -c "perl bulkmarcimport.pl \
  -b \
  -m MARCXML \
  -file /ruta/al/archivo.xml \
  -commit 1000"

# Parámetros:
# -b          : Modo bibliográfico
# -m MARCXML  : Formato de entrada
# -file       : Ruta del archivo
# -commit 1000: Hacer commit cada 1000 registros
```

---

## 🎓 EJEMPLO COMPLETO PASO A PASO

### Escenario

Migrar 1,000 registros de la Facultad de Ciencias Agrarias.

### Paso 1: Preparación

```bash
# 1. Verificar conectividad
telnet 192.168.1.10 3050

# 2. Verificar Python y librerías
python3 --version  # >= 3.8
pip3 install fdb   # Driver Firebird

# 3. Crear directorio de trabajo
mkdir -p /home/usuario/migracion_facagr
cd /home/usuario/migracion_facagr
```

### Paso 2: Configurar Script de Exportación

Editar `firebird_exporter.py` líneas 25-35:

```python
'FACAGR': {
    'nombre': 'Facultad de Ciencias Agrarias',
    'host': '192.168.1.10',      # ← IP REAL
    'port': 3050,
    'database': '/datos/biblio.fdb',  # ← RUTA REAL
    'user': 'SYSDBA',
    'password': 'password_real', # ← PASSWORD REAL
    'charset': 'UTF8'
}
```

### Paso 3: Exportar desde Firebird

```bash
python3 firebird_exporter.py --biblioteca FACAGR --output FACAGR.csv

# Output esperado:
# Conectando a Firebird: 192.168.1.10:3050
# ✓ Conexión exitosa
# Tablas encontradas: 15
# Ejecutando query de exportación...
# Progreso: 500/1000 registros (50%)
# ✓ Exportación completada: FACAGR.csv
#
# ESTADÍSTICAS:
# Registros leídos: 1000
# Registros escritos: 998
# Errores: 2
```

### Paso 4: Convertir a MARCXML

```bash
python3 opac_exportar.py \
  -i FACAGR.csv \
  --codbiblio FACAGR \
  --loc-default SALA \
  --stream \
  --split-by 5000

# Output esperado:
# → escribiendo: FACAGR_20251015_marcxml.xml
# ✅ Listo (stream/split).
```

### Paso 5: Validar MARCXML

```bash
# Verificar que es XML válido
xmllint --noout FACAGR_20251015_marcxml.xml
echo $?  # Debe ser 0 (sin errores)

# Ver primeros registros
head -100 FACAGR_20251015_marcxml.xml

# Contar registros
grep -c "<record>" FACAGR_20251015_marcxml.xml
# Debe dar: 998
```

### Paso 6: Configurar Koha

**En la interfaz web de Koha:**

1. **Crear biblioteca:**
   - Administration > Libraries > New library
   - Code: `FACAGR`
   - Name: `Facultad de Ciencias Agrarias`

2. **Crear ubicaciones:**
   - Administration > Authorized values > LOC
   - Agregar: `SALA`, `REF`, `DEP`, `TESIS`

3. **Verificar tipos de ítem:**
   - Administration > Item types
   - Verificar: `BK` (Libro), `MG` (Revista), `TES` (Tesis)

### Paso 7: Importar a Koha (Prueba)

```bash
# Importar lote de prueba (primeros 100 registros)
head -110 FACAGR_20251015_marcxml.xml > prueba.xml
echo "</collection>" >> prueba.xml

sudo koha-shell koha-cnc -c "perl bulkmarcimport.pl \
  -b \
  -m MARCXML \
  -file /home/usuario/migracion_facagr/prueba.xml \
  -commit 100"

# Verificar en OPAC:
# http://tu-koha.una.py/cgi-bin/koha/opac-search.pl?q=FACAGR
```

### Paso 8: Importar Completo

```bash
sudo koha-shell koha-cnc -c "perl bulkmarcimport.pl \
  -b \
  -m MARCXML \
  -file /home/usuario/migracion_facagr/FACAGR_20251015_marcxml.xml \
  -commit 1000" 2>&1 | tee import_log.txt

# Monitorear progreso
tail -f import_log.txt
```

### Paso 9: Reconstruir Índices

```bash
# Zebra (búsqueda tradicional)
sudo koha-rebuild-zebra -f -v koha-cnc

# O Elasticsearch (si está configurado)
sudo koha-elasticsearch --rebuild -v koha-cnc
```

### Paso 10: Verificación

```bash
# Contar registros importados
sudo koha-mysql koha-cnc -e "
  SELECT COUNT(*) as total
  FROM biblio
"

# Ver ítems por biblioteca
sudo koha-mysql koha-cnc -e "
  SELECT
    homebranch,
    COUNT(*) as items
  FROM items
  GROUP BY homebranch
"

# Buscar un título específico
sudo koha-mysql koha-cnc -e "
  SELECT biblionumber, title, author
  FROM biblio
  WHERE title LIKE '%suelo%'
  LIMIT 5
"
```

---

## ⚠️ ERRORES COMUNES Y SOLUCIONES

### Error 1: "Biblioteca no encontrada"

**Síntoma:**
```
DBD::mysql::st execute failed: Cannot add or update...
foreign key constraint fails (homebranch)
```

**Causa:** La biblioteca `FACAGR` no existe en Koha.

**Solución:**
```bash
# Verificar bibliotecas existentes
sudo koha-mysql koha-cnc -e "SELECT branchcode, branchname FROM branches"

# Crear si falta (interfaz web o SQL)
```

### Error 2: "Barcode duplicado"

**Síntoma:**
```
Duplicate entry 'AGR-0001' for key 'barcode'
```

**Causa:** Ya existe un ítem con ese código de barras.

**Solución:**
```bash
# Buscar duplicados en CSV antes de importar
cut -d';' -f7 FACAGR.csv | sort | uniq -d

# O agregar prefijo único
sed 's/^\([0-9]\)/FACAGR-\1/' FACAGR.csv > FACAGR_fixed.csv
```

### Error 3: "XML malformado"

**Síntoma:**
```
parser error : Opening and ending tag mismatch
```

**Causa:** Caracteres especiales mal escapados.

**Solución:**
```bash
# Verificar encoding
file -i FACAGR.csv

# Convertir si es necesario
iconv -f LATIN1 -t UTF-8 FACAGR.csv > FACAGR_utf8.csv

# Regenerar MARCXML
python3 opac_exportar.py -i FACAGR_utf8.csv ...
```

---

## 📈 MÉTRICAS Y TIEMPOS

### Tabla de Rendimiento

| Registros | Exportación FB | Conversión CSV→XML | Importación Koha | Total |
|-----------|----------------|-------------------|------------------|-------|
| 1,000 | ~2 min | ~1 min | ~3 min | ~6 min |
| 10,000 | ~15 min | ~5 min | ~20 min | ~40 min |
| 50,000 | ~60 min | ~20 min | ~90 min | ~3 horas |
| 100,000 | ~120 min | ~40 min | ~180 min | ~5.5 horas |

**Factores que afectan:**
- Velocidad de red (Firebird remoto)
- Complejidad de registros (largo de resumen, cantidad de materias)
- CPU del servidor Koha
- Uso de SSD vs HDD

---

## ✅ CHECKLIST DE VALIDACIÓN

Antes de considerar la migración exitosa:

- [ ] **Cantidad de registros**
  - Registros en Firebird = Registros en Koha

- [ ] **Datos críticos**
  - Todos los títulos se importaron
  - Autores están presentes
  - Códigos de barras únicos

- [ ] **Búsqueda funcional**
  - Buscar por título funciona
  - Buscar por autor funciona
  - Buscar por materia funciona

- [ ] **Visualización OPAC**
  - Registros se ven completos
  - Ejemplares aparecen correctamente
  - Ubicaciones son correctas

- [ ] **Integridad relacional**
  - Cada ítem tiene su registro bibliográfico
  - No hay registros huérfanos

---

## 📚 GLOSARIO TÉCNICO

| Término | Significado |
|---------|-------------|
| **MARC21** | Formato estándar para representar datos bibliográficos |
| **MARCXML** | MARC en formato XML |
| **Leader** | Primera línea de un registro MARC, contiene metadatos del registro |
| **Datafield** | Campo de datos MARC con tag numérico (ej: 245 para título) |
| **Subfield** | Subdivisión de un datafield identificada por una letra (ej: $a, $b) |
| **Indicator** | Valores numéricos que modifican el comportamiento de un campo |
| **homebranch** | Biblioteca propietaria de un ítem |
| **holdingbranch** | Biblioteca donde está físicamente un ítem |
| **itype** | Tipo de ítem (libro, revista, tesis, etc.) |
| **barcode** | Código de barras único de un ejemplar |
| **biblionumber** | ID único de un registro bibliográfico en Koha |
| **itemnumber** | ID único de un ejemplar en Koha |
| **OPAC** | Online Public Access Catalog (catálogo público) |
| **ILS** | Integrated Library System (sistema integrado de biblioteca) |

---

## 🔗 RECURSOS ADICIONALES

### Documentación Oficial

- **Koha Manual:** https://koha-community.org/manual/
- **MARC21:** https://www.loc.gov/marc/bibliographic/
- **Firebird:** https://firebirdsql.org/en/documentation/

### Comunidad

- **Koha Community:** https://koha-community.org/
- **Lista de correo Koha:** https://lists.koha-community.org/

### Herramientas

- **MARCEdit:** Software para editar registros MARC
- **pymarc:** Librería Python para trabajar con MARC
- **yaz-marcdump:** Herramienta CLI para validar MARC

---

## 📞 SOPORTE

**Para preguntas técnicas:**
- Email: soporte.biblioteca@una.py
- Documentación local: `/home/mvillalba/migradatos/`

**Para reportar problemas:**
1. Incluir mensaje de error completo
2. Archivo de log
3. Muestra de datos problemáticos (CSV o XML)
4. Pasos para reproducir

---

**Última actualización:** 2025-01-15
**Versión:** 1.0
**Autor:** Sistema de Biblioteca UNA

