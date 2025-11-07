# 🛡️ GUÍA COMPLETA: Prevención de Duplicados en Koha

**Versión:** 1.0
**Fecha:** 25 de Octubre de 2025
**Objetivo:** CERO duplicados en el catálogo

---

## 🎯 ¿Por qué son malos los duplicados?

### Problemas que causan:

```
❌ Confusión para usuarios
   → Dos registros del mismo libro
   → No saben cuál es el correcto

❌ Búsquedas ineficientes
   → Resultados repetidos
   → Catálogo desorganizado

❌ Estadísticas incorrectas
   → Total de títulos inflado
   → Reportes erróneos

❌ Pérdida de tiempo
   → Limpiar duplicados después es MUY trabajoso
```

---

## 🔍 Tipos de Duplicados

### 1. **Duplicado CRÍTICO** 🔴 (Nunca permitir)

**Mismo código de barras:**
```
LIBRO001 → "Don Quijote" (Ingeniería)
LIBRO001 → "Cien años de soledad" (Odontología)
          ❌ IMPOSIBLE - Código debe ser ÚNICO
```

**Impacto:** Sistema no puede distinguir cuál es cuál

---

### 2. **Duplicado REAL** 🟠 (Evitar)

**Mismo libro importado dos veces:**
```
Registro 1:
  - Título: "Don Quijote de la Mancha"
  - Autor: "Cervantes Saavedra, Miguel de"
  - ISBN: 978-84-376-0455-8
  - Barcode: LIBRO001

Registro 2:
  - Título: "Don Quijote de la Mancha"
  - Autor: "Cervantes Saavedra, Miguel de"
  - ISBN: 978-84-376-0455-8
  - Barcode: LIBRO002  ← Diferente código pero MISMO libro

❌ DUPLICADO REAL - Debe ser un solo registro con 2 ejemplares
```

**Cómo debería ser:**
```
✅ UN SOLO REGISTRO:
   - Título: "Don Quijote de la Mancha"
   - Autor: "Cervantes Saavedra, Miguel de"
   - ISBN: 978-84-376-0455-8
   - Ejemplares:
     * LIBRO001 (Ingeniería)
     * LIBRO002 (Odontología)
```

---

### 3. **Falso Duplicado** 🟢 (OK - Permitir)

**Diferentes ediciones del mismo libro:**
```
Edición 1:
  - Título: "Don Quijote"
  - Editorial: Planeta
  - Año: 2005
  - ISBN: 978-84-376-0455-8

Edición 2:
  - Título: "Don Quijote"
  - Editorial: Cátedra
  - Año: 2010
  - ISBN: 978-84-376-1234-5  ← ISBN diferente

✅ OK - Son ediciones DIFERENTES
```

---

## 🛠️ Sistema de Prevención Implementado

### Archivo: `/home/mvillalba/migradatos/prevenir_duplicados.sh`

Este script tiene **9 funciones** para prevenir duplicados:

```bash
1. barcode_existe_en_bd()            → ¿Este código ya existe?
2. isbn_existe_en_bd()               → ¿Este ISBN ya existe?
3. titulo_autor_existe_en_bd()       → ¿Este libro ya existe?
4. obtener_biblionumber_por_isbn()   → Dame el ID del libro por ISBN
5. obtener_biblionumber_por_titulo_autor()  → Dame el ID por título+autor
6. verificar_duplicados_en_csv()     → Buscar duplicados DENTRO del CSV
7. verificar_duplicados_csv_vs_bd()  → Buscar duplicados CSV vs BD
8. importar_inteligente()            → Decidir si crear o agregar ejemplar
9. generar_reporte_duplicados()      → Reporte HTML de duplicados
```

---

## 📋 Verificación en 3 Niveles

### NIVEL 1: Duplicados DENTRO del CSV

```bash
# Antes de importar, verificar el CSV mismo
./prevenir_duplicados.sh verificar_csv importar_aqui/ING.csv
```

**Qué busca:**
```
✓ Códigos de barras repetidos en el CSV
✓ ISBNs repetidos en el CSV
✓ Títulos+Autores repetidos en el CSV
```

**Ejemplo de salida:**
```
════════════════════════════════════════════════════════════
  VERIFICACIÓN DE DUPLICADOS EN CSV
════════════════════════════════════════════════════════════

1. Códigos de barras duplicados en CSV:
   ✗ ENCONTRADOS:
     - LIBRO001 (aparece 2 veces)
     - LIBRO005 (aparece 3 veces)

2. ISBNs duplicados en CSV:
   ⚠ ENCONTRADOS:
     - 978-84-376-0455-8 (aparece 2 veces)

❌ ACCIÓN: Corregir códigos de barras antes de importar
```

---

### NIVEL 2: Duplicados CSV vs BASE DE DATOS

```bash
# Verificar si lo que vas a importar ya existe en Koha
source prevenir_duplicados.sh
verificar_duplicados_csv_vs_bd importar_aqui/ING.csv
```

