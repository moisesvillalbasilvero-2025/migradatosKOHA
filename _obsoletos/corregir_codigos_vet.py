#!/usr/bin/env python3
"""
CORRECTOR DE CÓDIGOS DUPLICADOS - VET
======================================
Corrige códigos de acceso duplicados en el CSV de Veterinaria
generando códigos únicos automáticamente.

Universidad Nacional de Asunción
Versión: 1.0
Fecha: 2025-10-21
"""

import csv
import sys
from collections import defaultdict
from pathlib import Path

def corregir_codigos_vet(archivo_entrada):
    """
    Corrige códigos duplicados en VET.csv
    Genera códigos únicos: VET-XXXXX
    """

    print(f"\n{'='*70}")
    print("  CORRECTOR DE CÓDIGOS DUPLICADOS - VETERINARIA")
    print(f"{'='*70}\n")

    archivo_path = Path(archivo_entrada)
    archivo_salida = archivo_path.parent / f"{archivo_path.stem}_corregido.csv"

    print(f"Archivo entrada: {archivo_entrada}")
    print(f"Archivo salida: {archivo_salida}")
    print()

    # Leer CSV
    print("Leyendo archivo CSV...")
    with open(archivo_entrada, 'r', encoding='utf-8') as f:
        # Detectar delimitador
        primera_linea = f.readline()
        f.seek(0)

        if ';' in primera_linea:
            delimitador = ';'
            print(f"✓ Delimitador detectado: punto y coma (;)")
        else:
            delimitador = ','
            print(f"✓ Delimitador detectado: coma (,)")

        reader = csv.DictReader(f, delimiter=delimitador, quotechar='"')
        registros = list(reader)

    total_registros = len(registros)
    print(f"✓ Total de registros: {total_registros:,}")
    print()

    # Analizar duplicados
    print("Analizando códigos de acceso...")
    codigos_usados = defaultdict(list)

    for idx, reg in enumerate(registros):
        codigo = reg.get('nroacceso', '').strip()
        codigos_usados[codigo].append(idx)

    duplicados = {k: v for k, v in codigos_usados.items() if len(v) > 1}

    print(f"  Códigos únicos: {len(codigos_usados) - len(duplicados):,}")
    print(f"  Códigos duplicados: {len(duplicados):,}")
    print(f"  Registros afectados: {sum(len(v) for v in duplicados.values()):,}")
    print()

    # Generar códigos únicos
    print("Generando códigos únicos...")

    contador = 1
    codigos_generados = set()
    registros_corregidos = 0

    for reg in registros:
        codigo_original = reg.get('nroacceso', '').strip()

        # Si el código está vacío o es duplicado, generar uno nuevo
        if not codigo_original or codigo_original in duplicados:
            # Generar código único: VET-00001, VET-00002, etc.
            while True:
                nuevo_codigo = f"VET-{contador:05d}"
                if nuevo_codigo not in codigos_generados and nuevo_codigo not in codigos_usados:
                    break
                contador += 1

            reg['nroacceso'] = nuevo_codigo
            codigos_generados.add(nuevo_codigo)
            registros_corregidos += 1
            contador += 1

    print(f"✓ Códigos corregidos: {registros_corregidos:,}")
    print()

    # Guardar CSV corregido
    print("Guardando archivo corregido...")

    fieldnames = registros[0].keys()

    with open(archivo_salida, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter=delimitador, quotechar='"', quoting=csv.QUOTE_MINIMAL)
        writer.writeheader()
        writer.writerows(registros)

    print(f"✓ Archivo guardado: {archivo_salida}")
    print()

    # Verificar resultado
    print("Verificando resultado...")
    with open(archivo_salida, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter=delimitador, quotechar='"')
        nuevos_registros = list(reader)
        nuevos_codigos = [reg.get('nroacceso', '').strip() for reg in nuevos_registros]

    codigos_unicos_final = len(set(nuevos_codigos))

    if codigos_unicos_final == len(nuevos_registros):
        print(f"✓ VERIFICACIÓN EXITOSA: Todos los códigos son únicos ({codigos_unicos_final:,})")
    else:
        print(f"✗ ADVERTENCIA: Aún hay duplicados")
        print(f"  Total registros: {len(nuevos_registros):,}")
        print(f"  Códigos únicos: {codigos_unicos_final:,}")

    print()
    print(f"{'='*70}")
    print("  RESUMEN")
    print(f"{'='*70}")
    print(f"  Registros procesados: {total_registros:,}")
    print(f"  Códigos corregidos: {registros_corregidos:,}")
    print(f"  Archivo de salida: {archivo_salida.name}")
    print(f"{'='*70}")
    print()
    print("Siguiente paso:")
    print(f"  ./importar_nueva_biblioteca.sh VET {archivo_salida}")
    print()

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print("Uso: python3 corregir_codigos_vet.py ARCHIVO.csv")
        print()
        print("Ejemplo:")
        print("  python3 corregir_codigos_vet.py VET.csv")
        sys.exit(1)

    archivo = sys.argv[1]

    if not Path(archivo).exists():
        print(f"Error: Archivo no encontrado: {archivo}")
        sys.exit(1)

    corregir_codigos_vet(archivo)
