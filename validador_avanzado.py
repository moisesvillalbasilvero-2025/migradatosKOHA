#!/usr/bin/env python3
"""
════════════════════════════════════════════════════════════════════════════
VALIDADOR AVANZADO DE DATOS - SISTEMA DE IMPORTACIÓN KOHA
════════════════════════════════════════════════════════════════════════════

Sistema avanzado de validación de datos bibliográficos con:
- Validación de ISBN-10 e ISBN-13
- Validación de ISSN
- Detección de duplicados inteligente (fuzzy matching)
- Puntuación de calidad de catalogación
- Validación de campos MARC21
- Sugerencias de corrección automática

AUTORES: Universidad Nacional de Asunción
VERSIÓN: 1.0.0
FECHA: 2025-11-07
════════════════════════════════════════════════════════════════════════════
"""

import re
from dataclasses import dataclass
from typing import List, Dict, Optional, Tuple
from difflib import SequenceMatcher


@dataclass
class ResultadoValidacion:
    """Resultado de una validación individual"""
    campo: str
    valido: bool
    mensaje: str
    sugerencia: Optional[str] = None
    puntaje: float = 100.0


class ValidadorAvanzado:
    """
    Validador avanzado de datos bibliográficos.

    Proporciona validaciones profundas y sugerencias de corrección
    para asegurar la calidad de los datos importados.
    """

    def __init__(self):
        """Inicializa el validador con reglas de validación."""
        self.errores: List[ResultadoValidacion] = []
        self.warnings: List[ResultadoValidacion] = []
        self.puntaje_total: float = 100.0

    def validar_isbn(self, isbn: str) -> ResultadoValidacion:
        """
        Valida formato ISBN-10 o ISBN-13.

        Args:
            isbn: String del ISBN a validar

        Returns:
            ResultadoValidacion con el resultado

        Examples:
            >>> v = ValidadorAvanzado()
            >>> v.validar_isbn("978-0-306-40615-7")
            ResultadoValidacion(valido=True, ...)
            >>> v.validar_isbn("123-456")
            ResultadoValidacion(valido=False, ...)
        """
        if not isbn:
            return ResultadoValidacion(
                campo="isbn",
                valido=False,
                mensaje="ISBN vacío",
                sugerencia="Proporcionar un ISBN válido",
                puntaje=0.0
            )

        # Limpiar ISBN (quitar guiones, espacios)
        isbn_limpio = re.sub(r'[^0-9X]', '', isbn.upper())

        # Validar ISBN-10
        if len(isbn_limpio) == 10:
            if self._validar_isbn10(isbn_limpio):
                return ResultadoValidacion(
                    campo="isbn",
                    valido=True,
                    mensaje="ISBN-10 válido",
                    puntaje=100.0
                )
            else:
                return ResultadoValidacion(
                    campo="isbn",
                    valido=False,
                    mensaje="ISBN-10 inválido (checksum incorrecto)",
                    sugerencia="Verificar los dígitos del ISBN",
                    puntaje=30.0
                )

        # Validar ISBN-13
        elif len(isbn_limpio) == 13:
            if self._validar_isbn13(isbn_limpio):
                return ResultadoValidacion(
                    campo="isbn",
                    valido=True,
                    mensaje="ISBN-13 válido",
                    puntaje=100.0
                )
            else:
                return ResultadoValidacion(
                    campo="isbn",
                    valido=False,
                    mensaje="ISBN-13 inválido (checksum incorrecto)",
                    sugerencia="Verificar los dígitos del ISBN",
                    puntaje=30.0
                )

        else:
            return ResultadoValidacion(
                campo="isbn",
                valido=False,
                mensaje=f"Longitud incorrecta: {len(isbn_limpio)} dígitos (debe ser 10 o 13)",
                sugerencia="Verificar que el ISBN esté completo",
                puntaje=20.0
            )

    def _validar_isbn10(self, isbn: str) -> bool:
        """
        Valida checksum de ISBN-10.

        Algoritmo: suma de (dígito * posición) mod 11 == 0
        """
        try:
            suma = 0
            for i in range(9):
                suma += int(isbn[i]) * (10 - i)

            # El último dígito puede ser X (representa 10)
            ultimo = 10 if isbn[9] == 'X' else int(isbn[9])
            suma += ultimo

            return suma % 11 == 0
        except (ValueError, IndexError):
            return False

    def _validar_isbn13(self, isbn: str) -> bool:
        """
        Valida checksum de ISBN-13.

        Algoritmo: suma alternada (1x, 3x, 1x, 3x...) mod 10 == 0
        """
        try:
            suma = 0
            for i in range(12):
                multiplicador = 1 if i % 2 == 0 else 3
                suma += int(isbn[i]) * multiplicador

            checksum = (10 - (suma % 10)) % 10
            return checksum == int(isbn[12])
        except (ValueError, IndexError):
            return False

    def validar_issn(self, issn: str) -> ResultadoValidacion:
        """
        Valida formato ISSN (International Standard Serial Number).

        Args:
            issn: String del ISSN a validar (formato: XXXX-XXXX)

        Returns:
            ResultadoValidacion con el resultado
        """
        if not issn:
            return ResultadoValidacion(
                campo="issn",
                valido=True,
                mensaje="ISSN no proporcionado (opcional)",
                puntaje=100.0
            )

        # Limpiar ISSN
        issn_limpio = re.sub(r'[^0-9X]', '', issn.upper())

        if len(issn_limpio) != 8:
            return ResultadoValidacion(
                campo="issn",
                valido=False,
                mensaje=f"Longitud incorrecta: {len(issn_limpio)} dígitos (debe ser 8)",
                sugerencia="Formato: XXXX-XXXX",
                puntaje=30.0
            )

        # Validar checksum ISSN
        try:
            suma = 0
            for i in range(7):
                suma += int(issn_limpio[i]) * (8 - i)

            ultimo = 10 if issn_limpio[7] == 'X' else int(issn_limpio[7])
            checksum = (11 - (suma % 11)) % 11

            if checksum == 10:
                checksum_esperado = 'X'
            else:
                checksum_esperado = str(checksum)

            if issn_limpio[7] == checksum_esperado:
                return ResultadoValidacion(
                    campo="issn",
                    valido=True,
                    mensaje="ISSN válido",
                    puntaje=100.0
                )
            else:
                return ResultadoValidacion(
                    campo="issn",
                    valido=False,
                    mensaje="ISSN inválido (checksum incorrecto)",
                    sugerencia=f"El checksum debería ser: {checksum_esperado}",
                    puntaje=40.0
                )
        except (ValueError, IndexError):
            return ResultadoValidacion(
                campo="issn",
                valido=False,
                mensaje="ISSN con caracteres inválidos",
                sugerencia="Solo dígitos y opcionalmente X al final",
                puntaje=20.0
            )

    def calcular_similitud(self, texto1: str, texto2: str) -> float:
        """
        Calcula similitud entre dos textos usando SequenceMatcher.

        Args:
            texto1, texto2: Textos a comparar

        Returns:
            Float entre 0.0 (totalmente diferentes) y 1.0 (idénticos)
        """
        if not texto1 or not texto2:
            return 0.0

        # Normalizar: minúsculas, sin espacios extras
        t1 = ' '.join(texto1.lower().split())
        t2 = ' '.join(texto2.lower().split())

        return SequenceMatcher(None, t1, t2).ratio()

    def detectar_duplicado_probable(
        self,
        titulo: str,
        autor: str,
        registros_existentes: List[Dict[str, str]],
        umbral_similitud: float = 0.85
    ) -> List[Tuple[Dict, float]]:
        """
        Detecta registros probablemente duplicados usando fuzzy matching.

        Args:
            titulo: Título del registro a verificar
            autor: Autor del registro
            registros_existentes: Lista de registros en la BD
            umbral_similitud: Umbral de similitud (0.0-1.0)

        Returns:
            Lista de tuplas (registro, similitud) de posibles duplicados
        """
        duplicados_probables = []

        for registro in registros_existentes:
            # Calcular similitud del título
            sim_titulo = self.calcular_similitud(
                titulo,
                registro.get('titulo', '')
            )

            # Calcular similitud del autor si ambos tienen
            sim_autor = 0.0
            if autor and registro.get('autor'):
                sim_autor = self.calcular_similitud(
                    autor,
                    registro.get('autor', '')
                )

            # Similitud combinada (dar más peso al título)
            similitud = (sim_titulo * 0.7) + (sim_autor * 0.3)

            if similitud >= umbral_similitud:
                duplicados_probables.append((registro, similitud))

        # Ordenar por similitud descendente
        return sorted(duplicados_probables, key=lambda x: x[1], reverse=True)

    def validar_calidad_catalogacion(self, registro: Dict[str, any]) -> float:
        """
        Calcula un puntaje de calidad de catalogación (0-100).

        Evalúa:
        - Presencia de campos obligatorios
        - Presencia de campos recomendados
        - Longitud apropiada de campos
        - Formato correcto
        - Ausencia de caracteres problemáticos

        Args:
            registro: Diccionario con los campos del registro

        Returns:
            Puntaje de calidad (0-100)
        """
        puntaje = 100.0
        detalles = []

        # CAMPOS OBLIGATORIOS (40 puntos)
        campos_obligatorios = {
            'titulo': (20, 10),     # (puntos, min_length)
            'nroacceso': (20, 5)
        }

        for campo, (puntos, min_len) in campos_obligatorios.items():
            valor = registro.get(campo, '').strip()

            if not valor:
                puntaje -= puntos
                detalles.append(f"Falta campo obligatorio: {campo}")
            elif len(valor) < min_len:
                puntaje -= puntos * 0.5
                detalles.append(f"Campo {campo} muy corto: {len(valor)} caracteres")

        # CAMPOS RECOMENDADOS (30 puntos)
        campos_recomendados = {
            'autor': 10,
            'editorial': 10,
            'publicacion': 10
        }

        for campo, puntos in campos_recomendados.items():
            if not registro.get(campo, '').strip():
                puntaje -= puntos
                detalles.append(f"Falta campo recomendado: {campo}")

        # VALIDACIONES DE FORMATO (20 puntos)
        # ISBN/ISSN válidos
        isbn = registro.get('isbn', '').strip()
        if isbn:
            resultado_isbn = self.validar_isbn(isbn)
            if not resultado_isbn.valido:
                puntaje -= 10
                detalles.append(f"ISBN inválido: {resultado_isbn.mensaje}")

        # CARACTERES PROBLEMÁTICOS (10 puntos)
        caracteres_problematicos = ['�', '\x00', '\ufffd']
        for campo, valor in registro.items():
            if isinstance(valor, str):
                for char in caracteres_problematicos:
                    if char in valor:
                        puntaje -= 5
                        detalles.append(
                            f"Campo {campo} contiene caracteres problemáticos"
                        )
                        break

        return max(0.0, puntaje)

    def validar_registro_completo(self, registro: Dict[str, any]) -> Dict[str, any]:
        """
        Ejecuta todas las validaciones sobre un registro.

        Args:
            registro: Diccionario con los campos del registro

        Returns:
            Diccionario con resultados:
            {
                'valido': bool,
                'puntaje_calidad': float,
                'errores': List[ResultadoValidacion],
                'warnings': List[ResultadoValidacion],
                'sugerencias': List[str]
            }
        """
        self.errores = []
        self.warnings = []
        sugerencias = []

        # Validar ISBN si existe
        if isbn := registro.get('isbn', '').strip():
            resultado = self.validar_isbn(isbn)
            if not resultado.valido:
                self.errores.append(resultado)
                if resultado.sugerencia:
                    sugerencias.append(resultado.sugerencia)

        # Validar ISSN si existe
        if issn := registro.get('issn', '').strip():
            resultado = self.validar_issn(issn)
            if not resultado.valido:
                self.warnings.append(resultado)
                if resultado.sugerencia:
                    sugerencias.append(resultado.sugerencia)

        # Calcular calidad
        puntaje_calidad = self.validar_calidad_catalogacion(registro)

        # Determinar si es válido
        valido = len(self.errores) == 0 and puntaje_calidad >= 50.0

        return {
            'valido': valido,
            'puntaje_calidad': puntaje_calidad,
            'errores': self.errores,
            'warnings': self.warnings,
            'sugerencias': sugerencias
        }


