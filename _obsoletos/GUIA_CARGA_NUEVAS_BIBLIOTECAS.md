# 📚 GUÍA COMPLETA: CARGA DE NUEVAS BIBLIOTECAS
## Ejemplo Práctico: DER.csv (Facultad de Derecho)

---

## 🎯 RESUMEN DEL PROCESO

El sistema actual procesa datos de bibliotecas en **3 pasos principales**:

1. **Preparación**: CSV → Validación → Configuración
2. **Conversión**: CSV → MARCXML (formato estándar bibliotecario)
3. **Importación**: MARCXML → Koha + Reindexación

**Tiempo estimado**: 15-30 minutos (depende del tamaño del archivo)

---

## 📋 REQUISITOS PREVIOS

### Archivos Necesarios

- ✅ Archivo CSV con los datos (ej: `DER.csv`)
- ✅ Estructura de columnas compatible con el sistema
- ✅ Códigos de barras únicos (no duplicados)

### Información Requerida

| Dato | Ejemplo | Descripción |
|------|---------|-------------|
| **Código de biblioteca** | `DER` o `FACDER` | 3-10 caracteres, sin espacios |
| **Nombre completo** | "Facultad de Derecho" | Nombre descriptivo |
| **Ubicación por defecto** | `SALA` | Dónde están físicamente los libros |
| **Tipo de material** | `BK` (libros) | BK, MG, TES, etc. |

---

## 🔍 PASO 1: PREPARAR EL ARCHIVO CSV

### 1.1. Verificar Estructura del CSV

El archivo DER.csv debe tener estas columnas mínimas:

```csv
analisis,codbiblio,titulo,autor,editorial,publicacion,isbn_issn,ubicacion,nroacceso,loc,tipomaterial
```

**Columnas obligatorias:**
- `analisis` - ID único del registro
- `codbiblio` - Código de la biblioteca (ej: DER)
- `titulo` - Título del libro
- `nroacceso` - Código de barras ÚNICO
- `ubicacion` - Signatura topográfica

**Ejemplo de registro:**
```csv
1,DER,Derecho Civil I,González Juan,Editorial Jurídica,2023,978-123456,340 G65d,DER-00001,SALA,BK
```

### 1.2. Validar el Archivo

```bash
# Ver primeras líneas del CSV
head -5 DER.csv

# Contar registros
wc -l DER.csv

# Verificar que no tenga caracteres raros
file DER.csv

# Buscar códigos de barras duplicados
cut -d',' -f9 DER.csv | sort | uniq -d
```

Si hay duplicados, **deben corregirse antes de continuar**.

---

## ⚙️ PASO 2: CONFIGURAR LA NUEVA BIBLIOTECA

### 2.1. Agregar a la Configuración Principal

Editar el archivo de configuración:

```bash
nano /home/mvillalba/migradatos/migracion_config.json
```

Agregar nueva entrada en la sección `"bibliotecas"`:

```json
{
  "bibliotecas": {
    "POL": {
      "nombre": "Biblioteca Politécnica",
      "tipo_fuente": "csv",
      "archivo_csv": "POL.csv",
      "codigo_koha": "POL",
      "loc_default": "SALA",
      "activa": true,
      "prioridad": 1
    },
    "ARQ": {
      "nombre": "Arquitectura",
      "tipo_fuente": "csv",
      "archivo_csv": "ARQ.csv",
      "codigo_koha": "ARQ",
      "loc_default": "SALA",
      "activa": true,
      "prioridad": 2
    },
    "DER": {
      "nombre": "Facultad de Derecho",
      "tipo_fuente": "csv",
      "archivo_csv": "DER.csv",
      "codigo_koha": "DER",
      "loc_default": "SALA",
      "activa": true,
      "prioridad": 3
    }
  }
}
```

**Guardar**: `Ctrl+O`, `Enter`, `Ctrl+X`

### 2.2. Crear Código de Biblioteca en Koha

Ejecutar en línea de comandos:

