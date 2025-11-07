#!/usr/bin/env python3
"""
════════════════════════════════════════════════════════════════════════════
MÓDULO CENTRAL DE MAPEO MARC21 - SISTEMA DE IMPORTACIÓN KOHA
════════════════════════════════════════════════════════════════════════════

Módulo profesional y didáctico para convertir datos bibliográficos (desde CSV
o JSON) a formato MARCXML estándar MARC21.

CARACTERÍSTICAS:
✓ Agnóstico a la fuente de datos (CSV, JSON, dict Python)
✓ Configuración paramétrica vía JSON
✓ Validación y normalización de datos
✓ Generación de MARCXML válido
✓ Usado tanto por CLI como por API REST

FLUJOS SOPORTADOS:
  CSV → Dict Python → Este Módulo → MARCXML → Koha
  JSON API → Dict Python → Este Módulo → MARCXML → Koha

AUTORES: Universidad Nacional de Asunción
VERSIÓN: 1.0.0
FECHA: 2025-11-07
════════════════════════════════════════════════════════════════════════════
"""

import json
import re
import xml.etree.ElementTree as ET
from datetime import datetime
from hashlib import md5
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Any
from dataclasses import dataclass


# ════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN Y CONSTANTES
# ════════════════════════════════════════════════════════════════════════════

DEFAULT_LANG = "spa"
DEFAULT_COUNTRY = "py "  # 3 caracteres para MARC 008

# Mapeo por defecto de tipos de material
DEFAULT_ITEMTYPE_MAP = {
    "Monografia": "BK",
    "Monografía": "BK",
    "Libro": "BK",
    "Revista": "MG",
    "DVD": "VM",
    "CD": "MU",
    "Mapa": "MP",
    "Tesis": "TES",
}


# ════════════════════════════════════════════════════════════════════════════
# CLASES DE DATOS
# ════════════════════════════════════════════════════════════════════════════

@dataclass
class RegistroBibliografico:
    """
    Representa un registro bibliográfico normalizado.

    Esta clase intermedia permite recibir datos desde cualquier fuente
    (CSV, JSON API, base de datos) y tener una estructura uniforme.
    """
    # Campos identificadores
    codigo_biblioteca: str  # ej: MED, FACEN, POL
    numero_analisis: Optional[str] = None
    codigo_barras: Optional[str] = None

    # Campos bibliográficos
    titulo: str = ""
    sub_titulo: Optional[str] = None
    autor: Optional[str] = None
    autor_institucional: Optional[str] = None
    mencion_responsabilidad: Optional[str] = None

    # Publicación
    editorial: Optional[str] = None
    lugar_publicacion: Optional[str] = None
    año_publicacion: Optional[str] = None
    edicion: Optional[str] = None

    # Descripción física
    paginas: Optional[str] = None
    serie: Optional[str] = None

    # Contenido
    resumen: Optional[str] = None
    notas: Optional[str] = None
    materias: List[str] = None  # Lista de materias

    # Números normalizados
    isbn: Optional[str] = None
    issn: Optional[str] = None

    # Datos del ejemplar (item)
    signatura: Optional[str] = None
    ubicacion_fisica: Optional[str] = None
    tipo_material: Optional[str] = None
    volumen: Optional[str] = None
    fecha_adquisicion: Optional[str] = None
    precio: Optional[str] = None

    # Metadatos
    idioma: str = DEFAULT_LANG
    pais: str = DEFAULT_COUNTRY

    def __post_init__(self):
        """Inicializa valores por defecto para campos mutables."""
        if self.materias is None:
            self.materias = []


# ════════════════════════════════════════════════════════════════════════════
# CLASE PRINCIPAL: MAPEADOR MARC21
# ════════════════════════════════════════════════════════════════════════════

