#!/bin/bash
################################################################################
# SCRIPT DE CARGA AUTOMÁTICA DE NUEVAS BIBLIOTECAS
################################################################################
# Universidad Nacional de Asunción - Sistema Koha
#
# Este script automatiza completamente el proceso de carga de una nueva
# biblioteca al sistema Koha:
#   1. Valida el archivo CSV
#   2. Crea el código de biblioteca en Koha
#   3. Convierte CSV a MARCXML
#   4. Importa registros a Koha
#   5. Reindexar Zebra (modo seguro)
#   6. Verifica con agente experto
#
# USO:
#   sudo ./cargar_biblioteca.sh <codigo> <nombre> <archivo.csv>
#
# EJEMPLO:
#   sudo ./cargar_biblioteca.sh DER "Facultad de Derecho" DER.csv
#
# Fecha: 2025-10-16
# Versión: 1.0
################################################################################

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Directorios
WORK_DIR="/home/mvillalba/migradatos"
LOG_DIR="$WORK_DIR/logs"
INSTANCIA="koha-cnc"

# Crear log
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="$LOG_DIR/carga_biblioteca_${TIMESTAMP}.log"

################################################################################
# FUNCIONES AUXILIARES
################################################################################

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOGFILE"
}

success() {
    echo -e "${GREEN}[OK]${NC} $1" | tee -a "$LOGFILE"
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOGFILE"
}

info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$LOGFILE"
}

