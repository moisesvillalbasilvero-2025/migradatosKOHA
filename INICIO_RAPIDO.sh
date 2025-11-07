#!/bin/bash
################################################################################
# INICIO RÁPIDO - Acceso directo al sistema de importación con tmux
################################################################################
# Script de acceso rápido que muestra el menú de inicio y opciones comunes
################################################################################

clear

readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_CYAN='\033[0;36m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════════════════╗
║                                                                               ║
║   ██████╗ ██╗███████╗████████╗███████╗███╗   ███╗ █████╗                     ║
║  ██╔════╝██║██╔════╝╚══██╔══╝██╔════╝████╗ ████║██╔══██╗                    ║
║  ╚█████╗ ██║███████╗   ██║   █████╗  ██╔████╔██║███████║                    ║
║   ╚═══██╗██║╚════██║   ██║   ██╔══╝  ██║╚██╔╝██║██╔══██║                    ║
║  ██████╔╝██║███████║   ██║   ███████╗██║ ╚═╝ ██║██║  ██║                    ║
║  ╚═════╝ ╚═╝╚══════╝   ╚═╝   ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝                    ║
║                                                                               ║
║              IMPORTACIÓN PERSISTENTE CON TMUX - KOHA UNA                     ║
║                           INICIO RÁPIDO                                       ║
║                                                                               ║
╚═══════════════════════════════════════════════════════════════════════════════╝

EOF

echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
echo -e "${C_BOLD}OPCIONES DE INICIO RÁPIDO${C_NC}"
echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
echo ""
echo "  1) Gestor Interactivo Completo (RECOMENDADO)"
echo "  2) Importar un archivo específico"
echo "  3) Importar TODOS los archivos pendientes"
echo "  4) Ver estado de sesiones activas"
echo "  5) Monitor en tiempo real (Dashboard)"
echo "  6) Conectar a sesión existente"
echo "  7) Ver ayuda completa"
echo "  8) Ver documentación"
echo "  9) Ejecutar tests del sistema"
echo "  0) Salir"
echo ""
echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
echo -ne "${C_YELLOW}Selecciona una opción [1-9, 0]: ${C_NC}"
read opcion

case "$opcion" in
    1)
        echo -e "\n${C_GREEN}Iniciando gestor interactivo...${C_NC}\n"
        sleep 1
        ./gestionar_importaciones.sh
        ;;
    2)
        echo -e "\n${C_CYAN}Archivos disponibles en importar_aqui/:${C_NC}\n"
        ls -lh importar_aqui/*.csv 2>/dev/null || echo "No hay archivos CSV"
        echo ""
        echo -ne "${C_YELLOW}Ingresa el nombre del archivo (o ruta completa): ${C_NC}"
        read archivo
        if [ -n "$archivo" ]; then
            ./importar_tmux.sh "$archivo"
        fi
        ;;
    3)
        echo -e "\n${C_GREEN}Iniciando importación masiva...${C_NC}\n"
        ./importar_tmux.sh --all
        ;;
    4)
        echo -e "\n${C_GREEN}Mostrando estado de sesiones...${C_NC}\n"
        ./importar_tmux.sh --status
        echo ""
        echo -e "${C_CYAN}Presiona ENTER para continuar...${C_NC}"
        read
        ;;
    5)
        echo -e "\n${C_GREEN}Iniciando monitor en tiempo real...${C_NC}\n"
        sleep 1
        ./monitor_tmux.sh
        ;;
    6)
        echo -e "\n${C_CYAN}Sesiones disponibles:${C_NC}\n"
        tmux list-sessions 2>/dev/null | grep "koha-import-" || echo "No hay sesiones activas"
        echo ""
        echo -ne "${C_YELLOW}Ingresa el nombre de la sesión: ${C_NC}"
        read sesion
        if [ -n "$sesion" ]; then
            echo -e "\n${C_GREEN}Conectando a: $sesion${C_NC}"
            echo -e "${C_CYAN}Para desconectar sin detener: Ctrl+B luego D${C_NC}\n"
            sleep 2
            tmux attach-session -t "$sesion"
        fi
        ;;
    7)
        clear
        echo -e "${C_BOLD}${C_CYAN}AYUDA COMPLETA DEL SISTEMA${C_NC}\n"
        echo -e "${C_BOLD}1. importar_tmux.sh --help${C_NC}"
        echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
        ./importar_tmux.sh --help
        echo ""
        echo -e "${C_BOLD}2. monitor_tmux.sh --help${C_NC}"
        echo -e "${C_CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${C_NC}"
        ./monitor_tmux.sh --help
        echo ""
        echo -e "${C_CYAN}Presiona ENTER para continuar...${C_NC}"
        read
        ;;
    8)
        clear
        echo -e "${C_BOLD}${C_CYAN}DOCUMENTACIÓN DISPONIBLE${C_NC}\n"
        echo "  1) Guía completa del sistema (GUIA_SISTEMA_TMUX.md)"
        echo "  2) Resumen ejecutivo (RESUMEN_SISTEMA.txt)"
        echo ""
        echo -ne "${C_YELLOW}¿Cuál quieres ver? [1-2]: ${C_NC}"
        read doc_opcion

        case "$doc_opcion" in
            1)
                less GUIA_SISTEMA_TMUX.md
                ;;
            2)
                cat RESUMEN_SISTEMA.txt
                echo ""
                echo -e "${C_CYAN}Presiona ENTER para continuar...${C_NC}"
                read
                ;;
            *)
                echo -e "${C_YELLOW}Opción inválida${C_NC}"
                ;;
        esac
        ;;
    9)
        echo -e "\n${C_GREEN}Ejecutando tests del sistema...${C_NC}\n"
        ./test_sistema_tmux.sh
        echo ""
        echo -e "${C_CYAN}Presiona ENTER para continuar...${C_NC}"
        read
        ;;
    0)
        echo -e "\n${C_GREEN}¡Hasta luego!${C_NC}\n"
        exit 0
        ;;
    *)
        echo -e "\n${C_YELLOW}Opción inválida${C_NC}\n"
        sleep 1
        exec "$0"
        ;;
esac

# Preguntar si quiere volver al menú
echo ""
echo -ne "${C_YELLOW}¿Volver al menú de inicio? [Y/n]: ${C_NC}"
read volver

if [[ ! "$volver" =~ ^[Nn]$ ]]; then
    exec "$0"
fi

echo -e "\n${C_GREEN}¡Hasta luego!${C_NC}\n"