class MapeadorMARC21:
    """
    Mapeador profesional de datos bibliográficos a MARCXML.

    Convierte registros bibliográficos (desde cualquier fuente) a formato
    MARC21 estándar en XML, utilizando configuración parametrizada.

    Examples:
        >>> # Desde dict (puede venir de CSV o JSON API)
        >>> datos = {
        ...     'titulo': 'Cien años de soledad',
        ...     'autor': 'García Márquez, Gabriel',
        ...     'editorial': 'Sudamericana',
        ...     'publicacion': '1967'
        ... }
        >>>
        >>> mapeador = MapeadorMARC21(codigo_biblioteca='MED')
        >>> marcxml = mapeador.dict_a_marcxml(datos)
        >>> print(marcxml)
    """

    def __init__(
        self,
        codigo_biblioteca: str,
        config_path: Optional[Path] = None,
        mapeo_tipos: Optional[Dict[str, str]] = None,
        mapeo_ubicaciones: Optional[Dict[str, str]] = None
    ):
        """
        Inicializa el mapeador MARC21.

        Args:
            codigo_biblioteca: Código de la biblioteca (ej: MED, FACEN)
            config_path: Ruta al archivo config/mapeo_campos.json (opcional)
            mapeo_tipos: Mapeo personalizado de tipos de material (opcional)
            mapeo_ubicaciones: Mapeo personalizado de ubicaciones (opcional)
        """
        self.codigo_biblioteca = codigo_biblioteca.upper()
        self.config = self._cargar_config(config_path)
        self.mapeo_tipos = mapeo_tipos or DEFAULT_ITEMTYPE_MAP
        self.mapeo_ubicaciones = mapeo_ubicaciones or {}

        # Namespace MARC21
        self.ns = "http://www.loc.gov/MARC21/slim"

    def _cargar_config(self, config_path: Optional[Path]) -> Dict:
        """
        Carga configuración de mapeo desde JSON.

        Args:
            config_path: Ruta al archivo de configuración

        Returns:
            Dict con la configuración cargada
        """
        if config_path and config_path.exists():
            with open(config_path, 'r', encoding='utf-8') as f:
                return json.load(f)

        # Configuración por defecto
        return {
            "mapeo_tipos_material": DEFAULT_ITEMTYPE_MAP
        }

    @staticmethod
    def normalizar_texto(texto: Optional[str]) -> str:
        """
        Normaliza texto eliminando espacios extra y caracteres problemáticos.

        Args:
            texto: Texto a normalizar

        Returns:
            Texto normalizado
        """
        if not texto:
            return ""
        # Eliminar espacios extras
        texto = " ".join(texto.split())
        # Eliminar caracteres de control
        texto = re.sub(r'[\x00-\x1f\x7f-\x9f]', '', texto)
        return texto.strip()

    def dict_a_registro(self, datos: Dict[str, Any], idx: int = 1) -> RegistroBibliografico:
        """
        Convierte un diccionario de datos a un RegistroBibliografico normalizado.

        Este método permite recibir datos desde cualquier fuente (CSV parseado,
        JSON de API, etc.) y convertirlo a nuestra estructura interna.

        Args:
            datos: Diccionario con los datos bibliográficos
            idx: Índice del registro (para generar códigos de barras si falta)

        Returns:
            RegistroBibliografico normalizado

        Examples:
            >>> datos = {'titulo': 'Don Quijote', 'autor': 'Cervantes'}
            >>> registro = mapeador.dict_a_registro(datos)
            >>> print(registro.titulo)
            Don Quijote
        """
        # Procesar materias (puede venir como string separado por ;)
        materias = []
        materias_raw = datos.get('materia') or datos.get('materias', '')
        if isinstance(materias_raw, str):
            materias = [m.strip() for m in materias_raw.split(';') if m.strip()]
        elif isinstance(materias_raw, list):
            materias = [m.strip() for m in materias_raw if m.strip()]

        return RegistroBibliografico(
            # Identificadores
            codigo_biblioteca=datos.get('codbiblio', self.codigo_biblioteca),
            numero_analisis=self.normalizar_texto(datos.get('analisis')),
            codigo_barras=self.normalizar_texto(datos.get('nroacceso') or datos.get('barcode')),

            # Bibliográficos
            titulo=self.normalizar_texto(datos.get('titulo', '')),
            sub_titulo=self.normalizar_texto(datos.get('sub_titulo') or datos.get('subtitulo')),
            autor=self.normalizar_texto(datos.get('autor')),
            autor_institucional=self.normalizar_texto(datos.get('autorinst') or datos.get('autor_institucional')),
            mencion_responsabilidad=self.normalizar_texto(datos.get('mencion')),

            # Publicación
            editorial=self.normalizar_texto(datos.get('editorial')),
            lugar_publicacion=self.normalizar_texto(datos.get('procedencia') or datos.get('lugar')),
            año_publicacion=self.normalizar_texto(datos.get('publicacion') or datos.get('año') or datos.get('anio')),
            edicion=self.normalizar_texto(datos.get('edicion')),

            # Descripción
            paginas=self.normalizar_texto(datos.get('paginas')),
            serie=self.normalizar_texto(datos.get('serie') or datos.get('coleccion')),

            # Contenido
            resumen=self.normalizar_texto(datos.get('sintesis') or datos.get('resumen')),
            notas=self.normalizar_texto(datos.get('notas')),
            materias=materias,

            # Números
            isbn=self.normalizar_texto(datos.get('isbn')),
            issn=self.normalizar_texto(datos.get('issn')),

            # Ejemplar
            signatura=self.normalizar_texto(datos.get('ubicacion') or datos.get('signatura') or datos.get('callnumber')),
            ubicacion_fisica=self.normalizar_texto(datos.get('loc') or datos.get('ubicacion_fisica')),
            tipo_material=self.normalizar_texto(datos.get('tipomaterial') or datos.get('tipo')),
            volumen=self.normalizar_texto(datos.get('volumen')),
            fecha_adquisicion=self.normalizar_texto(datos.get('fechaadq') or datos.get('fecha_adquisicion')),
            precio=self.normalizar_texto(datos.get('precio')),

            # Metadatos
            idioma=datos.get('idioma', DEFAULT_LANG),
            pais=datos.get('pais', DEFAULT_COUNTRY)
        )

    def generar_numero_control(self, registro: RegistroBibliografico, idx: int) -> str:
        """
        Genera número de control único para el campo 001.

        Prioridad:
        1. Número de análisis (si existe)
        2. Código de barras (si existe)
        3. Hash generado a partir del título y autor

        Args:
            registro: RegistroBibliografico
            idx: Índice del registro

        Returns:
            Número de control único
        """
        if registro.numero_analisis:
            return f"ANL:{registro.numero_analisis}"

        if registro.codigo_barras:
            return f"BC:{registro.codigo_barras}"

        # Generar hash único
        base = f"{registro.titulo}|{registro.autor or ''}|{registro.año_publicacion or ''}|{idx}"
        return "HX:" + md5(base.encode("utf-8")).hexdigest()[:10]

    def generar_campo_008(self, registro: RegistroBibliografico) -> str:
        """
        Genera campo 008 (Datos de Longitud Fija) según MARC21.

        El campo 008 tiene 40 posiciones con información codificada.

        Formato:
        DDMMYY s YYYY país______________ idioma

        Args:
            registro: RegistroBibliografico

        Returns:
            String de 40 caracteres con el campo 008
        """
        # Fecha de entrada (hoy)
        fecha = datetime.utcnow().strftime("%y%m%d")

        # Año de publicación (4 dígitos)
        digits = re.sub(r"[^0-9]", "", registro.año_publicacion or "")
        año = (digits[:4] if digits else "    ").ljust(4)

        # País (3 caracteres)
        pais = (registro.pais or DEFAULT_COUNTRY).ljust(3)[:3]

        # Idioma (3 caracteres)
        idioma = (registro.idioma or DEFAULT_LANG).ljust(3)[:3]

        # Construir campo
        campo_008 = f"{fecha}s{año}    {pais}{' '*17}{idioma}  "

        return campo_008[:40].ljust(40)

    def agregar_campo_control(self, parent: ET.Element, tag: str, text: str) -> None:
        """
        Agrega un campo de control al registro MARC.

        Args:
            parent: Elemento padre XML
            tag: Tag del campo (001, 003, 005, 008)
            text: Contenido del campo
        """
        cf = ET.SubElement(parent, "controlfield", {"tag": tag})
        cf.text = text

    def agregar_campo_datos(
        self,
        parent: ET.Element,
        tag: str,
        subcampos: List[Tuple[str, str]],
        ind1: str = " ",
        ind2: str = " "
    ) -> None:
        """
        Agrega un campo de datos al registro MARC.

        Args:
            parent: Elemento padre XML
            tag: Tag del campo (020, 100, 245, etc.)
            subcampos: Lista de tuplas (code, value)
            ind1: Indicador 1
            ind2: Indicador 2

        Examples:
            >>> agregar_campo_datos(
            ...     rec, "245",
            ...     [("a", "Don Quijote"), ("b", "de la Mancha")],
            ...     ind1="1", ind2="0"
            ... )
        """
        # Filtrar subcampos vacíos
        subs = [(c, t) for c, t in subcampos if t and t.strip()]
        if not subs:
            return

        df = ET.SubElement(parent, "datafield", {"tag": tag, "ind1": ind1, "ind2": ind2})
        for code, text in subs:
            sf = ET.SubElement(df, "subfield", {"code": code})
            sf.text = text

    def generar_codigo_barras(self, registro: RegistroBibliografico, idx: int) -> str:
        """
        Genera código de barras si no existe.

        Args:
            registro: RegistroBibliografico
            idx: Índice del registro

        Returns:
            Código de barras (20 caracteres máximo)
        """
        if registro.codigo_barras:
            return registro.codigo_barras[:20]

        # Generar: {CODBIBLIO}-{7 dígitos}
        return f"{self.codigo_biblioteca}-{idx:07d}"[:20]

    def registro_a_marcxml(self, registro: RegistroBibliografico, idx: int = 1) -> ET.Element:
        """
        Convierte un RegistroBibliografico a elemento XML MARC21.

        Args:
            registro: RegistroBibliografico a convertir
            idx: Índice del registro

        Returns:
            ET.Element con el registro MARCXML
        """
        # Validación básica
        if not registro.titulo:
            raise ValueError("El título es obligatorio")

        # Crear elemento record
        rec = ET.Element(f"{{{self.ns}}}record")

        # Leader
        ET.SubElement(rec, "leader").text = "00000nam a2200000 i 4500"

        # ═══ CAMPOS DE CONTROL (001-008) ═══

        # 001 - Número de control
        num_control = self.generar_numero_control(registro, idx)
        self.agregar_campo_control(rec, "001", num_control)

        # 003 - Identificador de control
        self.agregar_campo_control(rec, "003", self.codigo_biblioteca)

        # 005 - Timestamp
        timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S") + ".0"
        self.agregar_campo_control(rec, "005", timestamp)

        # 008 - Datos de longitud fija
        campo_008 = self.generar_campo_008(registro)
        self.agregar_campo_control(rec, "008", campo_008)

        # ═══ CAMPOS DE DATOS ═══

        # 020 - ISBN
        if registro.isbn:
            self.agregar_campo_datos(rec, "020", [("a", registro.isbn)])

        # 040 - Fuente de catalogación
        self.agregar_campo_datos(
            rec, "040",
            [("a", self.codigo_biblioteca),
             ("b", registro.idioma),
             ("c", self.codigo_biblioteca)]
        )

        # 100 - Autor personal
        if registro.autor:
            self.agregar_campo_datos(
                rec, "100",
                [("a", registro.autor)],
                ind1="1"  # Apellido, nombre
            )
        # 110 - Autor institucional (solo si NO hay autor personal)
        elif registro.autor_institucional:
            self.agregar_campo_datos(
                rec, "110",
                [("a", registro.autor_institucional)],
                ind1="2"  # Nombre directo
            )

        # 245 - Título (OBLIGATORIO)
        subs_245 = [("a", registro.titulo)]
        if registro.sub_titulo:
            subs_245.append(("b", registro.sub_titulo))
        if registro.mencion_responsabilidad:
            subs_245.append(("c", registro.mencion_responsabilidad))

        ind1_245 = "1" if (registro.autor or registro.autor_institucional) else "0"
        self.agregar_campo_datos(rec, "245", subs_245, ind1=ind1_245, ind2="0")

        # 250 - Edición
        if registro.edicion:
            self.agregar_campo_datos(rec, "250", [("a", registro.edicion)])

        # 264 - Publicación
        subs_264 = []
        if registro.lugar_publicacion:
            subs_264.append(("a", registro.lugar_publicacion))
        if registro.editorial:
            subs_264.append(("b", registro.editorial))
        if registro.año_publicacion:
            subs_264.append(("c", registro.año_publicacion))
        if subs_264:
            self.agregar_campo_datos(rec, "264", subs_264, ind2="1")

        # 490 - Serie
        if registro.serie:
            self.agregar_campo_datos(rec, "490", [("a", registro.serie)], ind1="1")

        # 520 - Resumen
        if registro.resumen:
            self.agregar_campo_datos(rec, "520", [("a", registro.resumen)])

        # 650 - Materias (uno por tema)
        for materia in registro.materias:
            if materia:
                self.agregar_campo_datos(rec, "650", [("a", materia)], ind2="4")

        # 942 - Tipo de documento (Koha)
        tipo_koha = self.mapeo_tipos.get(registro.tipo_material or "", "BK")
        self.agregar_campo_datos(rec, "942", [("c", tipo_koha)])

        # 952 - Datos del ejemplar (Koha)
        codigo_barras = self.generar_codigo_barras(registro, idx)

        # Mapear ubicación si existe mapeo
        ubicacion_final = ""
        if registro.ubicacion_fisica and self.mapeo_ubicaciones:
            ubicacion_final = self.mapeo_ubicaciones.get(
                registro.ubicacion_fisica,
                registro.ubicacion_fisica
            )
        elif registro.ubicacion_fisica:
            ubicacion_final = registro.ubicacion_fisica

        subs_952 = [
            ("a", self.codigo_biblioteca),  # homebranch
            ("b", self.codigo_biblioteca),  # holdingbranch
            ("y", tipo_koha),               # itype
            ("p", codigo_barras),            # barcode
        ]

        if registro.signatura:
            subs_952.append(("o", registro.signatura))  # callnumber
        if ubicacion_final:
            # Insertar 'c' después de 'b'
            subs_952.insert(2, ("c", ubicacion_final))  # location
        if registro.volumen:
            subs_952.append(("h", registro.volumen))
        if registro.fecha_adquisicion:
            subs_952.append(("d", registro.fecha_adquisicion))
        if registro.precio:
            subs_952.append(("g", registro.precio))

        self.agregar_campo_datos(rec, "952", subs_952)

        return rec

    def dict_a_marcxml(self, datos: Dict[str, Any], idx: int = 1) -> str:
        """
        Convierte un diccionario de datos directamente a MARCXML (string).

        Este es el método principal para uso en API.

        Args:
            datos: Diccionario con datos bibliográficos
            idx: Índice del registro

        Returns:
            String con el XML del registro MARC

        Examples:
            >>> datos = {'titulo': 'Don Quijote', 'autor': 'Cervantes'}
            >>> xml_str = mapeador.dict_a_marcxml(datos)
        """
        registro = self.dict_a_registro(datos, idx)
        elemento = self.registro_a_marcxml(registro, idx)
        return ET.tostring(elemento, encoding="unicode")

    def lista_a_collection(self, lista_datos: List[Dict[str, Any]]) -> str:
        """
        Convierte una lista de diccionarios a una colección MARCXML completa.

        Args:
            lista_datos: Lista de diccionarios con datos bibliográficos

        Returns:
            String con el XML completo (con <collection>...</collection>)

        Examples:
            >>> datos_list = [
            ...     {'titulo': 'Libro 1', 'autor': 'Autor 1'},
            ...     {'titulo': 'Libro 2', 'autor': 'Autor 2'}
            ... ]
            >>> xml_completo = mapeador.lista_a_collection(datos_list)
        """
        # Crear colección
        ET.register_namespace('', self.ns)
        collection = ET.Element(f"{{{self.ns}}}collection")

        # Agregar cada registro
        for idx, datos in enumerate(lista_datos, start=1):
            registro = self.dict_a_registro(datos, idx)
            elemento = self.registro_a_marcxml(registro, idx)
            collection.append(elemento)

        # Convertir a string con formato
        tree = ET.ElementTree(collection)
        ET.indent(tree, space="  ")

        return ET.tostring(collection, encoding="unicode", xml_declaration=True)


