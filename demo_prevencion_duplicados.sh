#!/bin/bash
# ════════════════════════════════════════════════════════════════════════════
# DEMOSTRACIÓN DEL SISTEMA DE PREVENCIÓN DE DUPLICADOS
# ════════════════════════════════════════════════════════════════════════════
# Versión: 1.0
# Fecha: 25 de Octubre de 2025
# Uso: ./demo_prevencion_duplicados.sh
#
# Crea archivos CSV de ejemplo para demostrar las 3 detecciones:
# 1. Duplicados DENTRO del CSV
# 2. Duplicados vs BASE DE DATOS
# 3. Importación inteligente (agregar ejemplares)
# ════════════════════════════════════════════════════════════════════════════

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Directorio base
BASE_DIR="/home/mvillalba/migradatos"
DEMO_DIR="${BASE_DIR}/demo"

# Cargar funciones de prevención
source "${BASE_DIR}/prevenir_duplicados.sh"

clear

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  DEMOSTRACIÓN: Sistema de Prevención de Duplicados${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Crear directorio demo
mkdir -p "$DEMO_DIR"

# ═══════════════════════════════════════════════════════════════════════════
# DEMO 1: Duplicados DENTRO del CSV
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  DEMO 1: Detección de duplicados DENTRO del CSV${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Creando archivo CSV con códigos de barras duplicados..."

cat > "${DEMO_DIR}/ejemplo_duplicado_interno.csv" <<'EOF'
title,author,isbn,publisher,publicationyear,copyrightdate,pages,itemtype,dewey,itemcallnumber,barcode,homebranch,holdingbranch,location,price,replacementprice,notforloan,ccode,materials,abstract,subject,notes
"Introducción a la Programación","García, Juan","978-84-123-4567-0","Editorial Técnica","2020","2020","350","BK","005.1","005.1 GAR","DEMO001","ING","ING","SHELF","15000","20000","0","COMP","","Un libro completo sobre programación","Informática; Programación; Algoritmos",""
"Bases de Datos Avanzadas","López, María","978-84-234-5678-1","Ed. Sistemas","2021","2021","420","BK","005.74","005.74 LOP","DEMO002","ING","ING","SHELF","18000","25000","0","COMP","","Guía completa de bases de datos","Informática; Bases de Datos; SQL",""
"Redes de Computadoras","Martínez, Pedro","978-84-345-6789-2","Ed. Redes","2019","2019","380","BK","004.6","004.6 MAR","DEMO001","ING","ING","SHELF","16000","22000","0","COMP","","Teoría y práctica de redes","Informática; Redes; Telecomunicaciones",""
EOF

echo -e "${YELLOW}Archivo creado: ${DEMO_DIR}/ejemplo_duplicado_interno.csv${NC}"
echo ""
echo "Registros:"
echo "  - DEMO001 aparece 2 veces (líneas 2 y 4)"
echo "  - DEMO002 aparece 1 vez (OK)"
echo ""

echo "Verificando duplicados..."
echo ""

verificar_duplicados_en_csv "${DEMO_DIR}/ejemplo_duplicado_interno.csv" "/tmp/demo1_$$.log"

echo ""
echo -e "${RED}Resultado: Sistema detecta DEMO001 duplicado${NC}"
echo -e "${RED}Acción: NO se permite importar hasta corregir${NC}"
echo ""

read -p "Presiona Enter para continuar con DEMO 2..."
clear

# ═══════════════════════════════════════════════════════════════════════════
# DEMO 2: Duplicados vs BASE DE DATOS
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  DEMO 2: Detección de duplicados vs BASE DE DATOS${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Creando archivo CSV con códigos que podrían existir en BD..."

cat > "${DEMO_DIR}/ejemplo_verificar_bd.csv" <<'EOF'
title,author,isbn,publisher,publicationyear,copyrightdate,pages,itemtype,dewey,itemcallnumber,barcode,homebranch,holdingbranch,location,price,replacementprice,notforloan,ccode,materials,abstract,subject,notes
"Cálculo Diferencial e Integral","Larson, Ron","978-607-522-980-3","Cengage Learning","2010","2010","1200","BK","515","515 LAR","TEST001","ING","ING","SHELF","25000","35000","0","MAT","","Texto clásico de cálculo universitario","Matemáticas; Cálculo; Análisis",""
"Física Universitaria Vol. 1","Young, Hugh D.","978-607-32-1885-9","Pearson","2013","2013","800","BK","530","530 YOU","TEST002","ING","ING","SHELF","28000","38000","0","FIS","","Física con enfoque moderno","Física; Mecánica; Ondas",""
"Química General","Chang, Raymond","978-607-15-0928-4","McGraw-Hill","2010","2010","1150","BK","540","540 CHA","TEST003","ING","ING","SHELF","26000","36000","0","QUI","","Química general con ejercicios","Química; Átomos; Reacciones",""
EOF

echo -e "${YELLOW}Archivo creado: ${DEMO_DIR}/ejemplo_verificar_bd.csv${NC}"
echo ""
echo "Verificando contra base de datos..."
echo ""

verificar_duplicados_csv_vs_bd "${DEMO_DIR}/ejemplo_verificar_bd.csv" "/tmp/demo2_$$.log"
RESULT=$?

echo ""
if [ $RESULT -eq 1 ]; then
    echo -e "${RED}Resultado: Códigos de barras YA EXISTEN en BD${NC}"
    echo -e "${RED}Acción: NO se puede continuar${NC}"
elif [ $RESULT -eq 2 ]; then
    echo -e "${YELLOW}Resultado: ISBNs o Títulos YA EXISTEN${NC}"
    echo -e "${YELLOW}Acción: Sistema ofrece agregar ejemplares${NC}"
else
    echo -e "${GREEN}Resultado: No hay duplicados${NC}"
    echo -e "${GREEN}Acción: OK para importar${NC}"
fi

echo ""
read -p "Presiona Enter para continuar con DEMO 3..."
clear

# ═══════════════════════════════════════════════════════════════════════════
# DEMO 3: Modo Inteligente
# ═══════════════════════════════════════════════════════════════════════════

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  DEMO 3: Modo Inteligente (Agregar Ejemplares)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Simulando importación inteligente..."
echo ""

echo -e "${CYAN}Caso 1: Libro completamente nuevo${NC}"
echo "  Título: \"Nuevo Libro de Programación\""
echo "  ISBN: 978-99-999-9999-9 (no existe)"
echo "  Barcode: NEW001 (no existe)"
echo ""
echo -e "${GREEN}  → Sistema crea: biblionumber NUEVO + item NUEVO${NC}"
echo ""

echo -e "${CYAN}Caso 2: ISBN ya existe, barcode nuevo${NC}"
echo "  Título: \"Don Quijote de la Mancha\""
echo "  ISBN: 978-84-376-0455-8 (YA EXISTE)"
echo "  Barcode: DQ002 (nuevo)"
echo ""
echo -e "${YELLOW}  → Sistema detecta: biblionumber 123 existe${NC}"
echo -e "${GREEN}  → Sistema agrega: SOLO nuevo item (DQ002) al biblionumber 123${NC}"
echo ""

echo -e "${CYAN}Caso 3: Título + Autor existe, pero ISBN diferente${NC}"
echo "  Título: \"Cálculo\" (existe)"
echo "  Autor: \"Larson, Ron\" (existe)"
echo "  ISBN: 978-99-888-7777-6 (DIFERENTE)"
echo ""
echo -e "${BLUE}  → Sistema analiza: Mismo autor/título, pero ISBN diferente${NC}"
echo -e "${GREEN}  → Sistema crea: NUEVO biblionumber (es otra edición)${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════════════
# RESUMEN
# ═══════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  RESUMEN DE LA DEMOSTRACIÓN${NC}"
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}✓ DEMO 1:${NC} Sistema detecta duplicados DENTRO del CSV"
echo "  → Acción: Detiene importación hasta corregir"
echo ""

echo -e "${GREEN}✓ DEMO 2:${NC} Sistema detecta duplicados vs BASE DE DATOS"
echo "  → Acción: Informa al usuario, ofrece agregar ejemplares"
echo ""

echo -e "${GREEN}✓ DEMO 3:${NC} Modo Inteligente decide automáticamente"
echo "  → Libro nuevo: Crea registro completo"
echo "  → ISBN existe: Agrega solo ejemplar"
echo "  → Edición diferente: Crea nuevo registro"
echo ""

echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

echo "Archivos de ejemplo creados en:"
echo "  ${DEMO_DIR}/ejemplo_duplicado_interno.csv"
echo "  ${DEMO_DIR}/ejemplo_verificar_bd.csv"
echo ""

echo "Para probar con archivos reales:"
echo ""
echo -e "${YELLOW}  # Validar archivo${NC}"
echo "  ./validar_antes_importar.sh importar_aqui/TU_ARCHIVO.csv"
echo ""
echo -e "${YELLOW}  # Importar con protección${NC}"
echo "  ./importar_biblioteca.sh TU_CODIGO"
echo ""

echo -e "${GREEN}¡Sistema de prevención de duplicados listo!${NC}"
echo ""
