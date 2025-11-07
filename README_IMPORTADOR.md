# Importador Automático para Koha - UNA

## 🚀 Inicio Rápido

### Importar un archivo CSV

```bash
./importador_automatico_completo.sh archivo.csv
```

### Importar todos los archivos en `importar_aqui/`

```bash
./importador_automatico_completo.sh --all
```

¡Eso es todo! El sistema hará todo automáticamente.

---

## ✨ Características

El importador es **completamente automático y transparente**:

- ✅ **Detección automática** de la biblioteca por nombre de archivo
- ✅ **Generación de MARCXML** con parámetros optimizados
- ✅ **Limpieza automática** de namespaces XML
- ✅ **Importación con items** (ejemplares asociados)
- ✅ **Reindexación automática** de Zebra
- ✅ **Logs detallados** de cada proceso
- ✅ **Organización automática** de archivos (procesados/errores)
- ✅ **Reportes finales** con estadísticas

---

## 📁 Estructura de Directorios

```
migradatos/
├── importar_aqui/          ← Coloca tus archivos CSV aquí
├── procesados/             ← Archivos importados exitosamente
├── errores/                ← Archivos con errores
├── exports/                ← Archivos MARCXML generados
└── logs/                   ← Logs detallados de cada importación
```

---

## 📝 Uso Detallado

### 1. Importar un solo archivo

Simplemente ejecuta:

```bash
./importador_automatico_completo.sh importar_aqui/CODIGO.csv
```

**Ejemplo:**
```bash
./importador_automatico_completo.sh importar_aqui/QGY.csv
```

El sistema automáticamente:
1. Detecta que es la biblioteca "QGY"
2. Verifica que existe en Koha
3. Genera el MARCXML
4. Limpia los namespaces
5. Importa los registros bibliográficos
6. Importa los items (ejemplares)
7. Reindexacódigo de biblioteca
8. Mueve el archivo a `procesados/`

### 2. Importar múltiples archivos

```bash
./importador_automatico_completo.sh importar_aqui/*.csv
```

O para procesar todo lo que hay en `importar_aqui/`:

```bash
./importador_automatico_completo.sh --all
```

---

## 📊 Nomenclatura de Archivos

Los archivos CSV deben tener el **código de la biblioteca** como nombre:

- ✅ `QGY.csv` → Biblioteca QGY
- ✅ `DCSSP.csv` → Biblioteca DCSSP
- ✅ `BFIA.csv` → Biblioteca BFIA
- ❌ `biblioteca_quimica.csv` → No funcionará

---

## 🔍 Verificar Resultados

### Ver items importados

```bash
sudo koha-mysql koha-cnc -e "
SELECT
  b.branchcode AS Código,
  b.branchname AS Biblioteca,
  COUNT(i.itemnumber) AS Items
FROM branches b
LEFT JOIN items i ON b.branchcode = i.homebranch
WHERE b.branchcode = 'QGY'
GROUP BY b.branchcode;"
```

### Ver log detallado

```bash
tail -100 logs/importacion_YYYYMMDD_HHMMSS.log
```

El nombre del log se muestra al final de cada importación.

---

## ⚙️ Configuración Avanzada

Si necesitas modificar parámetros, edita las variables al inicio del script:

```bash
readonly LOC_DEFAULT="SALA"        # Ubicación por defecto
readonly COMMIT_SIZE="500"         # Registros por commit
readonly SPLIT_SIZE="2000"         # Registros por archivo XML
```

---

## 🔧 Solución de Problemas

### El archivo no se procesa

**Causa posible:** El código de biblioteca no existe en Koha

**Solución:** Verifica que la biblioteca existe:
```bash
sudo koha-mysql koha-cnc -e "SELECT branchcode, branchname FROM branches;"
```

### Los items no se importan

**Causa:** Este problema ya fue resuelto. El script usa `-m MARCXML` correctamente.

**Verificación:** Revisa el log de importación en `logs/`

### Error al generar MARCXML

**Causa posible:** Archivo CSV mal formado

**Solución:**
1. Revisa que el CSV esté en formato UTF-8
2. Verifica que tenga las columnas correctas
3. Consulta el log en `logs/`

---

## 📈 Estadísticas del Sistema

Ver estado general de Koha:

```bash
sudo koha-mysql koha-cnc -e "
SELECT
  'Biblios' as Tipo,
  FORMAT(COUNT(*), 0) as Total
FROM biblio
UNION ALL
SELECT 'Items', FORMAT(COUNT(*), 0)
FROM items
UNION ALL
SELECT 'Bibliotecas activas', COUNT(DISTINCT homebranch)
FROM items;"
```

---

## 📋 Archivos Procesados Correctamente (2025-11-04 al 2025-11-05)

| Código | Biblioteca | Items | Fecha |
|--------|-----------|-------|-------|
| DCSSP | Derecho CC.SS. San Pedro | 398 | 2025-11-04 |
| DESCP | Escuela CC.SS. y Políticas | 1,082 | 2025-11-04 |
| DGICT | Archivo Investigación DGICT | 1,094 | 2025-11-04 |
| ISA | Instituto Superior de Arte | 202 | 2025-11-04 |
| VETSE | CC. Veterinarias San Estanislao | 276 | 2025-11-04 |
| QGY | CC. Químicas Guayaiby | 71 | 2025-11-04 |
| BFIA | Fac. Ingeniería Filial Ayolas | 313 | 2025-11-04 |

**Total: 3,436 items importados**

---

## 🆘 Soporte

Para problemas o dudas:

1. **Revisar logs:** `logs/importacion_*.log`
2. **Verificar errores:** Archivos en `errores/`
3. **Consultar guía:** `GUIA_IMPORTACION.md`

---

## 📜 Licencia

Sistema desarrollado para la Universidad Nacional de Asunción (UNA)
Versión 3.0 - Noviembre 2025

---

**¡El importador está listo para usar! Solo coloca tus archivos CSV en `importar_aqui/` y ejecuta el script.**
