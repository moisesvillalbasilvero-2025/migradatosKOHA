# 📊 ANÁLISIS DEL SISTEMA ACTUAL Y PLAN DE ACCIÓN

## SITUACIÓN ACTUAL

###  Archivos Encontrados

1. **opac_exportar.py** (16KB)
   - Script existente de conversión CSV → MARCXML
   - Versión 6.0 - Ya tiene modo streaming y split
   - Específicamente diseñado para tu estructura
   - ✅ MUY BIEN DISEÑADO - Usar como base

2. **POL.csv** (11MB)
   - 12,467 registros bibliográficos
   - Biblioteca POL (Politécnica o similar)
   - Delimitador: `;` (punto y coma)
   - Encoding: UTF-8

### Campos en el CSV

```
codbiblio, analisis, nro_serie, titulo, titulo_serie, otro_titulo,
sub_titulo, autor, autorinst, mencion, volumen, nroacceso, nro_articulo,
ubicacion, tipomaterial, forma_adqui, copyright, editorial, edicion,
ejemplar, publicacion, procedencia, sintesis, fechacarga, paginaweb,
direccion_url, serie_mon, emailautor, idioma_descrip, nom_frecuencia,
isbn_issn, medio_descrip, nom_pais, codautor, tipo, temas_descrip,
...
```

### Mapeo Actual (952)
Tu script ya está alineado correctamente:
- `952$a` → homebranch (OBLIGATORIO) ✅
- `952$b` → holdingbranch ✅
- `952$c` → location (LOC) ✅
- `952$o` → itemcallnumber (signatura) ✅
- `952$p` → barcode ✅
- `952$y` → itemtype ✅

---

## ✅ PUNTOS FUERTES DEL SISTEMA ACTUAL

1. **Modo streaming implementado** - Bajo uso de memoria
2. **Split automático** - Divide en lotes configurables
3. **Detección automática de encoding y delimitador**
4. **Mapeo flexible de columnas** - Detecta variantes de nombres
5. **Generación correcta de MARCXML**
6. **Control por --codbiblio** - Asigna biblioteca por lote

---

## ⚠️ GAPS IDENTIFICADOS

### 1. Falta Conexión Directa a Firebird
El script actual solo procesa CSV, pero necesitas:
- Conexión directa a servidores Firebird remotos
- Sincronización automática programada
- Detección de cambios y actualizaciones

### 2. No hay Sistema de Sincronización
Falta:
- Detección de duplicados
- Actualización de registros existentes
- Programación automática (cron)
- Estado/historial de sincronizaciones

### 3. No hay Validación Pre-Importación
Necesitas:
- Validar que bibliotecas existan en Koha
- Verificar barcodes únicos
- Validar tipos de ítem y ubicaciones
- Control de calidad de datos

### 4. No hay Integración con Koha
Falta:
- Importación automática a Koha
- Rebuild de índices
- Manejo de errores de importación
- Rollback si falla

---

## 🎯 PLAN DE ACCIÓN RECOMENDADO

### FASE 1: MIGRACIÓN INICIAL (URGENTE)

#### Paso 1.1: Usar Tu Script Actual (opac_exportar.py)

```bash
cd /home/mvillalba/migradatos

# Generar MARCXML de POL con split cada 5000 registros
python3 opac_exportar.py \
  -i POL.csv \
  --codbiblio POL \
  --loc-default SALA \
  --stream \
  --split-by 5000

# Resultado: POL_20251015_marcxml_01.xml, _02.xml, _03.xml...
```

#### Paso 1.2: Validar MARCXML Generado

```bash
# Validar XML
for file in POL_*.xml; do
  echo "Validando $file..."
  xmllint --noout "$file" && echo "✓ OK" || echo "✗ ERROR"
done

# Ver estadísticas
wc -l POL_*.xml
grep -c "<record>" POL_*.xml
```

#### Paso 1.3: Importar a Koha (Primer Lote de Prueba)

```bash
# Importar primer archivo (5000 registros)
sudo koha-shell koha-cnc -c "
  bulkmarcimport.pl \
    -file /home/mvillalba/migradatos/POL_20251015_marcxml_01.xml \
    -biblios \
    -commit 1000 \
    -m MARCXML \
    -framework '' \
    -v
"

# Verificar en OPAC que se vean correctamente
```

#### Paso 1.4: Si OK, Importar Todo

```bash
# Script para importar todos los archivos
for file in /home/mvillalba/migradatos/POL_*.xml; do
  echo "==================================="
  echo "Importando: $file"
  echo "==================================="

  sudo koha-shell koha-cnc -c "
    bulkmarcimport.pl \
      -file $file \
      -biblios \
      -commit 1000 \
      -m MARCXML \
      -framework '' \
      -v
  "

  echo "✓ Completado: $file"
  echo ""
done

# Reconstruir índices
echo "Reconstruyendo índices..."
sudo koha-rebuild-zebra -f -v koha-cnc
```

### FASE 2: PREPARAR OTRAS BIBLIOTECAS

Para cada biblioteca adicional, necesitas obtener el CSV exportado desde Firebird.

#### Opción A: Exportar desde Firebird manualmente

```sql
-- En cada servidor Firebird, ejecutar:
SELECT
  'FACAGR' AS codbiblio,  -- Cambiar por cada facultad
  id_registro AS analisis,
  titulo,
  sub_titulo,
  autor,
  autor_institucional AS autorinst,
  editorial,
  ano_publicacion AS publicacion,
  lugar_publicacion AS procedencia,
  isbn,
  clasificacion AS ubicacion,
  codigo_barras AS nroacceso,
  tipo_material AS tipomaterial,
  -- etc...
FROM bibliograficos b
LEFT JOIN ejemplares e ON b.id = e.id_biblio
ORDER BY b.id;

-- Exportar a CSV con delimitador ;
```

