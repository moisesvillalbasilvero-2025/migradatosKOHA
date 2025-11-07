#!/usr/bin/env python3
"""
firebird_exporter.py - Exportador de Firebird a CSV para Koha
===============================================================

Conecta directamente a servidores Firebird y exporta datos bibliográficos
a formato CSV compatible con opac_exportar.py

Características:
- Conexión remota a Firebird 2.7.5
- Exportación directa sin archivos intermedios
- Mapeo configurable por biblioteca
- Validación de datos
- Logging detallado

Uso:
    python3 firebird_exporter.py --biblioteca FACAGR --output FACAGR.csv

Autor: Sistema UNA
Fecha: 2025-01-15
"""

import fdb
import csv
import sys
import os
import logging
import argparse
from datetime import datetime
from typing import Dict, List, Optional
from pathlib import Path


# ===========================================================================
# CONFIGURACIÓN DE BIBLIOTECAS Y SERVIDORES FIREBIRD
# ===========================================================================

FIREBIRD_SERVERS = {
    'FACAGR': {
        'nombre': 'Facultad de Ciencias Agrarias',
        'host': '192.168.1.10',           # ← CAMBIAR por IP real
        'port': 3050,
        'database': '/datos/biblio.fdb',  # ← CAMBIAR por ruta real
        'user': 'SYSDBA',
        'password': 'masterkey',          # ← CAMBIAR password real
        'charset': 'UTF8'
    },
    'FACEN': {
        'nombre': 'Facultad de Ciencias Exactas y Naturales',
        'host': '192.168.1.11',
        'port': 3050,
        'database': '/datos/biblio.fdb',
        'user': 'SYSDBA',
        'password': 'masterkey',
        'charset': 'UTF8'
    },
    'FACMED': {
        'nombre': 'Facultad de Ciencias Médicas',
        'host': '192.168.1.12',
        'port': 3050,
        'database': '/datos/biblio.fdb',
        'user': 'SYSDBA',
        'password': 'masterkey',
        'charset': 'UTF8'
    },
    # Agregar más bibliotecas...
}


# ===========================================================================
# SQL QUERIES
# ===========================================================================
# IMPORTANTE: Adaptar estos queries a la estructura REAL de tu Firebird

def get_export_query() -> str:
    """
    Query SQL para exportar datos bibliográficos.

    DEBE ADAPTARSE a los nombres reales de:
    - Tablas
    - Columnas
    - Relaciones

    en tu base de datos Firebird.
    """
    return """
        SELECT
            -- Identificadores
            b.ID_REGISTRO as analisis,
            b.ID_REGISTRO as identificador,

            -- Datos bibliográficos principales
            b.TITULO as titulo,
            b.SUBTITULO as sub_titulo,
            b.OTRO_TITULO as otro_titulo,
            b.TITULO_SERIE as titulo_serie,

            -- Autores
            b.AUTOR as autor,
            b.AUTOR_INSTITUCIONAL as autorinst,
            b.MENCION_RESPONSABILIDAD as mencion,

            -- Publicación
            b.EDITORIAL as editorial,
            b.LUGAR_PUBLICACION as procedencia,
            b.ANO_PUBLICACION as publicacion,
            b.EDICION as edicion,

            -- Descripción física
            b.PAGINAS as paginas,
            b.SERIE as serie_mon,

            -- Contenido
            b.RESUMEN as sintesis,
            b.NOTAS as notas,
            b.MATERIAS as temas_descrip,

            -- Identificadores estándar
            b.ISBN as isbn_issn,

            -- Campos de ejemplar
            e.CODIGO_BARRAS as nroacceso,
            e.SIGNATURA as ubicacion,
            e.UBICACION_FISICA as loc,
            e.TIPO_MATERIAL as tipomaterial,
            e.VOLUMEN as volumen,
            e.NUMERO as numero,
            e.FECHA_ADQUISICION as fechaadq,
            e.PRECIO as precio,
            e.FORMA_ADQUISICION as forma_adqui,
            e.EJEMPLAR as ejemplar,

            -- Fechas
            b.FECHA_CARGA as fechacarga

        FROM BIBLIOGRAFICOS b
        LEFT JOIN EJEMPLARES e ON b.ID_REGISTRO = e.ID_BIBLIO
        WHERE 1=1
        ORDER BY b.ID_REGISTRO, e.CODIGO_BARRAS
    """


# ===========================================================================
# LOGGER
# ===========================================================================

