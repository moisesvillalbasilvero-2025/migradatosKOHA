#!/bin/bash

################################################################################
# IMPORTADOR AUTOMÁTICO DE BIBLIOTECAS
################################################################################
# Universidad Nacional de Asunción - Sistema Koha
#
# Busca archivos CSV automáticamente y los importa al catálogo Koha
# con control de duplicados y filtrado por biblioteca
#
# CARACTERÍSTICAS:
# - Detección automática de código de biblioteca desde nombre de archivo
# - Verificación de duplicados antes de importar
# - Filtrado y búsqueda por biblioteca específica
# - Logs detallados de cada operación
# - Reportes completos post-importación
# - Respaldo automático de archivos procesados
#
# USO:
#   ./importar_automatico.sh                    # Buscar todos los CSV
#   ./importar_automatico.sh --dir /ruta        # Buscar en directorio específico
#   ./importar_automatico.sh --biblioteca MED   # Solo biblioteca MED
#   ./importar_automatico.sh --watch            # Modo vigilancia continua
#
# EJEMPLOS:
#   ./importar_automatico.sh --dir /tmp/datos
#   ./importar_automatico.sh --biblioteca VET
#   ./importar_automatico.sh --watch --dir importar_aqui/
#
# VERSIÓN: 2.0
# FECHA: 2025-10-24
################################################################################

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuración
INSTANCIA_KOHA="koha-cnc"
DIR_TRABAJO="/home/mvillalba/migradatos"
DIR_IMPORTAR="${DIR_TRABAJO}/importar_aqui"
DIR_PROCESADOS="${DIR_TRABAJO}/procesados"
DIR_ERRORES="${DIR_TRABAJO}/errores"
DIR_LOGS="${DIR_TRABAJO}/logs"
AGENTE_PYTHON="${DIR_TRABAJO}/agente_importador_v2.py"

# Variables
BIBLIOTECA_FILTRO=""
DIR_BUSQUEDA="$DIR_IMPORTAR"
MODO_WATCH=false
INTERVALO_WATCH=10

# ==================== FUNCIONES ====================

mostrar_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                                                                    ║"
    echo "║           IMPORTADOR AUTOMÁTICO DE BIBLIOTECAS                     ║"
    echo "║           Universidad Nacional de Asunción                         ║"
    echo "║                                                                    ║"
    echo "╔════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

mostrar_ayuda() {
    cat << EOF
${BOLD}IMPORTADOR AUTOMÁTICO DE BIBLIOTECAS${NC}

Busca y procesa archivos CSV automáticamente para importación a Koha

${BOLD}USO:${NC}
    $0 [OPCIONES]

${BOLD}OPCIONES:${NC}
    --dir DIR               Directorio donde buscar archivos CSV
                           (por defecto: $DIR_IMPORTAR)

    --biblioteca CODIGO     Filtrar solo biblioteca específica
                           Ejemplos: MED, VET, ING, FACAGR

    --watch                 Modo vigilancia continua
                           Busca nuevos archivos cada $INTERVALO_WATCH segundos

    --intervalo SEGUNDOS    Intervalo para modo watch (por defecto: $INTERVALO_WATCH)

    --help, -h              Mostrar esta ayuda

${BOLD}EJEMPLOS:${NC}
    # Procesar todos los CSV en carpeta por defecto
    $0

    # Buscar en directorio específico
    $0 --dir /tmp/datos_bibliotecas

    # Solo procesar biblioteca MED
    $0 --biblioteca MED

    # Procesar solo VET en directorio específico
    $0 --dir /datos --biblioteca VET

    # Modo vigilancia continua
    $0 --watch

    # Vigilancia cada 30 segundos
    $0 --watch --intervalo 30

${BOLD}REQUISITOS:${NC}
    - Archivos CSV deben tener código de biblioteca en el nombre
      Ejemplos: MED.csv, VET_2025.csv, ING_octubre.csv
    - La biblioteca debe existir en Koha
    - Campos obligatorios en CSV: titulo, nroacceso

${BOLD}CONTROL DE DUPLICADOS:${NC}
    El sistema verifica automáticamente duplicados de dos formas:
    1. Dentro del CSV (códigos de acceso repetidos)
    2. Contra base de datos Koha (registros ya existentes)

${BOLD}ARCHIVOS GENERADOS:${NC}
    logs/            - Logs detallados de cada importación
    procesados/      - CSV procesados exitosamente
    errores/         - CSV con errores
    exports/         - Archivos MARCXML generados

Universidad Nacional de Asunción - 2025
EOF
}

