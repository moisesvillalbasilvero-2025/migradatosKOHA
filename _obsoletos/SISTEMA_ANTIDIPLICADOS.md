# 🛡️ SISTEMA ANTI-DUPLICADOS
## Control Unívoco de Importaciones

Universidad Nacional de Asunción - Sistema Koha

---

## 🎯 OBJETIVO

**Garantizar que una biblioteca NO se importe dos veces** usando múltiples métodos de verificación.

---

## 🔒 3 MÉTODOS DE PROTECCIÓN

El sistema usa **3 capas** de verificación para prevenir duplicados:

### 1️⃣ **Verificación en Base de Datos Koha**

Busca si ya existen items de esa biblioteca:

```sql
SELECT COUNT(*) FROM items WHERE homebranch = 'CODIGO'
```

- **Items = 0** → ✅ OK para importar
- **Items > 0** → ⚠️ Ya existe, preguntar al usuario

---

### 2️⃣ **Registro de Importaciones (Log Histórico)**

Mantiene un archivo `.importaciones_registradas.db` con:

```
CODIGO|FECHA|ITEMS|HASH_CSV
VET|2025-10-21|9086|a3f5b2c8d...
ING|2025-10-20|15086|c7d9e1f2a...
POL|2025-10-15|12467|e4a6b8c2d...
```

Esto permite saber:
- ✅ Qué bibliotecas fueron importadas
- ✅ Cuándo se importaron
- ✅ Cuántos items tenían
- ✅ Huella digital del CSV usado

---

### 3️⃣ **Hash del Archivo CSV (Huella Digital)**

Calcula un hash MD5 del CSV:

```bash
md5sum VET.csv
# a3f5b2c8d1e4f6g7h8i9j0k1l2m3n4o5
```

- Si el hash **coincide** → ❌ Mismo archivo, ya importado
- Si el hash **difiere** → ✅ Archivo diferente, OK importar

Esto previene importar **el mismo CSV dos veces**.

---

## 🚀 USO DEL VERIFICADOR

### Uso Manual

```bash
# Verificar antes de importar
./verificar_duplicados.sh VET

# Con archivo CSV (verifica hash también)
./verificar_duplicados.sh VET /tmp/VET.csv
```

### Integrado en Importación

El script `importar_nueva_biblioteca.sh` **YA incluye** esta verificación automáticamente.

---

## 📋 FLUJO DE VERIFICACIÓN

```
┌─────────────────────────────────────┐
│ Usuario intenta importar VET       │
└──────────────┬──────────────────────┘
               │
               ↓
┌─────────────────────────────────────┐
│ 1. Verificar en Koha DB             │
│    SELECT COUNT(*) WHERE...         │
└──────────────┬──────────────────────┘
               │
               ├─→ Items = 0 ──────────┐
               │                       │
               └─→ Items > 0           │
                       │               │
                       ↓               │
               ┌──────────────┐        │
               │ ADVERTENCIA  │        │
               │ Ya existe    │        │
               └──────┬───────┘        │
                      │                │
         ┌────────────┴────────┐       │
         │                     │       │
         ↓                     ↓       │
    Eliminar              Cancelar    │
    y continuar                       │
         │                             │
         └─────────────┬───────────────┘
                       │
                       ↓
         ┌─────────────────────────┐
         │ 2. Verificar Registro   │
         │    Histórico            │
         └─────────┬───────────────┘
                   │
                   ├─→ No registrado ──┐
                   │                   │
                   └─→ Ya registrado   │
                           │           │
                           ↓           │
                   ┌──────────┐        │
                   │ADVERTENCIA│       │
                   └──────────┘        │
                           │           │
                           └───────────┤
                                       │
                                       ↓
                       ┌───────────────────────┐
                       │ 3. Verificar Hash CSV │
                       │    (si se proporciona)│
                       └───────┬───────────────┘
                               │
                               ├─→ Hash diferente ─→ ✅ OK
                               │
                               └─→ Hash igual ──────→ ❌ DUPLICADO
```

