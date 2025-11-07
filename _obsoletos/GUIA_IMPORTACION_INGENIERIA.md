# 📚 GUÍA DE IMPORTACIÓN - FACULTAD DE INGENIERÍA

**Universidad Nacional de Asunción**
**Sistema Koha OPAC**

---

## 📋 ÍNDICE

1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Análisis del Archivo ING.csv](#análisis-del-archivo-ingcsv)
3. [Proceso de Corrección](#proceso-de-corrección)
4. [Importación de Prueba](#importación-de-prueba)
5. [Importación Completa](#importación-completa)
6. [Filtrado por Facultad de Ingeniería](#filtrado-por-facultad-de-ingeniería)
7. [Verificación Post-Importación](#verificación-post-importación)
8. [Troubleshooting](#troubleshooting)

---

## 🎯 RESUMEN EJECUTIVO

### Estado del Archivo

- **Archivo original:** `ING.csv`
- **Total de registros:** 15,010
- **Biblioteca:** ING (Facultad de Ingeniería)
- **Calidad de datos:** 67.2/100 (REGULAR)

### Problemas Detectados y Solucionados

✅ **SOLUCIONADO:** 15,003 códigos de acceso duplicados o vacíos
✅ **SOLUCIONADO:** Códigos únicos generados en formato ING-0000001 hasta ING-0014892
⚠️ **ATENCIÓN:** Campos con baja completitud: ISBN (31%), idioma (13%), resumen (15%)

### Archivos Generados

- `ING_corregido.csv` - Archivo con códigos de acceso únicos (LISTO PARA IMPORTAR)
- `corregir_codigos_ing.py` - Script de corrección
- `importar_ing_prueba.sh` - Script de importación de prueba (100 registros)
- `importar_ing_completo.sh` - Script de importación completa (15,010 registros)

---

## 📊 ANÁLISIS DEL ARCHIVO ING.csv

### Estructura Básica

```
Total de registros: 15,010
Total de columnas:  53
Encoding:          UTF-8
Separador:         ; (punto y coma)
```

### Campos Obligatorios (100% Completos) ✅

- ✅ `titulo` - 100.00% completo
- ✅ `nroacceso` - 100.00% completo (después de corrección)
- ✅ `codbiblio` - 100.00% completo (valor: "ING  ")
- ✅ `tipomaterial` - 100.00% completo

### Campos Críticos para OPAC

| Campo | Completitud | Estado |
|-------|-------------|--------|
| autor | 85.88% | ✅ EXCELENTE |
| temas_descrip | 93.62% | ✅ EXCELENTE |
| editorial | 97.44% | ✅ EXCELENTE |
| publicacion | 99.52% | ✅ EXCELENTE |
| ubicacion | 100.00% | ✅ EXCELENTE |
| isbn_issn | 31.43% | ⚠️ CRÍTICO |
| autorinst | 9.70% | ⚠️ CRÍTICO |
| idioma_descrip | 13.00% | ⚠️ CRÍTICO |
| sintesis | 15.68% | ⚠️ CRÍTICO |

### Duplicados Detectados

- ❌ **15,003** duplicados por código de acceso → **CORREGIDO**
- ⚠️ 1,034 duplicados por ISBN/ISSN (puede ser normal - múltiples ejemplares)
- ⚠️ 3,101 duplicados por título exacto
- ⚠️ 1,705 duplicados por título + autor

---

## 🔧 PROCESO DE CORRECCIÓN

### Paso 1: Análisis del Archivo

```bash
# Analizar el archivo original
python3 analizador_csv.py ING.csv
```

Este comando genera:
- Reporte de estructura
- Detección de campos faltantes
- Análisis de duplicados
- Puntuación de calidad
- Archivo JSON con resultados

### Paso 2: Corrección de Códigos de Acceso

```bash
# Corregir códigos duplicados
python3 corregir_codigos_ing.py ING.csv
```

**¿Qué hace este script?**

1. ✅ Detecta códigos vacíos (13,034 registros)
2. ✅ Detecta códigos duplicados (1,969 registros)
3. ✅ Genera códigos únicos secuenciales: ING-0000001, ING-0000002, etc.
4. ✅ Preserva códigos existentes válidos (118 registros)
5. ✅ Verifica unicidad (0 duplicados al final)
6. ✅ Guarda resultado en `ING_corregido.csv`

**Resultado:**
```
Total de registros:     15,010
Códigos corregidos:     14,892
Códigos preservados:    118
Archivo de salida:      ING_corregido.csv
```

---

## 🧪 IMPORTACIÓN DE PRUEBA

### ¿Por qué hacer una prueba primero?

- ✅ Verificar que el mapeo de campos es correcto
- ✅ Revisar cómo se ven los registros en el OPAC
- ✅ Detectar problemas antes de importar 15,000 registros
- ✅ Ajustar configuraciones si es necesario

### Ejecutar Importación de Prueba

```bash
# Importar solo 100 registros
./importar_ing_prueba.sh
```

**Proceso:**

1. ✅ Crea archivo `ING_prueba_100.csv` (primeros 100 registros)
2. ✅ Genera MARCXML
3. ✅ Importa a Koha
4. ✅ Reconstruye índices
5. ✅ Muestra resumen

**Tiempo estimado:** 2-5 minutos

### Verificar Resultados de la Prueba

1. **Acceder al OPAC**
   ```
   URL: http://[servidor-koha]:8080
   ```

2. **Buscar registros de Ingeniería**
   - Ir a "Búsqueda avanzada"
   - En "Biblioteca" seleccionar: ING
   - Buscar: * (para ver todos)

3. **Verificar:**
   - ✅ Aparecen 100 registros
   - ✅ Los títulos se ven correctamente
   - ✅ Los autores están presentes
   - ✅ Las materias (keywords) funcionan
   - ✅ Los códigos de barras son únicos (ING-0000001, etc.)

---

## 🚀 IMPORTACIÓN COMPLETA

### Prerequisitos

- ✅ Importación de prueba exitosa
- ✅ Verificación de registros en OPAC
- ✅ Respaldo de base de datos Koha (recomendado)

### Ejecutar Importación Completa

```bash
# Importar todos los 15,010 registros
./importar_ing_completo.sh
```

**Confirmación Requerida:**
```
⚠  ADVERTENCIA: Esta es una importación COMPLETA
   Se importarán 15,010 registros a Koha
   Este proceso puede tomar varios minutos

¿Está SEGURO de continuar? (escriba 'SI' para confirmar):
```

**Proceso:**

1. ✅ Verificar archivo `ING_corregido.csv`
2. ✅ Generar archivos MARCXML (divididos en lotes de 5,000)
3. ✅ Importar cada lote a Koha
4. ✅ Reconstruir índices Zebra
5. ✅ Generar log de importación
6. ✅ Mostrar resumen final

**Tiempo estimado:** 15-30 minutos (dependiendo del servidor)

### Monitoreo Durante la Importación

Durante la importación verá:
```
Importando: ING_20251020_marcxml_01.xml
✓ ING_20251020_marcxml_01.xml importado exitosamente

Importando: ING_20251020_marcxml_02.xml
✓ ING_20251020_marcxml_02.xml importado exitosamente

Importando: ING_20251020_marcxml_03.xml
✓ ING_20251020_marcxml_03.xml importado exitosamente
```

---

## 🔍 FILTRADO POR FACULTAD DE INGENIERÍA

### Método 1: Desde el OPAC (Usuarios Finales)

**Paso a paso:**

1. Acceder al OPAC: `http://[servidor]:8080`
2. Click en "Búsqueda avanzada"
3. En el campo "Buscar", ingresar término de búsqueda
4. En "Biblioteca", seleccionar: **ING - Facultad de Ingeniería**
5. Click en "Buscar"

**Ejemplo de búsqueda:**
```
Término: construcción
Biblioteca: ING - Facultad de Ingeniería
Tipo de material: [Todos]
```

### Método 2: Staff Interface (Bibliotecarios)

**Opción A: Filtro por Biblioteca**

1. Acceder al Staff Interface
2. Ir a "Búsqueda"
3. Usar filtros avanzados
4. Seleccionar "Biblioteca: ING"

**Opción B: Búsqueda por Código de Barras**

```
Buscar códigos que comiencen con: ING-
```

Esto mostrará solo registros de Ingeniería porque todos los códigos tienen el formato:
- ING-0000001
- ING-0000002
- ...
- ING-0014892

### Método 3: URL Directa

**Para usuarios finales:**
```
http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=ING
```

**Para Staff:**
```
http://[servidor]/cgi-bin/koha/cataloguing/search.pl?branch=ING
```

### Método 4: API (Programático)

```bash
# Consulta a la API de Koha
curl -X GET "http://[servidor]/api/v1/biblios?library_id=ING" \
  -H "Authorization: Bearer [token]"
```

---

## ✅ VERIFICACIÓN POST-IMPORTACIÓN

### Checklist de Verificación

- [ ] **Cantidad de registros**
  ```bash
  # Conectar a MySQL
  mysql -u koha_cnc -p

  # Contar registros de ING
  SELECT COUNT(*) FROM items WHERE homebranch = 'ING';
  ```
  Debe devolver: **15,010**

- [ ] **Códigos de barras únicos**
  ```sql
  SELECT COUNT(DISTINCT barcode) FROM items WHERE homebranch = 'ING';
  ```
  Debe devolver: **15,010**

- [ ] **Búsqueda en OPAC funciona**
  - Buscar por título
  - Buscar por autor
  - Buscar por materia
  - Filtrar por biblioteca ING

- [ ] **Índices Zebra actualizados**
  ```bash
  sudo koha-rebuild-zebra -f -v koha-cnc
  ```

### Estadísticas de la Importación

```sql
-- Registros por tipo de material
SELECT itype, COUNT(*)
FROM items
WHERE homebranch = 'ING'
GROUP BY itype;

-- Top 10 autores más frecuentes
SELECT author, COUNT(*) as cantidad
FROM biblio
INNER JOIN items ON biblio.biblionumber = items.biblionumber
WHERE items.homebranch = 'ING'
GROUP BY author
ORDER BY cantidad DESC
LIMIT 10;

-- Registros por año de publicación
SELECT copyrightdate, COUNT(*)
FROM biblioitems
INNER JOIN items ON biblioitems.biblionumber = items.biblionumber
WHERE items.homebranch = 'ING'
GROUP BY copyrightdate
ORDER BY copyrightdate DESC
LIMIT 20;
```

---

## 🛠️ TROUBLESHOOTING

### Problema 1: Códigos de Acceso Duplicados

**Síntoma:**
```
ERROR: Duplicate barcode 'ING-0000123'
```

**Solución:**
```bash
# Volver a ejecutar el corrector
python3 corregir_codigos_ing.py ING.csv ING_corregido_v2.csv
```

### Problema 2: Errores en la Importación MARCXML

**Síntoma:**
```
ERROR: Invalid MARCXML format
```

**Solución:**
```bash
# Regenerar MARCXML con verbose
cd exports
python3 /home/mvillalba/migradatos/opac_exportar.py \
  -i /home/mvillalba/migradatos/ING_corregido.csv \
  --codbiblio ING \
  --loc-default SALA \
  --stream \
  --verbose
```

### Problema 3: Índices Zebra No Actualizan

**Síntoma:**
Los registros no aparecen en búsquedas del OPAC

**Solución:**
```bash
# Detener Zebra
sudo koha-stop-zebra koha-cnc

# Limpiar índices
sudo rm -rf /var/lib/koha/koha-cnc/biblios/shadow/*
sudo rm -rf /var/lib/koha/koha-cnc/biblios/register/*

# Reconstruir desde cero
sudo koha-rebuild-zebra -f -v -a koha-cnc

# Reiniciar Zebra
sudo koha-start-zebra koha-cnc
```

### Problema 4: Registros No Filtran por Biblioteca

**Síntoma:**
Al filtrar por ING, aparecen registros de otras bibliotecas

**Solución:**
```bash
# Verificar que el campo homebranch esté correcto
mysql -u koha_cnc -p koha_cnc

SELECT DISTINCT homebranch FROM items;

# Debe aparecer 'ING' en la lista
```

### Problema 5: Caracteres Extraños en los Títulos

**Síntoma:**
Títulos con caracteres como: "Ã©", "Ã±", etc.

**Solución:**
```bash
# Verificar encoding del archivo CSV
file -i ING_corregido.csv

# Debe devolver: charset=utf-8

# Si no es UTF-8, convertir:
iconv -f LATIN1 -t UTF-8 ING.csv > ING_utf8.csv
```

---

## 📞 SOPORTE Y CONTACTO

### Logs del Sistema

- **Log de importación:** `/home/mvillalba/migradatos/logs/importacion_ing_*.log`
- **Log de Koha:** `/var/log/koha/koha-cnc/`
- **Log de Zebra:** `/var/log/koha/koha-cnc/zebra-*.log`

### Comandos Útiles

```bash
# Ver logs en tiempo real
tail -f /var/log/koha/koha-cnc/opac-error.log

# Verificar estado de servicios
sudo koha-list --enabled

# Reiniciar todos los servicios de Koha
sudo koha-plack --restart koha-cnc
sudo koha-zebra --restart koha-cnc
```

### Información de la Importación

- **Biblioteca:** ING (Facultad de Ingeniería)
- **Código de biblioteca:** ING
- **Total de registros:** 15,010
- **Formato de códigos:** ING-0000001 hasta ING-0014892
- **Ubicación por defecto:** SALA
- **Archivo fuente:** ING_corregido.csv

---

## 📝 RESUMEN DE COMANDOS

### Análisis y Corrección
```bash
# Analizar archivo original
python3 analizador_csv.py ING.csv

# Corregir códigos de acceso
python3 corregir_codigos_ing.py ING.csv
```

### Importación
```bash
# Importación de prueba (100 registros)
./importar_ing_prueba.sh

# Importación completa (15,010 registros)
./importar_ing_completo.sh
```

### Verificación
```bash
# Reconstruir índices
sudo koha-rebuild-zebra -f -v koha-cnc

# Ver logs
tail -f logs/importacion_ing_*.log
```

---

## ✅ CONCLUSIÓN

El archivo ING.csv ha sido:

1. ✅ **Analizado** - Calidad 67.2/100
2. ✅ **Corregido** - 14,892 códigos únicos generados
3. ✅ **Preparado** - Listo para importar con `ING_corregido.csv`
4. ✅ **Documentado** - Scripts y guías disponibles

**Archivos Clave:**
- `ING_corregido.csv` - Archivo LISTO para importar
- `importar_ing_prueba.sh` - Importar 100 registros de prueba
- `importar_ing_completo.sh` - Importar todos los registros
- `GUIA_IMPORTACION_INGENIERIA.md` - Esta guía

**Próximo Paso Recomendado:**
```bash
./importar_ing_prueba.sh
```

---

**Fecha de creación:** 2025-10-20
**Versión:** 1.0
**Sistema:** Koha MARC21 + Zebra
**Universidad Nacional de Asunción**
