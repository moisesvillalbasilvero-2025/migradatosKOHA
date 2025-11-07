#!/usr/bin/env python3
"""
CORRECTOR DE CÓDIGOS DE ACCESO ÚNICOS PARA ING.CSV
===================================================
Universidad Nacional de Asunción - Facultad de Ingeniería

Este script corrige los códigos de acceso (nroacceso) duplicados o vacíos
en el archivo ING.csv, generando códigos únicos en el formato: ING-0000001

Características:
- Detecta códigos vacíos o duplicados
- Genera códigos únicos secuenciales
- Preserva códigos existentes válidos si no están duplicados
- Genera reporte de cambios realizados

Autor: Sistema Automatizado UNA
Versión: 1.0
Fecha: 2025-10-20
"""

import pandas as pd
import sys
from pathlib import Path
from datetime import datetime


class Color:
    """Colores ANSI para terminal"""
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'


def print_banner():
    """Muestra banner del sistema"""
    banner = f"""
{Color.BOLD}{Color.CYAN}
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║     CORRECTOR DE CÓDIGOS DE ACCESO - FACULTAD DE INGENIERÍA     ║
║              Universidad Nacional de Asunción                    ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
{Color.END}
"""
    print(banner)


def corregir_codigos_acceso(archivo_entrada, archivo_salida=None):
    """
    Corrige códigos de acceso duplicados o vacíos en el archivo CSV

    Args:
        archivo_entrada: Ruta al archivo CSV original
        archivo_salida: Ruta al archivo CSV corregido (opcional)
    """

    print(f"{Color.CYAN}Procesando archivo:{Color.END} {archivo_entrada}\n")

    # Leer CSV
    print(f"1. Leyendo archivo CSV...")
    df = pd.read_csv(archivo_entrada, encoding='utf-8', sep=';', quotechar='"', low_memory=False)
    total_registros = len(df)
    print(f"   {Color.GREEN}✓{Color.END} {total_registros:,} registros leídos")

    # Analizar códigos actuales
    print(f"\n2. Analizando códigos de acceso actuales...")

    # Convertir columna a string y limpiar espacios
    df['nroacceso'] = df['nroacceso'].astype(str).str.strip()

    # Detectar códigos vacíos
    codigos_vacios = (df['nroacceso'] == '') | (df['nroacceso'] == 'nan') | df['nroacceso'].isna()
    num_vacios = codigos_vacios.sum()

    # Detectar duplicados (excluyendo vacíos)
    df_no_vacios = df[~codigos_vacios]
    duplicados = df_no_vacios['nroacceso'].duplicated(keep=False)
    num_duplicados = duplicados.sum()

    print(f"   - Códigos vacíos: {Color.YELLOW}{num_vacios:,}{Color.END}")
    print(f"   - Códigos duplicados: {Color.YELLOW}{num_duplicados:,}{Color.END}")

    total_a_corregir = num_vacios + num_duplicados
    print(f"   - {Color.BOLD}Total a corregir: {total_a_corregir:,}{Color.END}")

    if total_a_corregir == 0:
        print(f"\n{Color.GREEN}✓ No hay códigos que corregir. El archivo está OK.{Color.END}")
        return

    # Generar códigos únicos
    print(f"\n3. Generando códigos únicos...")

    # Obtener código de biblioteca
    codbiblio = df['codbiblio'].iloc[0].strip() if 'codbiblio' in df.columns else 'ING'
    print(f"   Código de biblioteca: {Color.BOLD}{codbiblio}{Color.END}")

    # Contador para códigos nuevos
    contador = 1
    registros_corregidos = 0

    # Corregir códigos vacíos y duplicados
    for idx, row in df.iterrows():
        codigo_actual = str(row['nroacceso']).strip()

        # Si está vacío o es duplicado, generar nuevo código
        if codigo_actual == '' or codigo_actual == 'nan' or pd.isna(row['nroacceso']):
            nuevo_codigo = f"{codbiblio}-{contador:07d}"
            df.at[idx, 'nroacceso'] = nuevo_codigo
            contador += 1
            registros_corregidos += 1
        elif codigo_actual in df['nroacceso'].value_counts()[df['nroacceso'].value_counts() > 1].index:
            # Es un duplicado
            nuevo_codigo = f"{codbiblio}-{contador:07d}"
            df.at[idx, 'nroacceso'] = nuevo_codigo
            contador += 1
            registros_corregidos += 1

    print(f"   {Color.GREEN}✓{Color.END} {registros_corregidos:,} códigos corregidos")
    print(f"   {Color.GREEN}✓{Color.END} Formato: {codbiblio}-0000001 hasta {codbiblio}-{contador-1:07d}")

    # Verificar unicidad
    print(f"\n4. Verificando unicidad de códigos...")
    duplicados_finales = df['nroacceso'].duplicated().sum()

    if duplicados_finales == 0:
        print(f"   {Color.GREEN}✓✓ Todos los códigos son únicos{Color.END}")
    else:
        print(f"   {Color.RED}✗ Aún hay {duplicados_finales} duplicados{Color.END}")
        return

    # Guardar archivo corregido
    if archivo_salida is None:
        nombre_base = Path(archivo_entrada).stem
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        archivo_salida = f"{nombre_base}_corregido.csv"

    print(f"\n5. Guardando archivo corregido...")
    df.to_csv(archivo_salida, index=False, encoding='utf-8', sep=';', quotechar='"')
    print(f"   {Color.GREEN}✓{Color.END} Archivo guardado: {Color.BOLD}{archivo_salida}{Color.END}")

    # Generar reporte
    print(f"\n{Color.BOLD}{Color.BLUE}═══════════════════════════════════════════════════════════════════{Color.END}")
    print(f"{Color.BOLD}RESUMEN DE CORRECCIONES:{Color.END}")
    print(f"  • Total de registros: {total_registros:,}")
    print(f"  • Códigos corregidos: {registros_corregidos:,}")
    print(f"  • Códigos preservados: {total_registros - registros_corregidos:,}")
    print(f"  • Archivo de salida: {archivo_salida}")
    print(f"{Color.BOLD}{Color.BLUE}═══════════════════════════════════════════════════════════════════{Color.END}")

    print(f"\n{Color.GREEN}{Color.BOLD}✓✓✓ PROCESO COMPLETADO EXITOSAMENTE ✓✓✓{Color.END}\n")
    print(f"{Color.YELLOW}Próximo paso:{Color.END}")
    print(f"  Usar el archivo {Color.BOLD}{archivo_salida}{Color.END} para la importación a Koha\n")


def main():
    """Función principal"""
    print_banner()

    if len(sys.argv) < 2:
        print(f"{Color.BOLD}Uso:{Color.END}")
        print(f"  python3 corregir_codigos_ing.py <archivo_entrada.csv> [archivo_salida.csv]\n")
        print(f"{Color.BOLD}Ejemplo:{Color.END}")
        print(f"  python3 corregir_codigos_ing.py ING.csv")
        print(f"  python3 corregir_codigos_ing.py ING.csv ING_corregido.csv\n")
        sys.exit(1)

    archivo_entrada = sys.argv[1]
    archivo_salida = sys.argv[2] if len(sys.argv) > 2 else None

    if not Path(archivo_entrada).exists():
        print(f"{Color.RED}✗ Error: Archivo no encontrado: {archivo_entrada}{Color.END}\n")
        sys.exit(1)

    try:
        corregir_codigos_acceso(archivo_entrada, archivo_salida)
    except Exception as e:
        print(f"\n{Color.RED}✗ Error: {e}{Color.END}\n")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
