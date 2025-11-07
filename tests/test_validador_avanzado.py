#!/usr/bin/env python3
"""
Tests para el validador avanzado de datos.

Ejecutar con: python3 -m pytest tests/
o: python3 tests/test_validador_avanzado.py
"""

import sys
from pathlib import Path

# Agregar directorio padre al path para imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from validador_avanzado import ValidadorAvanzado


def test_isbn10_valido():
    """Test de ISBN-10 válido"""
    validador = ValidadorAvanzado()
    resultado = validador.validar_isbn("0-306-40615-2")

    assert resultado.valido == True
    assert resultado.puntaje == 100.0
    assert "ISBN-10 válido" in resultado.mensaje


def test_isbn13_valido():
    """Test de ISBN-13 válido"""
    validador = ValidadorAvanzado()
    resultado = validador.validar_isbn("978-0-306-40615-7")

    assert resultado.valido == True
    assert resultado.puntaje == 100.0
    assert "ISBN-13 válido" in resultado.mensaje


def test_isbn_invalido():
    """Test de ISBN inválido"""
    validador = ValidadorAvanzado()
    resultado = validador.validar_isbn("123-456-789")

    assert resultado.valido == False
    assert resultado.puntaje < 100.0
    assert resultado.sugerencia is not None


def test_isbn_vacio():
    """Test de ISBN vacío"""
    validador = ValidadorAvanzado()
    resultado = validador.validar_isbn("")

    assert resultado.valido == False
    assert "vacío" in resultado.mensaje.lower()


def test_issn_valido():
    """Test de ISSN válido"""
    validador = ValidadorAvanzado()
    resultado = validador.validar_issn("0378-5955")

    assert resultado.valido == True
    assert resultado.puntaje == 100.0


def test_issn_invalido():
    """Test de ISSN inválido"""
    validador = ValidadorAvanzado()
    resultado = validador.validar_issn("0378-5956")  # Checksum incorrecto

    assert resultado.valido == False
    assert "checksum" in resultado.mensaje.lower()


def test_similitud_textos():
    """Test de cálculo de similitud"""
    validador = ValidadorAvanzado()

    # Textos idénticos
    sim1 = validador.calcular_similitud("Cien años de soledad", "Cien años de soledad")
    assert sim1 == 1.0

    # Textos similares
    sim2 = validador.calcular_similitud("Cien años de soledad", "Cien anos de soledad")
    assert sim2 > 0.9

    # Textos diferentes
    sim3 = validador.calcular_similitud("Cien años de soledad", "Don Quijote")
    assert sim3 < 0.3


def test_validar_calidad_catalogacion():
    """Test de calidad de catalogación"""
    validador = ValidadorAvanzado()

    # Registro completo y bien formado
    registro_bueno = {
        'titulo': 'Cien años de soledad',
        'autor': 'Gabriel García Márquez',
        'editorial': 'Editorial Sudamericana',
        'publicacion': '1967',
        'isbn': '978-0-307-47472-8',
        'nroacceso': 'MED-001234'
    }
    puntaje1 = validador.validar_calidad_catalogacion(registro_bueno)
    assert puntaje1 >= 90.0

    # Registro incompleto
    registro_malo = {
        'titulo': 'Libro',
        'nroacceso': '123'
    }
    puntaje2 = validador.validar_calidad_catalogacion(registro_malo)
    assert puntaje2 < 70.0


def test_validar_registro_completo():
    """Test de validación completa de registro"""
    validador = ValidadorAvanzado()

    registro = {
        'titulo': 'Cien años de soledad',
        'autor': 'Gabriel García Márquez',
        'editorial': 'Editorial Sudamericana',
        'publicacion': '1967',
        'isbn': '978-0-307-47472-8',
        'nroacceso': 'MED-001234'
    }

    resultado = validador.validar_registro_completo(registro)

    assert resultado['valido'] == True
    assert resultado['puntaje_calidad'] >= 90.0
    assert len(resultado['errores']) == 0


def test_detectar_duplicado_probable():
    """Test de detección de duplicados"""
    validador = ValidadorAvanzado()

    registros_existentes = [
        {'titulo': 'Cien años de soledad', 'autor': 'Gabriel García Márquez'},
        {'titulo': 'Don Quijote de la Mancha', 'autor': 'Miguel de Cervantes'},
        {'titulo': 'La sombra del viento', 'autor': 'Carlos Ruiz Zafón'}
    ]

    # Buscar duplicado exacto
    duplicados = validador.detectar_duplicado_probable(
        titulo='Cien años de soledad',
        autor='Gabriel García Márquez',
        registros_existentes=registros_existentes,
        umbral_similitud=0.85
    )

    assert len(duplicados) > 0
    assert duplicados[0][1] >= 0.85  # Alta similitud

    # Buscar sin duplicados
    duplicados2 = validador.detectar_duplicado_probable(
        titulo='Libro totalmente nuevo',
        autor='Autor desconocido',
        registros_existentes=registros_existentes,
        umbral_similitud=0.85
    )

    assert len(duplicados2) == 0


# ════════════════════════════════════════════════════════════════════════════
# Ejecutar tests si se llama directamente
# ════════════════════════════════════════════════════════════════════════════

if __name__ == '__main__':
    print("═" * 70)
    print("EJECUTANDO TESTS DEL VALIDADOR AVANZADO")
    print("═" * 70 + "\n")

    tests = [
        ("test_isbn10_valido", test_isbn10_valido),
        ("test_isbn13_valido", test_isbn13_valido),
        ("test_isbn_invalido", test_isbn_invalido),
        ("test_isbn_vacio", test_isbn_vacio),
        ("test_issn_valido", test_issn_valido),
        ("test_issn_invalido", test_issn_invalido),
        ("test_similitud_textos", test_similitud_textos),
        ("test_validar_calidad_catalogacion", test_validar_calidad_catalogacion),
        ("test_validar_registro_completo", test_validar_registro_completo),
        ("test_detectar_duplicado_probable", test_detectar_duplicado_probable)
    ]

    exitosos = 0
    fallidos = 0

    for nombre, test_func in tests:
        try:
            test_func()
            print(f"✓ {nombre}")
            exitosos += 1
        except AssertionError as e:
            print(f"✗ {nombre}: {e}")
            fallidos += 1
        except Exception as e:
            print(f"✗ {nombre}: ERROR - {e}")
            fallidos += 1

    print("\n" + "═" * 70)
    print(f"RESULTADO: {exitosos} exitosos, {fallidos} fallidos")
    print("═" * 70)

    sys.exit(0 if fallidos == 0 else 1)
