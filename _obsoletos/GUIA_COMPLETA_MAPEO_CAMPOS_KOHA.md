# 📚 GUÍA COMPLETA DE MAPEO DE CAMPOS PARA KOHA OPAC

**Universidad Nacional de Asunción**
**Sistema de Migración a Koha**
**Versión:** 2.0
**Fecha:** 2025-10-17

---

## 📖 ÍNDICE

1. [Introducción](#introducción)
2. [Conceptos Fundamentales](#conceptos-fundamentales)
3. [Campos Bibliográficos (Registro MARC)](#campos-bibliográficos-registro-marc)
4. [Campos de Ítem (Holdings)](#campos-de-ítem-holdings)
5. [Mapeo CSV → MARC21 → Koha DB](#mapeo-csv--marc21--koha-db)
6. [Campos Obligatorios vs Opcionales](#campos-obligatorios-vs-opcionales)
7. [Reglas de Validación](#reglas-de-validación)
8. [Ejemplos Prácticos Completos](#ejemplos-prácticos-completos)
9. [Códigos Autorizados](#códigos-autorizados)
10. [Resolución de Problemas](#resolución-de-problemas)

---

## 🎯 INTRODUCCIÓN

### ¿Qué es el mapeo de campos?

El **mapeo de campos** es el proceso de traducir los datos de tu sistema actual (CSV/Firebird) al formato que Koha entiende (MARC21).

### Flujo de datos

```
┌─────────────┐      ┌──────────┐      ┌────────────┐      ┌──────────┐
│  CSV/       │      │  Script  │      │  MARCXML   │      │  Koha    │
│  Firebird   │  →   │  Python  │  →   │  (MARC21)  │  →   │  Database│
│  (origen)   │      │ Conversor│      │  (estándar)│      │  (destino│
└─────────────┘      └──────────┘      └────────────┘      └──────────┘
     ↓                     ↓                   ↓                  ↓
  titulo              mapping             245$a            biblio.title
  autor               mapping             100$a            biblio.author
  nroacceso           mapping             952$p            items.barcode
```

---

## 🧩 CONCEPTOS FUNDAMENTALES

### 1. ¿Qué es MARC21?

**MARC** (Machine-Readable Cataloging) es el estándar internacional para intercambio de información bibliográfica.

**Estructura de un campo MARC:**
```
Campo: 245
Indicadores: ind1=1, ind2=0
Subcampos: $a (título), $b (subtítulo), $c (responsabilidad)

Ejemplo completo:
245 10 $a Introducción a la física $b teoría y práctica $c por Albert Einstein
```

### 2. Tipos de campos MARC

| Tipo | Rango | Descripción | Ejemplo |
|------|-------|-------------|---------|
| **Líder** | Leader | Información de control del registro | `00000nam a2200000 i 4500` |
| **Campos de control** | 001-009 | Números de control y códigos fijos | 001, 003, 005, 008 |
| **Campos de datos** | 010-999 | Información bibliográfica | 100, 245, 260, 650 |
| **Holdings (ítems)** | 952 | Información de ejemplares físicos | 952$a, 952$p, 952$o |

### 3. Componentes de un campo de datos

```
TAG: Número de 3 dígitos (ej: 245)
  ↓
IND1, IND2: Indicadores (valores 0-9 o espacio)
  ↓
SUBCAMPOS: $a, $b, $c, etc. (contenido específico)
  ↓
CONTENIDO: El texto/dato en sí

Ejemplo:
100 1_ $a García Márquez, Gabriel $d 1927-2014
│   │  │  │                       │  │
│   │  │  │                       │  └─ Subcampo $d (fechas)
│   │  │  └─ Subcampo $a (nombre)
│   │  └─ Indicador 2 (vacío/indefinido)
│   └─ Indicador 1 (1 = nombre personal)
└─ Tag (100 = autor principal)
```

### 4. Diferencia entre REGISTRO BIBLIOGRÁFICO e ÍTEM

| Concepto | Descripción | Ejemplo | Cantidad |
|----------|-------------|---------|----------|
| **Registro Bibliográfico** | Información intelectual de la obra | "Don Quijote de la Mancha por Cervantes" | 1 registro |
| **Ítem (Ejemplar)** | Copia física específica | "Ejemplar #001 en Biblioteca POL" | N ítems |

**Ejemplo:**
```
Bibliográfico (uno):
  - Título: "Cien años de soledad"
  - Autor: Gabriel García Márquez
  - ISBN: 978-84-376-0494-7

Ítems (múltiples):
  - Ítem 1: Barcode POL-001234, ubicado en SALA
  - Ítem 2: Barcode POL-001235, ubicado en REFERENCIA
  - Ítem 3: Barcode POL-001236, ubicado en DEPÓSITO
```

---

## 📖 CAMPOS BIBLIOGRÁFICOS (REGISTRO MARC)

### LEADER (Líder del registro)

```
Valor fijo: 00000nam a2200000 i 4500

Explicación:
00000      = Longitud del registro (se calcula automáticamente)
n          = Status: n=nuevo
a          = Tipo: a=material textual
m          = Nivel bibliográfico: m=monografía
 (espacio) = Control
a          = Esquema de codificación
2200000    = Base de directorios
 (espacio) = Nivel de codificación
i          = Formato de catalogación: i=ISBD
4500       = Mapa de entrada
```

---

### 001 - NÚMERO DE CONTROL

**Descripción:** Identificador único del registro bibliográfico

**Origen en CSV:** `analisis`, `nroacceso`, o generado automáticamente

**Formato:**
```
Prefijo:Valor

Opciones:
ANL:8856              ← Si existe campo "analisis"
BC:POL-001234         ← Si existe "nroacceso"
HX:a1b2c3d4e5         ← Generado con hash MD5
```

**Ejemplo:**
```xml
<controlfield tag="001">ANL:8856</controlfield>
```

---

### 003 - IDENTIFICADOR DEL NÚMERO DE CONTROL

**Descripción:** Código de la institución que asignó el 001

**Valor:** Código de biblioteca (homebranch)

**Ejemplo:**
```xml
<controlfield tag="003">POL</controlfield>
```

---

### 005 - FECHA Y HORA DE ÚLTIMA TRANSACCIÓN

**Descripción:** Timestamp de la última modificación

**Formato:** YYYYMMDDhhmmss.0

**Ejemplo:**
```xml
<controlfield tag="005">20251017143025.0</controlfield>
```

---

### 008 - ELEMENTOS DE LONGITUD FIJA

**Descripción:** 40 caracteres con información codificada

**Estructura:**
```
Posiciones  Contenido                      Valor
00-05       Fecha de ingreso               251017 (AAMMDD)
06          Tipo de fecha                  s (fecha única)
07-10       Fecha 1 (publicación)          2023
11-14       Fecha 2 (no usada)             ____
15-17       Lugar de publicación           py_ (Paraguay)
18-34       Elementos específicos          _______________
35-37       Idioma                         spa (español)
38-39       Registro modificado            __ (no modificado)
```

**Ejemplo completo:**
```xml
<controlfield tag="008">251017s2023    py                 spa  </controlfield>
                        │     │        │                  │
                        │     │        │                  └─ Idioma: spa
                        │     │        └─ País: py (Paraguay)
                        │     └─ Año: 2023
                        └─ Fecha ingreso: 17 oct 2025
```

---

### 020 - ISBN (INTERNATIONAL STANDARD BOOK NUMBER)

**Descripción:** Número estándar del libro

**Campo CSV:** `isbn`, `isbn_issn`, `issn`

**Subcampos:**
- `$a` - ISBN

**Formato:**
```
ISBN-10: 84-376-0494-7
ISBN-13: 978-84-376-0494-7
ISSN: 0378-5955
```

**Validación:**
```python
# ISBN-13 válido
✓ 978-84-376-0494-7
✓ 9788437604947

# Limpiar automáticamente
"ISBN 978-84-376-0494-7"  → "978-84-376-0494-7"
"978 84 376 0494 7"       → "978-84-376-0494-7"
```

**Ejemplo MARC:**
```xml
<datafield tag="020" ind1=" " ind2=" ">
  <subfield code="a">978-84-376-0494-7</subfield>
</datafield>
```

---

### 040 - FUENTE DE CATALOGACIÓN

**Descripción:** Agencia que creó el registro original

**Subcampos:**
- `$a` - Agencia de catalogación original
- `$b` - Idioma de catalogación
- `$c` - Agencia que transcribió

**Ejemplo:**
```xml
<datafield tag="040" ind1=" " ind2=" ">
  <subfield code="a">POL</subfield>
  <subfield code="b">spa</subfield>
  <subfield code="c">POL</subfield>
</datafield>
```

---

### 100 - ENTRADA PRINCIPAL - NOMBRE PERSONAL

**Descripción:** Autor principal (persona)

**Campo CSV:** `autor`, `author`, `autor_personal`

**Indicadores:**
- ind1:
  - `0` = Nombre propio (ej: Mahoma)
  - `1` = Apellido, Nombre (más común)
  - `3` = Nombre de familia

**Subcampos:**
- `$a` - Nombre personal
- `$d` - Fechas asociadas (opcional)

**Formato preferido:**
```
Apellido, Nombre
García Márquez, Gabriel
Einstein, Albert
```

**Ejemplo:**
```xml
<datafield tag="100" ind1="1" ind2=" ">
  <subfield code="a">García Márquez, Gabriel</subfield>
</datafield>
```

**IMPORTANTE:**
- Solo se usa **100** (persona) **O** **110** (institución), no ambos
- Si hay autor personal, usar 100
- Si es autor corporativo/institucional, usar 110

---

### 110 - ENTRADA PRINCIPAL - NOMBRE CORPORATIVO

**Descripción:** Autor institucional

**Campo CSV:** `autorinst`, `autor_institucional`, `corporativo`

**Indicadores:**
- ind1:
  - `2` = Nombre en orden directo (más común)

**Subcampos:**
- `$a` - Nombre corporativo

**Ejemplo:**
```xml
<datafield tag="110" ind1="2" ind2=" ">
  <subfield code="a">Universidad Nacional de Asunción</subfield>
</datafield>
```

**Casos de uso:**
```
✓ Universidad Nacional de Asunción
✓ Banco Central del Paraguay
✓ Organización de las Naciones Unidas
✓ Ministerio de Educación y Ciencias
```

---

### 245 - MENCIÓN DE TÍTULO

**Descripción:** Título principal del recurso (OBLIGATORIO)

**Campos CSV:** `titulo`, `sub_titulo`, `mencion`

**Indicadores:**
- ind1:
  - `0` = No hay entrada de autor (anónimo)
  - `1` = Hay entrada de autor (100 o 110 presente)
- ind2: Número de caracteres a ignorar al ordenar (artículos)
  - `0` = No ignorar nada
  - `1` = Ignorar 1 carácter ("A ")
  - `2` = Ignorar 2 caracteres ("La")
  - `3` = Ignorar 3 caracteres ("The", "Los")
  - `4` = Ignorar 4 caracteres ("Las ")

**Subcampos:**
- `$a` - Título principal (OBLIGATORIO)
- `$b` - Subtítulo o resto del título
- `$c` - Mención de responsabilidad
- `$n` - Número de parte
- `$p` - Nombre de parte

**Ejemplos:**

**Ejemplo 1: Título simple**
```
CSV: titulo = "Introducción a la física"

MARC:
<datafield tag="245" ind1="0" ind2="0">
  <subfield code="a">Introducción a la física</subfield>
</datafield>
```

**Ejemplo 2: Título con subtítulo**
```
CSV:
  titulo = "Introducción a la física"
  sub_titulo = "teoría y práctica"

MARC:
<datafield tag="245" ind1="0" ind2="0">
  <subfield code="a">Introducción a la física</subfield>
  <subfield code="b">teoría y práctica</subfield>
</datafield>
```

**Ejemplo 3: Título completo con autor y responsabilidad**
```
CSV:
  autor = "Einstein, Albert"
  titulo = "La teoría de la relatividad"
  sub_titulo = "edición especial"
  mencion = "traducido por Juan Pérez"

MARC:
<datafield tag="100" ind1="1" ind2=" ">
  <subfield code="a">Einstein, Albert</subfield>
</datafield>
<datafield tag="245" ind1="1" ind2="3">
  <subfield code="a">La teoría de la relatividad</subfield>
  <subfield code="b">edición especial</subfield>
  <subfield code="c">traducido por Juan Pérez</subfield>
</datafield>
```

**Ejemplo 4: Título con artículo**
```
Título: "Los miserables"
         └── 4 caracteres (incluye espacio)

<datafield tag="245" ind1="1" ind2="4">
  <subfield code="a">Los miserables</subfield>
</datafield>
```

**Tabla de artículos en español:**

| Artículo | ind2 | Ejemplo |
|----------|------|---------|
| El | 3 | "El Quijote" |
| La | 3 | "La Odisea" |
| Los | 4 | "Los miserables" |
| Las | 4 | "Las mil y una noches" |
| Un | 3 | "Un mundo feliz" |
| Una | 4 | "Una historia" |

---

### 250 - MENCIÓN DE EDICIÓN

**Descripción:** Información sobre la edición

**Campo CSV:** `edicion`, `edition`

**Subcampos:**
- `$a` - Mención de edición

**Formatos aceptados:**
```
✓ 1a ed.
✓ 2a ed. rev. y aum.
✓ 3a edición
✓ Primera edición
✓ Ed. definitiva
```

**Ejemplo:**
```xml
<datafield tag="250" ind1=" " ind2=" ">
  <subfield code="a">3a ed.</subfield>
</datafield>
```

---

### 264 - PRODUCCIÓN, PUBLICACIÓN, DISTRIBUCIÓN, MANUFACTURA Y COPYRIGHT

**Descripción:** Información de publicación (reemplaza el antiguo 260)

**Campos CSV:** `procedencia`, `editorial`, `publicacion`

**Indicadores:**
- ind2:
  - `1` = Publicación
  - `2` = Distribución
  - `3` = Manufactura
  - `4` = Copyright

**Subcampos:**
- `$a` - Lugar de publicación
- `$b` - Nombre del editor
- `$c` - Fecha de publicación

**Ejemplos:**

**Ejemplo 1: Publicación completa**
```
CSV:
  procedencia = "Asunción"
  editorial = "Editorial Universitaria"
  publicacion = "2023"

MARC:
<datafield tag="264" ind1=" " ind2="1">
  <subfield code="a">Asunción</subfield>
  <subfield code="b">Editorial Universitaria</subfield>
  <subfield code="c">2023</subfield>
</datafield>
```

**Ejemplo 2: Solo editorial y año**
```
CSV:
  editorial = "Pearson"
  publicacion = "2021"

MARC:
<datafield tag="264" ind1=" " ind2="1">
  <subfield code="b">Pearson</subfield>
  <subfield code="c">2021</subfield>
</datafield>
```

**Formatos de fecha aceptados:**
```
✓ 2023
✓ 2023-2024
✓ [2023]
✓ c2023 (copyright)
✓ 2023, c2022
```

---

### 300 - DESCRIPCIÓN FÍSICA

**Descripción:** Extensión física del recurso

**Campo CSV:** `paginas`, `pages`

**Subcampos:**
- `$a` - Extensión (páginas, volúmenes)
- `$b` - Otros detalles físicos
- `$c` - Dimensiones

**Ejemplos:**
```xml
<datafield tag="300" ind1=" " ind2=" ">
  <subfield code="a">350 p.</subfield>
</datafield>

<datafield tag="300" ind1=" " ind2=" ">
  <subfield code="a">2 v.</subfield>
  <subfield code="b">il.</subfield>
  <subfield code="c">24 cm</subfield>
</datafield>
```

---

### 490 - MENCIÓN DE SERIE

**Descripción:** Serie a la que pertenece la publicación

**Campo CSV:** `serie`, `coleccion`, `serie_mon`

**Indicadores:**
- ind1:
  - `0` = No se hace entrada de serie
  - `1` = Se hace entrada de serie (campo 8XX)

**Subcampos:**
- `$a` - Mención de serie
- `$v` - Número dentro de la serie

**Ejemplos:**
```xml
<datafield tag="490" ind1="1" ind2=" ">
  <subfield code="a">Colección Ciencias Exactas</subfield>
</datafield>

<datafield tag="490" ind1="1" ind2=" ">
  <subfield code="a">Biblioteca del Estudiante</subfield>
  <subfield code="v">no. 15</subfield>
</datafield>
```

---

### 500 - NOTA GENERAL

**Descripción:** Notas que no encajan en otros campos

**Campo CSV:** `notas`, `notes`

**Subcampos:**
- `$a` - Nota general

**Ejemplos:**
```xml
<datafield tag="500" ind1=" " ind2=" ">
  <subfield code="a">Incluye bibliografía</subfield>
</datafield>

<datafield tag="500" ind1=" " ind2=" ">
  <subfield code="a">Traducción de: Introduction to Physics</subfield>
</datafield>

<datafield tag="500" ind1=" " ind2=" ">
  <subfield code="a">Incluye índice alfabético</subfield>
</datafield>
```

---

### 520 - SUMARIO, RESUMEN, ETC.

**Descripción:** Resumen del contenido

**Campo CSV:** `sintesis`, `resumen`, `abstract`

**Indicadores:**
- ind1:
  - ` ` (espacio) = Sumario/resumen
  - `0` = Materia
  - `1` = Revisión
  - `2` = Alcance y contenido
  - `3` = Abstract

**Subcampos:**
- `$a` - Sumario, etc.

**Ejemplo:**
```xml
<datafield tag="520" ind1=" " ind2=" ">
  <subfield code="a">Este libro presenta los conceptos fundamentales de la física moderna, incluyendo mecánica clásica, termodinámica y electromagnetismo. Dirigido a estudiantes universitarios de primer año.</subfield>
</datafield>
```

**Mejores prácticas:**
```
✓ Escribir en tercera persona
✓ Longitud: 50-300 palabras
✓ Describir contenido, no opinar
✓ Mencionar público objetivo si es relevante
```

---

### 650 - ENTRADA SECUNDARIA DE MATERIA - TÉRMINO DE MATERIA

**Descripción:** Términos temáticos para búsqueda por materia

**Campo CSV:** `materia`, `materias`, `temas_descrip`

**Indicadores:**
- ind1: Nivel (generalmente vacío)
- ind2: Fuente del encabezamiento
  - `0` = Library of Congress Subject Headings
  - `1` = LC subject headings para literatura infantil
  - `4` = Fuente no especificada

**Subcampos:**
- `$a` - Término de materia

**IMPORTANTE:** Si el CSV tiene múltiples materias separadas por `;`, crear un campo 650 por cada una.

**Ejemplos:**

**CSV:**
```
materia = "Física;Mecánica;Ciencia"
```

**MARC:**
```xml
<datafield tag="650" ind1=" " ind2="4">
  <subfield code="a">Física</subfield>
</datafield>
<datafield tag="650" ind1=" " ind2="4">
  <subfield code="a">Mecánica</subfield>
</datafield>
<datafield tag="650" ind1=" " ind2="4">
  <subfield code="a">Ciencia</subfield>
</datafield>
```

**Mejores prácticas:**
```
✓ Usar términos normalizados
✓ Singular o plural según la norma
✓ Primera letra en mayúscula
✓ Sin punto final
✓ Específico > Genérico

Ejemplos buenos:
✓ Ingeniería civil
✓ Química orgánica
✓ Literatura paraguaya
✓ Sistemas operativos

Ejemplos a mejorar:
✗ ingenieria (sin tilde)
✗ quimica. (punto final)
✗ LITERATURA (todo mayúsculas)
```

---

### 942 - ELEMENTOS AGREGADOS (ESPECÍFICO DE KOHA)

**Descripción:** Información específica de Koha (no es MARC estándar)

**Campo CSV:** `tipomaterial`

**Subcampos:**
- `$c` - Tipo de ítem (itype) del registro bibliográfico

**Valores comunes:**

| Tipo CSV | Código | Descripción |
|----------|--------|-------------|
| Monografía, Monografia, Libro | BK | Libro |
| Revista, Publicación periódica | MG | Revista/Magazine |
| Tesis | TES | Tesis |
| DVD, Video | VM | Material visual |
| CD, Audio | MU | Música |
| Mapa | MP | Material cartográfico |

**Ejemplo:**
```xml
<datafield tag="942" ind1=" " ind2=" ">
  <subfield code="c">BK</subfield>
</datafield>
```

---

## 📦 CAMPOS DE ÍTEM (HOLDINGS)

### 952 - DATOS DE UBICACIÓN E ÍTEM (ESPECÍFICO DE KOHA)

**Descripción:** Información del ejemplar físico específico

**IMPORTANTE:** Este es el campo más crítico para Koha. Un error aquí impedirá que el ítem sea usable.

#### Estructura completa del campo 952:

| Subcampo | Nombre | Base de datos Koha | Obligatorio | Descripción |
|----------|--------|-------------------|-------------|-------------|
| `$a` | homebranch | items.homebranch | **SÍ** | Biblioteca propietaria |
| `$b` | holdingbranch | items.holdingbranch | **SÍ** | Biblioteca donde está físicamente |
| `$c` | location | items.location | NO | Ubicación física dentro de la biblioteca |
| `$o` | itemcallnumber | items.itemcallnumber | NO | Signatura/cota |
| `$p` | barcode | items.barcode | **SÍ** | Código de barras (único) |
| `$y` | itype | items.itype | **SÍ** | Tipo de ítem |
| `$h` | enumchron | items.enumchron | NO | Volumen, número, cronología |
| `$d` | dateaccessioned | items.dateaccessioned | NO | Fecha de adquisición |
| `$g` | price | items.price | NO | Precio |
| `$v` | replacementprice | items.replacementprice | NO | Precio de reemplazo |
| `$2` | cn_source | items.cn_source | NO | Fuente de clasificación |
| `$7` | notforloan | items.notforloan | NO | Estado de préstamo |

---

#### 952$a - HOMEBRANCH (Biblioteca propietaria)

**Descripción:** Biblioteca a la que pertenece el ítem (no cambia aunque se preste a otra biblioteca)

**Origen:** Parámetro `--codbiblio` del script

**OBLIGATORIO:** SÍ

**Formato:** Código de biblioteca (3-10 caracteres)

**Ejemplos:**
```
POL       = Biblioteca Politécnica
FACEN     = Facultad de Ciencias Exactas
FACAGR    = Facultad de Ciencias Agrarias
FACMED    = Facultad de Ciencias Médicas
```

**Validación:**
- Debe existir previamente en Koha (Administración → Bibliotecas)
- Solo letras y números
- Sin espacios, sin caracteres especiales

**MARC:**
```xml
<datafield tag="952" ind1=" " ind2=" ">
  <subfield code="a">POL</subfield>
</datafield>
```

---

#### 952$b - HOLDINGBRANCH (Biblioteca física actual)

**Descripción:** Biblioteca donde está físicamente el ítem ahora

**Origen:** Generalmente igual a `$a` (homebranch)

**OBLIGATORIO:** SÍ

**Uso:** Cambia cuando el ítem se transfiere temporalmente a otra biblioteca

**Ejemplo:**
```
Ítem original de POL prestado temporalmente a FACEN:
  952$a = POL      ← Propietario permanente
  952$b = FACEN    ← Ubicación actual temporal

Después de devolución a POL:
  952$a = POL      ← No cambia
  952$b = POL      ← Vuelve al propietario
```

**MARC:**
```xml
<datafield tag="952" ind1=" " ind2=" ">
  <subfield code="a">POL</subfield>
  <subfield code="b">POL</subfield>
</datafield>
```

---

#### 952$c - LOCATION (Ubicación física)

**Descripción:** Ubicación específica dentro de la biblioteca

**Origen:** Columna `loc` del CSV o parámetro `--loc-default`

**OBLIGATORIO:** NO (pero muy recomendado)

**Códigos comunes:**

| Código | Descripción | Préstamo | Uso típico |
|--------|-------------|----------|------------|
| SALA | Sala de lectura | SÍ | Colección general |
| REF | Referencia | NO | Diccionarios, enciclopedias |
| DEP | Depósito | SÍ | Materiales antiguos o poco usados |
| TESIS | Tesis | RESTRINGIDO | Trabajos de grado |
| RESERVA | Reserva de profesores | RESTRINGIDO | Bibliografía obligatoria |
| HEMER | Hemeroteca | VARÍA | Revistas y periódicos |
| AV | Audiovisual | SÍ | DVDs, CDs |
| GEN | General | SÍ | Ubicación genérica |

**Validación:**
- Debe existir en Koha (Administración → Valores autorizados → LOC)
- Generalmente 2-10 caracteres
- Solo mayúsculas

**MARC:**
```xml
<datafield tag="952" ind1=" " ind2=" ">
  <subfield code="a">POL</subfield>
  <subfield code="b">POL</subfield>
  <subfield code="c">SALA</subfield>
</datafield>
```

---

#### 952$o - ITEMCALLNUMBER (Signatura/Cota)

**Descripción:** Número de clasificación para localizar el ítem en el estante

**Origen:** Columna `ubicacion`, `signatura`, `cota`, `callnumber` del CSV

**OBLIGATORIO:** NO (pero esencial para encontrar el ítem físicamente)

**Sistemas de clasificación comunes:**

**1. Dewey Decimal (DDC):**
```
000-099   Generalidades, Computación, Información
100-199   Filosofía y Psicología
200-299   Religión
300-399   Ciencias Sociales
400-499   Lenguas
500-599   Ciencias Puras
600-699   Ciencias Aplicadas, Tecnología
700-799   Artes, Recreación
800-899   Literatura
900-999   Historia, Geografía

Ejemplos:
530.1 EIN      ← 530.1 = Física, EIN = Einstein
547 SMI        ← 547 = Química orgánica, SMI = Smith
005.74 DAT     ← 005.74 = Bases de datos
```

**2. Library of Congress (LCC):**
```
A      Obras generales
B      Filosofía, Psicología, Religión
C-D    Historia
E-F    Historia de América
G      Geografía, Antropología
H      Ciencias Sociales
J      Ciencias Políticas
K      Derecho
L      Educación
M      Música
N      Bellas Artes
P      Lengua y Literatura
Q      Ciencia
R      Medicina
S      Agricultura
T      Tecnología
U      Ciencia Militar
V      Ciencia Naval
Z      Bibliografía, Bibliotecología

Ejemplos:
QC173.59 .E35   ← Física
QD251.2 .S65    ← Química orgánica
```

**3. Cutter:**
```
Formato: CLASE + AUTOR
         ↓       ↓
       530.1   EIN

CLASE = Dewey o LC
EIN   = Primeras letras del apellido del autor
```

**Validación:**
- Longitud: generalmente 5-30 caracteres
- Puede contener: números, letras, puntos, espacios

**MARC:**
```xml
<datafield tag="952" ind1=" " ind2=" ">
  <subfield code="o">530.1 EIN</subfield>
</datafield>
```

---

#### 952$p - BARCODE (Código de barras)

**Descripción:** Identificador único del ejemplar físico

**Origen:** Columna `nroacceso`, `barcode`, `codigo_barras` del CSV

**OBLIGATORIO:** SÍ (se genera automáticamente si falta)

**Formato:**
```
Preferido:
  CODIGO-NUMERO
  POL-0001234

Alternativos:
  Solo números: 001234567890
  Con letras: ABC123456
```

**Reglas:**
- **ÚNICO en todo Koha** (no puede haber dos ítems con el mismo barcode)
- Longitud: generalmente 5-20 caracteres
- Solo letras, números y guiones
- Sin espacios, sin caracteres especiales

**Generación automática (si CSV vacío):**
```python
barcode = f"{codbiblio}-{numero:07d}"

Ejemplos:
POL-0000001
POL-0000002
FACEN-0001234
```

**Validación:**
```python
✓ POL-0001234
✓ 001234567890
✓ ABC-123-456

✗ POL 001234 (tiene espacio)
✗ POL_001234 (underscore no recomendado)
✗ (vacío, sin autogenerar)
```

**MARC:**
```xml
<datafield tag="952" ind1=" " ind2=" ">
  <subfield code="p">POL-0001234</subfield>
</datafield>
```

---

#### 952$y - ITYPE (Tipo de ítem)

**Descripción:** Tipo de material del ítem

**Origen:** Columna `tipomaterial` del CSV

**OBLIGATORIO:** SÍ

**Códigos estándar en Koha:**

| Código | Descripción | Período préstamo típico | Renovable |
|--------|-------------|------------------------|-----------|
| BK | Libro (Book) | 14-21 días | SÍ |
| MG | Revista (Magazine) | 7 días | NO |
| TES | Tesis | 3 días | NO |
| VM | Material visual (DVD) | 7 días | SÍ |
| MU | Música (CD) | 7 días | SÍ |
| MP | Mapa | 14 días | SÍ |
| CR | Recurso electrónico | N/A | N/A |
| MX | Material mixto | 14 días | SÍ |

**Mapeo desde CSV:**

```python
MAPEO = {
    "Monografía": "BK",
    "Monografia": "BK",
    "Libro": "BK",
    "Revista": "MG",
    "Publicación periódica": "MG",
    "Tesis": "TES",
    "DVD": "VM",
    "Video": "VM",
    "CD": "MU",
    "Audio": "MU",
    "Mapa": "MP",
}
```

**Validación:**
- Debe existir en Koha (Administración → Tipos de ítem)
- Generalmente 2-4 caracteres
- Solo mayúsculas

**MARC:**
```xml
<datafield tag="952" ind1=" " ind2=" ">
  <subfield code="y">BK</subfield>
</datafield>
```

---

#### 952$h - ENUMCHRON (Volumen/Número/Cronología)

**Descripción:** Información de enumeración y cronología para publicaciones seriadas

**Origen:** Columna `volumen`, `tomo`, `vol` del CSV

**OBLIGATORIO:** NO

**Formato libre:**
```
Vol. 1
Tomo 3
v. 5, no. 2
Año 2023, Número 15
2023:1
```

**Ejemplos:**
```xml
<!-- Libro en varios tomos -->
<subfield code="h">Vol. 1</subfield>

<!-- Revista -->
<subfield code="h">Año 2023, No. 5</subfield>

<!-- Serie -->
<subfield code="h">Tomo III</subfield>
```

---

#### 952$d - DATEACCESSIONED (Fecha de adquisición)

**Descripción:** Fecha en que el ítem fue adquirido

**Origen:** Columna `fechaadq`, `fecha_adquisicion` del CSV

**OBLIGATORIO:** NO

**Formato:** YYYY-MM-DD (ISO 8601)

**Ejemplos:**
```
✓ 2023-01-15
✓ 2023-12-31
✓ 2020-06-01

✗ 15/01/2023 (formato incorrecto)
✗ 2023-1-5 (debe ser 2023-01-05)
```

**MARC:**
```xml
<datafield tag="952" ind1=" " ind2=" ">
  <subfield code="d">2023-01-15</subfield>
</datafield>
```

---

#### 952$g - PRICE (Precio de adquisición)

**Descripción:** Precio pagado por el ítem

**Origen:** Columna `precio`, `price`, `costo` del CSV

**OBLIGATORIO:** NO

**Formato:** Número decimal (sin símbolo de moneda)

**Ejemplos:**
```
✓ 150000
✓ 150000.00
✓ 25.50

✗ Gs 150.000 (texto)
✗ USD$25.00 (con símbolo)
```

**MARC:**
```xml
<datafield tag="952" ind1=" " ind2=" ">
  <subfield code="g">150000.00</subfield>
</datafield>
```

---

#### EJEMPLO COMPLETO DE CAMPO 952:

```xml
<datafield tag="952" ind1=" " ind2=" ">
  <subfield code="a">POL</subfield>              <!-- homebranch -->
  <subfield code="b">POL</subfield>              <!-- holdingbranch -->
  <subfield code="c">SALA</subfield>             <!-- location -->
  <subfield code="o">530.1 EIN</subfield>        <!-- callnumber -->
  <subfield code="p">POL-0001234</subfield>      <!-- barcode -->
  <subfield code="y">BK</subfield>               <!-- itype -->
  <subfield code="h">Vol. 1</subfield>           <!-- volumen -->
  <subfield code="d">2023-01-15</subfield>       <!-- fecha adquisición -->
  <subfield code="g">150000.00</subfield>        <!-- precio -->
</datafield>
```

---

## 🗺️ MAPEO CSV → MARC21 → KOHA DB

### Tabla completa de mapeo:

| Campo CSV | Candidatos | MARC21 | Subcampo | Koha DB | Obligatorio | Ejemplo |
|-----------|-----------|--------|----------|---------|-------------|---------|
| **CONTROL** |
| - | (generado) | 001 | - | biblioitems.biblionumber | ✓ | ANL:8856 |
| codbiblio | codbiblio, biblioteca, branch | 003 | - | - | ✓ | POL |
| - | (timestamp) | 005 | - | - | ✓ | 20251017143025.0 |
| publicacion | publicacion, año, anio, year | 008 | 07-10 | - | ✓ | 2023 |
| **BIBLIOGRÁFICO** |
| isbn | isbn, isbn_issn, issn | 020 | $a | biblioitems.isbn | - | 978-84-376-0494-7 |
| codbiblio | - | 040 | $a, $c | - | ✓ | POL |
| - | - | 040 | $b | - | ✓ | spa |
| autor | autor, author, autor_personal | 100 | $a | biblio.author | - | García Márquez, Gabriel |
| autorinst | autorinst, autor_institucional | 110 | $a | biblio.author | - | Universidad Nacional |
| titulo | titulo, título, title | 245 | $a | biblio.title | ✓ | Introducción a la física |
| sub_titulo | sub_titulo, subtitulo | 245 | $b | biblio.subtitle | - | teoría y práctica |
| mencion | mencion, responsabilidad | 245 | $c | - | - | traducido por Juan Pérez |
| edicion | edicion, edición, edition | 250 | $a | biblioitems.editionstatement | - | 3a ed. |
| procedencia | procedencia, lugar, place | 264 | $a | biblioitems.place | - | Asunción |
| editorial | editorial, publisher | 264 | $b | biblioitems.publishercode | - | Editorial UNA |
| publicacion | publicacion, año, year | 264 | $c | biblioitems.publicationyear | - | 2023 |
| paginas | paginas, páginas, pages | 300 | $a | biblioitems.pages | - | 350 p. |
| serie | serie, coleccion, colección | 490 | $a | biblio.seriestitle | - | Colección Ciencias |
| notas | notas, nota, notes | 500 | $a | - | - | Incluye bibliografía |
| sintesis | sintesis, resumen, abstract | 520 | $a | biblio.abstract | - | Este libro presenta... |
| materia | materia, temas_descrip, subject | 650 | $a | - | - | Física (múltiples campos) |
| tipomaterial | tipomaterial, tipomat | 942 | $c | biblioitems.itemtype | ✓ | BK |
| **ÍTEM (952)** |
| codbiblio | (parámetro --codbiblio) | 952 | $a | items.homebranch | ✓ | POL |
| codbiblio | (parámetro --codbiblio) | 952 | $b | items.holdingbranch | ✓ | POL |
| loc | loc, ubic_fisica, location_code | 952 | $c | items.location | - | SALA |
| ubicacion | ubicacion, signatura, cota | 952 | $o | items.itemcallnumber | - | 530.1 EIN |
| nroacceso | nroacceso, barcode, codigo_barras | 952 | $p | items.barcode | ✓ | POL-0001234 |
| tipomaterial | tipomaterial, itemtype | 952 | $y | items.itype | ✓ | BK |
| volumen | volumen, tomo, vol | 952 | $h | items.enumchron | - | Vol. 1 |
| fechaadq | fechaadq, fecha_adquisicion | 952 | $d | items.dateaccessioned | - | 2023-01-15 |
| precio | precio, price, costo | 952 | $g | items.price | - | 150000.00 |

---

## ✅ CAMPOS OBLIGATORIOS VS OPCIONALES

### OBLIGATORIOS (El registro NO se importará si faltan)

| Nivel | Campo | MARC | CSV | Validación |
|-------|-------|------|-----|------------|
| **Bibliográfico** | Título | 245$a | `titulo` | No vacío |
| | Tipo de ítem | 942$c | `tipomaterial` | Código válido |
| | Biblioteca | 003, 040$a | `codbiblio` | Existe en Koha |
| **Ítem** | Homebranch | 952$a | `codbiblio` | Existe en Koha |
| | Holdingbranch | 952$b | `codbiblio` | Existe en Koha |
| | Barcode | 952$p | `nroacceso` | Único en Koha |
| | Item type | 952$y | `tipomaterial` | Existe en Koha |

### CRÍTICOS PARA OPAC (Sin ellos el registro es poco útil)

| Campo | MARC | CSV | Impacto en OPAC |
|-------|------|-----|-----------------|
| Autor | 100$a / 110$a | `autor` / `autorinst` | Búsqueda por autor |
| ISBN | 020$a | `isbn` | Deduplicación, enlace Amazon |
| Editorial | 264$b | `editorial` | Información de publicación |
| Año | 264$c | `publicacion` | Filtros de búsqueda |
| Materias | 650$a | `materia` | Búsqueda temática |
| Resumen | 520$a | `sintesis` | Descripción del contenido |
| Signatura | 952$o | `ubicacion` | Localización física |
| Ubicación | 952$c | `loc` | Sección de la biblioteca |

### RECOMENDADOS (Mejoran la calidad del catálogo)

| Campo | MARC | CSV |
|-------|------|-----|
| Subtítulo | 245$b | `sub_titulo` |
| Edición | 250$a | `edicion` |
| Lugar de publicación | 264$a | `procedencia` |
| Páginas | 300$a | `paginas` |
| Serie | 490$a | `serie` |
| Notas | 500$a | `notas` |

### OPCIONALES (Nice to have)

| Campo | MARC | CSV |
|-------|------|-----|
| Mención de responsabilidad | 245$c | `mencion` |
| Volumen/Tomo | 952$h | `volumen` |
| Fecha de adquisición | 952$d | `fechaadq` |
| Precio | 952$g | `precio` |

---

## 🔍 REGLAS DE VALIDACIÓN

### Validación de campos OBLIGATORIOS

```python
# 1. Título (245$a)
if not titulo or titulo.strip() == "":
    ERROR: "Registro sin título"
    ACCIÓN: Omitir registro

# 2. Biblioteca (952$a, 952$b)
if codbiblio not in BIBLIOTECAS_VALIDAS:
    ERROR: f"Biblioteca '{codbiblio}' no existe en Koha"
    ACCIÓN: Crear biblioteca primero o usar código existente

# 3. Barcode (952$p)
if barcode in BARCODES_EXISTENTES:
    ERROR: f"Barcode '{barcode}' duplicado"
    ACCIÓN: Renumerar automáticamente

if not barcode:
    WARNING: "Barcode vacío, generando automáticamente"
    ACCIÓN: barcode = f"{codbiblio}-{numero:07d}"

# 4. Item type (952$y)
if itype not in ITYPES_VALIDOS:
    ERROR: f"Item type '{itype}' no existe en Koha"
    ACCIÓN: Mapear a tipo por defecto (BK) o crear tipo en Koha
```

### Validación de campos OPCIONALES

```python
# ISBN (020$a)
if isbn:
    # Limpiar
    isbn = re.sub(r'[^0-9X]', '', isbn.upper())

    # Validar longitud
    if len(isbn) not in [10, 13]:
        WARNING: f"ISBN '{isbn}' longitud inválida"

    # Validar checksum (opcional)
    if not validar_checksum_isbn(isbn):
        WARNING: f"ISBN '{isbn}' checksum inválido"

# Fecha de adquisición (952$d)
if fechaadq:
    try:
        datetime.strptime(fechaadq, '%Y-%m-%d')
    except ValueError:
        WARNING: f"Fecha '{fechaadq}' formato inválido, usar YYYY-MM-DD"
        ACCIÓN: Intentar parsear o dejar vacío

# Precio (952$g)
if precio:
    try:
        float(precio.replace(',', '.'))
    except ValueError:
        WARNING: f"Precio '{precio}' no es numérico"
        ACCIÓN: Limpiar o dejar vacío
```

### Validación de integridad relacional

```python
# Author + Title
if not autor and not autorinst:
    WARNING: "Registro sin autor personal ni institucional"
    ACCIÓN: ind1 del 245 = "0"

# Location code (952$c)
if loc and loc not in LOCATIONS_VALIDAS:
    ERROR: f"Location '{loc}' no existe en Koha"
    ACCIÓN: Usar --loc-default o crear location en Koha

# Call number (952$o)
if not callnumber:
    WARNING: "Sin signatura, dificulta ubicar ítem físico"
    ACCIÓN: Continuar pero recomendar agregar
```

---

## 📝 EJEMPLOS PRÁCTICOS COMPLETOS

### EJEMPLO 1: Monografía completa

**CSV:**
```csv
codbiblio;analisis;titulo;sub_titulo;autor;edicion;procedencia;editorial;publicacion;isbn;materia;sintesis;nroacceso;ubicacion;tipomaterial;loc;volumen
POL;8856;Introducción a la física;teoría y práctica;Einstein, Albert;3a ed.;Asunción;Editorial UNA;2023;978-84-376-0494-7;Física;Este libro presenta los conceptos fundamentales de la física moderna;POL-001234;530.1 EIN;Monografía;SALA;
```

**MARCXML generado:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<collection xmlns="http://www.loc.gov/MARC21/slim">
  <record>
    <leader>00000nam a2200000 i 4500</leader>

    <!-- Campos de control -->
    <controlfield tag="001">ANL:8856</controlfield>
    <controlfield tag="003">POL</controlfield>
    <controlfield tag="005">20251017143025.0</controlfield>
    <controlfield tag="008">251017s2023    py                 spa  </controlfield>

    <!-- ISBN -->
    <datafield tag="020" ind1=" " ind2=" ">
      <subfield code="a">978-84-376-0494-7</subfield>
    </datafield>

    <!-- Fuente de catalogación -->
    <datafield tag="040" ind1=" " ind2=" ">
      <subfield code="a">POL</subfield>
      <subfield code="b">spa</subfield>
      <subfield code="c">POL</subfield>
    </datafield>

    <!-- Autor -->
    <datafield tag="100" ind1="1" ind2=" ">
      <subfield code="a">Einstein, Albert</subfield>
    </datafield>

    <!-- Título -->
    <datafield tag="245" ind1="1" ind2="0">
      <subfield code="a">Introducción a la física</subfield>
      <subfield code="b">teoría y práctica</subfield>
    </datafield>

    <!-- Edición -->
    <datafield tag="250" ind1=" " ind2=" ">
      <subfield code="a">3a ed.</subfield>
    </datafield>

    <!-- Publicación -->
    <datafield tag="264" ind1=" " ind2="1">
      <subfield code="a">Asunción</subfield>
      <subfield code="b">Editorial UNA</subfield>
      <subfield code="c">2023</subfield>
    </datafield>

    <!-- Resumen -->
    <datafield tag="520" ind1=" " ind2=" ">
      <subfield code="a">Este libro presenta los conceptos fundamentales de la física moderna</subfield>
    </datafield>

    <!-- Materia -->
    <datafield tag="650" ind1=" " ind2="4">
      <subfield code="a">Física</subfield>
    </datafield>

    <!-- Tipo de ítem (942) -->
    <datafield tag="942" ind1=" " ind2=" ">
      <subfield code="c">BK</subfield>
    </datafield>

    <!-- Ítem (952) -->
    <datafield tag="952" ind1=" " ind2=" ">
      <subfield code="a">POL</subfield>
      <subfield code="b">POL</subfield>
      <subfield code="c">SALA</subfield>
      <subfield code="o">530.1 EIN</subfield>
      <subfield code="p">POL-001234</subfield>
      <subfield code="y">BK</subfield>
    </datafield>
  </record>
</collection>
```

---

### EJEMPLO 2: Tesis (sin autor personal)

**CSV:**
```csv
codbiblio;titulo;autorinst;publicacion;materia;nroacceso;ubicacion;tipomaterial;loc
POL;Análisis de sistemas de información;Universidad Nacional de Asunción;2022;Sistemas de información;POL-005678;005.74 UNA;Tesis;TESIS
```

**MARCXML:**
```xml
<record>
  <leader>00000nam a2200000 i 4500</leader>
  <controlfield tag="001">BC:POL-005678</controlfield>
  <controlfield tag="003">POL</controlfield>
  <controlfield tag="005">20251017143025.0</controlfield>
  <controlfield tag="008">251017s2022    py                 spa  </controlfield>

  <datafield tag="040" ind1=" " ind2=" ">
    <subfield code="a">POL</subfield>
    <subfield code="b">spa</subfield>
    <subfield code="c">POL</subfield>
  </datafield>

  <!-- Autor institucional -->
  <datafield tag="110" ind1="2" ind2=" ">
    <subfield code="a">Universidad Nacional de Asunción</subfield>
  </datafield>

  <!-- Título (ind1=1 porque hay autor corporativo) -->
  <datafield tag="245" ind1="1" ind2="0">
    <subfield code="a">Análisis de sistemas de información</subfield>
  </datafield>

  <datafield tag="264" ind1=" " ind2="1">
    <subfield code="c">2022</subfield>
  </datafield>

  <datafield tag="650" ind1=" " ind2="4">
    <subfield code="a">Sistemas de información</subfield>
  </datafield>

  <datafield tag="942" ind1=" " ind2=" ">
    <subfield code="c">TES</subfield>
  </datafield>

  <datafield tag="952" ind1=" " ind2=" ">
    <subfield code="a">POL</subfield>
    <subfield code="b">POL</subfield>
    <subfield code="c">TESIS</subfield>
    <subfield code="o">005.74 UNA</subfield>
    <subfield code="p">POL-005678</subfield>
    <subfield code="y">TES</subfield>
  </datafield>
</record>
```

---

### EJEMPLO 3: Revista (publicación seriada)

**CSV:**
```csv
codbiblio;titulo;editorial;publicacion;materia;nroacceso;tipomaterial;loc;volumen
POL;Revista de Ciencias Exactas;Facultad de Ciencias;2023;Ciencias;POL-REV-2023-01;Revista;HEMER;Año 2023, No. 1
```

**MARCXML:**
```xml
<record>
  <leader>00000nas a2200000 i 4500</leader>
  <!--       ^ a=serial -->

  <controlfield tag="001">BC:POL-REV-2023-01</controlfield>
  <controlfield tag="003">POL</controlfield>
  <controlfield tag="005">20251017143025.0</controlfield>
  <controlfield tag="008">251017s2023    py                 spa  </controlfield>

  <datafield tag="040" ind1=" " ind2=" ">
    <subfield code="a">POL</subfield>
    <subfield code="b">spa</subfield>
    <subfield code="c">POL</subfield>
  </datafield>

  <datafield tag="245" ind1="0" ind2="0">
    <subfield code="a">Revista de Ciencias Exactas</subfield>
  </datafield>

  <datafield tag="264" ind1=" " ind2="1">
    <subfield code="b">Facultad de Ciencias</subfield>
    <subfield code="c">2023</subfield>
  </datafield>

  <datafield tag="650" ind1=" " ind2="4">
    <subfield code="a">Ciencias</subfield>
  </datafield>

  <datafield tag="942" ind1=" " ind2=" ">
    <subfield code="c">MG</subfield>
  </datafield>

  <datafield tag="952" ind1=" " ind2=" ">
    <subfield code="a">POL</subfield>
    <subfield code="b">POL</subfield>
    <subfield code="c">HEMER</subfield>
    <subfield code="p">POL-REV-2023-01</subfield>
    <subfield code="y">MG</subfield>
    <subfield code="h">Año 2023, No. 1</subfield>
  </datafield>
</record>
```

---

### EJEMPLO 4: Registro mínimo (solo campos obligatorios)

**CSV:**
```csv
codbiblio;titulo;nroacceso;tipomaterial
POL;Manual de usuario;;Monografía
```

**MARCXML:**
```xml
<record>
  <leader>00000nam a2200000 i 4500</leader>

  <controlfield tag="001">HX:a1b2c3d4e5</controlfield>
  <controlfield tag="003">POL</controlfield>
  <controlfield tag="005">20251017143025.0</controlfield>
  <controlfield tag="008">251017s        py                 spa  </controlfield>

  <datafield tag="040" ind1=" " ind2=" ">
    <subfield code="a">POL</subfield>
    <subfield code="b">spa</subfield>
    <subfield code="c">POL</subfield>
  </datafield>

  <!-- Sin autor: ind1=0 -->
  <datafield tag="245" ind1="0" ind2="0">
    <subfield code="a">Manual de usuario</subfield>
  </datafield>

  <datafield tag="942" ind1=" " ind2=" ">
    <subfield code="c">BK</subfield>
  </datafield>

  <!-- Barcode autogenerado -->
  <datafield tag="952" ind1=" " ind2=" ">
    <subfield code="a">POL</subfield>
    <subfield code="b">POL</subfield>
    <subfield code="p">POL-0000001</subfield>
    <subfield code="y">BK</subfield>
  </datafield>
</record>
```

---

## 🔐 CÓDIGOS AUTORIZADOS

### Códigos que DEBEN existir en Koha ANTES de importar

#### 1. BIBLIOTECAS (Branches)

**Ubicación en Koha:** Administración → Bibliotecas y grupos

**Formato:**
- Código: 3-10 caracteres (ej: POL, FACEN)
- Nombre: Descripción completa

**Ejemplo de configuración:**

| Código | Nombre | Dirección | Email |
|--------|--------|-----------|-------|
| POL | Biblioteca Politécnica | Campus UNA, Edif. 5 | biblio.pol@una.py |
| FACEN | Fac. Ciencias Exactas | Campus Central | biblio.facen@una.py |
| FACAGR | Fac. Ciencias Agrarias | Campus Agrarias | biblio.facagr@una.py |

**Comando para verificar:**
```bash
sudo koha-mysql koha-cnc -e "SELECT branchcode, branchname FROM branches"
```

---

#### 2. UBICACIONES (Authorized value LOC)

**Ubicación en Koha:** Administración → Valores autorizados → LOC

**Ejemplo de configuración:**

| Código | Descripción | OPAC |
|--------|-------------|------|
| SALA | Sala de lectura | SÍ |
| REF | Referencia | SÍ |
| DEP | Depósito | NO |
| TESIS | Tesis | SÍ |
| RESERVA | Reserva de profesores | NO |
| HEMER | Hemeroteca | SÍ |
| AV | Audiovisual | SÍ |

**Comando para verificar:**
```bash
sudo koha-mysql koha-cnc -e "
SELECT authorised_value, lib
FROM authorised_values
WHERE category='LOC'
ORDER BY authorised_value"
```

---

#### 3. TIPOS DE ÍTEM (Item types)

**Ubicación en Koha:** Administración → Tipos de ítem

**Ejemplo de configuración:**

| Código | Descripción | Préstamo (días) | Renovaciones | OPAC |
|--------|-------------|-----------------|--------------|------|
| BK | Libro | 21 | 3 | SÍ |
| MG | Revista | 7 | 0 | SÍ |
| TES | Tesis | 3 | 0 | SÍ |
| VM | Material visual | 7 | 2 | SÍ |
| MU | Música | 7 | 2 | SÍ |
| MP | Mapa | 14 | 2 | SÍ |

**Comando para verificar:**
```bash
sudo koha-mysql koha-cnc -e "
SELECT itemtype, description
FROM itemtypes
ORDER BY itemtype"
```

---

### Scripts para crear códigos masivamente

#### Crear bibliotecas:
```sql
-- Archivo: crear_bibliotecas.sql
INSERT INTO branches (branchcode, branchname) VALUES
('POL', 'Biblioteca Politécnica'),
('FACEN', 'Facultad de Ciencias Exactas y Naturales'),
('FACAGR', 'Facultad de Ciencias Agrarias'),
('FACMED', 'Facultad de Ciencias Médicas'),
('FACED', 'Facultad de Educación'),
('FACDER', 'Facultad de Derecho');

-- Ejecutar:
-- sudo koha-mysql koha-cnc < crear_bibliotecas.sql
```

#### Crear ubicaciones:
```sql
-- Archivo: crear_ubicaciones.sql
INSERT INTO authorised_values (category, authorised_value, lib) VALUES
('LOC', 'SALA', 'Sala de lectura'),
('LOC', 'REF', 'Referencia'),
('LOC', 'DEP', 'Depósito'),
('LOC', 'TESIS', 'Tesis'),
('LOC', 'RESERVA', 'Reserva'),
('LOC', 'HEMER', 'Hemeroteca'),
('LOC', 'AV', 'Audiovisual'),
('LOC', 'GEN', 'General');

-- Ejecutar:
-- sudo koha-mysql koha-cnc < crear_ubicaciones.sql
```

---

## ❗ RESOLUCIÓN DE PROBLEMAS

### Problema 1: "homebranch not found"

**Error:**
```
ERROR: homebranch 'POL' not found in database
```

**Causa:** La biblioteca no existe en Koha

**Solución:**
```bash
# Verificar bibliotecas existentes
sudo koha-mysql koha-cnc -e "SELECT branchcode FROM branches"

# Crear biblioteca
sudo koha-mysql koha-cnc -e "
INSERT INTO branches (branchcode, branchname)
VALUES ('POL', 'Biblioteca Politécnica')"
```

---

### Problema 2: "duplicate barcode"

**Error:**
```
ERROR: Duplicate barcode 'POL-001234'
```

**Causa:** El código de barras ya existe en Koha

**Solución 1: Verificar duplicado**
```bash
sudo koha-mysql koha-cnc -e "
SELECT barcode, biblionumber, itemcallnumber
FROM items
WHERE barcode='POL-001234'"
```

**Solución 2: Renumerar automáticamente**
```python
# En el script, agregar sufijo
if barcode_existe(barcode):
    barcode = f"{barcode}-DUP{contador}"
```

**Solución 3: Limpiar barcodes duplicados del CSV**
```bash
# Encontrar duplicados
cut -d';' -f12 POL.csv | sort | uniq -d

# Renumerar en CSV
python3 renumerar_barcodes.py POL.csv
```

---

### Problema 3: "invalid item type"

**Error:**
```
ERROR: Item type 'Monografía' not valid
```

**Causa:** El tipo de ítem no existe en Koha o no está mapeado

**Solución 1: Mapear en el script**
```python
ITEMTYPE_MAP = {
    "Monografía": "BK",
    "Monografia": "BK",
    "Libro": "BK",
}
```

**Solución 2: Crear tipo en Koha**
```bash
sudo koha-mysql koha-cnc -e "
INSERT INTO itemtypes (itemtype, description)
VALUES ('BK', 'Libro')"
```

---

### Problema 4: "no title found"

**Error:**
```
WARNING: Record 1234 skipped - no title
```

**Causa:** Campo título vacío en CSV

**Solución:**
```bash
# Encontrar registros sin título
awk -F';' '$4 == ""' POL.csv

# Opción 1: Completar manualmente
# Opción 2: Usar otro campo como título (ej: serie)
# Opción 3: Omitir registro (default del script)
```

---

### Problema 5: "invalid date format"

**Error:**
```
WARNING: Invalid date '15/01/2023' in dateaccessioned
```

**Causa:** Formato de fecha incorrecto

**Solución:**
```python
# Convertir formato
def convertir_fecha(fecha_str):
    # De: 15/01/2023
    # A:  2023-01-15
    try:
        d, m, y = fecha_str.split('/')
        return f"{y}-{m.zfill(2)}-{d.zfill(2)}"
    except:
        return None
```

---

### Problema 6: "encoding error"

**Error:**
```
UnicodeDecodeError: 'utf-8' codec can't decode byte 0xf1
```

**Causa:** Encoding del CSV incorrecto

**Solución:**
```python
# El script ya detecta automáticamente, pero puedes forzar:
encodings = ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1']

for enc in encodings:
    try:
        df = pd.read_csv(csv_file, encoding=enc)
        print(f"✓ Encoding: {enc}")
        break
    except:
        continue
```

---

## 📚 REFERENCIAS Y RECURSOS

### Documentación oficial

1. **MARC 21 Format for Bibliographic Data**
   - https://www.loc.gov/marc/bibliographic/

2. **Koha Manual**
   - https://koha-community.org/manual/

3. **Koha Wiki**
   - https://wiki.koha-community.org/

4. **MARC 21 Concise (español)**
   - https://www.loc.gov/marc/bibliographic/bdintro.html

### Herramientas útiles

1. **Validador MARCXML**
   ```bash
   xmllint --schema MARC21slim.xsd archivo.xml
   ```

2. **Visor de registros MARC**
   - MarcEdit: https://marcedit.reeset.net/

3. **Convertidores online**
   - MARC Record Viewer: https://marcrecord.net/

---

## ✅ CHECKLIST DE VERIFICACIÓN PRE-IMPORTACIÓN

### 1. Preparación de Koha

- [ ] Bibliotecas creadas (branches)
- [ ] Ubicaciones creadas (LOC)
- [ ] Tipos de ítem creados (itemtypes)
- [ ] Usuarios de Koha configurados
- [ ] Backup de base de datos realizado

### 2. Preparación del CSV

- [ ] Archivo CSV accesible
- [ ] Encoding verificado (UTF-8, Latin-1, etc.)
- [ ] Delimitador verificado (`;`, `,`, `|`)
- [ ] Columnas obligatorias presentes:
  - [ ] titulo
  - [ ] codbiblio
  - [ ] nroacceso (o se generará auto)
  - [ ] tipomaterial

### 3. Validación del CSV

- [ ] Ejecutar `analizador_csv.py`
- [ ] Revisar reporte JSON generado
- [ ] Puntuación de calidad > 70%
- [ ] Sin duplicados críticos

### 4. Conversión a MARCXML

- [ ] Parámetros correctos:
  - [ ] `--codbiblio` correcto
  - [ ] `--loc-default` definido
  - [ ] `--stream` para archivos grandes
  - [ ] `--split-by` si > 25,000 registros

### 5. Validación del MARCXML

- [ ] XML bien formado (`xmllint --noout archivo.xml`)
- [ ] Campos obligatorios presentes (001, 245, 952$a, 952$p)
- [ ] Códigos de biblioteca válidos
- [ ] Barcodes únicos

### 6. Importación a Koha

- [ ] Prueba con lote pequeño (100-1000 registros)
- [ ] Verificar en OPAC
- [ ] Importación completa
- [ ] Rebuild de índices Zebra
- [ ] Verificación final en OPAC

---

## 🎓 GLOSARIO

| Término | Definición |
|---------|------------|
| **MARC** | Machine-Readable Cataloging - Formato estándar para catalogación |
| **MARC21** | Versión actual del estándar MARC |
| **MARCXML** | Representación XML del formato MARC21 |
| **Bibliográfico** | Información intelectual de la obra (título, autor, etc.) |
| **Ítem** | Ejemplar físico específico de una obra |
| **Holdings** | Información de posesión de ejemplares |
| **Homebranch** | Biblioteca propietaria permanente del ítem |
| **Holdingbranch** | Biblioteca donde está físicamente el ítem |
| **Barcode** | Código único de identificación del ejemplar |
| **Signatura** | Código de clasificación para ubicar el ítem |
| **LOC** | Código de ubicación física dentro de la biblioteca |
| **OPAC** | Online Public Access Catalog - Catálogo público |
| **Subcampo** | Componente de un campo MARC (ej: $a, $b) |
| **Indicador** | Valores de control en campos MARC (ind1, ind2) |
| **Tag** | Número de campo MARC (ej: 100, 245, 952) |

---

**FIN DE LA GUÍA**

Para preguntas o asistencia, consultar:
- `README.md` - Introducción al sistema
- `GUIA_RAPIDA.md` - Migración paso a paso
- `ANALISIS_Y_PLAN.md` - Análisis del sistema completo

**Última actualización:** 2025-10-17
**Versión del conversor:** 6.0
**Institución:** Universidad Nacional de Asunción
