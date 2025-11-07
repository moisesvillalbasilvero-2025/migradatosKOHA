# 📚 Guía del Sistema de Mapeo - ULTRA DIDÁCTICA

**Sistema de Mapeo Paramétrico CSV/JSON → MARC21 → Koha**

---

## 🎯 ¿Qué es el Sistema de Mapeo?

El sistema de mapeo es un **"traductor"** que convierte tus datos bibliográficos (ya sea desde un archivo CSV o desde datos JSON de la API) al formato MARC21 que entiende Koha.

```
┌─────────────────┐
│  TUS DATOS      │  ← Pueden venir de CSV o API (JSON)
│                 │
│ Titulo: "..."   │
│ Autor: "..."    │
│ Editorial: "..."│
└────────┬────────┘
         │
         ↓
┌────────────────────┐
│ SISTEMA DE MAPEO   │  ← Este archivo config/mapeo_campos.json
│                    │
│ Define reglas de   │
│ conversión         │
└────────┬───────────┘
         │
         ↓
┌────────────────────┐
│   MARCXML          │  ← Formato estándar bibliotecario
│                    │
│ 245 $a Titulo      │
│ 100 $a Autor       │
│ 260 $b Editorial   │
└────────┬───────────┘
         │
         ↓
┌────────────────────┐
│   KOHA OPAC        │  ← Base de datos de la biblioteca
└────────────────────┘
```

---

## 📖 Índice

