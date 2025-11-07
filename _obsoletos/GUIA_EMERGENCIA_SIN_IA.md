# 🆘 GUÍA DE EMERGENCIA - SIN IA
## Cómo importar bibliotecas manualmente

**Si la IA no funciona, sigue estos pasos simples:**

---

## 📋 PROCESO MANUAL COMPLETO

### OPCIÓN 1: USAR EL SCRIPT AUTOMÁTICO (Más Fácil) ⭐

```bash
# 1. Ir al directorio
cd /home/mvillalba/migradatos

# 2. Ejecutar el script
./importar_nueva_biblioteca.sh CODIGO /ruta/al/archivo.csv

# Ejemplo:
./importar_nueva_biblioteca.sh FACEN /tmp/FACEN.csv
```

**Eso es todo. El script hace todo automáticamente.**

---

### OPCIÓN 2: PASO A PASO MANUAL

Si el script no funciona, hazlo manualmente:

#### PASO 1: Copiar el CSV

```bash
cd /home/mvillalba/migradatos
cp /ruta/origen/archivo.csv ./CODIGO_$(date +%Y%m%d).csv
```

#### PASO 2: Verificar que la biblioteca existe en Koha

```bash
sudo koha-mysql koha-cnc -e "SELECT * FROM branches WHERE branchcode = 'CODIGO'"
```

**Si NO existe, crearla:**
- Ir a Staff Interface: http://servidor:8080/cgi-bin/koha/mainpage.pl
- Administración → Bibliotecas → Nueva biblioteca
- Código: CODIGO
- Nombre: Nombre completo
- Guardar

#### PASO 3: Generar MARCXML

```bash
cd exports

python3 /home/mvillalba/migradatos/opac_exportar.py \
  -i /home/mvillalba/migradatos/CODIGO_20251021.csv \
  --codbiblio CODIGO \
  --loc-default SALA \
  --stream \
  --split-by 5000
```

#### PASO 4: Validar XML (Opcional)

```bash
xmllint --noout CODIGO_*_marcxml_01.xml
```

#### PASO 5: Importar a Koha

```bash
sudo koha-shell koha-cnc -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
  -b \
  -m MARCXML \
  -file /home/mvillalba/migradatos/exports/CODIGO_*_marcxml_01.xml \
  -commit 1000"
```

**Si hay más archivos XML (_02, _03, etc.), repetir para cada uno:**

```bash
sudo koha-shell koha-cnc -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
  -b \
  -m MARCXML \
  -file /home/mvillalba/migradatos/exports/CODIGO_*_marcxml_02.xml \
  -commit 1000"
```

#### PASO 6: Reconstruir índices

```bash
sudo koha-rebuild-zebra -f -v koha-cnc
```

#### PASO 7: Verificar

```bash
sudo koha-mysql koha-cnc -e "
SELECT homebranch, COUNT(*) as total
FROM items
WHERE homebranch = 'CODIGO'
GROUP BY homebranch"
```

---

## 🔧 COMANDOS DE MANTENIMIENTO

### Ver todas las bibliotecas

```bash
sudo koha-mysql koha-cnc -e "
SELECT branchcode, branchname, COUNT(items.itemnumber) as items
FROM branches
LEFT JOIN items ON branches.branchcode = items.homebranch
GROUP BY branchcode, branchname
ORDER BY branchcode"
```

### Contar items de una biblioteca

```bash
sudo koha-mysql koha-cnc -e "
SELECT COUNT(*) FROM items WHERE homebranch = 'CODIGO'"
```

### Eliminar items de una biblioteca (CUIDADO)

```bash
sudo koha-mysql koha-cnc -e "DELETE FROM items WHERE homebranch = 'CODIGO'"
```

### Reindexar todo

```bash
sudo koha-rebuild-zebra -f -v koha-cnc
```

### Reiniciar servicios Koha

```bash
sudo koha-plack --restart koha-cnc
sudo systemctl restart apache2
```

---

## 🆘 SOLUCIÓN DE PROBLEMAS

### Error: "biblioteca no existe"
**Solución:** Crear biblioteca en Staff Interface primero

### Error: "archivo no encontrado"
**Solución:** Verificar ruta completa del archivo
```bash
ls -lh /ruta/completa/archivo.csv
```

### Error: "permisos denegados"
**Solución:** Usar sudo
```bash
sudo comando...
```

### Importación muy lenta
**Solución:** Normal para archivos grandes. Esperar o verificar:
```bash
# Ver procesos de Koha
ps aux | grep koha
```

### Búsqueda no funciona en OPAC
**Solución:** Reindexar
```bash
sudo koha-rebuild-zebra -f -v koha-cnc
```

### No aparecen registros nuevos
**Solución:**
1. Verificar en MySQL:
```bash
sudo koha-mysql koha-cnc -e "SELECT COUNT(*) FROM items WHERE homebranch = 'CODIGO'"
```

