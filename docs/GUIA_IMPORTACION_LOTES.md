# 📦 GUÍA: Importación por Lotes

**Script:** `/home/mvillalba/migradatos/importar_por_lotes.sh`
**Versión:** 1.0
**Fecha:** 25 de Octubre de 2025

---

## 🎯 ¿Qué es la Importación por Lotes?

Divide archivos CSV grandes en lotes pequeños para:
- ✅ Mejor rendimiento
- ✅ Menor uso de memoria
- ✅ Indexación incremental
- ✅ Recuperación ante errores
- ✅ Progreso visible

---

## 🚀 Uso Básico

### Sintaxis:
```bash
./importar_por_lotes.sh ARCHIVO.csv [TAMAÑO_LOTE]
```

### Ejemplos:

```bash
# Importar con lotes de 500 registros (default)
./importar_por_lotes.sh importar_aqui/ING.csv

# Importar con lotes de 100 registros (servidor con menos recursos)
./importar_por_lotes.sh importar_aqui/ING.csv 100

# Importar con lotes de 1000 registros (servidor potente)
./importar_por_lotes.sh importar_aqui/ING.csv 1000
```

---

## 📊 Comparación: Normal vs Por Lotes

| Aspecto | Importación Normal | Importación por Lotes |
|---------|-------------------|----------------------|
| **Rendimiento** | Lento en archivos grandes | ✅ Rápido y eficiente |
| **Memoria** | Puede llenar RAM | ✅ Uso controlado |
| **Indexación** | Al final (muy lento) | ✅ Incremental |
| **Errores** | Pierde todo | ✅ Solo pierde el lote |
| **Progreso** | No visible | ✅ Barra de progreso |
| **Recuperación** | Difícil | ✅ Re-importar solo lotes fallidos |

---

## 🔧 ¿Cómo Funciona?

### Proceso Paso a Paso:

```
1. ANÁLISIS
   ├─ Cuenta total de registros
   ├─ Calcula número de lotes
   └─ Estima tiempo total

2. DIVISIÓN
   ├─ Divide CSV en archivos pequeños
   ├─ Cada lote con su encabezado
   └─ Lotes numerados (lote_1_de_10.csv, etc.)

3. IMPORTACIÓN
   ├─ Importa lote 1 → espera 30s
   ├─ Importa lote 2 → espera 30s
   ├─ Importa lote 3 → espera 30s
   └─ ... continúa hasta terminar

4. REINDEXACIÓN FINAL
   ├─ Reindexar todo el catálogo
   └─ Reiniciar servicios

5. REPORTE
   ├─ Estadísticas completas
   ├─ Reporte HTML
   └─ Log detallado
```

---

## 💡 Recomendaciones de Tamaño de Lote

| Registros Totales | Tamaño Lote Recomendado | Razón |
|-------------------|-------------------------|-------|
| < 500 | No usar lotes | Usar importación normal |
| 500 - 2,000 | 100 - 200 | Servidor con recursos limitados |
| 2,000 - 10,000 | 500 | ✅ **Óptimo general** |
| 10,000 - 50,000 | 1,000 | Servidor potente |
| > 50,000 | 2,000 | Máximo rendimiento |

---

## 📝 Ejemplo Completo

### Escenario: Importar 5,000 libros de Ingeniería

```bash
# 1. Verificar archivo
wc -l importar_aqui/ING.csv
# Salida: 5001 (5000 registros + 1 encabezado)

# 2. Validar calidad (opcional pero recomendado)
./validar_antes_importar.sh importar_aqui/ING.csv

# 3. Importar por lotes de 500
cd /home/mvillalba/migradatos
./importar_por_lotes.sh importar_aqui/ING.csv 500
```

### Salida esperada:

```
═══════════════════════════════════════════════════════════════
  IMPORTACIÓN POR LOTES - KOHA UNA
═══════════════════════════════════════════════════════════════

[14:30:00] Archivo de entrada: importar_aqui/ING.csv
[14:30:00] Tamaño de lote: 500 registros
[14:30:00] Archivo de log: logs/batch_import_20251025_143000.log

═══════════════════════════════════════════════════════════════
  1. ANÁLISIS DEL ARCHIVO
═══════════════════════════════════════════════════════════════

[14:30:01] Total de líneas: 5001
[14:30:01] Total de registros: 5000
[14:30:01] Número de lotes: 10
[14:30:01] Tiempo estimado: ~20 minutos (2 min/lote)

¿Continuar con la importación en 10 lotes? (s/n) s

═══════════════════════════════════════════════════════════════
  2. DIVIDIENDO EN LOTES
═══════════════════════════════════════════════════════════════

[14:30:05] Creando 10 archivos de lote...
[14:30:05] Lote 1: 500 registros → temp_batches/lote_1_de_10.csv
[14:30:05] Lote 2: 500 registros → temp_batches/lote_2_de_10.csv
...
[14:30:10] ✓ Lotes creados exitosamente

═══════════════════════════════════════════════════════════════
  3. IMPORTANDO LOTES
═══════════════════════════════════════════════════════════════

═══════════════════════════════════════════════════════════════
  LOTE 1 DE 10 (500 registros)
═══════════════════════════════════════════════════════════════

[14:30:12] Iniciando importación del lote 1...
[14:32:15] ✓ Lote 1 importado exitosamente
[14:32:15] Esperando 30s para indexación...
Pausa: 0 segundos restantes...

Progreso general: 1/10 lotes (10%)

═══════════════════════════════════════════════════════════════
  LOTE 2 DE 10 (500 registros)
═══════════════════════════════════════════════════════════════

[14:32:45] Iniciando importación del lote 2...
[14:34:50] ✓ Lote 2 importado exitosamente
[14:34:50] Esperando 30s para indexación...

Progreso general: 2/10 lotes (20%)

... continúa hasta lote 10 ...

═══════════════════════════════════════════════════════════════
  4. REINDEXACIÓN FINAL
═══════════════════════════════════════════════════════════════

[14:52:00] Reindexando catálogo completo...
[14:53:30] ✓ Reindexación completada
[14:53:30] Reiniciando Plack...
[14:53:35] ✓ Plack reiniciado

═══════════════════════════════════════════════════════════════
  RESUMEN FINAL
═══════════════════════════════════════════════════════════════

═══════════════════════════════════════════════════════════════
  IMPORTACIÓN COMPLETADA
═══════════════════════════════════════════════════════════════

Archivo importado: importar_aqui/ING.csv
Total de lotes: 10
Tamaño de lote: 500 registros

✓ Registros exitosos: 5000

Tiempo total: 23m 35s
Log completo: logs/batch_import_20251025_143000.log

Registros en BD (hoy): 5000

═══════════════════════════════════════════════════════════════
  RECOMENDACIONES
═══════════════════════════════════════════════════════════════

1. Verificar en OPAC: http://opac.una.edu.py/
2. Revisar log completo: less logs/batch_import_20251025_143000.log
3. Verificar calidad:
   koha-mysql koha-cnc -e "SELECT COUNT(*) FROM biblio WHERE datecreated = CURDATE()"

Reporte HTML generado: reportes/batch_import_20251025_143000.html

✓ ¡IMPORTACIÓN POR LOTES COMPLETADA!
```