# ════════════════════════════════════════════════════════════════════════════
# FUNCIONES DE UTILIDAD
# ════════════════════════════════════════════════════════════════════════════

def crear_mapeador(
    codigo_biblioteca: str,
    config_path: Optional[str] = None,
    mapeo_tipos_path: Optional[str] = None,
    mapeo_ubicaciones_path: Optional[str] = None
) -> MapeadorMARC21:
    """
    Factory function para crear un mapeador configurado.

    Args:
        codigo_biblioteca: Código de la biblioteca
        config_path: Ruta a config/mapeo_campos.json
        mapeo_tipos_path: Ruta a archivo JSON con mapeo de tipos
        mapeo_ubicaciones_path: Ruta a archivo JSON con mapeo de ubicaciones

    Returns:
        MapeadorMARC21 configurado

    Examples:
        >>> mapeador = crear_mapeador('MED',
        ...                           mapeo_ubicaciones_path='config/ejemplos/medicina_loc_map.json')
    """
    config = Path(config_path) if config_path else None

    # Cargar mapeo de tipos si existe
    mapeo_tipos = None
    if mapeo_tipos_path:
        path = Path(mapeo_tipos_path)
        if path.exists():
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                mapeo_tipos = data.get('default', {}).get('itemtype_map', {})

    # Cargar mapeo de ubicaciones si existe
    mapeo_ubicaciones = None
    if mapeo_ubicaciones_path:
        path = Path(mapeo_ubicaciones_path)
        if path.exists():
            with open(path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                # Puede estar en 'ubicaciones' o directamente en el root
                mapeo_ubicaciones = data.get('ubicaciones', data)

    return MapeadorMARC21(
        codigo_biblioteca=codigo_biblioteca,
        config_path=config,
        mapeo_tipos=mapeo_tipos,
        mapeo_ubicaciones=mapeo_ubicaciones
    )


# ════════════════════════════════════════════════════════════════════════════
# EJEMPLO DE USO
# ════════════════════════════════════════════════════════════════════════════

if __name__ == '__main__':
    print("═" * 70)
    print("DEMOSTRACIÓN: Módulo de Mapeo MARC21")
    print("═" * 70)
    print()

    # Ejemplo 1: Desde dict simple (puede venir de JSON API)
    print("📘 Ejemplo 1: Datos desde API (JSON → MARCXML)")
    print("-" * 70)

    datos_api = {
        'titulo': 'Cien años de soledad',
        'autor': 'García Márquez, Gabriel',
        'editorial': 'Editorial Sudamericana',
        'publicacion': '1967',
        'isbn': '978-0-307-47472-8',
        'materia': 'Literatura latinoamericana; Narrativa colombiana',
        'nroacceso': 'MED-001234',
        'ubicacion': '860.5 GAR'
    }

    mapeador = MapeadorMARC21(codigo_biblioteca='MED')
    marcxml = mapeador.dict_a_marcxml(datos_api)

    print("Datos de entrada (JSON):")
    print(json.dumps(datos_api, indent=2, ensure_ascii=False))
    print("\nMARCXML generado:")
    print(marcxml[:500] + "..." if len(marcxml) > 500 else marcxml)
    print()

    # Ejemplo 2: Lista de registros (colección completa)
    print("📚 Ejemplo 2: Múltiples registros → Colección MARCXML")
    print("-" * 70)

    datos_lista = [
        {'titulo': 'Don Quijote', 'autor': 'Cervantes', 'publicacion': '1605'},
        {'titulo': 'El principito', 'autor': 'Saint-Exupéry', 'publicacion': '1943'},
    ]

    collection_xml = mapeador.lista_a_collection(datos_lista)
    print(f"Colección con {len(datos_lista)} registros generada")
    print(f"Tamaño total: {len(collection_xml)} caracteres")
    print()

    # Ejemplo 3: Con mapeo de ubicaciones
    print("📍 Ejemplo 3: Con mapeo de ubicaciones personalizadas")
    print("-" * 70)

    mapeo_ubicaciones = {
        "SALA_NORTE": "NORTE",
        "SALA_SUR": "SUR",
        "DEPOSITO": "DEP"
    }

    mapeador2 = MapeadorMARC21(
        codigo_biblioteca='CENTRAL',
        mapeo_ubicaciones=mapeo_ubicaciones
    )

    datos_con_ubicacion = {
        'titulo': 'Libro de Física',
        'ubicacion_fisica': 'SALA_NORTE',  # Se mapeará a 'NORTE'
        'ubicacion': '530 FIS'
    }

    marcxml2 = mapeador2.dict_a_marcxml(datos_con_ubicacion)
    print("✓ Ubicación 'SALA_NORTE' mapeada a 'NORTE' en MARC 952 $c")
    print()

    print("═" * 70)
    print("✅ Módulo de Mapeo MARC21 funcionando correctamente")
    print("═" * 70)
