# 📊 TABLA DE MAPEO DE CAMPOS
## Firebird → CSV → MARC21 → Koha

**Documento para Unidades Académicas**

Este documento muestra cómo se mapean los campos desde su base de datos Firebird actual hacia el sistema Koha.

---

## 🎯 OBJETIVO

Cada unidad académica debe revisar esta tabla y confirmar:
1. ✅ Los nombres de campos en su base Firebird
2. ✅ Qué datos tiene disponibles
3. ✅ Cómo deben mapearse a Koha

---

## 📋 TABLA DE MAPEO COMPLETA

### SECCIÓN 1: IDENTIFICACIÓN DEL REGISTRO

| Campo Firebird | Campo CSV | MARC21 | Koha Field | Descripción | Obligatorio |
|----------------|-----------|--------|------------|-------------|-------------|
| `ID_REGISTRO` | `analisis` | 001 | biblionumber | Identificador único del registro | ✅ SÍ |
| `CODIGO_FACULTAD` | `codbiblio` | 003 | - | Código de la biblioteca/facultad | ✅ SÍ |

### SECCIÓN 2: TÍTULO Y RESPONSABILIDAD

| Campo Firebird | Campo CSV | MARC21 | Koha Field | Descripción | Obligatorio |
|----------------|-----------|--------|------------|-------------|-------------|
| `TITULO` | `titulo` | 245$a | biblio.title | Título principal del documento | ✅ SÍ |
| `SUBTITULO` | `sub_titulo` | 245$b | biblio.subtitle | Subtítulo o título complementario | ❌ No |
| `TITULO_SERIE` | `titulo_serie` | 490$a | - | Nombre de la serie o colección | ❌ No |
| `OTRO_TITULO` | `otro_titulo` | 246$a | - | Título alternativo o paralelo | ❌ No |
| `MENCION_RESPONSABILIDAD` | `mencion` | 245$c | - | Mención de responsabilidad | ⚠️ Recomendado |

### SECCIÓN 3: AUTORES

| Campo Firebird | Campo CSV | MARC21 | Koha Field | Descripción | Obligatorio |
|----------------|-----------|--------|------------|-------------|-------------|
| `AUTOR` | `autor` | 100$a | biblio.author | Autor personal principal | ⚠️ Recomendado |
| `AUTOR_INSTITUCIONAL` | `autorinst` | 110$a | - | Autor corporativo/institución | ❌ No |
| `COAUTOR_1` | `coautor` | 700$a | - | Coautor o autor secundario | ❌ No |

### SECCIÓN 4: PUBLICACIÓN

| Campo Firebird | Campo CSV | MARC21 | Koha Field | Descripción | Obligatorio |
|----------------|-----------|--------|------------|-------------|-------------|
| `EDITORIAL` | `editorial` | 264$b | biblioitems.publishercode | Nombre de la editorial | ⚠️ Recomendado |
| `LUGAR_PUBLICACION` | `procedencia` | 264$a | biblioitems.place | Ciudad de publicación | ⚠️ Recomendado |
| `ANO_PUBLICACION` | `publicacion` | 264$c | biblioitems.publicationyear | Año de publicación | ⚠️ Recomendado |
| `EDICION` | `edicion` | 250$a | - | Número o descripción de edición | ❌ No |

### SECCIÓN 5: DESCRIPCIÓN FÍSICA

| Campo Firebird | Campo CSV | MARC21 | Koha Field | Descripción | Obligatorio |
|----------------|-----------|--------|------------|-------------|-------------|
| `PAGINAS` | `paginas` | 300$a | biblioitems.pages | Número de páginas | ❌ No |
| `ILUSTRACIONES` | - | 300$b | - | Ilustraciones, gráficos, etc. | ❌ No |
| `DIMENSIONES` | - | 300$c | - | Tamaño en centímetros | ❌ No |

### SECCIÓN 6: IDENTIFICADORES ESTÁNDAR

| Campo Firebird | Campo CSV | MARC21 | Koha Field | Descripción | Obligatorio |
|----------------|-----------|--------|------------|-------------|-------------|
| `ISBN` | `isbn_issn` | 020$a | biblioitems.isbn | ISBN del libro | ⚠️ Recomendado |
| `ISSN` | `isbn_issn` | 022$a | biblioitems.issn | ISSN de la revista | ❌ No |

### SECCIÓN 7: CONTENIDO Y MATERIAS

