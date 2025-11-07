#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# SISTEMA DE SINCRONIZACIÓN AUTOMATIZADA
# Facultad de Arquitectura, Diseño y Arte → OPAC Koha
# ═══════════════════════════════════════════════════════════════
#
# Este script automatiza TODO el proceso de sincronización:
# 1. Genera MARCXML desde CSV
# 2. Valida el XML generado
# 3. Importa a Koha
# 4. Reconstruye índices
# 5. Verifica importación
# 6. Envía notificación
#
# Uso:
#   ./sincronizar_arquitectura.sh
#
# Para automatizar:
#   crontab -e
#   0 2 * * * /home/mvillalba/migradatos/sincronizar_arquitectura.sh
#
# ═══════════════════════════════════════════════════════════════

set -e  # Salir si hay error

# ═══════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════

BIBLIOTECA="ARQ"
NOMBRE_BIBLIOTECA="Facultad de Arquitectura, Diseño y Arte"
CSV_INPUT="/home/mvillalba/migradatos/ARQ.csv"
DIR_TRABAJO="/home/mvillalba/migradatos"
DIR_LOGS="/home/mvillalba/migradatos/logs"
INSTANCIA_KOHA="koha-cnc"

# Códigos de ubicación para esta biblioteca
LOC_DEFAULT="SALA"

# Email para notificaciones (opcional)
EMAIL_NOTIF="biblioteca.arquitectura@una.py"
ENVIAR_EMAIL=false  # Cambiar a true para activar

# ═══════════════════════════════════════════════════════════════
# FUNCIONES
# ═══════════════════════════════════════════════════════════════

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ ERROR: $1" | tee -a "$LOGFILE"
    exit 1
}

success() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✓ $1" | tee -a "$LOGFILE"
}

# ═══════════════════════════════════════════════════════════════
# INICIO
# ═══════════════════════════════════════════════════════════════

# Crear directorio de logs
mkdir -p "$DIR_LOGS"

# Archivo de log único por ejecución
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
LOGFILE="$DIR_LOGS/sync_${BIBLIOTECA}_${TIMESTAMP}.log"

log "╔═══════════════════════════════════════════════════════════╗"
log "║  SINCRONIZACIÓN AUTOMATIZADA - $NOMBRE_BIBLIOTECA"
log "╚═══════════════════════════════════════════════════════════╝"
log ""

# ═══════════════════════════════════════════════════════════════
# PASO 1: VERIFICACIONES PREVIAS
# ═══════════════════════════════════════════════════════════════

log "📋 PASO 1/6: Verificaciones previas"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verificar archivo CSV
if [ ! -f "$CSV_INPUT" ]; then
    error "No se encontró el archivo CSV: $CSV_INPUT"
fi
success "Archivo CSV encontrado: $CSV_INPUT"

# Contar registros
TOTAL_REGISTROS=$(wc -l < "$CSV_INPUT")
TOTAL_REGISTROS=$((TOTAL_REGISTROS - 1))  # Restar header
log "   Total de registros: $TOTAL_REGISTROS"

# Verificar Python
if ! command -v python3 &> /dev/null; then
    error "Python 3 no está instalado"
fi
success "Python 3 disponible"

# Verificar script de exportación
SCRIPT_EXPORT="$DIR_TRABAJO/opac_exportar.py"
if [ ! -f "$SCRIPT_EXPORT" ]; then
    error "No se encontró el script: $SCRIPT_EXPORT"
fi
success "Script de exportación disponible"

# Verificar Koha
if ! command -v koha-shell &> /dev/null; then
    error "Koha no está disponible"
fi
success "Koha disponible"

log ""

# ═══════════════════════════════════════════════════════════════
# PASO 2: GENERAR MARCXML
# ═══════════════════════════════════════════════════════════════

log "🔄 PASO 2/6: Generando MARCXML desde CSV"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$DIR_TRABAJO"

# Generar MARCXML
log "   Ejecutando conversión CSV → MARCXML..."

python3 "$SCRIPT_EXPORT" \
    -i "$CSV_INPUT" \
    --codbiblio "$BIBLIOTECA" \
    --loc-default "$LOC_DEFAULT" \
    --stream \
    --split-by 5000 \
    2>&1 | tee -a "$LOGFILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    error "Falló la generación de MARCXML"
