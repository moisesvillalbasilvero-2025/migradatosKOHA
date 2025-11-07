# 🚀 IMPORTACIÓN SIMULTÁNEA DE VARIAS BIBLIOTECAS
## Universidad Nacional de Asunción

---

## 🎯 OBJETIVO

Importar **VARIAS bibliotecas al mismo tiempo** para ahorrar tiempo.

---

## ⚡ USO RÁPIDO

```bash
cd /home/mvillalba/migradatos
./importar_multiples.sh
```

Luego sigue las instrucciones en pantalla.

---

## 📋 EJEMPLO COMPLETO

### Escenario:
Tienes 3 bibliotecas para importar:
- FACEN (Ciencias Exactas)
- MED (Medicina)
- DER (Derecho)

### Pasos:

```bash
# 1. Ejecutar el script
./importar_multiples.sh

# 2. El script te pregunta:
#    "Ingresa las bibliotecas a importar:"

# 3. Ingresas (TODO en una línea):
FACEN:/tmp/FACEN.csv,MED:/tmp/MED.csv,DER:/tmp/DER.csv

# 4. El script valida los archivos

# 5. Pregunta si continuar, respondes: SI

# 6. Inicia las 3 importaciones EN PARALELO

# 7. Puedes esperar o dejarlas corriendo en background
```

---

## 📝 FORMATO

**Formato general:**
```
CODIGO1:/ruta/archivo1.csv,CODIGO2:/ruta/archivo2.csv,CODIGO3:/ruta/archivo3.csv
```

**Sin espacios entre comas!**

### Ejemplos válidos:

```bash
# 2 bibliotecas
FACEN:/tmp/FACEN.csv,MED:/tmp/MED.csv

# 3 bibliotecas
ODONT:./ODONT.csv,FARM:./FARM.csv,PSICO:./PSICO.csv

# Con rutas absolutas
FACEN:/home/usuario/datos/FACEN.csv,MED:/tmp/medicina.csv

# Archivos en el directorio actual
FACEN:./FACEN_20251021.csv,MED:./MED_20251021.csv
```

---

## ⚙️ QUÉ HACE EL SCRIPT

1. **Valida** que todos los archivos existan
2. **Inicia** todas las importaciones en paralelo (background)
3. **Genera logs** separados para cada biblioteca
4. Te permite **esperar** o **dejar corriendo**
5. **Muestra resumen** al final (si esperas)

---

## 📊 VENTAJAS DE IMPORTACIÓN SIMULTÁNEA

### ⏱️ Ahorro de tiempo:

**Secuencial (una por una):**
```
FACEN: 30 minutos
  ↓
MED:   40 minutos
  ↓
DER:   25 minutos
  ↓
TOTAL: 95 minutos (1h 35min)
```

**Paralelo (simultáneas):**
```
FACEN: 30 minutos ─┐
MED:   40 minutos ─┼─→ TOTAL: 40 minutos (la más lenta)
DER:   25 minutos ─┘
```

**¡Ahorras 55 minutos!** 🚀

---

## 📁 LOGS INDIVIDUALES

Cada biblioteca genera su propio log:

```
logs/
├── importacion_FACEN_20251021_100530.log
├── importacion_MED_20251021_100532.log
└── importacion_DER_20251021_100534.log
```

Ver progreso en tiempo real:
```bash
tail -f logs/importacion_FACEN_*.log
```

---

## 🔄 MONITOREO

### Ver procesos activos:
```bash
ps aux | grep importar_nueva_biblioteca
```

### Ver logs en tiempo real:
```bash
# Biblioteca específica
tail -f logs/importacion_FACEN_*.log

# Todas a la vez (en terminales separadas)
tail -f logs/importacion_*.log
```

---

## ⚠️ CONSIDERACIONES IMPORTANTES

### 1. **Recursos del servidor**

- Cada importación consume CPU y memoria
- No importar más de **3-4** bibliotecas simultáneas
- Servidor con 8GB RAM: máximo 4 simultáneas
- Servidor con 4GB RAM: máximo 2 simultáneas

### 2. **Requisitos previos**

✅ Todas las bibliotecas deben existir en Koha
✅ Archivos CSV deben estar accesibles
✅ Sin errores en los CSVs

### 3. **Si algo falla**

Una biblioteca puede fallar sin afectar las demás:
- FACEN: ✅ Completada
- MED: ❌ Falló
- DER: ✅ Completada

---

## 🆘 PROBLEMAS COMUNES

### Problema: "archivo no encontrado"

**Causa:** Ruta incorrecta

**Solución:**
```bash
# Verificar ruta
ls -lh /tmp/FACEN.csv

# Usar ruta absoluta completa
./importar_multiples.sh
FACEN:/tmp/FACEN.csv,MED:/home/usuario/MED.csv
```

### Problema: "biblioteca no existe"

**Causa:** No creaste la biblioteca en Koha

**Solución:**
1. Ir a Staff Interface
2. Administración → Bibliotecas
3. Crear cada biblioteca primero
4. Volver a ejecutar

### Problema: Servidor muy lento

**Causa:** Demasiadas importaciones simultáneas

