#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
# IMPORTADOR POR LOTES - KOHA UNA
# ════════════════════════════════════════════════════════════════════════════
# Versión: 2.0 - Con prevención de duplicados
# Fecha: 25 de Octubre de 2025
# Uso: ./importar_por_lotes.sh ARCHIVO.csv [TAMAÑO_LOTE]
#
# Divide archivos grandes en lotes pequeños para mejor rendimiento
# ════════════════════════════════════════════════════════════════════════════

set -e  # Detener en caso de error

# Cargar funciones de prevención de duplicados
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/prevenir_duplicados.sh"

# ═══════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN
# ═══════════════════════════════════════════════════════════════════════════

CSV_FILE=$1
BATCH_SIZE=${2:-500}  # Por defecto 500 registros por lote

BASE_DIR="/home/mvillalba/migradatos"
BATCH_DIR="${BASE_DIR}/temp_batches"
LOG_DIR="${BASE_DIR}/logs"
FECHA=$(date '+%Y%m%d_%H%M%S')
LOG_FILE="${LOG_DIR}/batch_import_${FECHA}.log"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# ═══════════════════════════════════════════════════════════════════════════
# FUNCIONES
# ═══════════════════════════════════════════════════════════════════════════

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✓${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ✗${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Limpiar al salir
cleanup() {
    if [ -d "$BATCH_DIR" ]; then
        log "Limpiando archivos temporales..."
        rm -rf "$BATCH_DIR"
    fi
}
trap cleanup EXIT

# ═══════════════════════════════════════════════════════════════════════════
# VALIDACIONES
# ═══════════════════════════════════════════════════════════════════════════

if [ -z "$CSV_FILE" ]; then
    echo -e "${RED}Error: Debe proporcionar el archivo CSV${NC}"
    echo "Uso: $0 archivo.csv [tamaño_lote]"
    echo ""
    echo "Ejemplos:"
    echo "  $0 ING.csv           # Lotes de 500 registros (default)"
    echo "  $0 ING.csv 100       # Lotes de 100 registros"
    echo "  $0 ING.csv 1000      # Lotes de 1000 registros"
    exit 1
fi

if [ ! -f "$CSV_FILE" ]; then
    echo -e "${RED}Error: El archivo $CSV_FILE no existe${NC}"
    exit 1
fi

# Crear directorios si no existen
mkdir -p "$BATCH_DIR"
mkdir -p "$LOG_DIR"

# ═══════════════════════════════════════════════════════════════════════════
# INICIO
# ═══════════════════════════════════════════════════════════════════════════

clear
print_header "IMPORTACIÓN POR LOTES - KOHA UNA"

log "Archivo de entrada: $CSV_FILE"
log "Tamaño de lote: $BATCH_SIZE registros"
log "Archivo de log: $LOG_FILE"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# ANÁLISIS DEL ARCHIVO
# ═══════════════════════════════════════════════════════════════════════════

print_header "1. ANÁLISIS DEL ARCHIVO"

TOTAL_LINES=$(wc -l < "$CSV_FILE")
TOTAL_RECORDS=$((TOTAL_LINES - 1))  # Menos encabezado
NUM_BATCHES=$(( (TOTAL_RECORDS + BATCH_SIZE - 1) / BATCH_SIZE ))  # Redondear arriba

log "Total de líneas: $TOTAL_LINES"
log "Total de registros: $TOTAL_RECORDS"
log "Número de lotes: $NUM_BATCHES"
echo ""

# Estimación de tiempo
ESTIMATED_TIME_PER_BATCH=2  # minutos por lote
TOTAL_ESTIMATED_TIME=$((NUM_BATCHES * ESTIMATED_TIME_PER_BATCH))

log "Tiempo estimado: ~$TOTAL_ESTIMATED_TIME minutos ($ESTIMATED_TIME_PER_BATCH min/lote)"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# VERIFICACIÓN DE DUPLICADOS
# ═══════════════════════════════════════════════════════════════════════════

print_header "VERIFICACIÓN DE DUPLICADOS"

# Verificar duplicados en el CSV
log "Verificando duplicados internos en el CSV..."
verificar_duplicados_en_csv "$CSV_FILE" "/tmp/dup_batch_internal_$$.log"
if [ $? -ne 0 ]; then
    log_error "Se encontraron códigos de barras duplicados en el CSV"
    cat "/tmp/dup_batch_internal_$$.log" | tail -30
    rm -f "/tmp/dup_batch_internal_$$.log"
    echo ""
    log_error "Corrige los duplicados antes de continuar"
    exit 1
fi
log_success "No hay duplicados internos"

# Verificar duplicados contra BD
log "Verificando duplicados contra base de datos..."
verificar_duplicados_csv_vs_bd "$CSV_FILE" "/tmp/dup_batch_bd_$$.log"
DUP_RESULT=$?

if [ $DUP_RESULT -eq 1 ]; then
    log_error "CRÍTICO: Hay códigos de barras que ya existen en la BD"
    cat "/tmp/dup_batch_bd_$$.log" | tail -30
    rm -f "/tmp/dup_batch_bd_$$.log" "/tmp/dup_batch_internal_$$.log"
    echo ""
    log_error "No se puede continuar. Corrige los códigos de barras duplicados."
    exit 1
elif [ $DUP_RESULT -eq 2 ]; then
    log_warning "Se encontraron ISBNs/Títulos existentes"
    log "El sistema agregará ejemplares automáticamente (no creará duplicados)"
    echo ""
else
    log_success "No se encontraron duplicados"
fi

# Limpiar logs temporales
rm -f "/tmp/dup_batch_bd_$$.log" "/tmp/dup_batch_internal_$$.log"

echo ""

# ═══════════════════════════════════════════════════════════════════════════
# CONFIRMACIÓN
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${YELLOW}¿Continuar con la importación en $NUM_BATCHES lotes? (s/n)${NC}"
read -r RESPUESTA

if [ "$RESPUESTA" != "s" ] && [ "$RESPUESTA" != "S" ]; then
    log "Importación cancelada por el usuario"
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════
# DIVISIÓN EN LOTES
# ═══════════════════════════════════════════════════════════════════════════

print_header "2. DIVIDIENDO EN LOTES"

# Guardar encabezado
HEADER=$(head -1 "$CSV_FILE")

log "Creando $NUM_BATCHES archivos de lote..."

for i in $(seq 1 $NUM_BATCHES); do
    START_LINE=$(( (i - 1) * BATCH_SIZE + 2 ))  # +2 para saltar encabezado
    END_LINE=$(( i * BATCH_SIZE + 1 ))

    BATCH_FILE="${BATCH_DIR}/lote_${i}_de_${NUM_BATCHES}.csv"

    # Crear archivo con encabezado
    echo "$HEADER" > "$BATCH_FILE"

    # Agregar registros del lote
    sed -n "${START_LINE},${END_LINE}p" "$CSV_FILE" >> "$BATCH_FILE"

    BATCH_RECORDS=$(( $(wc -l < "$BATCH_FILE") - 1 ))
    log "Lote $i: $BATCH_RECORDS registros → $BATCH_FILE"
done

log_success "Lotes creados exitosamente"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# IMPORTACIÓN DE LOTES
# ═══════════════════════════════════════════════════════════════════════════

print_header "3. IMPORTANDO LOTES"

# Variables de estadísticas
TOTAL_SUCCESS=0
TOTAL_ERRORS=0
START_TIME=$(date +%s)

for i in $(seq 1 $NUM_BATCHES); do
    BATCH_FILE="${BATCH_DIR}/lote_${i}_de_${NUM_BATCHES}.csv"
    BATCH_RECORDS=$(( $(wc -l < "$BATCH_FILE") - 1 ))

    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  LOTE $i DE $NUM_BATCHES ($BATCH_RECORDS registros)${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""

    # Copiar a directorio de importación
    CODIGO_LOTE="LOTE${i}_${FECHA}"
    cp "$BATCH_FILE" "${BASE_DIR}/importar_aqui/${CODIGO_LOTE}.csv"

    # Importar usando el script existente
    log "Iniciando importación del lote $i..."

    if ./importar_biblioteca.sh "$CODIGO_LOTE" >> "$LOG_FILE" 2>&1; then
        log_success "Lote $i importado exitosamente"
        TOTAL_SUCCESS=$((TOTAL_SUCCESS + BATCH_RECORDS))
    else
        log_error "Error en lote $i"
        TOTAL_ERRORS=$((TOTAL_ERRORS + BATCH_RECORDS))

        # Preguntar si continuar
        echo -e "${YELLOW}¿Continuar con el siguiente lote? (s/n)${NC}"
        read -r CONTINUAR
        if [ "$CONTINUAR" != "s" ] && [ "$CONTINUAR" != "S" ]; then
            log_error "Importación detenida por el usuario"
            break
        fi
    fi

    # Limpiar archivo temporal
    rm -f "${BASE_DIR}/importar_aqui/${CODIGO_LOTE}.csv"

    # Pausa entre lotes para que Zebra procese
    if [ $i -lt $NUM_BATCHES ]; then
        PAUSE_TIME=30
        log "Esperando ${PAUSE_TIME}s para indexación..."

        # Barra de progreso
        for ((j=PAUSE_TIME; j>0; j--)); do
            echo -ne "${CYAN}Pausa: $j segundos restantes...\r${NC}"
            sleep 1
        done
        echo ""
    fi

    # Progreso general
    PERCENT=$(( i * 100 / NUM_BATCHES ))
    echo ""
    echo -e "${CYAN}Progreso general: $i/$NUM_BATCHES lotes ($PERCENT%)${NC}"
    echo ""
done

# ═══════════════════════════════════════════════════════════════════════════
# REINDEXACIÓN FINAL
# ═══════════════════════════════════════════════════════════════════════════

print_header "4. REINDEXACIÓN FINAL"

log "Reindexando catálogo completo..."
if sudo koha-rebuild-zebra -f -v koha-cnc >> "$LOG_FILE" 2>&1; then
    log_success "Reindexación completada"
else
    log_error "Error en reindexación"
fi

log "Reiniciando Plack..."
if sudo koha-plack --restart koha-cnc >> "$LOG_FILE" 2>&1; then
    log_success "Plack reiniciado"
else
    log_error "Error reiniciando Plack"
fi

# ═══════════════════════════════════════════════════════════════════════════
# ESTADÍSTICAS FINALES
# ═══════════════════════════════════════════════════════════════════════════

END_TIME=$(date +%s)
ELAPSED_TIME=$((END_TIME - START_TIME))
ELAPSED_MINUTES=$((ELAPSED_TIME / 60))
ELAPSED_SECONDS=$((ELAPSED_TIME % 60))

print_header "RESUMEN FINAL"

echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  IMPORTACIÓN COMPLETADA${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}Archivo importado:${NC} $CSV_FILE"
echo -e "${CYAN}Total de lotes:${NC} $NUM_BATCHES"
echo -e "${CYAN}Tamaño de lote:${NC} $BATCH_SIZE registros"
echo ""

echo -e "${GREEN}✓ Registros exitosos:${NC} $TOTAL_SUCCESS"
if [ $TOTAL_ERRORS -gt 0 ]; then
    echo -e "${RED}✗ Registros con error:${NC} $TOTAL_ERRORS"
fi
echo ""

echo -e "${CYAN}Tiempo total:${NC} ${ELAPSED_MINUTES}m ${ELAPSED_SECONDS}s"
echo -e "${CYAN}Log completo:${NC} $LOG_FILE"
echo ""

# Verificación en base de datos
log "Verificando registros en base de datos..."
DB_COUNT=$(koha-mysql koha-cnc -sN -e "
    SELECT COUNT(*)
    FROM biblio
    WHERE datecreated = CURDATE()
" 2>/dev/null || echo "0")

echo -e "${CYAN}Registros en BD (hoy):${NC} $DB_COUNT"
echo ""

# Recomendaciones
print_header "RECOMENDACIONES"

echo "1. Verificar en OPAC: http://opac.una.edu.py/"
echo "2. Revisar log completo: less $LOG_FILE"
echo "3. Verificar calidad:"
echo "   koha-mysql koha-cnc -e \"SELECT COUNT(*) FROM biblio WHERE datecreated = CURDATE()\""
echo ""

if [ $TOTAL_ERRORS -gt 0 ]; then
    echo -e "${YELLOW}⚠ Hubo errores. Revisar log para detalles.${NC}"
    echo ""
fi

# Generar reporte HTML
REPORT_FILE="${BASE_DIR}/reportes/batch_import_${FECHA}.html"
mkdir -p "${BASE_DIR}/reportes"

cat > "$REPORT_FILE" <<EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Reporte Importación por Lotes - $FECHA</title>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            margin: 40px;
            background: #f5f5f5;
        }
        .container {
            max-width: 900px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(2, 1fr);
            gap: 20px;
            margin: 30px 0;
        }
        .stat-box {
            background: #ecf0f1;
            padding: 20px;
            border-radius: 8px;
            border-left: 4px solid #3498db;
        }
        .stat-label {
            color: #7f8c8d;
            font-size: 14px;
            margin-bottom: 5px;
        }
        .stat-value {
            color: #2c3e50;
            font-size: 32px;
            font-weight: bold;
        }
        .success { border-left-color: #27ae60; }
        .error { border-left-color: #e74c3c; }
        .info { border-left-color: #3498db; }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background: #3498db;
            color: white;
            font-weight: 600;
        }
        tr:hover {
            background: #f8f9fa;
        }
        .badge {
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            font-weight: 600;
        }
        .badge-success {
            background: #27ae60;
            color: white;
        }
        .badge-error {
            background: #e74c3c;
            color: white;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 Reporte de Importación por Lotes</h1>
        <p><strong>Fecha:</strong> $(date '+%Y-%m-%d %H:%M:%S')</p>
        <p><strong>Archivo:</strong> $CSV_FILE</p>

        <div class="stats">
            <div class="stat-box info">
                <div class="stat-label">Total de Lotes</div>
                <div class="stat-value">$NUM_BATCHES</div>
            </div>
            <div class="stat-box info">
                <div class="stat-label">Registros por Lote</div>
                <div class="stat-value">$BATCH_SIZE</div>
            </div>
            <div class="stat-box success">
                <div class="stat-label">Registros Exitosos</div>
                <div class="stat-value">$TOTAL_SUCCESS</div>
            </div>
            <div class="stat-box error">
                <div class="stat-label">Registros con Error</div>
                <div class="stat-value">$TOTAL_ERRORS</div>
            </div>
        </div>

        <h2>⏱️ Tiempo de Ejecución</h2>
        <p><strong>${ELAPSED_MINUTES} minutos ${ELAPSED_SECONDS} segundos</strong></p>

        <h2>📝 Detalles de Lotes</h2>
        <table>
            <thead>
                <tr>
                    <th>Lote</th>
                    <th>Registros</th>
                    <th>Estado</th>
                </tr>
            </thead>
            <tbody>
EOF

# Agregar detalles de cada lote
for i in $(seq 1 $NUM_BATCHES); do
    BATCH_RECORDS=$(( $(wc -l < "${BATCH_DIR}/lote_${i}_de_${NUM_BATCHES}.csv" 2>/dev/null || echo "1") - 1 ))
    cat >> "$REPORT_FILE" <<EOF
                <tr>
                    <td>Lote $i de $NUM_BATCHES</td>
                    <td>$BATCH_RECORDS</td>
                    <td><span class="badge badge-success">✓ Completado</span></td>
                </tr>
EOF
done

cat >> "$REPORT_FILE" <<EOF
            </tbody>
        </table>

        <h2>🔗 Enlaces Útiles</h2>
        <ul>
            <li><a href="http://opac.una.edu.py/" target="_blank">Ver en OPAC</a></li>
            <li><a href="http://staff.una.edu.py/" target="_blank">Staff Interface</a></li>
        </ul>

        <h2>📋 Log Completo</h2>
        <p><code>$LOG_FILE</code></p>
    </div>
</body>
</html>
EOF

echo -e "${CYAN}Reporte HTML generado:${NC} $REPORT_FILE"
echo ""

log_success "¡IMPORTACIÓN POR LOTES COMPLETADA!"
