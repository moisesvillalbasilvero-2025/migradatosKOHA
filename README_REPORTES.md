# 📊 Sistema de Reportes Estadísticos - Koha UNA

Sistema completo de generación de reportes estadísticos sobre el catálogo bibliográfico.

---

## 📋 Características

✅ **Reporte por biblioteca** con títulos y ejemplares
✅ **Ranking visual** con gráficos ASCII y barras de progreso
✅ **Estadísticas generales** del sistema completo
✅ **Actividad reciente** (últimas 24h, 7 días, 30 días)
✅ **Exportación múltiple**: TXT, HTML, CSV, JSON
✅ **Generación automática** después de cada importación
✅ **Reportes visuales** con gráficos y diseño profesional

---

## 🚀 Uso Rápido

### Generar Reporte Completo

```bash
./generar_reporte_estadistico.sh
```

El reporte se genera automáticamente en formato texto y se guarda en `reportes/`.

### Exportar a HTML (Recomendado)

```bash
./generar_reporte_estadistico.sh --html
```

Genera un reporte HTML interactivo con:
- Diseño moderno y profesional
- Gráficos visuales con barras de progreso
- Ranking con medallas (🥇🥈🥉)
- Estadísticas en tarjetas destacadas
- Responsive para móviles

### Exportar a Todos los Formatos

```bash
./generar_reporte_estadistico.sh --all
```

Genera reportes en TXT, HTML, CSV y JSON simultáneamente.

---

## 📊 Tipos de Reportes

### 1. Reporte General

Muestra todas las bibliotecas del sistema con:
- Código de biblioteca
- Nombre completo
- Número de títulos únicos
- Número de ejemplares totales
- Gráficos ASCII de distribución

**Ejemplo:**
```
═══════════════════════════════════════════════════════════════════════════
📚 DETALLE POR BIBLIOTECA
═══════════════════════════════════════════════════════════════════════════

┌─────────┬──────────────────────────────────┬───────────┬────────────┐
│ Código  │ Nombre                           │ Títulos   │ Ejemplares │
├─────────┼──────────────────────────────────┼───────────┼────────────┤
│ ING     │ Facultad de Ingeniería           │     5,234 │     12,567 │
│         │ ████████████████████████████████ │           │            │
│ MED     │ Facultad de Medicina             │     3,891 │      8,432 │
│         │ ████████████████████░░░░░░░░░░░░ │           │            │
│ POL     │ Facultad Politécnica             │     2,456 │      6,123 │
│         │ ████████████░░░░░░░░░░░░░░░░░░░░ │           │            │
└─────────┴──────────────────────────────────┴───────────┴────────────┘
```

### 2. Top 10 Bibliotecas

Ranking de las 10 bibliotecas con más ejemplares:

```
═══════════════════════════════════════════════════════════════════════════
🏆 TOP 10 BIBLIOTECAS POR CANTIDAD DE EJEMPLARES
═══════════════════════════════════════════════════════════════════════════

🥇 #1   ING       Facultad de Ingeniería
        Títulos: 5,234 | Ejemplares: 12,567
        ████████████████████████████████████████████████████████████

🥈 #2   MED       Facultad de Medicina
        Títulos: 3,891 | Ejemplares: 8,432
        ████████████████████████████████████░░░░░░░░░░░░░░░░░░░░░░░

🥉 #3   POL       Facultad Politécnica
        Títulos: 2,456 | Ejemplares: 6,123
        ████████████████████░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
```

### 3. Actividad Reciente

Muestra nuevos registros agregados:

```
═══════════════════════════════════════════════════════════════════════════
📅 ACTIVIDAD RECIENTE (Nuevos Registros)
═══════════════════════════════════════════════════════════════════════════

Últimas 24 horas:
  • Títulos agregados:    124
  • Ejemplares agregados:  342

Últimos 7 días:
  • Títulos agregados:    856
  • Ejemplares agregados:  2,341

Últimos 30 días:
  • Títulos agregados:    3,421
  • Ejemplares agregados:  9,876
```

### 4. Reporte de Biblioteca Específica

```bash
./generar_reporte_estadistico.sh --biblioteca ING
```

Genera un reporte detallado solo para la biblioteca ING.

---

## 📁 Formatos de Exportación

### Texto (TXT) - Por Defecto

- Formato legible en terminal
- Con colores ANSI
- Gráficos ASCII
- Ideal para: logs, debugging, terminal

**Ubicación:** `reportes/estadisticas_YYYYMMDD_HHMMSS.txt`

### HTML - Recomendado

- Diseño moderno y profesional
- Gráficos interactivos con CSS
- Colores degradados
- Ranking con medallas
- Responsive (móviles/tablets)
- Ideal para: presentaciones, reportes ejecutivos

