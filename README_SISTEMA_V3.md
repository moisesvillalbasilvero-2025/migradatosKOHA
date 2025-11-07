# 📚 SISTEMA DE IMPORTACIÓN AUTOMÁTICA KOHA V3.0

**Universidad Nacional de Asunción**
**Sistema Optimizado de Importación de Datos Bibliográficos**
**Fecha: 31 de Octubre de 2025**

---

## 🎯 Inicio Rápido

```bash
# 1. Colocar archivo CSV en importar_aqui/
cp tu_archivo.csv importar_aqui/MED.csv

# 2. Ejecutar importador
./importar_optimizado.sh

# 3. ¡Listo! Ver resultados en reportes/
```

**📖 Guía rápida completa**: [INICIO_RAPIDO_V3.txt](./INICIO_RAPIDO_V3.txt)

---

## 📦 Componentes del Sistema

### Scripts Principales

| Script | Descripción | Uso |
|--------|-------------|-----|
| **importar_optimizado.sh** | 🎯 Script maestro orquestador | `./importar_optimizado.sh [opciones]` |
| **agente_importador_v3.py** | 🤖 Motor de importación con recuperación | `./agente_importador_v3.py archivo.csv` |
| **validador_csv.py** | ✅ Validador preventivo de CSV | `./validador_csv.py archivo.csv` |
| **dashboard.py** | 📊 Dashboard web de monitoreo | `./dashboard.py` |

### Scripts de Compatibilidad (Legacy)

Mantenidos para compatibilidad con flujos existentes:

- `importar_automatico.sh` - Wrapper original
- `agente_importador_v2.py` - Versión anterior
- `importar_biblioteca.sh` - Script individual
- `importar_con_tmux.sh` - Soporte tmux

---

## 🚀 Características V3.0

### ✨ Nuevas Características

- ✅ **Recuperación automática** ante fallos e interrupciones
- ✅ **Dashboard web** con visualización en tiempo real
- ✅ **Modo batch optimizado** para múltiples archivos
- ✅ **Sistema unificado** de orquestación
- ✅ **Validación mejorada** con reintentos automáticos
- ✅ **Reportes detallados** automáticos
- ✅ **API REST** para integración
- ✅ **Logs estructurados** con niveles

### 🔄 Mejoras sobre V2.0

| Aspecto | V2.0 | V3.0 |
|---------|------|------|
| Recuperación ante fallos | ❌ Manual | ✅ Automática |
| Dashboard | ❌ No | ✅ Web en tiempo real |
| Reportes | ⚠️ Básicos | ✅ Detallados |
| Validación | ⚠️ Simple | ✅ Completa con reintentos |
| Modo batch | ⚠️ Limitado | ✅ Optimizado |
| API | ❌ No | ✅ REST disponible |

---

## 📂 Estructura de Directorios

```
/home/mvillalba/migradatos/
│
├── 📄 Scripts Principales
│   ├── importar_optimizado.sh       ⭐ Script maestro V3
│   ├── agente_importador_v3.py      ⭐ Motor principal V3
│   ├── validador_csv.py             ⭐ Validador
│   └── dashboard.py                 ⭐ Dashboard web
│
├── 📄 Scripts Legacy (compatibilidad)
│   ├── importar_automatico.sh
│   ├── agente_importador_v2.py
│   ├── importar_biblioteca.sh
│   └── importar_con_tmux.sh
│
├── 📁 Directorios de Datos
│   ├── importar_aqui/              🔵 Coloca aquí tus CSV
│   ├── procesados/                 ✅ CSVs exitosos
│   ├── errores/                    ❌ CSVs con problemas
│   ├── logs/                       📝 Logs del sistema
│   ├── reportes/                   📊 Reportes generados
│   ├── exports/                    📦 Archivos MARCXML
│   └── .cache/                     💾 Estado de recuperación
│
├── 📚 Documentación
│   ├── README_SISTEMA_V3.md        📖 Este archivo
│   ├── GUIA_COMPLETA_OPTIMIZADA.md 📕 Guía detallada
│   ├── INICIO_RAPIDO_V3.txt        ⚡ Referencia rápida
│   └── docs/                       📂 Documentación adicional
│
└── 🗂️ Obsoletos
    └── _obsoletos/                 🗄️ Scripts antiguos archivados
```