log_info() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${CYAN}[${timestamp}] INFO: $1${NC}"
    echo "[${timestamp}] INFO: $1" >> "$LOG_GENERAL"
}

log_success() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${GREEN}[${timestamp}] ✓ $1${NC}"
    echo "[${timestamp}] SUCCESS: $1" >> "$LOG_GENERAL"
}

log_warning() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${YELLOW}[${timestamp}] ⚠ $1${NC}"
    echo "[${timestamp}] WARNING: $1" >> "$LOG_GENERAL"
}

log_error() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${RED}[${timestamp}] ✗ $1${NC}"
    echo "[${timestamp}] ERROR: $1" >> "$LOG_GENERAL"
}

detectar_codigo_biblioteca() {
    local archivo="$1"
    local nombre=$(basename "$archivo" .csv)

    # Intentar extraer código (3-6 letras mayúsculas)
    local codigo=$(echo "$nombre" | grep -o -E '[A-Z]{3,6}' | head -1)

    if [ -z "$codigo" ]; then
        return 1
    fi

    echo "$codigo"
    return 0
}

verificar_biblioteca_existe() {
    local codigo="$1"

    local existe=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM branches WHERE branchcode = '${codigo}'" 2>/dev/null)

    if [ "$existe" = "1" ]; then
        return 0
    else
        return 1
    fi
}

verificar_duplicados_koha() {
    local codigo="$1"

    local items=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM items WHERE homebranch = '${codigo}'" 2>/dev/null)

    echo "$items"
}

buscar_archivos_csv() {
    local directorio="$1"
    local filtro="$2"

    if [ ! -d "$directorio" ]; then
        log_error "Directorio no existe: $directorio"
        return 1
    fi

    local archivos_encontrados=()

    # Buscar archivos CSV
    while IFS= read -r archivo; do
        if [ -f "$archivo" ]; then
            local codigo=$(detectar_codigo_biblioteca "$archivo")

            # Si hay filtro, verificar coincidencia
            if [ -n "$filtro" ]; then
                if [ "$codigo" = "$filtro" ]; then
                    archivos_encontrados+=("$archivo")
                fi
            else
                archivos_encontrados+=("$archivo")
            fi
        fi
    done < <(find "$directorio" -maxdepth 1 -type f -name "*.csv" 2>/dev/null)

    # Retornar archivos encontrados
    for archivo in "${archivos_encontrados[@]}"; do
        echo "$archivo"
    done

    return 0
}

procesar_archivo() {
    local archivo="$1"

    log_info "Iniciando procesamiento: $(basename "$archivo")"

    # Detectar código
    local codigo=$(detectar_codigo_biblioteca "$archivo")

    if [ -z "$codigo" ]; then
        log_error "No se detectó código de biblioteca en: $(basename "$archivo")"
        log_info "El nombre debe contener 3-6 letras mayúsculas (ej: MED.csv)"
        return 1
    fi

    log_success "Código detectado: $codigo"

    # Verificar que biblioteca existe
    if ! verificar_biblioteca_existe "$codigo"; then
        log_error "La biblioteca '$codigo' NO existe en Koha"
        log_info "Créela en: Staff Interface → Administración → Bibliotecas"
        return 1
    fi

    local nombre_bib=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT branchname FROM branches WHERE branchcode = '${codigo}'" 2>/dev/null)
    log_success "Biblioteca verificada: $nombre_bib"

    # Verificar duplicados
    local items_existentes=$(verificar_duplicados_koha "$codigo")
    log_info "Items existentes en Koha para $codigo: $items_existentes"

    if [ "$items_existentes" -gt 0 ]; then
        log_warning "Ya existen $items_existentes items de esta biblioteca"
        echo -e "${YELLOW}Se agregarán NUEVOS registros (no se duplicarán los existentes)${NC}"

        read -p "¿Desea continuar? (SI/no): " -r respuesta
        if [[ ! $respuesta =~ ^(SI|si|S|s|YES|yes|Y|y|)$ ]]; then
            log_warning "Importación cancelada por el usuario"
            return 1
        fi
    fi

    # Ejecutar agente de importación
    echo ""
    log_info "Ejecutando agente de importación..."
    echo ""

    if [ -x "$AGENTE_PYTHON" ]; then
        "$AGENTE_PYTHON" "$archivo"
        local resultado=$?

        if [ $resultado -eq 0 ]; then
            log_success "Importación completada exitosamente: $codigo"
            return 0
        else
            log_error "Error durante la importación de: $(basename "$archivo")"
            return 1
        fi
    else
        log_error "Agente de importación no encontrado o no ejecutable: $AGENTE_PYTHON"
        return 1
    fi
}

