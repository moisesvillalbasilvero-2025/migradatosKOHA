#!/bin/bash
################################################################################
# EJEMPLOS DE USO DE LA API REST DEL DASHBOARD
################################################################################
# Universidad Nacional de Asunción
# Ejemplos prácticos para entender cómo usar la API REST
#
# REQUISITOS:
#   - Dashboard debe estar corriendo: ./dashboard.py
#   - curl instalado (viene por defecto en Linux)
#
# USO:
#   ./ejemplos_api.sh
#
################################################################################

# Colores
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

API_BASE="http://localhost:5000"

echo ""
echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║                                                                    ║${NC}"
echo -e "${BOLD}${CYAN}║           EJEMPLOS DE USO DE LA API REST - DASHBOARD              ║${NC}"
echo -e "${BOLD}${CYAN}║                                                                    ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Verificar que dashboard esté corriendo
if ! curl -s "$API_BASE/api/estado" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ El dashboard no está corriendo${NC}"
    echo ""
    echo "Iniciar primero con:"
    echo "  ./dashboard.py"
    echo ""
    echo "Luego ejecutar este script en otra terminal"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Dashboard detectado en $API_BASE${NC}"
echo ""

# ============================================================================
# EJEMPLO 1: Obtener estadísticas
# ============================================================================

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}EJEMPLO 1: Obtener Estadísticas de Bibliotecas${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Endpoint: GET /api/stats"
echo ""
echo -e "${YELLOW}Comando:${NC}"
echo "  curl http://localhost:5000/api/stats"
echo ""
echo -e "${YELLOW}Respuesta (formateada):${NC}"
curl -s "$API_BASE/api/stats" | python3 -m json.tool | head -30
echo "  ..."
echo ""
read -p "Presiona Enter para continuar..."

# ============================================================================
# EJEMPLO 2: Obtener solo totales
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}EJEMPLO 2: Extraer Solo los Totales${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Usando 'jq' para filtrar JSON (más potente que json.tool)"
echo ""
echo -e "${YELLOW}Comando:${NC}"
echo "  curl -s http://localhost:5000/api/stats | jq '.totales'"
echo ""
echo -e "${YELLOW}Respuesta:${NC}"

if command -v jq &> /dev/null; then
    curl -s "$API_BASE/api/stats" | jq '.totales'
else
    echo "(jq no instalado, mostrando con python)"
    curl -s "$API_BASE/api/stats" | python3 -c "import sys, json; data=json.load(sys.stdin); print(json.dumps(data['totales'], indent=2))"
fi

echo ""
read -p "Presiona Enter para continuar..."

# ============================================================================
# EJEMPLO 3: Top 5 bibliotecas
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}EJEMPLO 3: Top 5 Bibliotecas con Más Items${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Comando:${NC}"
echo "  curl -s http://localhost:5000/api/stats | jq '.bibliotecas[:5]'"
echo ""
echo -e "${YELLOW}Respuesta:${NC}"

if command -v jq &> /dev/null; then
    curl -s "$API_BASE/api/stats" | jq '.bibliotecas[:5]'
else
    curl -s "$API_BASE/api/stats" | python3 -c "import sys, json; data=json.load(sys.stdin); print(json.dumps(data['bibliotecas'][:5], indent=2))"
fi

echo ""
read -p "Presiona Enter para continuar..."

# ============================================================================
# EJEMPLO 4: Estado del sistema
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}EJEMPLO 4: Estado del Sistema${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Endpoint: GET /api/estado"
echo ""
echo -e "${YELLOW}Comando:${NC}"
echo "  curl http://localhost:5000/api/estado"
echo ""
echo -e "${YELLOW}Respuesta:${NC}"
curl -s "$API_BASE/api/estado" | python3 -m json.tool
echo ""
read -p "Presiona Enter para continuar..."

# ============================================================================
# EJEMPLO 5: Logs recientes
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}EJEMPLO 5: Últimos Logs${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Endpoint: GET /api/logs"
echo ""
echo -e "${YELLOW}Comando:${NC}"
echo "  curl http://localhost:5000/api/logs"
echo ""
echo -e "${YELLOW}Respuesta (primeros 3):${NC}"

if command -v jq &> /dev/null; then
    curl -s "$API_BASE/api/logs" | jq '.logs[:3]'
else
    curl -s "$API_BASE/api/logs" | python3 -c "import sys, json; data=json.load(sys.stdin); print(json.dumps(data['logs'][:3], indent=2))"
fi

echo ""
read -p "Presiona Enter para continuar..."

# ============================================================================
# EJEMPLO 6: Importaciones recientes
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}EJEMPLO 6: Últimas Importaciones${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Endpoint: GET /api/importaciones"
echo ""
echo -e "${YELLOW}Comando:${NC}"
echo "  curl http://localhost:5000/api/importaciones"
echo ""
echo -e "${YELLOW}Respuesta:${NC}"
curl -s "$API_BASE/api/importaciones" | python3 -m json.tool
echo ""
read -p "Presiona Enter para continuar..."

# ============================================================================
# EJEMPLO 7: Uso desde Python
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}EJEMPLO 7: Usar la API desde Python${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}Script Python (ejemplo_api.py):${NC}"
cat << 'PYTHON'
import requests

