# 🚀 GUÍA RÁPIDA DE EJECUCIÓN
## Sistema de Migración Bibliográfica a Koha

---

## 📍 UBICACIÓN DE ARCHIVOS

```
/home/mvillalba/migradatos/
├── opac_exportar.py                    # ✅ Script principal (CSV → MARCXML)
├── firebird_exporter.py                # 🆕 Exportador Firebird → CSV
├── firebird_structure_analyzer.py      # 🆕 Analizador de BD Firebird
├── POL.csv                             # ✅ Datos de biblioteca POL (12,467 registros)
├── ANALISIS_Y_PLAN.md                  # 📊 Análisis completo
└── GUIA_RAPIDA.md                      # 📖 Esta guía
```

---

## ⚡ INICIO RÁPIDO - MIGRACIÓN DE POL

### Paso 1: Verificar Instalación de Python

```bash
cd /home/mvillalba/migradatos

# Verificar Python
python3 --version  # Debe ser 3.8+

# Instalar fdb si no está instalado
pip3 install fdb
```

### Paso 2: Configurar Koha (IMPORTANTE - HACER PRIMERO)

#### 2.1 Crear Biblioteca POL

1. Ir a: **Administration > Libraries**
2. Click en "New library"
3. Llenar:
   - **Code:** `POL`
   - **Name:** `Biblioteca Politécnica` (o el nombre correcto)
4. Guardar

#### 2.2 Crear Ubicaciones (LOC)

1. Ir a: **Administration > Authorized values**
2. Categoría: **LOC**
3. Agregar valores:

| Código | Descripción |
|--------|-------------|
| `SALA` | Sala de lectura |
| `REF`  | Referencia (no se presta) |
| `DEP`  | Depósito |
| `TESIS` | Tesis |

#### 2.3 Verificar Tipos de Ítem

1. Ir a: **Administration > Item types**
2. Verificar que existan:

| Código | Descripción |
|--------|-------------|
| `BK` | Libro / Book |
| `MG` | Revista / Magazine |
| `TES` | Tesis |
| `VM` | Material visual (DVD) |

### Paso 3: Generar MARCXML

```bash
cd /home/mvillalba/migradatos

# Generar MARCXML con split cada 5000 registros
python3 opac_exportar.py \
  -i POL.csv \
  --codbiblio POL \
  --loc-default SALA \
  --stream \
  --split-by 5000

# Resultado: Crea archivos POL_YYYYMMDD_marcxml_01.xml, _02.xml, _03.xml...
```

### Paso 4: Validar MARCXML

```bash
# Verificar que los archivos XML sean válidos
for file in POL_*_marcxml_*.xml; do
  echo "Validando $file..."
  xmllint --noout "$file" 2>&1 | grep -q "validates" && echo "✓ OK" || echo "⚠ Revisar"
done

# Ver cuántos registros hay
grep -c "<record>" POL_*_marcxml_*.xml
```

### Paso 5: Importar a Koha (Lote de Prueba)

```bash
# PRIMERO: Probar con el primer archivo (5000 registros)
sudo koha-shell koha-cnc -c "perl bulkmarcimport.pl \
  -b \
  -m MARCXML \
  -file /home/mvillalba/migradatos/POL_*_marcxml_01.xml \
  -commit 1000"

# Verificar en el OPAC:
# http://tu-servidor-koha/cgi-bin/koha/opac-search.pl
```

### Paso 6: Si TODO OK, Importar Completo

```bash
cd /home/mvillalba/migradatos

# Crear script de importación
cat > import_all.sh << 'EOF'
#!/bin/bash
for file in POL_*_marcxml_*.xml; do
  echo "================================"
  echo "Importando: $file"
  echo "================================"

  sudo koha-shell koha-cnc -c "perl bulkmarcimport.pl \
    -b \
    -m MARCXML \
    -file /home/mvillalba/migradatos/$file \
    -commit 1000"

  if [ $? -eq 0 ]; then
    echo "✓ OK: $file"
  else
    echo "✗ ERROR: $file"
    exit 1
  fi
  echo ""
done

echo "Reconstruyendo índices..."
sudo koha-rebuild-zebra -f -v koha-cnc

echo "✓ IMPORTACIÓN COMPLETA"
EOF

chmod +x import_all.sh

# Ejecutar importación
./import_all.sh 2>&1 | tee import_log.txt
```

---

## 🔍 ANALIZAR BASE DE DATOS FIREBIRD

Si tienes acceso a la base de datos Firebird:

```bash
cd /home/mvillalba/migradatos

# Analizar estructura
python3 firebird_structure_analyzer.py \
  --database /ruta/a/tu/base.fdb \
  --user SYSDBA \
  --password tu_password \
  --detailed

# Exportar estructura como SQL
python3 firebird_structure_analyzer.py \
  --database /ruta/a/tu/base.fdb \
  --export-ddl estructura_firebird.sql
```

---

## 📊 VERIFICACIÓN POST-IMPORTACIÓN

```bash
# Contar registros importados
sudo koha-mysql koha-cnc -e "
  SELECT COUNT(*) as total_biblios
  FROM biblio
"

# Ver ítems por biblioteca
sudo koha-mysql koha-cnc -e "
  SELECT
    homebranch,
    COUNT(*) as total_items
  FROM items
  GROUP BY homebranch
"

# Ver algunos registros
sudo koha-mysql koha-cnc -e "
  SELECT
    biblio.biblionumber,
    biblio.title,
    items.barcode,
    items.homebranch,
    items.itemcallnumber
  FROM biblio
  JOIN items ON biblio.biblionumber = items.biblionumber
  LIMIT 10
"
```

---

## 🆘 TROUBLESHOOTING

### Problema: Error "homebranch not found"

**Solución:** La biblioteca POL no existe en Koha
```bash
# Verificar bibliotecas en Koha
sudo koha-mysql koha-cnc -e "SELECT branchcode, branchname FROM branches"

# Crear biblioteca si falta
```

### Problema: "Invalid itemtype"

**Solución:** Verificar tipos de ítem
```bash
sudo koha-mysql koha-cnc -e "SELECT itemtype, description FROM itemtypes"
```

### Problema: XML malformado

**Solución:** Regenerar MARCXML con encoding correcto
```bash
# Verificar encoding del CSV
file -i POL.csv

# Si no es UTF-8, convertir:
iconv -f LATIN1 -t UTF-8 POL.csv > POL_utf8.csv
```

---

## 📋 CHECKLIST DE MIGRACIÓN POL

- [ ] Python 3.8+ instalado
- [ ] Biblioteca POL creada en Koha
- [ ] Ubicaciones (LOC) creadas
- [ ] Tipos de ítem verificados
- [ ] MARCXML generado
- [ ] MARCXML validado
- [ ] Lote de prueba importado (5000 registros)
- [ ] Verificado en OPAC
- [ ] Importación completa ejecutada
- [ ] Índices reconstruidos
- [ ] Verificación de datos
- [ ] Backup realizado

---

## 🎯 PRÓXIMOS PASOS

1. Completar migración de POL
2. Analizar estructura Firebird de otras bibliotecas
3. Crear tabla de mapeo de campos
4. Exportar datos de otras bibliotecas
5. Importar todas las bibliotecas
6. Configurar sincronización automática

---

Fecha: 2025-01-15
Sistema: Koha + Firebird 2.7.5