#### Opción B: Script Python para Exportar desde Firebird

Voy a crear un script helper para esto.

### FASE 3: SISTEMA DE SINCRONIZACIÓN AUTOMÁTICA

Una vez migrados todos los datos iniciales, implementar el sistema de sincronización que te creé anteriormente.

---

## 📋 CHECKLIST INMEDIATO

### Para Biblioteca POL (LISTO)

- [x] CSV disponible (POL.csv - 12,467 registros)
- [x] Script de conversión funcional (opac_exportar.py)
- [ ] Código de biblioteca creado en Koha (POL)
- [ ] Ubicaciones (LOC) creadas en Koha
- [ ] Tipos de ítem configurados en Koha
- [ ] Generar MARCXML
- [ ] Validar MARCXML
- [ ] Importar lote de prueba (primeros 5000)
- [ ] Verificar visualización en OPAC
- [ ] Importar completo
- [ ] Reconstruir índices

### Para Otras Bibliotecas

- [ ] FACAGR - Obtener CSV o conexión Firebird
- [ ] FACEN - Obtener CSV o conexión Firebird
- [ ] FACMED - Obtener CSV o conexión Firebird
- [ ] FACDER - Obtener CSV o conexión Firebird
- [ ] ... (otras facultades)

---

## 🔧 CONFIGURACIÓN REQUERIDA EN KOHA

### 1. Crear Códigos de Bibliotecas

```
Administration > Libraries > New library

Código: POL
Nombre: Biblioteca Politécnica

Código: FACAGR
Nombre: Facultad de Ciencias Agrarias

Código: FACEN
Nombre: Facultad de Ciencias Exactas y Naturales

# etc...
```

### 2. Crear Ubicaciones (LOC)

```
Administration > Authorized values > LOC

SALA = Sala de lectura
REF  = Referencia
DEP  = Depósito
TESIS = Tesis
```

### 3. Crear/Verificar Tipos de Ítem

```
Administration > Item types

BK = Libro (Book)
MG = Revista/Magazine
VM = Material visual (Video)
MU = Música (CD)
MP = Mapa
TES = Tesis
```

---

## 📊 ESTADÍSTICAS POL.CSV

```
Total registros: 12,467
Tamaño: 11 MB

Tipos de material detectados:
- Monografía (mayoría)
- Libro
- Tesis
- Revista

Años de publicación: 1966-2025
Idiomas: Español (spa) principalmente

Campos con datos:
✓ Título
✓ Autor (mayoría)
✓ Editorial
✓ Año publicación
✓ Ubicación/signatura
✓ Código de barras
✓ Materias/temas

Campos con problemas:
⚠ ISBN: Solo algunos registros
⚠ Resumen: Pocos registros
```

---

## 🚀 COMANDOS RÁPIDOS

### Generar MARCXML de POL

```bash
cd /home/mvillalba/migradatos

python3 opac_exportar.py \
  -i POL.csv \
  --codbiblio POL \
  --loc-default SALA \
  --stream \
  --split-by 5000
```

### Importar a Koha

```bash
# Función helper para importar
import_to_koha() {
  local file=$1
  echo "Importando $file..."

  sudo koha-shell koha-cnc -c "
    bulkmarcimport.pl \
      -file $file \
      -biblios \
      -commit 1000 \
      -m MARCXML \
      -framework '' \
      -v 2>&1
  " | tee -a import_log.txt

  return ${PIPESTATUS[0]}
}

# Importar todos
for f in POL_*_marcxml_*.xml; do
  import_to_koha "$f" || {
    echo "ERROR en $f"
    break
  }
done

# Rebuild índices
sudo koha-rebuild-zebra -f -v koha-cnc
```

### Verificar Importación

```bash
# Contar registros importados
sudo koha-mysql koha-cnc -e "
  SELECT
    COUNT(*) as total_biblios
  FROM biblio
"

# Contar ítems por biblioteca
sudo koha-mysql koha-cnc -e "
  SELECT
    homebranch,
    COUNT(*) as total_items
  FROM items
  GROUP BY homebranch
"
```

---

## 📝 PRÓXIMOS PASOS

1. **HOY - URGENTE:**
   - Crear bibliotecas/ubicaciones/tipos en Koha
   - Generar MARCXML de POL
   - Importar lote de prueba (5000 registros)
   - Verificar visualización en OPAC

2. **ESTA SEMANA:**
   - Si prueba OK, importar POL completo
   - Obtener CSV/datos de otras bibliotecas
   - Documentar estructura Firebird real

3. **PRÓXIMA SEMANA:**
   - Migrar bibliotecas restantes
   - Implementar sistema de sincronización
   - Configurar cron para updates automáticos

---

## 🆘 NECESITO DE TI

1. **Acceso a Servidores Firebird:**
   - IPs de cada servidor
   - Puerto (default 3050)
   - Usuario/password
   - Ruta de cada base de datos

2. **Estructura Real de Firebird:**
   - Nombres exactos de tablas
   - Nombres exactos de columnas
   - Relaciones entre tablas

3. **Definir Códigos:**
   - Código corto para cada biblioteca (POL, FACAGR, etc.)
   - Mapeo de ubicaciones (¿cómo se llaman en Firebird vs Koha?)
   - Mapeo de tipos de material

---

**ESTADO:** ✅ Listo para comenzar migración de POL
**PRIORIDAD:** Configurar Koha y ejecutar primera importación

