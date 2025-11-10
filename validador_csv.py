#!/usr/bin/env python3
"""
VALIDADOR CSV PREVENTIVO
========================
Valida archivos CSV antes de iniciar la importación para detectar
problemas de formato, estructura y contenido.

USO:
    python3 validador_csv.py archivo.csv
    python3 validador_csv.py --strict archivo.csv  # Modo estricto
    python3 validador_csv.py --dir importar_aqui/  # Validar directorio

VALIDACIONES:
    - Existencia y tamaño del archivo
    - Formato CSV válido
    - Columnas obligatorias (titulo, nroacceso)
    - Consistencia de delimitadores
    - Detección de líneas malformadas
    - Validación de encoding
    - Duplicados en códigos de acceso

VERSIÓN: 1.0
FECHA: 2025-10-24
"""

import os
import sys
import csv
import argparse
from pathlib import Path
from typing import Dict, List, Tuple, Optional
from collections import Counter
from datetime import datetime

# Importar gestor de configuración centralizado (opcional para este script)
# validador_csv.py es standalone pero puede usar config si está disponible
try:
    from config_manager import get_config
    _config = get_config()
    _has_config = True
except ImportError:
    _has_config = False


# Colores ANSI
class Colors:
    G = '\033[92m'   # Verde
    Y = '\033[93m'   # Amarillo
    R = '\033[91m'   # Rojo
    B = '\033[94m'   # Azul
    C = '\033[96m'   # Cyan
    BOLD = '\033[1m'
    END = '\033[0m'


# NOTA: Este script es independiente y no requiere configuración centralizada
# ya que trabaja directamente con archivos CSV proporcionados como argumentos.
# La importación de config_manager es opcional para futuras integraciones.