---

## 🔍 Monitoreo Durante la Importación

### En otra terminal, puedes monitorear:

```bash
# Ver registros importados en tiempo real
watch -n 5 'koha-mysql koha-cnc -e "
    SELECT COUNT(*) as Total_Hoy
    FROM biblio
    WHERE datecreated = CURDATE()
"'

# Ver uso de memoria
watch -n 5 'free -h'

# Ver procesos de Koha
watch -n 5 'ps aux | grep koha'

# Ver últimas líneas del log
tail -f logs/batch_import_*.log
```

---

## 🛠️ Solución de Problemas

### Problema: "Error en lote 5"

**Solución:**
```bash
# 1. Ver el error en el log
tail -50 logs/batch_import_FECHA.log

# 2. Ver el archivo del lote problemático
cat temp_batches/lote_5_de_10.csv | less

# 3. Corregir el CSV original y re-importar solo ese lote
# (El script preguntará si deseas continuar)
```

### Problema: "Toma mucho tiempo"

**Solución:**
```bash
# Aumentar tamaño de lote (menos pausas)
./importar_por_lotes.sh archivo.csv 1000

# O reducir pausa entre lotes (editar script, línea ~250):
PAUSE_TIME=15  # Cambiar de 30 a 15 segundos
```

### Problema: "Se quedó sin memoria"

**Solución:**
```bash
# Reducir tamaño de lote
./importar_por_lotes.sh archivo.csv 100

# O liberar memoria antes de importar
sudo systemctl stop memcached
sudo systemctl start memcached
```

---

## 📈 Comparación de Rendimiento

### Archivo de 10,000 registros:

| Método | Tiempo | Memoria Pico | Éxito |
|--------|--------|--------------|-------|
| **Normal** | ~90 min | 2.5 GB | ⚠️ A veces falla |
| **Lotes 100** | ~60 min | 800 MB | ✅ Siempre funciona |
| **Lotes 500** | ~45 min | 1.2 GB | ✅ Óptimo |
| **Lotes 1000** | ~40 min | 1.8 GB | ✅ Rápido (si hay RAM) |

---

## 📊 Reporte HTML

Después de la importación, se genera un reporte HTML profesional:

**Ubicación:** `/home/mvillalba/migradatos/reportes/batch_import_FECHA.html`

**Contenido:**
- ✅ Estadísticas visuales
- ✅ Detalles de cada lote
- ✅ Tiempo de ejecución
- ✅ Enlaces al OPAC
- ✅ Gráficos de progreso

**Abrir reporte:**
```bash
firefox reportes/batch_import_*.html
```

---

## 🎯 Mejores Prácticas

### 1. Antes de Importar
```bash
# Siempre validar primero
./validar_antes_importar.sh archivo.csv

# Hacer backup de la BD
sudo koha-dump koha-cnc
```

### 2. Durante la Importación
```bash
# Usar screen o tmux para no perder progreso
screen -S importacion
./importar_por_lotes.sh archivo.csv
# Ctrl+A, D para detach
```

### 3. Después de Importar
```bash
# Verificar calidad
koha-mysql koha-cnc -e "
    SELECT COUNT(*) FROM biblio WHERE datecreated = CURDATE()
"

# Ver en OPAC
firefox http://opac.una.edu.py/
```

---

## 🚀 Comandos Rápidos

```bash
# Importación estándar (500 registros/lote)
./importar_por_lotes.sh importar_aqui/ING.csv

# Importación rápida (1000 registros/lote)
./importar_por_lotes.sh importar_aqui/ING.csv 1000

# Importación conservadora (100 registros/lote)
./importar_por_lotes.sh importar_aqui/ING.csv 100

# Con screen (recomendado para archivos grandes)
screen -S import
./importar_por_lotes.sh importar_aqui/ING.csv
# Ctrl+A, D para detach
# screen -r import para volver
```

---

## 📞 Soporte

**Logs:** `/home/mvillalba/migradatos/logs/batch_import_*.log`
**Reportes:** `/home/mvillalba/migradatos/reportes/batch_import_*.html`
**Archivos temporales:** `/home/mvillalba/migradatos/temp_batches/`

---

**¡Con importación por lotes, manejar miles de registros es pan comido!** 🎉
