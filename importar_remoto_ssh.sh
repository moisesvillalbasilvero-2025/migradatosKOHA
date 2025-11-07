#!/bin/bash
# IMPORTACIÓN REMOTA VÍA SSH
# ==========================
# Ejecuta la importación directamente en el servidor remoto Firebird
# y descarga los archivos generados para importarlos a Koha local
#
# USO:
#   ./importar_remoto_ssh.sh CODIGO_SERVIDOR
#
# EJEMPLO:
#   ./importar_remoto_ssh.sh FACAGR

set -euo pipefail

SERVIDOR_CODIGO="${1:-}"

if [ -z "$SERVIDOR_CODIGO" ]; then
    echo "════════════════════════════════════════════════════════════"
    echo "IMPORTACIÓN REMOTA VÍA SSH - Uso"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Uso: ./importar_remoto_ssh.sh CODIGO_SERVIDOR"
    echo ""
    echo "Este script:"
    echo "  1. Se conecta por SSH al servidor remoto"
    echo "  2. Exporta datos de Firebird a CSV en el servidor"
    echo "  3. Descarga el CSV generado"
    echo "  4. Importa a Koha local"
    echo ""
    echo "Ejemplo:"
    echo "  ./importar_remoto_ssh.sh FACAGR"
    echo ""
    exit 1
fi

# ============================================================================
# CONFIGURACIÓN DE SERVIDORES
# ============================================================================

case "$SERVIDOR_CODIGO" in
    FACAGR)
        SSH_HOST="192.168.1.100"
        SSH_USER="usuario"
        SSH_PORT="22"
        FIREBIRD_DB="/datos/biblioteca.gdb"
        FIREBIRD_USER="SYSDBA"
        FIREBIRD_PASS="masterkey"
        DESCRIPCION="Facultad de Ciencias Agrarias"
        ;;

    FACMED)
        SSH_HOST="192.168.1.101"
        SSH_USER="admin"
        SSH_PORT="22"
        FIREBIRD_DB="/opt/firebird/medicina.gdb"
        FIREBIRD_USER="SYSDBA"
        FIREBIRD_PASS="password"
        DESCRIPCION="Facultad de Medicina"
        ;;

    *)
        echo "✗ Servidor desconocido: $SERVIDOR_CODIGO"
        echo ""
        echo "Servidores configurados: FACAGR, FACMED"
        echo "Para agregar más, editar: $0"
        exit 1
        ;;
esac

# ============================================================================
# DIRECTORIOS
# ============================================================================

REMOTE_TEMP_DIR="/tmp/koha_export_$$"
LOCAL_TEMP_DIR="./temp_remoto_${SERVIDOR_CODIGO}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CSV_FILENAME="${SERVIDOR_CODIGO}_${TIMESTAMP}.csv"

echo "════════════════════════════════════════════════════════════"
echo "IMPORTACIÓN REMOTA VÍA SSH"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Servidor:      $DESCRIPCION ($SERVIDOR_CODIGO)"
echo "SSH:           $SSH_USER@$SSH_HOST:$SSH_PORT"
echo "Firebird:      $FIREBIRD_DB"
echo "CSV destino:   $CSV_FILENAME"
echo ""

# ============================================================================
# PASO 1: VERIFICAR CONECTIVIDAD SSH
# ============================================================================

echo "────────────────────────────────────────────────────────────"
echo "PASO 1/5: Verificar conectividad SSH"
echo "────────────────────────────────────────────────────────────"
echo ""

if ! ssh -p $SSH_PORT -o ConnectTimeout=5 -o BatchMode=yes \
     $SSH_USER@$SSH_HOST exit 2>/dev/null; then
    echo "✗ No se puede conectar por SSH"
    echo ""
    echo "Configurar autenticación sin password:"
    echo "  ssh-copy-id -p $SSH_PORT $SSH_USER@$SSH_HOST"
    echo ""
    exit 1
fi

echo "✓ Conectividad SSH OK"
echo ""

# ============================================================================
# PASO 2: CREAR SCRIPT DE EXPORTACIÓN EN SERVIDOR REMOTO
# ============================================================================

echo "────────────────────────────────────────────────────────────"
echo "PASO 2/5: Crear script de exportación en servidor remoto"
echo "────────────────────────────────────────────────────────────"
echo ""