```bash
# Opción 1: Via interfaz web de Koha (recomendado)
# Ir a: Administración → Bibliotecas → Nueva biblioteca

# Opción 2: Via script (más rápido)
sudo koha-mysql koha-cnc -e "
INSERT INTO branches (branchcode, branchname)
VALUES ('DER', 'Facultad de Derecho')
ON DUPLICATE KEY UPDATE branchname='Facultad de Derecho';
"
```

### 2.3. Verificar Tipos de Material

```bash
# Ver tipos existentes
sudo koha-mysql koha-cnc -e "SELECT itemtype, description FROM itemtypes;"

# Si falta alguno, agregarlo
sudo koha-mysql koha-cnc -e "
INSERT IGNORE INTO itemtypes (itemtype, description)
VALUES ('BK', 'Libro');
"
```

---

## 🔄 PASO 3: CONVERTIR CSV A MARCXML

### 3.1. Copiar el CSV al Directorio de Trabajo

```bash
# Si el archivo está en otro lugar
cp /ruta/donde/esta/DER.csv /home/mvillalba/migradatos/

# Verificar que llegó correctamente
ls -lh /home/mvillalba/migradatos/DER.csv
```

### 3.2. Ejecutar Conversión a MARCXML

```bash
cd /home/mvillalba/migradatos

# Conversión básica
python3 opac_exportar.py -i DER.csv --codbiblio DER --loc-default SALA

# Conversión con más opciones
python3 opac_exportar.py \
  -i DER.csv \
  --codbiblio DER \
  --loc-default SALA \
  --split-by 5000
```

**Parámetros:**
- `-i DER.csv` - Archivo de entrada
- `--codbiblio DER` - Código de la biblioteca
- `--loc-default SALA` - Ubicación por defecto
- `--split-by 5000` - Dividir en archivos de 5000 registros (opcional)

**Resultado esperado:**
```
✓ Procesando DER.csv...
✓ Validando estructura...
✓ Convirtiendo a MARCXML...
✓ Generado: DER_20251016_marcxml_01.xml (5000 registros)
✓ Generado: DER_20251016_marcxml_02.xml (3247 registros)
✓ Total: 8247 registros procesados en 45.3 segundos
```

### 3.3. Verificar Archivos MARCXML Generados

```bash
# Listar archivos generados
ls -lh DER_*_marcxml_*.xml

# Ver estructura del primer registro
head -50 DER_20251016_marcxml_01.xml
```

---

## 📥 PASO 4: IMPORTAR A KOHA

### 4.1. Método Automático (Recomendado)

Usar el script de sincronización:

```bash
cd /home/mvillalba/migradatos

# Editar el script para usar DER
nano sincronizar_arquitectura.sh
```

Modificar estas líneas:

```bash
# Línea 30: Cambiar biblioteca
BIBLIOTECA="DER"

# Línea 32: Cambiar archivo CSV
CSV_INPUT="/home/mvillalba/migradatos/DER.csv"

# Línea 45: Cambiar nombre descriptivo
NOMBRE_BIBLIOTECA="Facultad de Derecho"
```

Guardar y ejecutar:

```bash
sudo ./sincronizar_arquitectura.sh
```

### 4.2. Método Manual (Paso a Paso)

Si prefieres hacerlo manualmente para entender el proceso:

#### 4.2.1. Importar Registros

```bash
# Importar primer archivo MARCXML
sudo koha-shell koha-cnc -c "
cd /home/mvillalba/migradatos && \
/usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
  -b -file DER_20251016_marcxml_01.xml \
  -commit 1000 \
  -match 'control_number,=,001'
"
```

**Parámetros importantes:**
- `-b` - Importar solo registros bibliográficos + ítems
- `-file` - Archivo MARCXML a importar
- `-commit 1000` - Guardar cada 1000 registros
- `-match` - Evitar duplicados basándose en el campo 001

#### 4.2.2. Verificar Importación