---

## 🎓 Casos de Uso

### Caso 1: Usuario Nuevo - Primera Importación

```bash
# 1. Leer guía rápida
cat INICIO_RAPIDO_V3.txt

# 2. Validar archivo
./validador_csv.py MED.csv

# 3. Importar
./importar_optimizado.sh MED.csv

# 4. Ver resultado
cat reportes/reporte_MED_*.txt
```

**Tiempo estimado**: 10-15 minutos
**Documentación**: [INICIO_RAPIDO_V3.txt](./INICIO_RAPIDO_V3.txt)

---

### Caso 2: Usuario Avanzado - Múltiples Bibliotecas

```bash
# 1. Colocar todos los CSV
cp /origen/*.csv importar_aqui/

# 2. Validar todos
./validador_csv.py --dir importar_aqui/

# 3. Iniciar dashboard (opcional pero recomendado)
./dashboard.py &

# 4. Importar todo en batch
./importar_optimizado.sh --batch importar_aqui/

# 5. Ver resumen
cat reportes/resumen_*.txt
```

**Tiempo estimado**: Variable según cantidad
**Documentación**: [GUIA_COMPLETA_OPTIMIZADA.md](./GUIA_COMPLETA_OPTIMIZADA.md) → Sección "Modo Batch"

---

### Caso 3: Automatización - Vigilancia Continua

```bash
# 1. Iniciar en tmux (persistente)
tmux new-session -s importacion

# 2. Iniciar vigilancia
./importar_optimizado.sh --watch

# 3. Desconectar (Ctrl+b d)
# El sistema seguirá procesando automáticamente

# 4. Reconectar cuando quieras
tmux attach -t importacion
```

**Tiempo estimado**: Continuo
**Documentación**: [GUIA_COMPLETA_OPTIMIZADA.md](./GUIA_COMPLETA_OPTIMIZADA.md) → Sección "Modo Vigilancia"

---

### Caso 4: Recuperación - Importación Interrumpida

```bash
# Si una importación falló o se interrumpió:

# 1. Volver a ejecutar el mismo comando
./importar_optimizado.sh archivo.csv

# 2. El sistema detecta automáticamente el estado guardado
# 3. Continúa desde donde se quedó
# ✅ No se pierde progreso
```

**Tiempo estimado**: Continúa desde el punto de fallo
**Documentación**: [GUIA_COMPLETA_OPTIMIZADA.md](./GUIA_COMPLETA_OPTIMIZADA.md) → Sección "Recuperación ante Fallos"

---

## 📊 Monitoreo y Dashboard

### Iniciar Dashboard Web

```bash
# Iniciar servidor
./dashboard.py

# Acceder desde navegador
http://localhost:5000
```

### Características del Dashboard

- 📈 Estadísticas en tiempo real
- 📚 Top bibliotecas por items
- 📥 Historial de importaciones
- 💾 Estado del sistema (espacio, procesos)
- 🔄 Actualización automática cada 30s

### API REST

Endpoints disponibles:

```bash
# Estadísticas de bibliotecas
curl http://localhost:5000/api/stats

# Logs recientes
curl http://localhost:5000/api/logs

# Últimas importaciones
curl http://localhost:5000/api/importaciones

# Estado del sistema
curl http://localhost:5000/api/estado
```

**Documentación**: [GUIA_COMPLETA_OPTIMIZADA.md](./GUIA_COMPLETA_OPTIMIZADA.md) → Sección "Dashboard Web"

---

## 🛠️ Comandos Útiles

### Importación

```bash
# Archivo único
./importar_optimizado.sh archivo.csv

# Carpeta por defecto
./importar_optimizado.sh

# Modo batch
./importar_optimizado.sh --batch /ruta/

# Modo vigilancia
./importar_optimizado.sh --watch

# Solo validar
./importar_optimizado.sh --validate-only
```

### Validación

```bash
# Validar archivo
./validador_csv.py archivo.csv

# Validar directorio
./validador_csv.py --dir importar_aqui/

# Modo estricto
./validador_csv.py --strict archivo.csv
```