class ValidadorCSV:
    """Validador de archivos CSV para importación"""

    COLUMNAS_OBLIGATORIAS = ['titulo', 'nroacceso']
    COLUMNAS_RECOMENDADAS = ['autor', 'editorial', 'publicacion']

    MAX_SIZE_MB = 1000  # Advertencia si supera 1GB
    MAX_SIZE_MB_STRICT = 500  # Error en modo estricto
    MIN_COLUMNS = 3
    MAX_COLUMNS = 100

    def __init__(self, archivo: Path, strict: bool = False):
        self.archivo = archivo
        self.strict = strict
        self.errores: List[str] = []
        self.warnings: List[str] = []
        self.info: List[str] = []
        self.encoding = 'utf-8'
        self.delimiter = ';'
        self.total_lineas = 0
        self.columnas = []

    def log_error(self, msg: str):
        """Registra un error crítico"""
        self.errores.append(msg)
        print(f"{Colors.R}✗ ERROR: {msg}{Colors.END}")

    def log_warning(self, msg: str):
        """Registra una advertencia"""
        self.warnings.append(msg)
        print(f"{Colors.Y}⚠ WARNING: {msg}{Colors.END}")

    def log_info(self, msg: str):
        """Registra información"""
        self.info.append(msg)
        print(f"{Colors.C}ℹ INFO: {msg}{Colors.END}")

    def log_success(self, msg: str):
        """Registra éxito"""
        print(f"{Colors.G}✓ {msg}{Colors.END}")

    def validar_existencia(self) -> bool:
        """Valida que el archivo existe y es accesible"""
        print(f"\n{Colors.BOLD}1. VALIDANDO EXISTENCIA Y PERMISOS...{Colors.END}")

        if not self.archivo.exists():
            self.log_error(f"Archivo no existe: {self.archivo}")
            return False

        if not self.archivo.is_file():
            self.log_error(f"No es un archivo regular: {self.archivo}")
            return False

        if not os.access(self.archivo, os.R_OK):
            self.log_error(f"No se tiene permiso de lectura: {self.archivo}")
            return False

        self.log_success(f"Archivo existe y es accesible")
        return True

    def validar_tamanio(self) -> bool:
        """Valida el tamaño del archivo"""
        print(f"\n{Colors.BOLD}2. VALIDANDO TAMAÑO...{Colors.END}")

        tamanio_bytes = self.archivo.stat().st_size
        tamanio_mb = tamanio_bytes / (1024 * 1024)

        self.log_info(f"Tamaño: {tamanio_mb:.2f} MB ({tamanio_bytes:,} bytes)")

        if tamanio_mb > self.MAX_SIZE_MB:
            msg = f"Archivo muy grande ({tamanio_mb:.2f} MB). Considerar dividir."
            if self.strict and tamanio_mb > self.MAX_SIZE_MB_STRICT:
                self.log_error(msg)
                return False
            else:
                self.log_warning(msg)

        if tamanio_bytes == 0:
            self.log_error("Archivo vacío (0 bytes)")
            return False

        self.log_success(f"Tamaño válido")
        return True

    def detectar_encoding(self) -> bool:
        """Detecta y valida el encoding del archivo"""
        print(f"\n{Colors.BOLD}3. DETECTANDO ENCODING...{Colors.END}")

        encodings = ['utf-8', 'utf-8-sig', 'cp1252', 'latin-1', 'iso-8859-1']

        for enc in encodings:
            try:
                with open(self.archivo, 'r', encoding=enc) as f:
                    f.read(4096)  # Leer muestra
                self.encoding = enc
                self.log_success(f"Encoding detectado: {enc}")
                return True
            except UnicodeDecodeError:
                continue
            except Exception as e:
                self.log_warning(f"Error probando encoding {enc}: {e}")

        self.log_error("No se pudo detectar encoding válido")
        return False

    def detectar_delimitador(self) -> bool:
        """Detecta el delimitador del CSV"""
        print(f"\n{Colors.BOLD}4. DETECTANDO DELIMITADOR...{Colors.END}")

        try:
            with open(self.archivo, 'r', encoding=self.encoding) as f:
                muestra = f.read(4096)

            # Contar posibles delimitadores
            contadores = {
                ';': muestra.count(';'),
                ',': muestra.count(','),
                '\t': muestra.count('\t'),
                '|': muestra.count('|')
            }

            delim_detectado = max(contadores, key=contadores.get)

            if contadores[delim_detectado] < 2:
                self.log_error("No se detectó delimitador válido en el archivo")
                return False

            self.delimiter = delim_detectado
            delim_nombre = {';': 'punto y coma', ',': 'coma', '\t': 'tabulador', '|': 'pipe'}
            self.log_success(f"Delimitador: '{delim_detectado}' ({delim_nombre.get(delim_detectado, 'desconocido')})")

            return True

        except Exception as e:
            self.log_error(f"Error detectando delimitador: {e}")
            return False

    def validar_estructura(self) -> bool:
        """Valida la estructura del CSV"""
        print(f"\n{Colors.BOLD}5. VALIDANDO ESTRUCTURA CSV...{Colors.END}")

        try:
            with open(self.archivo, 'r', encoding=self.encoding) as f:
                # Leer encabezado
                reader = csv.DictReader(f, delimiter=self.delimiter)
                self.columnas = [col.strip() for col in (reader.fieldnames or [])]

                if not self.columnas:
                    self.log_error("No se detectaron columnas/encabezado")
                    return False

                num_cols = len(self.columnas)
                self.log_info(f"Columnas detectadas: {num_cols}")

                # Validar número de columnas
                if num_cols < self.MIN_COLUMNS:
                    self.log_error(f"Muy pocas columnas ({num_cols}). Mínimo: {self.MIN_COLUMNS}")
                    return False

                if num_cols > self.MAX_COLUMNS:
                    self.log_warning(f"Muchas columnas ({num_cols}). Máximo recomendado: {self.MAX_COLUMNS}")

                # Mostrar primeras columnas
                print(f"\n{Colors.C}Primeras 10 columnas:{Colors.END}")
                for i, col in enumerate(self.columnas[:10], 1):
                    print(f"  {i}. {col}")
                if num_cols > 10:
                    print(f"  ... y {num_cols - 10} más")

                self.log_success("Estructura básica válida")
                return True

        except csv.Error as e:
            self.log_error(f"Error de formato CSV: {e}")
            return False
        except Exception as e:
            self.log_error(f"Error validando estructura: {e}")
            return False

    def validar_columnas_obligatorias(self) -> bool:
        """Valida que existan las columnas obligatorias"""
        print(f"\n{Colors.BOLD}6. VALIDANDO COLUMNAS OBLIGATORIAS...{Colors.END}")

        columnas_lower = [col.lower().strip() for col in self.columnas]

        # Verificar obligatorias
        faltantes = []
        for col_oblig in self.COLUMNAS_OBLIGATORIAS:
            if col_oblig.lower() not in columnas_lower:
                faltantes.append(col_oblig)

        if faltantes:
            self.log_error(f"Faltan columnas obligatorias: {', '.join(faltantes)}")
            return False

        self.log_success(f"Todas las columnas obligatorias presentes: {', '.join(self.COLUMNAS_OBLIGATORIAS)}")

        # Verificar recomendadas
        faltantes_recom = []
        for col_recom in self.COLUMNAS_RECOMENDADAS:
            if col_recom.lower() not in columnas_lower:
                faltantes_recom.append(col_recom)

        if faltantes_recom:
            self.log_warning(f"Faltan columnas recomendadas: {', '.join(faltantes_recom)}")

        return True

    def validar_contenido(self) -> bool:
        """Valida el contenido del CSV (muestra)"""
        print(f"\n{Colors.BOLD}7. VALIDANDO CONTENIDO (muestra de 1000 líneas)...{Colors.END}")

        try:
            with open(self.archivo, 'r', encoding=self.encoding) as f:
                reader = csv.DictReader(f, delimiter=self.delimiter)
                columnas_lower = {col.lower().strip(): col for col in (reader.fieldnames or [])}

                # Encontrar columnas clave
                col_titulo = columnas_lower.get('titulo')
                col_nroacceso = columnas_lower.get('nroacceso')

                lineas_vacias = 0
                lineas_sin_titulo = 0
                lineas_sin_acceso = 0
                inconsistencias = []
                codigos_acceso = []

                num_cols_esperadas = len(self.columnas)

                for i, row in enumerate(reader, start=2):  # Start at 2 (header is 1)
                    if i > 1000:  # Muestra de 1000 líneas
                        break

                    # Verificar número de columnas
                    num_cols_linea = len(row)
                    if num_cols_linea != num_cols_esperadas:
                        inconsistencias.append(i)

                    # Verificar campos obligatorios
                    titulo = row.get(col_titulo, '').strip() if col_titulo else ''
                    nroacceso = row.get(col_nroacceso, '').strip() if col_nroacceso else ''

                    if not titulo:
                        lineas_sin_titulo += 1

                    if not nroacceso:
                        lineas_sin_acceso += 1

                    if not titulo and not nroacceso:
                        lineas_vacias += 1

                    if nroacceso:
                        codigos_acceso.append(nroacceso)

                self.total_lineas = i - 1  # No contar header

                # Reportar hallazgos
                self.log_info(f"Líneas procesadas (muestra): {self.total_lineas}")

                if lineas_vacias > 0:
                    msg = f"Líneas completamente vacías: {lineas_vacias}"
                    if lineas_vacias > self.total_lineas * 0.1:  # Más del 10%
                        self.log_error(msg)
                        return False
                    else:
                        self.log_warning(msg)

                if lineas_sin_titulo > 0:
                    msg = f"Líneas sin título: {lineas_sin_titulo}"
                    if self.strict:
                        self.log_error(msg)
                        return False
                    else:
                        self.log_warning(msg)

                if lineas_sin_acceso > 0:
                    self.log_warning(f"Líneas sin código de acceso: {lineas_sin_acceso}")

                if inconsistencias:
                    self.log_warning(f"Líneas con número de columnas inconsistente: {len(inconsistencias)}")
                    if len(inconsistencias) <= 5:
                        print(f"{Colors.Y}  Líneas afectadas: {', '.join(map(str, inconsistencias))}{Colors.END}")

                # Analizar duplicados en códigos de acceso
                if codigos_acceso:
                    contador = Counter(codigos_acceso)
                    duplicados = sum(1 for count in contador.values() if count > 1)

                    if duplicados > 0:
                        total_registros_duplicados = sum(count - 1 for count in contador.values() if count > 1)
                        self.log_warning(
                            f"Códigos de acceso duplicados: {duplicados} códigos "
                            f"({total_registros_duplicados} registros duplicados)"
                        )

                        # Mostrar los más duplicados
                        mas_duplicados = contador.most_common(5)
                        if mas_duplicados[0][1] > 1:
                            print(f"\n{Colors.Y}  Más duplicados:{Colors.END}")
                            for codigo, count in mas_duplicados:
                                if count > 1:
                                    print(f"    • {codigo}: {count} veces")
                    else:
                        self.log_success("No se encontraron duplicados en la muestra")

                if len(self.errores) == 0:
                    self.log_success("Contenido validado correctamente")

                return len(self.errores) == 0

        except Exception as e:
            self.log_error(f"Error validando contenido: {e}")
            return False

    def validar_todo(self) -> bool:
        """Ejecuta todas las validaciones"""
        print(f"\n{Colors.BOLD}{Colors.C}{'═'*70}{Colors.END}")
        print(f"{Colors.BOLD}{Colors.C}VALIDADOR CSV PREVENTIVO{Colors.END}")
        print(f"{Colors.BOLD}{Colors.C}{'═'*70}{Colors.END}")
        print(f"\n{Colors.BOLD}Archivo:{Colors.END} {self.archivo}")
        print(f"{Colors.BOLD}Modo:{Colors.END} {'ESTRICTO' if self.strict else 'NORMAL'}")
        print(f"{Colors.BOLD}Fecha:{Colors.END} {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

        # Ejecutar validaciones en orden
        validaciones = [
            self.validar_existencia,
            self.validar_tamanio,
            self.detectar_encoding,
            self.detectar_delimitador,
            self.validar_estructura,
            self.validar_columnas_obligatorias,
            self.validar_contenido,
        ]

        for validacion in validaciones:
            if not validacion():
                # Si alguna validación falla, detener
                break

        # Resumen final
        self.mostrar_resumen()

        return len(self.errores) == 0

    def mostrar_resumen(self):
        """Muestra resumen de la validación"""
        print(f"\n{Colors.BOLD}{Colors.C}{'═'*70}{Colors.END}")
        print(f"{Colors.BOLD}RESUMEN DE VALIDACIÓN{Colors.END}")
        print(f"{Colors.BOLD}{Colors.C}{'═'*70}{Colors.END}\n")

        if self.errores:
            print(f"{Colors.R}{Colors.BOLD}✗ ERRORES CRÍTICOS: {len(self.errores)}{Colors.END}")
            for i, error in enumerate(self.errores, 1):
                print(f"  {i}. {error}")
            print()

        if self.warnings:
            print(f"{Colors.Y}{Colors.BOLD}⚠ ADVERTENCIAS: {len(self.warnings)}{Colors.END}")
            for i, warning in enumerate(self.warnings, 1):
                print(f"  {i}. {warning}")
            print()

        # Información adicional
        if self.columnas:
            print(f"{Colors.BOLD}INFORMACIÓN DEL ARCHIVO:{Colors.END}")
            print(f"  Encoding:     {self.encoding}")
            print(f"  Delimitador:  '{self.delimiter}'")
            print(f"  Columnas:     {len(self.columnas)}")
            if self.total_lineas > 0:
                print(f"  Líneas:       ~{self.total_lineas}+")
            print()

        # Veredicto final
        if len(self.errores) == 0:
            print(f"{Colors.G}{Colors.BOLD}{'═'*70}{Colors.END}")
            print(f"{Colors.G}{Colors.BOLD}✓✓✓ ARCHIVO VÁLIDO PARA IMPORTACIÓN ✓✓✓{Colors.END}")
            print(f"{Colors.G}{Colors.BOLD}{'═'*70}{Colors.END}\n")
            return True
        else:
            print(f"{Colors.R}{Colors.BOLD}{'═'*70}{Colors.END}")
            print(f"{Colors.R}{Colors.BOLD}✗✗✗ ARCHIVO NO VÁLIDO - CORREGIR ERRORES ✗✗✗{Colors.END}")
            print(f"{Colors.R}{Colors.BOLD}{'═'*70}{Colors.END}\n")
            return False


def validar_directorio(directorio: Path, strict: bool = False) -> Tuple[List[Path], List[Path]]:
    """Valida todos los CSV en un directorio"""
    print(f"\n{Colors.BOLD}Validando directorio: {directorio}{Colors.END}\n")

    archivos_csv = list(directorio.glob("*.csv"))

    if not archivos_csv:
        print(f"{Colors.Y}No se encontraron archivos CSV en {directorio}{Colors.END}")
        return [], []

    print(f"{Colors.C}Archivos CSV encontrados: {len(archivos_csv)}{Colors.END}\n")

    validos = []
    invalidos = []

    for i, archivo in enumerate(archivos_csv, 1):
        print(f"\n{Colors.BOLD}{'─'*70}")
        print(f"Validando archivo {i}/{len(archivos_csv)}: {archivo.name}")
        print(f"{'─'*70}{Colors.END}\n")

        validador = ValidadorCSV(archivo, strict)
        if validador.validar_todo():
            validos.append(archivo)
        else:
            invalidos.append(archivo)

    # Resumen general
    print(f"\n{Colors.BOLD}{Colors.C}{'═'*70}{Colors.END}")
    print(f"{Colors.BOLD}RESUMEN GENERAL DEL DIRECTORIO{Colors.END}")
    print(f"{Colors.BOLD}{Colors.C}{'═'*70}{Colors.END}\n")

    print(f"Total archivos:    {len(archivos_csv)}")
    print(f"{Colors.G}Válidos:           {len(validos)}{Colors.END}")
    print(f"{Colors.R}Inválidos:         {len(invalidos)}{Colors.END}\n")

    if validos:
        print(f"{Colors.G}Archivos válidos:{Colors.END}")
        for archivo in validos:
            print(f"  ✓ {archivo.name}")
        print()

    if invalidos:
        print(f"{Colors.R}Archivos inválidos:{Colors.END}")
        for archivo in invalidos:
            print(f"  ✗ {archivo.name}")
        print()

    return validos, invalidos


def main():
    parser = argparse.ArgumentParser(
        description="Validador CSV Preventivo para Sistema de Importación Koha",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos:
  %(prog)s archivo.csv                    # Validar un archivo
  %(prog)s --strict archivo.csv           # Validación estricta
  %(prog)s --dir importar_aqui/           # Validar directorio
  %(prog)s --dir importar_aqui/ --strict  # Validar directorio (estricto)

Universidad Nacional de Asunción - 2025
        """
    )

    parser.add_argument('archivo', nargs='?', help='Archivo CSV a validar')
    parser.add_argument('--strict', '-s', action='store_true',
                       help='Modo estricto (errores más rigurosos)')
    parser.add_argument('--dir', '-d', help='Validar todos los CSV en un directorio')
    parser.add_argument('--version', action='version', version='%(prog)s 1.0')

    args = parser.parse_args()

    # Validar directorio o archivo
    if args.dir:
        directorio = Path(args.dir)
        if not directorio.is_dir():
            print(f"{Colors.R}Error: No es un directorio válido: {directorio}{Colors.END}")
            sys.exit(1)

        validos, invalidos = validar_directorio(directorio, args.strict)
        sys.exit(0 if len(invalidos) == 0 else 1)

    elif args.archivo:
        archivo = Path(args.archivo)
        validador = ValidadorCSV(archivo, args.strict)
        resultado = validador.validar_todo()
        sys.exit(0 if resultado else 1)

    else:
        parser.print_help()
        sys.exit(0)


if __name__ == '__main__':
    main()
