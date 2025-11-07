#!/bin/bash

################################################################################
# SCRIPT DE REORGANIZACIÓN DEL SISTEMA
################################################################################
# Reorganiza la carpeta migradatos dejando solo archivos útiles y optimizados
#
# ESTRUCTURA NUEVA:
#   /scripts/              - Scripts principales
#   /docs/                 - Documentación esencial
#   /config/               - Archivos de configuración
#   /_obsoletos/           - Archivos antiguos/obsoletos
#   /importar_aqui/        - Entrada de CSV
#   /procesados/           - CSV procesados
#   /errores/              - CSV con errores
#   /exports/              - MARCXML generados
#   /logs/                 - Logs y reportes
#
# USO:
#   ./REORGANIZAR_SISTEMA.sh
#   ./REORGANIZAR_SISTEMA.sh --dry-run    # Solo mostrar, no mover
#
# VERSIÓN: 1.0
# FECHA: 2025-10-24
################################################################################

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

DRY_RUN=false

if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    echo -e "${YELLOW}MODO DRY-RUN: Solo mostrará cambios sin ejecutar${NC}"
    echo ""
fi

echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}${BOLD}║                                                                    ║${NC}"
echo -e "${CYAN}${BOLD}║              REORGANIZACIÓN DEL SISTEMA MIGRADATOS                 ║${NC}"
echo -e "${CYAN}${BOLD}║                                                                    ║${NC}"
echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# ==================== CREAR ESTRUCTURA ====================

echo -e "${BOLD}1. CREAR NUEVA ESTRUCTURA${NC}"
echo "────────────────────────────────────────────────────────────────────"

DIRS=(
    "scripts"
    "docs"
    "config"
    "_obsoletos"
    "importar_aqui"
    "procesados"
    "errores"
    "exports"
    "logs"
)

for dir in "${DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        if [ "$DRY_RUN" = false ]; then
            mkdir -p "$dir"
        fi
        echo -e "${GREEN}✓${NC} Crear: $dir/"
    else
        echo -e "${CYAN}·${NC} Existe: $dir/"
    fi
done
echo ""

# ==================== MOVER SCRIPTS PRINCIPALES ====================

echo -e "${BOLD}2. ORGANIZAR SCRIPTS PRINCIPALES${NC}"
echo "────────────────────────────────────────────────────────────────────"

SCRIPTS_PRINCIPALES=(
    "agente_importador_v2.py"
    "importar_automatico.sh"
    "importar_con_tmux.sh"
    "subir_csv.sh"
    "reindexar_optimizado.sh"
    "opac_exportar.py"
)

for script in "${SCRIPTS_PRINCIPALES[@]}"; do
    if [ -f "$script" ]; then
        if [ "$DRY_RUN" = false ]; then
            mv "$script" scripts/
        fi
        echo -e "${GREEN}→${NC} scripts/$script"
    fi
done
echo ""

# ==================== MOVER DOCUMENTACIÓN ESENCIAL ====================

echo -e "${BOLD}3. ORGANIZAR DOCUMENTACIÓN ESENCIAL${NC}"
echo "────────────────────────────────────────────────────────────────────"

DOCS_ESENCIALES=(
    "GUIA_DIDACTICA_IMPORTADOR_V2.md"
    "GUIA_AGENTE_AUTOMATICO.md"
    "GUIA_OPTIMIZACION_RECURSOS_LIMITADOS.md"
    "INICIO_RAPIDO_AGENTE.txt"
    "COMO_SUBIR_ARCHIVOS.txt"
    "INDICE_DOCUMENTACION_COMPLETA.txt"
    "README.md"
)

for doc in "${DOCS_ESENCIALES[@]}"; do
    if [ -f "$doc" ]; then
        if [ "$DRY_RUN" = false ]; then
            mv "$doc" docs/
        fi
        echo -e "${GREEN}→${NC} docs/$doc"
    fi
done
echo ""

# ==================== MOVER CONFIGURACIÓN ====================

echo -e "${BOLD}4. ORGANIZAR ARCHIVOS DE CONFIGURACIÓN${NC}"
echo "────────────────────────────────────────────────────────────────────"

CONFIG_FILES=(
    "migracion_config.json"
)

for config in "${CONFIG_FILES[@]}"; do
    if [ -f "$config" ]; then
        if [ "$DRY_RUN" = false ]; then
            mv "$config" config/
        fi
        echo -e "${GREEN}→${NC} config/$config"
    fi
