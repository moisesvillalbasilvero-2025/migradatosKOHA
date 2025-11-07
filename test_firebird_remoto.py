#!/usr/bin/env python3
"""
SCRIPT DE PRUEBA - CONEXIÓN FIREBIRD REMOTO
============================================
Prueba la conexión a un servidor Firebird remoto
y muestra información básica de la base de datos.

USO:
    ./test_firebird_remoto.py

Luego ingresa los datos cuando te los solicite.
"""

import sys

# Verificar que fdb está instalado
try:
    import fdb
    print(f"✓ Módulo fdb instalado (versión {fdb.__version__})\n")
except ImportError:
    print("✗ Error: Módulo 'fdb' no instalado")
    print("\nInstalar con uno de estos comandos:")
    print("  pip3 install fdb")
    print("  sudo apt install python3-fdb")
    sys.exit(1)


# ===========================================================================
# COLORES
# ===========================================================================

class C:
    G = '\033[92m'
    Y = '\033[93m'
    R = '\033[91m'
    B = '\033[94m'
    C = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'


# ===========================================================================
# FUNCIÓN PRINCIPAL
# ===========================================================================

def test_firebird_connection():
    """Prueba conexión a Firebird"""

    print(f"{C.BOLD}{C.C}{'═'*70}{C.END}")
    print(f"{C.BOLD}{C.C}PRUEBA DE CONEXIÓN A FIREBIRD REMOTO{C.END}")
    print(f"{C.BOLD}{C.C}{'═'*70}{C.END}\n")

    # Solicitar datos de conexión
    print(f"{C.BOLD}Ingresa los datos de conexión:{C.END}\n")

    # Ejemplos comunes
    print(f"{C.C}Ejemplos de valores comunes:{C.END}")
    print(f"  Host: 192.168.1.100, localhost, servidor.edu.py")
    print(f"  Puerto: 3050 (por defecto)")
    print(f"  Base de datos: /datos/biblio.fdb, C:\\Datos\\biblio.fdb")
    print(f"  Usuario: SYSDBA (por defecto)")
    print(f"  Password: masterkey (por defecto de Firebird)\n")

    # Leer datos
    host = input(f"{C.C}Host del servidor Firebird: {C.END}").strip() or "localhost"
    port = input(f"{C.C}Puerto (Enter para 3050): {C.END}").strip() or "3050"
    database = input(f"{C.C}Ruta de la base de datos: {C.END}").strip()
    user = input(f"{C.C}Usuario (Enter para SYSDBA): {C.END}").strip() or "SYSDBA"

    # Password (sin echo)
    import getpass
    password = getpass.getpass(f"{C.C}Password: {C.END}")

    charset = input(f"{C.C}Charset (Enter para UTF8): {C.END}").strip() or "UTF8"

    print()

    # Validar datos mínimos
    if not database:
        print(f"{C.R}✗ Error: Debes especificar la ruta de la base de datos{C.END}")
        sys.exit(1)

    # Intentar conectar
    print(f"{C.BOLD}{'─'*70}{C.END}")
    print(f"{C.BOLD}Intentando conectar...{C.END}\n")

    config = {
        'host': host,
        'port': int(port),
        'database': database,
        'user': user,
        'password': password,
        'charset': charset
    }

    print(f"  Host:         {host}:{port}")
    print(f"  Base de datos: {database}")
    print(f"  Usuario:      {user}")
    print(f"  Charset:      {charset}")
    print()

    try:
        # Conectar
        print(f"{C.C}→ Conectando...{C.END}")
        conn = fdb.connect(**config)

        print(f"{C.G}✓ CONEXIÓN EXITOSA{C.END}\n")

        cursor = conn.cursor()

        # Obtener información del servidor
        print(f"{C.BOLD}{'─'*70}{C.END}")
        print(f"{C.BOLD}INFORMACIÓN DEL SERVIDOR FIREBIRD{C.END}")
        print(f"{C.BOLD}{'─'*70}{C.END}\n")

        # Versión de Firebird
        try:
            cursor.execute("SELECT rdb$get_context('SYSTEM', 'ENGINE_VERSION') FROM RDB$DATABASE")
            version = cursor.fetchone()[0]
            print(f"  Versión Firebird:  {version}")
        except:
            print(f"  Versión Firebird:  No disponible")

        # Nombre de la base de datos
        try:
            cursor.execute("SELECT MON$DATABASE_NAME FROM MON$DATABASE")
            db_name = cursor.fetchone()[0]
            print(f"  Base de datos:     {db_name}")
        except:
            print(f"  Base de datos:     {database}")

        # Número de tablas
        cursor.execute("""
            SELECT COUNT(*)
            FROM RDB$RELATIONS
            WHERE RDB$SYSTEM_FLAG = 0
            AND RDB$VIEW_BLR IS NULL
        """)
        num_tablas = cursor.fetchone()[0]
        print(f"  Total de tablas:   {num_tablas}")

        # Listar tablas
        print(f"\n{C.BOLD}{'─'*70}{C.END}")
        print(f"{C.BOLD}TABLAS EN LA BASE DE DATOS{C.END}")
        print(f"{C.BOLD}{'─'*70}{C.END}\n")

        cursor.execute("""
            SELECT RDB$RELATION_NAME
            FROM RDB$RELATIONS
            WHERE RDB$SYSTEM_FLAG = 0
            AND RDB$VIEW_BLR IS NULL
            ORDER BY RDB$RELATION_NAME
        """)

        tablas = [row[0].strip() for row in cursor.fetchall()]

        if tablas:
            print(f"  Encontradas {len(tablas)} tablas:\n")

            for i, tabla in enumerate(tablas, 1):
                # Contar registros
                try:
                    cursor.execute(f'SELECT COUNT(*) FROM "{tabla}"')
                    count = cursor.fetchone()[0]
                    print(f"    {i:2}. {tabla:<35} {count:>10,} registros")
                except:
                    print(f"    {i:2}. {tabla:<35} {'(error contando)':>10}")

            # Identificar tablas probables para bibliografía
            print(f"\n{C.BOLD}Tablas que podrían contener datos bibliográficos:{C.END}")

            keywords = ['BIBLIO', 'LIBRO', 'BOOK', 'CATALO', 'MATERIAL', 'EJEMPLAR', 'ITEM']
            tablas_biblio = []

            for tabla in tablas:
                tabla_upper = tabla.upper()
                if any(kw in tabla_upper for kw in keywords):
                    tablas_biblio.append(tabla)
                    print(f"  → {tabla}")

            if not tablas_biblio:
                print(f"  {C.Y}(No se detectaron automáticamente){C.END}")
                print(f"  {C.Y}Revisa la lista completa arriba{C.END}")

        else:
            print(f"  {C.Y}No se encontraron tablas{C.END}")

        # Guardar configuración de ejemplo
        print(f"\n{C.BOLD}{'─'*70}{C.END}")
        print(f"{C.BOLD}CONFIGURACIÓN PARA firebird_directo_koha.py{C.END}")
        print(f"{C.BOLD}{'─'*70}{C.END}\n")

        print(f"{C.C}Copia esto en la sección FIREBIRD_SERVERS:{C.END}\n")

        # Generar código
        codigo_ejemplo = "TU_CODIGO"  # Usuario puede cambiar

        print(f"    '{codigo_ejemplo}': {{")
        print(f"        'nombre': 'Nombre de Tu Biblioteca',")
        print(f"        'host': '{host}',")
        print(f"        'port': {port},")
        print(f"        'database': '{database}',")
        print(f"        'user': '{user}',")
        print(f"        'password': '***CAMBIAR***',  # ← No guardar password en código")
        print(f"        'charset': '{charset}',")
        print(f"        'activo': True,")
        print(f"    }},")
        print()

        # Guardar en archivo
        output_file = f"config_firebird_{host.replace('.', '_')}.txt"

        with open(output_file, 'w') as f:
            f.write(f"Configuración de conexión Firebird\n")
            f.write(f"{'='*70}\n\n")
            f.write(f"Host: {host}:{port}\n")
            f.write(f"Base de datos: {database}\n")
            f.write(f"Usuario: {user}\n")
            f.write(f"Charset: {charset}\n\n")
            f.write(f"Total tablas: {num_tablas}\n\n")
            f.write(f"Tablas encontradas:\n")
            for tabla in tablas:
                f.write(f"  - {tabla}\n")

        print(f"{C.G}✓ Información guardada en: {output_file}{C.END}")

        # Cerrar conexión
        cursor.close()
        conn.close()

        # Mensaje final de éxito
        print(f"\n{C.BOLD}{C.G}{'═'*70}{C.END}")
        print(f"{C.BOLD}{C.G}✓✓✓ PRUEBA DE CONEXIÓN EXITOSA ✓✓✓{C.END}")
        print(f"{C.BOLD}{C.G}{'═'*70}{C.END}\n")

        print(f"{C.BOLD}Próximos pasos:{C.END}")
        print(f"  1. Identifica las tablas con datos bibliográficos")
        print(f"  2. Analiza su estructura con: ./firebird_structure_analyzer.py")
        print(f"  3. Configura firebird_directo_koha.py con estos datos")
        print(f"  4. Adapta el query SQL a tus nombres de tablas/columnas")
        print(f"  5. Ejecuta primera importación")
        print()

        return True

    except Exception as e:
        print(f"\n{C.R}{'═'*70}{C.END}")
        print(f"{C.R}✗✗✗ ERROR DE CONEXIÓN ✗✗✗{C.END}")
        print(f"{C.R}{'═'*70}{C.END}\n")

        print(f"{C.R}Error: {e}{C.END}\n")

        print(f"{C.BOLD}Posibles causas:{C.END}")
        print(f"  1. {C.Y}IP/hostname incorrecto{C.END}")
        print(f"     → Verifica que puedes hacer ping al servidor")
        print(f"       ping {host}")
        print()
        print(f"  2. {C.Y}Puerto bloqueado por firewall{C.END}")
        print(f"     → Verifica que puerto 3050 está abierto")
        print(f"       telnet {host} {port}")
        print()
        print(f"  3. {C.Y}Usuario/password incorrectos{C.END}")
        print(f"     → Verifica credenciales con administrador de Firebird")
        print()
        print(f"  4. {C.Y}Firebird no acepta conexiones remotas{C.END}")
        print(f"     → En el servidor Firebird, verificar firebird.conf")
        print(f"       RemoteBindAddress = 0.0.0.0")
        print()
        print(f"  5. {C.Y}Ruta de base de datos incorrecta{C.END}")
        print(f"     → Verifica que el archivo existe en el servidor")
        print(f"       (en el servidor) ls -la {database}")
        print()

        return False


# ===========================================================================
# MAIN
# ===========================================================================

if __name__ == '__main__':
    try:
        success = test_firebird_connection()
        sys.exit(0 if success else 1)
    except KeyboardInterrupt:
        print(f"\n\n{C.Y}Cancelado por usuario{C.END}\n")
        sys.exit(1)
    except Exception as e:
        print(f"\n{C.R}Error inesperado: {e}{C.END}\n")
        import traceback
        traceback.print_exc()
        sys.exit(1)
