# 🚀 Sistema Completo de Importación con Prevención de Duplicados

**Versión:** 3.0
**Fecha:** 25 de Octubre de 2025
**Estado:** ✅ Integrado en todos los flujos de importación

---

## 📋 Resumen del Sistema

El sistema de importación ahora incluye **prevención automática de duplicados** en **todas las formas de importación**:

```
┌─────────────────────────────────────────────────────────────┐
│  SISTEMA DE IMPORTACIÓN v3.0                                │
│  ────────────────────────────────────────────────────────   │
│                                                              │
│  ✅ Validación de calidad                                    │
│  ✅ Prevención de duplicados (NUEVO)                         │
│  ✅ Importación inteligente                                  │
│  ✅ Importación por lotes                                    │
│  ✅ Reportes detallados                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔐 Niveles de Protección

### NIVEL 1: Validador (Pre-importación)
**Script:** `validar_antes_importar.sh`

```bash
./validar_antes_importar.sh importar_aqui/ING.csv
```

**Qué hace:**
- ✅ Valida calidad de datos (scoring 0-100)
- ✅ **Detecta duplicados DENTRO del CSV**
- ✅ **Detecta duplicados CSV vs BASE DE DATOS**
- ✅ Muestra recomendaciones antes de importar

**Salida:**
```
════════════════════════════════════════════════════════════════
  7. DUPLICADOS vs BASE DE DATOS
════════════════════════════════════════════════════════════════

[INFO] Verificando duplicados contra base de datos...

[INFO] 7.1 - Duplicados DENTRO del CSV:
✓ No hay duplicados internos en el CSV

[INFO] 7.2 - Duplicados CSV vs BASE DE DATOS:
⚠ POSIBLE DUPLICADO - ISBN: 978-84-376-0455-8
  Título: Don Quijote de la Mancha
  (Puede ser nuevo ejemplar de libro existente)

════════════════════════════════════════════════════════════════
  PUNTUACIÓN DE CALIDAD: 85/100
════════════════════════════════════════════════════════════════

ℹ️ INFO: Hay ISBNs/Títulos existentes, el sistema agregará
         ejemplares automáticamente
```

---

### NIVEL 2: Importador Simple
**Script:** `importar_biblioteca.sh`

```bash
./importar_biblioteca.sh ING
```

**Qué hace:**
- ✅ Verifica requisitos del sistema
- ✅ **Valida duplicados antes de generar XML**
- ✅ Pregunta confirmación si hay ISBNs existentes
- ✅ Importa con modo inteligente (agrega ejemplares, no duplica)

**Flujo de ejecución:**
```
1. Verificar requisitos
2. Analizar CSV
3. ⭐ VERIFICAR DUPLICADOS (NUEVO)
   ├─ Duplicados en CSV → ERROR crítico
   ├─ Duplicados en BD (barcode) → ERROR crítico
   └─ Duplicados en BD (ISBN/título) → Agregar ejemplares
4. Generar MARCXML
5. Importar a Koha
6. Verificar resultado
```

**Ejemplo de salida:**
```
════════════════════════════════════════════════════════════════
  IMPORTACIÓN AUTOMÁTICA DE BIBLIOTECA: ING
════════════════════════════════════════════════════════════════

[INFO] Verificando duplicados antes de importar...
[INFO]   1. Verificando duplicados internos en CSV...
[OK]   No hay duplicados internos

[INFO]   2. Verificando duplicados contra base de datos...
[WARN] Se encontraron ISBNs/Títulos existentes
[INFO]   El sistema agregará ejemplares automáticamente (no creará duplicados)

¿Continuar con importación inteligente? (s/n): s

[INFO] Generando archivos MARCXML...
```

---

### NIVEL 3: Importador por Lotes
**Script:** `importar_por_lotes.sh`

```bash
./importar_por_lotes.sh importar_aqui/ING.csv 500
```

**Qué hace:**
- ✅ Analiza archivo grande
- ✅ **Verifica duplicados ANTES de dividir en lotes**
- ✅ Divide en lotes pequeños
- ✅ Importa cada lote con pausa para indexación
- ✅ Genera reporte HTML completo

**Ventajas:**
- 🚀 Más rápido para archivos grandes
- 💾 Menor uso de memoria
- 🔄 Indexación incremental
- 🛡️ **Protección contra duplicados desde el inicio**

**Flujo:**
```
1. Analizar archivo CSV
2. ⭐ VERIFICAR DUPLICADOS (NUEVO)
   └─ Si hay duplicados críticos → DETENER
