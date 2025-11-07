# 🚀 GUÍA COMPLETA - SISTEMA DE IMPORTACIÓN OPTIMIZADO KOHA

**Universidad Nacional de Asunción**
**Sistema de Importación Automatizada - Versión 3.0**
**Fecha: 31 de Octubre de 2025**

---

## 📋 Tabla de Contenidos

1. [Introducción](#introducción)
2. [Arquitectura del Sistema](#arquitectura-del-sistema)
3. [Instalación y Configuración](#instalación-y-configuración)
4. [Guía de Uso Rápida](#guía-de-uso-rápida)
5. [Modos de Operación](#modos-de-operación)
6. [Dashboard Web](#dashboard-web)
7. [Recuperación ante Fallos](#recuperación-ante-fallos)
8. [Solución de Problemas](#solución-de-problemas)
9. [API y Automatización](#api-y-automatización)
10. [Mejores Prácticas](#mejores-prácticas)

---

## 📖 Introducción

El **Sistema de Importación Optimizado** es una solución integral para automatizar la importación de datos bibliográficos desde archivos CSV al sistema Koha OPAC de la Universidad Nacional de Asunción.

### ✨ Características Principales

- ✅ **Detección automática** de código de biblioteca desde nombre de archivo
- ✅ **Validación preventiva** de archivos CSV antes de importar
- ✅ **Control de duplicados** interno y contra base de datos
- ✅ **Recuperación ante fallos** - Continúa desde donde se interrumpió
- ✅ **Dashboard web** para monitoreo en tiempo real
- ✅ **Modo batch** para procesar múltiples archivos
- ✅ **Modo vigilancia** para importación continua
- ✅ **Reportes detallados** automáticos
- ✅ **Logs completos** de cada operación
- ✅ **API REST** para integración

### 🎯 Componentes del Sistema

| Componente | Descripción | Archivo |
|------------|-------------|---------|
| **Script Maestro** | Orquestador principal del sistema | `importar_optimizado.sh` |
| **Agente Python V3** | Motor de importación con recuperación | `agente_importador_v3.py` |
| **Validador CSV** | Validación preventiva de archivos | `validador_csv.py` |
| **Dashboard Web** | Monitoreo visual en tiempo real | `dashboard.py` |

---

## 🏗️ Arquitectura del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    SISTEMA DE IMPORTACIÓN                       │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              │               │               │
    ┌─────────▼────────┐ ┌───▼────────┐ ┌───▼──────────┐
    │ Script Maestro   │ │ Dashboard  │ │ Validador    │
    │ (Orquestador)    │ │   Web      │ │     CSV      │
    └─────────┬────────┘ └────────────┘ └──────────────┘
              │
    ┌─────────▼─────────┐
    │  Agente Python V3 │
    │  (Motor Core)     │
    └─────────┬─────────┘
              │
    ┌─────────▼─────────┐
    │  Sistema Koha     │
    │  (Base de Datos)  │
    └───────────────────┘
```

### Flujo de Datos

1. **Entrada**: Archivos CSV en carpeta `importar_aqui/`
2. **Validación**: Verificación de formato y estructura
3. **Procesamiento**: Conversión a MARCXML
4. **Importación**: Carga a Koha con control de transacciones
5. **Reindexación**: Actualización de índices de búsqueda
6. **Reporte**: Generación de estadísticas y logs

---

## ⚙️ Instalación y Configuración

### Requisitos del Sistema

```bash
# Sistema Operativo
- Linux (Ubuntu 20.04+ / Debian 10+)

# Software Requerido
- Python 3.8+
- Koha 20.05+
- MySQL/MariaDB
- Permisos sudo

# Espacio en Disco
- Mínimo: 10 GB libres
- Recomendado: 50 GB+
```

### Instalación

```bash
# 1. Clonar o descargar sistema
cd /home/mvillalba/migradatos

# 2. Dar permisos de ejecución
chmod +x importar_optimizado.sh
chmod +x agente_importador_v3.py
chmod +x validador_csv.py
chmod +x dashboard.py

# 3. Crear directorios necesarios (automático al ejecutar)
# Los scripts crearán automáticamente:
# - importar_aqui/
# - procesados/
# - errores/
# - logs/
# - reportes/
# - exports/

# 4. Verificar instalación
./importar_optimizado.sh --help
```

---

## 🚀 Guía de Uso Rápida

### Caso 1: Importar un Archivo Único

```bash
# Forma más simple (archivo en importar_aqui/)
./importar_optimizado.sh

# O especificar archivo directamente
./importar_optimizado.sh /ruta/a/MED.csv
```

### Caso 2: Validar Antes de Importar

```bash
# Solo validar sin importar
./importar_optimizado.sh --validate-only --batch importar_aqui/

# Validar archivo específico
./validador_csv.py archivo.csv
```

### Caso 3: Procesar Múltiples Archivos (Batch)

```bash
# Procesar todos los CSV en un directorio
./importar_optimizado.sh --batch /ruta/directorio/

# Procesar carpeta por defecto
./importar_optimizado.sh
```

### Caso 4: Modo Vigilancia Continua

```bash
# Iniciar modo vigilancia
./importar_optimizado.sh --watch

# El sistema monitoreará importar_aqui/ cada 10 segundos
# Coloca archivos CSV y se procesarán automáticamente
```

---

## 🔧 Modos de Operación

### 1. Modo Normal (Archivo Único)

Procesa un archivo CSV específico.

```bash
./importar_optimizado.sh MED.csv
```

**Proceso:**
1. ✓ Detecta código de biblioteca (MED)
2. ✓ Verifica que existe en Koha
3. ✓ Valida estructura del CSV
4. ✓ Genera archivos MARCXML
5. ✓ Importa a Koha
6. ✓ Reindexa catálogo
7. ✓ Genera reporte

**Salida:**
- Log: `logs/maestro_YYYYMMDD_HHMMSS.log`
- Reporte: `reportes/reporte_MED_YYYYMMDD_HHMMSS.txt`
- CSV movido a: `procesados/MED_YYYYMMDD_HHMMSS.csv`

---

### 2. Modo Batch

Procesa todos los archivos CSV en un directorio.

```bash
./importar_optimizado.sh --batch /ruta/directorio/

# O carpeta por defecto
./importar_optimizado.sh
```

**Ventajas:**
- Procesa múltiples bibliotecas en una sola ejecución
- Genera reporte consolidado
- Control de errores por archivo
- Estadísticas globales

**Ejemplo de salida:**

```
╔════════════════════════════════════════════════════════════════════╗
║              RESUMEN DE EJECUCIÓN - IMPORTADOR OPTIMIZADO          ║
╚════════════════════════════════════════════════════════════════════╝

Archivos procesados:    5
Importaciones exitosas: 4
Importaciones fallidas: 1
Duración total:         1847 segundos (30 minutos)
```

---

### 3. Modo Vigilancia (Watch)

Monitorea continuamente una carpeta y procesa automáticamente nuevos archivos.

```bash
./importar_optimizado.sh --watch
```

**Uso típico:**

1. Iniciar vigilancia (puede ser en sesión tmux):
   ```bash
   ./importar_optimizado.sh --watch
   ```

2. Desde otra terminal, copiar archivos CSV:
   ```bash
   cp /origen/FACEN.csv importar_aqui/
   ```

3. El sistema detectará y procesará automáticamente

**Características:**
- Revisa carpeta cada 10 segundos
- Detecta archivos nuevos o modificados
- Procesa automáticamente
- No duplica procesamiento
- Se puede detener con Ctrl+C

---

### 4. Modo Solo-Validación

Valida archivos sin importar (útil para pruebas).

```bash
./importar_optimizado.sh --validate-only --batch importar_aqui/
```

**Validaciones realizadas:**
- ✓ Formato CSV correcto
- ✓ Encoding (UTF-8)
- ✓ Delimitador (`;` o `,`)
- ✓ Columnas obligatorias (titulo, nroacceso)
- ✓ Duplicados internos
- ✓ Tamaño de archivo
- ✓ Integridad de datos

---

## 📊 Dashboard Web

El dashboard proporciona visualización en tiempo real del estado del sistema.

### Iniciar Dashboard

```bash
# Puerto por defecto (5000)
./dashboard.py

# Puerto personalizado
./dashboard.py --port 8888

# Acceso desde red
./dashboard.py --host 0.0.0.0 --port 5000
```

### Acceso

Abre tu navegador en:
```
http://localhost:5000
```

### Características

- **Estadísticas en vivo**: Total de biblios, items, bibliotecas
- **Top bibliotecas**: Ranking por número de items
- **Últimas importaciones**: Historial reciente
- **Estado del sistema**: Espacio libre, procesos activos
- **Actualización automática**: Cada 30 segundos

### API REST

El dashboard expone una API REST:

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

**Ejemplo de respuesta (stats):**

```json
{
  "bibliotecas": [
    {
      "codigo": "MED",
      "nombre": "Biblioteca de Medicina",
      "titulos": 15234,
      "ejemplares": 18567
    }
  ],
  "totales": {
    "biblios": 128110,
    "items": 109451,
    "bibliotecas": 14
  }
}
```

---

## 🔄 Recuperación ante Fallos

El sistema V3 incluye **recuperación automática** ante interrupciones.

### Cómo Funciona

1. **Guardado de estado**: El sistema guarda su estado cada paso:
   - Fase actual (validación, marcxml, importación, reindex)
   - Archivos XML generados
   - Archivos XML ya importados
   - Registros procesados

2. **Detección de interrupción**: Al iniciar, verifica si hay estados guardados

3. **Reanudación**: Continúa desde el último punto exitoso

### Uso de Recuperación

```bash
# El sistema detecta automáticamente si hay que recuperar
./importar_optimizado.sh MED.csv

# O forzar reanudación
./agente_importador_v3.py MED.csv --resume
```

### Escenarios de Recuperación

#### Escenario 1: Fallo durante generación MARCXML

```
[FALLO aquí]
✓ Validación completa
✗ Generación MARCXML interrumpida
- Importación pendiente

[RECUPERACIÓN]
$ ./importar_optimizado.sh MED.csv
→ Detecta estado guardado
→ Reintenta generación MARCXML
→ Continúa importación
```

#### Escenario 2: Fallo durante importación (archivo 3 de 5)

```
[FALLO aquí]
✓ Archivos 1-2 importados
✗ Archivo 3 interrumpido
- Archivos 4-5 pendientes

[RECUPERACIÓN]
$ ./agente_importador_v3.py MED.csv --resume
→ Carga estado
→ Salta archivos 1-2 (ya importados)
→ Continúa desde archivo 3
```

### Limpieza de Estado

El estado se limpia automáticamente tras completar exitosamente.

Para limpiar manualmente:
```bash
rm -f .cache/estado_*.pkl
```

---

## 🛠️ Solución de Problemas

### Problema 1: "No se detectó código de biblioteca"

**Causa**: El nombre del archivo no contiene un código válido.

**Solución**:
```bash
# ❌ Mal
archivo_datos.csv

# ✅ Bien
MED.csv
MED_2025.csv
FACEN_octubre.csv
```

---

### Problema 2: "La biblioteca no existe en Koha"

**Causa**: El código detectado no existe en la base de datos.

**Solución**:
```bash
# Ver bibliotecas disponibles
sudo koha-mysql koha-cnc -e "SELECT branchcode, branchname FROM branches"

# Crear biblioteca en Koha
# Staff Interface → Administración → Bibliotecas → Nueva biblioteca
```

---

### Problema 3: "Faltan columnas obligatorias"

**Causa**: El CSV no tiene las columnas `titulo` y `nroacceso`.

**Solución**:
```bash
# Validar archivo
./validador_csv.py archivo.csv

# Verificar encabezado del CSV
head -1 archivo.csv

# Asegurarse de tener (mínimo):
titulo;nroacceso;autor;editorial;...
```

---

### Problema 4: "Error de memoria durante importación"

**Causa**: Archivo muy grande para recursos disponibles.

**Solución**:
```bash
# Opción 1: Dividir archivo manualmente
split -l 5000 archivo_grande.csv archivo_parte_

# Opción 2: Reducir MAX_RECORDS_PER_FILE en agente_importador_v3.py
# Editar línea ~72:
MAX_RECORDS_PER_FILE = 1000  # Reducir de 2000 a 1000
```

---

### Problema 5: "Timeout durante reindexación"

**Causa**: Catálogo muy grande.

**Solución**:
```bash
# La reindexación no es crítica, se puede hacer manualmente después
sudo koha-rebuild-zebra -v koha-cnc

# O en horario de baja carga
sudo koha-rebuild-zebra -b koha-cnc  # Solo biblios
```

---

### Problema 6: "Duplicados en códigos de acceso"

**Causa**: El CSV tiene códigos de barras repetidos.

**Solución**:
```bash
# Detectar duplicados
./validador_csv.py archivo.csv

# Ver cuáles están duplicados
awk -F';' 'NR>1 {print $2}' archivo.csv | sort | uniq -d

# Usar script de corrección (si existe para tu biblioteca)
python3 corregir_codigos_CODIGO.py archivo.csv
```

---

## 🤖 API y Automatización

### Integración con Cron

Procesar archivos automáticamente cada hora:

```bash
# Editar crontab
crontab -e

# Agregar línea:
0 * * * * cd /home/mvillalba/migradatos && ./importar_optimizado.sh >> logs/cron.log 2>&1
```

### Integración con Scripts Externos

```bash
#!/bin/bash
# script_externo.sh

# Copiar archivo a carpeta de importación
cp /origen/datos.csv /home/mvillalba/migradatos/importar_aqui/MED.csv

# Ejecutar importación
cd /home/mvillalba/migradatos
./importar_optimizado.sh

# Verificar resultado
if [ $? -eq 0 ]; then
    echo "Importación exitosa"
    # Enviar notificación (email, webhook, etc.)
else
    echo "Error en importación"
    # Alertar
fi
```

### Uso de API REST

```python
import requests

# Obtener estadísticas
response = requests.get('http://localhost:5000/api/stats')
stats = response.json()

print(f"Total items: {stats['totales']['items']}")

# Monitorear importaciones
response = requests.get('http://localhost:5000/api/importaciones')
importaciones = response.json()

for imp in importaciones['importaciones']:
    print(f"Biblioteca {imp['codigo']} - {imp['fecha']}")
```

---

## 💡 Mejores Prácticas

### 1. Preparación de Archivos CSV

```bash
# ✅ Buenas prácticas
- Usar nombres claros: MED.csv, FACEN.csv
- Encoding UTF-8
- Delimitador consistente (`;` preferido)
- Incluir todas las columnas obligatorias
- Verificar que no haya líneas vacías al final

# ❌ Evitar
- Nombres ambiguos: datos.csv, export.csv
- Mezclar delimitadores
- Archivos con BOM (UTF-8 con BOM)
```

### 2. Validación Preventiva

**SIEMPRE valida antes de importar:**

```bash
# Validar archivo
./validador_csv.py archivo.csv

# Solo importar si validación es exitosa
if [ $? -eq 0 ]; then
    ./importar_optimizado.sh archivo.csv
fi
```

### 3. Respaldos

```bash
# Respaldar CSV original
cp archivo.csv archivo.csv.backup

# Respaldar base de datos antes de importación grande
sudo mysqldump koha_koha-cnc > backup_$(date +%Y%m%d).sql
```

### 4. Monitoreo

```bash
# Iniciar dashboard para monitoreo visual
./dashboard.py &

# Monitorear logs en tiempo real
tail -f logs/maestro_*.log

# Ver procesos activos
ps aux | grep bulkmarcimport
```

### 5. Optimización de Rendimiento

```bash
# Para archivos grandes (>50k registros):

# 1. Ejecutar en horario de baja carga
# 2. Aumentar recursos temporalmente
# 3. Dividir en lotes más pequeños
# 4. Usar modo batch con archivos de 10k registros c/u

# Ejemplo de división
split -l 10000 archivo_grande.csv archivo_parte_
# Renombrar manualmente: MED_parte_1.csv, MED_parte_2.csv...
./importar_optimizado.sh --batch ./
```

### 6. Mantenimiento

```bash
# Limpiar logs antiguos (>30 días)
find logs/ -name "*.log" -mtime +30 -delete

# Limpiar archivos procesados antiguos
find procesados/ -name "*.csv" -mtime +90 -delete

# Limpiar cache de estado
rm -rf .cache/estado_*.pkl

# Optimizar base de datos periódicamente
sudo koha-mysql koha-cnc -e "OPTIMIZE TABLE biblio, items, biblioitems"
```

---

## 📈 Métricas y Rendimiento

### Tiempos Estimados

| Tamaño | Registros | Tiempo Aprox. | Recomendación |
|--------|-----------|---------------|---------------|
| Pequeño | < 1,000 | 2-5 min | Archivo único |
| Mediano | 1,000-10,000 | 5-20 min | Archivo único o dividir |
| Grande | 10,000-50,000 | 20-60 min | Dividir en lotes |
| Muy grande | > 50,000 | 1-3 horas | Dividir + horario nocturno |

### Recursos del Sistema

```bash
# Uso típico durante importación
CPU: 40-60%
RAM: 2-4 GB
Disco: escritura ~50 MB/s
Red: mínimo

# Recomendaciones hardware
CPU: 4+ cores
RAM: 8+ GB
Disco: SSD preferido
```

---

## 📞 Soporte y Contacto

### Logs y Diagnóstico

Cuando reportes un problema, incluye:

```bash
# 1. Versión del sistema
./importar_optimizado.sh --help | head -1

# 2. Último log
tail -100 logs/maestro_*.log | tail -1

# 3. Estado de Koha
sudo koha-mysql koha-cnc -e "SELECT VERSION()"

# 4. Espacio en disco
df -h /home/mvillalba/migradatos
```

### Ubicación de Archivos Importantes

```
/home/mvillalba/migradatos/
├── importar_optimizado.sh      # Script maestro
├── agente_importador_v3.py     # Motor principal
├── validador_csv.py            # Validador
├── dashboard.py                # Dashboard web
├── importar_aqui/              # CSVs a procesar
├── logs/                       # Logs del sistema
├── reportes/                   # Reportes generados
├── procesados/                 # CSVs exitosos
└── errores/                    # CSVs con errores
```

---

## 📚 Referencias

- [Documentación Koha](https://koha-community.org/manual/)
- [Formato MARC21](https://www.loc.gov/marc/)
- [Bulkmarcimport Tool](https://koha-community.org/manual/latest/en/html/command_line_utilities.html#bulkmarcimport-pl)

---

## 🎓 Créditos

**Universidad Nacional de Asunción**
**Biblioteca Central**
**Sistema Koha OPAC**

**Desarrollado por**: Equipo de Migración de Datos
**Versión**: 3.0
**Fecha**: Octubre 2025

---

## 📄 Licencia

Este sistema es propiedad de la Universidad Nacional de Asunción.
Uso exclusivo para fines académicos y administrativos de la institución.

---

**¿Necesitas ayuda?**

```bash
# Ver ayuda de cada componente
./importar_optimizado.sh --help
./agente_importador_v3.py --help
./validador_csv.py --help
./dashboard.py --help
```

**¡Importaciones exitosas! 🎉**