def setup_logger(biblioteca_cod: str) -> logging.Logger:
    """Configura logging"""
    logger = logging.getLogger(f'firebird_export_{biblioteca_cod}')
    logger.setLevel(logging.INFO)

    # Console
    ch = logging.StreamHandler()
    ch.setLevel(logging.INFO)

    # File
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    log_file = f'export_{biblioteca_cod}_{timestamp}.log'
    fh = logging.FileHandler(log_file, encoding='utf-8')
    fh.setLevel(logging.DEBUG)

    formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)
    fh.setFormatter(formatter)

    logger.addHandler(ch)
    logger.addHandler(fh)

    return logger


# ===========================================================================
# FIREBIRD EXPORTER
# ===========================================================================

class FirebirdExporter:
    """Exportador de Firebird a CSV"""

    def __init__(self, biblioteca_cod: str, output_file: str):
        if biblioteca_cod not in FIREBIRD_SERVERS:
            raise ValueError(f"Biblioteca '{biblioteca_cod}' no configurada")

        self.biblioteca_cod = biblioteca_cod
        self.config = FIREBIRD_SERVERS[biblioteca_cod]
        self.output_file = output_file
        self.logger = setup_logger(biblioteca_cod)

        self.connection = None
        self.cursor = None

        self.stats = {
            'registros_leidos': 0,
            'registros_escritos': 0,
            'errores': 0,
            'advertencias': []
        }

    def connect(self) -> bool:
        """Conecta a Firebird"""
        try:
            self.logger.info(f"Conectando a Firebird: {self.config['host']}:{self.config['port']}")
            self.logger.info(f"Base de datos: {self.config['database']}")

            self.connection = fdb.connect(
                host=self.config['host'],
                port=self.config['port'],
                database=self.config['database'],
                user=self.config['user'],
                password=self.config['password'],
                charset=self.config['charset']
            )

            self.cursor = self.connection.cursor()
            self.logger.info("✓ Conexión exitosa")

            # Verificar tablas
            self.cursor.execute("""
                SELECT RDB$RELATION_NAME
                FROM RDB$RELATIONS
                WHERE RDB$SYSTEM_FLAG = 0
                AND RDB$VIEW_BLR IS NULL
            """)

            tables = [row[0].strip() for row in self.cursor.fetchall()]
            self.logger.info(f"Tablas encontradas: {len(tables)}")
            self.logger.debug(f"Tablas: {', '.join(tables[:10])}")

            return True

        except Exception as e:
            self.logger.error(f"✗ Error de conexión: {e}")
            return False

    def disconnect(self):
        """Cierra conexión"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
        self.logger.info("Conexión cerrada")

    def normalize_value(self, value) -> str:
        """Normaliza valor para CSV"""
        if value is None:
            return ""

        # Si es bytes, decodificar
        if isinstance(value, bytes):
            try:
                value = value.decode('utf-8')
            except:
                value = value.decode('latin-1')

        # Convertir a string
        value = str(value).strip()

        # Limpiar caracteres problemáticos
        value = value.replace('\r\n', ' ')
        value = value.replace('\n', ' ')
        value = value.replace('\r', ' ')
        value = ' '.join(value.split())  # Normalizar espacios

        return value

    def export(self) -> bool:
        """Exporta datos a CSV"""
        try:
            query = get_export_query()

            self.logger.info("Ejecutando query de exportación...")
            self.cursor.execute(query)

            # Obtener nombres de columnas
            columns = [desc[0].lower() for desc in self.cursor.description]
            self.logger.info(f"Columnas: {len(columns)}")

            # Añadir codbiblio al inicio
            columns_with_bib = ['codbiblio'] + columns

            # Abrir archivo CSV
            self.logger.info(f"Creando archivo: {self.output_file}")

            with open(self.output_file, 'w', encoding='utf-8', newline='') as csvfile:
                writer = csv.DictWriter(
                    csvfile,
                    fieldnames=columns_with_bib,
                    delimiter=';',
                    quotechar='"',
                    quoting=csv.QUOTE_MINIMAL
                )

                # Escribir header
                writer.writeheader()

                # Procesar filas
                batch_size = 1000
                batch = []

                for row in self.cursor:
                    self.stats['registros_leidos'] += 1

                    # Crear diccionario
                    row_dict = {'codbiblio': self.biblioteca_cod}

                    for i, col in enumerate(columns):
                        row_dict[col] = self.normalize_value(row[i])

                    # Validaciones básicas
                    if not row_dict.get('titulo'):
                        self.logger.warning(f"Registro {row_dict.get('analisis')} sin título - OMITIDO")
                        self.stats['advertencias'].append(f"Sin título: {row_dict.get('analisis')}")
                        continue

                    batch.append(row_dict)

                    # Escribir en lotes
                    if len(batch) >= batch_size:
                        writer.writerows(batch)
                        self.stats['registros_escritos'] += len(batch)
                        self.logger.info(f"Progreso: {self.stats['registros_escritos']} registros escritos...")
                        batch = []

                # Escribir últimos registros
                if batch:
                    writer.writerows(batch)
                    self.stats['registros_escritos'] += len(batch)

            self.logger.info(f"✓ Exportación completada: {self.output_file}")
            return True

        except Exception as e:
            self.logger.error(f"✗ Error durante exportación: {e}")
            import traceback
            traceback.print_exc()
            return False

    def print_stats(self):
        """Imprime estadísticas"""
        self.logger.info("="*70)
        self.logger.info("ESTADÍSTICAS DE EXPORTACIÓN")
        self.logger.info("="*70)
        self.logger.info(f"Biblioteca: {self.config['nombre']}")
        self.logger.info(f"Registros leídos: {self.stats['registros_leidos']}")
        self.logger.info(f"Registros escritos: {self.stats['registros_escritos']}")
        self.logger.info(f"Errores: {self.stats['errores']}")

        if self.stats['advertencias']:
            self.logger.warning(f"Advertencias: {len(self.stats['advertencias'])}")
            for adv in self.stats['advertencias'][:10]:
                self.logger.warning(f"  - {adv}")
            if len(self.stats['advertencias']) > 10:
                self.logger.warning(f"  ... y {len(self.stats['advertencias']) - 10} más")

        self.logger.info("="*70)


# ===========================================================================
# CLI
# ===========================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Exportador de Firebird a CSV para Koha',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Ejemplos de uso:

  # Exportar una biblioteca
  python3 firebird_exporter.py --biblioteca FACAGR --output FACAGR.csv

  # Exportar todas las bibliotecas
  python3 firebird_exporter.py --all

Bibliotecas configuradas:
''' + '\n'.join([f"  - {cod}: {cfg['nombre']}" for cod, cfg in FIREBIRD_SERVERS.items()])
    )

    parser.add_argument(
        '--biblioteca',
        type=str,
        choices=list(FIREBIRD_SERVERS.keys()),
        help='Código de la biblioteca a exportar'
    )

    parser.add_argument(
        '--output',
        type=str,
        help='Archivo CSV de salida'
    )

    parser.add_argument(
        '--all',
        action='store_true',
        help='Exportar todas las bibliotecas'
    )

    args = parser.parse_args()

    # Validaciones
    if not args.all and not args.biblioteca:
        parser.error("Debe especificar --biblioteca o --all")

    if args.biblioteca and not args.output:
        args.output = f"{args.biblioteca}.csv"

    # Procesar
    if args.all:
        # Exportar todas
        for bib_cod in FIREBIRD_SERVERS.keys():
            print(f"\n{'='*70}")
            print(f"EXPORTANDO: {FIREBIRD_SERVERS[bib_cod]['nombre']}")
            print(f"{'='*70}\n")

            output_file = f"{bib_cod}.csv"

            try:
                exporter = FirebirdExporter(bib_cod, output_file)

                if not exporter.connect():
                    print(f"✗ Error conectando a {bib_cod}")
                    continue

                success = exporter.export()
                exporter.disconnect()
                exporter.print_stats()

                if success:
                    print(f"\n✓ Archivo generado: {output_file}\n")
                else:
                    print(f"\n✗ Error exportando {bib_cod}\n")

            except Exception as e:
                print(f"\n✗ Error procesando {bib_cod}: {e}\n")

    else:
        # Exportar una
        exporter = FirebirdExporter(args.biblioteca, args.output)

        if not exporter.connect():
            sys.exit(1)

        success = exporter.export()
        exporter.disconnect()
        exporter.print_stats()

        if success:
            print(f"\n✓ Exportación exitosa: {args.output}")
            print(f"\nPróximo paso:")
            print(f"  python3 opac_exportar.py \\")
            print(f"    -i {args.output} \\")
            print(f"    --codbiblio {args.biblioteca} \\")
            print(f"    --loc-default SALA \\")
            print(f"    --stream \\")
            print(f"    --split-by 5000")
        else:
            sys.exit(1)


if __name__ == '__main__':
    main()