fi

# Buscar archivos MARCXML generados
MARCXML_FILES=(${BIBLIOTECA}_*_marcxml*.xml)

if [ ${#MARCXML_FILES[@]} -eq 0 ]; then
    error "No se generaron archivos MARCXML"
fi

success "MARCXML generado: ${#MARCXML_FILES[@]} archivo(s)"
for file in "${MARCXML_FILES[@]}"; do
    log "   - $file ($(du -h "$file" | cut -f1))"
done

log ""

# ═══════════════════════════════════════════════════════════════
# PASO 3: VALIDAR MARCXML
# ═══════════════════════════════════════════════════════════════

log "✓ PASO 3/6: Validando MARCXML"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

VALIDACION_OK=true

for file in "${MARCXML_FILES[@]}"; do
    log "   Validando: $file"

    # Validar que sea XML bien formado
    if command -v xmllint &> /dev/null; then
        if xmllint --noout "$file" 2>&1 | tee -a "$LOGFILE"; then
            success "   ✓ $file es XML válido"
        else
            log "   ✗ $file tiene errores XML"
            VALIDACION_OK=false
        fi
    else
        log "   ⚠ xmllint no disponible, saltando validación XML"
    fi

    # Contar registros
    REGISTROS_XML=$(grep -o "</ns0:record>" "$file" | wc -l || echo "0")
    log "   → Registros en archivo: $REGISTROS_XML"
done

if [ "$VALIDACION_OK" = false ]; then
    error "Validación de MARCXML falló"
fi

success "Validación completada"
log ""

# ═══════════════════════════════════════════════════════════════
# PASO 4: IMPORTAR A KOHA
# ═══════════════════════════════════════════════════════════════

log "📥 PASO 4/6: Importando a Koha"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

IMPORTADOS=0
ERRORES_IMPORT=0

for file in "${MARCXML_FILES[@]}"; do
    log "   Importando: $file"

    # Importar a Koha
    if sudo koha-shell "$INSTANCIA_KOHA" -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
        -b \
        -m MARCXML \
        -file $DIR_TRABAJO/$file \
        -commit 1000 \
        2>&1" | tee -a "$LOGFILE"; then

        success "   ✓ Importado: $file"
        ((IMPORTADOS++))
    else
        log "   ✗ Error importando: $file"
        ((ERRORES_IMPORT++))
    fi
done

log ""
log "   Archivos importados exitosamente: $IMPORTADOS"
log "   Archivos con errores: $ERRORES_IMPORT"

if [ $IMPORTADOS -eq 0 ]; then
    error "No se pudo importar ningún archivo"
fi

success "Importación completada"
log ""

# ═══════════════════════════════════════════════════════════════
# PASO 5: RECONSTRUIR ÍNDICES
# ═══════════════════════════════════════════════════════════════

log "🔍 PASO 5/6: Reconstruyendo índices de búsqueda"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Detectar motor de búsqueda
SEARCH_ENGINE=$(sudo koha-shell "$INSTANCIA_KOHA" -c "perl -e \"use C4::Context; print C4::Context->preference('SearchEngine')\"" 2>/dev/null || echo "Zebra")

log "   Motor de búsqueda: $SEARCH_ENGINE"

if [ "$SEARCH_ENGINE" = "Elasticsearch" ]; then
    log "   Reconstruyendo índices Elasticsearch..."
    sudo koha-elasticsearch --rebuild -v "$INSTANCIA_KOHA" 2>&1 | tee -a "$LOGFILE"
else
    log "   Reconstruyendo índices Zebra..."
    sudo koha-rebuild-zebra -b -v "$INSTANCIA_KOHA" 2>&1 | tee -a "$LOGFILE"
fi

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    success "Índices reconstruidos exitosamente"
else
    log "⚠ Advertencia: Problemas al reconstruir índices (no crítico)"
fi

log ""

# ═══════════════════════════════════════════════════════════════
# PASO 6: VERIFICACIÓN POST-IMPORTACIÓN
# ═══════════════════════════════════════════════════════════════

log "✓ PASO 6/6: Verificación post-importación"
log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Contar registros en Koha para esta biblioteca
log "   Consultando base de datos Koha..."

REGISTROS_KOHA=$(sudo koha-mysql "$INSTANCIA_KOHA" -N -e "
    SELECT COUNT(DISTINCT biblionumber)
    FROM items
    WHERE homebranch = '$BIBLIOTECA'
" 2>/dev/null || echo "0")

log "   Total de títulos en Koha para $BIBLIOTECA: $REGISTROS_KOHA"

ITEMS_KOHA=$(sudo koha-mysql "$INSTANCIA_KOHA" -N -e "
    SELECT COUNT(*)
    FROM items
    WHERE homebranch = '$BIBLIOTECA'
" 2>/dev/null || echo "0")

log "   Total de ejemplares en Koha para $BIBLIOTECA: $ITEMS_KOHA"

# Mostrar algunos registros recientes
log ""
log "   Últimos 3 registros importados:"
sudo koha-mysql "$INSTANCIA_KOHA" -e "
    SELECT
        biblio.biblionumber,
        LEFT(biblio.title, 50) as titulo,
        items.barcode
    FROM biblio
    JOIN items ON biblio.biblionumber = items.biblionumber
    WHERE items.homebranch = '$BIBLIOTECA'
    ORDER BY biblio.biblionumber DESC
    LIMIT 3
" 2>&1 | tee -a "$LOGFILE"

success "Verificación completada"
log ""

# ═══════════════════════════════════════════════════════════════
# RESUMEN FINAL
# ═══════════════════════════════════════════════════════════════

log "╔═══════════════════════════════════════════════════════════╗"
log "║  RESUMEN DE SINCRONIZACIÓN"
log "╚═══════════════════════════════════════════════════════════╝"
log ""
log "Biblioteca: $NOMBRE_BIBLIOTECA ($BIBLIOTECA)"
log "Fecha/Hora: $(date '+%Y-%m-%d %H:%M:%S')"
log ""
log "📊 ESTADÍSTICAS:"
log "   • Registros en CSV: $TOTAL_REGISTROS"
log "   • Títulos en Koha: $REGISTROS_KOHA"
log "   • Ejemplares en Koha: $ITEMS_KOHA"
log "   • Archivos MARCXML generados: ${#MARCXML_FILES[@]}"
log "   • Archivos importados: $IMPORTADOS"
log "   • Errores de importación: $ERRORES_IMPORT"
log ""
log "✅ SINCRONIZACIÓN COMPLETADA EXITOSAMENTE"
log ""
log "📝 Log completo en: $LOGFILE"
log ""

# ═══════════════════════════════════════════════════════════════
# NOTIFICACIÓN POR EMAIL (OPCIONAL)
# ═══════════════════════════════════════════════════════════════

if [ "$ENVIAR_EMAIL" = true ]; then
    log "📧 Enviando notificación por email..."

    EMAIL_BODY="Sincronización completada para $NOMBRE_BIBLIOTECA

Fecha: $(date '+%Y-%m-%d %H:%M:%S')

ESTADÍSTICAS:
- Registros en CSV: $TOTAL_REGISTROS
- Títulos en Koha: $REGISTROS_KOHA
- Ejemplares en Koha: $ITEMS_KOHA
- Archivos importados: $IMPORTADOS
- Errores: $ERRORES_IMPORT

Estado: EXITOSA

Log: $LOGFILE
"

    echo "$EMAIL_BODY" | mail -s "Sincronización $BIBLIOTECA - $(date '+%Y-%m-%d')" "$EMAIL_NOTIF" 2>&1 | tee -a "$LOGFILE" || log "⚠ No se pudo enviar email"
fi

# ═══════════════════════════════════════════════════════════════
# LIMPIEZA (OPCIONAL)
# ═══════════════════════════════════════════════════════════════

# Descomentar para mover archivos MARCXML a directorio de respaldo
# mkdir -p "$DIR_TRABAJO/respaldo"
# mv "${MARCXML_FILES[@]}" "$DIR_TRABAJO/respaldo/" 2>&1 | tee -a "$LOGFILE"

# Descomentar para eliminar logs antiguos (más de 30 días)
# find "$DIR_LOGS" -name "sync_${BIBLIOTECA}_*.log" -mtime +30 -delete

log "═══════════════════════════════════════════════════════════"
log "Sincronización finalizada"
log "═══════════════════════════════════════════════════════════"

exit 0
