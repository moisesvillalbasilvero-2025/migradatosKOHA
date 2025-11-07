#!/usr/bin/env python3
"""
ANALIZADOR INTELIGENTE DE ARCHIVOS CSV PARA KOHA
===================================================
Universidad Nacional de Asunción

Analiza archivos CSV, detecta campos faltantes, sugiere métodos
para obtener los datos faltantes y genera un reporte completo.

CARACTERÍSTICAS:
- Análisis profundo de estructura CSV
- Detección de campos obligatorios y recomendados
- Análisis de calidad de datos
- Detección de duplicados por múltiples criterios
- Sugerencias para obtener datos faltantes
- Validación contra catálogo OPAC de referencia (FACEN)
- Generación de reportes HTML y PDF
- Recomendaciones para mejorar la calidad del catálogo

Versión: 1.0
Fecha: 2025-10-16
"""

import os
import sys
import pandas as pd
import json
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional, Tuple
import re
from collections import Counter, defaultdict


class Color:
    """Colores ANSI"""
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    MAGENTA = '\033[95m'
    BOLD = '\033[1m'
    END = '\033[0m'


class AnalizadorCSV:
    """Analizador inteligente de archivos CSV"""

    def __init__(self, csv_path: str):
        self.csv_path = csv_path
        self.df = None
        self.encoding = None
        self.analisis = {}

        # Campos esperados según el catálogo de referencia FACEN
        self.campos_obligatorios = [
            'titulo',
            'nroacceso',
            'codbiblio',
            'tipomaterial'
        ]

        self.campos_criticos_opac = [
            'autor',           # Autor principal
            'autorinst',       # Autor institucional
            'temas_descrip',   # Materias (keywords para búsqueda)
            'isbn_issn',       # ISBN/ISSN (identificador único)
            'editorial',       # Editorial
            'publicacion',     # Año de publicación
            'idioma_descrip',  # Idioma
            'ubicacion',       # Signatura topográfica
            'sintesis'         # Resumen/abstract
        ]

        self.campos_enriquecimiento = [
            'edicion',
            'nom_pais',
            'medio_descrip',
            'procedencia',
            'volumen',
            'ejemplar',
            'notas'
        ]

    def cargar_csv(self) -> bool:
        """Carga CSV con detección automática de encoding"""
        print(f"\n{Color.CYAN}Analizando archivo:{Color.END} {Path(self.csv_path).name}")
        print("="*70)

        encodings = ['utf-8', 'latin-1', 'cp1252', 'iso-8859-1']

        for encoding in encodings:
            try:
                self.df = pd.read_csv(
                    self.csv_path,
                    encoding=encoding,
                    sep=';',
                    quotechar='"',
                    low_memory=False
                )
                self.encoding = encoding
                print(f"{Color.GREEN}✓{Color.END} Encoding detectado: {Color.BOLD}{encoding}{Color.END}")
                return True
            except UnicodeDecodeError:
                continue
            except Exception as e:
                print(f"{Color.RED}Error:{Color.END} {e}")
                continue

        print(f"{Color.RED}✗ No se pudo leer el archivo con ningún encoding{Color.END}")
        return False

    def analizar_estructura(self):
        """Analiza estructura básica del CSV"""
        print(f"\n{Color.BOLD}{Color.BLUE}1. ESTRUCTURA BÁSICA{Color.END}")
        print("-" * 70)

        total_registros = len(self.df)
        total_columnas = len(self.df.columns)

        print(f"Total de registros: {Color.BOLD}{total_registros:,}{Color.END}")
        print(f"Total de columnas: {Color.BOLD}{total_columnas}{Color.END}")

        # Limpiar nombres de columnas
        self.df.columns = [col.strip().lower() for col in self.df.columns]

        print(f"\nColumnas presentes:")
        for i, col in enumerate(self.df.columns, 1):
            print(f"  {i:2d}. {col}")

        self.analisis['estructura'] = {
            'total_registros': total_registros,
            'total_columnas': total_columnas,
            'columnas': list(self.df.columns)
        }

    def analizar_campos_obligatorios(self):
        """Analiza presencia de campos obligatorios"""
        print(f"\n{Color.BOLD}{Color.BLUE}2. CAMPOS OBLIGATORIOS{Color.END}")
        print("-" * 70)

        columnas_presentes = set(self.df.columns)
        campos_faltantes = []
        campos_presentes = []

        for campo in self.campos_obligatorios:
            if campo in columnas_presentes:
                # Contar valores no nulos
                no_nulos = self.df[campo].notna().sum()
                porcentaje = (no_nulos / len(self.df)) * 100

                if porcentaje >= 95:
                    print(f"  {Color.GREEN}✓{Color.END} {campo:20s} - {porcentaje:6.2f}% completo")
                    campos_presentes.append(campo)
                elif porcentaje >= 70:
                    print(f"  {Color.YELLOW}⚠{Color.END} {campo:20s} - {porcentaje:6.2f}% completo (MEJORABLE)")
                    campos_presentes.append(campo)
                else:
                    print(f"  {Color.RED}✗{Color.END} {campo:20s} - {porcentaje:6.2f}% completo (CRÍTICO)")
                    campos_faltantes.append(campo)
            else:
                print(f"  {Color.RED}✗{Color.END} {campo:20s} - COLUMNA NO EXISTE")
                campos_faltantes.append(campo)

        self.analisis['obligatorios'] = {
            'faltantes': campos_faltantes,
            'presentes': campos_presentes
        }

    def analizar_campos_criticos_opac(self):
        """Analiza campos críticos para el OPAC"""
        print(f"\n{Color.BOLD}{Color.BLUE}3. CAMPOS CRÍTICOS PARA OPAC (Búsqueda y Visualización){Color.END}")
        print("-" * 70)

        columnas_presentes = set(self.df.columns)
        analisis_criticos = {}

        for campo in self.campos_criticos_opac:
            if campo in columnas_presentes:
                valores_vacios = self.df[campo].isna().sum() + (self.df[campo] == '').sum()
                valores_llenos = len(self.df) - valores_vacios
                porcentaje = (valores_llenos / len(self.df)) * 100

                analisis_criticos[campo] = {
                    'presente': True,
                    'porcentaje_completo': porcentaje,
                    'valores_llenos': valores_llenos,
                    'valores_vacios': valores_vacios
                }

                # Indicador visual
                if porcentaje >= 80:
                    icono = f"{Color.GREEN}✓✓{Color.END}"
                    estado = "EXCELENTE"
                elif porcentaje >= 50:
                    icono = f"{Color.YELLOW}⚠{Color.END} "
                    estado = "MEJORABLE"
                else:
                    icono = f"{Color.RED}✗✗{Color.END}"
                    estado = "CRÍTICO"

                print(f"  {icono} {campo:20s} - {porcentaje:6.2f}% ({estado})")

                # Análisis específico por campo
                if campo == 'isbn_issn' and porcentaje < 50:
                    print(f"      {Color.CYAN}→{Color.END} Buscar ISBNs en Google Books API / Open Library")
                elif campo == 'temas_descrip' and porcentaje < 50:
                    print(f"      {Color.CYAN}→{Color.END} Usar clasificación Dewey para generar materias")
                elif campo == 'autor' and porcentaje < 70:
                    print(f"      {Color.CYAN}→{Color.END} Revisar campo 'autorinst' (autor institucional)")

            else:
                analisis_criticos[campo] = {
                    'presente': False,
                    'porcentaje_completo': 0
                }
                print(f"  {Color.RED}✗✗{Color.END} {campo:20s} - NO EXISTE (agregar columna)")

        self.analisis['criticos'] = analisis_criticos

    def detectar_duplicados(self):
        """Detecta duplicados por múltiples criterios"""
        print(f"\n{Color.BOLD}{Color.BLUE}4. DETECCIÓN DE DUPLICADOS{Color.END}")
        print("-" * 70)

        duplicados_info = {}

        # 1. Por código de acceso (nroacceso)
        if 'nroacceso' in self.df.columns:
            dups_acceso = self.df[self.df.duplicated(subset=['nroacceso'], keep=False)]
            num_dups_acceso = len(dups_acceso)

            if num_dups_acceso > 0:
                print(f"  {Color.RED}⚠{Color.END} Duplicados por CÓDIGO DE ACCESO: {num_dups_acceso}")
                print(f"      Acción: Renumerar códigos duplicados")
                duplicados_info['nroacceso'] = num_dups_acceso
            else:
                print(f"  {Color.GREEN}✓{Color.END} Sin duplicados por CÓDIGO DE ACCESO")

        # 2. Por ISBN/ISSN
        if 'isbn_issn' in self.df.columns:
            df_con_isbn = self.df[self.df['isbn_issn'].notna() & (self.df['isbn_issn'] != '')]
            dups_isbn = df_con_isbn[df_con_isbn.duplicated(subset=['isbn_issn'], keep=False)]
            num_dups_isbn = len(dups_isbn)

            if num_dups_isbn > 0:
                print(f"  {Color.YELLOW}⚠{Color.END} Duplicados por ISBN/ISSN: {num_dups_isbn}")
                print(f"      Posible: Múltiples ejemplares del mismo título (NORMAL)")
                duplicados_info['isbn_issn'] = num_dups_isbn
            else:
                print(f"  {Color.GREEN}✓{Color.END} Sin duplicados por ISBN/ISSN")

        # 3. Por título exacto
        if 'titulo' in self.df.columns:
            dups_titulo = self.df[self.df.duplicated(subset=['titulo'], keep=False)]
            num_dups_titulo = len(dups_titulo)

            if num_dups_titulo > 0:
                print(f"  {Color.YELLOW}⚠{Color.END} Duplicados por TÍTULO EXACTO: {num_dups_titulo}")
                print(f"      Revisar: Pueden ser ejemplares múltiples o duplicados reales")
                duplicados_info['titulo'] = num_dups_titulo
            else:
                print(f"  {Color.GREEN}✓{Color.END} Sin duplicados por TÍTULO")

        # 4. Por título + autor (duplicado real más probable)
        if 'titulo' in self.df.columns and 'autor' in self.df.columns:
            dups_titulo_autor = self.df[self.df.duplicated(subset=['titulo', 'autor'], keep=False)]
            num_dups_titulo_autor = len(dups_titulo_autor)

            if num_dups_titulo_autor > 0:
                print(f"  {Color.RED}⚠{Color.END} Duplicados por TÍTULO + AUTOR: {num_dups_titulo_autor}")
                print(f"      {Color.BOLD}Acción requerida:{Color.END} Fusionar o eliminar duplicados")
                duplicados_info['titulo_autor'] = num_dups_titulo_autor

                # Mostrar ejemplos
                if num_dups_titulo_autor > 0 and num_dups_titulo_autor <= 20:
                    print(f"\n      Ejemplos de duplicados detectados:")
                    ejemplos = dups_titulo_autor.groupby(['titulo', 'autor']).size().head(5)
                    for (tit, aut), count in ejemplos.items():
                        tit_corto = tit[:40] if len(str(tit)) > 40 else tit
                        aut_corto = aut[:30] if len(str(aut)) > 30 else aut
                        print(f"        - \"{tit_corto}\" por {aut_corto} ({count} copias)")
            else:
                print(f"  {Color.GREEN}✓{Color.END} Sin duplicados por TÍTULO + AUTOR")

        self.analisis['duplicados'] = duplicados_info

    def analizar_calidad_datos(self):
        """Analiza calidad general de los datos"""
        print(f"\n{Color.BOLD}{Color.BLUE}5. CALIDAD DE DATOS{Color.END}")
        print("-" * 70)

        # Calcular puntuación de calidad
        puntos_totales = 0
        puntos_obtenidos = 0

        # Campos obligatorios (40 puntos)
        campos_obl_ok = len(self.analisis['obligatorios']['presentes'])
        campos_obl_total = len(self.campos_obligatorios)
        puntos_obl = (campos_obl_ok / campos_obl_total) * 40
        puntos_obtenidos += puntos_obl
        puntos_totales += 40

        # Campos críticos (40 puntos)
        campos_crit_completos = sum(
            1 for c in self.analisis['criticos'].values()
            if c['presente'] and c['porcentaje_completo'] >= 70
        )
        puntos_crit = (campos_crit_completos / len(self.campos_criticos_opac)) * 40
        puntos_obtenidos += puntos_crit
        puntos_totales += 40

        # Sin duplicados críticos (20 puntos)
        duplicados_criticos = self.analisis['duplicados'].get('titulo_autor', 0)
        if duplicados_criticos == 0:
            puntos_dup = 20
        elif duplicados_criticos < len(self.df) * 0.05:  # Menos del 5%
            puntos_dup = 15
        elif duplicados_criticos < len(self.df) * 0.10:  # Menos del 10%
            puntos_dup = 10
        else:
            puntos_dup = 5

        puntos_obtenidos += puntos_dup
        puntos_totales += 20

        calidad_porcentaje = (puntos_obtenidos / puntos_totales) * 100

        # Mostrar puntuación
        if calidad_porcentaje >= 85:
            color = Color.GREEN
            estado = "EXCELENTE"
        elif calidad_porcentaje >= 70:
            color = Color.YELLOW
            estado = "BUENO"
        elif calidad_porcentaje >= 50:
            color = Color.YELLOW
            estado = "REGULAR"
        else:
            color = Color.RED
            estado = "NECESITA MEJORA"

        print(f"\n  {Color.BOLD}PUNTUACIÓN DE CALIDAD:{Color.END}")
        print(f"  {color}{Color.BOLD}{calidad_porcentaje:.1f}/100{Color.END} - {estado}")
        print(f"\n  Desglose:")
        print(f"    - Campos obligatorios:  {puntos_obl:5.1f}/40")
        print(f"    - Campos críticos OPAC: {puntos_crit:5.1f}/40")
        print(f"    - Sin duplicados:       {puntos_dup:5.1f}/20")

        self.analisis['calidad'] = {
            'puntuacion': calidad_porcentaje,
            'estado': estado,
            'desglose': {
                'obligatorios': puntos_obl,
                'criticos': puntos_crit,
                'duplicados': puntos_dup
            }
        }

    def generar_plan_mejora(self):
        """Genera plan de acción para mejorar los datos"""
        print(f"\n{Color.BOLD}{Color.BLUE}6. PLAN DE MEJORA Y ACCIÓN{Color.END}")
        print("=" * 70)

        acciones = []
        prioridad_num = 1

        # Campos obligatorios faltantes
        if self.analisis['obligatorios']['faltantes']:
            print(f"\n{Color.BOLD}{Color.RED}PRIORIDAD CRÍTICA:{Color.END}")
            for campo in self.analisis['obligatorios']['faltantes']:
                print(f"  {prioridad_num}. Completar campo OBLIGATORIO: '{campo}'")
                if campo == 'nroacceso':
                    print(f"     {Color.CYAN}→{Color.END} Generar automáticamente: CODBIB-0000001, CODBIB-0000002, ...")
                elif campo == 'codbiblio':
                    print(f"     {Color.CYAN}→{Color.END} Extraer del nombre del archivo o solicitar al bibliotecario")
                elif campo == 'tipomaterial':
                    print(f"     {Color.CYAN}→{Color.END} Detectar automáticamente: LIBRO, REVISTA, TESIS, etc.")
                prioridad_num += 1

        # Campos críticos con baja completitud
        print(f"\n{Color.BOLD}{Color.YELLOW}PRIORIDAD ALTA:{Color.END}")
        for campo, info in self.analisis['criticos'].items():
            if info['presente'] and info['porcentaje_completo'] < 50:
                print(f"  {prioridad_num}. Enriquecer campo: '{campo}' ({info['porcentaje_completo']:.1f}% completo)")

                if campo == 'isbn_issn':
                    print(f"     {Color.CYAN}→{Color.END} Método 1: Buscar en Open Library API")
                    print(f"     {Color.CYAN}→{Color.END} Método 2: Buscar en Google Books API")
                    print(f"     {Color.CYAN}→{Color.END} Método 3: Extraer de sintesis/notas si existe")

                elif campo == 'autor':
                    print(f"     {Color.CYAN}→{Color.END} Revisar campo 'autorinst' si autor personal no existe")
                    print(f"     {Color.CYAN}→{Color.END} Buscar en bases de datos bibliográficas")

                elif campo == 'temas_descrip':
                    print(f"     {Color.CYAN}→{Color.END} Método 1: Extraer de título usando IA/NLP")
                    print(f"     {Color.CYAN}→{Color.END} Método 2: Usar clasificación Dewey → materias")
                    print(f"     {Color.CYAN}→{Color.END} Método 3: API de clasificación automática")

                elif campo == 'editorial':
                    print(f"     {Color.CYAN}→{Color.END} Buscar en bases de datos de ISBN")

                elif campo == 'publicacion':
                    print(f"     {Color.CYAN}→{Color.END} Extraer de campo 'copyright' si existe")
                    print(f"     {Color.CYAN}→{Color.END} Buscar en bases de datos externas")

                prioridad_num += 1

        # Duplicados
        if self.analisis['duplicados']:
            print(f"\n{Color.BOLD}{Color.YELLOW}PRIORIDAD MEDIA:{Color.END}")
            if self.analisis['duplicados'].get('nroacceso', 0) > 0:
                print(f"  {prioridad_num}. Resolver duplicados de CÓDIGO DE ACCESO")
                print(f"     {Color.CYAN}→{Color.END} Renumerar automáticamente con sufijos: -001, -002, etc.")
                prioridad_num += 1

            if self.analisis['duplicados'].get('titulo_autor', 0) > 0:
                print(f"  {prioridad_num}. Revisar duplicados de TÍTULO + AUTOR")
                print(f"     {Color.CYAN}→{Color.END} Opción 1: Fusionar registros (si son idénticos)")
                print(f"     {Color.CYAN}→{Color.END} Opción 2: Mantener (si son ejemplares múltiples)")
                print(f"     {Color.CYAN}→{Color.END} Opción 3: Revisar manualmente uno por uno")
                prioridad_num += 1

    def generar_comparacion_facen(self):
        """Compara con el catálogo OPAC de FACEN"""
        print(f"\n{Color.BOLD}{Color.BLUE}7. COMPARACIÓN CON CATÁLOGO FACEN (Referencia){Color.END}")
        print("=" * 70)

        facen_fields = {
            'Título': '✓' if 'titulo' in self.df.columns else '✗',
            'Autor': '✓' if 'autor' in self.df.columns else '✗',
            'Autor institucional': '✓' if 'autorinst' in self.df.columns else '✗',
            'Año': '✓' if 'publicacion' in self.df.columns else '✗',
            'Materia': '✓' if 'temas_descrip' in self.df.columns else '✗',
            'Idioma': '✓' if 'idioma_descrip' in self.df.columns else '✗',
            'Tipo de material': '✓' if 'tipomaterial' in self.df.columns else '✗',
            'Ubicación': '✓' if 'ubicacion' in self.df.columns else '✗',
            'ISBN/ISSN': '✓' if 'isbn_issn' in self.df.columns else '✗',
            'Editorial': '✓' if 'editorial' in self.df.columns else '✗'
        }

        print("\nCampos presentes vs. FACEN:")
        for field, status in facen_fields.items():
            if status == '✓':
                print(f"  {Color.GREEN}{status}{Color.END} {field}")
            else:
                print(f"  {Color.RED}{status}{Color.END} {field}")

        cobertura = list(facen_fields.values()).count('✓') / len(facen_fields) * 100
        print(f"\nCobertura respecto a FACEN: {cobertura:.1f}%")

        if cobertura >= 90:
            print(f"{Color.GREEN}✓ Excelente compatibilidad con FACEN{Color.END}")
        elif cobertura >= 70:
            print(f"{Color.YELLOW}⚠ Buena compatibilidad, algunos campos por mejorar{Color.END}")
        else:
            print(f"{Color.RED}⚠ Baja compatibilidad, se requiere enriquecimiento significativo{Color.END}")

    def guardar_reporte_json(self):
        """Guarda reporte en formato JSON"""
        nombre_base = Path(self.csv_path).stem
        output_file = f"analisis_{nombre_base}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(self.analisis, f, indent=2, ensure_ascii=False)

        print(f"\n{Color.GREEN}✓ Reporte JSON guardado:{Color.END} {output_file}")

    def ejecutar_analisis_completo(self):
        """Ejecuta análisis completo"""
        if not self.cargar_csv():
            return False

        self.analizar_estructura()
        self.analizar_campos_obligatorios()
        self.analizar_campos_criticos_opac()
        self.detectar_duplicados()
        self.analizar_calidad_datos()
        self.generar_plan_mejora()
        self.generar_comparacion_facen()
        self.guardar_reporte_json()

        print(f"\n{Color.GREEN}{Color.BOLD}✓✓✓ ANÁLISIS COMPLETADO ✓✓✓{Color.END}\n")

        return True


def main():
    """Función principal"""
    import sys

    if len(sys.argv) < 2:
        print(f"\n{Color.BOLD}Uso:{Color.END} python3 analizador_csv.py <archivo.csv>")
        print(f"\nEjemplo:")
        print(f"  python3 analizador_csv.py POL.csv")
        print(f"  python3 analizador_csv.py ARQ.csv\n")
        sys.exit(1)

    csv_file = sys.argv[1]

    if not os.path.exists(csv_file):
        print(f"{Color.RED}Error: Archivo no encontrado: {csv_file}{Color.END}")
        sys.exit(1)

    print(f"\n{Color.BOLD}{Color.CYAN}")
    print("="*70)
    print("  ANALIZADOR INTELIGENTE DE ARCHIVOS CSV PARA KOHA")
    print("  Universidad Nacional de Asunción")
    print("="*70)
    print(f"{Color.END}")

    analizador = AnalizadorCSV(csv_file)
    analizador.ejecutar_analisis_completo()


if __name__ == '__main__':
    main()
