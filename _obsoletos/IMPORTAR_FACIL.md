# IMPORTAR NUEVA BIBLIOTECA - GUÍA ULTRA RÁPIDA
Universidad Nacional de Asunción - Sistema Koha

## UN SOLO COMANDO

```bash
./importar_nueva_biblioteca.sh CODIGO /ruta/al/archivo.csv
```

## EJEMPLO REAL

```bash
# Importar Facultad de Ciencias Exactas
./importar_nueva_biblioteca.sh FACEN /tmp/FACEN_20251021.csv

# Importar Medicina
./importar_nueva_biblioteca.sh MED datos/MED_20251021.csv
```

---

## REQUISITO PREVIO

**IMPORTANTE:** La biblioteca debe existir en Koha ANTES de importar.

### Crear biblioteca en Koha (2 minutos):

1. Abrir Staff Interface: http://servidor:8080/cgi-bin/koha/mainpage.pl
2. Ir a: **Administración → Bibliotecas y grupos**
3. Clic: **Nueva biblioteca**
4. Llenar:
   - **Código:** CODIGO (ej: FACEN, MED, etc.)
   - **Nombre:** Nombre completo de la facultad
5. **Guardar**

✓ Listo. Ya puedes ejecutar el script.

---

## QUÉ HACE EL SCRIPT AUTOMÁTICAMENTE

El script hace TODO por ti:

1. ✓ Copia el CSV al directorio de trabajo
2. ✓ Analiza el CSV
3. ✓ Verifica que la biblioteca exista en Koha
4. ✓ Detecta si ya hay registros (evita duplicados)
5. ✓ Genera MARCXML automáticamente
6. ✓ Valida el XML
7. ✓ Importa a Koha
8. ✓ Reconstruye índices
9. ✓ Verifica la importación
10. ✓ Genera reporte completo

---

## FORMATO DEL CSV

El CSV debe tener este formato:

```
codigo,inventario,autor,titulo,editorial,edicion,...
001,12345,García,El libro,Editorial XYZ,2023,...
002,12346,Pérez,Otro libro,Editorial ABC,2022,...
```

**Importante:**
- Primera fila = nombres de columnas
- Separador: coma (,)
- Encoding: UTF-8
- Extensión: .csv

---

## NOMBRES DE ARCHIVO RECOMENDADOS

Formato: `CODIGO_YYYYMMDD.csv`

Ejemplos:
- `FACEN_20251021.csv`
- `MED_20251021.csv`
- `DER_20251021.csv`

---

## VERIFICAR LA IMPORTACIÓN

### Opción 1: En el OPAC (para usuarios)

```
http://servidor:8080/cgi-bin/koha/opac-search.pl?branch=CODIGO
```

### Opción 2: En MySQL (técnico)

```bash
sudo koha-mysql koha-cnc -e "
SELECT homebranch, COUNT(*) as total
FROM items
WHERE homebranch = 'CODIGO'
GROUP BY homebranch"
```

### Opción 3: Ver el reporte

```bash
cat logs/importacion_CODIGO_20251021.log
```

---

## PREGUNTAS FRECUENTES

### ¿Puedo importar el mismo CSV dos veces?

Sí, pero se duplicarán los registros. El script te advertirá si ya existen items.

### ¿Qué pasa si hay errores en el CSV?

El script detectará errores en el paso de validación XML y te avisará.

### ¿Cuánto tarda?

- 1,000 registros: ~5 minutos
- 5,000 registros: ~20 minutos
- 10,000+ registros: ~40 minutos

### ¿Puedo cancelar a la mitad?

Sí (Ctrl+C), pero los registros ya importados quedarán en Koha.

### ¿Necesito ser root?

No, pero necesitas permisos sudo para koha-shell y koha-mysql.

---

## EJEMPLO COMPLETO

```bash
# 1. Recibir CSV de la facultad
# Archivo recibido: /tmp/datos_facen.csv

# 2. Crear biblioteca en Koha (Staff Interface)
# Código: FACEN
# Nombre: Facultad de Ciencias Exactas y Naturales

# 3. Ejecutar importación
./importar_nueva_biblioteca.sh FACEN /tmp/datos_facen.csv

# 4. Esperar... (el script hace todo)

# 5. Ver resultado en OPAC
# http://servidor:8080/cgi-bin/koha/opac-search.pl?branch=FACEN

# ✓ Listo!
```

---

## TROUBLESHOOTING RÁPIDO

| Error | Solución |
|-------|----------|
| "biblioteca NO existe en Koha" | Crear biblioteca en Staff Interface primero |
| "archivo no encontrado" | Verificar ruta del CSV |
| "XML inválido" | Revisar caracteres especiales en CSV |
| "permisos denegados" | Agregar sudo antes del comando |

---

## ARCHIVOS GENERADOS

Después de la importación encontrarás:

```
/home/mvillalba/migradatos/
├── FACEN_20251021.csv              ← CSV copiado
├── exports/
│   ├── FACEN_20251021_marcxml_01.xml  ← XML generado
│   └── FACEN_20251021_marcxml_02.xml
└── logs/
    └── importacion_FACEN_20251021.log ← Reporte
```

---

## RESUMEN

### Para importar una nueva biblioteca:

1. **Crear biblioteca en Koha** (Staff Interface)
2. **Ejecutar:** `./importar_nueva_biblioteca.sh CODIGO archivo.csv`
3. **Esperar** (el script hace todo automáticamente)
4. **Verificar** en OPAC

**¡Así de simple!**

---

## SOPORTE

- Documentación completa: `cat COMO_IMPORTAR_NUEVA_BIBLIOTECA.md`
- Ver scripts disponibles: `ls -lh *.sh`
- Logs: `ls -lh logs/`

---

Fecha: 2025-10-21
Sistema: Migración Automatizada UNA → Koha
Versión: 2.0
