# 🎯 GUÍA: FILTRADO CORRECTO POR FACULTAD DE INGENIERÍA

**Universidad Nacional de Asunción - Sistema Koha**

---

## ⚠️ PROBLEMA COMÚN

Cuando buscas "ingeniería" o "ING" en el OPAC, aparecen resultados de **DOS bibliotecas diferentes**:

1. **ING** - Biblioteca de la Facultad de Ingeniería (205 registros)
2. **POL** - Facultad Politécnica (256 registros sobre temas de ingeniería)

**IMPORTANTE:** Estas son bibliotecas DIFERENTES. La Politécnica tiene libros sobre ingeniería, pero están en OTRA biblioteca física.

---

## ✅ MÉTODOS CORRECTOS DE FILTRADO

### Método 1: Filtro por Biblioteca en OPAC (RECOMENDADO)

**Paso a paso:**

1. Ir al OPAC: `http://[servidor]:8080`

2. Click en **"Búsqueda avanzada"** (Advanced search)

3. En el formulario de búsqueda:
   - Campo de búsqueda: *[dejar vacío o escribir término]*
   - **Biblioteca:** Seleccionar **"ING - Biblioteca de la Facultad de Ingeniería"**
   - NO seleccionar "POL"

4. Click en "Buscar"

**Esto mostrará SOLO los registros físicamente ubicados en la Facultad de Ingeniería**

---

### Método 2: URL Directa con Parámetro de Biblioteca

**Para usuarios finales (OPAC):**
```
http://[servidor]:8080/cgi-bin/koha/opac-search.pl?idx=&q=&branch=ING
```

**Para buscar un término específico en la Facultad de Ingeniería:**
```
http://[servidor]:8080/cgi-bin/koha/opac-search.pl?idx=&q=construccion&branch=ING
```

**Para Staff Interface:**
```
http://[servidor]/cgi-bin/koha/catalogue/search.pl?idx=&q=&branch=ING
```

---

### Método 3: Búsqueda por Código de Barras

**Solo registros NUEVOS de Ingeniería (importados hoy):**

En el buscador del OPAC:
```
Buscar: ING-
```

Esto mostrará solo los registros con códigos de barras que comienzan con "ING-":
- ING-0000001
- ING-0000002
- ...
- ING-0000100

---

### Método 4: Consulta SQL Directa (Para Administradores)

```sql
-- Ver SOLO registros de la Facultad de Ingeniería
SELECT
    b.title AS titulo,
    b.author AS autor,
    i.barcode AS codigo_barras,
    i.homebranch AS biblioteca,
    i.itemcallnumber AS signatura
FROM biblio b
JOIN items i ON b.biblionumber = i.biblionumber
WHERE i.homebranch = 'ING'
LIMIT 20;
```

---

## 📊 ESTADÍSTICAS ACTUALES

### Bibliotecas en el Sistema

| Código | Nombre | Total Registros |
|--------|--------|-----------------|
| **ING** | Biblioteca de la Facultad de Ingeniería | **205** |
| POL | Centro de Información Politécnica | 12,467 |
| AGRO | Facultad de Ciencias Agrarias | 37,226 |
| ARQ | Facultad de Arquitectura | 3,944 |
| FACEN | Facultad de Ciencias Exactas | 37 |
| Otras | Varias | ~1,500 |

### Desglose de Registros ING

```
Total ING: 205 registros
├── Registros anteriores: ~105 (códigos antiguos: 35, 3, 23, etc.)
└── Registros nuevos (importados hoy): 100 (ING-0000001 a ING-0000100)
```

---

## ⚠️ POR QUÉ APARECEN REGISTROS DE POLITÉCNICA

**Razón:** La Facultad Politécnica tiene **256 libros sobre temas de ingeniería** en su propia biblioteca.

Ejemplos de libros de POL sobre ingeniería:
- "Mecánica para ingenieros" (POL-0000169)
- "Ingeniería económica" (POL-0000130)
- "Métodos numéricos para la física y la ingeniería" (POL-0000125)

