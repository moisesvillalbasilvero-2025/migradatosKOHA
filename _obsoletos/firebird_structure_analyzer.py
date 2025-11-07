#!/usr/bin/env python3
"""
Analizador de estructura de base de datos Firebird
====================================================
Conecta a la BD Firebird y muestra su estructura completa:
- Tablas
- Columnas
- Tipos de datos
- Relaciones
- Datos de ejemplo

Uso:
    python3 firebird_structure_analyzer.py --database /path/to/database.fdb
"""

import fdb
import sys
import argparse
from typing import List, Dict, Tuple


def connect_firebird(db_path: str, host: str = 'localhost', user: str = 'SYSDBA', password: str = 'masterkey') -> fdb.Connection:
    """Conecta a Firebird"""
    try:
        print(f"Conectando a: {db_path}")
        conn = fdb.connect(
            host=host,
            database=db_path,
            user=user,
            password=password,
            charset='UTF8'
        )
        print("✓ Conexión exitosa\n")
        return conn
    except Exception as e:
        print(f"✗ Error de conexión: {e}")
        sys.exit(1)


def get_tables(conn: fdb.Connection) -> List[str]:
    """Obtiene lista de tablas"""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT RDB$RELATION_NAME
        FROM RDB$RELATIONS
        WHERE RDB$SYSTEM_FLAG = 0
        AND RDB$VIEW_BLR IS NULL
        ORDER BY RDB$RELATION_NAME
    """)
    return [row[0].strip() for row in cursor.fetchall()]


def get_columns(conn: fdb.Connection, table_name: str) -> List[Dict]:
    """Obtiene columnas de una tabla"""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT
            rf.RDB$FIELD_NAME as field_name,
            f.RDB$FIELD_TYPE as field_type,
            f.RDB$FIELD_LENGTH as field_length,
            rf.RDB$NULL_FLAG as null_flag,
            f.RDB$FIELD_SUB_TYPE as field_subtype
        FROM RDB$RELATION_FIELDS rf
        JOIN RDB$FIELDS f ON rf.RDB$FIELD_SOURCE = f.RDB$FIELD_NAME
        WHERE rf.RDB$RELATION_NAME = ?
        ORDER BY rf.RDB$FIELD_POSITION
    """, [table_name])

    columns = []
    for row in cursor.fetchall():
        field_name = row[0].strip() if row[0] else ''
        field_type = row[1]
        field_length = row[2]
        null_flag = row[3]
        field_subtype = row[4]

        # Mapear tipos de Firebird
        type_mapping = {
            7: 'SMALLINT',
            8: 'INTEGER',
            10: 'FLOAT',
            12: 'DATE',
            13: 'TIME',
            14: 'CHAR',
            16: 'BIGINT',
            27: 'DOUBLE',
            35: 'TIMESTAMP',
            37: 'VARCHAR',
            261: 'BLOB'
        }

        field_type_name = type_mapping.get(field_type, f'UNKNOWN({field_type})')

        if field_type in [14, 37]:  # CHAR/VARCHAR
            field_type_name += f"({field_length})"

        if field_type == 261:  # BLOB
            if field_subtype == 1:
                field_type_name = 'BLOB TEXT'
            else:
                field_type_name = 'BLOB BINARY'

        columns.append({
            'name': field_name,
            'type': field_type_name,
            'nullable': 'NULL' if null_flag is None else 'NOT NULL'
        })

    return columns


def get_sample_data(conn: fdb.Connection, table_name: str, limit: int = 3) -> Tuple[List[str], List[tuple]]:
    """Obtiene datos de ejemplo"""
    cursor = conn.cursor()

    try:
        cursor.execute(f'SELECT FIRST {limit} * FROM "{table_name}"')
        columns = [desc[0].strip() for desc in cursor.description]
        rows = cursor.fetchall()
        return columns, rows
    except Exception as e:
        return [], []


def get_foreign_keys(conn: fdb.Connection, table_name: str) -> List[Dict]:
    """Obtiene foreign keys de una tabla"""
    cursor = conn.cursor()
    cursor.execute("""
        SELECT
            rc.RDB$CONSTRAINT_NAME as constraint_name,
            cse.RDB$FIELD_NAME as field_name,
            ref.RDB$RELATION_NAME as ref_table,
            refc.RDB$FIELD_NAME as ref_field
        FROM RDB$RELATION_CONSTRAINTS rc
        JOIN RDB$REF_CONSTRAINTS ref ON rc.RDB$CONSTRAINT_NAME = ref.RDB$CONSTRAINT_NAME
        JOIN RDB$INDICES idx ON rc.RDB$INDEX_NAME = idx.RDB$INDEX_NAME
        JOIN RDB$INDEX_SEGMENTS cse ON idx.RDB$INDEX_NAME = cse.RDB$INDEX_NAME
        JOIN RDB$RELATION_CONSTRAINTS rc2 ON ref.RDB$CONST_NAME_UQ = rc2.RDB$CONSTRAINT_NAME
        JOIN RDB$INDICES idx2 ON rc2.RDB$INDEX_NAME = idx2.RDB$INDEX_NAME
        JOIN RDB$INDEX_SEGMENTS refc ON idx2.RDB$INDEX_NAME = refc.RDB$INDEX_NAME
        WHERE rc.RDB$RELATION_NAME = ?
        AND rc.RDB$CONSTRAINT_TYPE = 'FOREIGN KEY'
    """, [table_name])

    fks = []
    for row in cursor.fetchall():
        fks.append({
            'constraint': row[0].strip() if row[0] else '',
            'field': row[1].strip() if row[1] else '',
            'ref_table': row[2].strip() if row[2] else '',
            'ref_field': row[3].strip() if row[3] else ''
        })

    return fks


