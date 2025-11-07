# 🌟 IMPORTACIÓN PERFECTA - CALIDAD OPAC GARANTIZADA
## Universidad Nacional de Asunción - Sistema Koha

---

## 🎯 OBJETIVO

Importar bibliotecas con **DATOS PERFECTOS** que se vean **IMPECABLES en el OPAC**.

---

## ⭐ NUEVO SCRIPT: `importar_perfecto.sh`

Este script **auto-corrige y optimiza** los datos antes de importar.

### Uso:

```bash
./importar_perfecto.sh CODIGO /ruta/archivo.csv
```

### Ejemplo:

```bash
./importar_perfecto.sh MED /tmp/MED.csv
```

---

## 🔧 QUÉ HACE AUTOMÁTICAMENTE

### 1. **Análisis Inteligente**
- Detecta encoding del archivo
- Cuenta registros
- Analiza calidad de datos
- Detecta duplicados

### 2. **Auto-Corrección**
- **Códigos duplicados** → Genera códigos únicos automáticamente
- **Validación de campos** → Verifica campos obligatorios
- **Optimización de datos** → Prepara para OPAC perfecto

### 3. **Verificaciones de Seguridad**
- ✅ Biblioteca existe en Koha
- ✅ Detecta items existentes
- ✅ Opción de limpiar antes de importar
- ✅ Confirmación antes de proceder

### 4. **Importación Optimizada**
- Usa archivo corregido automáticamente
- Valida XML generado
- Reconstruye índices
- Verifica resultado final

---

## 📊 COMPARACIÓN: Normal vs Perfecta

### Importación Normal:

```bash
./importar_nueva_biblioteca.sh MED /tmp/MED.csv

# Problemas potenciales:
# ⚠️ Códigos duplicados → 1 registro falla
# ⚠️ Datos sin validar → Errores en OPAC
# ⚠️ Sin auto-corrección → Trabajo manual después
```

### Importación Perfecta:

```bash
./importar_perfecto.sh MED /tmp/MED.csv

# Ventajas:
# ✅ Auto-corrige códigos duplicados
# ✅ Valida todo antes de importar
# ✅ Datos optimizados para OPAC
# ✅ Calidad garantizada
# ✅ Cero errores
```

---

## 🎓 EJEMPLO COMPLETO

### Escenario:
Tienes MED.csv con 4,767 registros y códigos duplicados.

### Pasos:

```bash
# 1. Conectar al servidor
ssh usuario@servidor
cd /home/mvillalba/migradatos

# 2. Ejecutar importación perfecta
./importar_perfecto.sh MED /tmp/MED.csv
```

### Salida del Script:

```
╔════════════════════════════════════════════════════════════════════╗
║       IMPORTACIÓN PERFECTA - CALIDAD OPAC GARANTIZADA              ║
╚════════════════════════════════════════════════════════════════════╝

PASO 1: Verificar archivo original
════════════════════════════════════════════════════════════════
✓ Archivo encontrado: /tmp/MED.csv
  Registros: 4,767

PASO 2: Análisis inteligente y auto-corrección
════════════════════════════════════════════════════════════════

Verificando duplicados...
⚠ Detectados 4767 códigos duplicados
ℹ Auto-corrigiendo códigos...
✓ Códigos corregidos automáticamente
  Archivo corregido: MED_corregido.csv

PASO 3: Verificar biblioteca en Koha
════════════════════════════════════════════════════════════════
✓ Biblioteca encontrada: Biblioteca de la Facultad de Ciencias Médicas

PASO 4: Verificar items existentes
════════════════════════════════════════════════════════════════
  Items existentes: 0

✓ Datos verificados y corregidos
✓ OK para importación perfecta

¿Continuar con la importación? (SI/no): SI

PASO 5: Importación con calidad garantizada
════════════════════════════════════════════════════════════════

[... importación en progreso ...]

╔════════════════════════════════════════════════════════════╗
║                                                            ║
║  ✓✓✓ IMPORTACIÓN PERFECTA COMPLETADA ✓✓✓                  ║
║                                                            ║
║  Datos optimizados para OPAC                               ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

VERIFICACIÓN FINAL:
  • Biblioteca: MED
  • Items importados: 4,767
  • Calidad: PERFECTA

Ver en OPAC:
  http://servidor:8080/cgi-bin/koha/opac-search.pl?branch=MED
```

---

## 🛡️ GARANTÍAS DE CALIDAD