done
echo ""

# ==================== MOVER SCRIPTS ANTIGUOS ====================

echo -e "${BOLD}5. MOVER SCRIPTS OBSOLETOS${NC}"
echo "────────────────────────────────────────────────────────────────────"

SCRIPTS_OBSOLETOS=(
    "agente_importador.py"
    "auto_importar.py"
    "importador_automatico.py"
    "migracion_automatizada.py"
    "cargar_biblioteca.sh"
    "importar_ing_prueba.sh"
    "importar_ing_completo.sh"
    "importar_nueva_biblioteca.sh"
    "importar_multiples.sh"
    "importar_perfecto.sh"
    "reindexar_ing_rapido.sh"
    "reindexar_solo_ing.sh"
    "reindexar_koha.sh"
    "sincronizar_arquitectura.sh"
    "test_sistema.sh"
    "verificar_duplicados.sh"
)

for script in "${SCRIPTS_OBSOLETOS[@]}"; do
    if [ -f "$script" ]; then
        if [ "$DRY_RUN" = false ]; then
            mv "$script" _obsoletos/
        fi
        echo -e "${YELLOW}→${NC} _obsoletos/$script"
    fi
done
echo ""

# ==================== MOVER DOCUMENTACIÓN ANTIGUA ====================

echo -e "${BOLD}6. MOVER DOCUMENTACIÓN ANTIGUA${NC}"
echo "────────────────────────────────────────────────────────────────────"

DOCS_ANTIGUOS=(
    "00_INICIO_AQUI.md"
    "ANALISIS_Y_PLAN.md"
    "ESTADO_ACTUAL_MIGRACION.md"
    "GUIA_CARGA_NUEVAS_BIBLIOTECAS.md"
    "GUIA_COMPLETA_MAPEO_CAMPOS_KOHA.md"
    "GUIA_DIDACTICA_COMPLETA.md"
    "GUIA_IMPORTACION_INGENIERIA.md"
    "GUIA_OPERACIONES_DIARIAS.md"
    "GUIA_PRESENTACION_JEFES.md"
    "GUIA_RAPIDA.md"
    "IMPORTACION_PERFECTA.md"
    "IMPORTAR_FACIL.md"
    "IMPORTAR_SIMULTANEO.md"
    "INDICE_DOCUMENTACION.md"
    "SISTEMA_DESCENTRALIZADO.md"
    "SISTEMA_TOTALMENTE_AUTOMATIZADO.md"
    "SISTEMA_LISTO.md"
    "SINCRONIZACION_ARQUITECTURA.md"
    "COMO_IMPORTAR_NUEVA_BIBLIOTECA.md"
    "TUTORIAL_PASO_A_PASO.md"
    "COMO_USAR_AUTO_IMPORTAR.txt"
    "RESUMEN_AUTO_IMPORTADOR.txt"
    "RESUMEN_SISTEMA_AGENTE.txt"
    "INICIO_RAPIDO.txt"
    "INSTRUCCIONES_RAPIDAS.txt"
    "COMANDOS_RAPIDOS.txt"
    "CHEATSHEET.txt"
)

for doc in "${DOCS_ANTIGUOS[@]}"; do
    if [ -f "$doc" ]; then
        if [ "$DRY_RUN" = false ]; then
            mv "$doc" _obsoletos/
        fi
        echo -e "${YELLOW}→${NC} _obsoletos/$doc"
    fi
done
echo ""

# ==================== MOVER ARCHIVOS DE ANÁLISIS ====================

echo -e "${BOLD}7. MOVER ARCHIVOS DE ANÁLISIS${NC}"
echo "────────────────────────────────────────────────────────────────────"

ANALISIS=(
    "analisis_*.json"
    "ANALISIS_*.md"
    "PLANTILLA_*.md"
    "REPORTE_*.md"
    "FILTRADO_*.md"
)

for pattern in "${ANALISIS[@]}"; do
    for file in $pattern 2>/dev/null; do
        if [ -f "$file" ]; then
            if [ "$DRY_RUN" = false ]; then
                mv "$file" _obsoletos/
            fi
            echo -e "${YELLOW}→${NC} _obsoletos/$file"
        fi
    done
done
echo ""

# ==================== CREAR ENLACES SIMBÓLICOS ====================

echo -e "${BOLD}8. CREAR ENLACES SIMBÓLICOS EN RAÍZ${NC}"
echo "────────────────────────────────────────────────────────────────────"