# Obtener estadísticas
response = requests.get('http://localhost:5000/api/stats')
data = response.json()

# Mostrar totales
print(f"Total Biblios: {data['totales']['biblios']:,}")
print(f"Total Items: {data['totales']['items']:,}")
print(f"Total Bibliotecas: {data['totales']['bibliotecas']}")

# Top 3 bibliotecas
print("\nTop 3 Bibliotecas:")
for i, bib in enumerate(data['bibliotecas'][:3], 1):
    print(f"  {i}. {bib['codigo']:6} - {bib['ejemplares']:,} items")
PYTHON

echo ""
echo -e "${YELLOW}Ejecutar:${NC}"

python3 << 'PYTHON_EXEC'
import requests

try:
    response = requests.get('http://localhost:5000/api/stats')
    data = response.json()

    print(f"Total Biblios: {data['totales']['biblios']:,}")
    print(f"Total Items: {data['totales']['items']:,}")
    print(f"Total Bibliotecas: {data['totales']['bibliotecas']}")

    print("\nTop 3 Bibliotecas:")
    for i, bib in enumerate(data['bibliotecas'][:3], 1):
        print(f"  {i}. {bib['codigo']:6} - {bib['ejemplares']:,} items")
except Exception as e:
    print(f"Error: {e}")
PYTHON_EXEC

echo ""
read -p "Presiona Enter para continuar..."

# ============================================================================
# EJEMPLO 8: Monitoreo automático
# ============================================================================

echo ""
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}EJEMPLO 8: Monitoreo Continuo (cada 5 segundos)${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Script que consulta la API cada 5 segundos"
echo ""
echo -e "${YELLOW}Presiona Ctrl+C para detener...${NC}"
echo ""

contador=0
while true; do
    ((contador++))

    # Obtener datos
    stats=$(curl -s "$API_BASE/api/stats")
    estado=$(curl -s "$API_BASE/api/estado")

    # Extraer valores
    total_items=$(echo "$stats" | python3 -c "import sys, json; print(json.load(sys.stdin)['totales']['items'])")
    hora=$(echo "$estado" | python3 -c "import sys, json; print(json.load(sys.stdin)['hora_servidor'])")
    espacio=$(echo "$estado" | python3 -c "import sys, json; print(json.load(sys.stdin)['espacio_libre'])")

    # Mostrar
    clear
    echo -e "${BOLD}MONITOREO EN TIEMPO REAL (#$contador)${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Hora:          $hora"
    echo "Total Items:   $total_items"
    echo "Espacio Libre: $espacio"
    echo ""
    echo "Próxima actualización en 5 segundos..."
    echo "(Ctrl+C para detener)"

    sleep 5
done

echo ""
echo -e "${GREEN}✓ Ejemplos completados${NC}"
echo ""