**Ubicación:** `reportes/estadisticas_YYYYMMDD_HHMMSS.html`

**Vista previa:**
- Tarjetas con estadísticas destacadas
- Tablas con hover effects
- Barras de progreso animadas
- Ranking visual con badges

### CSV - Para Análisis

- Formato separado por comas
- Compatible con Excel/LibreOffice
- Ideal para: análisis de datos, gráficos externos

**Formato:**
```csv
Codigo,Nombre,Titulos,Ejemplares
ING,"Facultad de Ingeniería",5234,12567
MED,"Facultad de Medicina",3891,8432
POL,"Facultad Politécnica",2456,6123
```

**Ubicación:** `reportes/estadisticas_YYYYMMDD_HHMMSS.csv`

### JSON - Para Programación

- Formato estructurado
- Compatible con APIs
- Ideal para: integraciones, automatizaciones

**Formato:**
```json
{
  "fecha_generacion": "2025-11-04 10:30:00",
  "instancia": "koha-cnc",
  "resumen": {
    "total_bibliotecas": 25,
    "total_titulos": 45678,
    "total_ejemplares": 123456,
    "total_usuarios": 5678,
    "bibliotecas_con_items": 20
  },
  "bibliotecas": [
    {
      "codigo": "ING",
      "nombre": "Facultad de Ingeniería",
      "titulos": 5234,
      "ejemplares": 12567
    }
  ]
}
```

**Ubicación:** `reportes/estadisticas_YYYYMMDD_HHMMSS.json`

---

## 🎯 Opciones Disponibles

```bash
./generar_reporte_estadistico.sh [OPCIONES]

Opciones:
  --biblioteca CODIGO    Reporte de una biblioteca específica
  --html                 Exportar a HTML
  --csv                  Exportar a CSV
  --json                 Exportar a JSON
  --all                  Exportar a todos los formatos
  --no-graficos          Sin gráficos ASCII (más rápido)
  --help, -h             Mostrar ayuda
```

---

## 📊 Ejemplos de Uso

### Ejemplo 1: Reporte Básico

```bash
./generar_reporte_estadistico.sh
```

**Salida:**
- Reporte en texto con todos los datos
- Guardado en `reportes/estadisticas_20251104_103045.txt`

### Ejemplo 2: Reporte HTML para Presentación

```bash
./generar_reporte_estadistico.sh --html
```

**Salida:**
- Reporte HTML profesional
- Abre con navegador: `firefox reportes/estadisticas_20251104_103045.html`

### Ejemplo 3: Datos para Excel

```bash
./generar_reporte_estadistico.sh --csv
```

**Salida:**
- Archivo CSV listo para importar
- Abre con Excel: `libreoffice reportes/estadisticas_20251104_103045.csv`

### Ejemplo 4: Todas las Exportaciones

```bash
./generar_reporte_estadistico.sh --all
```

**Salida:**
- 4 archivos: TXT, HTML, CSV, JSON
- Todos con el mismo timestamp

### Ejemplo 5: Reporte de una Biblioteca

```bash
./generar_reporte_estadistico.sh --biblioteca ING --html
```

**Salida:**
- Reporte HTML solo con datos de Ingeniería
- Útil para enviar a coordinadores de biblioteca

---

## 🔄 Generación Automática

### Durante Importación

Los reportes se generan **automáticamente** al final de cada importación exitosa:

```bash
./importar_rapido.sh archivo.csv
```

Al finalizar:
1. ✓ Importación completada
2. 📊 Generando reporte estadístico...
3. ✓ Reporte estadístico generado
4. ℹ Reportes disponibles en: reportes/

### Desactivar Generación Automática

Si no quieres reportes automáticos:

```bash
python3 importar_ultra_optimizado.py archivo.csv --no-reporte
```

---

## 📈 Casos de Uso

### Caso 1: Reporte Mensual para Dirección

```bash
# Generar reporte HTML completo
./generar_reporte_estadistico.sh --html

# Enviar por email
# El archivo HTML se puede adjuntar directamente
```

### Caso 2: Análisis de Crecimiento

```bash
# Generar reportes antes y después de importación
./generar_reporte_estadistico.sh --csv --json

# Comparar archivos CSV con herramientas de análisis
```

### Caso 3: Verificación Post-Importación

```bash
# Después de importar, verificar nueva biblioteca
./generar_reporte_estadistico.sh --biblioteca ING --html
```

### Caso 4: Dashboard Ejecutivo

```bash
# Generar todos los formatos para diferentes audiencias
./generar_reporte_estadistico.sh --all

# TXT: para logs/terminal
# HTML: para presentaciones
# CSV: para análisis en Excel
# JSON: para dashboard web
```

---

## 🎨 Personalización

### Modificar Diseño HTML

El HTML se genera dinámicamente. Para personalizar:

