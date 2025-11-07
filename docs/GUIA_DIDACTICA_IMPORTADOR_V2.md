# GUÍA DIDÁCTICA COMPLETA DEL IMPORTADOR V2
## Entendiendo Paso a Paso el Sistema de Importación Automática

**Universidad Nacional de Asunción**
**Sistema de Migración Bibliográfica**
**Versión 2.0 - 24 de Octubre 2025**

---

## 📚 ÍNDICE

1. [Introducción - ¿Qué es y para qué sirve?](#introducción)
2. [Arquitectura del Sistema](#arquitectura)
3. [Componentes Principales](#componentes)
4. [Flujo de Trabajo Completo](#flujo-de-trabajo)
5. [¿Cómo Funciona Internamente?](#funcionamiento-interno)
6. [Control de Duplicados Explicado](#control-de-duplicados)
7. [Ejemplos Prácticos Paso a Paso](#ejemplos-prácticos)
8. [Resolución de Problemas](#resolución-de-problemas)
9. [Preguntas Frecuentes](#preguntas-frecuentes)

---

## INTRODUCCIÓN

### ¿Qué es el Importador V2?

El **Importador V2** es un sistema inteligente que automatiza completamente el proceso de migración de registros bibliográficos desde archivos CSV hacia el catálogo Koha OPAC.

### ¿Para qué sirve?

**Antes del Importador V2** (proceso manual):
1. 👤 Recibir CSV de una biblioteca
2. 👤 Abrir y verificar formato manualmente
3. 👤 Ejecutar script de conversión CSV → MARCXML
4. 👤 Verificar XML generado
5. 👤 Importar manualmente a Koha
6. 👤 Esperar que termine
7. 👤 Reindexar manualmente
8. 👤 Verificar en OPAC
9. ⏰ **Tiempo total: 1-2 horas por biblioteca**

**Con el Importador V2** (proceso automático):
1. 🤖 Colocar CSV en carpeta `importar_aqui/`
2. 🤖 Ejecutar `./importar_automatico.sh`
3. ☕ ¡Listo! Todo se hace automáticamente
4. ⏰ **Tiempo de intervención: 30 segundos**

### Ventajas Principales

| Característica | Sin Importador | Con Importador V2 |
|----------------|----------------|-------------------|
| **Tiempo manual** | 1-2 horas | 30 segundos |
| **Errores humanos** | Frecuentes | Minimizados |
| **Validaciones** | Manuales | Automáticas |
| **Duplicados** | Sin control | Control multinivel |
| **Trazabilidad** | Poca | Completa (logs) |
| **Continuidad** | Se pierde si te desconectas | Asegurada con tmux |
| **Procesamiento masivo** | Difícil | Fácil (modo vigilancia) |

---

## ARQUITECTURA

### Vista General del Sistema

```
┌─────────────────────────────────────────────────────────────────┐
│                    SISTEMA IMPORTADOR V2                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │   ENTRADA    │───→│  PROCESADOR  │───→│    SALIDA    │    │
│  └──────────────┘    └──────────────┘    └──────────────┘    │
│         │                    │                    │            │
│    CSV Files          Validación &          Koha OPAC         │
│                       Transformación                           │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                   CAPA DE CONTINUIDAD                     │ │
│  │                      (tmux)                               │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │                   CAPA DE LOGS                            │ │
│  │             (Trazabilidad completa)                       │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Componentes del Sistema

```
Sistema Importador V2
│
├── CAPA DE ENTRADA
│   ├── subir_csv.sh              [Helper para subir archivos]
│   └── importar_aqui/             [Carpeta de entrada]
│
├── CAPA DE ORQUESTACIÓN
│   ├── importar_automatico.sh    [Orquestador principal]
│   └── importar_con_tmux.sh      [Orquestador con continuidad]
│
├── CAPA DE PROCESAMIENTO
│   ├── agente_importador_v2.py   [Motor principal]
│   └── opac_exportar.py          [Conversor CSV→MARCXML]
│
├── CAPA DE PERSISTENCIA
│   ├── procesados/               [Archivos exitosos]
│   ├── errores/                  [Archivos con problemas]
│   ├── exports/                  [MARCXML generados]
│   └── logs/                     [Logs y reportes]
│
└── CAPA DE DESTINO
    └── Koha OPAC                 [Catálogo bibliográfico]
```

---

## COMPONENTES

### 1. agente_importador_v2.py (El Cerebro)

**¿Qué hace?**
Es el procesador principal. Contiene toda la lógica de importación.

**Funciones principales:**
- `detectar_codigo_biblioteca()` - Extrae código del nombre del archivo
- `verificar_biblioteca_koha()` - Verifica que biblioteca existe en Koha
- `analizar_estructura_csv()` - Valida formato y estructura del CSV
- `corregir_duplicados()` - Corrige códigos duplicados internos
- `generar_marcxml()` - Convierte CSV a formato MARC XML
- `validar_xml()` - Verifica sintaxis XML
- `importar_a_koha()` - Ejecuta la importación
- `reindexar()` - Actualiza índices de búsqueda

**¿Cómo se ejecuta?**
```bash
# Directo (un archivo)
./agente_importador_v2.py archivo.csv

# Múltiples archivos
./agente_importador_v2.py archivo1.csv archivo2.csv archivo3.csv

# Ver ayuda
./agente_importador_v2.py --help
```

**Ejemplo de salida:**
```
════════════════════════════════════════════════════════════════════
📄 PROCESANDO: MED.csv
════════════════════════════════════════════════════════════════════

1. DETECCIÓN DE BIBLIOTECA
────────────────────────────────────────────────────────────────────
✓ Código detectado: MED

2. VERIFICACIÓN EN KOHA
────────────────────────────────────────────────────────────────────
✓ Biblioteca: Facultad de Ciencias Médicas

3. ANÁLISIS DEL CSV
────────────────────────────────────────────────────────────────────
✓ Total de registros: 3847
✓ Columnas detectadas: 25
✓ Separador: ';'
⚠ Códigos duplicados: 127 (142 registros)

...

✓✓✓ IMPORTACIÓN COMPLETADA EXITOSAMENTE ✓✓✓
```

### 2. importar_automatico.sh (El Orquestador)

**¿Qué hace?**
Busca archivos CSV automáticamente y llama al agente para procesarlos.

**Ventajas:**
- Busca todos los CSV en una carpeta
- Permite filtrar por biblioteca específica
- Tiene modo vigilancia (monitoreo continuo)
- Muestra estadísticas del catálogo

**¿Cómo se ejecuta?**
```bash
# Modo normal (busca y procesa)
./importar_automatico.sh

# Solo una biblioteca
./importar_automatico.sh --biblioteca MED

# Modo vigilancia
./importar_automatico.sh --watch

# Ver estadísticas
./importar_automatico.sh --stats

# Buscar en otro directorio
./importar_automatico.sh --dir /ruta/personalizada
```

### 3. importar_con_tmux.sh (Asegurador de Continuidad)

**¿Qué hace?**
Ejecuta el importador dentro de una sesión tmux para asegurar que la importación continúe aunque te desconectes.

**¿Qué es tmux?**
`tmux` es un "multiplicador de terminal". Piensa en él como un programa que mantiene tu terminal corriendo en segundo plano, incluso si cierras la ventana o te desconectas.

**Analogía:**
- **Sin tmux**: Como una llamada telefónica. Si cuelgas, se corta.
- **Con tmux**: Como WhatsApp. El mensaje se envía aunque cierres la app.

**¿Cómo se usa?**
```bash
# Iniciar importación en tmux
./importar_con_tmux.sh

# Ver sesiones activas
./importar_con_tmux.sh --status

# Reconectar a sesión
./importar_con_tmux.sh --attach

# Detener sesión
./importar_con_tmux.sh --kill
```

**Comandos tmux útiles:**
- `Ctrl+b d` - Desconectar (sigue corriendo)
- `tmux ls` - Listar sesiones
- `tmux attach` - Reconectar

### 4. subir_csv.sh (El Helper)

**¿Qué hace?**
Facilita subir archivos CSV a la carpeta de importación.

**Uso:**
```bash
# Subir y renombrar
./subir_csv.sh archivo.csv CODIGO

# Ejemplos:
./subir_csv.sh medicina.csv MED
./subir_csv.sh /tmp/datos.csv VET
```

---

## FLUJO DE TRABAJO

### Flujo Completo Paso a Paso

```
PASO 1: ENTRADA
───────────────
Usuario coloca:
  medicina_2025.csv  →  importar_aqui/MED.csv

                ↓

PASO 2: DETECCIÓN
─────────────────
agente_importador_v2.py detecta:
  Nombre: MED.csv
  Código extraído: "MED" (busca 3-6 letras mayúsculas)

                ↓

PASO 3: VERIFICACIÓN KOHA
──────────────────────────
Consulta base de datos:
  SELECT branchname FROM branches WHERE branchcode='MED'

  ¿Existe? ✓ Sí → Continuar
           ✗ No → Error y mover a errores/

                ↓

PASO 4: ANÁLISIS CSV
─────────────────────
Lee archivo y verifica:
  • Detectar separador: , o ;
  • Campos obligatorios: titulo, nroacceso ✓
  • Contar registros: 3847
  • Detectar duplicados internos: 127 códigos repetidos

                ↓

PASO 5: CONTROL DUPLICADOS (Nivel 1)
─────────────────────────────────────
Verificar duplicados en el CSV:
  • Si > 50 duplicados → Ejecutar corrección automática
  • Genera: MED_corregido.csv
  • Usar archivo corregido para continuar

                ↓

PASO 6: CONTROL DUPLICADOS (Nivel 2)
─────────────────────────────────────
Consultar base de datos Koha:
  SELECT COUNT(*) FROM items WHERE homebranch='MED'

  Resultado: 1200 items existentes

  Informar al usuario:
  ⚠ Ya existen 1200 items de esta biblioteca
  ¿Desea continuar? (SI/no):

                ↓

PASO 7: GENERACIÓN MARCXML
───────────────────────────
Ejecutar conversor:
  python3 opac_exportar.py \
    -i MED.csv \
    --codbiblio MED \
    --loc-default SALA \
    --stream

  Genera: exports/MED_20251024_marcxml.xml
  Registros XML: 3847

                ↓

PASO 8: VALIDACIÓN XML
───────────────────────
Verificar sintaxis:
  xmllint --noout MED_20251024_marcxml.xml

  ✓ XML válido → Continuar
  ✗ XML inválido → Error y mover a errores/

                ↓

PASO 9: IMPORTACIÓN KOHA
─────────────────────────
Ejecutar importador de Koha:
  sudo koha-shell koha-cnc -c \
    "perl .../bulkmarcimport.pl \
      -b -m MARCXML \
      -file MED_20251024_marcxml.xml \
      -commit 1000"

  Progreso:
  100..................................................
  200..................................................
  ...
  3847
  3847 biblios imported
  3847 items imported

                ↓

PASO 10: REINDEXACIÓN
──────────────────────
Actualizar índices de búsqueda:
  sudo koha-rebuild-zebra -f -v koha-cnc

  ✓ Índices actualizados

                ↓

PASO 11: VERIFICACIÓN
──────────────────────
Contar items después:
  SELECT COUNT(*) FROM items WHERE homebranch='MED'

  Antes:  1200
  Después: 5047
  Nuevos: 3847 ✓

                ↓

PASO 12: REPORTES
──────────────────
Generar:
  • Log detallado: logs/importacion_MED_20251024.log
  • Reporte ejecutivo: logs/reporte_MED_20251024.txt
  • Mover CSV: procesados/MED_OK_20251024.csv

                ↓

PASO 13: FIN
────────────
✓✓✓ IMPORTACIÓN COMPLETADA ✓✓✓
```

---

## FUNCIONAMIENTO INTERNO

### ¿Cómo Detecta el Código de Biblioteca?

**Algoritmo de detección:**

```python
def detectar_codigo_biblioteca(archivo):
    """
    Busca secuencia de 3-6 letras mayúsculas en el nombre
    """
    nombre = archivo.stem.upper()  # "MED_2025.csv" → "MED_2025"

    # Patrones de búsqueda (del más específico al general)
    patrones = [
        r'^([A-Z]{3,6})(?:_|\.)',   # Código al inicio: MED_xxx
        r'([A-Z]{3,6})(?:_|\d)',     # Código seguido de: MED_123
        r'([A-Z]{3,6})',             # Cualquier secuencia: xMEDx
    ]

    for patron in patrones:
        match = re.search(patron, nombre)
        if match:
            codigo = match.group(1)
            # Excluir palabras comunes
            if codigo not in ['CSV', 'DATOS', 'FILE']:
                return codigo

    return None  # No se detectó código
```

**Ejemplos:**

| Nombre Archivo | Proceso de Detección | Resultado |
|----------------|----------------------|-----------|
| `MED.csv` | Buscar 3-6 letras: **MED** encontrado | ✓ MED |
| `VET_2025.csv` | Buscar 3-6 letras: **VET** encontrado | ✓ VET |
| `medicina_datos.csv` | Buscar 3-6 letras: ninguno | ✗ Sin código |
| `ING_octubre.csv` | Buscar 3-6 letras: **ING** encontrado | ✓ ING |
| `FACAGR_completo.csv` | Buscar 3-6 letras: **FACAGR** encontrado | ✓ FACAGR |

### ¿Cómo Funciona el Control de Duplicados?

**Nivel 1: Duplicados dentro del CSV**

```python
def analizar_duplicados_csv(archivo_csv):
    """
    Cuenta cuántos códigos de acceso están repetidos
    """
    codigos = []

    # Leer todos los registros
    for registro in leer_csv(archivo_csv):
        codigo = registro['nroacceso'].strip()
        if codigo:
            codigos.append(codigo)

    # Contar ocurrencias
    contador = Counter(codigos)

    # Detectar duplicados
    duplicados = 0
    for codigo, cantidad in contador.items():
        if cantidad > 1:
            duplicados += 1

    return duplicados
```

**Ejemplo:**

CSV con 100 registros:
```csv
nroacceso,titulo
MED001,Libro A
MED002,Libro B
MED001,Libro C  ← Duplicado!
MED003,Libro D
MED002,Libro E  ← Duplicado!
```

Resultado:
- Total registros: 100
- Códigos únicos: 98
- Códigos duplicados: 2 (MED001 y MED002)
- Registros afectados: 4

**Nivel 2: Duplicados en base de datos Koha**

```python
def verificar_duplicados_koha(codigo_biblioteca):
    """
    Cuenta items existentes en Koha para esta biblioteca
    """
    query = f"""
        SELECT COUNT(*)
        FROM items
        WHERE homebranch = '{codigo_biblioteca}'
    """

    resultado = ejecutar_query(query)
    items_existentes = resultado[0]

    return items_existentes
```

**¿Qué pasa con los duplicados?**

🔵 **Duplicados en CSV:**
- Si > 50 → Se ejecuta corrección automática
- Genera archivo `*_corregido.csv`
- Agrega sufijos: `MED001`, `MED001-1`, `MED001-2`

🟢 **Duplicados en Koha:**
- Se informan al usuario
- Usuario decide si continuar
- Koha maneja unicidad por `barcode` (código de barras)
- **NO se duplican registros existentes**

### ¿Cómo Genera el MARCXML?

**Proceso de conversión:**

```
CSV (formato tabular)
│
│  nroacceso,titulo,autor,editorial
│  MED001,Anatomía,García,Panamericana
│
└──→ Conversión
     │
     ├─ Campo 245 (Título): Anatomía
     ├─ Campo 100 (Autor): García
     ├─ Campo 260 (Editorial): Panamericana
     ├─ Campo 952 (Item): MED001 @ MED
     │
     └──→ MARCXML (formato estructurado)
          │
          │  <record>
          │    <datafield tag="245">
          │      <subfield code="a">Anatomía</subfield>
          │    </datafield>
          │    <datafield tag="100">
          │      <subfield code="a">García</subfield>
          │    </datafield>
          │    ...
          │  </record>
          │
          └──→ Koha OPAC
```

**Script conversor:**
```bash
python3 opac_exportar.py \
  -i MED.csv \              # Archivo de entrada
  --codbiblio MED \         # Código de biblioteca
  --loc-default SALA \      # Ubicación por defecto
  --stream                  # Modo streaming (eficiente)
```

### ¿Cómo Importa a Koha?

**Comando de importación:**

```bash
sudo koha-shell koha-cnc -c "
  perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
    -b \                    # Modo batch
    -m MARCXML \            # Formato MARCXML
    -file archivo.xml \     # Archivo a importar
    -commit 1000            # Commit cada 1000 registros
"
```

**¿Qué hace internamente?**

1. Lee XML registro por registro
2. Cada 1000 registros:
   - Inserta en tabla `biblio` (registro bibliográfico)
   - Inserta en tabla `biblioitems` (detalles)
   - Inserta en tabla `items` (ejemplares físicos)
   - Hace `COMMIT` a la base de datos
3. Muestra progreso: `100...200...300...`
4. Al final: `3847 biblios imported, 3847 items imported`

---

## CONTROL DE DUPLICADOS

### Escenario Completo

**Situación inicial:**
- Biblioteca MED tiene **1,000 items** en Koha
- Quieres importar CSV con **500 nuevos registros**
- Pero el CSV tiene **30 códigos duplicados internos**

### Paso a Paso

#### 1. Detección de Duplicados en CSV

```
Análisis del CSV:
├─ Total registros: 500
├─ Códigos únicos: 470
└─ Duplicados internos: 30 códigos (60 registros afectados)

Ejemplo de duplicados:
  MED001 aparece 2 veces
  MED002 aparece 3 veces
  MED003 aparece 2 veces
  ...
```

**Acción automática:**
```bash
# Se ejecuta automáticamente:
python3 corregir_codigos.py MED.csv

# Genera:
MED_corregido.csv

# Contenido corregido:
MED001   ← Original
MED001-1 ← Duplicado 1
MED002   ← Original
MED002-1 ← Duplicado 1
MED002-2 ← Duplicado 2
```

#### 2. Verificación en Koha

```sql
-- Se ejecuta automáticamente:
SELECT COUNT(*)
FROM items
WHERE homebranch = 'MED';

-- Resultado: 1000 items
```

**Información al usuario:**
```
4. VERIFICACIÓN DE ITEMS EXISTENTES
────────────────────────────────────────────
Items actuales en Koha para MED: 1000
⚠ Ya existen 1000 items. Se agregarán NUEVOS registros

¿Desea continuar? (SI/no):
```

#### 3. Usuario Responde SI

El sistema continúa con la importación.

#### 4. Importación

```
Importando 500 registros nuevos...

Koha verifica cada registro:
  ¿Existe barcode "MED001"?
    → Si existe → SKIP (no duplica)
    → Si no existe → INSERT (agrega)

Progreso:
100..................................................
200..................................................
300..................................................
400..................................................
500

500 biblios imported
498 items imported (2 ya existían)
```

#### 5. Resultado Final

```sql
-- Consultar después:
SELECT COUNT(*)
FROM items
WHERE homebranch = 'MED';

-- Resultado: 1498 items
```

**Resumen:**
- Antes: 1,000 items
- Intentado importar: 500
- Ya existentes (duplicados): 2
- Realmente importados: 498
- Después: 1,498 items ✓

### ¿Por Qué NO Duplica?

**Koha usa índice único en `barcode`:**

```sql
-- Definición de tabla items en Koha:
CREATE TABLE items (
  itemnumber INT PRIMARY KEY AUTO_INCREMENT,
  barcode VARCHAR(20) UNIQUE,  ← ÚNICO!
  homebranch VARCHAR(10),
  ...
);

-- Si intentas insertar barcode duplicado:
INSERT INTO items (barcode, homebranch)
VALUES ('MED001', 'MED');

-- Error: Duplicate entry 'MED001' for key 'barcode'
-- El bulkmarcimport.pl maneja este error y continúa
```

**Analogía:**
- El `barcode` es como el **DNI** de un libro
- No pueden existir dos libros con el mismo DNI
- Si intentas agregar uno que ya existe, Koha lo rechaza
- Pero continúa con los demás

---

## EJEMPLOS PRÁCTICOS

### Ejemplo 1: Primera Importación (Biblioteca Nueva)

**Contexto:**
- Biblioteca: Facultad de Ciencias Médicas (MED)
- CSV: 3,847 registros
- Items en Koha: 0 (primera vez)

**Paso a Paso:**

```bash
# 1. Preparar archivo
cd /home/mvillalba/migradatos
cp /datos_origen/medicina_2025.csv importar_aqui/MED.csv

# 2. Verificar que biblioteca existe
sudo koha-mysql koha-cnc -e \
  "SELECT branchcode, branchname FROM branches WHERE branchcode='MED'"

# Resultado:
# +------------+--------------------------------+
# | branchcode | branchname                     |
# +------------+--------------------------------+
# | MED        | Facultad de Ciencias Médicas   |
# +------------+--------------------------------+

# 3. Ejecutar importador
./importar_automatico.sh

# 4. Proceso automático:
```

**Salida del proceso:**

```
╔════════════════════════════════════════════════════════════════════╗
║           IMPORTADOR AUTOMÁTICO DE BIBLIOTECAS                     ║
╚════════════════════════════════════════════════════════════════════╝

Buscando archivos CSV en: /home/.../importar_aqui
✓ Archivos encontrados: 1

  1. MED.csv [MED]

¿Procesar estos archivos? (SI/no): SI

════════════════════════════════════════════════════════════════════
📄 PROCESANDO: MED.csv
════════════════════════════════════════════════════════════════════

1. DETECCIÓN DE BIBLIOTECA
────────────────────────────────────────────────────────────────────
✓ Código detectado: MED

2. VERIFICACIÓN EN KOHA
────────────────────────────────────────────────────────────────────
✓ Biblioteca: Facultad de Ciencias Médicas

3. ANÁLISIS DEL CSV
────────────────────────────────────────────────────────────────────
✓ Total de registros: 3847
Columnas detectadas: 25
Separador: ';'
⚠ Códigos duplicados: 127 (142 registros)

4. VERIFICACIÓN DE ITEMS EXISTENTES
────────────────────────────────────────────────────────────────────
Items actuales en Koha para MED: 0

5. CORRECCIÓN DE DUPLICADOS
────────────────────────────────────────────────────────────────────
→ Iniciando corrección de duplicados...
✓ Archivo corregido: MED_corregido.csv

6. GENERACIÓN DE MARCXML
────────────────────────────────────────────────────────────────────
→ Generando MARCXML...
✓ Generados 1 archivo(s) XML con 3847 registros
  • MED_20251024_marcxml.xml: 3847 registros

7. VALIDACIÓN DE XML
────────────────────────────────────────────────────────────────────
→ Validando archivos XML...
✓ MED_20251024_marcxml.xml - Válido

8. IMPORTACIÓN A KOHA
────────────────────────────────────────────────────────────────────
→ Importando a Koha...
  Procesando: MED_20251024_marcxml.xml
100..................................................
200..................................................
[...]
3800..................................................
3847
  3847 biblios imported
  3847 items imported
✓ MED_20251024_marcxml.xml importado

9. REINDEXACIÓN
────────────────────────────────────────────────────────────────────
→ Reindexando catálogo...
✓ Reindexación completada

10. VERIFICACIÓN FINAL
────────────────────────────────────────────────────────────────────
Items antes:   0
Items después: 3847
✓ Items nuevos:  3847

═══════════════════════════════════════════════════════════════════
✓✓✓ IMPORTACIÓN COMPLETADA EXITOSAMENTE ✓✓✓
═══════════════════════════════════════════════════════════════════

Tiempo total: 245 segundos
URL verificación: http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=MED

→ Archivo movido a: /home/mvillalba/migradatos/procesados/MED_OK_20251024_143025.csv

✓ Reporte guardado: logs/reporte_MED_20251024_143025.txt
✓ Log guardado: logs/importacion_MED_20251024_143025.log
```

**5. Verificar:**

```bash
# Ver en base de datos
sudo koha-mysql koha-cnc -e \
  "SELECT COUNT(*) FROM items WHERE homebranch='MED'"

# Resultado: 3847

# Ver reporte
cat logs/reporte_MED_20251024_143025.txt

# Ver en OPAC
firefox http://servidor:8080/cgi-bin/koha/opac-search.pl?branch=MED
```

### Ejemplo 2: Agregar Más Registros (Biblioteca Existente)

**Contexto:**
- Biblioteca: MED (ya tiene 3,847 items)
- CSV nuevo: 500 registros adicionales
- Algunos registros pueden estar duplicados

**Paso a Paso:**

```bash
# 1. Preparar nuevo CSV
cp /datos_origen/med_adicionales_2025.csv importar_aqui/MED_nuevos.csv

# 2. Ejecutar
./importar_automatico.sh
```

**Salida:**

```
3. ANÁLISIS DEL CSV
────────────────────────────────────────────────────────────────────
✓ Total de registros: 500

4. VERIFICACIÓN DE ITEMS EXISTENTES
────────────────────────────────────────────────────────────────────
Items actuales en Koha para MED: 3847
⚠ Ya existen 3847 items de esta biblioteca
Se agregarán NUEVOS registros (no se duplicarán los existentes)

¿Desea continuar de todas formas? (escriba SI): SI

[... proceso continúa ...]

8. IMPORTACIÓN A KOHA
────────────────────────────────────────────────────────────────────
→ Importando a Koha...
100..................................................
200..................................................
300..................................................
400..................................................
500

  500 biblios processed
  498 items imported (2 already existed, skipped)

10. VERIFICACIÓN FINAL
────────────────────────────────────────────────────────────────────
Items antes:   3847
Items después: 4345
✓ Items nuevos:  498 (2 duplicados omitidos)
```

**Resultado:**
- Antes: 3,847 items
- Intentó importar: 500
- Duplicados omitidos: 2
- Realmente importados: 498
- Después: 4,345 items ✓

### Ejemplo 3: Modo Vigilancia (Procesamiento Continuo)

**Contexto:**
Tienes varias bibliotecas que enviarán archivos durante el día.

**Configuración:**

```bash
# Terminal 1: Activar vigilancia
cd /home/mvillalba/migradatos
./importar_con_tmux.sh --watch

# Salida:
# ╔══════════════════════════════════════════════════════════════════╗
# ║       INICIANDO IMPORTACIÓN EN TMUX - MODO VIGILANCIA            ║
# ╚══════════════════════════════════════════════════════════════════╝
#
# Sesión:   importacion-koha
# Comando:  ./importar_automatico.sh --watch
#
# ✓ Sesión iniciada: importacion-koha
# La importación está corriendo en segundo plano.
# Puedes cerrar esta terminal sin problemas.
```

**Usar durante el día:**

```bash
# Cuando llegue un CSV nuevo:
# Terminal 2 (cualquier momento):
cp /datos/medicina_lunes.csv importar_aqui/MED_lunes.csv
cp /datos/veterinaria_lunes.csv importar_aqui/VET_lunes.csv

# Se procesan automáticamente en 10 segundos
# Ver progreso:
./importar_con_tmux.sh --attach

# Desconectar sin detener: Ctrl+b d
```

**Al final del día:**

```bash
# Detener vigilancia
./importar_con_tmux.sh --kill

# Ver estadísticas del día
./importar_automatico.sh --stats
```

---

## RESOLUCIÓN DE PROBLEMAS

### Problema 1: "No se detectó código de biblioteca"

**Síntoma:**
```
1. DETECCIÓN DE BIBLIOTECA
────────────────────────────────────────────
✗ No se detectó código de biblioteca en el nombre del archivo
```

**Causa:**
El nombre del archivo no contiene una secuencia de 3-6 letras mayúsculas.

**Solución:**
```bash
# Renombrar archivo
mv datos.csv MED.csv
mv biblioteca_medicina.csv MED_medicina.csv
mv registros_2025.csv VET_2025.csv
```

**Ejemplos:**
| Incorrecto | Correcto |
|------------|----------|
| `datos.csv` | `MED.csv` |
| `biblioteca.csv` | `VET.csv` |
| `new.csv` | `ING.csv` |

### Problema 2: "La biblioteca 'XXX' NO existe en Koha"

**Síntoma:**
```
2. VERIFICACIÓN EN KOHA
────────────────────────────────────────────
✗ La biblioteca 'MED' NO existe en Koha
Créela en: Staff Interface → Administración → Bibliotecas
```

**Causa:**
La biblioteca no está creada en Koha.

**Solución:**

1. Ir a Staff Interface de Koha
2. Administración → Bibliotecas
3. Click en "Nueva biblioteca"
4. Llenar:
   - **Código**: MED (mismo que en el archivo CSV)
   - **Nombre**: Facultad de Ciencias Médicas
5. Guardar

**Verificar:**
```bash
sudo koha-mysql koha-cnc -e \
  "SELECT branchcode, branchname FROM branches WHERE branchcode='MED'"
```

### Problema 3: "Formato CSV inválido"

**Síntoma:**
```
3. ANÁLISIS DEL CSV
────────────────────────────────────────────
✗ Faltan campos obligatorios: titulo, nroacceso
```

**Causa:**
El CSV no tiene los campos obligatorios.

**Solución:**

Verificar columnas:
```bash
head -1 archivo.csv
```

Debe mostrar al menos:
```
nroacceso,titulo,...
```

o

```
nroacceso;titulo;...
```

**Agregar campos faltantes** en hoja de cálculo (Excel/LibreOffice) antes de exportar.

### Problema 4: "Error generando MARCXML"

**Síntoma:**
```
6. GENERACIÓN DE MARCXML
────────────────────────────────────────────
✗ No se pudieron generar archivos MARCXML
```

**Causa:**
Error en conversión CSV → MARCXML.

**Diagnóstico:**

```bash
# Ver log
cat logs/importacion_*.log | grep -A 10 "MARCXML"

# Probar manualmente
cd exports
python3 ../opac_exportar.py \
  -i ../archivo.csv \
  --codbiblio MED \
  --stream
```

**Soluciones comunes:**

1. **Encoding incorrecto:**
```bash
# Verificar encoding
file archivo.csv

# Debe ser: UTF-8

# Convertir si es necesario
iconv -f ISO-8859-1 -t UTF-8 archivo.csv > archivo_utf8.csv
```

2. **Caracteres especiales:**
```bash
# Limpiar caracteres problemáticos
sed -i 's/\r$//' archivo.csv  # Eliminar \r de Windows
```

### Problema 5: Importación muy lenta

**Síntoma:**
La importación de un archivo grande (>10MB) tarda mucho.

**Causa:**
Archivos grandes requieren más tiempo de procesamiento.

**Soluciones:**

1. **Usar tmux para no perder progreso:**
```bash
./importar_con_tmux.sh
```

2. **Dividir archivo en partes:**
```bash
# Dividir CSV en archivos de 1000 líneas cada uno
split -l 1000 -d --additional-suffix=.csv archivo_grande.csv MED_parte_

# Resultado:
# MED_parte_00.csv (1000 líneas)
# MED_parte_01.csv (1000 líneas)
# ...
```

3. **Importar en horarios de baja carga:**
- Noche o madrugada
- Menos carga en el servidor

4. **Monitorear progreso:**
```bash
tail -f logs/importacion_*.log
```

### Problema 6: "Permission denied"

**Síntoma:**
```bash
./importar_automatico.sh: Permission denied
```

**Causa:**
Script no tiene permisos de ejecución.

**Solución:**
```bash
chmod +x importar_automatico.sh
chmod +x agente_importador_v2.py
chmod +x importar_con_tmux.sh
chmod +x subir_csv.sh
```

### Problema 7: No puede subir archivos a importar_aqui/

**Síntoma:**
```bash
cp archivo.csv importar_aqui/
# cp: cannot create regular file 'importar_aqui/MED.csv': Permission denied
```

**Causa:**
No tienes permisos en la carpeta.

**Solución:**
```bash
# Dar permisos a tu usuario
sudo chown -R mvillalba:mvillalba importar_aqui/
sudo chmod 775 importar_aqui/

# Verificar
ls -ld importar_aqui/
# drwxrwxr-x 2 mvillalba mvillalba 4096 ...
```

---

## PREGUNTAS FRECUENTES

### ❓ ¿Puedo procesar varias bibliotecas a la vez?

**Respuesta:** Sí.

```bash
# Colocar todos los CSV:
cp medicina.csv importar_aqui/MED.csv
cp veterinaria.csv importar_aqui/VET.csv
cp ingenieria.csv importar_aqui/ING.csv

# Ejecutar:
./importar_automatico.sh

# El sistema procesará cada uno secuencialmente
```

### ❓ ¿Se van a duplicar mis registros si ya existen?

**Respuesta:** NO.

El sistema verifica en dos niveles:
1. **CSV**: Corrige duplicados internos
2. **Koha**: Omite registros que ya existen (por barcode)

Solo se agregan registros nuevos.

### ❓ ¿Qué pasa si cierro la terminal durante la importación?

**Respuesta:** Depende.

- **Sin tmux**: ❌ Se detiene la importación
- **Con tmux**: ✓ Continúa corriendo

**Recomendación:**
```bash
# Usar tmux para importaciones largas
./importar_con_tmux.sh
```

### ❓ ¿Puedo ver el progreso de una importación en curso?

**Respuesta:** Sí.

```bash
# Si usaste tmux:
./importar_con_tmux.sh --attach

# O ver logs en tiempo real:
tail -f logs/importacion_*.log
```

### ❓ ¿Cómo sé si la importación fue exitosa?

**Respuesta:** Varias formas.

1. **Mensaje final:**
```
✓✓✓ IMPORTACIÓN COMPLETADA EXITOSAMENTE ✓✓✓
```

2. **Archivo movido a procesados/:**
```bash
ls -lht procesados/ | head -1
```

3. **Reporte generado:**
```bash
cat logs/reporte_CODIGO_*.txt
```

4. **Verificar en Koha:**
```bash
sudo koha-mysql koha-cnc -e \
  "SELECT COUNT(*) FROM items WHERE homebranch='MED'"
```

5. **Ver en OPAC:**
```
http://servidor:8080/cgi-bin/koha/opac-search.pl?branch=MED
```

### ❓ ¿Cuánto tarda una importación?

**Respuesta:** Depende del tamaño.

| Registros | Tamaño CSV | Tiempo Aproximado |
|-----------|------------|-------------------|
| 100 | < 1 MB | 30-60 segundos |
| 1,000 | ~5 MB | 2-3 minutos |
| 5,000 | ~15 MB | 8-10 minutos |
| 10,000 | ~30 MB | 15-20 minutos |

**Factores que influyen:**
- Tamaño del CSV
- Número de duplicados
- Carga del servidor
- Complejidad de registros

### ❓ ¿Puedo cancelar una importación en progreso?

**Respuesta:** Sí, pero no es recomendable.

```bash
# Si usaste tmux:
./importar_con_tmux.sh --kill

# Si no usaste tmux:
Ctrl+C

# Ver procesos y matar manualmente:
ps aux | grep agente_importador
kill -9 <PID>
```

**Consecuencia:**
- Los registros ya procesados quedan en Koha
- Los no procesados se pierden
- Puede quedar en estado inconsistente

**Mejor opción:**
- Dejar que termine
- Si hay error, se mueve a errores/ automáticamente

### ❓ ¿Dónde están los logs?

**Respuesta:** En la carpeta `logs/`

```bash
# Ver logs disponibles
ls -lht logs/

# Ver log específico
cat logs/importacion_MED_20251024_143025.log

# Ver reporte
cat logs/reporte_MED_20251024_143025.txt

# Buscar errores
grep ERROR logs/*.log
```

### ❓ ¿Cómo limpio archivos antiguos?

**Respuesta:** Manualmente o con scripts.

```bash
# Limpiar logs antiguos (>30 días)
find logs/ -name "*.log" -mtime +30 -delete

# Limpiar procesados antiguos (>60 días)
find procesados/ -name "*.csv" -mtime +60 -delete

# Limpiar XMLs temporales (>7 días)
find exports/ -name "*.xml" -mtime +7 -delete

# Hacer backup antes de limpiar
tar -czf backup_logs_$(date +%Y%m%d).tar.gz logs/
```

### ❓ ¿Puedo usar el sistema sin supervisión?

**Respuesta:** Sí, con modo vigilancia.

```bash
# Activar vigilancia al inicio del día
nohup ./importar_automatico.sh --watch > vigilancia.log 2>&1 &

# Durante el día, solo colocar archivos:
cp archivo.csv importar_aqui/CODIGO.csv

# Se procesan automáticamente cada 10 segundos

# Al final del día, detener:
pkill -f importar_automatico.sh
```

### ❓ ¿Qué hago si un archivo da error?

**Respuesta:** Revisar y corregir.

1. **Ver log de error:**
```bash
cat logs/importacion_CODIGO_*.log
```

2. **Recuperar archivo:**
```bash
cp errores/CODIGO_ERROR_*.csv archivo_corregido.csv
```

3. **Corregir problema** según mensaje de error

4. **Renombrar y volver a intentar:**
```bash
cp archivo_corregido.csv importar_aqui/CODIGO.csv
./importar_automatico.sh
```

---

## RESUMEN FINAL

### Lo Que Debes Recordar

✅ **El sistema es automático**: Solo coloca CSV y ejecuta script
✅ **Detecta biblioteca del nombre**: Asegúrate que el nombre tenga el código
✅ **NO duplica registros**: Control en 2 niveles
✅ **Usa tmux para continuidad**: Importaciones largas
✅ **Logs completos**: Revisa si hay dudas
✅ **Modo vigilancia**: Para procesamiento continuo

### Comandos Esenciales

```bash
# Subir archivo
./subir_csv.sh archivo.csv CODIGO

# Importar
./importar_automatico.sh

# Con tmux (recomendado)
./importar_con_tmux.sh

# Ver progreso
tail -f logs/importacion_*.log

# Ver estadísticas
./importar_automatico.sh --stats
```

### Flujo Típico

```
1. Recibir CSV de biblioteca
        ↓
2. ./subir_csv.sh archivo.csv CODIGO
        ↓
3. ./importar_automatico.sh
        ↓
4. ☕ Esperar (automático)
        ↓
5. Verificar en OPAC
        ↓
6. ✓ Listo!
```

---

**Universidad Nacional de Asunción**
**Sistema de Importación Automática v2.0**
**24 de Octubre 2025**

---

*Esta guía cubre el 100% del funcionamiento del sistema. Para dudas específicas, consultar los logs o la documentación adicional.*