**Esto es CORRECTO y NORMAL:**
- Son libros diferentes
- Están en una biblioteca diferente (Politécnica)
- Tienen códigos de barras diferentes (POL-XXXXXXX)
- Están físicamente en otro lugar

---

## 🔍 DIFERENCIA CLAVE: Biblioteca vs. Tema

### ❌ INCORRECTO: Buscar por palabra clave

Si buscas simplemente **"ingeniería"** sin filtrar por biblioteca:
- Resultado: ~461 registros (205 de ING + 256 de POL)
- Incluye libros de TODAS las bibliotecas que mencionan "ingeniería"

### ✅ CORRECTO: Filtrar por biblioteca ING

Si filtras por **Biblioteca: ING**:
- Resultado: 205 registros
- SOLO libros que están físicamente en la Facultad de Ingeniería

---

## 🎓 EJEMPLOS PRÁCTICOS

### Ejemplo 1: Buscar libros de construcción en Ingeniería

**Paso 1:** Ir a Búsqueda avanzada

**Paso 2:** Configurar:
```
Término de búsqueda: construcción
Biblioteca: ING - Biblioteca de la Facultad de Ingeniería
```

**Resultado:** Solo libros sobre construcción que están en la Facultad de Ingeniería

---

### Ejemplo 2: Ver todos los libros de Ingeniería

**Paso 1:** Ir a Búsqueda avanzada

**Paso 2:** Configurar:
```
Término de búsqueda: [dejar vacío o poner *]
Biblioteca: ING - Biblioteca de la Facultad de Ingeniería
```

**Resultado:** Todos los 205 libros de la Facultad de Ingeniería

---

### Ejemplo 3: Comparar libros sobre un tema en diferentes bibliotecas

**Para ver libros sobre mecánica en ING:**
```
Término: mecánica
Biblioteca: ING
```

**Para ver libros sobre mecánica en POL:**
```
Término: mecánica
Biblioteca: POL
```

---

## 🛠️ VERIFICACIÓN

### Prueba 1: Verificar que el filtro funciona

```bash
# Contar registros de ING
sudo koha-mysql koha-cnc -e "SELECT COUNT(*) FROM items WHERE homebranch = 'ING';"
# Resultado esperado: 205

# Contar registros de POL
sudo koha-mysql koha-cnc -e "SELECT COUNT(*) FROM items WHERE homebranch = 'POL';"
# Resultado esperado: 12467
```

### Prueba 2: Ver códigos de barras de cada biblioteca

```bash
# Ver 10 códigos de ING
sudo koha-mysql koha-cnc -e "SELECT barcode FROM items WHERE homebranch = 'ING' LIMIT 10;"

# Ver 10 códigos de POL
sudo koha-mysql koha-cnc -e "SELECT barcode FROM items WHERE homebranch = 'POL' LIMIT 10;"
```

---

## 📝 RESUMEN

### ✅ Lo que está CORRECTO:
- Los registros de ING tienen `homebranch = 'ING'` ✓
- Los registros de POL tienen `homebranch = 'POL'` ✓
- Los códigos de barras son únicos ✓
- Las bibliotecas están separadas correctamente ✓

### ⚠️ Lo que puede confundir:
- POL tiene libros SOBRE ingeniería, pero son de otra biblioteca
- Si buscas por palabra clave sin filtrar, aparecen ambas bibliotecas
- Los nombres de las bibliotecas son similares (Ingeniería vs Politécnica)

### 💡 Solución:
**SIEMPRE usar el filtro de biblioteca en Búsqueda avanzada**

```
Búsqueda avanzada → Biblioteca: ING - Biblioteca de la Facultad de Ingeniería
```

---

## 🔗 ENLACES RÁPIDOS

**Ver todos los registros de Ingeniería:**
```
http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=ING
```

**Ver todos los registros de Politécnica:**
```
http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=POL
```

---

**Fecha:** 2025-10-20
**Sistema:** Koha MARC21
**Universidad Nacional de Asunción**
