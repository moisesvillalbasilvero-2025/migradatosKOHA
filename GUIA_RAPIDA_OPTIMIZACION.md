# GUÍA RÁPIDA: SISTEMA OPTIMIZADO DE IMPORTACIÓN

**Universidad Nacional de Asunción**
**Sistema Koha OPAC - Importación CSV**
**Fecha:** 2025-10-24

---

## 🚀 INICIO RÁPIDO

### ¿Cómo importar ahora con persistencia SSH?

```bash
# 1. Subir tu archivo CSV
./subir_csv.sh MED.csv MED

# 2. EJECUTAR CON PERSISTENCIA (RECOMENDADO)
./importar_con_tmux.sh

# 3. O en modo vigilancia continua
./importar_con_tmux.sh --watch
```

**¡LISTO!** La importación continuará aunque te desconectes de SSH.

---

## 📋 NUEVAS HERRAMIENTAS DISPONIBLES

### 1. IMPORTACIÓN CON PERSISTENCIA
```bash
./importar_con_tmux.sh              # Modo normal en tmux
./importar_con_tmux.sh --watch      # Modo vigilancia continua
./importar_con_tmux.sh --attach     # Reconectar a sesión activa
./importar_con_tmux.sh --status     # Ver estado de sesiones
./importar_con_tmux.sh --kill       # Detener todas las importaciones
```

**¿Por qué usar tmux?**
- ✅ Las importaciones NO se interrumpen si cierras SSH
- ✅ Puedes reconectar desde cualquier terminal
- ✅ Perfectas para importaciones largas (20k+ registros)
- ✅ Logs permanentes

### 2. MONITOR EN TIEMPO REAL
```bash
./monitor_importacion.sh              # Vista única
./monitor_importacion.sh --watch      # Actualización continua cada 5s
./monitor_importacion.sh --compact    # Vista compacta
```

**Información mostrada:**
- Estado de sesiones tmux activas
- Procesos de importación en curso
- Estadísticas por biblioteca en Koha
- Uso de recursos (disco, memoria)
- Archivos pendientes
- Últimos logs

### 3. VALIDADOR PREVENTIVO DE CSV
```bash
./validador_csv.py archivo.csv                # Validar un archivo
./validador_csv.py --strict archivo.csv       # Modo estricto
./validador_csv.py --dir importar_aqui/       # Validar directorio completo
```

**Validaciones realizadas:**
- ✅ Formato CSV correcto
- ✅ Columnas obligatorias (titulo, nroacceso)
- ✅ Detección de duplicados
- ✅ Encoding válido
- ✅ Delimitadores consistentes
- ✅ Líneas malformadas

---

## 🔄 FLUJO DE TRABAJO RECOMENDADO

### Opción A: Importación Manual Segura
```bash
# Paso 1: Validar el CSV primero
./validador_csv.py datos.csv

# Paso 2: Si es válido, subir
./subir_csv.sh datos.csv MED

# Paso 3: Importar CON PERSISTENCIA
./importar_con_tmux.sh

# Paso 4: Puedes desconectarte de SSH
# La importación continúa en segundo plano

# Paso 5: Reconectar cuando quieras ver progreso
./importar_con_tmux.sh --attach

# Paso 6: Desconectar de tmux (sin detener)
# Presiona: Ctrl+b luego d

# Paso 7: Monitorear desde otra terminal
./monitor_importacion.sh --watch
```

### Opción B: Modo Vigilancia Automática
```bash
# Inicia vigilancia en tmux
./importar_con_tmux.sh --watch

# Desconéctate de SSH (sigue vigilando)

# Coloca archivos CSV en importar_aqui/
# Se procesarán automáticamente

# Reconéctate para ver progreso
./importar_con_tmux.sh --attach
```

### Opción C: Validación de Lote
```bash
# Validar todos los CSVs antes de importar
./validador_csv.py --dir importar_aqui/

# Si todos son válidos, ejecutar modo automático
./importar_automatico.sh
```

---

## 🎯 COMANDOS ESENCIALES

### Comandos tmux (Control de Sesiones)
```bash
# DENTRO de una sesión tmux:
Ctrl+b d              # Desconectar (sigue corriendo)
Ctrl+b [              # Modo scroll/búsqueda
q                     # Salir del modo scroll

# FUERA de sesión tmux:
tmux ls               # Listar sesiones activas
tmux attach           # Conectar a última sesión
tmux attach -t NOMBRE # Conectar a sesión específica
tmux kill-session     # Matar sesión
```

