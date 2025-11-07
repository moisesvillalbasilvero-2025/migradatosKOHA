# 📋 GUÍA RÁPIDA - OPERACIONES DIARIAS
## Sistema de Migración UNA → Koha

**Última actualización:** 2025-10-15

---

## ✅ MIGRACIÓN EXITOSA DE ARQ

### Resultados Obtenidos
```
✓ Títulos importados: 3,609
✓ Ejemplares importados: 3,944
✓ Archivos MARCXML: 2 (12.9 MB)
✓ Tiempo total: ~12 minutos
✓ Estado: Operacional en OPAC
```

---

## 🚀 COMANDOS ESENCIALES

### Verificar Estado de una Biblioteca

```bash
# Contar registros de ARQ
sudo koha-mysql koha-cnc -N -e "SELECT COUNT(DISTINCT biblionumber) FROM items WHERE homebranch = 'ARQ'"

# Ver últimos registros importados
sudo koha-mysql koha-cnc -e "SELECT biblio.biblionumber, LEFT(biblio.title, 50), items.barcode FROM biblio JOIN items ON biblio.biblionumber = items.biblionumber WHERE items.homebranch = 'ARQ' ORDER BY biblio.biblionumber DESC LIMIT 5"

# Ver distribución por tipo de material
sudo koha-mysql koha-cnc -e "SELECT itype, COUNT(*) FROM items WHERE homebranch = 'ARQ' GROUP BY itype"
```

### Sincronizar ARQ (Actualización)

```bash
cd /home/mvillalba/migradatos
./sincronizar_arquitectura.sh
```

### Migrar Nueva Biblioteca

```bash
# 1. Preparar CSV en /home/mvillalba/migradatos/

# 2. Generar MARCXML
cd /home/mvillalba/migradatos
python3 opac_exportar.py \
    -i NOMBRE_BIBLIOTECA.csv \
    --codbiblio COD \
    --loc-default SALA \
    --stream \
    --split-by 5000

# 3. Importar a Koha
sudo koha-shell koha-cnc -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
    -b \
    -m MARCXML \
    -file /home/mvillalba/migradatos/COD_*_marcxml_01.xml \
    -commit 1000"

# 4. Rebuild índices
sudo koha-rebuild-zebra -f -v koha-cnc

# 5. Verificar
sudo koha-mysql koha-cnc -N -e "SELECT COUNT(*) FROM items WHERE homebranch = 'COD'"
```

### Sistema Automatizado (Múltiples Bibliotecas)

```bash
# Configurar bibliotecas activas
nano /home/mvillalba/migradatos/migracion_config.json

# Ejecutar migración automática
cd /home/mvillalba/migradatos
python3 migracion_automatizada.py --auto

# Procesar solo una biblioteca
python3 migracion_automatizada.py --biblioteca POL
```

---

## 📊 VERIFICACIÓN POST-MIGRACIÓN

### Checklist Rápido

```bash
# 1. ¿Cuántos registros?
sudo koha-mysql koha-cnc -N -e "SELECT COUNT(DISTINCT biblionumber) FROM items WHERE homebranch = 'XXX'"

# 2. ¿Están en el OPAC?
# Visitar: http://tu-koha.una.py/cgi-bin/koha/opac-search.pl
# Buscar algo y filtrar por biblioteca XXX

# 3. ¿Los índices están actualizados?
sudo koha-rebuild-zebra -f -v koha-cnc

# 4. ¿Hay errores en los logs?
tail -100 /home/mvillalba/migradatos/logs/sync_XXX_*.log
```

---

## 🔧 TROUBLESHOOTING

### Error: "Can't open perl script bulkmarcimport.pl"
```bash
# Usar ruta completa:
/usr/share/koha/bin/migration_tools/bulkmarcimport.pl
```

### Error: "duplicate barcode"
```
Es normal. El sistema importa el registro bibliográfico pero advierte sobre
códigos de barras duplicados. Solo se crea el primer ejemplar con ese código.
```

