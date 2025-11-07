#!/usr/bin/env python3
"""
SISTEMA DE DETECCIÓN Y PREVENCIÓN DE DUPLICADOS PARA KOHA
============================================================
Universidad Nacional de Asunción

Este módulo previene la creación de duplicados en Koha durante la importación.
Implementa múltiples estrategias de detección y resolución automática.

CARACTERÍSTICAS:
- Verificación contra base de datos Koha existente
- Detección por ISBN, código de barras, título+autor
- Estrategias configurables: skip, update, merge, create_new
- Sistema de scoring para match fuzzy
- Generación automática de códigos únicos
- Prevención en tiempo real durante importación

Autor: Sistema Automatizado UNA
Versión: 1.0
Fecha: 2025-10-16
"""

import subprocess
import re
from typing import Dict, List, Optional, Tuple
from dataclasses import dataclass
from enum import Enum


class DuplicateStrategy(Enum):
    """Estrategias para manejar duplicados"""
    SKIP = "skip"                    # Saltar el registro duplicado
    UPDATE = "update"                # Actualizar registro existente
    MERGE = "merge"                  # Fusionar datos
    CREATE_NEW = "create_new"        # Crear nuevo con sufijo
    ASK = "ask"                      # Preguntar al usuario


@dataclass
class DuplicateMatch:
    """Información de un duplicado detectado"""
    biblionumber: Optional[int]
    match_type: str  # 'isbn', 'barcode', 'title_author', 'exact'
    confidence: float  # 0.0 - 1.0
    existing_title: str
    existing_author: str
    existing_barcode: str