### Monitoreo de Procesos
```bash
# Ver procesos activos de importación
ps aux | grep -E 'importa|bulkmarcimport|opac_exportar'

# Ver uso de disco
df -h /home/mvillalba/migradatos
du -sh exports/

# Ver logs en tiempo real
tail -f logs/importacion_*.log

# Ver últimos logs
ls -lht logs/ | head -10
```

### Consultas a Koha
```bash
# Items por biblioteca
sudo koha-mysql koha-cnc -e "
  SELECT homebranch, COUNT(*) as items
  FROM items
  GROUP BY homebranch
  ORDER BY items DESC"

# Última importación por biblioteca
sudo koha-mysql koha-cnc -e "
  SELECT homebranch, DATE(MAX(dateaccessioned)) as ultima
  FROM items
  GROUP BY homebranch"

# Total de registros
sudo koha-mysql koha-cnc -e "
  SELECT
    (SELECT COUNT(*) FROM biblio) as biblios,
    (SELECT COUNT(*) FROM items) as items"
```

---

## ⚠️ SOLUCIÓN DE PROBLEMAS

### Problema: "No hay sesiones tmux activas"
```bash
# Solución: Iniciar nueva sesión
./importar_con_tmux.sh
```

### Problema: "La importación parece congelada"
```bash
# 1. Verificar que sigue corriendo
ps aux | grep bulkmarcimport

# 2. Ver progreso en Koha
./monitor_importacion.sh

# 3. Verificar log actualizado
tail -f logs/importacion_*.log
```

### Problema: "Error en archivo CSV"
```bash
# 1. Validar primero
./validador_csv.py archivo.csv

# 2. Ver detalles del error
cat logs/importacion_*.log | grep ERROR

# 3. Revisar archivo en carpeta errores/
ls -lht errores/
```

### Problema: "Quiero detener importación"
```bash
# 1. Ver sesiones activas
./importar_con_tmux.sh --status

# 2. Detener sesión
./importar_con_tmux.sh --kill

# O conectar y cancelar manualmente
./importar_con_tmux.sh --attach
# Luego: Ctrl+C dentro de la sesión
```

### Problema: "Me desconecté y perdí la sesión"
```bash
# ¡NO hay problema con tmux!

# Reconectar a la sesión
./importar_con_tmux.sh --attach

# O directamente
tmux attach -t importacion-koha
```

---

## 📊 COMPARACIÓN: ANTES vs AHORA

| Aspecto | ANTES | AHORA CON MEJORAS |
|---------|-------|-------------------|
| **Desconexión SSH** | ❌ Pierde todo | ✅ Continúa en tmux |
| **Validación previa** | ⚠️  Manual | ✅ Script automático |
| **Monitoreo** | ⚠️  Logs estáticos | ✅ Monitor en tiempo real |
| **Persistencia** | ❌ Ninguna | ✅ Total con tmux |
| **Recuperación** | ❌ Re-iniciar | ✅ Reconexión instantánea |
| **Visibilidad** | ⚠️  Limitada | ✅ Dashboard completo |

---

## 🎓 MEJORES PRÁCTICAS

### ✅ HACER
1. **SIEMPRE usar tmux** para importaciones grandes (>1000 registros)
2. **Validar CSV** antes de importar (`./validador_csv.py`)
3. **Monitorear progreso** con `./monitor_importacion.sh --watch`
4. **Guardar logs** para referencia futura
5. **Desconectar con Ctrl+b d** (no cerrar terminal)
6. **Verificar espacio en disco** antes de importaciones grandes

### ❌ NO HACER
1. ❌ Importar archivos sin validar
2. ❌ Cerrar terminal sin tmux en importaciones largas
3. ❌ Ignorar warnings del validador
4. ❌ Ejecutar múltiples importaciones grandes simultáneas
5. ❌ Olvidar limpiar archivos XML antiguos

---

## 📈 MÉTRICAS Y RENDIMIENTO

### Tiempos Observados (BCT - 19,298 registros)
```
Conversión CSV→XML:      17 segundos
Importación a Koha:      27 minutos
Reindexación:            9 segundos
─────────────────────────────────────
TOTAL:                   ~27 minutos

Velocidad promedio:      ~700 registros/minuto
```

### Uso de Recursos Típico
```
Memoria:          200-400 MB (modo streaming)
Disco (exports):  ~50 MB por 5,000 registros
CPU:              20-40% durante importación
```

---

## 📚 DOCUMENTACIÓN ADICIONAL