### Monitoreo

```bash
# Dashboard web
./dashboard.py

# Ver logs en tiempo real
tail -f logs/maestro_*.log

# Estadísticas de Koha
sudo koha-mysql koha-cnc -e "
  SELECT homebranch, COUNT(*) as items
  FROM items
  GROUP BY homebranch"
```

---

## 🔧 Solución de Problemas

### Problemas Comunes

| Problema | Solución Rápida | Documentación |
|----------|-----------------|---------------|
| "No se detectó código" | Renombrar: `datos.csv` → `MED.csv` | [Guía Completa](./GUIA_COMPLETA_OPTIMIZADA.md#problema-1) |
| "Biblioteca no existe" | Crear en Koha Staff Interface | [Guía Completa](./GUIA_COMPLETA_OPTIMIZADA.md#problema-2) |
| "Faltan columnas" | Verificar `titulo` y `nroacceso` | [Guía Completa](./GUIA_COMPLETA_OPTIMIZADA.md#problema-3) |
| Error de memoria | Dividir archivo en partes | [Guía Completa](./GUIA_COMPLETA_OPTIMIZADA.md#problema-4) |
| Duplicados | Ver con validador | [Guía Completa](./GUIA_COMPLETA_OPTIMIZADA.md#problema-6) |

### Logs de Diagnóstico

```bash
# Ver últimos errores
cat logs/maestro_*.log | grep ERROR | tail -20

# Ver log completo
cat logs/maestro_$(date +%Y%m%d)_*.log

# Ver reporte específico
cat reportes/reporte_MED_*.txt
```

---

## 📈 Rendimiento

### Tiempos Estimados

| Tamaño | Registros | Tiempo | Modo Recomendado |
|--------|-----------|--------|------------------|
| Pequeño | < 1,000 | 2-5 min | Normal |
| Mediano | 1,000-10,000 | 5-20 min | Normal o Batch |
| Grande | 10,000-50,000 | 20-60 min | Batch dividido |
| Muy grande | > 50,000 | 1-3 horas | Batch + Nocturno |

### Optimizaciones

```bash
# Para archivos grandes:

# 1. Dividir en lotes
split -l 10000 archivo_grande.csv parte_

# 2. Renombrar con código
mv parte_aa MED_parte_1.csv
mv parte_ab MED_parte_2.csv

# 3. Procesar batch
./importar_optimizado.sh --batch ./
```

---

## 🔐 Seguridad y Respaldos

### Antes de Importar

```bash
# 1. Respaldar CSV original
cp archivo.csv archivo.csv.backup

# 2. Respaldar base de datos (opcional pero recomendado para importaciones grandes)
sudo mysqldump koha_koha-cnc > backup_$(date +%Y%m%d).sql.gz
```

### Después de Importar

```bash
# Verificar totales
sudo koha-mysql koha-cnc -e "
  SELECT COUNT(*) as total_items FROM items"

# Verificar biblioteca específica
sudo koha-mysql koha-cnc -e "
  SELECT COUNT(*) FROM items WHERE homebranch='MED'"
```

---

## 🤝 Integración

### Con Cron (Automatización)

```bash
# Editar crontab
crontab -e

# Procesar automáticamente cada hora
0 * * * * cd /home/mvillalba/migradatos && ./importar_optimizado.sh

# A las 2 AM diariamente
0 2 * * * cd /home/mvillalba/migradatos && ./importar_optimizado.sh --batch importar_aqui/
```

### Con Scripts Externos

```python
import subprocess
import requests

# Importar
resultado = subprocess.run(
    ['./importar_optimizado.sh', 'archivo.csv'],
    capture_output=True
)

if resultado.returncode == 0:
    # Consultar API para estadísticas
    stats = requests.get('http://localhost:5000/api/stats').json()
    print(f"Total items: {stats['totales']['items']}")
```

---

## 📚 Documentación Completa

### Archivos de Documentación

| Documento | Descripción | Cuándo Leer |
|-----------|-------------|-------------|
| **README_SISTEMA_V3.md** | Este archivo - Índice general | Primero |
| **INICIO_RAPIDO_V3.txt** | Referencia rápida de comandos | Para uso diario |
| **GUIA_COMPLETA_OPTIMIZADA.md** | Guía detallada completa | Para casos avanzados |

### Comandos de Ayuda

```bash
# Ayuda de cada componente
./importar_optimizado.sh --help
./agente_importador_v3.py --help
./validador_csv.py --help
./dashboard.py --help
```

---

## 🎓 Formación y Capacitación

### Para Usuarios Nuevos

1. **Leer**: [INICIO_RAPIDO_V3.txt](./INICIO_RAPIDO_V3.txt) (15 min)
2. **Practicar**: Importar archivo de prueba (30 min)
3. **Revisar**: Reportes y logs generados (15 min)

**Total**: ~1 hora

### Para Usuarios Avanzados

1. **Leer**: [GUIA_COMPLETA_OPTIMIZADA.md](./GUIA_COMPLETA_OPTIMIZADA.md) (30 min)
2. **Experimentar**: Modos batch y vigilancia (1 hora)
3. **Configurar**: Dashboard y automatización (30 min)

**Total**: ~2 horas

---

## 🔄 Migración desde V2

### Diferencias Clave

```bash
# V2 (antiguo)
./importar_automatico.sh

# V3 (nuevo - recomendado)
./importar_optimizado.sh
```

### Compatibilidad

Los scripts V2 siguen funcionando, pero se recomienda migrar a V3 para:

- ✅ Recuperación automática
- ✅ Dashboard web
- ✅ Reportes mejorados
- ✅ API REST

### Guía de Migración

1. **Probar V3** con archivo de prueba
2. **Comparar** resultados con V2
3. **Migrar** gradualmente tus flujos
4. **Mantener** V2 como respaldo temporal

---

## 📞 Soporte

### Información del Sistema

```bash
# Versión
./importar_optimizado.sh --help | head -1

# Estado
df -h /home/mvillalba/migradatos
ps aux | grep bulkmarcimport
```

### Reportar Problemas

Incluir:
1. ✅ Comando ejecutado
2. ✅ Último log: `tail -50 logs/maestro_*.log`
3. ✅ Archivo de prueba (si es pequeño)
4. ✅ Versión del sistema

---

## ✅ Estado del Proyecto

### Versión Actual: 3.0

**Estado**: ✅ Producción
**Fecha de Release**: 31 de Octubre de 2025
**Mantenimiento**: Activo

### Componentes

| Componente | Estado | Versión |
|------------|--------|---------|
| Script Maestro | ✅ Estable | 3.0 |
| Agente Python | ✅ Estable | 3.0 |
| Validador | ✅ Estable | 1.0 |
| Dashboard | ✅ Estable | 1.0 |
| Documentación | ✅ Completa | 3.0 |

---

## 🏆 Créditos

**Universidad Nacional de Asunción**
**Biblioteca Central**
**Equipo de Migración de Datos**

**Desarrolladores**: Equipo Técnico UNA
**Fecha**: Octubre 2025
**Versión**: 3.0

---

## 🎯 Próximos Pasos

### Para Empezar Ahora

1. ✅ Lee [INICIO_RAPIDO_V3.txt](./INICIO_RAPIDO_V3.txt)
2. ✅ Coloca un CSV de prueba en `importar_aqui/`
3. ✅ Ejecuta `./importar_optimizado.sh`
4. ✅ Revisa el reporte generado

### Para Dominar el Sistema

1. ✅ Lee [GUIA_COMPLETA_OPTIMIZADA.md](./GUIA_COMPLETA_OPTIMIZADA.md)
2. ✅ Experimenta con diferentes modos
3. ✅ Configura el dashboard
4. ✅ Automatiza tus importaciones

---

## 📄 Licencia

Sistema propietario de la Universidad Nacional de Asunción.
Uso exclusivo para fines académicos y administrativos de la institución.

---

**¿Necesitas ayuda?**

```bash
# Ver ayuda
./importar_optimizado.sh --help

# Leer guía rápida
cat INICIO_RAPIDO_V3.txt

# Leer guía completa
less GUIA_COMPLETA_OPTIMIZADA.md
```

**¡Bienvenido al Sistema de Importación V3.0! 🚀**