---

## ⚙️ OPCIONES CUANDO SE DETECTA DUPLICADO

Si el verificador detecta que la biblioteca ya existe, presenta opciones:

```
OPCIONES:
  A) Eliminar items existentes y reimportar
  B) Cancelar importación
  C) Importar de todas formas (duplicará registros)

¿Qué deseas hacer? (A/B/C):
```

### Opción A: Eliminar y Reimportar

```bash
# Seleccionar A
# Confirmar escribiendo: ELIMINAR

# El script:
# 1. Elimina todos los items de esa biblioteca
# 2. Verifica que se eliminaron
# 3. Permite continuar con la importación
```

**Uso:** Cuando quieres **reemplazar** datos antiguos con nuevos.

### Opción B: Cancelar

```bash
# Seleccionar B

# El script se detiene
# No se importa nada
```

**Uso:** Cuando te das cuenta que es un error.

### Opción C: Continuar de Todas Formas

```bash
# Seleccionar C

# El script continúa
# DUPLICARÁ los registros
```

**Uso:** Solo si realmente quieres tener duplicados (raro).

---

## 📊 REGISTRO DE IMPORTACIONES

### Ubicación del archivo

```bash
/home/mvillalba/migradatos/.importaciones_registradas.db
```

### Formato

```
CODIGO|FECHA|ITEMS|HASH_CSV
VET|2025-10-21 10:40:00|9086|a3f5b2c8d1e4f6g7h8i9j0
ING|2025-10-20 23:05:00|15086|c7d9e1f2a3b4c5d6e7f8
POL|2025-10-15 18:30:00|12467|e4a6b8c2d1f3g5h7i9j1
```

### Ver historial

```bash
cat /home/mvillalba/migradatos/.importaciones_registradas.db
```

### Borrar registro (para permitir reimportación)

```bash
# Editar archivo y eliminar línea
nano /home/mvillalba/migradatos/.importaciones_registradas.db

# O eliminar específica
sed -i '/^VET|/d' /home/mvillalba/migradatos/.importaciones_registradas.db
```

---

## 🔐 HASH DEL CSV - HUELLA DIGITAL

### ¿Qué es un Hash?

Un **hash** es una huella digital única de un archivo. Si cambias **1 solo caracter**, el hash cambia completamente.

### Ejemplo:

```bash
# CSV original
md5sum VET.csv
# a3f5b2c8d1e4f6g7h8i9j0k1l2m3n4o5

# Mismo CSV (sin cambios)
md5sum VET.csv
# a3f5b2c8d1e4f6g7h8i9j0k1l2m3n4o5  ← IGUAL

# CSV con 1 cambio (agregaste 1 registro)
md5sum VET_nuevo.csv
# z9y8x7w6v5u4t3s2r1q0p9o8n7m6l5k4  ← DIFERENTE
```

### Ventajas:

✅ Detecta si es **exactamente** el mismo archivo
✅ Previene importar el mismo CSV dos veces
✅ Permite re-importar si el CSV fue actualizado

---

## 🎓 EJEMPLOS DE USO

### Ejemplo 1: Primera importación

```bash
./importar_nueva_biblioteca.sh VET /tmp/VET.csv

# Verificación:
#   ✓ No hay items en Koha
#   ✓ Sin registro previo
#   ✓ Sin hash previo
# → Importa sin problemas
```

### Ejemplo 2: Intento de re-importar mismo archivo

```bash
./importar_nueva_biblioteca.sh VET /tmp/VET.csv

# Verificación:
#   ✗ Hay 9,086 items en Koha
#   ✗ Registro previo encontrado
#   ✗ Hash coincide (mismo archivo)
#
# OPCIONES:
#   A) Eliminar y reimportar
#   B) Cancelar ← Seleccionar esta
#   C) Duplicar
```