header() {
    echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${BLUE}  $1${NC}"
    echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

separator() {
    echo -e "${BLUE}────────────────────────────────────────────────────────────${NC}"
}

# Verificar que se ejecuta como root
if [ "$EUID" -ne 0 ]; then
    error "Este script debe ejecutarse como root (usar sudo)"
    exit 1
fi

# Crear directorio de logs si no existe
mkdir -p "$LOG_DIR"

################################################################################
# VALIDACIÓN DE PARÁMETROS
################################################################################

header "VALIDACIÓN DE PARÁMETROS"

if [ $# -ne 3 ]; then
    error "Número incorrecto de parámetros"
    echo
    echo "USO:"
    echo "  $0 <codigo> <nombre> <archivo.csv>"
    echo
    echo "EJEMPLO:"
    echo "  $0 DER 'Facultad de Derecho' DER.csv"
    echo "  $0 FACAGR 'Facultad de Ciencias Agrarias' FACAGR.csv"
    echo
    echo "PARÁMETROS:"
    echo "  <codigo>      Código de 3-10 caracteres (sin espacios)"
    echo "  <nombre>      Nombre descriptivo (entre comillas si tiene espacios)"
    echo "  <archivo.csv> Ruta al archivo CSV"
    echo
    exit 1
fi

BIBLIOTECA_CODE="$1"
BIBLIOTECA_NOMBRE="$2"
CSV_FILE="$3"

# Validar código de biblioteca
if ! [[ "$BIBLIOTECA_CODE" =~ ^[A-Z0-9]{3,10}$ ]]; then
    error "Código de biblioteca inválido: '$BIBLIOTECA_CODE'"
    info "El código debe tener 3-10 caracteres, solo letras mayúsculas y números"
    info "Ejemplos válidos: DER, FACAGR, POL, FACECON"
    exit 1
fi

success "Código válido: $BIBLIOTECA_CODE"
success "Nombre: $BIBLIOTECA_NOMBRE"

################################################################################
# VALIDACIÓN DEL ARCHIVO CSV
################################################################################

header "VALIDACIÓN DEL ARCHIVO CSV"

# Verificar que existe
if [ ! -f "$CSV_FILE" ]; then
    error "Archivo no encontrado: $CSV_FILE"
    exit 1
fi

success "Archivo encontrado: $CSV_FILE"

# Obtener ruta absoluta
CSV_FILE=$(realpath "$CSV_FILE")
info "Ruta completa: $CSV_FILE"

# Verificar tamaño
FILESIZE=$(stat -f%z "$CSV_FILE" 2>/dev/null || stat -c%s "$CSV_FILE" 2>/dev/null)
FILESIZE_MB=$(echo "scale=2; $FILESIZE / 1024 / 1024" | bc)
info "Tamaño: ${FILESIZE_MB} MB"

# Contar líneas
TOTAL_LINES=$(wc -l < "$CSV_FILE")
TOTAL_RECORDS=$((TOTAL_LINES - 1))  # Restar cabecera
info "Total de líneas: $TOTAL_LINES"
info "Registros (sin cabecera): $TOTAL_RECORDS"

if [ $TOTAL_RECORDS -lt 1 ]; then
    error "El archivo no contiene registros (solo cabecera)"
    exit 1
fi

# Verificar encoding
ENCODING=$(file -b --mime-encoding "$CSV_FILE")
info "Encoding detectado: $ENCODING"

if [ "$ENCODING" != "utf-8" ] && [ "$ENCODING" != "us-ascii" ]; then
    warning "Encoding no es UTF-8, puede causar problemas con caracteres especiales"
    warning "Considera convertir con: iconv -f $ENCODING -t UTF-8 $CSV_FILE > ${CSV_FILE}.utf8"
fi

# Ver primeras líneas
info "Primeras 3 líneas del archivo:"
head -3 "$CSV_FILE" | tee -a "$LOGFILE"

separator

################################################################################
# VERIFICAR DUPLICADOS
################################################################################

info "Verificando códigos de barras duplicados..."

# Detectar columna de códigos de barras (asumiendo que se llama 'nroacceso')
# Esto es una verificación básica
DUPLICATES=$(cut -d',' -f9 "$CSV_FILE" 2>/dev/null | tail -n +2 | sort | uniq -d | wc -l)

if [ $DUPLICATES -gt 0 ]; then
    warning "Se encontraron $DUPLICATES códigos de barras duplicados en el CSV"
    warning "Esto puede causar errores durante la importación"
    echo
    read -p "¿Desea continuar de todas formas? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        info "Cancelado por el usuario"
        exit 0
    fi
fi

success "Validación del CSV completada"

################################################################################
# CONFIRMACIÓN FINAL
################################################################################

header "RESUMEN"

echo -e "${BOLD}Se va a cargar:${NC}"
echo -e "  Biblioteca: ${CYAN}$BIBLIOTECA_CODE${NC} - $BIBLIOTECA_NOMBRE"
echo -e "  Archivo:    ${CYAN}$CSV_FILE${NC}"
echo -e "  Registros:  ${CYAN}$TOTAL_RECORDS${NC}"
echo -e "  Tamaño:     ${CYAN}${FILESIZE_MB} MB${NC}"
echo
echo -e "${YELLOW}Este proceso:${NC}"
echo "  1. Creará el código de biblioteca en Koha"
echo "  2. Convertirá el CSV a formato MARCXML"
echo "  3. Importará los registros a Koha"
echo "  4. Reindexará el sistema (puede tardar varios minutos)"
echo
echo -e "${BOLD}Tiempo estimado: 15-30 minutos${NC}"
echo

read -p "¿Desea continuar? (s/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    info "Cancelado por el usuario"
    exit 0
fi

INICIO=$(date +%s)

################################################################################
# PASO 1: CREAR CÓDIGO DE BIBLIOTECA EN KOHA
################################################################################

header "PASO 1: CREAR BIBLIOTECA EN KOHA"

info "Verificando si la biblioteca ya existe..."

EXISTS=$(sudo koha-mysql $INSTANCIA -e "SELECT COUNT(*) FROM branches WHERE branchcode='$BIBLIOTECA_CODE'" 2>/dev/null | tail -1)

if [ "$EXISTS" = "1" ]; then
    warning "La biblioteca '$BIBLIOTECA_CODE' ya existe en Koha"
    info "Actualizando nombre..."
else
    info "Creando nueva biblioteca..."
fi

sudo koha-mysql $INSTANCIA -e "
INSERT INTO branches (branchcode, branchname)
VALUES ('$BIBLIOTECA_CODE', '$BIBLIOTECA_NOMBRE')
ON DUPLICATE KEY UPDATE branchname='$BIBLIOTECA_NOMBRE';
" 2>&1 | tee -a "$LOGFILE"

if [ $? -eq 0 ]; then
    success "Biblioteca creada/actualizada en Koha"
else
    error "Error al crear biblioteca en Koha"
    exit 1
fi

# Verificar
sudo koha-mysql $INSTANCIA -e "SELECT * FROM branches WHERE branchcode='$BIBLIOTECA_CODE';" | tee -a "$LOGFILE"

################################################################################
# PASO 2: CONVERTIR CSV A MARCXML
################################################################################

header "PASO 2: CONVERSIÓN CSV → MARCXML"

cd "$WORK_DIR" || exit 1

info "Ejecutando conversión..."
info "Script: opac_exportar.py"
info "Parámetros:"
info "  - Input: $CSV_FILE"
info "  - Código biblioteca: $BIBLIOTECA_CODE"
info "  - Ubicación por defecto: SALA"

python3 "$WORK_DIR/opac_exportar.py" \
    -i "$CSV_FILE" \
    --codbiblio "$BIBLIOTECA_CODE" \
    --loc-default SALA \
    2>&1 | tee -a "$LOGFILE"

if [ ${PIPESTATUS[0]} -ne 0 ]; then
    error "Error en la conversión CSV → MARCXML"
    error "Ver detalles en: $LOGFILE"
    exit 1
fi

success "Conversión completada"

# Buscar archivos MARCXML generados
MARCXML_FILES=$(ls -t ${BIBLIOTECA_CODE}_*_marcxml_*.xml 2>/dev/null)

if [ -z "$MARCXML_FILES" ]; then
    error "No se encontraron archivos MARCXML generados"
    exit 1
fi

MARCXML_COUNT=$(echo "$MARCXML_FILES" | wc -l)
info "Archivos MARCXML generados: $MARCXML_COUNT"

for file in $MARCXML_FILES; do
    SIZE=$(ls -lh "$file" | awk '{print $5}')
    info "  - $file ($SIZE)"
done

################################################################################
# PASO 3: IMPORTAR A KOHA
################################################################################

header "PASO 3: IMPORTACIÓN A KOHA"

for MARCXML in $MARCXML_FILES; do
    info "Importando: $MARCXML"

    sudo koha-shell $INSTANCIA -c "
    cd $WORK_DIR && \
    /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
      -b \
      -file $MARCXML \
      -commit 1000 \
      -match 'control_number,=,001' \
    " 2>&1 | tee -a "$LOGFILE"

    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        success "Importado: $MARCXML"
    else
        error "Error importando: $MARCXML"
        warning "Continuando con siguiente archivo..."
    fi
done

success "Importación completada"

################################################################################
# PASO 4: REINDEXAR ZEBRA
################################################################################

header "PASO 4: REINDEXACIÓN DE ZEBRA"

warning "Iniciando reindexación (modo seguro con flag -b)"
warning "IMPORTANTE: NO usar -f para no borrar índices existentes"
info "Esto puede tardar varios minutos..."

# Reindexar con flag -b (seguro)
sudo koha-rebuild-zebra -b -v $INSTANCIA 2>&1 | tee -a "$LOGFILE"

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    success "Reindexación completada"
else
    warning "Reindexación completada con advertencias (revisar log)"
fi

################################################################################
# PASO 5: VERIFICACIÓN
################################################################################

header "PASO 5: VERIFICACIÓN"

info "Ejecutando verificación con agente experto..."

if [ -f "$WORK_DIR/zebra_expert_agent.py" ]; then
    python3 "$WORK_DIR/zebra_expert_agent.py" --no-fix 2>&1 | tee -a "$LOGFILE"
    success "Verificación con agente completada"
else
    warning "Agente experto no encontrado, saltando verificación automatizada"
fi

separator

info "Consultando estadísticas en base de datos..."

echo
echo "Registros bibliográficos totales:"
sudo koha-mysql $INSTANCIA -e "SELECT COUNT(*) as total FROM biblio;" 2>/dev/null

echo
echo "Ítems por biblioteca:"
sudo koha-mysql $INSTANCIA -e "
SELECT homebranch, COUNT(*) as cantidad
FROM items
GROUP BY homebranch
ORDER BY cantidad DESC;
" 2>/dev/null

echo
echo "Ítems de la nueva biblioteca ($BIBLIOTECA_CODE):"
sudo koha-mysql $INSTANCIA -e "
SELECT
    '$BIBLIOTECA_CODE' as Biblioteca,
    '$BIBLIOTECA_NOMBRE' as Nombre,
    COUNT(*) as Items_Cargados,
    COUNT(DISTINCT biblionumber) as Registros_Bibliograficos
FROM items
WHERE homebranch='$BIBLIOTECA_CODE';
" 2>/dev/null

echo
echo "Verificar duplicados de códigos de barras:"
DUPLICATES_DB=$(sudo koha-mysql $INSTANCIA -e "
SELECT COUNT(*) FROM (
    SELECT barcode
    FROM items
    WHERE homebranch='$BIBLIOTECA_CODE'
    GROUP BY barcode
    HAVING COUNT(*) > 1
) as dups;
" 2>/dev/null | tail -1)

if [ "$DUPLICATES_DB" = "0" ]; then
    success "No hay duplicados de códigos de barras"
else
    error "Se encontraron $DUPLICATES_DB códigos de barras duplicados"
    warning "Ejecutar para ver detalles:"
    warning "  sudo koha-mysql $INSTANCIA -e \"SELECT barcode, COUNT(*) FROM items WHERE homebranch='$BIBLIOTECA_CODE' GROUP BY barcode HAVING COUNT(*) > 1;\""
fi

################################################################################
# FINALIZACIÓN
################################################################################

FIN=$(date +%s)
DURACION=$((FIN - INICIO))
MINUTOS=$((DURACION / 60))
SEGUNDOS=$((DURACION % 60))

header "PROCESO COMPLETADO"

echo -e "${GREEN}✓${NC} Biblioteca cargada exitosamente"
echo
echo -e "${BOLD}Resumen:${NC}"
echo -e "  Biblioteca:     ${CYAN}$BIBLIOTECA_CODE${NC} - $BIBLIOTECA_NOMBRE"
echo -e "  Registros CSV:  ${CYAN}$TOTAL_RECORDS${NC}"
echo -e "  Archivos XML:   ${CYAN}$MARCXML_COUNT${NC}"
echo -e "  Tiempo total:   ${CYAN}${MINUTOS}m ${SEGUNDOS}s${NC}"
echo
echo -e "${BOLD}Próximos pasos:${NC}"
echo "  1. Verificar en el OPAC: https://koha.cnc.una.py"
echo "  2. Buscar algunos títulos para confirmar"
echo "  3. Verificar que los ítems tengan la ubicación correcta"
echo
echo -e "${BOLD}Archivos generados:${NC}"
echo "  - Log completo: $LOGFILE"
echo "  - MARCXML: ${BIBLIOTECA_CODE}_*_marcxml_*.xml"
echo
echo -e "${BOLD}Comandos útiles:${NC}"
echo "  # Ver log"
echo "  cat $LOGFILE"
echo
echo "  # Verificar con agente experto"
echo "  sudo python3 $WORK_DIR/zebra_expert_agent.py"
echo
echo "  # Ver estadísticas"
echo "  sudo koha-mysql $INSTANCIA -e \"SELECT homebranch, COUNT(*) FROM items GROUP BY homebranch;\""
echo

success "¡Carga de biblioteca completada! 🎉"

exit 0
