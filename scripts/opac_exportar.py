#!/usr/bin/env python3
"""
csv_koha_final_optimized_v6.py — Conversor CSV → MARCXML para Koha (alineado 952 a/b/c) con MODO STREAMING

Fecha: 2025-10-15

NOVEDADES v6 vs v5:
- 🏎️ Modo STREAMING opcional (--stream) para generar MARCXML sin cargar todo en memoria.
  Útil para lotes grandes (100k+). Escribe el XML por partes manteniendo la validez del documento.
- 🪓 Opción --split-by N para dividir la salida en múltiples archivos de hasta N registros cada uno.
  (funciona con y sin --stream).
- 🧹 Limpiezas y micro-optimizaciones (menos copies, normalizaciones más baratas).
- 🧭 Misma alineación a tu framework confirmado:
    952$a → items.homebranch (OBLIGATORIO)
    952$b → items.holdingbranch
    952$c → items.location (opcional/LOC autorizado)
    952$o → items.itemcallnumber (signatura/cota)
    952$p → items.barcode
    952$y → items.itype
- 🧩 --codbiblio manda sobre el CSV (por facultad) para 952$a y 952$b.

EJEMPLOS:
  # POL con LOC por defecto y streaming
  python3 csv_koha_final_optimized_v6.py -i POL.csv --codbiblio POL --loc-default GEN --stream

  # AGRO con mapeo de LOC y salida en partes de 25k registros
  python3 csv_koha_final_optimized_v6.py -i AGRO.csv --codbiblio AGRO --loc-map loc_map_agro.json --split-by 25000

Requisitos: Python 3.9+
"""

from __future__ import annotations

import argparse
import csv
import json
import os
import re
import sys
import xml.etree.ElementTree as ET
from datetime import datetime
from hashlib import md5
from pathlib import Path
from typing import Dict, List, Tuple, Optional, Iterable


VERSION = "6.0"
DEFAULT_LANG = "spa"
DEFAULT_COUNTRY = "py "  # para MARC 008 (3 chars)

COLUMN_MAPPING = {
    "codbiblio": ["codbiblio", "biblioteca", "branch"],
    "analisis": ["analisis", "id", "identificador", "codigo"],
    "titulo": ["titulo", "tÃ­tulo", "título", "title"],
    "sub_titulo": ["sub_titulo", "subtitulo", "subtitle"],
    "autor": ["autor", "author", "autor_personal"],
    "autorinst": ["autorinst", "autor_institucional", "corporativo"],
    "mencion": ["mencion", "responsabilidad"],
    "edicion": ["edicion", "ediciÃ³n", "edición", "edition"],
    "procedencia": ["procedencia", "lugar", "place"],
    "publicacion": ["publicacion", "aÃ±o", "año", "anio", "year"],
    "editorial": ["editorial", "publisher"],
    "paginas": ["paginas", "pÃ¡ginas", "páginas", "pages"],
    "serie": ["serie", "coleccion", "colección"],
    "sintesis": ["sintesis", "resumen", "abstract"],
    "notas": ["notas", "nota", "notes"],
    "materia": ["materia", "materias", "subject", "temas_descrip"],
    "isbn": ["isbn", "isbn_issn", "issn"],
    "nroacceso": ["nroacceso", "barcode", "codigo_barras", "codbarras"],
    "ubicacion": ["ubicacion", "signatura", "cota", "callnumber"],  # → 952$o
    "loc": ["loc", "ubic_fisica", "ubicacion_fisica", "location_code"],  # → 952$c
    "tipomaterial": ["tipomaterial", "tipomat", "itemtype"],
    "volumen": ["volumen", "tomo", "vol"],
    "fechaadq": ["fechaadq", "fecha_adquisicion"],
    "precio": ["precio", "price", "costo"],
}

DEFAULT_ITEMTYPE_MAP = {
    "Monografia": "BK",
    "Monografía": "BK",
    "Revista": "MG",
    "DVD": "VM",
    "CD": "MU",
    "Mapa": "MP",
    "Tesis": "TES",
}


def normalize_text(s: Optional[str]) -> str:
    if not s:
        return ""
    return " ".join(s.split())


def add_controlfield(parent: ET.Element, tag: str, text: str) -> None:
    cf = ET.SubElement(parent, "controlfield", {"tag": tag})
    cf.text = text


