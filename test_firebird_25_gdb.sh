#!/bin/bash
# Prueba rápida de conexión Firebird 2.5.7 con archivo .gdb

echo "════════════════════════════════════════════════════════════"
echo "PRUEBA CONEXIÓN FIREBIRD 2.5.7 (archivos .gdb)"
echo "════════════════════════════════════════════════════════════"
echo ""
echo "El driver fdb 2.0.4 SOPORTA:"
echo "  ✓ Firebird 2.5.x"
echo "  ✓ Archivos .gdb (formato antiguo)"
echo "  ✓ Archivos .fdb (formato nuevo)"
echo "  ✓ Conexiones remotas TCP/IP"
echo ""
echo "════════════════════════════════════════════════════════════"
echo ""

# Ejecutar test
./test_firebird_remoto.py