**Solución:**
```bash
# Hacer en grupos más pequeños
# Grupo 1:
FACEN:/tmp/FACEN.csv,MED:/tmp/MED.csv

# Esperar que termine

# Grupo 2:
DER:/tmp/DER.csv,ODONT:/tmp/ODONT.csv
```

---

## 🎓 COMPARACIÓN: INDIVIDUAL vs SIMULTÁNEO

### Importación Individual (secuencial):

```bash
# Una por una
./importar_nueva_biblioteca.sh FACEN /tmp/FACEN.csv
# Esperar...

./importar_nueva_biblioteca.sh MED /tmp/MED.csv
# Esperar...

./importar_nueva_biblioteca.sh DER /tmp/DER.csv
# Esperar...

# Tiempo total: suma de todas
```

### Importación Simultánea (paralelo):

```bash
# Todas a la vez
./importar_multiples.sh
FACEN:/tmp/FACEN.csv,MED:/tmp/MED.csv,DER:/tmp/DER.csv

# Tiempo total: la más lenta
```

---

## 📋 EJEMPLO PASO A PASO

### Preparación:

```bash
# 1. Crear las 3 bibliotecas en Koha (Staff Interface)
#    - FACEN
#    - MED
#    - DER

# 2. Asegurarte que los CSV están disponibles
ls -lh /tmp/FACEN.csv
ls -lh /tmp/MED.csv
ls -lh /tmp/DER.csv

# 3. Conectar al servidor
ssh usuario@servidor
cd /home/mvillalba/migradatos
```

### Ejecución:

```bash
./importar_multiples.sh
```

**Salida:**
```
╔════════════════════════════════════════════════════════════════════╗
║     IMPORTACIÓN SIMULTÁNEA DE MÚLTIPLES BIBLIOTECAS                ║
╚════════════════════════════════════════════════════════════════════╝

BIBLIOTECAS DISPONIBLES:
────────────────────────────────────────────────────────────────
Archivos CSV encontrados:
  • FACEN.csv (5234 registros)
  • MED.csv (8732 registros)
  • DER.csv (4521 registros)

INSTRUCCIONES:
────────────────────────────────────────────────────────────────
Ingresa los códigos de biblioteca y rutas CSV separados por coma

Ingresa las bibliotecas a importar: FACEN:/tmp/FACEN.csv,MED:/tmp/MED.csv,DER:/tmp/DER.csv

BIBLIOTECAS A IMPORTAR:
────────────────────────────────────────────────────────────────
  • FACEN: /tmp/FACEN.csv
    ✓ Archivo encontrado
  • MED: /tmp/MED.csv
    ✓ Archivo encontrado
  • DER: /tmp/DER.csv
    ✓ Archivo encontrado

Total a importar: 3 biblioteca(s)

¿Continuar con la importación? (SI/no): SI

INICIANDO IMPORTACIONES EN PARALELO
════════════════════════════════════════════════════════════════

▶ Iniciando importación de FACEN
  ✓ Proceso iniciado (PID: 12345)
  ℹ Log: logs/importacion_FACEN_20251021_103045.log

▶ Iniciando importación de MED
  ✓ Proceso iniciado (PID: 12348)
  ℹ Log: logs/importacion_MED_20251021_103047.log

▶ Iniciando importación de DER
  ✓ Proceso iniciado (PID: 12351)
  ℹ Log: logs/importacion_DER_20251021_103049.log

MONITOREANDO PROCESOS
════════════════════════════════════════════════════════════════

Importaciones en progreso: 3

Puedes:
  • Dejar corriendo y cerrar terminal (procesos en background)
  • Ver logs en tiempo real: tail -f logs/importacion_CODIGO_*.log
  • Esperar aquí hasta que terminen todas

¿Esperar hasta que terminen? (S/n): S

Esperando a que terminen todas las importaciones...

⏳ Esperando a FACEN (PID: 12345)...
✓ FACEN completado exitosamente

⏳ Esperando a MED (PID: 12348)...
✓ MED completado exitosamente

⏳ Esperando a DER (PID: 12351)...
✓ DER completado exitosamente

RESUMEN FINAL
════════════════════════════════════════════════════════════════

FACEN:
  Registros importados: 5,234

MED:
  Registros importados: 8,732

DER:
  Registros importados: 4,521

✓✓✓ IMPORTACIONES COMPLETADAS ✓✓✓
```

---

## 🎯 RESUMEN

### Para importar VARIAS bibliotecas simultáneamente:

```bash
./importar_multiples.sh
```

### Formato:
```
CODIGO1:/ruta/csv1,CODIGO2:/ruta/csv2,CODIGO3:/ruta/csv3
```

### Ventajas:
- ⚡ Mucho más rápido
- 🔄 Procesos independientes
- 📊 Logs separados
- ✅ Si una falla, otras continúan

### Límites recomendados:
- Servidor 4GB RAM: 2 simultáneas
- Servidor 8GB RAM: 4 simultáneas
- Servidor 16GB+ RAM: 6 simultáneas

---

**Fecha:** 2025-10-21
**Sistema:** UNA → Koha - Importación Paralela