### Ejemplo 3: Importar archivo actualizado

```bash
# CSV fue modificado (agregaron 500 libros nuevos)

./importar_nueva_biblioteca.sh VET /tmp/VET_actualizado.csv

# Verificación:
#   ✗ Hay 9,086 items en Koha
#   ✗ Registro previo encontrado
#   ✓ Hash DIFERENTE (archivo actualizado)
#
# OPCIONES:
#   A) Eliminar y reimportar ← Seleccionar esta
#   B) Cancelar
#   C) Duplicar
```

---

## 🛠️ COMANDOS ÚTILES

### Ver items de una biblioteca

```bash
sudo koha-mysql koha-cnc -e "
SELECT COUNT(*) FROM items WHERE homebranch = 'VET'"
```

### Ver historial de importaciones

```bash
cat .importaciones_registradas.db
```

### Calcular hash de un CSV

```bash
md5sum archivo.csv
```

### Comparar hashes de 2 archivos

```bash
md5sum archivo1.csv
md5sum archivo2.csv

# Si son iguales → archivos idénticos
# Si difieren → archivos diferentes
```

### Limpiar items de una biblioteca

```bash
sudo koha-mysql koha-cnc -e "
DELETE FROM items WHERE homebranch = 'VET'"
```

---

## ⚠️ CASOS ESPECIALES

### Caso 1: Quiero re-importar con datos actualizados

```bash
# Opción A: Eliminar registro del log
sed -i '/^VET|/d' .importaciones_registradas.db

# Opción B: Usar opción "A" cuando el script pregunte
./importar_nueva_biblioteca.sh VET nuevo.csv
# Seleccionar: A
# Confirmar: ELIMINAR
```

### Caso 2: Importé por error

```bash
# Eliminar items
sudo koha-mysql koha-cnc -e "DELETE FROM items WHERE homebranch = 'CODIGO'"

# Eliminar del registro
sed -i '/^CODIGO|/d' .importaciones_registradas.db

# Reindexar
sudo koha-rebuild-zebra -f -v koha-cnc
```

### Caso 3: ¿Cuándo fue la última importación?

```bash
grep "^VET|" .importaciones_registradas.db

# Resultado:
# VET|2025-10-21 10:40:00|9086|a3f5b2c8d...
#     └─────┬──────┘
#       Fecha y hora
```

---

## 📊 ESTADÍSTICAS

Ver todas las bibliotecas importadas:

```bash
sudo koha-mysql koha-cnc -e "
SELECT
    homebranch,
    COUNT(*) as items,
    MIN(dateaccessioned) as primera_fecha,
    MAX(dateaccessioned) as ultima_fecha
FROM items
GROUP BY homebranch
ORDER BY items DESC"
```

---

## 🎯 RESUMEN

### El sistema previene duplicados mediante:

1. ✅ **Verificación en Koha DB** - ¿Ya hay items?
2. ✅ **Registro histórico** - ¿Ya fue importado antes?
3. ✅ **Hash del CSV** - ¿Es el mismo archivo?

### Ubicación de archivos:

```
/home/mvillalba/migradatos/
├── verificar_duplicados.sh           ← Script verificador
└── .importaciones_registradas.db     ← Base de datos histórico
```

### Uso:

```bash
# Verificación manual
./verificar_duplicados.sh CODIGO [archivo.csv]

# Automático (integrado)
./importar_nueva_biblioteca.sh CODIGO archivo.csv
```

---

## ✅ GARANTÍAS

Con este sistema tienes **garantía** de que:

✅ NO se importará la misma biblioteca dos veces por accidente
✅ Sabrás si ya existe antes de importar
✅ Tendrás historial de todas las importaciones
✅ Podrás re-importar si actualizas los datos

---

**Fecha:** 2025-10-21
**Versión:** 1.0
**Sistema:** Control Anti-Duplicados UNA → Koha