**Qué busca:**
```
✓ ¿Estos barcodes ya están en la BD?
✓ ¿Estos ISBNs ya están en la BD?
✓ ¿Estos títulos+autores ya están en la BD?
```

**Ejemplo de salida:**
```
════════════════════════════════════════════════════════════
  VERIFICACIÓN: CSV vs BASE DE DATOS
════════════════════════════════════════════════════════════

Analizando registros...

✗ DUPLICADO - Barcode: LIBRO001
  Título: Don Quijote de la Mancha

⚠ POSIBLE DUPLICADO - ISBN: 978-84-376-0455-8
  Título: Don Quijote de la Mancha
  (Puede ser nuevo ejemplar de libro existente)

════════════════════════════════════════════════════════════
  RESUMEN
════════════════════════════════════════════════════════════
Total registros analizados: 150
Códigos de barras duplicados: 1
ISBNs que ya existen: 3
Títulos+Autores que ya existen: 2

❌ CRÍTICO: Hay códigos de barras duplicados
   Acción: CORREGIR antes de importar
```

---

### NIVEL 3: Importación Inteligente (AUTOMÁTICO)

Durante la importación, el sistema decide automáticamente:

```
Para cada registro del CSV:

┌─────────────────────────────────────┐
│ ¿El barcode ya existe?              │
└─────────────────────────────────────┘
          │
    SÍ ─→ ❌ ERROR - No importar
          │
    NO ─→ ✓ Continuar
          │
          ▼
┌─────────────────────────────────────┐
│ ¿El ISBN ya existe en BD?           │
└─────────────────────────────────────┘
          │
    SÍ ─→ 📚 Agregar EJEMPLAR al libro existente
          │
    NO ─→ Continuar
          │
          ▼
┌─────────────────────────────────────┐
│ ¿Título + Autor ya existe en BD?    │
└─────────────────────────────────────┘
          │
    SÍ ─→ 📚 Agregar EJEMPLAR al libro existente
          │
    NO ─→ ✨ Crear NUEVO registro completo
```

---

## 🚀 Uso Práctico

### Paso 1: Verificar CSV antes de importar

```bash
cd /home/mvillalba/migradatos

# Cargar funciones
source prevenir_duplicados.sh

# Verificar duplicados internos
verificar_duplicados_en_csv importar_aqui/ING.csv
```

**Resultado:**
- Si encuentra duplicados → Corregir CSV
- Si no encuentra → Continuar al Paso 2

---

### Paso 2: Verificar CSV vs Base de Datos

```bash
# Verificar contra BD
verificar_duplicados_csv_vs_bd importar_aqui/ING.csv
```

**Interpretación de resultados:**

| Código | Significado | Acción |
|--------|-------------|--------|
| **0** | Sin duplicados | ✅ Importar con confianza |
| **1** | Barcodes duplicados | ❌ DETENER - Corregir CSV |
| **2** | ISBNs/Títulos duplicados | ⚠️ Revisar si son nuevos ejemplares |

---

### Paso 3: Importar con Modo Inteligente

```bash
# El validador ya incluye verificación de duplicados
./validar_antes_importar.sh importar_aqui/ING.csv

# Si pasa validación, importar
./importar_biblioteca.sh ING
```

El sistema automáticamente:
- ✅ Detecta libros existentes
- ✅ Agrega ejemplares en vez de duplicar
- ✅ Crea solo registros nuevos

---

## 📊 Ejemplos Reales

### Ejemplo 1: Código de Barras Duplicado (ERROR)

**CSV:**
```csv
title,author,barcode,...
"Libro A","Autor A","LIBRO001",...
"Libro B","Autor B","LIBRO001",...  ← ❌ MISMO CÓDIGO
```

**Resultado:**
```
❌ ERROR CRÍTICO
   Barcode LIBRO001 aparece 2 veces
   Acción: Cambiar uno de ellos
```

**Solución:**
```csv
title,author,barcode,...
"Libro A","Autor A","LIBRO001",...
"Libro B","Autor B","LIBRO002",...  ← ✅ Código único
```

---

### Ejemplo 2: Libro Ya Existe (Agregar Ejemplar)

**En la BD ya existe:**
```
biblionumber: 123
Título: "Don Quijote"
Autor: "Cervantes, Miguel de"
ISBN: 978-84-376-0455-8
Ejemplares:
  - LIBRO001 (Ingeniería)
```

**Intentas importar:**
```csv
title,author,isbn,barcode,...
"Don Quijote","Cervantes, Miguel de","978-84-376-0455-8","LIBRO002",...
```

**Sistema decide:**
```
🔍 Detectado: ISBN 978-84-376-0455-8 ya existe
📚 Acción: Agregar EJEMPLAR al biblionumber 123

✅ Resultado en BD:
   biblionumber: 123
   Título: "Don Quijote"
   Ejemplares:
     - LIBRO001 (Ingeniería)
     - LIBRO002 (Odontología)  ← NUEVO
```