def count_records(conn: fdb.Connection, table_name: str) -> int:
    """Cuenta registros en una tabla"""
    cursor = conn.cursor()
    try:
        cursor.execute(f'SELECT COUNT(*) FROM "{table_name}"')
        return cursor.fetchone()[0]
    except:
        return 0


def analyze_database(db_path: str, host: str = 'localhost', user: str = 'SYSDBA', password: str = 'masterkey', detailed: bool = False):
    """Analiza estructura completa de la BD"""

    conn = connect_firebird(db_path, host, user, password)

    print("="*80)
    print("ESTRUCTURA DE LA BASE DE DATOS FIREBIRD")
    print("="*80)
    print()

    # Obtener tablas
    tables = get_tables(conn)
    print(f"📊 Total de tablas: {len(tables)}\n")

    # Analizar cada tabla
    for table_name in tables:
        print("─"*80)
        print(f"📋 TABLA: {table_name}")
        print("─"*80)

        # Contar registros
        record_count = count_records(conn, table_name)
        print(f"Registros: {record_count:,}")
        print()

        # Columnas
        columns = get_columns(conn, table_name)
        print("Columnas:")
        for col in columns:
            print(f"  • {col['name']:<30} {col['type']:<20} {col['nullable']}")
        print()

        # Foreign Keys
        if detailed:
            fks = get_foreign_keys(conn, table_name)
            if fks:
                print("Relaciones (Foreign Keys):")
                for fk in fks:
                    print(f"  • {fk['field']} → {fk['ref_table']}.{fk['ref_field']}")
                print()

        # Datos de ejemplo
        if detailed and record_count > 0:
            print("Datos de ejemplo (primeras 3 filas):")
            col_names, sample_rows = get_sample_data(conn, table_name, 3)

            if sample_rows:
                # Mostrar nombres de columnas
                print("  " + " | ".join([f"{c[:15]:<15}" for c in col_names[:5]]))
                print("  " + "-"*70)

                # Mostrar datos
                for row in sample_rows:
                    values = []
                    for val in row[:5]:
                        if val is None:
                            val_str = "NULL"
                        elif isinstance(val, bytes):
                            val_str = val.decode('utf-8', errors='ignore')[:15]
                        else:
                            val_str = str(val)[:15]
                        values.append(f"{val_str:<15}")

                    print("  " + " | ".join(values))
            print()

        print()

    # Resumen general
    print("="*80)
    print("RESUMEN")
    print("="*80)

    for table_name in tables:
        count = count_records(conn, table_name)
        if count > 0:
            print(f"  {table_name:<30} {count:>10,} registros")

    print()
    print("="*80)

    conn.close()


def export_structure_to_sql(db_path: str, output_file: str):
    """Exporta estructura como SQL DDL"""

    conn = connect_firebird(db_path)
    tables = get_tables(conn)

    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("-- Estructura de base de datos Firebird\n")
        f.write(f"-- Exportado: {db_path}\n")
        f.write(f"-- Fecha: {__import__('datetime').datetime.now()}\n\n")

        for table_name in tables:
            columns = get_columns(conn, table_name)

            f.write(f"-- Tabla: {table_name}\n")
            f.write(f"CREATE TABLE {table_name} (\n")

            col_defs = []
            for col in columns:
                col_def = f"    {col['name']} {col['type']}"
                if col['nullable'] == 'NOT NULL':
                    col_def += " NOT NULL"
                col_defs.append(col_def)

            f.write(",\n".join(col_defs))
            f.write("\n);\n\n")

    conn.close()
    print(f"✓ Estructura exportada a: {output_file}")


def main():
    parser = argparse.ArgumentParser(
        description='Analizador de estructura de base de datos Firebird',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument(
        '--database',
        required=True,
        help='Ruta al archivo .fdb de Firebird'
    )

    parser.add_argument(
        '--host',
        default='localhost',
        help='Host del servidor Firebird (default: localhost)'
    )

    parser.add_argument(
        '--user',
        default='SYSDBA',
        help='Usuario de Firebird (default: SYSDBA)'
    )

    parser.add_argument(
        '--password',
        default='masterkey',
        help='Password de Firebird'
    )

    parser.add_argument(
        '--detailed',
        action='store_true',
        help='Mostrar análisis detallado con datos de ejemplo'
    )

    parser.add_argument(
        '--export-ddl',
        help='Exportar estructura DDL a archivo SQL'
    )

    args = parser.parse_args()

    if args.export_ddl:
        export_structure_to_sql(args.database, args.export_ddl)
    else:
        analyze_database(
            args.database,
            args.host,
            args.user,
            args.password,
            args.detailed
        )


if __name__ == '__main__':
    main()