1. [Conceptos Básicos](#conceptos-básicos)
2. [Estructura del Archivo de Mapeo](#estructura-del-archivo-de-mapeo)
3. [Mapeo de Columnas CSV](#mapeo-de-columnas-csv)
4. [Mapeo a MARC21](#mapeo-a-marc21)
5. [Cómo Agregar Nuevos Campos](#cómo-agregar-nuevos-campos)
6. [Ejemplos Prácticos](#ejemplos-prácticos)
7. [Casos de Uso Reales](#casos-de-uso-reales)
8. [Solución de Problemas](#solución-de-problemas)

---

## 1️⃣ Conceptos Básicos

### ¿Qué es MARC21?

MARC21 es el **formato estándar internacional** para describir materiales bibliográficos. Es como el "idioma universal" de las bibliotecas.

**Estructura básica:**
- **Tag (Etiqueta):** Número de 3 dígitos que identifica el tipo de información
  - Ejemplos: 245 = Título, 100 = Autor, 260 = Editorial

- **Indicators (Indicadores):** 2 caracteres que dan contexto adicional
  - Ejemplo: 245 1 0 significa "hay autor principal" y "sin artículos iniciales"

- **Subfields (Subcampos):** Partes específicas de la información, marcadas con $
  - Ejemplo: 245 $a (título) $b (subtítulo) $c (responsabilidad)

**Ejemplo completo:**
```
245 10 $a Cien años de soledad $b una novela $c Gabriel García Márquez
│   │  │   │                     │            │
│   │  │   └─ Título             └─Subtítulo  └─ Autor
│   │  └─ Subcampo 'a'
│   └─ Indicadores (1 = hay autor, 0 = sin artículos)
└─ Tag 245 (campo de título)
```

### Dos Métodos de Importación

#### Método 1: CLI con CSV (Actual)
```bash
# Tienes un archivo CSV con tus datos
python3 scripts/opac_exportar.py --input biblioteca.csv --codbiblio MED
```
**Flujo:** `CSV → Mapeo → MARCXML → Koha`

#### Método 2: API con JSON (Nuevo)
```bash
# Envías datos JSON directamente
curl -X POST http://localhost:8000/api/v1/import \
     -H "Content-Type: application/json" \
     -d '{"titulo": "Mi libro", "autor": "Juan Pérez", ...}'
```
**Flujo:** `JSON → Mapeo → MARCXML → Koha`

**¡IMPORTANTE:** Ambos métodos usan el MISMO sistema de mapeo (`config/mapeo_campos.json`)

---

## 2️⃣ Estructura del Archivo de Mapeo

El archivo `config/mapeo_campos.json` tiene 3 secciones principales:

```json
{
  "mapeo_columnas_csv": {
    // Define qué nombres pueden tener tus campos
  },

  "mapeo_marc21": {
    // Define cómo se convierten a MARC21
  },

  "mapeo_tipos_material": {
    // Define tipos de material (Libro, DVD, etc.)
  }
}
```

### Sección 1: mapeo_columnas_csv

**¿Para qué sirve?**
Define todas las **variantes posibles** de nombres de columnas.

**¿Por qué es útil?**
Tu CSV puede tener "Título", "titulo", "TITULO", "title"... todos se reconocen.

**Ejemplo:**
```json
"titulo": {
  "nombre_legible": "Título",
  "descripcion": "Título principal de la obra",
  "variantes_csv": ["titulo", "título", "tÃ­tulo", "title", "titulo_principal"],
  "obligatorio": true,
  "ejemplo": "Cien años de soledad"
}
```

**Explicación:**
- `nombre_legible`: Nombre para humanos
- `descripcion`: Qué representa este campo
- `variantes_csv`: TODAS las formas en que puede aparecer en tu CSV
- `obligatorio`: true si es requerido, false si es opcional
- `ejemplo`: Un valor de ejemplo real

### Sección 2: mapeo_marc21

**¿Para qué sirve?**
Define cómo cada campo lógico se convierte a MARC21.

**Ejemplo:**
```json
"245": {
  "nombre": "Título",
  "fuente": "titulo + sub_titulo + mencion",
  "subfields": {
    "a": "Título principal",
    "b": "Subtítulo",
    "c": "Mención de responsabilidad"
  },
  "indicadores": {
    "ind1": "0 si no hay autor, 1 si hay",
    "ind2": "0 (sin artículos iniciales)"
  },
  "ejemplo": "245 10 $a Cien años de soledad $b una historia $c Gabriel García Márquez",
  "obligatorio": true
}
```

### Sección 3: mapeo_tipos_material

**¿Para qué sirve?**
Convierte nombres legibles a códigos Koha.

**Ejemplo:**
```json
"mapeo_tipos_material": {
  "Monografía": "BK",
  "Libro": "BK",
  "Revista": "MG",
  "DVD": "VM"
}
```

---

## 3️⃣ Mapeo de Columnas CSV

### Campos Obligatorios

#### 📖 Título (titulo)
```json
"titulo": {
  "variantes_csv": ["titulo", "título", "title"],
  "obligatorio": true
}
```
**En tu CSV puede ser:** `Titulo`, `TITULO`, `title`, etc.
**Se mapea a MARC21:** 245 $a

#### 🏢 Código de Biblioteca (codbiblio)
```json
"codbiblio": {
  "variantes_csv": ["codbiblio", "biblioteca", "branch"],
  "obligatorio": false,
  "ejemplo": "MED, FACEN, POL"
}
```
**En tu CSV puede ser:** `Biblioteca`, `branch`, etc.
**Se usa para:** Identificar la facultad/biblioteca propietaria

### Campos Opcionales (Pero Recomendados)

#### 👤 Autor (autor)
```json
"autor": {
  "variantes_csv": ["autor", "author", "autor_personal"],
  "obligatorio": false,
  "ejemplo": "García Márquez, Gabriel"
}
```
**Formato recomendado:** Apellido, Nombre
**Se mapea a MARC21:** 100 $a

#### 📅 Año de Publicación (publicacion)
```json
"publicacion": {
  "variantes_csv": ["publicacion", "año", "anio", "year"],
  "obligatorio": false,
  "ejemplo": "1967, 2023"
}
```
**Formatos aceptados:** 1967, 2023, etc.
**Se mapea a MARC21:** 264 $c y parte del campo 008

#### 🏭 Editorial (editorial)
```json
"editorial": {
  "variantes_csv": ["editorial", "publisher"],
  "obligatorio": false,
  "ejemplo": "Editorial Sudamericana"
}
```
**Se mapea a MARC21:** 264 $b

#### 📊 ISBN (isbn)
```json
"isbn": {
  "variantes_csv": ["isbn", "issn", "isbn_issn"],
  "obligatorio": false,
  "ejemplo": "978-0-307-47472-8"
}
```
**Formatos aceptados:** Con o sin guiones
**Se mapea a MARC21:** 020 $a

### Campos de Ejemplar (Item)

#### 🏷️ Código de Barras (nroacceso)
```json
"nroacceso": {
  "variantes_csv": ["nroacceso", "barcode", "codigo_barras"],
  "obligatorio": false,
  "ejemplo": "MED-001234"
}
```
**Se mapea a MARC21:** 952 $p (código de barras del ejemplar)

#### 📍 Signatura/Cota (ubicacion)
```json
"ubicacion": {
  "variantes_csv": ["ubicacion", "signatura", "cota", "callnumber"],
  "obligatorio": false,
  "ejemplo": "860.5 GAR"
}
```
**Se mapea a MARC21:** 952 $o (call number)

#### 🗂️ Ubicación Física (loc)
```json
"loc": {
  "variantes_csv": ["loc", "ubicacion_fisica", "location_code"],
  "obligatorio": false,
  "ejemplo": "GEN, REF, TESIS"
}
```
**Valores típicos:**
- `GEN` = Colección General
- `REF` = Referencia
- `TESIS` = Sala de Tesis
- `RES` = Reserva

**Se mapea a MARC21:** 952 $c

---

## 4️⃣ Mapeo a MARC21

### Campos de Control (001-008)

#### 001 - Número de Control
```
Fuente: analisis | nroacceso | generado automáticamente
Formato:
  - Si existe 'analisis': ANL:12345
  - Si existe 'nroacceso': BC:MED-001234
  - Sino: HX:ab12cd34ef (hash único)
```

#### 003 - Código de Control
```
Fuente: codbiblio
Valor: MED, FACEN, POL, etc.
Propósito: Identificar la biblioteca que creó el registro
```

#### 005 - Timestamp
```
Fuente: Generado automáticamente
Formato: 20251107143025.0 (YYYYMMDDhhmmss.f)
Propósito: Última fecha de modificación
```

#### 008 - Datos de Longitud Fija
```
Fuente: publicacion + idioma + país
Formato: DDMMYY s YYYY país______________ idioma
Ejemplo: 251107s1967    py                 spa
         │      │ │      │                   │
         │      │ │      └─ País (py = Paraguay)
         │      │ └─ Año de publicación (1967)
         │      └─ Tipo fecha (s = single date)
         └─ Fecha entrada (07 nov 2025)
```

### Campos de Datos (010-999)

#### 020 - ISBN
```
Tag: 020
Ind1: (espacio)
Ind2: (espacio)
Subfields:
  $a - Número ISBN

Ejemplo de CSV:
  isbn: "978-0-307-47472-8"

Resultado MARC:
  020   $a 978-0-307-47472-8
```

#### 100 - Autor Personal
```
Tag: 100
Ind1: 1 (apellido, nombre)
Ind2: (espacio)
Subfields:
  $a - Nombre del autor

Ejemplo de CSV:
  autor: "García Márquez, Gabriel"

Resultado MARC:
  100 1 $a García Márquez, Gabriel

NOTA: Solo se crea si existe 'autor' (persona física)
```

#### 110 - Autor Institucional
```
Tag: 110
Ind1: 2 (nombre en orden directo)
Ind2: (espacio)
Subfields:
  $a - Nombre de la institución

Ejemplo de CSV:
  autorinst: "Universidad Nacional de Asunción"

Resultado MARC:
  110 2 $a Universidad Nacional de Asunción

NOTA: Solo se crea si existe 'autorinst' y NO existe 'autor'
```

#### 245 - Título (OBLIGATORIO)
```
Tag: 245
Ind1:
  0 = No hay autor/autorinst en 1XX
  1 = Hay autor/autorinst en 1XX
Ind2: 0 (número de caracteres a ignorar para ordenar)
Subfields:
  $a - Título principal (OBLIGATORIO)
  $b - Subtítulo
  $c - Mención de responsabilidad

Ejemplo de CSV:
  titulo: "Cien años de soledad"
  sub_titulo: "una novela"
  mencion: "Gabriel García Márquez"

Resultado MARC:
  245 10 $a Cien años de soledad $b una novela $c Gabriel García Márquez
```

#### 250 - Edición
```
Tag: 250
Subfields:
  $a - Mención de edición

Ejemplo de CSV:
  edicion: "2a ed."

Resultado MARC:
  250   $a 2a ed.
```

#### 264 - Publicación
```
Tag: 264
Ind1: (espacio)
Ind2: 1 (publicación)
Subfields:
  $a - Lugar de publicación
  $b - Editorial
  $c - Año

Ejemplo de CSV:
  procedencia: "Buenos Aires"
  editorial: "Editorial Sudamericana"
  publicacion: "1967"

Resultado MARC:
  264  1 $a Buenos Aires $b Editorial Sudamericana $c 1967
```

#### 650 - Materia (Puede ser múltiple)
```
Tag: 650
Ind1: (espacio)
Ind2: 4 (fuente no especificada)
Subfields:
  $a - Término de materia

Ejemplo de CSV:
  materia: "Literatura latinoamericana; Narrativa colombiana; Realismo mágico"

Resultado MARC:
  650  4 $a Literatura latinoamericana
  650  4 $a Narrativa colombiana
  650  4 $a Realismo mágico

NOTA: Se crea UN campo 650 por cada tema (separados por punto y coma)
```

#### 942 - Tipo de Documento (Koha)
```
Tag: 942
Subfields:
  $c - Tipo de ítem (itype)

Ejemplo de CSV:
  tipomaterial: "Monografía"

Mapeo (según mapeo_tipos_material):
  "Monografía" → "BK"

Resultado MARC:
  942   $c BK
```

#### 952 - Datos del Ejemplar (Koha - MUY IMPORTANTE)
```
Tag: 952
Subfields (principales):
  $a - homebranch (biblioteca propietaria) - OBLIGATORIO
  $b - holdingbranch (biblioteca actual)
  $c - location (ubicación física: GEN, REF, etc.)
  $o - itemcallnumber (signatura/cota)
  $p - barcode (código de barras) - OBLIGATORIO
  $y - itype (tipo de material)
  $h - copynumber (volumen/tomo)
  $d - dateaccessioned (fecha de adquisición)
  $g - price (precio)

Ejemplo de CSV:
  codbiblio: "MED"
  nroacceso: "MED-001234"
  ubicacion: "860.5 GAR"
  loc: "GEN"
  tipomaterial: "Monografía"
  volumen: "Vol. 1"
  fechaadq: "2023-05-15"
  precio: "25000"

Resultado MARC:
  952   $a MED $b MED $c GEN $o 860.5 GAR $p MED-001234 $y BK $h Vol. 1 $d 2023-05-15 $g 25000

EXPLICACIÓN de cada subcampo:
  $a MED         → Esta biblioteca es la propietaria
  $b MED         → Actualmente está en esta biblioteca
  $c GEN         → Ubicación física: Colección General
  $o 860.5 GAR   → Signatura/cota para encontrarlo en el estante
  $p MED-001234  → Código de barras para préstamos
  $y BK          → Tipo: Book (Monografía)
  $h Vol. 1      → Es el volumen 1
  $d 2023-05-15  → Adquirido el 15 de mayo de 2023
  $g 25000       → Costó 25000 (guaraníes)
```

---

## 5️⃣ Cómo Agregar Nuevos Campos

### Caso Práctico: Agregar campo "Idioma Original"

**Situación:** Quieres registrar el idioma en que se escribió originalmente el libro.

#### Paso 1: Identifica tu columna CSV
Tu CSV tiene una columna llamada `idioma_orig`:
```csv
titulo,autor,editorial,idioma_orig
"El principito","Saint-Exupéry, Antoine de","Salamandra","francés"
```

#### Paso 2: Agrega a mapeo_columnas_csv
Abre `config/mapeo_campos.json` y agrega en la sección `mapeo_columnas_csv`:

```json
"idioma_original": {
  "nombre_legible": "Idioma Original",
  "descripcion": "Idioma en que se escribió originalmente la obra",
  "variantes_csv": ["idioma_orig", "idioma_original", "original_language", "idioma"],
  "obligatorio": false,
  "ejemplo": "español, francés, inglés"
}
```

#### Paso 3: Consulta estándar MARC21
Ve a https://www.loc.gov/marc/bibliographic/ y busca el campo apropiado.

Para idiomas, encontrarás: **041 - Código de Idioma**

#### Paso 4: Agrega a mapeo_marc21
En la sección `mapeo_marc21`, agrega:

```json
"idioma": {
  "041": {
    "nombre": "Código de Idioma",
    "fuente": "idioma_original",
    "subfields": {
      "a": "Código de idioma (ISO 639-2, 3 letras)"
    },
    "ejemplo": "041   $a fre",
    "nota": "Requiere convertir nombre a código: 'francés' → 'fre', 'español' → 'spa'"
  }
}
```

#### Paso 5: Crea tabla de conversión (si necesitas)
Si tu CSV usa nombres y MARC requiere códigos, agrega:

```json
"mapeo_idiomas": {
  "_explicacion": "Convierte nombres de idiomas a códigos ISO 639-2",
  "español": "spa",
  "francés": "fre",
  "inglés": "eng",
  "portugués": "por",
  "alemán": "ger",
  "italiano": "ita"
}
```

#### Paso 6: Modifica el código (solo si es necesario)
Si necesitas lógica especial (como convertir nombres a códigos), edita `scripts/opac_exportar.py`:

```python
# Agregar en la clase Converter
def get_language_code(self, lang_name: str) -> str:
    """Convierte nombre de idioma a código ISO 639-2"""
    mapeo = self.config.get('mapeo_idiomas', {})
    return mapeo.get(lang_name.lower(), 'und')  # 'und' = undetermined

# Agregar en create_record()
idioma_original = normalize_text(row.get(colmap.get("idioma_original", ""), ""))
if idioma_original:
    codigo_idioma = self.get_language_code(idioma_original)
    add_datafield(rec, "041", [("a", codigo_idioma)])
```

#### Paso 7: Prueba con archivo pequeño
```bash
# Crear CSV de prueba
cat > test_idioma.csv <<EOF
titulo,autor,idioma_orig
"El principito","Saint-Exupéry","francés"
EOF

# Probar en dry-run
python3 scripts/opac_exportar.py \
  --input test_idioma.csv \
  --codbiblio TEST \
  --config config/mapeo_campos.json

# Verificar el XML generado
cat TEST_*_marcxml.xml | grep "041"
# Debería mostrar: <datafield tag="041">...
```

---

## 6️⃣ Ejemplos Prácticos

### Ejemplo 1: CSV Básico

**Tu CSV:**
```csv
titulo,autor,editorial,año
"Cien años de soledad","García Márquez, Gabriel","Sudamericana","1967"
```

**Configuración necesaria:** ¡Ya está lista! El mapeo por defecto reconoce estos campos.

**Comando:**
```bash
python3 scripts/opac_exportar.py -i libros.csv --codbiblio MED
```

**MARCXML generado:**
```xml
<record>
  <controlfield tag="001">HX:abc123def4</controlfield>
  <controlfield tag="003">MED</controlfield>
  <datafield tag="100" ind1="1" ind2=" ">
    <subfield code="a">García Márquez, Gabriel</subfield>
  </datafield>
  <datafield tag="245" ind1="1" ind2="0">
    <subfield code="a">Cien años de soledad</subfield>
  </datafield>
  <datafield tag="264" ind1=" " ind2="1">
    <subfield code="b">Sudamericana</subfield>
    <subfield code="c">1967</subfield>
  </datafield>
  <datafield tag="952">
    <subfield code="a">MED</subfield>
    <subfield code="b">MED</subfield>
    <subfield code="y">BK</subfield>
    <subfield code="p">MED-0000001</subfield>
  </datafield>
</record>
```

### Ejemplo 2: CSV con Columnas Personalizadas

**Tu CSV:**
```csv
Título Completo,Escritor,Casa Editorial,Publicado,Código Barra
"Don Quijote","Cervantes","Planeta","1605","MED-12345"
```

**¿Funcionará?** ¡SÍ! Gracias al mapeo flexible:
- "Título Completo" → reconocido como `titulo` (por variantes)
- "Escritor" → necesitas agregar a variantes de `autor`

**Modificación en mapeo_campos.json:**
```json
"autor": {
  "variantes_csv": ["autor", "author", "autor_personal", "Escritor"],
  // ← Agregar "Escritor"
}
```

### Ejemplo 3: CSV con Múltiples Materias

**Tu CSV:**
```csv
titulo,materia
"Introducción a la Física","Física; Ciencia; Educación"
```

**MARCXML generado:**
```xml
<datafield tag="650" ind1=" " ind2="4">
  <subfield code="a">Física</subfield>
</datafield>
<datafield tag="650" ind1=" " ind2="4">
  <subfield code="a">Ciencia</subfield>
</datafield>
<datafield tag="650" ind1=" " ind2="4">
  <subfield code="a">Educación</subfield>
</datafield>
```
**¡Automático!** El sistema divide por punto y coma.

---

## 7️⃣ Casos de Uso Reales

### Caso 1: Biblioteca de Medicina (MED)

**CSV de entrada:**
```csv
titulo,autor,editorial,año,materia,isbn,barcode,signatura
"Gray's Anatomy","Gray, Henry","Elsevier","2020","Anatomía; Medicina","978-0-7020-7705-0","MED-5001","611 GRA"
```

**Características:**
- ISBN válido
- Materia específica de medicina
- Signatura Dewey (611 = Anatomía)
- Código de barras con prefijo MED

**Comando:**
```bash
python3 scripts/opac_exportar.py \
  -i medicina.csv \
  --codbiblio MED \
  --loc-default GEN
```

**Resultado:** Importación perfecta con todos los campos mapeados.

### Caso 2: Biblioteca de Agronomía (AGRO) con Ubicaciones

**CSV con ubicación física:**
```csv
titulo,autor,ubicacion_fisica,signatura
"Cultivos Tropicales","Pérez, Juan","LABORATORIO","630 PER"
"Suelos del Paraguay","González, María","INVESTIGACION","631.4 GON"
```

**Configuración especial (mapeo de ubicaciones):**

Crear `config/loc_map_agro.json`:
```json
{
  "LABORATORIO": "LAB",
  "INVESTIGACION": "INV",
  "GENERAL": "GEN"
}
```

**Comando:**
```bash
python3 scripts/opac_exportar.py \
  -i agronomia.csv \
  --codbiblio AGRO \
  --loc-map config/loc_map_agro.json
```

**MARCXML generado:**
```xml
<datafield tag="952">
  <subfield code="a">AGRO</subfield>
  <subfield code="b">AGRO</subfield>
  <subfield code="c">LAB</subfield>  ← Mapeado desde "LABORATORIO"
  <subfield code="o">630 PER</subfield>
</datafield>
```

### Caso 3: Biblioteca de Politécnica (POL) con DVDs

**CSV de materiales audiovisuales:**
```csv
titulo,tipo,año,duracion
"Curso de AutoCAD Básico","DVD","2023","120 min"
"Tutorial SolidWorks","DVD","2022","180 min"
```

**Mapeo de tipos:**
```json
"mapeo_tipos_material": {
  "DVD": "VM",
  "Video": "VM",
  "CD-ROM": "MU"
}
```

**Comando:**
```bash
python3 scripts/opac_exportar.py \
  -i audiovisuales.csv \
  --codbiblio POL
```

**MARCXML generado:**
```xml
<datafield tag="942">
  <subfield code="c">VM</subfield>  ← VM = Visual Materials
</datafield>
<datafield tag="952">
  <subfield code="y">VM</subfield>
</datafield>
```

---

## 8️⃣ Solución de Problemas

### Problema 1: "No se encontró columna de título"

**Error:**
```
❌ No se encontró columna de título.
```

**Causa:** Tu CSV tiene la columna título con un nombre no reconocido.

**Solución:**
```bash
# 1. Ver las columnas de tu CSV
head -1 mi_archivo.csv

# Salida ejemplo:
# Título_Libro,Autor_Principal,Editorial

# 2. Agregar "Título_Libro" a las variantes en mapeo_campos.json
"titulo": {
  "variantes_csv": ["titulo", "título", "title", "Título_Libro"]
}
```

### Problema 2: Tipos de material no reconocidos

**Síntoma:** Todos los items aparecen como "BK" (libro) en Koha.

**Causa:** El valor en tu CSV no está en `mapeo_tipos_material`.

**Tu CSV dice:**
```csv
tipomaterial
Libro Físico
```

**Solución:** Agregar a mapeo:
```json
"mapeo_tipos_material": {
  "Libro Físico": "BK",
  "Libro": "BK"
}
```

### Problema 3: Códigos de barras duplicados

**Error:**
```
⚠ WARNING: Código de barras duplicado: MED-0000001
```

**Causa:** Múltiples filas sin código de barras único.

**Solución 1 - Proporcionar códigos únicos en CSV:**
```csv
titulo,barcode
"Libro 1","MED-001"
"Libro 2","MED-002"
```

**Solución 2 - Dejar que se generen automáticamente:**
El sistema genera: `{codbiblio}-{numero:07d}`
- MED-0000001
- MED-0000002
- etc.

### Problema 4: Materias no se separan

**Síntoma:** Todo el campo materia va a un solo 650.

**Tu CSV:**
```csv
materia
"Física,Ciencia,Educación"
```

**Problema:** Usas comas, el sistema espera punto y coma.

**Solución:** Cambiar separador a punto y coma:
```csv
materia
"Física; Ciencia; Educación"
```

### Problema 5: Caracteres especiales se ven mal

**Síntoma:** `GarcÃ­a` en vez de `García`

**Causa:** Encoding incorrecto del CSV.

**Solución:**
```bash
# Convertir CSV a UTF-8
iconv -f CP1252 -t UTF-8 archivo_original.csv > archivo_utf8.csv

# O especificar encoding en Excel:
# Al guardar: "CSV UTF-8 (delimitado por comas)"
```

---

## 📌 Resumen Rápido

### ✅ Campos OBLIGATORIOS
- **Título** (245 $a)

### 🌟 Campos MUY RECOMENDADOS
- **Autor** (100 $a o 110 $a)
- **Código de Biblioteca** (952 $a/$b)
- **Código de Barras** (952 $p)

### 📋 Campos OPCIONALES pero útiles
- Editorial (264 $b)
- Año (264 $c)
- ISBN (020 $a)
- Materia (650 $a)
- Signatura (952 $o)
- Ubicación (952 $c)

### 🎯 Cómo usar este sistema

1. **Preparar CSV** con tus columnas (pueden tener cualquier nombre)
2. **Verificar mapeo** en `config/mapeo_campos.json`
3. **Agregar variantes** si tus columnas tienen nombres únicos
4. **Probar** con archivo pequeño
5. **Importar** cuando esté perfecto

---

## 🆘 Soporte

**¿Necesitas ayuda?**

1. Lee esta guía completa
2. Revisa `config/mapeo_campos.json` con ejemplos
3. Prueba con archivos pequeños primero
4. Consulta https://www.loc.gov/marc/bibliographic/ para campos MARC

**Recursos adicionales:**
- GUIA_USO_COMPLETA.md - Guía general del sistema
- api/README_API.md - Guía de la API REST
- https://koha-community.org/manual/ - Manual de Koha

---

**¡Sistema de Mapeo Listo! 🎉**

Ahora puedes importar desde cualquier CSV o JSON con total flexibilidad.