if [ "$DRY_RUN" = false ]; then
    # Enlaces a scripts principales
    ln -sf scripts/agente_importador_v2.py agente_importador_v2.py
    ln -sf scripts/importar_automatico.sh importar_automatico.sh
    ln -sf scripts/importar_con_tmux.sh importar_con_tmux.sh
    ln -sf scripts/subir_csv.sh subir_csv.sh
    ln -sf scripts/reindexar_optimizado.sh reindexar_optimizado.sh

    # Enlaces a docs principales
    ln -sf docs/README.md README.md
    ln -sf docs/INICIO_RAPIDO_AGENTE.txt LEEME.txt
fi

echo -e "${GREEN}✓${NC} Enlaces simbólicos creados en raíz"
echo ""

# ==================== LIMPIAR ARCHIVOS TEMPORALES ====================

echo -e "${BOLD}9. LIMPIAR ARCHIVOS TEMPORALES${NC}"
echo "────────────────────────────────────────────────────────────────────"

if [ "$DRY_RUN" = false ]; then
    # Limpiar CSVs antiguos en raíz
    if ls *.csv 1> /dev/null 2>&1; then
        for csv in *.csv; do
            if [ "$csv" != "QUI.csv" ]; then
                mv "$csv" _obsoletos/
                echo -e "${YELLOW}→${NC} _obsoletos/$csv"
            fi
        done
    fi

    # Limpiar XMLs antiguos en raíz
    if ls *.xml 1> /dev/null 2>&1; then
        for xml in *.xml; do
            mv "$xml" exports/
            echo -e "${GREEN}→${NC} exports/$xml"
        done
    fi
fi
echo ""

# ==================== RESUMEN ====================

echo -e "${BOLD}RESUMEN DE REORGANIZACIÓN${NC}"
echo "════════════════════════════════════════════════════════════════════"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo -e "${GREEN}NUEVA ESTRUCTURA:${NC}"
    echo ""
    echo "scripts/           - Scripts principales (5 archivos)"
    echo "  ├─ agente_importador_v2.py"
    echo "  ├─ importar_automatico.sh"
    echo "  ├─ importar_con_tmux.sh"
    echo "  ├─ subir_csv.sh"
    echo "  └─ reindexar_optimizado.sh"
    echo ""
    echo "docs/              - Documentación esencial (7 archivos)"
    echo "  ├─ GUIA_DIDACTICA_IMPORTADOR_V2.md"
    echo "  ├─ GUIA_AGENTE_AUTOMATICO.md"
    echo "  ├─ GUIA_OPTIMIZACION_RECURSOS_LIMITADOS.md"
    echo "  ├─ INICIO_RAPIDO_AGENTE.txt"
    echo "  ├─ COMO_SUBIR_ARCHIVOS.txt"
    echo "  ├─ INDICE_DOCUMENTACION_COMPLETA.txt"
    echo "  └─ README.md"
    echo ""
    echo "config/            - Configuración"
    echo "  └─ migracion_config.json"
    echo ""
    echo "importar_aqui/     - Entrada de CSV"
    echo "procesados/        - CSV procesados"
    echo "errores/           - CSV con errores"
    echo "exports/           - MARCXML generados"
    echo "logs/              - Logs y reportes"
    echo ""
    echo "_obsoletos/        - Archivos antiguos (no se usan)"
    echo ""
    echo -e "${GREEN}✓${NC} Raíz limpia con enlaces simbólicos a scripts"
    echo ""

    # Contar archivos
    TOTAL_OBSOLETOS=$(ls -1 _obsoletos/ 2>/dev/null | wc -l)
    echo -e "${YELLOW}Archivos movidos a _obsoletos/: ${TOTAL_OBSOLETOS}${NC}"
    echo ""

    echo -e "${CYAN}${BOLD}✓✓✓ REORGANIZACIÓN COMPLETADA ✓✓✓${NC}"
else
    echo -e "${YELLOW}Ejecute sin --dry-run para aplicar cambios${NC}"
fi

echo ""
echo -e "${CYAN}ACCESO RÁPIDO:${NC}"
echo "  ./agente_importador_v2.py    - Importador principal"
echo "  ./importar_automatico.sh      - Orquestador automático"
echo "  ./importar_con_tmux.sh        - Con continuidad tmux"
echo "  cat LEEME.txt                 - Inicio rápido"
echo ""

exit 0