```bash
# Contar registros importados
sudo koha-mysql koha-cnc -e "
SELECT COUNT(*) as total_registros
FROM biblio;
"

# Ver últimos 10 registros importados
sudo koha-mysql koha-cnc -e "
SELECT biblionumber, title, author
FROM biblio
ORDER BY biblionumber DESC
LIMIT 10;
"

# Contar ítems de la biblioteca DER
sudo koha-mysql koha-cnc -e "
SELECT COUNT(*) as items_DER
FROM items
WHERE homebranch='DER';
"
```

#### 4.2.3. Reindexar Zebra

**IMPORTANTE**: Usar flag `-b` (NO `-f`) para no borrar índices:

```bash
sudo koha-rebuild-zebra -b -v koha-cnc
```

Monitorear progreso:

```bash
# En otra terminal
watch -n 5 'sudo du -sh /var/lib/koha/koha-cnc/biblios/'
```

---

## ✅ PASO 5: VERIFICACIÓN Y PRUEBAS

### 5.1. Verificar con el Agente Experto

```bash
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --no-fix
```

Debe mostrar:
```
✓ Zebra corriendo
✓ Índices poblados
✓ XX,XXX registros en base de datos
✓ Porcentaje indexado: 99%+
```

### 5.2. Pruebas en el OPAC

Abrir navegador: `https://koha.cnc.una.py`

**Prueba 1: Búsqueda simple**
```
Buscar: "derecho"
Resultados esperados: Libros de la Facultad de Derecho
```

**Prueba 2: Búsqueda avanzada**
```
Biblioteca: Facultad de Derecho
Tipo de material: Libro
Resultados: Solo libros de DER
```

**Prueba 3: Verificar ítem individual**
```
1. Buscar un libro específico
2. Abrir registro
3. Verificar pestaña "Ejemplares"
4. Confirmar:
   - ✓ Código de barras correcto
   - ✓ Ubicación: SALA
   - ✓ Biblioteca: Facultad de Derecho
   - ✓ Estado: Disponible
```

### 5.3. Verificación Técnica

```bash
# Registros por biblioteca
sudo koha-mysql koha-cnc -e "
SELECT homebranch, COUNT(*) as cantidad
FROM items
GROUP BY homebranch
ORDER BY cantidad DESC;
"

# Verificar duplicados de códigos de barras
sudo koha-mysql koha-cnc -e "
SELECT barcode, COUNT(*) as veces
FROM items
GROUP BY barcode
HAVING veces > 1;
"

# Si hay duplicados, se muestran aquí - DEBEN corregirse
```

---

## 🔧 SOLUCIÓN DE PROBLEMAS COMUNES

### Problema 1: Error "duplicate barcode"

**Causa**: Código de barras ya existe en el sistema

**Solución**:
```bash
# Encontrar el duplicado
sudo koha-mysql koha-cnc -e "
SELECT itemnumber, barcode, homebranch
FROM items
WHERE barcode='DER-00001';
"

# Opción A: Corregir en el CSV y reimportar
# Opción B: Agregar prefijo a los nuevos
python3 opac_exportar.py -i DER.csv --codbiblio DER --barcode-prefix "DER-2025-"
```

### Problema 2: "No se encuentra la biblioteca"

**Solución**:
```bash
# Crear código de biblioteca
sudo koha-mysql koha-cnc -e "
INSERT IGNORE INTO branches (branchcode, branchname)
VALUES ('DER', 'Facultad de Derecho');
"

# Verificar
sudo koha-mysql koha-cnc -e "SELECT * FROM branches WHERE branchcode='DER';"
```

### Problema 3: Índices no actualizados

**Síntoma**: Búsquedas no muestran los nuevos registros

**Solución**:
```bash
# Reindexar (modo seguro)
sudo koha-rebuild-zebra -b -v koha-cnc

# Verificar con agente
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py
```

### Problema 4: Caracteres extraños en títulos

**Causa**: Encoding incorrecto del CSV

**Solución**:
```bash
# Convertir a UTF-8
iconv -f ISO-8859-1 -t UTF-8 DER.csv > DER_utf8.csv
mv DER_utf8.csv DER.csv

# Verificar encoding
file -i DER.csv
# Debe mostrar: charset=utf-8
```