class DetectorDuplicados:
    """Detector de duplicados en Koha"""

    def __init__(self, instancia_koha: str = "koha-cnc", estrategia: DuplicateStrategy = DuplicateStrategy.UPDATE):
        self.instancia = instancia_koha
        self.estrategia = estrategia
        self.cache_codigos = set()
        self.cache_isbns = set()
        self.stats = {
            'duplicados_detectados': 0,
            'duplicados_resueltos': 0,
            'nuevos_creados': 0
        }

    def query_koha(self, query: str) -> str:
        """Ejecuta query SQL en Koha"""
        comando = f'sudo koha-mysql {self.instancia} -e "{query}"'
        try:
            resultado = subprocess.run(
                comando,
                shell=True,
                capture_output=True,
                text=True,
                timeout=30
            )
            if resultado.returncode == 0:
                return resultado.stdout.strip()
            return ""
        except Exception:
            return ""

    def cargar_codigos_existentes(self, biblioteca_cod: str):
        """Pre-carga códigos de barras existentes en memoria"""
        query = f"""
            SELECT barcode FROM items
            WHERE homebranch = '{biblioteca_cod}'
            AND barcode IS NOT NULL
        """

        resultado = self.query_koha(query)
        if resultado:
            lineas = resultado.split('\n')[1:]  # Skip header
            self.cache_codigos = set(codigo.strip() for codigo in lineas if codigo.strip())

        print(f"  Cache cargado: {len(self.cache_codigos)} códigos de barras existentes")

    def cargar_isbns_existentes(self):
        """Pre-carga ISBNs existentes"""
        query = """
            SELECT DISTINCT isbn FROM biblioitems
            WHERE isbn IS NOT NULL AND isbn != ''
        """

        resultado = self.query_koha(query)
        if resultado:
            lineas = resultado.split('\n')[1:]
            self.cache_isbns = set(isbn.strip() for isbn in lineas if isbn.strip())

        print(f"  Cache cargado: {len(self.cache_isbns)} ISBNs existentes")

    def buscar_por_codigo_barras(self, barcode: str) -> Optional[DuplicateMatch]:
        """Busca duplicado por código de barras"""
        if not barcode:
            return None

        # Verificar en cache primero
        if barcode in self.cache_codigos:
            query = f"""
                SELECT
                    b.biblionumber,
                    b.title,
                    b.author,
                    i.barcode
                FROM biblio b
                JOIN items i ON b.biblionumber = i.biblionumber
                WHERE i.barcode = '{barcode}'
                LIMIT 1
            """

            resultado = self.query_koha(query)
            if resultado:
                lineas = resultado.split('\n')
                if len(lineas) > 1:
                    datos = lineas[1].split('\t')
                    if len(datos) >= 4:
                        return DuplicateMatch(
                            biblionumber=int(datos[0]),
                            match_type='barcode',
                            confidence=1.0,
                            existing_title=datos[1],
                            existing_author=datos[2],
                            existing_barcode=datos[3]
                        )

        return None

    def buscar_por_isbn(self, isbn: str) -> Optional[DuplicateMatch]:
        """Busca duplicado por ISBN"""
        if not isbn or isbn not in self.cache_isbns:
            return None

        # Limpiar ISBN
        isbn_limpio = re.sub(r'[^0-9X]', '', isbn.upper())

        query = f"""
            SELECT
                b.biblionumber,
                b.title,
                b.author,
                bi.isbn
            FROM biblio b
            JOIN biblioitems bi ON b.biblionumber = bi.biblionumber
            WHERE REPLACE(REPLACE(bi.isbn, '-', ''), ' ', '') = '{isbn_limpio}'
            LIMIT 1
        """

        resultado = self.query_koha(query)
        if resultado:
            lineas = resultado.split('\n')
            if len(lineas) > 1:
                datos = lineas[1].split('\t')
                if len(datos) >= 4:
                    return DuplicateMatch(
                        biblionumber=int(datos[0]),
                        match_type='isbn',
                        confidence=0.95,
                        existing_title=datos[1],
                        existing_author=datos[2],
                        existing_barcode=""
                    )

        return None

    def buscar_por_titulo_autor(self, titulo: str, autor: str) -> Optional[DuplicateMatch]:
        """Busca duplicado por título + autor (fuzzy match)"""
        if not titulo:
            return None

        # Normalizar título para búsqueda
        titulo_norm = re.sub(r'[^\w\s]', '', titulo.lower())[:50]

        # Query con LIKE para fuzzy matching
        query = f"""
            SELECT
                b.biblionumber,
                b.title,
                b.author
            FROM biblio b
            WHERE LOWER(b.title) LIKE '%{titulo_norm}%'
            LIMIT 5
        """

        resultado = self.query_koha(query)
        if resultado:
            lineas = resultado.split('\n')
            if len(lineas) > 1:
                # Calcular similitud con cada resultado
                for i in range(1, len(lineas)):
                    datos = lineas[i].split('\t')
                    if len(datos) >= 3:
                        titulo_existente = datos[1].lower()
                        autor_existente = datos[2].lower() if datos[2] else ""

                        # Scoring simple
                        score = 0.0
                        if titulo.lower() == titulo_existente:
                            score += 0.6
                        elif titulo_norm in titulo_existente:
                            score += 0.4

                        if autor and autor_existente:
                            if autor.lower() == autor_existente:
                                score += 0.4
                            elif autor.lower()[:10] in autor_existente:
                                score += 0.2

                        if score >= 0.7:  # Threshold de confianza
                            return DuplicateMatch(
                                biblionumber=int(datos[0]),
                                match_type='title_author',
                                confidence=score,
                                existing_title=datos[1],
                                existing_author=datos[2],
                                existing_barcode=""
                            )

        return None

    def detectar_duplicado(self, registro: Dict) -> Optional[DuplicateMatch]:
        """Detecta si un registro es duplicado usando múltiples estrategias"""

        # 1. Verificar por código de barras (más confiable)
        if registro.get('nroacceso'):
            match = self.buscar_por_codigo_barras(registro['nroacceso'])
            if match:
                return match

        # 2. Verificar por ISBN
        if registro.get('isbn_issn'):
            match = self.buscar_por_isbn(registro['isbn_issn'])
            if match:
                return match

        # 3. Verificar por título + autor
        if registro.get('titulo'):
            match = self.buscar_por_titulo_autor(
                registro['titulo'],
                registro.get('autor', '')
            )
            if match:
                return match

        return None

    def resolver_duplicado(self, registro: Dict, match: DuplicateMatch) -> Dict:
        """Resuelve un duplicado según la estrategia configurada"""

        self.stats['duplicados_detectados'] += 1

        if self.estrategia == DuplicateStrategy.SKIP:
            print(f"    [SKIP] Duplicado detectado, saltando registro")
            return {'accion': 'skip', 'razon': f"Duplicado por {match.match_type}"}

        elif self.estrategia == DuplicateStrategy.UPDATE:
            print(f"    [UPDATE] Actualizando registro existente (biblio: {match.biblionumber})")
            self.stats['duplicados_resueltos'] += 1
            return {'accion': 'update', 'biblionumber': match.biblionumber}

        elif self.estrategia == DuplicateStrategy.CREATE_NEW:
            # Generar nuevo código de barras único
            nuevo_codigo = self.generar_codigo_unico(registro['nroacceso'])
            registro['nroacceso'] = nuevo_codigo
            print(f"    [CREATE_NEW] Creando con nuevo código: {nuevo_codigo}")
            self.stats['nuevos_creados'] += 1
            return {'accion': 'create', 'nuevo_codigo': nuevo_codigo}

        elif self.estrategia == DuplicateStrategy.MERGE:
            # Fusionar datos (tomar los mejores de cada uno)
            print(f"    [MERGE] Fusionando datos con registro existente")
            self.stats['duplicados_resueltos'] += 1
            return {'accion': 'merge', 'biblionumber': match.biblionumber}

        else:  # ASK
            print(f"    [?] Duplicado detectado (confianza: {match.confidence:.0%})")
            print(f"        Existente: '{match.existing_title}' por {match.existing_author}")
            print(f"        Nuevo: '{registro.get('titulo')}' por {registro.get('autor')}")
            # En modo automático, por defecto UPDATE
            return {'accion': 'update', 'biblionumber': match.biblionumber}

    def generar_codigo_unico(self, codigo_base: str) -> str:
        """Genera un código de barras único"""
        if not codigo_base:
            import random
            codigo_base = f"AUTO{random.randint(100000, 999999)}"

        # Intentar con sufijos
        for i in range(1, 1000):
            nuevo_codigo = f"{codigo_base}-{i:03d}"
            if nuevo_codigo not in self.cache_codigos:
                self.cache_codigos.add(nuevo_codigo)
                return nuevo_codigo

        # Si llegamos aquí, usar timestamp
        import time
        ts_code = f"{codigo_base}-{int(time.time())}"
        self.cache_codigos.add(ts_code)
        return ts_code

    def pre_procesar_csv(self, csv_path: str, output_path: str) -> Tuple[int, int]:
        """Pre-procesa CSV para eliminar/resolver duplicados internos"""
        import pandas as pd

        print(f"\nPre-procesando CSV para detectar duplicados internos...")

        df = pd.read_csv(csv_path, sep=';', encoding='utf-8', low_memory=False)

        registros_originales = len(df)
        print(f"  Registros originales: {registros_originales}")

        # 1. Resolver duplicados de código de acceso
        if 'nroacceso' in df.columns:
            codigos_duplicados = df[df.duplicated(subset=['nroacceso'], keep=False)]
            if len(codigos_duplicados) > 0:
                print(f"  ⚠ Detectados {len(codigos_duplicados)} códigos duplicados, renumerando...")

                # Renumerar códigos duplicados
                codigo_bib = df['codbiblio'].iloc[0] if 'codbiblio' in df.columns else 'GEN'

                duplicados_grupos = df[df.duplicated(subset=['nroacceso'], keep='first')].index

                contador = 1
                for idx in duplicados_grupos:
                    nuevo_codigo = f"{codigo_bib}-{contador:07d}"
                    while nuevo_codigo in df['nroacceso'].values:
                        contador += 1
                        nuevo_codigo = f"{codigo_bib}-{contador:07d}"

                    df.at[idx, 'nroacceso'] = nuevo_codigo
                    contador += 1

                print(f"  ✓ Códigos renumerados exitosamente")

        # 2. Eliminar duplicados exactos de título+autor+año
        columnas_dup = ['titulo', 'autor', 'publicacion']
        columnas_existentes = [col for col in columnas_dup if col in df.columns]

        if len(columnas_existentes) >= 2:
            antes = len(df)
            df = df.drop_duplicates(subset=columnas_existentes, keep='first')
            despues = len(df)

            if antes > despues:
                print(f"  ✓ Eliminados {antes - despues} duplicados exactos")

        # 3. Guardar CSV limpio
        df.to_csv(output_path, index=False, sep=';', encoding='utf-8')

        registros_finales = len(df)
        registros_eliminados = registros_originales - registros_finales

        print(f"  Registros finales: {registros_finales}")
        print(f"  Duplicados eliminados: {registros_eliminados}")
        print(f"  ✓ CSV limpio guardado: {output_path}")

        return registros_originales, registros_finales

    def generar_reporte(self) -> str:
        """Genera reporte de duplicados detectados"""
        reporte = f"""
REPORTE DE DETECCIÓN DE DUPLICADOS
===================================

Duplicados detectados: {self.stats['duplicados_detectados']}
Duplicados resueltos: {self.stats['duplicados_resueltos']}
Nuevos creados (con código único): {self.stats['nuevos_creados']}

Estrategia utilizada: {self.estrategia.value}
"""
        return reporte


def ejemplo_uso():
    """Ejemplo de uso del detector"""
    print("Inicializando detector de duplicados...")

    detector = DetectorDuplicados(
        instancia_koha="koha-cnc",
        estrategia=DuplicateStrategy.UPDATE
    )

    # Pre-cargar caches
    detector.cargar_codigos_existentes("POL")
    detector.cargar_isbns_existentes()

    # Ejemplo de detección
    registro = {
        'titulo': 'Ultrasonidos',
        'autor': 'Cracknell, A.P.',
        'nroacceso': 'POL-0000001',
        'isbn_issn': '978-3-16-148410-0'
    }

    match = detector.detectar_duplicado(registro)

    if match:
        print(f"\n✗ DUPLICADO DETECTADO!")
        print(f"  Tipo de match: {match.match_type}")
        print(f"  Confianza: {match.confidence:.0%}")
        print(f"  Registro existente: {match.existing_title}")

        resolucion = detector.resolver_duplicado(registro, match)
        print(f"  Acción tomada: {resolucion['accion']}")
    else:
        print(f"\n✓ No es duplicado, se puede importar")

    # Reporte final
    print(detector.generar_reporte())


if __name__ == '__main__':
    ejemplo_uso()