def add_datafield(parent: ET.Element, tag: str, subfields: List[Tuple[str, str]], ind1: str = " ", ind2: str = " ") -> None:
    subs = [(c, t) for c, t in subfields if t and t.strip()]
    if not subs:
        return
    df = ET.SubElement(parent, "datafield", {"tag": tag, "ind1": ind1, "ind2": ind2})
    for code, text in subs:
        sf = ET.SubElement(df, "subfield", {"code": code})
        sf.text = normalize_text(text)


def detect_encoding(file_path: str) -> str:
    for enc in ("utf-8", "cp1252", "latin-1"):
        try:
            with open(file_path, "r", encoding=enc) as fh:
                fh.read(4096)
            return enc
        except Exception:
            pass
    return "utf-8"


def detect_delimiter(file_path: str, encoding: str) -> str:
    try:
        with open(file_path, "r", encoding=encoding) as fh:
            sample = fh.read(4096)
        sniffer = csv.Sniffer()
        return sniffer.sniff(sample, delimiters=";,|\t").delimiter
    except Exception:
        return ";"


def find_column(headers: List[str], candidates: List[str]) -> Optional[str]:
    lower = {h.lower().strip(): h for h in headers}
    for cand in candidates:
        name = cand.lower()
        if name in lower:
            return lower[name]
    return None


def build_marc_008(pub_year: str, language: str, country: str) -> str:
    date_part = datetime.utcnow().strftime("%y%m%d")
    digits = re.sub(r"[^0-9]", "", pub_year or "")
    year4 = (digits[:4] if digits else "    ").ljust(4)
    country_code = (country or DEFAULT_COUNTRY).ljust(3)[:3]
    lang_code = (language or DEFAULT_LANG).ljust(3)[:3]
    field_008 = f"{date_part}s{year4}    {country_code}{' '*17}{lang_code}  "
    return field_008[:40].ljust(40)


def ensure_barcode(raw: str, branch: str, idx: int) -> str:
    raw = normalize_text(raw)
    return raw[:20] if raw else f"{branch}-{idx:07d}"[:20]


def make_local_id(titulo: str, autor: str, anio: str, idx: int) -> str:
    base = f"{titulo}|{autor}|{anio}|{idx}"
    return "HX:" + md5(base.encode("utf-8")).hexdigest()[:10]


def load_json(path: Optional[str]) -> dict:
    if not path or not os.path.isfile(path):
        return {}
    with open(path, "r", encoding="utf-8") as fh:
        return json.load(fh)


def write_collection_header(fh) -> None:
    fh.write('<?xml version="1.0" encoding="UTF-8"?>\n')
    fh.write('<collection xmlns="http://www.loc.gov/MARC21/slim">\n')


def write_collection_footer(fh) -> None:
    fh.write('</collection>\n')


def record_to_string(record: ET.Element) -> str:
    return ET.tostring(record, encoding="unicode")