### Índices Desactualizados
```bash
# Reconstruir completamente
sudo koha-stop-zebra koha-cnc
sudo koha-rebuild-zebra -f -v koha-cnc
sudo koha-start-zebra koha-cnc
```

### Revisar Logs
```bash
# Último log de sincronización
ls -lt /home/mvillalba/migradatos/logs/sync_*.log | head -1

# Ver contenido
tail -100 /home/mvillalba/migradatos/logs/sync_ARQ_*.log | less
```

---

## 📁 ESTRUCTURA DE ARCHIVOS

```
/home/mvillalba/migradatos/
├── *.csv                          # CSVs de origen
├── *_marcxml*.xml                 # MARCXML generados
├── *.sh                           # Scripts automatizados
├── *.py                           # Scripts Python
├── *.md                           # Documentación
├── migracion_config.json          # Configuración
├── logs/                          # Logs de ejecución
├── exports/                       # Exports temporales
└── backups/                       # Backups de Koha
```

---

## 🎯 PRÓXIMOS PASOS

### Esta Semana
1. Verificar ARQ en OPAC
2. Resolver duplicados de ARQ (si necesario)
3. Migrar POL (12,467 registros listos)

### Este Mes
4. Configurar cron para sincronización automática
5. Contactar otras facultades
6. Preparar migración masiva

---

## 📞 REFERENCIA RÁPIDA

### Documentación Principal
- **Estado completo:** `RESUMEN_SISTEMA_MIGRACION.md`
- **Guía técnica:** `GUIA_DIDACTICA_COMPLETA.md`
- **Índice completo:** `INDICE_DOCUMENTACION.md`

### Comandos Críticos
```bash
# Ver estado de Koha
sudo koha-list

# Entrar al shell de Koha
sudo koha-shell koha-cnc

# Ver bibliotecas configuradas
sudo koha-mysql koha-cnc -e "SELECT branchcode, branchname FROM branches"

# Contar todos los registros
sudo koha-mysql koha-cnc -e "SELECT homebranch, COUNT(*) FROM items GROUP BY homebranch"
```

---

## 🔐 BACKUP Y SEGURIDAD

### Crear Backup Manual
```bash
# Backup completo de Koha
sudo koha-dump koha-cnc > /home/mvillalba/migradatos/backups/koha_backup_$(date +%Y%m%d_%H%M%S).sql

# Backup de una biblioteca específica
sudo koha-mysql koha-cnc -e "SELECT * FROM biblio JOIN items ON biblio.biblionumber = items.biblionumber WHERE items.homebranch = 'ARQ'" > arq_backup.sql
```

### Restaurar Backup
```bash
# CUIDADO: Esto sobrescribe datos
sudo koha-mysql koha-cnc < /home/mvillalba/migradatos/backups/koha_backup_FECHA.sql
```

---

## ✅ CHECKLIST DIARIO

- [ ] Verificar logs de sincronización nocturna
- [ ] Revisar errores en `/home/mvillalba/migradatos/logs/`
- [ ] Contar registros por biblioteca
- [ ] Verificar índices actualizados
- [ ] Probar búsquedas en OPAC

---

## 📈 ESTADÍSTICAS ACTUALES

| Biblioteca | Títulos | Ejemplares | Estado |
|------------|---------|------------|--------|
| ARQ | 3,609 | 3,944 | ✅ Operacional |
| POL | - | - | 📋 Listo para migrar |
| Otras | - | - | 📝 Planificación |

**Total migrado:** 3,609 títulos, 3,944 ejemplares
**Próximo objetivo:** POL (12,467 registros)

---

**Sistema de Migración UNA → Koha**
**Versión:** 1.0
**Estado:** ✅ Producción
**Soporte:** /home/mvillalba/migradatos/INDICE_DOCUMENTACION.md