### Archivos de Referencia
```
docs/
├── ANALISIS_OPTIMIZACION_IMPORTACION.md    # Análisis técnico completo
├── GUIA_RAPIDA_OPTIMIZACION.md             # Esta guía
├── GUIA_DIDACTICA_IMPORTADOR_V2.md         # Guía del agente v2
└── README.md                                # Documentación general

scripts/
├── opac_exportar.py                         # Conversor CSV→MARCXML
└── agente_importador_v2.py                  # Motor de importación

/
├── importar_con_tmux.sh                     # ⭐ PERSISTENCIA SSH
├── monitor_importacion.sh                   # ⭐ MONITOR TIEMPO REAL
├── validador_csv.py                         # ⭐ VALIDACIÓN PREVENTIVA
├── importar_automatico.sh                   # Importador automático
└── subir_csv.sh                             # Subida de archivos
```

---

## 🔗 INTEGRACIÓN CON HERRAMIENTAS EXISTENTES

### Compatible con:
- ✅ `agente_importador_v2.py` (sin cambios)
- ✅ `opac_exportar.py` (sin cambios)
- ✅ `importar_automatico.sh` (wrapper con tmux)
- ✅ Todos los scripts de corrección existentes

### Nuevas capacidades:
- ✅ Persistencia total de sesiones SSH
- ✅ Validación preventiva automatizada
- ✅ Monitoreo en tiempo real
- ✅ Dashboards informativos

---

## 🆘 AYUDA Y SOPORTE

### Obtener Ayuda
```bash
./importar_con_tmux.sh --help
./monitor_importacion.sh --help
./validador_csv.py --help
```

### Verificar Estado del Sistema
```bash
# Verificar tmux instalado
which tmux

# Verificar conexión a Koha
sudo koha-mysql koha-cnc -e "SELECT 1"

# Verificar espacio en disco
df -h /home/mvillalba/migradatos

# Ver procesos activos
ps aux | grep koha
```

### Logs Importantes
```bash
# Logs de importación
ls -lht logs/importacion_*.log

# Reportes de importación
ls -lht logs/reporte_*.txt

# Ver último log completo
less $(ls -t logs/importacion_*.log | head -1)
```

---

## ✨ EJEMPLOS PRÁCTICOS

### Ejemplo 1: Importación Segura de Biblioteca Medicina
```bash
# 1. Validar
./validador_csv.py MED.csv

# 2. Subir
./subir_csv.sh MED.csv MED

# 3. Importar en tmux
./importar_con_tmux.sh

# 4. Desconectar (Ctrl+b d)

# 5. Ir a tomar café ☕

# 6. Volver y ver progreso
./importar_con_tmux.sh --attach
```

### Ejemplo 2: Vigilancia Continua de Importaciones
```bash
# Terminal 1: Iniciar vigilancia
./importar_con_tmux.sh --watch
# Desconectar: Ctrl+b d

# Terminal 2: Monitor en tiempo real
./monitor_importacion.sh --watch

# Coloca archivos CSV en importar_aqui/
# Se procesan automáticamente
```

### Ejemplo 3: Validación de Lote Antes de Importar
```bash
# Validar todos los CSV
./validador_csv.py --dir importar_aqui/

# Si todos válidos, importar
./importar_automatico.sh
```

---

## 📝 CHECKLIST PRE-IMPORTACIÓN

```
[ ] CSV validado con validador_csv.py
[ ] Espacio en disco suficiente (df -h)
[ ] Biblioteca existe en Koha
[ ] Código de biblioteca en nombre de archivo
[ ] tmux instalado y funcionando
[ ] Backup reciente (si aplica)
[ ] Monitor disponible en otra terminal
```

---

## 🎉 ¡MEJORAS IMPLEMENTADAS!

### ✅ Completado
1. ✅ Sistema de persistencia con tmux
2. ✅ Monitor en tiempo real
3. ✅ Validador preventivo de CSV
4. ✅ Documentación completa
5. ✅ Scripts ejecutables y listos
6. ✅ Guías de uso

### 🔄 Próximas Mejoras (Opcionales)
1. Sistema de checkpoint/resume para recuperación
2. Paralelización de importación de XMLs
3. Optimización de parámetros de commit
4. Dashboard web (opcional)
5. Notificaciones automáticas por email

---

**¡SISTEMA LISTO PARA USO EN PRODUCCIÓN!**

**Universidad Nacional de Asunción**
**Sistema Koha OPAC**
**2025-10-24**

---
