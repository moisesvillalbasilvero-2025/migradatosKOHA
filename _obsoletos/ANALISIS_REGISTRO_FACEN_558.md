# 🎯 ANÁLISIS DEL REGISTRO FACEN 558
## Campos MARC Usados y Cómo Replicarlos

Basado en el registro real de FACEN:
**https://catalogobibliografico.facen.una.py** (Registro 558)

---

## 📊 CAMPOS MARC DETECTADOS EN FACEN

### Campos de Control

| Campo | Valor en FACEN | Descripción |
|-------|----------------|-------------|
| **Leader** | `03077nam a2200289Ia 4500` | Cabecera MARC |
| **008** | `241024t2014    xx ...` | Elementos fijos |
| **040$a** | `PY-SlUNAC` | Agencia catalogadora |
| **040$b** | `spa` | Idioma de catalogación |
| **040$c** | `rda` | Convenciones (RDA) |
| **041$a** | `spa` | Código de idioma |

### Clasificación

| Campo | Valor en FACEN | Qué es |
|-------|----------------|--------|
| **082$a** | `631.41` | Dewey (CDD) |
| **082$b** | `D543a` | Cutter |

### Autor Principal

| Campo | Valor en FACEN |
|-------|----------------|
| **100$a** | `Díaz Cubilla, Felicia Mabel` |
| **100$e** | `Autor` (rol) |

### Título

| Campo | Valor en FACEN |
|-------|----------------|
| **245$a** | `Aplicación de métodos de oxidación avanzada para la degradación de compuestos fenólicos en agua y suelo contaminados` |
| **245$c** | `/ Felicia Mabel Díaz Cubilla [Autor]; Janina Alejandra Rosso [Orientador] y Paula Isabel Villabrille [Orientador]` |

### Publicación

| Campo | Valor en FACEN |
|-------|----------------|
| **264$a** | `San Lorenzo` |
| **264$b** | `Facultad de Ciencias Exactas y Naturales` |
| **264$c** | `℗2014` |

### Descripción Física

| Campo | Valor en FACEN |
|-------|----------------|
| **300$a** | `63 páginas` |
| **300$c** | `30 centímetros` |

### Notas

| Campo | Valor en FACEN |
|-------|----------------|
| **500$a** | `Incluye referencias bibliográficas` |
| **502$a** | `Trabajo final de postgrado (Máster en Fisicoquímica con énfasis en Fisicoquímica Ambiental)` |
| **520$a** | (Resumen completo de 1300+ caracteres) |

### Materias (Palabras Clave)

| Campo | Valor en FACEN |
|-------|----------------|
| **653$a** | `Agua potable` |
| **653$a** | `Aguas` |
| **653$a** | `Procesos fitoquímicos` |
| **653$a** | `Tratamiento de aguas` |

### Autores Secundarios

| Campo | Valor en FACEN |
|-------|----------------|
| **700$a** | `Rosso, Janina Alejandra` |
| **700$e** | `Orientador` |
| **700$a** | `Villabrille, Paula Isabel` |
| **700$e** | `Orientador` |

### Control Koha

| Campo | Valor en FACEN |
|-------|----------------|
| **942$c** | `Libros` |
| **942$2** | Fecha catalogación |

### Ejemplar (952)

| Campo | Valor en FACEN | Descripción |
|-------|----------------|-------------|
| **952$a** | `Biblioteca e Internet, Facultad de Ciencias Exactas y Naturales` | homebranch |
| **952$b** | `Biblioteca e Internet, Facultad de Ciencias Exactas y Naturales` | holdingbranch |
| **952$8** | `Colección Editorial (CE)` | collection |
| **952$o** | `631.41 D543a` | Signatura |
| **952$p** | `CE41` | Código de barras |
| **952$y** | `Libros` | Tipo |

---

## ✅ AJUSTES NECESARIOS AL SCRIPT

Tu script `opac_exportar.py` ya genera la mayoría de estos campos correctamente. Los ajustes necesarios son:

### 1. Campo 040 (Agencia Catalogadora)

**Actualmente genera:**
```xml
<datafield tag="040" ind1=" " ind2=" ">
  <subfield code="a">POL</subfield>
  <subfield code="b">spa</subfield>
  <subfield code="c">POL</subfield>
</datafield>
```

**Debería generar (estilo FACEN):**
```xml
<datafield tag="040" ind1=" " ind2=" ">
  <subfield code="a">PY-SlUNAC</subfield>
  <subfield code="b">spa</subfield>
  <subfield code="c">rda</subfield>
</datafield>
```

### 2. Campo 082 con Cutter (082$b)

**Actualmente solo genera:**
```xml
<datafield tag="082" ind1="0" ind2="4">
  <subfield code="a">631.4</subfield>
  <subfield code="2">23</subfield>
</datafield>
```

**Debería generar:**
```xml
<datafield tag="082" ind1="0" ind2="4">
  <subfield code="a">631.41</subfield>
  <subfield code="b">D543a</subfield>
  <subfield code="2">23</subfield>
</datafield>
```

### 3. Campo 100 con rol de autor

**Actualmente genera:**
```xml
<datafield tag="100" ind1="1" ind2=" ">
  <subfield code="a">García, José</subfield>
</datafield>
```

**Debería generar (con rol):**
```xml
<datafield tag="100" ind1="1" ind2=" ">
  <subfield code="a">García, José</subfield>
  <subfield code="e">Autor</subfield>
</datafield>
```

### 4. Campo 502 (Nota de Tesis)