### Problema 5: Registros importados sin ítems

**Causa**: Error en columnas del CSV

**Diagnóstico**:
```bash
# Ver registros sin ítems
sudo koha-mysql koha-cnc -e "
SELECT b.biblionumber, b.title
FROM biblio b
LEFT JOIN items i ON b.biblionumber = i.biblionumber
WHERE i.itemnumber IS NULL
LIMIT 10;
"
```

**Solución**: Verificar que el CSV tenga las columnas `nroacceso`, `ubicacion`, `codbiblio`

---

## 📊 SCRIPT AUTOMATIZADO COMPLETO

Para facilitar el proceso, puedes crear un script que lo haga todo:

```bash
nano /home/mvillalba/migradatos/cargar_biblioteca.sh
```

Contenido:

```bash
#!/bin/bash
# Script para cargar una nueva biblioteca

# Configuración
BIBLIOTECA_CODE="$1"
BIBLIOTECA_NOMBRE="$2"
CSV_FILE="$3"

if [ -z "$BIBLIOTECA_CODE" ] || [ -z "$BIBLIOTECA_NOMBRE" ] || [ -z "$CSV_FILE" ]; then
    echo "Uso: $0 <codigo> <nombre> <archivo.csv>"
    echo "Ejemplo: $0 DER 'Facultad de Derecho' DER.csv"
    exit 1
fi

echo "=== CARGANDO BIBLIOTECA: $BIBLIOTECA_NOMBRE ==="
echo "Código: $BIBLIOTECA_CODE"
echo "Archivo: $CSV_FILE"
echo

# 1. Verificar archivo
if [ ! -f "$CSV_FILE" ]; then
    echo "ERROR: Archivo $CSV_FILE no existe"
    exit 1
fi

echo "✓ Archivo encontrado: $(wc -l < $CSV_FILE) líneas"

# 2. Crear código en Koha
echo "Creando biblioteca en Koha..."
sudo koha-mysql koha-cnc -e "
INSERT INTO branches (branchcode, branchname)
VALUES ('$BIBLIOTECA_CODE', '$BIBLIOTECA_NOMBRE')
ON DUPLICATE KEY UPDATE branchname='$BIBLIOTECA_NOMBRE';
"
echo "✓ Biblioteca creada/actualizada"

# 3. Convertir a MARCXML
echo "Convirtiendo CSV a MARCXML..."
python3 /home/mvillalba/migradatos/opac_exportar.py \
    -i "$CSV_FILE" \
    --codbiblio "$BIBLIOTECA_CODE" \
    --loc-default SALA

if [ $? -ne 0 ]; then
    echo "ERROR: Fallo en la conversión"
    exit 1
fi
echo "✓ Conversión completada"

# 4. Importar a Koha
echo "Importando a Koha..."
MARCXML=$(ls -t ${BIBLIOTECA_CODE}_*_marcxml_*.xml 2>/dev/null | head -1)

if [ -z "$MARCXML" ]; then
    echo "ERROR: No se encontró archivo MARCXML"
    exit 1
fi

sudo koha-shell koha-cnc -c "
cd /home/mvillalba/migradatos && \
/usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
  -b -file $MARCXML \
  -commit 1000 \
  -match 'control_number,=,001'
"
echo "✓ Importación completada"

# 5. Reindexar
echo "Reindexando Zebra..."
sudo koha-rebuild-zebra -b -v koha-cnc > /dev/null 2>&1
echo "✓ Reindexación completada"

# 6. Verificar
echo
echo "=== VERIFICACIÓN ==="
sudo koha-mysql koha-cnc -e "
SELECT
    '$BIBLIOTECA_CODE' as Biblioteca,
    COUNT(*) as Items_Cargados
FROM items
WHERE homebranch='$BIBLIOTECA_CODE';
"

echo
echo "✓ PROCESO COMPLETADO"
echo "Verificar en: https://koha.cnc.una.py"
```