| Campo Firebird | Campo CSV | MARC21 | Koha Field | Descripción | Obligatorio |
|----------------|-----------|--------|------------|-------------|-------------|
| `RESUMEN` | `sintesis` | 520$a | - | Resumen o abstract | ❌ No |
| `NOTAS` | `notas` | 500$a | - | Notas generales | ❌ No |
| `MATERIAS` | `temas_descrip` | 650$a | - | Materias o temas (separadas por ;) | ⚠️ Recomendado |
| `SERIE` | `serie_mon` | 490$a | biblioitems.seriestitle | Serie monográfica | ❌ No |

### SECCIÓN 8: EJEMPLARES (ÍTEMS) - MUY IMPORTANTE

| Campo Firebird | Campo CSV | MARC21 | Koha Field | Descripción | Obligatorio |
|----------------|-----------|--------|------------|-------------|-------------|
| `CODIGO_FACULTAD` | `codbiblio` | 952$a | items.homebranch | Biblioteca propietaria | ✅ SÍ |
| `CODIGO_FACULTAD` | `codbiblio` | 952$b | items.holdingbranch | Biblioteca donde está físicamente | ✅ SÍ |
| `UBICACION_FISICA` | `loc` | 952$c | items.location | Ubicación dentro de la biblioteca | ⚠️ Recomendado |
| `SIGNATURA` | `ubicacion` | 952$o | items.itemcallnumber | Signatura/cota topográfica | ✅ SÍ |
| `CODIGO_BARRAS` | `nroacceso` | 952$p | items.barcode | Código de barras ÚNICO | ✅ SÍ |
| `TIPO_MATERIAL` | `tipomaterial` | 952$y | items.itype | Tipo de material | ✅ SÍ |
| `VOLUMEN` | `volumen` | 952$h | items.enumchron | Volumen/tomo/número | ❌ No |
| `FECHA_ADQUISICION` | `fechaadq` | 952$d | items.dateaccessioned | Fecha de ingreso | ❌ No |
| `PRECIO` | `precio` | 952$g | items.price | Precio de compra | ❌ No |
| `FORMA_ADQUISICION` | `forma_adqui` | - | - | Cómo se adquirió (compra, donación) | ❌ No |
| `NUMERO_EJEMPLAR` | `ejemplar` | - | items.copynumber | Número de ejemplar | ❌ No |

---

## 🔑 VALORES AUTORIZADOS

### Códigos de Biblioteca (homebranch/holdingbranch)

Cada facultad debe tener un código ÚNICO de 3-10 caracteres:

| Código Sugerido | Nombre Completo |
|-----------------|-----------------|
| `POL` | Biblioteca Politécnica |
| `FACAGR` | Facultad de Ciencias Agrarias |
| `FACEN` | Facultad de Ciencias Exactas y Naturales |
| `FACMED` | Facultad de Ciencias Médicas |
| `FACDER` | Facultad de Derecho |
| `FACECON` | Facultad de Ciencias Económicas |
| `FACFIL` | Facultad de Filosofía |
| `FACING` | Facultad de Ingeniería |
| *(agregar otras)* | |

### Ubicaciones Físicas (LOC - location)

| Código | Descripción | Préstamo |
|--------|-------------|----------|
| `SALA` | Sala de lectura | ✅ Sí |
| `REF` | Referencia | ❌ No |
| `DEP` | Depósito | ✅ Sí |
| `TESIS` | Tesis | ⚠️ Depende |
| `HEMEROTE CA` | Hemeroteca | ⚠️ Depende |
| `RESERVA` | Reserva | ⚠️ Depende |

### Tipos de Material (itemtype)

| Código | Descripción | Tipo MARC |
|--------|-------------|-----------|
| `BK` | Libro | Book |
| `MG` | Revista/Magazine | Continuing Resource |
| `TES` | Tesis | Thesis |
| `VM` | Material visual (DVD, Video) | Visual Material |
| `MU` | Música (CD audio) | Music |
| `MP` | Mapa | Cartographic Material |
| `MX` | Material mixto | Mixed Material |

---

## 📝 INSTRUCCIONES PARA UNIDADES ACADÉMICAS

### Paso 1: Revisar Nombres de Campos

Comparar con su base de datos Firebird actual:

