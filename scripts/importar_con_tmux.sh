#!/bin/bash

################################################################################
# IMPORTADOR CON TMUX - ASEGURA CONTINUIDAD
################################################################################
# Este script ejecuta el importador automático dentro de una sesión tmux
# para asegurar que las importaciones continúen incluso si te desconectas
#
# USO:
#   ./importar_con_tmux.sh                    # Modo normal en tmux
#   ./importar_con_tmux.sh --watch            # Modo vigilancia en tmux
#   ./importar_con_tmux.sh --attach           # Conectar a sesión existente
#   ./importar_con_tmux.sh --status           # Ver estado de sesiones
#   ./importar_con_tmux.sh --kill             # Detener todas las sesiones
#
# VENTAJAS:
#   • Las importaciones continúan si te desconectas
#   • Puedes reconectar y ver el progreso
#   • Múltiples sesiones independientes
#   • Logs permanentes
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

SESION_NOMBRE="importacion-koha"
DIR_TRABAJO="/home/mvillalba/migradatos"

mostrar_ayuda() {
    cat << EOF
${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗
║                                                                      ║
║              IMPORTADOR CON TMUX - CONTINUIDAD ASEGURADA             ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝${NC}

${BOLD}USO:${NC}
    $0 [OPCIÓN]

${BOLD}OPCIONES:${NC}
    (sin opción)        Ejecutar importador normal en tmux
    --watch, -w         Ejecutar modo vigilancia en tmux
    --attach, -a        Conectar a sesión existente
    --status, -s        Ver estado de sesiones tmux
    --kill, -k          Detener todas las sesiones de importación
    --help, -h          Mostrar esta ayuda

${BOLD}EJEMPLOS:${NC}
    # Iniciar importación en tmux
    $0

    # Modo vigilancia continua en tmux
    $0 --watch

    # Reconectar a sesión activa
    $0 --attach

    # Ver qué sesiones están corriendo
    $0 --status

    # Detener todas las importaciones
    $0 --kill

${BOLD}COMANDOS TMUX ÚTILES:${NC}
    Ctrl+b d            Desconectar de sesión (sigue corriendo)
    tmux ls             Listar sesiones activas
    tmux attach         Reconectar a sesión
    tmux kill-session   Cerrar sesión

${BOLD}VENTAJAS DE USAR TMUX:${NC}
    ✅ Las importaciones continúan si cierras la terminal
    ✅ Puedes desconectarte y reconectar
    ✅ Perfecto para importaciones largas
    ✅ Ver progreso en tiempo real cuando quieras

Universidad Nacional de Asunción - 2025
EOF
}

verificar_tmux() {
    if ! command -v tmux &> /dev/null; then
        echo -e "${RED}✗ tmux no está instalado${NC}"
        echo ""
        echo "Instalar con:"
        echo "  sudo apt install tmux -y"
        echo ""
        exit 1
    fi
}

listar_sesiones() {
    echo -e "${CYAN}${BOLD}SESIONES TMUX ACTIVAS:${NC}"
    echo ""

    if tmux ls 2>/dev/null; then
        echo ""
        echo -e "${GREEN}Para conectar a una sesión:${NC}"
        echo "  tmux attach -t NOMBRE_SESION"
        echo ""
        echo "O usar:"
        echo "  ./importar_con_tmux.sh --attach"
    else
        echo -e "${YELLOW}No hay sesiones tmux activas${NC}"
        echo ""
        echo "Iniciar nueva sesión:"
        echo "  ./importar_con_tmux.sh"
    fi
}

conectar_sesion() {
    if tmux has-session -t "$SESION_NOMBRE" 2>/dev/null; then
        echo -e "${CYAN}Conectando a sesión: ${BOLD}$SESION_NOMBRE${NC}"
        echo ""
        tmux attach -t "$SESION_NOMBRE"
    else
        echo -e "${YELLOW}No existe sesión con nombre: $SESION_NOMBRE${NC}"
        echo ""
        echo "Sesiones disponibles:"
        tmux ls 2>/dev/null || echo -e "${YELLOW}  (ninguna)${NC}"
        echo ""
        echo "Crear nueva sesión:"
        echo "  ./importar_con_tmux.sh"
    fi
}

detener_sesiones() {
    echo -e "${YELLOW}Deteniendo sesiones de importación...${NC}"
    echo ""

    if tmux has-session -t "$SESION_NOMBRE" 2>/dev/null; then
        tmux kill-session -t "$SESION_NOMBRE"
        echo -e "${GREEN}✓ Sesión '$SESION_NOMBRE' detenida${NC}"
    else
        echo -e "${YELLOW}No hay sesión '$SESION_NOMBRE' activa${NC}"
    fi

    echo ""
}

ejecutar_importacion() {
    local modo="$1"

    verificar_tmux

    # Verificar si ya existe una sesión
    if tmux has-session -t "$SESION_NOMBRE" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Ya existe una sesión de importación activa: ${BOLD}$SESION_NOMBRE${NC}"
        echo ""
        read -p "¿Deseas conectarte a ella? (SI/no): " respuesta

        if [[ $respuesta =~ ^(SI|si|S|s|YES|yes|Y|y|)$ ]]; then
            tmux attach -t "$SESION_NOMBRE"
        else
            echo ""
            echo "Para detener la sesión existente:"
            echo "  ./importar_con_tmux.sh --kill"
        fi
        exit 0
    fi

    # Preparar comando según modo
    local comando=""
    local descripcion=""

    if [ "$modo" = "watch" ]; then
        comando="./importar_automatico.sh --watch"
        descripcion="MODO VIGILANCIA"
    else
        comando="./importar_automatico.sh"
        descripcion="MODO NORMAL"
    fi

    # Banner
    echo ""
    echo -e "${CYAN}${BOLD}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║       INICIANDO IMPORTACIÓN EN TMUX - $descripcion          ║${NC}"
    echo -e "${CYAN}${BOLD}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Sesión:${NC}   $SESION_NOMBRE"
    echo -e "${GREEN}Comando:${NC}  $comando"
    echo -e "${GREEN}Directorio:${NC} $DIR_TRABAJO"
    echo ""
    echo -e "${CYAN}${BOLD}IMPORTANTE:${NC}"
    echo -e "  • La importación correrá en segundo plano"
    echo -e "  • Puedes cerrar esta terminal sin interrumpir el proceso"
    echo -e "  • Para ver el progreso: ${BOLD}./importar_con_tmux.sh --attach${NC}"
    echo -e "  • Para desconectar de tmux: ${BOLD}Ctrl+b luego d${NC}"
    echo ""

    read -p "¿Continuar? (SI/no): " respuesta

    if [[ ! $respuesta =~ ^(SI|si|S|s|YES|yes|Y|y|)$ ]]; then
        echo -e "${YELLOW}Cancelado${NC}"
        exit 0
    fi

    echo ""
    echo -e "${CYAN}Creando sesión tmux...${NC}"

    # Crear sesión tmux y ejecutar comando
    tmux new-session -d -s "$SESION_NOMBRE" -c "$DIR_TRABAJO"
    tmux send-keys -t "$SESION_NOMBRE" "$comando" C-m

    sleep 2

    echo -e "${GREEN}✓ Sesión iniciada: ${BOLD}$SESION_NOMBRE${NC}"
    echo ""
    echo -e "${CYAN}${BOLD}PRÓXIMOS PASOS:${NC}"
    echo ""
    echo "1. Ver progreso en tiempo real:"
    echo "   ${BOLD}./importar_con_tmux.sh --attach${NC}"
    echo "   o"
    echo "   ${BOLD}tmux attach -t $SESION_NOMBRE${NC}"
    echo ""
    echo "2. Ver estado de sesiones:"
    echo "   ${BOLD}./importar_con_tmux.sh --status${NC}"
    echo ""
    echo "3. Ver logs:"
    echo "   ${BOLD}tail -f logs/importacion_*.log${NC}"
    echo ""
    echo "4. Detener sesión:"
    echo "   ${BOLD}./importar_con_tmux.sh --kill${NC}"
    echo ""
    echo -e "${GREEN}La importación está corriendo en segundo plano.${NC}"
    echo -e "${GREEN}Puedes cerrar esta terminal sin problemas.${NC}"
    echo ""
}

# ==================== MAIN ====================

case "${1:-}" in
    --watch|-w)
        ejecutar_importacion "watch"
        ;;
    --attach|-a)
        verificar_tmux
        conectar_sesion
        ;;
    --status|-s)
        verificar_tmux
        listar_sesiones
        ;;
    --kill|-k)
        verificar_tmux
        detener_sesiones
        ;;
    --help|-h)
        mostrar_ayuda
        ;;
    "")
        ejecutar_importacion "normal"
        ;;
    *)
        echo -e "${RED}Opción desconocida: $1${NC}"
        echo ""
        mostrar_ayuda
        exit 1
        ;;
esac

exit 0
