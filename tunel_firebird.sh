#!/bin/bash
# TÚNEL SSH A FIREBIRD REMOTO
# ============================
# Crea un túnel SSH para acceder a Firebird remoto de forma segura
#
# USO:
#   ./tunel_firebird.sh CODIGO_SERVIDOR
#
# EJEMPLO:
#   ./tunel_firebird.sh FACAGR

set -euo pipefail

SERVIDOR_CODIGO="${1:-}"

if [ -z "$SERVIDOR_CODIGO" ]; then
    echo "════════════════════════════════════════════════════════════"
    echo "TÚNEL SSH A FIREBIRD - Uso"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Uso: ./tunel_firebird.sh CODIGO_SERVIDOR"
    echo ""
    echo "Ejemplo:"
    echo "  ./tunel_firebird.sh FACAGR"
    echo ""
    echo "Servidores disponibles:"
    echo "  FACAGR - Facultad de Ciencias Agrarias"
    echo "  FACMED - Facultad de Medicina"
    echo ""
    exit 1
fi

# ============================================================================
# CONFIGURACIÓN DE SERVIDORES
# ============================================================================
# Agregar aquí tus servidores Firebird

case "$SERVIDOR_CODIGO" in
    FACAGR)
        SSH_HOST="192.168.1.100"
        SSH_USER="usuario"
        SSH_PORT="22"
        FIREBIRD_PORT="3050"
        LOCAL_PORT="3050"
        DESCRIPCION="Facultad de Ciencias Agrarias"
        ;;

    FACMED)
        SSH_HOST="192.168.1.101"
        SSH_USER="admin"
        SSH_PORT="22"
        FIREBIRD_PORT="3050"
        LOCAL_PORT="3051"  # Puerto local diferente
        DESCRIPCION="Facultad de Medicina"
        ;;

    # AGREGAR MÁS SERVIDORES AQUÍ
    # EJEMPLO)
    #     SSH_HOST="192.168.1.102"
    #     SSH_USER="root"
    #     SSH_PORT="22"
    #     FIREBIRD_PORT="3050"
    #     LOCAL_PORT="3052"
    #     DESCRIPCION="Descripción del servidor"
    #     ;;

    *)
        echo "✗ Servidor desconocido: $SERVIDOR_CODIGO"
        echo ""
        echo "Servidores configurados:"
        echo "  FACAGR, FACMED"
        echo ""
        echo "Para agregar más servidores, editar: $0"
        exit 1
        ;;
esac

# ============================================================================
# CREAR TÚNEL SSH
# ============================================================================

echo "════════════════════════════════════════════════════════════"
echo "TÚNEL SSH A FIREBIRD"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "Servidor:      $DESCRIPCION ($SERVIDOR_CODIGO)"
echo "SSH:           $SSH_USER@$SSH_HOST:$SSH_PORT"
echo "Firebird:      localhost:$LOCAL_PORT → remoto:$FIREBIRD_PORT"
echo ""

# Verificar si ya hay túnel activo en ese puerto
if lsof -Pi :$LOCAL_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo "⚠️  Ya hay un túnel activo en puerto $LOCAL_PORT"
    echo ""

    # Mostrar proceso
    PID=$(lsof -ti:$LOCAL_PORT)
    echo "Proceso: PID $PID"
    ps -p $PID -o pid,cmd 2>/dev/null | tail -n +2 || echo "PID $PID"
    echo ""

    read -p "¿Cerrar y recrear túnel? (s/n): " respuesta
    if [ "$respuesta" = "s" ] || [ "$respuesta" = "S" ]; then
        echo "Cerrando túnel anterior..."
        kill $PID 2>/dev/null || true
        sleep 2
    else
        echo "Usando túnel existente"
        echo ""
        echo "Conecta a Firebird en: localhost:$LOCAL_PORT"
        exit 0
    fi
fi

# Verificar conectividad SSH
echo "Verificando conectividad SSH..."
if ! ssh -p $SSH_PORT -o ConnectTimeout=5 -o BatchMode=yes \
     $SSH_USER@$SSH_HOST exit 2>/dev/null; then
    echo "✗ No se puede conectar por SSH"
    echo ""
    echo "Posibles causas:"
    echo "  1. Host/puerto incorrectos"
    echo "  2. Clave SSH no configurada"
    echo "  3. Firewall bloqueando puerto SSH"
    echo ""
    echo "Configurar autenticación sin password:"
    echo "  ssh-copy-id -p $SSH_PORT $SSH_USER@$SSH_HOST"
    echo ""
    exit 1
fi

echo "✓ Conectividad SSH OK"
echo ""

# Crear túnel en background
echo "Creando túnel SSH..."

# Opciones:
#   -f: ejecutar en background
#   -N: no ejecutar comando remoto (solo túnel)
#   -L: forward de puerto local
#   -o ExitOnForwardFailure=yes: salir si no puede crear túnel

ssh -f -N \
    -L ${LOCAL_PORT}:localhost:${FIREBIRD_PORT} \
    -p ${SSH_PORT} \
    -o ExitOnForwardFailure=yes \
    ${SSH_USER}@${SSH_HOST}

# Verificar que túnel está activo
sleep 2

if lsof -Pi :$LOCAL_PORT -sTCP:LISTEN -t >/dev/null 2>&1; then
    PID=$(lsof -ti:$LOCAL_PORT)

    echo "✓ Túnel SSH creado exitosamente (PID: $PID)"
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "TÚNEL ACTIVO"
    echo "════════════════════════════════════════════════════════════"
    echo ""
    echo "Conecta a Firebird en:"
    echo "  Host:   localhost"
    echo "  Puerto: $LOCAL_PORT"
    echo ""
    echo "Usar con firebird_directo_koha.py:"
    echo "  En FIREBIRD_SERVERS, configurar:"
    echo "    'host': 'localhost',"
    echo "    'port': $LOCAL_PORT,"
    echo ""
    echo "Para cerrar el túnel:"
    echo "  kill $PID"
    echo "  # O usar: ./cerrar_tunel.sh $LOCAL_PORT"
    echo ""

    # Guardar PID para referencia
    echo "$PID" > /tmp/tunel_firebird_${SERVIDOR_CODIGO}.pid

else
    echo "✗ Error creando túnel SSH"
    echo ""
    echo "Revisar logs de SSH con:"
    echo "  ssh -v -N -L ${LOCAL_PORT}:localhost:${FIREBIRD_PORT} -p ${SSH_PORT} ${SSH_USER}@${SSH_HOST}"
    exit 1
fi