**Agregar soporte para:**
```xml
<datafield tag="502" ind1=" " ind2=" ">
  <subfield code="a">Trabajo final de postgrado (Máster en...)</subfield>
</datafield>
```

### 5. Campo 653 en lugar de 650 para materias

FACEN usa **653** (términos no controlados) en lugar de **650** (términos controlados).

**Tu script genera:**
```xml
<datafield tag="650" ind1=" " ind2="4">
  <subfield code="a">Suelos</subfield>
</datafield>
```

**FACEN usa:**
```xml
<datafield tag="653" ind1=" " ind2=" ">
  <subfield code="a">Agua potable</subfield>
</datafield>
```

---

## 🔧 SCRIPT ACTUALIZADO

Voy a crear un script específico para generar registros estilo FACEN:

**Archivo:** `opac_exportar_FACEN.py`

**Cambios principales:**
1. ✅ Campo 040 con `PY-SlUNAC` y `rda`
2. ✅ Campo 082 con Cutter ($b)
3. ✅ Campo 100 con rol $e
4. ✅ Campo 502 para tesis
5. ✅ Campo 653 para materias (palabras clave)
6. ✅ Campo 700 con rol $e para orientadores
7. ✅ Leader correcto según tipo de documento
8. ✅ Campo 008 mejorado

---

## 📝 MAPEO CSV → MARC COMPLETO (ESTILO FACEN)

| Campo CSV | Campo MARC | Valor Ejemplo | Notas |
|-----------|------------|---------------|-------|
| `codbiblio` | 003, 952$a/b | `FACEN` | Código de biblioteca |
| `analisis` | 001 | `000558` | ID único |
| `titulo` | 245$a | `Aplicación de métodos...` | OBLIGATORIO |
| `sub_titulo` | 245$b | | Opcional |
| `autor` | 100$a | `Díaz Cubilla, Felicia Mabel` | Con rol $e=Autor |
| - | 100$e | `Autor` | Rol fijo |
| `mencion` | 245$c | `/ Felicia... [Autor]` | Responsabilidad |
| `editorial` | 264$b | `FACEN` | Editor |
| `procedencia` | 264$a | `San Lorenzo` | Lugar |
| `publicacion` | 264$c | `2014` | Año |
| `paginas` | 300$a | `63 páginas` | Con "páginas" |
| - | 300$c | `30 centímetros` | Dimensión estándar |
| `ubicacion` | 952$o | `631.41 D543a` | Signatura con Cutter |
| - | 082$a | `631.41` | Dewey (de signatura) |
| - | 082$b | `D543a` | Cutter (de signatura) |
| `nroacceso` | 952$p | `CE41` | Código de barras |
| `tipomaterial` | 942$c, 952$y | `Libros` | Tipo de documento |
| `temas_descrip` | 653$a | `Agua potable ; Aguas` | Separar por ; |
| `sintesis` | 520$a | (Resumen largo) | Resumen completo |
| `notas` | 500$a | `Incluye referencias...` | Notas generales |
| - | 502$a | `Trabajo final de postgrado...` | Si es tesis |
| `coautor` / orientadores | 700$a | `Rosso, Janina Alejandra` | Con rol $e |
| - | 700$e | `Orientador` | Rol específico |

---

## 🎯 RESUMEN DE DIFERENCIAS FACEN vs ESTÁNDAR

| Aspecto | Estándar General | FACEN |
|---------|------------------|-------|
| **Agencia** | Código biblioteca | `PY-SlUNAC` |
| **Convenciones** | `aacr` | `rda` |
| **Materias** | 650 (controlado) | 653 (libre) |
| **Cutter** | Solo en 952$o | También en 082$b |
| **Rol autor** | Sin especificar | Con $e=Autor |
| **Rol orientador** | Genérico | Específico "Orientador" |
| **Tesis** | 500 genérico | 502 específico |
| **Dimensiones** | Opcional | Siempre "30 centímetros" |
| **Páginas** | "350 p." | "63 páginas" (completo) |

---

## ✅ VALIDACIÓN

Tu registro generado DEBE verse así en la vista MARC:

```
000 -CABECERA
    03077nam a2200289Ia 4500
008 -ELEMENTOS DE LONGITUD FIJA
    251015s2023    py ||||||||||||| ||spa||
040 ## -FUENTE DE CATALOGACIÓN
    $a PY-SlUNAC $b spa $c rda
082 ## -CLASIFICACIÓN DEWEY
    $a 631.41 $b D543a $2 23
100 ## -AUTOR PRINCIPAL
    $a Díaz Cubilla, Felicia Mabel $e Autor
245 #0 -TÍTULO
    $a Aplicación de métodos... $c / Felicia Mabel...
264 ## -PUBLICACIÓN
    $a San Lorenzo $b FACEN $c 2014
300 ## -DESCRIPCIÓN
    $a 63 páginas $c 30 centímetros
500 ## -NOTA
    $a Incluye referencias bibliográficas
502 ## -TESIS
    $a Trabajo final de postgrado (Máster...)
520 ## -RESUMEN
    $a Los compuestos fenólicos...
653 ## -MATERIAS
    $a Agua potable
653 ## -MATERIAS
    $a Aguas
700 ## -AUTOR SECUNDARIO
    $a Rosso, Janina Alejandra $e Orientador
942 ## -KOHA
    $c Libros
952 ## -EJEMPLAR
    $a FACEN $b FACEN $o 631.41 D543a $p CE41 $y Libros
```

---

**Próximo paso:** ¿Quieres que actualice el script `opac_exportar.py` para generar este formato exacto de FACEN?