class Converter:
    def __init__(self, args: argparse.Namespace) -> None:
        self.input = args.input
        self.lang = args.idioma or DEFAULT_LANG
        self.country = DEFAULT_COUNTRY
        self.codbiblio = (args.codbiblio or Path(self.input).stem.split("_")[0] or "UNA").upper()
        self.map_config = load_json(args.map_config)
        self.branch_map = {k.upper(): v for k, v in self.map_config.get("default", {}).get("branch_map", {}).items()}
        self.itemtype_map = {**DEFAULT_ITEMTYPE_MAP, **self.map_config.get("default", {}).get("itemtype_map", {})}
        self.loc_map = load_json(args.loc_map)
        self.loc_default = normalize_text(args.loc_default or "")
        self.one_record_per_row = bool(args.one_record_per_row)
        self.stream = bool(args.stream)
        self.split_by = int(args.split_by) if args.split_by else 0

        self.encoding = detect_encoding(self.input)
        self.delimiter = detect_delimiter(self.input, self.encoding)

        self.branch_final = self.branch_map.get(self.codbiblio, self.codbiblio)

    def read_rows(self):
        fh = open(self.input, "r", encoding=self.encoding, newline="")
        reader = csv.DictReader(fh, delimiter=self.delimiter)
        headers = [h.strip() for h in (reader.fieldnames or [])]
        return headers, reader

    def build_column_map(self, headers: List[str]) -> Dict[str, Optional[str]]:
        mapping: Dict[str, Optional[str]] = {}
        for logical, cands in COLUMN_MAPPING.items():
            mapping[logical] = find_column(headers, cands)
        if not mapping.get("titulo"):
            print("❌ No se encontró columna de título.", file=sys.stderr)
            sys.exit(1)
        return mapping

    def create_record(self, row: dict, idx: int, colmap: Dict[str, Optional[str]]) -> Optional[ET.Element]:
        titulo = normalize_text(row.get(colmap.get("titulo", ""), ""))
        if not titulo:
            return None
        autor = normalize_text(row.get(colmap.get("autor", ""), ""))
        autorinst = normalize_text(row.get(colmap.get("autorinst", ""), ""))
        sub_titulo = normalize_text(row.get(colmap.get("sub_titulo", ""), ""))
        mencion = normalize_text(row.get(colmap.get("mencion", ""), ""))
        edicion = normalize_text(row.get(colmap.get("edicion", ""), ""))
        procedencia = normalize_text(row.get(colmap.get("procedencia", ""), ""))
        publicacion = normalize_text(row.get(colmap.get("publicacion", ""), ""))
        editorial = normalize_text(row.get(colmap.get("editorial", ""), ""))
        serie = normalize_text(row.get(colmap.get("serie", ""), ""))
        sintesis = normalize_text(row.get(colmap.get("sintesis", ""), ""))
        materia = normalize_text(row.get(colmap.get("materia", ""), ""))
        isbn = normalize_text(row.get(colmap.get("isbn", ""), ""))
        nroacceso = normalize_text(row.get(colmap.get("nroacceso", ""), ""))
        callnumber = normalize_text(row.get(colmap.get("ubicacion", ""), ""))  # 952$o
        loc_raw = normalize_text(row.get(colmap.get("loc", ""), ""))
        tipomaterial = normalize_text(row.get(colmap.get("tipomaterial", ""), ""))
        volumen = normalize_text(row.get(colmap.get("volumen", ""), ""))
        fechaadq = normalize_text(row.get(colmap.get("fechaadq", ""), ""))
        precio = normalize_text(row.get(colmap.get("precio", ""), ""))

        ns = "http://www.loc.gov/MARC21/slim"
        rec = ET.Element(f"{{{ns}}}record")
        ET.SubElement(rec, "leader").text = "00000nam a2200000 i 4500"

        # 001
        analisis = normalize_text(row.get(colmap.get("analisis", ""), ""))
        if analisis:
            local_id = f"ANL:{analisis}"
        elif nroacceso:
            local_id = f"BC:{nroacceso}"
        else:
            local_id = make_local_id(titulo, autor, publicacion, idx)

        add_controlfield(rec, "001", local_id)
        add_controlfield(rec, "003", self.branch_final)
        add_controlfield(rec, "005", datetime.utcnow().strftime("%Y%m%d%H%M%S") + ".0")
        add_controlfield(rec, "008", build_marc_008(publicacion, self.lang, self.country))

        if isbn:
            add_datafield(rec, "020", [("a", isbn)])

        add_datafield(rec, "040", [("a", self.branch_final), ("b", self.lang), ("c", self.branch_final)])

        if autor:
            add_datafield(rec, "100", [("a", autor)], ind1="1")
        elif autorinst:
            add_datafield(rec, "110", [("a", autorinst)], ind1="2")

        subs_245: List[Tuple[str, str]] = [("a", titulo)]
        if sub_titulo:
            subs_245.append(("b", sub_titulo))
        if mencion:
            subs_245.append(("c", mencion))
        add_datafield(rec, "245", subs_245, ind1=("1" if (autor or autorinst) else "0"), ind2="0")

        if edicion:
            add_datafield(rec, "250", [("a", edicion)])

        subs_264: List[Tuple[str, str]] = []
        if procedencia:
            subs_264.append(("a", procedencia))
        if editorial:
            subs_264.append(("b", editorial))
        if publicacion:
            subs_264.append(("c", publicacion))
        if subs_264:
            add_datafield(rec, "264", subs_264, ind2="1")

        if serie:
            add_datafield(rec, "490", [("a", serie)], ind1="1")
        if sintesis:
            add_datafield(rec, "520", [("a", sintesis)])
        if materia:
            for tema in (t.strip() for t in materia.split(";")):
                if tema:
                    add_datafield(rec, "650", [("a", tema)], ind2="4")

        itype = self.itemtype_map.get(tipomaterial, "BK")
        add_datafield(rec, "942", [("c", itype)])

        barcode = ensure_barcode(nroacceso, self.branch_final, idx)
        loc_mapped = ""
        if isinstance(self.loc_map, dict) and self.loc_map:
            loc_mapped = self.loc_map.get(loc_raw, "") if loc_raw else ""
        if not loc_mapped and self.loc_default:
            loc_mapped = self.loc_default

        subs_952: List[Tuple[str, str]] = [
            ("a", self.branch_final),
            ("b", self.branch_final),
            ("y", itype),
            ("p", barcode),
            ("o", callnumber),
        ]
        if loc_mapped:
            subs_952.insert(2, ("c", loc_mapped))
        if volumen:
            subs_952.append(("h", volumen))
        if fechaadq:
            subs_952.append(("d", fechaadq))
        if precio:
            subs_952.append(("g", precio))

        add_datafield(rec, "952", subs_952)

        return rec

    def output_base(self) -> str:
        stamp = datetime.now().strftime("%Y%m%d")
        return f"{self.branch_final}_{stamp}_marcxml"

    def convert(self) -> None:
        headers, reader = self.read_rows()
        colmap = self.build_column_map(headers)

        base = self.output_base()
        if self.stream or self.split_by:
            idx = 0
            file_index = 1
            fh = None
            try:
                for row in reader:
                    idx += 1
                    if fh is None:
                        outname = f"{base}.xml" if file_index == 1 and not self.split_by else f"{base}_{file_index:02d}.xml"
                        fh = open(outname, "w", encoding="utf-8")
                        write_collection_header(fh)
                        print(f"→ escribiendo: {outname}")

                    rec = self.create_record(row, idx, colmap)
                    if rec is not None:
                        fh.write(record_to_string(rec))
                        fh.write("\n")

                    if self.split_by and (idx % self.split_by == 0):
                        write_collection_footer(fh)
                        fh.close()
                        fh = None
                        file_index += 1

                if fh is not None:
                    write_collection_footer(fh)
                    fh.close()
            finally:
                if fh and not fh.closed:
                    try:
                        write_collection_footer(fh)
                        fh.close()
                    except Exception:
                        pass

            print("✅ Listo (stream/split).")
        else:
            # modo en memoria (para lotes medianos)
            ns = "http://www.loc.gov/MARC21/slim"
            ET.register_namespace('', ns)
            collection = ET.Element(f"{{{ns}}}collection")

            for idx, row in enumerate(reader, start=1):
                rec = self.create_record(row, idx, colmap)
                if rec is not None:
                    collection.append(rec)

            tree = ET.ElementTree(collection)
            ET.indent(tree, space="  ")
            outname = f"{base}.xml"
            tree.write(outname, encoding="utf-8", xml_declaration=True)
            print(f"✅ Listo: {outname}")