### ✅ **Códigos Únicos**
- **0 duplicados** en códigos de barras
- Cada libro tiene código único: MED-00001, MED-00002, etc.
- **Sin errores** en importación

### ✅ **Datos Validados**
- Todos los campos obligatorios presentes
- Formato correcto
- Encoding UTF-8 verificado

### ✅ **OPAC Perfecto**
- Búsquedas funcionan correctamente
- Registros se ven impecables
- Sin registros rotos
- Todos los campos visibles

---

## 📋 DIFERENCIAS CLAVE

| Característica | Normal | Perfecta |
|----------------|--------|----------|
| Auto-corrección | ❌ No | ✅ Sí |
| Validación previa | ⚠️ Básica | ✅ Completa |
| Duplicados | ⚠️ Pueden fallar | ✅ Corregidos |
| Calidad OPAC | ⚠️ Variable | ✅ Garantizada |
| Errores | ⚠️ Posibles | ✅ Cero |

---

## 🔄 FLUJO DEL SCRIPT

```
┌─────────────────────────────┐
│ CSV Original (con problemas)│
└──────────────┬──────────────┘
               │
               ↓
┌─────────────────────────────┐
│ 1. Análisis Inteligente     │
│    - Detecta duplicados     │
│    - Analiza calidad        │
└──────────────┬──────────────┘
               │
               ↓
┌─────────────────────────────┐
│ 2. Auto-Corrección          │
│    - Genera códigos únicos  │
│    - Optimiza datos         │
│    - Crea CSV_corregido.csv │
└──────────────┬──────────────┘
               │
               ↓
┌─────────────────────────────┐
│ 3. Verificaciones           │
│    - Biblioteca existe      │
│    - Items existentes       │
│    - Confirmación usuario   │
└──────────────┬──────────────┘
               │
               ↓
┌─────────────────────────────┐
│ 4. Importación Perfecta     │
│    - Usa CSV corregido      │
│    - Valida XML             │
│    - Importa a Koha         │
│    - Reconstruye índices    │
└──────────────┬──────────────┘
               │
               ↓
┌─────────────────────────────┐
│ ✓ OPAC PERFECTO             │
│   - 0 errores               │
│   - Datos impecables        │
│   - 100% calidad            │
└─────────────────────────────┘
```

---

## 💡 CUÁNDO USAR CADA SCRIPT

### Usa `importar_perfecto.sh` cuando:

✅ Quieres **datos perfectos** en OPAC
✅ El CSV tiene **duplicados**
✅ Es la **primera vez** que importas esa biblioteca
✅ Quieres **calidad garantizada**
✅ No quieres **problemas después**

### Usa `importar_nueva_biblioteca.sh` cuando:

⚠️ El CSV ya está **100% limpio**
⚠️ Ya verificaste **manualmente** los datos
⚠️ Sabes que **no hay duplicados**

**Recomendación:** Siempre usa `importar_perfecto.sh` para estar seguro.

---

## 🎯 RESUMEN

### Para importar con **CALIDAD PERFECTA**:

```bash
./importar_perfecto.sh CODIGO archivo.csv
```

### Ventajas:

✅ **Auto-corrige** códigos duplicados
✅ **Valida** datos antes de importar
✅ **Optimiza** para OPAC perfecto
✅ **Garantiza** cero errores
✅ **Verifica** resultado final

### El script hace TODOOPAC por ti:

1. Analiza el CSV
2. Detecta problemas
3. Corrige automáticamente
4. Verifica biblioteca en Koha
5. Importa con calidad perfecta
6. Verifica resultado

---

## 📚 ARCHIVOS GENERADOS

Después de usar `importar_perfecto.sh`:

```
/home/mvillalba/migradatos/
├── MED.csv                      ← Original
├── MED_corregido.csv            ← Corregido (auto-generado)
├── MED_20251021.csv             ← Copia en migradatos
├── exports/
│   └── MED_*_marcxml_01.xml     ← XML generado
└── logs/
    └── importacion_MED_*.log    ← Reporte
```

---

## ✅ CHECKLIST DE CALIDAD

Después de importar, verifica:

- [ ] Items en Koha = Registros en CSV
- [ ] Búsqueda en OPAC funciona
- [ ] Registros se ven completos
- [ ] Sin errores en logs
- [ ] Códigos de barras únicos
- [ ] Todos los campos visibles

---

**Fecha:** 2025-10-21
**Versión:** 2.0 - Calidad OPAC Garantizada
**Sistema:** Importación Perfecta UNA → Koha