```sql
-- En su servidor Firebird, ejecutar:
SELECT FIRST 10 * FROM BIBLIOGRAFICOS;
SELECT FIRST 10 * FROM EJEMPLARES;
```

Completar esta tabla:

| Mi Campo en Firebird | Corresponde a | Observaciones |
|---------------------|---------------|---------------|
| Ejemplo: `TIT_LIBRO` | `TITULO` | Campo obligatorio |
| | | |
| | | |

### Paso 2: Identificar Campos Faltantes

Marcar qué campos NO tienen en su BD:

- [ ] SUBTITULO
- [ ] AUTOR
- [ ] EDITORIAL
- [ ] ISBN
- [ ] RESUMEN
- [ ] MATERIAS
- [ ] CODIGO_BARRAS
- [ ] SIGNATURA
- [ ] UBICACION_FISICA

### Paso 3: Definir Códigos

**Código de su biblioteca (3-10 caracteres):**
```
Mi código: _______________
Ejemplo: FACAGR
```

**Ubicaciones que manejan:**
```
1. SALA - Sala de lectura
2. ___________ - _______________
3. ___________ - _______________
4. ___________ - _______________
```

**Tipos de material que tienen:**
```
1. BK - Libros
2. ___________ - _______________
3. ___________ - _______________
```

### Paso 4: Proporcionar Datos de Conexión

**Datos del servidor Firebird** (confidencial - enviar por canal seguro):

```
IP del servidor: ___________________
Puerto: 3050 (generalmente)
Base de datos: /ruta/a/base.fdb
Usuario: SYSDBA (generalmente)
Password: ___________________
```

**Información de contacto:**
```
Responsable: ___________________
Email: ___________________
Teléfono: ___________________
```

---

## 🎓 EJEMPLOS PRÁCTICOS

### Ejemplo 1: Libro Simple

**Datos en Firebird:**
```
TITULO: "El suelo y su formación"
AUTOR: "García, José"
EDITORIAL: "Editorial UNA"
ANO: 2023
CODIGO_BARRAS: "001234"
SIGNATURA: "631.4 G216s"
```

**Resultado en Koha:**
- Título: El suelo y su formación
- Autor: García, José
- Editorial: Editorial UNA
- Año: 2023
- Ítem con barcode: FACAGR-001234
- Ubicado en: FACAGR - SALA
- Signatura: 631.4 G216s

### Ejemplo 2: Revista

**Datos en Firebird:**
```
TITULO: "Revista de Ciencias Agrarias"
ISSN: "1234-5678"
EDITORIAL: "FACAGR"
TIPO_MATERIAL: "Revista"
```

**Resultado en Koha:**
- Título: Revista de Ciencias Agrarias
- ISSN: 1234-5678
- Tipo: Revista (MG)
- Ubicación: HEMEROTECA

---

## ✅ CHECKLIST DE INFORMACIÓN REQUERIDA

**Para iniciar la migración de su biblioteca, necesitamos:**

- [ ] Tabla de mapeo de campos completada
- [ ] Lista de ubicaciones (LOC) que manejan
- [ ] Lista de tipos de material
- [ ] Código propuesto para la biblioteca
- [ ] Datos de conexión a Firebird
- [ ] Contacto del responsable
- [ ] Muestra de 100 registros (CSV o SQL)
- [ ] Cantidad aproximada de registros bibliográficos
- [ ] Cantidad aproximada de ejemplares

---

## 📞 CONTACTO Y SOPORTE

**Para consultas sobre esta tabla de mapeo:**

- Email: soporte.biblioteca@una.py
- Sistema: Migración a Koha MARC21
- Documento: TABLA_MAPEO_V1.0

---

## 🔄 PROCESO DE MIGRACIÓN

Una vez recibida toda la información:

1. ✅ Validamos la estructura de su BD
2. ✅ Creamos script de exportación personalizado
3. ✅ Generamos archivo CSV de prueba (100 registros)
4. ✅ Convertimos a MARCXML
5. ✅ Importamos lote de prueba a Koha
6. ✅ Revisamos juntos los resultados
7. ✅ Ajustamos si es necesario
8. ✅ Ejecutamos migración completa
9. ✅ Verificamos la importación
10. ✅ Configuramos sincronización automática

**Tiempo estimado:** 1-2 semanas por biblioteca

---

**Fecha:** 2025-01-15
**Versión:** 1.0
**Sistema:** Koha MARC21 + Firebird 2.7.5
