# CÓMO IMPORTAR UNA NUEVA BIBLIOTECA
Universidad Nacional de Asunción - Sistema Koha

## PROCESO MANUAL (Paso a Paso)

Cuando recibes un nuevo archivo CSV de una biblioteca:

### 1. PREPARAR EL ARCHIVO CSV

```bash
# Copiar el archivo CSV al directorio de trabajo
# Formato recomendado: CODIGO_YYYYMMDD.csv
# Ejemplo: FACEN_20251021.csv

cp /ruta/origen/archivo.csv /home/mvillalba/migradatos/CODIGO_20251021.csv
```

### 2. VERIFICAR EL CSV

```bash
# Ver primeras líneas
head -n 5 CODIGO_20251021.csv

# Contar registros
wc -l CODIGO_20251021.csv

# Analizar estructura
python3 analizador_csv.py CODIGO_20251021.csv
```

### 3. CONFIGURAR EN KOHA (Staff Interface)

**Crear la biblioteca:**
- Staff → Administración → Bibliotecas
- Agregar biblioteca nueva:
  - Código: CODIGO (ej: FACEN)
  - Nombre: Facultad de ...
  - Activa: Sí

**Crear ubicación (opcional):**
- Staff → Administración → Ubicaciones
- Código biblioteca: CODIGO
- Ubicación: SALA (o la que corresponda)

### 4. GENERAR MARCXML

```bash
cd /home/mvillalba/migradatos/exports

python3 /home/mvillalba/migradatos/opac_exportar.py \
  -i /home/mvillalba/migradatos/CODIGO_20251021.csv \
  --codbiblio CODIGO \
  --loc-default SALA \
  --stream \
  --split-by 5000
```

### 5. VALIDAR XML GENERADO

```bash
# Buscar archivos generados
ls -lh CODIGO_*_marcxml*.xml

# Contar registros en XML
grep -c "<record>" CODIGO_*_marcxml_01.xml

# Validar sintaxis XML
xmllint --noout CODIGO_*_marcxml_01.xml
```

### 6. IMPORTAR A KOHA

```bash
# Para cada archivo XML generado:
sudo koha-shell koha-cnc -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
  -b \
  -m MARCXML \
  -file /home/mvillalba/migradatos/exports/CODIGO_*_marcxml_01.xml \
  -commit 1000"
```

### 7. RECONSTRUIR ÍNDICES

```bash
sudo koha-rebuild-zebra -f -v koha-cnc
```

### 8. VERIFICAR EN KOHA

```bash
# Ver cuántos items se importaron
sudo koha-mysql koha-cnc -e "
SELECT homebranch, COUNT(*) as total
FROM items
WHERE homebranch = 'CODIGO'
GROUP BY homebranch"
```

### 9. VERIFICAR EN OPAC

- Ir a: http://servidor:8080
- Búsqueda avanzada → Filtrar por biblioteca: CODIGO
- Revisar registros

---

## PROCESO AUTOMATIZADO (Recomendado)

### Opción A: Script Individual

```bash
# Ejecutar script de importación automática
./importar_nueva_biblioteca.sh CODIGO /ruta/al/archivo.csv
```

### Opción B: Configurar y Usar Sistema Automatizado

```bash
# 1. Editar configuración
nano migracion_config.json

# 2. Agregar la nueva biblioteca:
{
  "CODIGO": {
    "nombre": "Nombre de la Facultad",
    "tipo_fuente": "csv",
    "archivo_csv": "CODIGO_20251021.csv",
    "codigo_koha": "CODIGO",
    "loc_default": "SALA",
    "activa": true,
    "prioridad": 10
  }
}

# 3. Ejecutar migración
python3 migracion_automatizada.py --biblioteca CODIGO
```

---

## CHECKLIST RÁPIDO

- [ ] CSV copiado al directorio migradatos con nombre: CODIGO_YYYYMMDD.csv
- [ ] CSV analizado (estructura correcta)
- [ ] Biblioteca creada en Koha Staff (código + nombre)
- [ ] Ubicación creada en Koha (si aplica)
- [ ] MARCXML generado exitosamente
- [ ] XML validado (xmllint sin errores)
- [ ] Importación a Koha completada
- [ ] Índices reconstruidos
- [ ] Verificación en MySQL (count items)
- [ ] Verificación en OPAC (búsqueda funciona)
- [ ] Registro en bitácora/log

---

## FORMATO ESPERADO DEL CSV

El CSV debe tener estos campos (según tu configuración actual):

```
codigo,inventario,autor,titulo,... (otros campos)
```

**Importante:**
- Primera fila = headers
- Separador: coma (,)
- Codificación: UTF-8
- Sin BOM

---

## TIEMPOS ESTIMADOS

| Registros | Tiempo Total (aprox) |
|-----------|---------------------|
| 1,000     | 5-10 minutos        |
| 5,000     | 15-30 minutos       |
| 10,000    | 30-60 minutos       |
| 20,000+   | 1-2 horas           |

---

## PROBLEMAS COMUNES

### Error: "biblioteca no existe en Koha"
→ Crear biblioteca en Staff primero

### Error: "campos vacíos en CSV"
→ Verificar que CSV tenga todos los campos requeridos

### Error: "XML inválido"
→ Revisar datos en CSV (caracteres especiales, encoding)

### Error: "duplicados"
→ Usar script detector de duplicados antes de importar

---

Fecha: 2025-10-21
