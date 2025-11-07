#!/bin/bash
# CERRAR TÚNEL SSH A FIREBIRD
# ============================
# Cierra un túnel SSH activo
#
# USO:
#   ./cerrar_tunel.sh [PUERTO]
#
# Si no se especifica puerto, muestra todos los túneles activos

set -euo pipefail

PUERTO="${1:-}"

echo "════════════════════════════════════════════════════════════"
echo "CERRAR TÚNEL SSH A FIREBIRD"
echo "════════════════════════════════════════════════════════════"
echo ""

# Si no se especifica puerto, listar túneles activos
if [ -z "$PUERTO" ]; then
    echo "Túneles SSH activos:"
    echo ""

    # Buscar procesos ssh con -L (port forwarding)
    if pgrep -f "ssh.*-L.*3050" >/dev/null 2>&1; then
        ps aux | grep "ssh.*-L" | grep -v grep | awk '{print $2, $11, $12, $13, $14, $15}'
        echo ""

        # Listar puertos en escucha
        echo "Puertos locales en escucha:"
        lsof -iTCP -sTCP:LISTEN | grep -E ":(305[0-9])" || echo "  (ninguno en rango 3050-3059)"
        echo ""

        read -p "Ingresa el puerto a cerrar (Enter para cancelar): " PUERTO
        if [ -z "$PUERTO" ]; then
            echo "Cancelado"
            exit 0
        fi
    else
        echo "  No hay túneles SSH activos"
        exit 0
    fi
fi

# Verificar si hay proceso en ese puerto
if ! lsof -Pi :$PUERTO -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "✗ No hay túnel activo en puerto $PUERTO"
    exit 1
fi

# Obtener PID
PID=$(lsof -ti:$PUERTO)

echo "Túnel en puerto $PUERTO:"
ps -p $PID -o pid,user,cmd 2>/dev/null || echo "PID $PID"
echo ""

read -p "¿Cerrar este túnel? (s/n): " respuesta
if [ "$respuesta" != "s" ] && [ "$respuesta" != "S" ]; then
    echo "Cancelado"
    exit 0
fi

# Cerrar túnel
echo "Cerrando túnel (PID: $PID)..."
kill $PID 2>/dev/null || {
    echo "✗ Error cerrando túnel"
    echo "Intenta con: sudo kill $PID"
    exit 1
}

sleep 1

# Verificar que cerró
if ! lsof -Pi :$PUERTO -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "✓ Túnel cerrado exitosamente"

    # Limpiar archivo PID si existe
    rm -f /tmp/tunel_firebird_*.pid

else
    echo "⚠️  El túnel sigue activo"
    echo "Intenta con: sudo kill -9 $PID"
    exit 1
fi