3. Dividir en lotes de 500 registros
4. Importar lote 1 → esperar 30s
5. Importar lote 2 → esperar 30s
6. ... continuar
7. Reindexar todo el catálogo
8. Generar reporte HTML
```

---

## 🛡️ Tipos de Duplicados Detectados

### 1. CRÍTICO 🔴 (Sistema DETIENE la importación)

**Código de barras duplicado:**
```
LIBRO001 aparece 2 veces en el CSV
→ ❌ ERROR - No se puede continuar
→ ACCIÓN: Cambiar uno de los códigos
```

**Código de barras ya existe en BD:**
```
LIBRO001 ya está en la base de datos
→ ❌ ERROR - No se puede continuar
→ ACCIÓN: Usar código diferente
```

### 2. ADVERTENCIA 🟡 (Sistema pregunta al usuario)

**ISBN ya existe en BD:**
```
ISBN 978-84-376-0455-8 ya existe
→ ⚠️ ADVERTENCIA
→ OPCIÓN: Agregar nuevo ejemplar al registro existente
→ El usuario decide si continuar
```

**Título + Autor ya existe:**
```
"Don Quijote" / "Cervantes, Miguel de" ya existe
→ ⚠️ ADVERTENCIA
→ OPCIÓN: Agregar nuevo ejemplar al registro existente
```

### 3. PERMITIDO 🟢 (Sistema permite)

**Diferentes ediciones:**
```
Mismo título, ISBNs diferentes
→ ✅ OK - Son ediciones diferentes
→ Se crean registros separados
```

---

## 📖 Guía de Uso Paso a Paso

### Opción 1: Importación Segura (Recomendada)

```bash
cd /home/mvillalba/migradatos

# PASO 1: Validar primero
./validar_antes_importar.sh importar_aqui/ING.csv

# Ver resultados:
# - Score < 50: Corregir errores
# - Score 50-70: Revisar advertencias
# - Score > 70: ✅ Listo para importar

# PASO 2: Si hay duplicados críticos, corregir CSV
# Si hay solo advertencias (ISBNs existentes), continuar

# PASO 3: Importar
./importar_biblioteca.sh ING

# El sistema:
# - Detecta duplicados automáticamente
# - Pregunta confirmación si hay ISBNs existentes
# - Agrega ejemplares en vez de duplicar registros
```

### Opción 2: Importación por Lotes (Archivos grandes)

```bash
cd /home/mvillalba/migradatos

# PASO 1: Validar (opcional pero recomendado)
./validar_antes_importar.sh importar_aqui/ING.csv

# PASO 2: Importar por lotes
./importar_por_lotes.sh importar_aqui/ING.csv 500

# El sistema:
# - Verifica duplicados antes de empezar
# - Divide en lotes de 500 registros
# - Importa con pausas para indexación
# - Genera reporte HTML
```

---

## 🔍 Verificación Manual de Duplicados

### Antes de importar:

```bash
# Verificar solo duplicados en CSV
source prevenir_duplicados.sh
verificar_duplicados_en_csv importar_aqui/ING.csv
```

### Verificar duplicados CSV vs BD:

```bash
source prevenir_duplicados.sh
verificar_duplicados_csv_vs_bd importar_aqui/ING.csv
```

**Códigos de retorno:**
- `0` = Sin duplicados (✅ OK)
- `1` = Barcodes duplicados (❌ ERROR)
- `2` = ISBNs/Títulos duplicados (⚠️ ADVERTENCIA)

---

## 📊 Reportes y Logs

### Logs del Validador:
```
/tmp/validacion_FECHA.txt
```

### Logs de Importación:
```
/home/mvillalba/migradatos/logs/import_ING_FECHA.log
```

### Logs de Lotes:
```
/home/mvillalba/migradatos/logs/batch_import_FECHA.log
```

### Reporte HTML (Lotes):
```
/home/mvillalba/migradatos/reportes/batch_import_FECHA.html
```

---

## ⚙️ Funciones Disponibles

Todas las funciones están en `/home/mvillalba/migradatos/prevenir_duplicados.sh`:

```bash
# 1. Verificar si barcode existe
barcode_existe_en_bd "LIBRO001"

# 2. Verificar si ISBN existe
isbn_existe_en_bd "978-84-376-0455-8"

# 3. Verificar título + autor
titulo_autor_existe_en_bd "Don Quijote" "Cervantes, Miguel de"

# 4. Obtener biblionumber por ISBN
biblionumber=$(obtener_biblionumber_por_isbn "978-84-376-0455-8")

# 5. Obtener biblionumber por título + autor
biblionumber=$(obtener_biblionumber_por_titulo_autor "Don Quijote" "Cervantes")

# 6. Verificar duplicados en CSV
verificar_duplicados_en_csv "archivo.csv"

# 7. Verificar CSV vs BD
verificar_duplicados_csv_vs_bd "archivo.csv"