def main():
    p = argparse.ArgumentParser(description="CSV → MARCXML para Koha (MARC21; 952 a/b/c) con streaming y split opcional.")
    p.add_argument("-i", "--input", required=True, help="CSV de entrada")
    p.add_argument("--codbiblio", help="Código de biblioteca (ej: POL, AGRO). Si se indica, predomina en 952$a/$b.")
    p.add_argument("--idioma", default=DEFAULT_LANG, help="Código de idioma MARC (ej: spa)")
    p.add_argument("--map-config", help="JSON con 'default.branch_map' y 'default.itemtype_map'")
    p.add_argument("--loc-default", help="LOC por defecto si no hay --loc-map ni columna 'loc'")
    p.add_argument("--loc-map", help="JSON con mapeo de valores CSV → LOC autorizado")
    p.add_argument("--one-record-per-row", action="store_true", default=True, help="1 fila = 1 biblio + 1 ítem (default)")
    p.add_argument("--stream", action="store_true", help="Genera salida en streaming (recomendado para lotes grandes)")
    p.add_argument("--split-by", type=int, help="Parte la salida cada N registros (ej: 25000)")
    p.add_argument("--version", action="version", version=f"%(prog)s {VERSION}")
    args = p.parse_args()

    if not os.path.isfile(args.input):
        print(f"❌ No existe el archivo: {args.input}", file=sys.stderr)
        sys.exit(1)

    Converter(args).convert()


if __name__ == "__main__":
    main()