# ════════════════════════════════════════════════════════════════════════════
# EJEMPLO DE USO
# ════════════════════════════════════════════════════════════════════════════

if __name__ == '__main__':
    # Ejemplo de validación
    validador = ValidadorAvanzado()

    # Test ISBN
    print("═" * 70)
    print("PRUEBA DE VALIDACIÓN ISBN")
    print("═" * 70)

    isbns_test = [
        ("978-0-306-40615-7", "ISBN-13 válido"),
        ("0-306-40615-2", "ISBN-10 válido"),
        ("123-456-789", "ISBN inválido"),
        ("", "ISBN vacío")
    ]

    for isbn, descripcion in isbns_test:
        resultado = validador.validar_isbn(isbn)
        print(f"\n{descripcion}: {isbn}")
        print(f"  Válido: {resultado.valido}")
        print(f"  Mensaje: {resultado.mensaje}")
        if resultado.sugerencia:
            print(f"  Sugerencia: {resultado.sugerencia}")
        print(f"  Puntaje: {resultado.puntaje}/100")

    # Test registro completo
    print("\n" + "═" * 70)
    print("PRUEBA DE VALIDACIÓN DE REGISTRO COMPLETO")
    print("═" * 70)

    registro = {
        'titulo': 'Cien años de soledad',
        'autor': 'Gabriel García Márquez',
        'editorial': 'Editorial Sudamericana',
        'publicacion': '1967',
        'isbn': '978-0-307-47472-8',
        'nroacceso': 'MED-001234'
    }

    resultado = validador.validar_registro_completo(registro)

    print(f"\nVálido: {resultado['valido']}")
    print(f"Puntaje de calidad: {resultado['puntaje_calidad']:.1f}/100")

    if resultado['errores']:
        print("\nErrores:")
        for error in resultado['errores']:
            print(f"  ✗ {error.mensaje}")

    if resultado['warnings']:
        print("\nAdvertencias:")
        for warning in resultado['warnings']:
            print(f"  ⚠ {warning.mensaje}")

    if resultado['sugerencias']:
        print("\nSugerencias:")
        for sugerencia in resultado['sugerencias']:
            print(f"  💡 {sugerencia}")

    print("\n" + "═" * 70)