# 8. Importación inteligente (decide qué hacer)
importar_inteligente "título" "autor" "isbn" "barcode" "homebranch"
```

---

## 🎯 Casos de Uso

### Caso 1: Importar nueva biblioteca (sin duplicados esperados)

```bash
./validar_antes_importar.sh importar_aqui/NUEVA_BIB.csv
# Resultado: Score 85/100, sin duplicados

./importar_biblioteca.sh NUEVA_BIB
# El sistema verifica y confirma: sin duplicados
```

### Caso 2: Agregar ejemplares a libros existentes

```bash
./validar_antes_importar.sh importar_aqui/EJEMPLARES.csv
# Resultado: ⚠️ 50 ISBNs ya existen

./importar_biblioteca.sh EJEMPLARES
# El sistema pregunta: "¿Continuar con importación inteligente?"
# Usuario confirma: s
# Sistema agrega 50 nuevos ejemplares (no crea duplicados)
```

### Caso 3: Archivo grande (10,000 registros)

```bash
./validar_antes_importar.sh importar_aqui/GRANDE.csv
# Resultado: Score 78/100, 3 advertencias de ISBNs existentes

./importar_por_lotes.sh importar_aqui/GRANDE.csv 500
# Sistema verifica duplicados
# Divide en 20 lotes de 500
# Importa con pausas
# Genera reporte HTML
```

---

## 🚨 Solución de Problemas

### Problema: "Códigos de barras duplicados en CSV"

**Causa:** Mismo código de barras aparece 2+ veces en el archivo

**Solución:**
```bash
# 1. Ver duplicados
verificar_duplicados_en_csv importar_aqui/ING.csv

# 2. Encontrar líneas específicas
grep "LIBRO001" importar_aqui/ING.csv

# 3. Editar CSV y cambiar códigos duplicados

# 4. Re-validar
./validar_antes_importar.sh importar_aqui/ING.csv
```

### Problema: "Código de barras ya existe en BD"

**Causa:** Código que intentas importar ya está en la base de datos

**Solución:**
```bash
# 1. Verificar en BD
koha-mysql koha-cnc -e "
SELECT biblionumber, barcode, homebranch
FROM items
WHERE barcode = 'LIBRO001'
"

# 2. Cambiar el código en el CSV a uno nuevo

# 3. Re-validar e importar
```

### Problema: "50 ISBNs ya existen"

**Causa:** Estás importando libros que ya existen (normal si agregas ejemplares)

**Solución:**
```bash
# Esto NO es un error
# El sistema preguntará si deseas agregar ejemplares
# Responde "s" para continuar

# El sistema automáticamente:
# - Encuentra el biblionumber existente
# - Agrega solo el nuevo ejemplar (item)
# - NO crea registro duplicado
```

---

## 📚 Documentación Relacionada

- **Guía de Prevención de Duplicados:** `GUIA_PREVENCION_DUPLICADOS.md`
- **Guía de Importación por Lotes:** `GUIA_IMPORTACION_LOTES.md`
- **Estructura del Catálogo:** `GUIA_ESTRUCTURA_CSV_Y_SQL.md`
- **Mejora Continua:** `MEJORA_CONTINUA_CATALOGO.md`

---

## ✅ Checklist de Importación

### Antes de importar:
- [ ] CSV en `/home/mvillalba/migradatos/importar_aqui/`
- [ ] Ejecutar validador: `./validar_antes_importar.sh`
- [ ] Score > 70 o errores corregidos
- [ ] Backup de BD (si es importación grande)

### Durante importación:
- [ ] Sistema verifica duplicados automáticamente
- [ ] Confirmar si hay advertencias de ISBNs existentes
- [ ] Monitorear progreso (si es por lotes)

### Después de importar:
- [ ] Verificar en OPAC: http://opac.una.edu.py/
- [ ] Revisar log de importación
- [ ] Confirmar total de registros en BD
- [ ] Ver reporte HTML (si es por lotes)

---

## 🎓 Resumen de Mejoras v3.0

| Aspecto | Antes (v2.0) | Ahora (v3.0) |
|---------|-------------|--------------|
| **Duplicados** | No detectaba | ✅ Detecta 3 niveles |
| **Validación** | Solo calidad | ✅ Calidad + Duplicados |
| **Importador Simple** | Sin verificación | ✅ Verifica antes de importar |
| **Importador Lotes** | Sin verificación | ✅ Verifica antes de dividir |
| **Modo Inteligente** | No existía | ✅ Agrega ejemplares vs duplicar |
| **Prevención** | Manual | ✅ Automática en todos los flujos |

---

**¡Sistema completo de importación con CERO duplicados garantizado!** 🎯

Para cualquier duda, revisa:
```bash
less /home/mvillalba/migradatos/docs/GUIA_PREVENCION_DUPLICADOS.md
```
