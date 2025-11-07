═══════════════════════════════════════════════════════════════
  PAQUETE DE EXPORTACIÓN LOCAL - BIBLIOTECAS UNA
═══════════════════════════════════════════════════════════════

📦 CONTENIDO DEL PAQUETE

  exportar_mis_datos.py      - Script de exportación
  verificar_exportacion.py   - Validador de datos
  README.txt                 - Este archivo

═══════════════════════════════════════════════════════════════
🎯 ¿QUÉ HACE ESTE PAQUETE?

Permite exportar los datos bibliográficos de su biblioteca
desde SU PROPIO servidor Firebird, sin necesidad de dar
acceso remoto.

═══════════════════════════════════════════════════════════════
📋 REQUISITOS

1. Python 3.8 o superior
   Verificar: python3 --version

2. Librería fdb
   Instalar: pip3 install fdb

3. Acceso a su base de datos Firebird (local)

═══════════════════════════════════════════════════════════════
🚀 PASOS RÁPIDOS

PASO 1: Instalar dependencia
  pip3 install fdb

PASO 2: Primera ejecución (crea config)
  python3 exportar_mis_datos.py

PASO 3: Editar config_biblioteca.json
  - Abrir con editor de texto
  - Completar código de biblioteca
  - Verificar ruta de base de datos
  - Ajustar nombres de tablas/campos

PASO 4: Ejecutar exportación
  python3 exportar_mis_datos.py

PASO 5: Verificar datos
  python3 verificar_exportacion.py

PASO 6: Enviar archivo CSV
  Email: soporte.biblioteca@una.py
  Adjuntar: datos_FACXX.csv

═══════════════════════════════════════════════════════════════
📧 SOPORTE

Email: soporte.biblioteca@una.py
Tel: XXX-XXXX

═══════════════════════════════════════════════════════════════

Versión: 1.0
Fecha: 2025-01-15
Sistema: Migración a Koha UNA