---

### Ejemplo 3: Diferentes Ediciones (OK)

**En BD existe:**
```
Título: "Cálculo"
Autor: "Larson, Ron"
ISBN: 978-968-18-6186-8  (9na edición, 2006)
```

**Importas:**
```csv
title,author,isbn,...
"Cálculo","Larson, Ron","978-968-18-7777-7",...  ← ISBN diferente
```

**Sistema decide:**
```
🔍 Título "Cálculo" + Autor "Larson, Ron" existe
🔍 Pero ISBN es diferente
✨ Acción: Crear NUEVO registro (es otra edición)

✅ Resultado: 2 registros (OK)
   - Edición 9na (2006)
   - Edición 10ma (2010)
```

---

## 🧹 Limpiar Duplicados Existentes

Si ya tienes duplicados en la BD:

```bash
# 1. Encontrar duplicados por ISBN
koha-mysql koha-cnc -e "
SELECT isbn, COUNT(*) as total
FROM biblioitems
WHERE isbn IS NOT NULL AND isbn != ''
GROUP BY isbn
HAVING total > 1
ORDER BY total DESC
"

# 2. Encontrar duplicados por Título + Autor
koha-mysql koha-cnc -e "
SELECT title, author, COUNT(*) as total
FROM biblio
GROUP BY title, author
HAVING total > 1
ORDER BY total DESC
"

# 3. Ver detalles de un duplicado específico
koha-mysql koha-cnc -e "
SELECT
    b.biblionumber,
    b.title,
    b.author,
    bi.isbn,
    COUNT(i.itemnumber) as num_ejemplares
FROM biblio b
JOIN biblioitems bi ON b.biblionumber = bi.biblionumber
LEFT JOIN items i ON b.biblionumber = i.biblionumber
WHERE bi.isbn = '978-84-376-0455-8'
GROUP BY b.biblionumber
"
```

**Fusionar duplicados manualmente:**
```bash
# Mover ejemplares del duplicado al registro principal
koha-mysql koha-cnc -e "
UPDATE items
SET biblionumber = 123,  -- ID del registro principal
    biblioitemnumber = 456
WHERE biblionumber = 789  -- ID del duplicado
"

# Eliminar registro duplicado vacío
koha-mysql koha-cnc -e "
DELETE FROM biblio WHERE biblionumber = 789
"
```

---

## 📋 Checklist Anti-Duplicados

### Antes de Importar:
```
□ Verificar duplicados en el CSV
□ Verificar duplicados CSV vs BD
□ Revisar códigos de barras únicos
□ Confirmar que ISBNs repetidos son ediciones diferentes
□ Hacer backup de la BD (por si acaso)
```

### Durante Importación:
```
□ Usar modo inteligente (detecta duplicados automáticamente)
□ Revisar logs por mensajes de "Libro existe"
□ Confirmar que agrega ejemplares en vez de duplicar
```

### Después de Importar:
```
□ Buscar posibles duplicados en OPAC
□ Verificar que títulos no aparezcan 2 veces
□ Revisar estadísticas de catálogo
```

---

## 🎯 Estrategias de Prevención

### Estrategia 1: Códigos de Barras Únicos

```bash
# Usar prefijo por biblioteca
ING-001, ING-002, ING-003  (Ingeniería)
ODO-001, ODO-002, ODO-003  (Odontología)
QUI-001, QUI-002, QUI-003  (Química)

# O usar año + secuencial
2025-001, 2025-002, 2025-003
```

### Estrategia 2: Validar SIEMPRE Antes

```bash
# NUNCA importar sin validar
./validar_antes_importar.sh archivo.csv  # ← OBLIGATORIO

# Solo si pasa validación
./importar_biblioteca.sh archivo
```

### Estrategia 3: Importación Incremental

```bash
# No importar todo de una vez
# Dividir en lotes y verificar c/u

./importar_por_lotes.sh archivo.csv 100
# Verificar después de cada lote
```

---

## 🚨 Casos de Emergencia

### "Ya importé y tengo 500 duplicados"

```bash
# 1. Detener inmediatamente
sudo koha-plack --stop koha-cnc

# 2. Hacer backup
sudo koha-dump koha-cnc

# 3. Identificar duplicados
koha-mysql koha-cnc -e "
SELECT title, COUNT(*) FROM biblio
GROUP BY title HAVING COUNT(*) > 1
" > duplicados.txt

# 4. Contactar soporte antes de eliminar
```

---

## 📚 Resumen

### ✅ SIEMPRE:
- Validar CSV antes de importar
- Usar códigos de barras únicos
- Verificar contra base de datos
- Hacer backup antes de importar masivo

### ❌ NUNCA:
- Importar sin validar
- Repetir códigos de barras
- Ignorar advertencias de duplicados
- Importar todo de una vez sin verificar

---

**¡Con estos controles, tendrás un catálogo limpio y sin duplicados!** 🎯