# Crear script Python de exportación
EXPORT_SCRIPT=$(cat <<'PYTHON_EOF'
#!/usr/bin/env python3
"""
Script de exportación Firebird a CSV
Ejecutado en servidor remoto vía SSH
"""
import sys
import csv

try:
    import fdb
except ImportError:
    print("ERROR: Módulo fdb no instalado en servidor remoto")
    print("Instalar con: pip3 install fdb")
    sys.exit(1)

# Configuración desde variables de entorno
import os
DB_PATH = os.environ.get('FIREBIRD_DB', '/datos/biblioteca.gdb')
DB_USER = os.environ.get('FIREBIRD_USER', 'SYSDBA')
DB_PASS = os.environ.get('FIREBIRD_PASS', 'masterkey')
OUTPUT_CSV = os.environ.get('OUTPUT_CSV', 'export.csv')

print(f"Conectando a: {DB_PATH}")

try:
    conn = fdb.connect(
        database=DB_PATH,
        user=DB_USER,
        password=DB_PASS,
        charset='WIN1252'
    )

    cursor = conn.cursor()

    # QUERY SQL - ADAPTAR A TU ESTRUCTURA
    # Este es un ejemplo genérico
    query = """
        SELECT FIRST 1000
            b.ID as analisis,
            b.TITULO as titulo,
            b.AUTOR as autor,
            b.EDITORIAL as editorial,
            b.ANO as ano,
            b.ISBN as isbn,
            e.CODIGO as nroacceso,
            e.FECHA_ALTA as fecha_alta
        FROM BIBLIOGRAFICOS b
        LEFT JOIN EJEMPLARES e ON e.ID_BIBLIO = b.ID
        WHERE b.ACTIVO = 1
        ORDER BY b.ID
    """

    print("Ejecutando consulta...")
    cursor.execute(query)

    # Escribir CSV
    print(f"Escribiendo: {OUTPUT_CSV}")

    with open(OUTPUT_CSV, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f, delimiter=';')

        # Header
        writer.writerow(['analisis', 'titulo', 'autor', 'editorial',
                        'ano', 'isbn', 'nroacceso', 'fecha_alta'])

        # Datos
        count = 0
        for row in cursor:
            writer.writerow(row)
            count += 1

            if count % 100 == 0:
                print(f"  {count} registros procesados...", end='\r')

        print(f"\n✓ {count} registros exportados")

    cursor.close()
    conn.close()

    print(f"✓ Archivo generado: {OUTPUT_CSV}")

except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
PYTHON_EOF
)

# Enviar script al servidor remoto
echo "Enviando script de exportación..."

ssh -p $SSH_PORT $SSH_USER@$SSH_HOST "mkdir -p $REMOTE_TEMP_DIR"

echo "$EXPORT_SCRIPT" | ssh -p $SSH_PORT $SSH_USER@$SSH_HOST \
    "cat > $REMOTE_TEMP_DIR/export_firebird.py && chmod +x $REMOTE_TEMP_DIR/export_firebird.py"

echo "✓ Script enviado"
echo ""

# ============================================================================
# PASO 3: EJECUTAR EXPORTACIÓN EN SERVIDOR REMOTO
# ============================================================================

echo "────────────────────────────────────────────────────────────"
echo "PASO 3/5: Ejecutar exportación en servidor remoto"
echo "────────────────────────────────────────────────────────────"
echo ""

ssh -p $SSH_PORT $SSH_USER@$SSH_HOST \
    "cd $REMOTE_TEMP_DIR && \
     FIREBIRD_DB='$FIREBIRD_DB' \
     FIREBIRD_USER='$FIREBIRD_USER' \
     FIREBIRD_PASS='$FIREBIRD_PASS' \
     OUTPUT_CSV='$CSV_FILENAME' \
     python3 export_firebird.py"

echo ""
echo "✓ Exportación completada en servidor remoto"
echo ""

# ============================================================================
# PASO 4: DESCARGAR CSV
# ============================================================================

echo "────────────────────────────────────────────────────────────"
echo "PASO 4/5: Descargar CSV desde servidor remoto"
echo "────────────────────────────────────────────────────────────"
echo ""

mkdir -p "$LOCAL_TEMP_DIR"

echo "Descargando $CSV_FILENAME..."

scp -P $SSH_PORT \
    $SSH_USER@$SSH_HOST:$REMOTE_TEMP_DIR/$CSV_FILENAME \
    $LOCAL_TEMP_DIR/

echo "✓ CSV descargado a: $LOCAL_TEMP_DIR/$CSV_FILENAME"
echo ""

# Limpiar archivos remotos
echo "Limpiando archivos temporales en servidor remoto..."
ssh -p $SSH_PORT $SSH_USER@$SSH_HOST "rm -rf $REMOTE_TEMP_DIR"

echo "✓ Limpieza completada"
echo ""

# ============================================================================
# PASO 5: IMPORTAR A KOHA LOCAL
# ============================================================================

echo "────────────────────────────────────────────────────────────"
echo "PASO 5/5: Importar a Koha local"
echo "────────────────────────────────────────────────────────────"
echo ""

CSV_PATH="$LOCAL_TEMP_DIR/$CSV_FILENAME"

if [ ! -f "$CSV_PATH" ]; then
    echo "✗ Error: CSV no encontrado: $CSV_PATH"
    exit 1
fi

# Contar registros
NUM_REGISTROS=$(tail -n +2 "$CSV_PATH" | wc -l)
echo "CSV contiene: $NUM_REGISTROS registros"
echo ""

# Verificar si existe importar_optimizado.sh
if [ -x "./importar_optimizado.sh" ]; then
    echo "Usando importar_optimizado.sh..."
    ./importar_optimizado.sh "$CSV_PATH" --codigo "$SERVIDOR_CODIGO"

elif [ -x "./agente_importador_v3.py" ]; then
    echo "Usando agente_importador_v3.py..."
    ./agente_importador_v3.py \
        --csv "$CSV_PATH" \
        --biblioteca "$SERVIDOR_CODIGO"

else
    echo "⚠️  Scripts de importación no encontrados"
    echo ""
    echo "CSV disponible en: $CSV_PATH"
    echo "Importar manualmente con:"
    echo "  ./importar_optimizado.sh $CSV_PATH --codigo $SERVIDOR_CODIGO"
    echo ""
    exit 0
fi

echo ""
echo "════════════════════════════════════════════════════════════"
echo "✓ IMPORTACIÓN REMOTA COMPLETADA"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Servidor:        $DESCRIPCION"
echo "Registros:       $NUM_REGISTROS"
echo "CSV local:       $CSV_PATH"
echo ""
echo "Para limpiar archivos temporales:"
echo "  rm -rf $LOCAL_TEMP_DIR"
echo ""