2. Reindexar:
```bash
sudo koha-rebuild-zebra -f -v koha-cnc
```

3. Limpiar caché del navegador (Ctrl+F5)

---

## 📁 UBICACIONES IMPORTANTES

```bash
# Directorio de trabajo
/home/mvillalba/migradatos/

# CSV originales
/home/mvillalba/migradatos/*.csv

# XML generados
/home/mvillalba/migradatos/exports/*.xml

# Logs
/home/mvillalba/migradatos/logs/*.log

# Scripts
/home/mvillalba/migradatos/*.sh
/home/mvillalba/migradatos/*.py
```

---

## 🎯 EJEMPLO COMPLETO DE EMERGENCIA

**Caso:** Recibiste FACEN.csv y necesitas importarlo YA

```bash
# 1. Conectarse al servidor
ssh usuario@servidor

# 2. Ir al directorio
cd /home/mvillalba/migradatos

# 3. Copiar archivo
cp /tmp/FACEN.csv ./FACEN_20251021.csv

# 4. Verificar biblioteca existe
sudo koha-mysql koha-cnc -e "SELECT * FROM branches WHERE branchcode = 'FACEN'"

# Si no existe, crear en Staff Interface primero!

# 5. Generar XML
cd exports
python3 ../opac_exportar.py -i ../FACEN_20251021.csv --codbiblio FACEN --loc-default SALA --stream --split-by 5000

# 6. Importar (puede tomar tiempo)
sudo koha-shell koha-cnc -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl -b -m MARCXML -file /home/mvillalba/migradatos/exports/FACEN_*_marcxml_01.xml -commit 1000"

# Si hay más archivos (_02, _03), repetir comando cambiando _01 por _02, etc.

# 7. Reindexar
sudo koha-rebuild-zebra -f -v koha-cnc

# 8. Verificar
sudo koha-mysql koha-cnc -e "SELECT COUNT(*) FROM items WHERE homebranch = 'FACEN'"

# ✓ Listo!
```

---

## 📞 NÚMEROS DE EMERGENCIA

### Archivos clave:
- `IMPORTAR_FACIL.md` - Guía rápida
- `COMO_IMPORTAR_NUEVA_BIBLIOTECA.md` - Guía detallada
- `importar_nueva_biblioteca.sh` - Script automático

### Comandos rápidos:

```bash
# Ver scripts disponibles
ls -lh *.sh

# Ver logs recientes
ls -lht logs/ | head

# Ver CSV disponibles
ls -lh *.csv

# Estado de Koha
sudo koha-list

# Ver todas las bibliotecas con items
sudo koha-mysql koha-cnc -e "
SELECT homebranch, COUNT(*) as items
FROM items
GROUP BY homebranch
ORDER BY items DESC"
```

---

## ✅ CHECKLIST RÁPIDO

Antes de importar, verificar:

- [ ] CSV copiado a /home/mvillalba/migradatos/
- [ ] Biblioteca existe en Koha (verificar en Staff o MySQL)
- [ ] Suficiente espacio en disco
- [ ] Koha funcionando (sudo koha-list)

Durante la importación:

- [ ] No cerrar la terminal
- [ ] No interrumpir el proceso
- [ ] Esperar pacientemente (puede tardar 30+ minutos)

Después de importar:

- [ ] Reindexar con koha-rebuild-zebra
- [ ] Verificar count en MySQL
- [ ] Probar búsqueda en OPAC
- [ ] Verificar algunos registros aleatorios

---

## 💡 TIPS IMPORTANTES

1. **Siempre reindexar después de importar**
   ```bash
   sudo koha-rebuild-zebra -f -v koha-cnc
   ```

2. **Si algo falla, ver logs de Koha:**
   ```bash
   sudo tail -f /var/log/koha/koha-cnc/plack-error.log
   ```

3. **Backup antes de cambios grandes:**
   ```bash
   sudo koha-dump koha-cnc > backup_$(date +%Y%m%d).sql
   ```

4. **No interrumpir una importación en progreso**
   - Puede dejar la base de datos inconsistente
   - Mejor esperar a que termine

5. **Formato de nombres de archivo:**
   - Recomendado: `CODIGO_YYYYMMDD.csv`
   - Ejemplo: `FACEN_20251021.csv`

---

## 🎓 ORDEN DE IMPORTACIÓN RECOMENDADO

Si tienes que importar varias bibliotecas:

1. Las más pequeñas primero (para probar)
2. Verificar cada una antes de continuar
3. Una a la vez (no en paralelo)
4. Reindexar después de CADA importación

---

**RECUERDA:** Si el script `importar_nueva_biblioteca.sh` funciona, úsalo. Es más fácil y seguro que hacerlo manualmente.

```bash
./importar_nueva_biblioteca.sh CODIGO /ruta/archivo.csv
```

---

**Fecha:** 2025-10-21
**Versión:** 1.0 - Guía de Emergencia
**Sistema:** UNA → Koha