1. Edita `generar_reporte_estadistico.sh`
2. Busca la sección `exportar_html()`
3. Modifica el CSS inline según necesites

**Colores predeterminados:**
- Primario: `#667eea` (morado-azul)
- Secundario: `#764ba2` (morado oscuro)
- Fondo: Degradado entre primario y secundario

### Añadir Más Estadísticas

Para agregar nuevos datos al reporte:

1. Crea una función SQL en `generar_reporte_estadistico.sh`
2. Llama la función en `generar_reporte_completo()`
3. Actualiza también `exportar_html()`, `exportar_csv()` y `exportar_json()`

---

## 📂 Estructura de Reportes

```
reportes/
├── estadisticas_20251104_103045.txt     # Texto con colores
├── estadisticas_20251104_103045.html    # HTML profesional
├── estadisticas_20251104_103045.csv     # CSV para Excel
├── estadisticas_20251104_103045.json    # JSON para APIs
├── estadisticas_20251103_152030.txt     # Reportes anteriores
└── ...
```

**Nombre de archivos:** `estadisticas_YYYYMMDD_HHMMSS.{txt|html|csv|json}`

---

## 🔍 Datos Incluidos en Reportes

### Resumen General
- Total de bibliotecas en el sistema
- Bibliotecas con ítems vs sin ítems
- Total de títulos únicos
- Total de ejemplares
- Promedio de ejemplares por título
- Total de usuarios registrados

### Por Biblioteca
- Código de biblioteca
- Nombre completo
- Número de títulos únicos
- Número de ejemplares totales
- Distribución visual (gráficos)

### Ranking
- Top 10 bibliotecas por ejemplares
- Top 10 bibliotecas por títulos
- Medallas visuales (🥇🥈🥉)

### Actividad Reciente
- Nuevos registros últimas 24 horas
- Nuevos registros últimos 7 días
- Nuevos registros últimos 30 días

---

## 💡 Consejos y Mejores Prácticas

### 1. Genera Reportes Regularmente

```bash
# Crear tarea cron para reportes semanales
0 9 * * 1 /home/mvillalba/migradatos/generar_reporte_estadistico.sh --html
```

### 2. Compara Reportes Históricos

```bash
# Guarda reportes con nombres descriptivos
mv reportes/estadisticas_20251104_103045.csv reportes/noviembre_2025.csv
```

### 3. Usa HTML para Presentaciones

El formato HTML es ideal para:
- Reuniones con dirección
- Reportes a rectorado
- Publicación en intranet
- Archivo histórico visual

### 4. Usa CSV para Análisis

El formato CSV es ideal para:
- Gráficos en Excel/LibreOffice
- Análisis estadístico en R/Python
- Comparaciones entre periodos
- Importación a otros sistemas

### 5. Automatiza Todo

```bash
# Script que importa Y genera reportes
./importar_rapido.sh nuevo_lote.csv
# Ya incluye generación automática de reportes
```

---

## 🐛 Troubleshooting

### Problema: "No se encontraron datos"

**Causa:** Base de datos vacía o sin permisos

**Solución:**
```bash
# Verificar conexión a BD
sudo koha-mysql koha-cnc -e "SELECT COUNT(*) FROM items"

# Verificar permisos
ls -l generar_reporte_estadistico.sh
chmod +x generar_reporte_estadistico.sh
```

### Problema: HTML no se genera

**Causa:** Caracteres especiales en nombres de bibliotecas

**Solución:** El script escapa automáticamente. Si persiste:
```bash
# Generar solo TXT primero
./generar_reporte_estadistico.sh

# Luego intentar HTML
./generar_reporte_estadistico.sh --html
```

### Problema: CSV con formato incorrecto

**Causa:** Comas en nombres de bibliotecas

**Solución:** Ya está implementado el escape automático. Si falla:
```bash
# Usar JSON en su lugar
./generar_reporte_estadistico.sh --json
```

### Problema: Reportes muy lentos

**Causa:** Base de datos grande

**Solución:**
```bash
# Desactivar gráficos para acelerar
./generar_reporte_estadistico.sh --no-graficos

# O generar solo una biblioteca
./generar_reporte_estadistico.sh --biblioteca ING
```

---

## 📞 Soporte

Para problemas con reportes:

1. Verifica logs del sistema
2. Prueba con `--no-graficos` para modo rápido
3. Intenta generar solo TXT primero
4. Consulta esta documentación

---

## 🎓 Recursos Adicionales

- `OPTIMIZACIONES.md` - Documentación del sistema optimizado
- `RESUMEN_OPTIMIZACIONES.txt` - Resumen ejecutivo
- `LEEME_PRIMERO.txt` - Guía de inicio rápido

---

**Universidad Nacional de Asunción**
**Sistema de Bibliotecas - Koha**
**Noviembre 2025**
