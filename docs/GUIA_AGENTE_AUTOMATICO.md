# SISTEMA DE IMPORTACIÓN AUTOMÁTICA A KOHA
## Agente Inteligente v2.0

**Universidad Nacional de Asunción**
**Sistema de Migración Bibliográfica**
**Fecha: 24 de Octubre 2025**

---

## 📋 ÍNDICE

1. [Descripción General](#descripción-general)
2. [Características Principales](#características-principales)
3. [Requisitos del Sistema](#requisitos-del-sistema)
4. [Estructura del Sistema](#estructura-del-sistema)
5. [Guía de Uso Rápida](#guía-de-uso-rápida)
6. [Modo Manual](#modo-manual)
7. [Modo Automático](#modo-automático)
8. [Control de Duplicados](#control-de-duplicados)
9. [Filtrado por Biblioteca](#filtrado-por-biblioteca)
10. [Logs y Reportes](#logs-y-reportes)
11. [Solución de Problemas](#solución-de-problemas)
12. [Ejemplos Prácticos](#ejemplos-prácticos)

---

## DESCRIPCIÓN GENERAL

Sistema completamente automatizado para importación de registros bibliográficos al catálogo Koha OPAC, con capacidades de:

- ✅ **Detección automática** de código de biblioteca desde nombre de archivo
- ✅ **Validación previa** de requisitos y estructura
- ✅ **Control de duplicados** en CSV y en base de datos Koha
- ✅ **Corrección automática** de errores comunes
- ✅ **Generación y validación** de MARCXML
- ✅ **Importación sin supervisión** con reindexación automática
- ✅ **Logs detallados** y reportes completos
- ✅ **Modo vigilancia** para procesamiento continuo

---

## CARACTERÍSTICAS PRINCIPALES

### 🤖 Detección Automática de Biblioteca

El sistema detecta el código de biblioteca directamente del nombre del archivo:

| Nombre de Archivo | Código Detectado |
|-------------------|------------------|
| `MED.csv` | MED |
| `VET_2025.csv` | VET |
| `ING_octubre.csv` | ING |
| `FACAGR_completo.csv` | FACAGR |
| `POL_20251024.csv` | POL |

**No funcionará con:**
- `datos.csv` (sin código)
- `biblioteca_nueva.csv` (sin código)

### 🛡️ Control de Duplicados

**Nivel 1 - En el CSV:**
- Detecta códigos de acceso duplicados dentro del archivo
- Corrige automáticamente si supera el umbral (50 duplicados)
- Genera archivo `*_corregido.csv`

**Nivel 2 - En Koha:**
- Consulta base de datos antes de importar
- Informa cantidad de items existentes para la biblioteca
- Solicita confirmación si ya existen registros
- **NO duplica registros existentes** en la importación

### 🔍 Filtrado por Biblioteca

Puedes procesar solo una biblioteca específica:

```bash
# Solo procesar archivos de biblioteca MED
./importar_automatico.sh --biblioteca MED

# Solo procesar VET de un directorio específico
./importar_automatico.sh --dir /datos --biblioteca VET
```

---

## REQUISITOS DEL SISTEMA

### Requisitos Técnicos

1. **Sistema Operativo:** Linux (Ubuntu/Debian)
2. **Koha instalado y configurado**
3. **Python 3.6+**
4. **Permisos sudo** para comandos de Koha
5. **Espacio en disco:** Mínimo 1GB libre

### Requisitos del Archivo CSV

#### Obligatorios:
- **Campos requeridos:** `titulo`, `nroacceso`
- **Formato:** CSV válido (separado por `,` o `;`)
- **Codificación:** UTF-8
- **Nombre:** Debe contener código de biblioteca (3-6 letras mayúsculas)

#### Opcionales:
- `autor`, `editorial`, `anio`, `isbn`, `materia`, `notas`, etc.

#### Ejemplo de CSV válido:

```csv
nroacceso,titulo,autor,editorial,anio
MED001,Anatomía Humana,García López,Médica Panamericana,2020
MED002,Fisiología Médica,Guyton Hall,Elsevier,2019
```

### Requisitos Previos

1. **La biblioteca debe existir en Koha:**
   - Staff Interface → Administración → Bibliotecas
   - Crear con el mismo código que usarás en el nombre del archivo

2. **Verificar acceso a Koha:**
```bash
sudo koha-mysql koha-cnc -e "SELECT * FROM branches LIMIT 1"
```

---

## ESTRUCTURA DEL SISTEMA

### Directorios

```
/home/mvillalba/migradatos/
│
├── agente_importador_v2.py       # Agente Python (procesador principal)
├── importar_automatico.sh        # Script bash (orquestador)
│
├── importar_aqui/                # ← COLOCA TUS CSV AQUÍ
│   ├── MED.csv
│   ├── VET_2025.csv
│   └── ING_octubre.csv
│
├── procesados/                   # CSV procesados exitosamente
│   └── MED_OK_20251024_143025.csv
│
├── errores/                      # CSV con errores
│   └── DATOS_SIN_CODIGO_20251024_150000.csv
│
├── exports/                      # MARCXML generados
│   ├── MED_20251024_marcxml.xml
│   └── VET_20251024_marcxml.xml
│
└── logs/                         # Logs y reportes
    ├── importacion_MED_20251024_143025.log
    └── reporte_MED_20251024_143025.txt
```

### Archivos Principales

| Archivo | Descripción |
|---------|-------------|
| `agente_importador_v2.py` | Procesador Python con toda la lógica de importación |
| `importar_automatico.sh` | Orquestador bash para búsqueda y control |
| `opac_exportar.py` | Conversor CSV → MARCXML |

---

## GUÍA DE USO RÁPIDA

### 🚀 Inicio en 3 Pasos

#### **Paso 1:** Preparar archivo CSV

Renombrar para incluir código de biblioteca:

```bash
# Ejemplo: archivo de Medicina
mv datos_medicina.csv MED.csv

# Ejemplo: archivo de Veterinaria
mv registros_2025.csv VET_2025.csv
```

#### **Paso 2:** Colocar en carpeta de importación

```bash
cp MED.csv /home/mvillalba/migradatos/importar_aqui/
```

#### **Paso 3:** Ejecutar importador

```bash
cd /home/mvillalba/migradatos
./importar_automatico.sh
```

¡Listo! El sistema procesará automáticamente.

---

## MODO MANUAL

### Procesar un archivo específico

```bash
# Con el agente Python
./agente_importador_v2.py MED.csv

# Con el script bash
./importar_automatico.sh --dir /ruta/al/archivo
```

### Procesar múltiples archivos

```bash
./agente_importador_v2.py MED.csv VET.csv ING.csv
```

### Procesar desde directorio específico

```bash
./importar_automatico.sh --dir /tmp/datos_bibliotecas
```

---

## MODO AUTOMÁTICO

### Modo Vigilancia Continua

Monitorea una carpeta y procesa automáticamente cualquier CSV nuevo:

```bash
# Vigilar carpeta por defecto (importar_aqui/)
./importar_automatico.sh --watch

# Vigilar directorio personalizado
./importar_automatico.sh --watch --dir /datos/entrada

# Vigilar cada 30 segundos
./importar_automatico.sh --watch --intervalo 30
```

**Funcionamiento:**
1. El script queda corriendo en segundo plano
2. Revisa la carpeta cada N segundos (por defecto 10)
3. Detecta archivos nuevos o modificados
4. Los procesa automáticamente
5. Mueve a `procesados/` o `errores/`

**Detener vigilancia:**
```
Ctrl+C
```

---

## CONTROL DE DUPLICADOS

### Verificación Automática

El sistema realiza **DOS verificaciones**:

#### 1️⃣ Duplicados Dentro del CSV

**Qué detecta:**
- Códigos de acceso (`nroacceso`) repetidos en el mismo archivo

**Qué hace:**
- Si detecta > 50 duplicados: ejecuta corrección automática
- Genera archivo `*_corregido.csv`
- Usa el archivo corregido para la importación

**Ejemplo de salida:**
```
3. ANÁLISIS DEL CSV
────────────────────────────────────────────
✓ Total de registros: 3847
⚠ Códigos duplicados: 127 (142 registros afectados)

5. CORRECCIÓN DE DUPLICADOS
────────────────────────────────────────────
→ Iniciando corrección de duplicados...
✓ Archivo corregido: MED_corregido.csv
```

#### 2️⃣ Duplicados en Base de Datos Koha

**Qué detecta:**
- Items ya existentes en Koha para esa biblioteca

**Qué hace:**
- Consulta: `SELECT COUNT(*) FROM items WHERE homebranch = 'MED'`
- Informa cantidad de items existentes
- Solicita confirmación antes de continuar
- **La importación NO duplica registros existentes**

**Ejemplo de salida:**
```
4. VERIFICACIÓN DE ITEMS EXISTENTES
────────────────────────────────────────────
Items actuales en Koha para MED: 3205
⚠ Ya existen 3205 items de esta biblioteca
Se agregarán NUEVOS registros (no se duplicarán los existentes)

¿Desea continuar? (SI/no):
```

### Consulta Manual de Duplicados

```bash
# Ver items por biblioteca
sudo koha-mysql koha-cnc -e "
SELECT homebranch, COUNT(*) as items
FROM items
GROUP BY homebranch
ORDER BY items DESC"

# Ver items específicos de una biblioteca
sudo koha-mysql koha-cnc -e "
SELECT barcode, biblionumber
FROM items
WHERE homebranch = 'MED'
LIMIT 10"
```

---

## FILTRADO POR BIBLIOTECA

### Procesar Solo Una Biblioteca

```bash
# Solo procesar archivos de MED
./importar_automatico.sh --biblioteca MED

# Solo VET de un directorio específico
./importar_automatico.sh --dir /datos --biblioteca VET

# Vigilancia solo de ING
./importar_automatico.sh --watch --biblioteca ING
```

### Ver Estadísticas por Biblioteca

```bash
./importar_automatico.sh --stats
```

**Salida:**
```
╔════════════════════════════════════════════════════════════════════╗
║                    ESTADÍSTICAS DEL CATÁLOGO                       ║
╚════════════════════════════════════════════════════════════════════╝

Bibliotecas con items en Koha:

+--------+--------------------------------+-------+
| Código | Nombre                         | Items |
+--------+--------------------------------+-------+
| MED    | Fac. Ciencias Médicas          | 3847  |
| VET    | Fac. Ciencias Veterinarias     | 2156  |
| ING    | Fac. Ingeniería                | 1523  |
| FACAGR | Fac. Ciencias Agrarias         | 891   |
+--------+--------------------------------+-------+

Total general:
  Biblios:  8234
  Items:    8417
```

---

## LOGS Y REPORTES

### Logs Generados

Cada importación genera:

#### 1. **Log de Proceso** (`logs/importacion_*.log`)

Contiene traza completa de la ejecución:

```
[2025-10-24 14:30:25] INFO: Iniciando procesamiento: MED.csv
[2025-10-24 14:30:25] SUCCESS: ✓ Código detectado: MED
[2025-10-24 14:30:26] SUCCESS: ✓ Biblioteca: Facultad de Ciencias Médicas
[2025-10-24 14:30:27] SUCCESS: ✓ Total de registros: 3847
[2025-10-24 14:30:45] SUCCESS: ✓ Generados 1 archivo(s) XML con 3847 registros
...
```

#### 2. **Reporte Completo** (`logs/reporte_*.txt`)

Resumen ejecutivo de la importación:

```
═══════════════════════════════════════════════════════════════════════
REPORTE DE IMPORTACIÓN AUTOMÁTICA
═══════════════════════════════════════════════════════════════════════

INFORMACIÓN GENERAL
───────────────────
Fecha y hora:        2025-10-24 14:35:12
Código biblioteca:   MED
Nombre biblioteca:   Facultad de Ciencias Médicas

ARCHIVO CSV
───────────
Ruta original:       /home/mvillalba/migradatos/importar_aqui/MED.csv
Nombre archivo:      MED.csv
Total registros:     3847
Duplicados:          127
Corrección aplicada: Sí

GENERACIÓN MARCXML
──────────────────
Archivos generados:  1
Registros en XML:    3847
Validación XML:      Válido

IMPORTACIÓN KOHA
────────────────
Items antes:         0
Items después:       3847
Items importados:    3847
Estado importación:  1 exitosos, 0 fallidos

RESULTADO FINAL
───────────────
Estado:              EXITOSO
Tiempo total:        245 segundos

VERIFICACIÓN
────────────
URL OPAC: http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=MED
═══════════════════════════════════════════════════════════════════════
```

### Consultar Logs

```bash
# Ver últimos logs
ls -lht logs/ | head

# Ver log específico
cat logs/importacion_MED_20251024_143025.log

# Ver reporte específico
cat logs/reporte_MED_20251024_143025.txt

# Buscar errores en logs
grep ERROR logs/importacion_*.log
```

---

## SOLUCIÓN DE PROBLEMAS

### Errores Comunes

#### ❌ "No se detectó código de biblioteca"

**Causa:** Nombre de archivo sin código de 3-6 letras

**Solución:**
```bash
# Renombrar archivo
mv datos.csv MED_datos.csv
```

#### ❌ "La biblioteca 'XYZ' NO existe en Koha"

**Causa:** Biblioteca no creada en Koha

**Solución:**
1. Ir a Staff Interface
2. Administración → Bibliotecas
3. Nueva biblioteca
4. Código: XYZ (mismo del archivo)
5. Guardar

#### ❌ "Formato CSV inválido"

**Causa:** Faltan campos obligatorios o CSV corrupto

**Solución:**
```bash
# Verificar campos
head -1 archivo.csv

# Debe contener al menos: titulo,nroacceso
```

#### ❌ "Error generando MARCXML"

**Causa:** Script `opac_exportar.py` no encontrado o error en conversión

**Solución:**
```bash
# Verificar que existe
ls -l opac_exportar.py

# Probar manualmente
python3 opac_exportar.py -i test.csv --codbiblio MED --stream
```

#### ❌ "Timeout en importación"

**Causa:** Archivo muy grande

**Solución:**
1. Dividir CSV en archivos más pequeños
2. Aumentar timeout en configuración del agente

#### ❌ "Error de permisos"

**Causa:** Usuario sin permisos sudo

**Solución:**
```bash
# Agregar usuario a sudoers
sudo usermod -aG sudo $USER
```

### Verificaciones Diagnósticas

```bash
# 1. Verificar conexión a Koha
sudo koha-mysql koha-cnc -e "SELECT 1"

# 2. Verificar bibliotecas existentes
sudo koha-mysql koha-cnc -e "SELECT branchcode, branchname FROM branches"

# 3. Verificar items importados
sudo koha-mysql koha-cnc -e "SELECT homebranch, COUNT(*) FROM items GROUP BY homebranch"

# 4. Verificar permisos de archivos
ls -l agente_importador_v2.py importar_automatico.sh

# 5. Probar agente Python
./agente_importador_v2.py --help
```

---

## EJEMPLOS PRÁCTICOS

### Ejemplo 1: Importar Primera Biblioteca (MED)

```bash
# Paso 1: Preparar CSV
cd /home/mvillalba/migradatos
cp /datos_origen/medicina.csv importar_aqui/MED.csv

# Paso 2: Verificar que biblioteca existe en Koha
sudo koha-mysql koha-cnc -e "SELECT * FROM branches WHERE branchcode='MED'"

# Paso 3: Importar
./importar_automatico.sh

# Responder "SI" a las confirmaciones

# Paso 4: Verificar en OPAC
# http://servidor:8080/cgi-bin/koha/opac-search.pl?branch=MED
```

### Ejemplo 2: Importar Múltiples Bibliotecas

```bash
# Preparar archivos
cp /datos/medicina.csv importar_aqui/MED.csv
cp /datos/veterinaria.csv importar_aqui/VET.csv
cp /datos/ingenieria.csv importar_aqui/ING.csv

# Importar todas
./importar_automatico.sh

# O con el agente directamente
./agente_importador_v2.py importar_aqui/*.csv
```

### Ejemplo 3: Modo Vigilancia para Procesamiento Continuo

```bash
# Terminal 1: Iniciar vigilancia
cd /home/mvillalba/migradatos
./importar_automatico.sh --watch

# Terminal 2: Agregar archivos cuando estén listos
cp /datos/nuevos/POL.csv /home/mvillalba/migradatos/importar_aqui/

# Se procesará automáticamente en 10 segundos
```

### Ejemplo 4: Procesar Solo Una Biblioteca

```bash
# Solo procesar MED de directorio con múltiples archivos
./importar_automatico.sh --dir /datos/todos --biblioteca MED
```

### Ejemplo 5: Actualizar Biblioteca Existente (Agregar Más Registros)

```bash
# Situación: MED ya tiene 3000 items, queremos agregar 500 más

# Paso 1: Preparar CSV con nuevos 500 registros
cp /datos/med_adicionales.csv importar_aqui/MED_nuevos.csv

# Paso 2: Importar
./importar_automatico.sh

# El sistema detectará los 3000 items existentes
# Preguntará si deseas continuar
# Responder: SI

# Los 500 nuevos se agregarán SIN duplicar los 3000 existentes
```

---

## WORKFLOW DIARIO RECOMENDADO

### Para Administrador del Sistema

**Opción A: Procesamiento Manual**

```bash
# 1. Recibir CSV de bibliotecas
# 2. Colocar en importar_aqui/ con nombre correcto
# 3. Ejecutar una vez al día:
cd /home/mvillalba/migradatos
./importar_automatico.sh

# 4. Revisar logs
tail -f logs/importacion_*.log
```

**Opción B: Procesamiento Automático Continuo**

```bash
# 1. Iniciar vigilancia una vez (puede ser al boot)
cd /home/mvillalba/migradatos
nohup ./importar_automatico.sh --watch > vigilancia.log 2>&1 &

# 2. Solo colocar CSV cuando estén listos
# Se procesan automáticamente

# 3. Revisar logs periódicamente
tail -f vigilancia.log
```

### Para Encargados de Biblioteca

1. Exportar datos desde sistema anterior a CSV
2. Verificar que CSV tenga campos: `titulo`, `nroacceso`
3. Nombrar archivo con código de biblioteca (ej: MED.csv)
4. Enviar a administrador o colocar en carpeta compartida
5. Esperar confirmación de importación exitosa
6. Verificar registros en OPAC

---

## COMANDOS ÚTILES

### Gestión de Archivos

```bash
# Listar archivos pendientes
ls -lh importar_aqui/

# Listar procesados exitosos
ls -lht procesados/ | head

# Listar con errores
ls -lht errores/ | head

# Mover archivo a importar
cp /origen/archivo.csv importar_aqui/CODIGO.csv
```

### Verificación en Koha

```bash
# Ver todas las bibliotecas
sudo koha-mysql koha-cnc -e "SELECT branchcode, branchname FROM branches"

# Contar items por biblioteca
sudo koha-mysql koha-cnc -e "
SELECT homebranch, COUNT(*) as total
FROM items
GROUP BY homebranch
ORDER BY total DESC"

# Ver últimos items importados de una biblioteca
sudo koha-mysql koha-cnc -e "
SELECT barcode, biblionumber, dateaccessioned
FROM items
WHERE homebranch = 'MED'
ORDER BY dateaccessioned DESC
LIMIT 10"
```

### Logs y Monitoreo

```bash
# Ver log en tiempo real
tail -f logs/importacion_*.log

# Buscar errores
grep -i error logs/*.log

# Ver reportes generados hoy
ls -lh logs/reporte_*$(date +%Y%m%d)*.txt

# Resumen de procesamiento
grep "RESULTADO FINAL" logs/reporte_*.txt
```

---

## MANTENIMIENTO

### Limpieza Periódica

```bash
# Limpiar logs antiguos (más de 30 días)
find logs/ -name "*.log" -mtime +30 -delete

# Limpiar archivos procesados antiguos
find procesados/ -name "*.csv" -mtime +60 -delete

# Limpiar XMLs temporales
find exports/ -name "*.xml" -mtime +7 -delete
```

### Backup

```bash
# Backup de configuración y scripts
tar -czf backup_sistema_importacion_$(date +%Y%m%d).tar.gz \
  agente_importador_v2.py \
  importar_automatico.sh \
  opac_exportar.py \
  migracion_config.json

# Backup de logs y reportes importantes
tar -czf backup_logs_$(date +%Y%m%d).tar.gz logs/reporte_*.txt
```

---

## SOPORTE Y CONTACTO

### Documentación Adicional

- `README.md` - Visión general del proyecto
- `GUIA_RAPIDA.md` - Guía rápida de inicio
- `COMO_USAR_AUTO_IMPORTAR.txt` - Tutorial paso a paso

### Archivos de Configuración

- `migracion_config.json` - Configuración general

### Logs de Sistema

```bash
# Ver logs de Koha
sudo tail -f /var/log/koha/koha-cnc/opac-error.log
sudo tail -f /var/log/koha/koha-cnc/intranet-error.log
```

---

## CONCLUSIÓN

Este sistema de importación automática te permite:

✅ **Ahorro de tiempo:** Procesamiento desatendido
✅ **Seguridad:** Control de duplicados multinivel
✅ **Trazabilidad:** Logs completos de cada operación
✅ **Flexibilidad:** Modo manual, automático o vigilancia
✅ **Escalabilidad:** Procesa una o cientos de bibliotecas
✅ **Confiabilidad:** Validaciones en cada paso

**¡El sistema está listo para usar!** 🚀

---

**Universidad Nacional de Asunción**
**Sistema de Gestión Bibliográfica**
**Versión 2.0 - Octubre 2025**
