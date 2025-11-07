# INSTRUCTIVO DE IMPORTACIÓN OPTIMIZADO
## Sistema de Gestión Bibliográfica Koha - UNA

**Versión:** 2.0 Optimizada
**Fecha:** 25 de Octubre de 2025
**Autor:** Equipo de Migración - UNA

---

## TABLA DE CONTENIDOS

1. [Requisitos Previos](#requisitos-previos)
2. [Preparación del Archivo CSV](#preparación-del-archivo-csv)
3. [Proceso de Importación Paso a Paso](#proceso-de-importación-paso-a-paso)
4. [Verificación y Control de Calidad](#verificación-y-control-de-calidad)
5. [Solución de Problemas](#solución-de-problemas)
6. [Mantenimiento y Optimización](#mantenimiento-y-optimización)
7. [Comandos de Referencia Rápida](#comandos-de-referencia-rápida)

---

## REQUISITOS PREVIOS

### ✅ Verificaciones Iniciales

Antes de comenzar, asegúrate de que:

```bash
# 1. El código de biblioteca existe en Koha
sudo koha-mysql koha-cnc -e "SELECT branchcode, branchname FROM branches WHERE branchcode = 'CODIGO'"

# 2. Hay espacio suficiente en disco (mínimo 2GB libres)
df -h /home/mvillalba/migradatos

# 3. Los servicios están activos
systemctl status mysql
systemctl status apache2
koha-zebra --status koha-cnc
```

### 📋 Estructura de Directorios

```
/home/mvillalba/migradatos/
├── importar_aqui/          # Colocar archivos CSV aquí
├── exports/                # Archivos MARCXML generados
├── errores/                # Archivos con problemas
├── logs/                   # Registros de importación
└── scripts/                # Scripts de conversión
```

---

## PREPARACIÓN DEL ARCHIVO CSV

### 📄 Formato del Archivo

**Nombre:** `CODIGO_BIBLIOTECA.csv`
**Ejemplos válidos:**
- `BC.csv` (Biblioteca Central)
- `FACEN.csv` (Facultad de Ciencias Exactas)
- `MED.csv` (Medicina)

**Formato:**
- Codificación: UTF-8
- Separador: punto y coma (`;`)
- Primera línea: encabezados
- Campos entre comillas dobles (`"`)

### ✅ Validación del CSV

```bash
# Verificar formato
head -3 /home/mvillalba/migradatos/importar_aqui/CODIGO.csv

# Contar registros (excluir header)
wc -l /home/mvillalba/migradatos/importar_aqui/CODIGO.csv

# Verificar código de biblioteca en primera columna
head -2 /home/mvillalba/migradatos/importar_aqui/CODIGO.csv | tail -1 | cut -d';' -f1
```

---

## PROCESO DE IMPORTACIÓN PASO A PASO

### MÉTODO 1: IMPORTACIÓN AUTOMÁTICA (Recomendado)

#### Paso 1: Colocar el Archivo

```bash
# Copiar archivo a la carpeta de importación
cp /ruta/origen/CODIGO.csv /home/mvillalba/migradatos/importar_aqui/

# Verificar que esté presente
ls -lh /home/mvillalba/migradatos/importar_aqui/CODIGO.csv
```

#### Paso 2: Generar MARCXML

```bash
cd /home/mvillalba/migradatos/exports

python3 /home/mvillalba/migradatos/scripts/opac_exportar.py \
  -i /home/mvillalba/migradatos/importar_aqui/CODIGO.csv \
  --codbiblio CODIGO \
  --loc-default CODIGO \
  --stream \
  --split-by 1000
```

**Salida esperada:**
```
→ escribiendo: CODIGO_20251025_marcxml_01.xml
→ escribiendo: CODIGO_20251025_marcxml_02.xml
...
✅ Listo (stream/split).
```

#### Paso 3: Verificar Archivos MARCXML

```bash
# Listar archivos generados
ls -lh /home/mvillalba/migradatos/exports/CODIGO_*_marcxml*.xml

# Contar registros totales
grep -c '<ns0:record' /home/mvillalba/migradatos/exports/CODIGO_*_marcxml*.xml | \
  awk -F: '{sum+=$2} END {print "Total registros:", sum}'

# Ver contenido de un archivo (primeras líneas)
head -30 /home/mvillalba/migradatos/exports/CODIGO_20251025_marcxml_01.xml
```

#### Paso 4: Importar a Koha

**Opción A: Importación secuencial (más estable)**

```bash
for xml in /home/mvillalba/migradatos/exports/CODIGO_*_marcxml*.xml; do
  echo "=== Importando: $(basename $xml) ==="
  sudo koha-shell koha-cnc -c \
    "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
    -b -m MARCXML -file $xml -commit 1000" 2>&1 | tail -3
done
```

**Opción B: Importación con script Python (más rápido)**

```bash
python3 << 'EOF'
import subprocess
import glob

archivos = sorted(glob.glob('/home/mvillalba/migradatos/exports/CODIGO_*_marcxml*.xml'))

for idx, xml in enumerate(archivos, 1):
    print(f"\n[{idx}/{len(archivos)}] Importando: {xml.split('/')[-1]}")

    cmd = f'sudo koha-shell koha-cnc -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl -b -m MARCXML -file {xml} -commit 1000" 2>&1'

    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)

    # Mostrar últimas 2 líneas
    for line in result.stdout.strip().split('\n')[-2:]:
        print(f"  {line}")

print("\n✅ Importación completada")
EOF
```

#### Paso 5: Verificar Importación

```bash
# Contar registros en la base de datos
sudo koha-mysql koha-cnc -e \
  "SELECT COUNT(DISTINCT biblionumber) as titulos, COUNT(*) as items
   FROM items WHERE homebranch = 'CODIGO'"

# Ver últimos registros importados
sudo koha-mysql koha-cnc -e \
  "SELECT biblio.biblionumber, LEFT(biblio.title, 60) as titulo, items.barcode
   FROM biblio
   JOIN items ON biblio.biblionumber = items.biblionumber
   WHERE items.homebranch = 'CODIGO'
   ORDER BY biblio.biblionumber DESC
   LIMIT 10"
```

#### Paso 6: Reindexar Zebra

```bash
# Reindexación completa (primera vez o después de muchos cambios)
sudo koha-rebuild-zebra -f -v koha-cnc

# Reindexación incremental (solo cambios recientes)
sudo koha-rebuild-zebra -v koha-cnc
```

---

### MÉTODO 2: SCRIPT AUTOMATIZADO TODO-EN-UNO

Crear script `/home/mvillalba/migradatos/importar_biblioteca.sh`:

```bash
#!/bin/bash
# Script optimizado para importación completa
# Uso: ./importar_biblioteca.sh CODIGO

set -e

CODIGO=$1
CSV_PATH="/home/mvillalba/migradatos/importar_aqui/${CODIGO}.csv"
EXPORT_DIR="/home/mvillalba/migradatos/exports"
LOG_DIR="/home/mvillalba/migradatos/logs"
FECHA=$(date '+%Y%m%d_%H%M%S')

# Validaciones
if [ -z "$CODIGO" ]; then
    echo "❌ Error: Debe especificar el código de biblioteca"
    echo "Uso: $0 CODIGO_BIBLIOTECA"
    exit 1
fi

if [ ! -f "$CSV_PATH" ]; then
    echo "❌ Error: No existe $CSV_PATH"
    exit 1
fi

echo "════════════════════════════════════════════════════════"
echo "  IMPORTACIÓN AUTOMÁTICA: $CODIGO"
echo "  Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════════════════"

# Contar registros en CSV
TOTAL_CSV=$(($(wc -l < "$CSV_PATH") - 1))
echo "[INFO] Registros en CSV: $TOTAL_CSV"

# 1. GENERAR MARCXML
echo ""
echo "[1/5] Generando archivos MARCXML..."
cd "$EXPORT_DIR"
python3 /home/mvillalba/migradatos/scripts/opac_exportar.py \
  -i "$CSV_PATH" \
  --codbiblio "$CODIGO" \
  --loc-default "$CODIGO" \
  --stream \
  --split-by 1000 2>&1 | grep -E "escribiendo|Listo"

# 2. VERIFICAR GENERACIÓN
echo ""
echo "[2/5] Verificando archivos generados..."
ARCHIVOS_XML=$(ls -1 ${EXPORT_DIR}/${CODIGO}_*_marcxml*.xml 2>/dev/null | wc -l)
if [ $ARCHIVOS_XML -eq 0 ]; then
    echo "❌ Error: No se generaron archivos MARCXML"
    exit 1
fi

TOTAL_XML=$(grep -c '<ns0:record' ${EXPORT_DIR}/${CODIGO}_*_marcxml*.xml | \
            awk -F: '{sum+=$2} END {print sum}')
echo "✅ Archivos XML generados: $ARCHIVOS_XML"
echo "✅ Total registros XML: $TOTAL_XML"

# 3. ITEMS ANTES DE IMPORTAR
echo ""
echo "[3/5] Consultando estado actual..."
ITEMS_ANTES=$(sudo koha-mysql koha-cnc -N -e \
  "SELECT COUNT(DISTINCT biblionumber) FROM items WHERE homebranch = '$CODIGO'" || echo "0")
echo "📊 Títulos existentes: $ITEMS_ANTES"

# 4. IMPORTAR A KOHA
echo ""
echo "[4/5] Importando a Koha..."
CONTADOR=0
for xml in ${EXPORT_DIR}/${CODIGO}_*_marcxml*.xml; do
    CONTADOR=$((CONTADOR + 1))
    NOMBRE=$(basename $xml)
    echo "  [$CONTADOR/$ARCHIVOS_XML] $NOMBRE"

    sudo koha-shell koha-cnc -c \
      "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
       -b -m MARCXML -file $xml -commit 1000" 2>&1 | tail -2 | sed 's/^/    /'
done

# 5. VERIFICAR RESULTADO
echo ""
echo "[5/5] Verificando importación..."
ITEMS_DESPUES=$(sudo koha-mysql koha-cnc -N -e \
  "SELECT COUNT(DISTINCT biblionumber) FROM items WHERE homebranch = '$CODIGO'" || echo "0")
IMPORTADOS=$((ITEMS_DESPUES - ITEMS_ANTES))

echo "✅ Títulos después: $ITEMS_DESPUES"
echo "✅ Registros importados: $IMPORTADOS"

# GUARDAR LOG
LOG_FILE="${LOG_DIR}/import_${CODIGO}_${FECHA}.log"
cat > "$LOG_FILE" <<LOGEOF
Fecha: $(date '+%Y-%m-%d %H:%M:%S')
Biblioteca: $CODIGO
CSV: $CSV_PATH
Registros CSV: $TOTAL_CSV
Archivos XML: $ARCHIVOS_XML
Registros XML: $TOTAL_XML
Títulos antes: $ITEMS_ANTES
Títulos después: $ITEMS_DESPUES
Importados: $IMPORTADOS
Estado: ÉXITO
LOGEOF

echo ""
echo "📝 Log guardado: $LOG_FILE"
echo ""
echo "════════════════════════════════════════════════════════"
echo "  ✅ IMPORTACIÓN COMPLETADA EXITOSAMENTE"
echo "════════════════════════════════════════════════════════"
echo ""
echo "⚠️  IMPORTANTE: Ejecutar reindexación:"
echo "    sudo koha-rebuild-zebra -v koha-cnc"
echo ""
```

**Dar permisos y ejecutar:**

```bash
chmod +x /home/mvillalba/migradatos/importar_biblioteca.sh
/home/mvillalba/migradatos/importar_biblioteca.sh CODIGO
```

---

## VERIFICACIÓN Y CONTROL DE CALIDAD

### 📊 Consultas de Verificación

```bash
# 1. Total por biblioteca
sudo koha-mysql koha-cnc -e \
  "SELECT homebranch, COUNT(DISTINCT biblionumber) as titulos, COUNT(*) as items
   FROM items
   GROUP BY homebranch
   ORDER BY titulos DESC"

# 2. Registros sin código de barras
sudo koha-mysql koha-cnc -e \
  "SELECT COUNT(*) FROM items WHERE homebranch = 'CODIGO' AND barcode IS NULL"

# 3. Duplicados potenciales
sudo koha-mysql koha-cnc -e \
  "SELECT barcode, COUNT(*) as cantidad
   FROM items
   WHERE homebranch = 'CODIGO'
   GROUP BY barcode
   HAVING cantidad > 1"

# 4. Registros recientes
sudo koha-mysql koha-cnc -e \
  "SELECT DATE(timestamp) as fecha, COUNT(*) as cantidad
   FROM items
   WHERE homebranch = 'CODIGO'
   GROUP BY DATE(timestamp)
   ORDER BY fecha DESC
   LIMIT 7"

# 5. Distribución por tipo de material
sudo koha-mysql koha-cnc -e \
  "SELECT itype, COUNT(*) as cantidad
   FROM items
   WHERE homebranch = 'CODIGO'
   GROUP BY itype
   ORDER BY cantidad DESC"
```

### 🔍 Búsqueda en OPAC

```bash
# URL de búsqueda por biblioteca
echo "http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=CODIGO"
```

---

## SOLUCIÓN DE PROBLEMAS

### ❌ Error: "No se generaron archivos MARCXML"

**Causa:** Formato incorrecto del CSV o problemas de codificación

**Solución:**
```bash
# Verificar codificación
file -i /home/mvillalba/migradatos/importar_aqui/CODIGO.csv

# Convertir a UTF-8 si es necesario
iconv -f ISO-8859-1 -t UTF-8 archivo_original.csv > CODIGO.csv

# Verificar separador
head -1 /home/mvillalba/migradatos/importar_aqui/CODIGO.csv
```

---

### ❌ Error: "duplicate barcode"

**Causa:** Código de barras duplicado en la base de datos

**Solución:**
```bash
# Buscar duplicados
sudo koha-mysql koha-cnc -e \
  "SELECT barcode, COUNT(*) FROM items GROUP BY barcode HAVING COUNT(*) > 1"

# Eliminar duplicado específico (con precaución)
sudo koha-mysql koha-cnc -e \
  "DELETE FROM items WHERE itemnumber = ID_DEL_DUPLICADO LIMIT 1"
```

---

### ❌ Error: "Zebra not responding"

**Causa:** Servicio Zebra detenido o sin responder

**Solución:**
```bash
# Verificar estado
koha-zebra --status koha-cnc

# Reiniciar servicio
sudo koha-zebra --restart koha-cnc

# Verificar logs
sudo tail -50 /var/log/koha/koha-cnc/zebra-error.log
```

---

### ⚠️ Archivos en carpeta "errores"

**Qué hacer:**

1. **Revisar el log:**
   ```bash
   cat /home/mvillalba/migradatos/logs/reporte_CODIGO_*.txt
   ```

2. **Verificar el problema:**
   ```bash
   head -5 /home/mvillalba/migradatos/errores/CODIGO_ERROR_*.csv
   ```

3. **Reintentar importación:**
   ```bash
   cp /home/mvillalba/migradatos/errores/CODIGO_ERROR_*.csv \
      /home/mvillalba/migradatos/importar_aqui/CODIGO.csv

   # Luego seguir proceso normal
   ```

---

## MANTENIMIENTO Y OPTIMIZACIÓN

### 🔄 Reindexación Automática (Cron)

```bash
# Editar crontab
sudo crontab -e

# Agregar estas líneas:
# Reindexación incremental cada hora
0 * * * * koha-rebuild-zebra -a -z koha-cnc >> /var/log/koha/zebra-reindex.log 2>&1

# Reindexación completa domingos a las 3 AM
0 3 * * 0 koha-rebuild-zebra -f -v koha-cnc >> /var/log/koha/zebra-reindex-full.log 2>&1
```

### 🧹 Limpieza de Archivos Temporales

```bash
# Crear script de limpieza
cat > /home/mvillalba/migradatos/limpiar_temporales.sh << 'EOF'
#!/bin/bash
# Limpieza de archivos temporales de importación

DIAS=30

echo "Limpiando archivos XML de exportación mayores a $DIAS días..."
find /home/mvillalba/migradatos/exports -name "*.xml" -mtime +$DIAS -delete

echo "Limpiando logs mayores a 60 días..."
find /home/mvillalba/migradatos/logs -name "*.log" -mtime +60 -delete
find /home/mvillalba/migradatos/logs -name "*.txt" -mtime +60 -delete

echo "✅ Limpieza completada"
df -h /home/mvillalba/migradatos
EOF

chmod +x /home/mvillalba/migradatos/limpiar_temporales.sh

# Ejecutar mensualmente (cron)
# 0 2 1 * * /home/mvillalba/migradatos/limpiar_temporales.sh
```

### 📊 Script de Monitoreo

```bash
# Crear script de estado
cat > /usr/local/bin/koha-estado-importacion.sh << 'EOF'
#!/bin/bash
echo "════════════════════════════════════════════════════════"
echo "  ESTADO DEL SISTEMA DE IMPORTACIÓN"
echo "  Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "════════════════════════════════════════════════════════"

echo ""
echo "=== ESPACIO EN DISCO ==="
df -h /home/mvillalba/migradatos | tail -1

echo ""
echo "=== ARCHIVOS PENDIENTES ==="
echo "CSV en importar_aqui: $(ls -1 /home/mvillalba/migradatos/importar_aqui/*.csv 2>/dev/null | wc -l)"
echo "CSV en errores: $(ls -1 /home/mvillalba/migradatos/errores/*.csv 2>/dev/null | wc -l)"

echo ""
echo "=== TOP 10 BIBLIOTECAS (por cantidad de títulos) ==="
sudo koha-mysql koha-cnc -t -e \
  "SELECT homebranch as Biblioteca,
          COUNT(DISTINCT biblionumber) as Títulos,
          COUNT(*) as Items
   FROM items
   GROUP BY homebranch
   ORDER BY Títulos DESC
   LIMIT 10"

echo ""
echo "=== SERVICIOS ==="
printf "MySQL:     "; systemctl is-active mysql || echo "INACTIVO"
printf "Apache:    "; systemctl is-active apache2 || echo "INACTIVO"
printf "Memcached: "; systemctl is-active memcached || echo "INACTIVO"
printf "Zebra:     "; koha-zebra --status koha-cnc | grep -q "running" && echo "active" || echo "INACTIVO"

echo ""
echo "=== ÚLTIMA REINDEXACIÓN ==="
ls -lh /var/log/koha/zebra-reindex*.log 2>/dev/null | tail -2

echo ""
echo "════════════════════════════════════════════════════════"
EOF

chmod +x /usr/local/bin/koha-estado-importacion.sh
```

---

## COMANDOS DE REFERENCIA RÁPIDA

### 📝 Cheat Sheet

```bash
# ═══ VERIFICACIÓN PREVIA ═══
# Ver bibliotecas disponibles
sudo koha-mysql koha-cnc -e "SELECT branchcode, branchname FROM branches"

# Contar registros actuales
sudo koha-mysql koha-cnc -e "SELECT homebranch, COUNT(*) FROM items GROUP BY homebranch"

# ═══ IMPORTACIÓN RÁPIDA ═══
# 1. Generar MARCXML
cd /home/mvillalba/migradatos/exports
python3 ../scripts/opac_exportar.py -i ../importar_aqui/CODIGO.csv --codbiblio CODIGO --loc-default CODIGO --stream --split-by 1000

# 2. Importar
for xml in CODIGO_*.xml; do sudo koha-shell koha-cnc -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl -b -m MARCXML -file $xml -commit 1000"; done

# 3. Reindexar
sudo koha-rebuild-zebra -v koha-cnc

# ═══ VERIFICACIÓN ═══
sudo koha-mysql koha-cnc -e "SELECT COUNT(*) FROM items WHERE homebranch = 'CODIGO'"

# ═══ LIMPIEZA ═══
# Mover CSV procesado
mv /home/mvillalba/migradatos/importar_aqui/CODIGO.csv /home/mvillalba/migradatos/procesados/

# Limpiar XMLs antiguos
rm /home/mvillalba/migradatos/exports/CODIGO_*.xml
```

---

## CONTACTO Y SOPORTE

**Equipo de Migración - UNA**
📧 Email: soporte-biblioteca@una.py
📞 Teléfono: (021) XXX-XXXX
🏢 Ubicación: Dirección de Bibliotecas - UNA

---

**Última actualización:** 25 de Octubre de 2025
**Revisión:** v2.0 - Proceso Optimizado
