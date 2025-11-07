#!/usr/bin/env python3
"""
EXPORTADOR LOCAL DE DATOS BIBLIOGRÁFICOS - VERSIÓN BIBLIOTECA
==============================================================
Script para que cada biblioteca exporte sus datos localmente
sin necesidad de dar acceso remoto al servidor.

Universidad Nacional de Asunción - Sistema de Migración a Koha
Versión: 1.0
Fecha: 2025-01-15
"""

import fdb
import csv
import json
import sys
import os
from datetime import datetime


class ExportadorLocal:
    """Exportador de datos bibliográficos local"""

    def __init__(self, config_file='config_biblioteca.json'):
        self.config = self.cargar_config(config_file)
        self.stats = {'registros_exportados': 0, 'errores': 0, 'advertencias': []}

    def cargar_config(self, config_file):
        """Carga configuración desde JSON"""
        if not os.path.exists(config_file):
            print(f"❌ No se encontró: {config_file}")
            print("\n📝 Creando archivo de ejemplo...")
            self.crear_config_ejemplo(config_file)
            print(f"✓ Archivo creado: {config_file}\n")
            print("⚠️  IMPORTANTE: Edite el archivo y complete sus datos antes de continuar\n")
            sys.exit(0)

        with open(config_file, 'r', encoding='utf-8') as f:
            return json.load(f)

    def crear_config_ejemplo(self, config_file):
        """Crea archivo de configuración de ejemplo"""
        config = {
            "_comentario_1": "═══════════════════════════════════════════════════════",
            "_comentario_2": "CONFIGURACIÓN DE EXPORTACIÓN - EDITAR ANTES DE USAR",
            "_comentario_3": "═══════════════════════════════════════════════════════",
            "biblioteca": {
                "codigo": "FACXX",
                "nombre": "Facultad de XXXXX",
                "contacto": "responsable@facultad.una.py"
            },
            "firebird": {
                "_comentario": "Datos de conexión a SU base de datos Firebird",
                "host": "localhost",
                "port": 3050,
                "database": "C:\\Firebird\\data\\biblioteca.fdb",
                "user": "SYSDBA",
                "password": "masterkey",
                "charset": "UTF8"
            },
            "exportacion": {
                "archivo_salida": "datos_FACXX.csv",
                "incluir_ejemplares": True,
                "limite_prueba": None
            },
            "tablas": {
                "_comentario": "Nombres EXACTOS de sus tablas (verificar en su BD)",
                "bibliograficos": "BIBLIOGRAFICOS",
                "ejemplares": "EJEMPLARES"
            },
            "campos": {
                "_comentario": "Nombres EXACTOS de sus campos (verificar en su BD)",
                "_ejemplo": "Si su campo se llama 'TIT_LIBRO' poner 'TIT_LIBRO'",
                "id_biblio": "ID_REGISTRO",
                "titulo": "TITULO",
                "subtitulo": "SUBTITULO",
                "autor": "AUTOR",
                "autor_institucional": "AUTOR_INSTITUCIONAL",
                "editorial": "EDITORIAL",
                "ano_publicacion": "ANO_PUBLICACION",
                "lugar_publicacion": "LUGAR_PUBLICACION",
                "edicion": "EDICION",
                "paginas": "PAGINAS",
                "isbn": "ISBN",
                "clasificacion": "CLASIFICACION",
                "signatura": "SIGNATURA",
                "resumen": "RESUMEN",
                "materias": "MATERIAS",
                "notas": "NOTAS",
                "codigo_barras": "CODIGO_BARRAS",
                "ubicacion_fisica": "UBICACION_FISICA",
                "tipo_material": "TIPO_MATERIAL"
            }
        }

        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)

    def conectar(self):
        """Conecta a Firebird"""
        try:
            print(f"\n🔌 Conectando a Firebird...")
            print(f"   Host: {self.config['firebird']['host']}")
            print(f"   BD: {self.config['firebird']['database']}")

            conn = fdb.connect(
                host=self.config['firebird']['host'],
                port=self.config['firebird']['port'],
                database=self.config['firebird']['database'],
                user=self.config['firebird']['user'],
                password=self.config['firebird']['password'],
                charset=self.config['firebird']['charset']
            )

            print("   ✓ Conexión exitosa\n")
            return conn

        except Exception as e:
            print(f"\n❌ Error de conexión: {e}\n")
            print("Verifique:")
            print("  1. Firebird está ejecutándose")
            print("  2. Ruta de base de datos correcta")
            print("  3. Usuario/password correctos\n")
            sys.exit(1)

    def construir_query(self):
        """Construye SQL según configuración"""
        c = self.config['campos']
        t_bib = self.config['tablas']['bibliograficos']
        t_ej = self.config['tablas']['ejemplares']

        campos_bib = f"""
            b.{c['id_biblio']} as analisis,
            b.{c['titulo']} as titulo,
            b.{c.get('subtitulo', "''")} as sub_titulo,
            b.{c['autor']} as autor,
            b.{c.get('autor_institucional', "''")} as autorinst,
            b.{c['editorial']} as editorial,
            b.{c['ano_publicacion']} as publicacion,
            b.{c['lugar_publicacion']} as procedencia,
            b.{c.get('edicion', "''")} as edicion,
            b.{c.get('paginas', "''")} as paginas,
            b.{c.get('isbn', "''")} as isbn_issn,
            b.{c.get('resumen', "''")} as sintesis,
            b.{c.get('materias', "''")} as temas_descrip,
            b.{c.get('notas', "''")} as notas
        """

        campos_ej = f"""
            e.{c.get('codigo_barras', "''")} as nroacceso,
            e.{c.get('signatura', c.get('clasificacion', "''"))} as ubicacion,
            e.{c.get('ubicacion_fisica', "''")} as loc,
            e.{c.get('tipo_material', "''")} as tipomaterial
        """

        query = f"""
            SELECT
                {campos_bib},
                {campos_ej}
            FROM {t_bib} b
            LEFT JOIN {t_ej} e ON b.{c['id_biblio']} = e.ID_BIBLIO
            ORDER BY b.{c['id_biblio']}
        """

        limite = self.config['exportacion'].get('limite_prueba')
        if limite:
            query += f"\nFETCH FIRST {limite} ROWS ONLY"

        return query

    def normalizar(self, valor):
        """Normaliza valores"""
        if valor is None:
            return ""
        if isinstance(valor, bytes):
            try:
                valor = valor.decode('utf-8')
            except:
                valor = valor.decode('latin-1', errors='ignore')
        return ' '.join(str(valor).strip().split())

    def exportar(self):
        """Ejecuta exportación"""
        print("="*70)
        print(f" EXPORTACIÓN - {self.config['biblioteca']['nombre']}")
        print("="*70 + "\n")

        conn = self.conectar()
        cursor = conn.cursor()

        print("📝 Construyendo consulta...")
        query = self.construir_query()
        print("   ✓ Consulta lista\n")

        print("🔍 Consultando base de datos...")
        try:
            cursor.execute(query)
            print("   ✓ Consulta ejecutada\n")
        except Exception as e:
            print(f"\n❌ Error en consulta SQL: {e}\n")
            print("Posibles causas:")
            print("  - Nombres de tablas incorrectos")
            print("  - Nombres de campos incorrectos")
            print("\nRevise config_biblioteca.json\n")
            sys.exit(1)

        columnas = [desc[0].lower() for desc in cursor.description]
        columnas_csv = ['codbiblio'] + columnas

        archivo = self.config['exportacion']['archivo_salida']
        print(f"💾 Creando: {archivo}")

        with open(archivo, 'w', encoding='utf-8', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=columnas_csv, delimiter=';', quoting=csv.QUOTE_MINIMAL)
            writer.writeheader()

            batch = []
            for row in cursor:
                row_dict = {'codbiblio': self.config['biblioteca']['codigo']}
                for i, col in enumerate(columnas):
                    row_dict[col] = self.normalizar(row[i])

                if not row_dict.get('titulo'):
                    self.stats['advertencias'].append(f"Sin título: {row_dict.get('analisis')}")
                    continue

                batch.append(row_dict)

                if len(batch) >= 100:
                    writer.writerows(batch)
                    self.stats['registros_exportados'] += len(batch)
                    print(f"   {self.stats['registros_exportados']} registros...", end='\r')
                    batch = []

            if batch:
                writer.writerows(batch)
                self.stats['registros_exportados'] += len(batch)

        print(f"\n   ✓ Archivo creado\n")
        conn.close()

        self.mostrar_resultados()

    def mostrar_resultados(self):
        """Muestra resultados"""
        print("="*70)
        print(" RESULTADOS")
        print("="*70)
        print(f"Biblioteca: {self.config['biblioteca']['nombre']}")
        print(f"Código: {self.config['biblioteca']['codigo']}")
        print(f"Registros exportados: {self.stats['registros_exportados']:,}")
        if self.stats['advertencias']:
            print(f"Advertencias: {len(self.stats['advertencias'])}")
        print("="*70 + "\n")

        print("✅ EXPORTACIÓN COMPLETADA\n")
        print("📧 PRÓXIMOS PASOS:\n")
        print("1. Verificar archivo:")
        print(f"   python3 verificar_exportacion.py\n")
        print("2. Enviar por email a:")
        print(f"   soporte.biblioteca@una.py")
        print(f"   Asunto: Datos migración - {self.config['biblioteca']['codigo']}")
        print(f"   Adjunto: {self.config['exportacion']['archivo_salida']}\n")


def main():
    print("""
    ╔══════════════════════════════════════════════════════════╗
    ║   EXPORTADOR LOCAL DE DATOS BIBLIOGRÁFICOS               ║
    ║   Universidad Nacional de Asunción                       ║
    ║   Sistema de Migración a Koha                            ║
    ╚══════════════════════════════════════════════════════════╝
    """)

    try:
        exportador = ExportadorLocal()
        exportador.exportar()
    except KeyboardInterrupt:
        print("\n\n⚠️  Cancelado por usuario\n")
    except Exception as e:
        print(f"\n❌ Error: {e}\n")
        import traceback
        traceback.print_exc()


if __name__ == '__main__':
    main()