modo_normal() {
    log_info "Buscando archivos CSV en: $DIR_BUSQUEDA"

    if [ -n "$BIBLIOTECA_FILTRO" ]; then
        log_info "Filtrando por biblioteca: $BIBLIOTECA_FILTRO"
    fi

    # Buscar archivos
    mapfile -t archivos < <(buscar_archivos_csv "$DIR_BUSQUEDA" "$BIBLIOTECA_FILTRO")

    if [ ${#archivos[@]} -eq 0 ]; then
        log_warning "No se encontraron archivos CSV para procesar"

        if [ -n "$BIBLIOTECA_FILTRO" ]; then
            log_info "Verifique que existan archivos con código '$BIBLIOTECA_FILTRO' en el nombre"
        fi

        return 1
    fi

    log_success "Archivos encontrados: ${#archivos[@]}"
    echo ""

    # Mostrar archivos
    for i in "${!archivos[@]}"; do
        local archivo="${archivos[$i]}"
        local codigo=$(detectar_codigo_biblioteca "$archivo")
        echo -e "  ${BOLD}$((i+1)).${NC} $(basename "$archivo") ${CYAN}[$codigo]${NC}"
    done

    echo ""
    read -p "¿Procesar estos archivos? (SI/no): " -r respuesta

    if [[ ! $respuesta =~ ^(SI|si|S|s|YES|yes|Y|y|)$ ]]; then
        log_warning "Procesamiento cancelado por el usuario"
        return 0
    fi

    # Procesar cada archivo
    local exitosos=0
    local fallidos=0

    for archivo in "${archivos[@]}"; do
        echo ""
        echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════════${NC}"

        if procesar_archivo "$archivo"; then
            ((exitosos++))
        else
            ((fallidos++))
        fi

        echo -e "${BOLD}${CYAN}════════════════════════════════════════════════════════════════════${NC}"
        echo ""
    done

    # Resumen
    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║                      RESUMEN DE PROCESAMIENTO                      ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  Total archivos:    ${BOLD}${#archivos[@]}${NC}"
    echo -e "  ${GREEN}Exitosos:          ${BOLD}${exitosos}${NC}"

    if [ $fallidos -gt 0 ]; then
        echo -e "  ${RED}Fallidos:          ${BOLD}${fallidos}${NC}"
    fi

    echo ""
    log_success "Procesamiento completado"

    return 0
}

modo_vigilancia() {
    log_info "MODO VIGILANCIA ACTIVADO"
    log_info "Directorio: $DIR_BUSQUEDA"
    log_info "Intervalo: ${INTERVALO_WATCH}s"

    if [ -n "$BIBLIOTECA_FILTRO" ]; then
        log_info "Filtro: $BIBLIOTECA_FILTRO"
    fi

    echo ""
    echo -e "${YELLOW}Presione Ctrl+C para detener${NC}"
    echo ""

    declare -A archivos_procesados

    while true; do
        # Buscar archivos
        mapfile -t archivos < <(buscar_archivos_csv "$DIR_BUSQUEDA" "$BIBLIOTECA_FILTRO")

        # Procesar nuevos archivos
        for archivo in "${archivos[@]}"; do
            local hash=$(md5sum "$archivo" | cut -d' ' -f1)

            if [ -z "${archivos_procesados[$archivo]}" ] || [ "${archivos_procesados[$archivo]}" != "$hash" ]; then
                echo ""
                log_info "🔔 NUEVO ARCHIVO DETECTADO: $(basename "$archivo")"
                echo ""

                sleep 2  # Esperar estabilidad

                if procesar_archivo "$archivo"; then
                    archivos_procesados[$archivo]=$hash
                else
                    log_error "Error procesando: $(basename "$archivo")"
                fi

                echo ""
            fi
        done

        sleep "$INTERVALO_WATCH"
    done
}

generar_estadisticas() {
    echo ""
    echo -e "${BOLD}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║                    ESTADÍSTICAS DEL CATÁLOGO                       ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # Obtener estadísticas de Koha
    echo -e "${CYAN}Bibliotecas con items en Koha:${NC}"
    echo ""

    sudo koha-mysql ${INSTANCIA_KOHA} -t -e "
    SELECT
        b.branchcode AS 'Código',
        b.branchname AS 'Nombre',
        COUNT(i.itemnumber) AS 'Items'
    FROM branches b
    LEFT JOIN items i ON b.branchcode = i.homebranch
    GROUP BY b.branchcode, b.branchname
    HAVING COUNT(i.itemnumber) > 0
    ORDER BY COUNT(i.itemnumber) DESC;
    " 2>/dev/null

    echo ""

    # Total general
    local total_items=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM items" 2>/dev/null)
    local total_biblios=$(sudo koha-mysql ${INSTANCIA_KOHA} -N -e "SELECT COUNT(*) FROM biblio" 2>/dev/null)

    echo -e "${BOLD}Total general:${NC}"
    echo -e "  Biblios:  ${BOLD}${total_biblios}${NC}"
    echo -e "  Items:    ${BOLD}${total_items}${NC}"
    echo ""
}

# ==================== PROCESAR ARGUMENTOS ====================

while [[ $# -gt 0 ]]; do
    case $1 in
        --dir)
            DIR_BUSQUEDA="$2"
            shift 2
            ;;
        --biblioteca)
            BIBLIOTECA_FILTRO="$2"
            shift 2
            ;;
        --watch)
            MODO_WATCH=true
            shift
            ;;
        --intervalo)
            INTERVALO_WATCH="$2"
            shift 2
            ;;
        --stats|--estadisticas)
            mostrar_banner
            generar_estadisticas
            exit 0
            ;;
        --help|-h)
            mostrar_ayuda
            exit 0
            ;;
        *)
            echo -e "${RED}Opción desconocida: $1${NC}"
            echo "Use --help para ver opciones disponibles"
            exit 1
            ;;
    esac
done

# ==================== INICIO ====================

# Crear directorios necesarios
mkdir -p "$DIR_IMPORTAR" "$DIR_PROCESADOS" "$DIR_ERRORES" "$DIR_LOGS"

# Configurar log general
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_GENERAL="${DIR_LOGS}/importador_automatico_${TIMESTAMP}.log"

# Banner
mostrar_banner

# Verificar que existe el agente Python
if [ ! -f "$AGENTE_PYTHON" ]; then
    log_error "Agente de importación no encontrado: $AGENTE_PYTHON"
    exit 1
fi

if [ ! -x "$AGENTE_PYTHON" ]; then
    log_warning "Agente no ejecutable, agregando permisos..."
    chmod +x "$AGENTE_PYTHON"
fi

# Verificar acceso a Koha
if ! sudo koha-mysql ${INSTANCIA_KOHA} -e "SELECT 1" &>/dev/null; then
    log_error "No se puede conectar a Koha: $INSTANCIA_KOHA"
    exit 1
fi

log_success "Conexión a Koha verificada"

# Ejecutar modo correspondiente
if [ "$MODO_WATCH" = true ]; then
    modo_vigilancia
else
    modo_normal
fi

log_success "Proceso finalizado"
echo ""

exit 0
