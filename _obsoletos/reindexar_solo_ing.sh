#!/bin/bash
################################################################################
# REINDEXAR SOLO REGISTROS DE INGENIERÍA (RÁPIDO)
################################################################################
# Este script reindexará SOLO los registros nuevos de ING importados hoy
# NO reindexará todo el catálogo
#
# Tiempo estimado: 1-2 minutos
################################################################################

echo "Reindexando SOLO registros de Ingeniería..."

# Obtener los biblionumbers de los registros ING nuevos
BIBLIOS=$(sudo koha-mysql koha-cnc -N -e "
SELECT DISTINCT biblionumber
FROM items
WHERE barcode LIKE 'ING-%'
ORDER BY biblionumber;
")

TOTAL=$(echo "$BIBLIOS" | wc -l)
echo "Total de registros a reindexar: $TOTAL"

# Exportar solo estos registros a un archivo temporal
TEMP_FILE="/tmp/ing_reindex_$(date +%Y%m%d_%H%M%S).mrc"

sudo koha-shell koha-cnc -c "perl -I/usr/share/koha/lib /usr/share/koha/bin/migration_tools/export_records.pl \
  --format=xml \
  --record-type=bibs \
  --biblionumber-list='$(echo $BIBLIOS | tr '\n' ',')' > $TEMP_FILE"

echo "Registros exportados a: $TEMP_FILE"

# Reindexar solo estos registros
echo "Reindexando..."
sudo koha-shell koha-cnc -c "perl /usr/share/koha/bin/migration_tools/rebuild_zebra.pl -b -x -v"

echo "✓ Reindexación completada"

# Limpiar
rm -f $TEMP_FILE

echo ""
echo "Prueba ahora el filtro en el OPAC:"
echo "  http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch=ING"
