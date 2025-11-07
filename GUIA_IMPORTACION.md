# Guía de Importación Optimizada para Koha - UNA

## Resumen de Correcciones Aplicadas (2025-11-04)

### Problemas Identificados y Solucionados

1. **Error en parámetro de opac_exportar.py**
   - ❌ Incorrecto: `-i archivo.csv`
   - ✅ Correcto: `--input archivo.csv`

2. **Error en bulkmarcimport.pl**
   - ❌ Incorrecto: `-b -m MARCXML` (solo importa biblios, sin items)
   - ✅ Correcto: `-m MARCXML` (importa biblios E items)

### Archivos Corregidos

- ✅ `agente_importador_v3.py` - Líneas 301 y 380
- ✅ `importar_ultra_optimizado.py` - Líneas 320 y 383

---

## Comando Correcto para Importación Manual

### 1. Generar MARCXML desde CSV

```bash
python3 scripts/opac_exportar.py \
  --input ruta/al/archivo.csv \
  --codbiblio CODIGO_BIBLIOTECA \
  --loc-default SALA \
  --stream \
  --split-by 2000
```

**Ejemplo:**
```bash
python3 scripts/opac_exportar.py \
  --input importar_aqui/QGY.csv \
  --codbiblio QGY \
  --loc-default SALA \
  --stream \
  --split-by 2000
```

### 2. Limpiar Namespaces (Opcional pero Recomendado)

```bash
sed 's/<ns0:record/<record/g; s/<\/ns0:record/<\/record/g; s/xmlns:ns0=/xmlns=/g' \
  archivo.xml > archivo_limpio.xml
```

### 3. Importar a Koha con Items

```bash
sudo koha-shell koha-cnc -c "\
  /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
  -m MARCXML \
  -file /ruta/completa/al/archivo.xml \
  -commit 500"
```

**Ejemplo:**
```bash
sudo koha-shell koha-cnc -c "\
  /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
  -m MARCXML \
  -file /home/mvillalba/migradatos/exports/QGY_20251104_marcxml_01_limpio.xml \
  -commit 500"
```

### 4. Reindexar Zebra

```bash
sudo koha-rebuild-zebra -v -full koha-cnc
```

---

## Uso de Scripts Automatizados

### Opción 1: Agente Importador v3 (Recomendado)

```bash
./agente_importador_v3.py archivo.csv
```

**Características:**
- ✅ Recuperación ante fallos
- ✅ Reintentos automáticos
- ✅ Validación mejorada
- ✅ Importa biblios E items correctamente

### Opción 2: Importador Ultra-Optimizado

```bash
./importar_ultra_optimizado.py archivo.csv --workers 3
```

**Características:**
- ✅ Procesamiento paralelo
- ✅ Chunks adaptativos
- ✅ Máximo rendimiento
- ✅ Importa biblios E items correctamente

---

## Verificación Post-Importación

### Ver items por biblioteca

```bash
sudo koha-mysql koha-cnc -e "
SELECT
  b.branchcode AS Código,
  b.branchname AS Biblioteca,
  COUNT(i.itemnumber) AS Items
FROM branches b
LEFT JOIN items i ON b.branchcode = i.homebranch
WHERE b.branchcode IN ('QGY', 'DCSSP', 'DESCP', 'DGICT', 'ISA', 'VETSE')
GROUP BY b.branchcode, b.branchname
ORDER BY Items DESC;"
```

### Verificar totales del sistema

```bash
sudo koha-mysql koha-cnc -e "
SELECT 'Biblios' as Tipo, COUNT(*) as Total FROM biblio
UNION ALL
SELECT 'Items', COUNT(*) FROM items;"
```

---

## Troubleshooting

### Problema: No se generan archivos MARCXML

**Causa:** Parámetro incorrecto en opac_exportar.py
**Solución:** Usar `--input` en lugar de `-i`

### Problema: Se importan biblios pero no items

**Causa 1:** Falta parámetro `-m MARCXML`
**Solución:** Agregar `-m MARCXML` al comando bulkmarcimport.pl

**Causa 2:** Se usa parámetro `-b` (biblios only)
**Solución:** Remover `-b` del comando

### Problema: Archivos con namespace ns0:

**Causa:** opac_exportar.py genera XML con namespace
**Solución:** Limpiar con sed antes de importar (ver comando arriba)

---

## Estadísticas de Importación (2025-11-04)

### Bibliotecas Importadas Exitosamente

| Código | Biblioteca | Items |
|--------|-----------|-------|
| DCSSP | Derecho y CC.SS. San Pedro | 398 |
| DESCP | Escuela CC.SS. y Políticas | 1,082 |
| DGICT | Archivo Investigación DGICT | 1,094 |
| ISA | Instituto Superior de Arte | 202 |
| VETSE | CC. Veterinarias San Estanislao | 276 |
| QGY | CC. Químicas Guayaiby | 71 |
| **TOTAL** | | **3,123** |

---

## Contacto y Soporte

Para problemas con la importación, verificar:

1. Logs en: `/home/mvillalba/migradatos/logs/`
2. Archivos MARCXML en: `/home/mvillalba/migradatos/exports/`
3. Logs de Koha en: `/var/log/koha/koha-cnc/`

---

**Última actualización:** 2025-11-04
**Versión:** 2.0 (Optimizada)