Dar permisos y usar:

```bash
chmod +x /home/mvillalba/migradatos/cargar_biblioteca.sh

# Usar así:
sudo ./cargar_biblioteca.sh DER "Facultad de Derecho" DER.csv
```

---

## 📝 CHECKLIST PRE-IMPORTACIÓN

Antes de importar DER.csv o cualquier otra biblioteca, verificar:

- [ ] Archivo CSV tiene encoding UTF-8
- [ ] Códigos de barras son únicos (no duplicados internamente)
- [ ] Códigos de barras no existen ya en Koha
- [ ] Columna `codbiblio` tiene el código correcto
- [ ] Códigos de barras tienen formato consistente
- [ ] Signatura topográfica (`ubicacion`) está presente
- [ ] Título está presente en todos los registros
- [ ] Backup de base de datos realizado (por seguridad)

**Comando para backup**:
```bash
sudo koha-dump koha-cnc
# Backup guardado en: /var/spool/koha/koha-cnc/
```

---

## 📈 DESPUÉS DE LA IMPORTACIÓN

### Tareas de Mantenimiento

**Diario:**
```bash
# Verificar índices
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --no-fix
```

**Semanal:**
```bash
# Estadísticas
sudo koha-mysql koha-cnc -e "
SELECT homebranch, COUNT(*) as items
FROM items
GROUP BY homebranch;
"
```

**Mensual:**
```bash
# Backup
sudo koha-dump koha-cnc
```

### Documentar la Nueva Biblioteca

Actualizar: `/home/mvillalba/migradatos/INDICE_DOCUMENTACION.md`

Agregar sección:
```markdown
## Facultad de Derecho (DER)

- **Fecha de carga**: 2025-10-16
- **Registros**: 8,247
- **Archivo fuente**: DER.csv
- **Responsable**: [Nombre]
- **Notas**: [Observaciones especiales]
```

---

## 🎓 EJEMPLO COMPLETO: CARGAR DER.CSV

### Comandos Secuenciales

```bash
# 1. Preparar entorno
cd /home/mvillalba/migradatos

# 2. Verificar archivo
ls -lh DER.csv
head -3 DER.csv

# 3. Crear código de biblioteca
sudo koha-mysql koha-cnc -e "
INSERT INTO branches (branchcode, branchname)
VALUES ('DER', 'Facultad de Derecho')
ON DUPLICATE KEY UPDATE branchname='Facultad de Derecho';
"

# 4. Convertir a MARCXML
python3 opac_exportar.py -i DER.csv --codbiblio DER --loc-default SALA

# 5. Importar
sudo koha-shell koha-cnc -c "
cd /home/mvillalba/migradatos && \
/usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
  -b -file DER_$(date +%Y%m%d)_marcxml_01.xml \
  -commit 1000 \
  -match 'control_number,=,001'
"

# 6. Reindexar (modo seguro)
sudo koha-rebuild-zebra -b -v koha-cnc

# 7. Verificar
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --no-fix

# 8. Ver estadísticas
sudo koha-mysql koha-cnc -e "
SELECT homebranch, COUNT(*)
FROM items
WHERE homebranch='DER'
GROUP BY homebranch;
"
```

**Tiempo total estimado**: 20-30 minutos

---

## 🆘 CONTACTO Y SOPORTE

Si tienes problemas durante la carga:

1. **Verificar logs**:
   ```bash
   tail -100 /home/mvillalba/migradatos/logs/*.log
   ```

2. **Ejecutar agente experto**:
   ```bash
   sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py
   ```

3. **Consultar documentación**:
   - `TABLA_MAPEO_UNIDADES_ACADEMICAS.md`
   - `AGENTE_ZEBRA_MANUAL.md`
   - `REPORTE_INDICES_BORRADOS.md`

---

**Guía creada**: 2025-10-16
**Versión**: 1.0
**Sistema**: Koha MARC21 + Zebra
**Próxima actualización**: Agregar soporte para Elasticsearch
