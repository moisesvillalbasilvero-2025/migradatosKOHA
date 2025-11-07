# 🔄 SISTEMA DE MIGRACIÓN DESCENTRALIZADO
## Exportación Local por cada Biblioteca

**Para cuando NO hay acceso remoto a los servidores Firebird**

---

## 🎯 CONCEPTO

Cada biblioteca/facultad puede:
1. Ejecutar un script en SU propio servidor
2. Generar un archivo CSV con sus datos
3. Enviarlo al equipo central
4. El equipo central lo procesa y carga a Koha

**Ventajas:**
- ✅ No requiere acceso remoto
- ✅ Cada biblioteca controla sus datos
- ✅ Más seguro (no compartir passwords)
- ✅ Proceso independiente por biblioteca
- ✅ Pueden ejecutarlo cuando quieran

---

## 📦 PAQUETE PARA DISTRIBUIR A BIBLIOTECAS

### Contenido del Paquete

```
koha_exportador_local/
├── README_BIBLIOTECA.txt          # Instrucciones simples
├── exportar_mis_datos.py          # Script para ejecutar
├── config_biblioteca.json         # Configuración
├── verificar_exportacion.py       # Validador
└── INSTRUCCIONES_PASO_A_PASO.pdf  # Manual con capturas
```

---

## 📝 SCRIPT PARA BIBLIOTECAS

### exportar_mis_datos.py

```python
#!/usr/bin/env python3
"""
EXPORTADOR LOCAL DE DATOS BIBLIOGRÁFICOS
=========================================
Script para que cada biblioteca exporte sus datos desde Firebird
y los prepare para carga en el catálogo unificado Koha.

IMPORTANTE: Este script se ejecuta EN EL SERVIDOR DE LA BIBLIOTECA,
no requiere conectarse remotamente.

Autor: Sistema de Bibliotecas UNA
Fecha: 2025-01-15
"""

import fdb
import csv
import json
import sys
import os
from datetime import datetime
from pathlib import Path


class ExportadorLocal:
    """Exportador de datos bibliográficos local"""

    def __init__(self, config_file='config_biblioteca.json'):
        """
        Inicializa el exportador

        Args:
            config_file: Archivo de configuración JSON
        """
        self.config = self.cargar_config(config_file)
        self.stats = {
            'registros_exportados': 0,
            'errores': 0,
            'advertencias': []
        }

    def cargar_config(self, config_file):
        """Carga configuración desde JSON"""
        if not os.path.exists(config_file):
            print(f"❌ No se encontró el archivo de configuración: {config_file}")
            print("\nCreando archivo de ejemplo...")
            self.crear_config_ejemplo(config_file)
            print(f"\n✓ Archivo creado: {config_file}")
            print("\n⚠️  IMPORTANTE: Edite el archivo y configure sus datos antes de continuar")
            sys.exit(1)

        with open(config_file, 'r', encoding='utf-8') as f:
            return json.load(f)

    def crear_config_ejemplo(self, config_file):
        """Crea archivo de configuración de ejemplo"""
        config_ejemplo = {
            "_comentario": "Configuración de exportación - Editar antes de usar",
            "biblioteca": {
                "codigo": "FACXX",
                "nombre": "Facultad de XXXXX",
                "contacto": "responsable@facultad.una.py"
            },
            "firebird": {
                "host": "localhost",
                "port": 3050,
                "database": "/ruta/completa/a/tu/base.fdb",
                "user": "SYSDBA",
                "password": "masterkey",
                "charset": "UTF8"
            },
            "exportacion": {
                "archivo_salida": "datos_FACXX.csv",
                "incluir_ejemplares": True,
                "limite_registros": None
            },
            "mapeo_tablas": {
                "_comentario": "Nombres de tus tablas en Firebird",
                "tabla_bibliograficos": "BIBLIOGRAFICOS",
                "tabla_ejemplares": "EJEMPLARES"
            },
            "mapeo_campos": {
                "_comentario": "Nombres de tus campos en Firebird",
                "id_registro": "ID_REGISTRO",
                "titulo": "TITULO",
                "subtitulo": "SUBTITULO",
                "autor": "AUTOR",
                "editorial": "EDITORIAL",
                "ano_publicacion": "ANO_PUBLICACION",
                "lugar_publicacion": "LUGAR_PUBLICACION",
                "isbn": "ISBN",
                "clasificacion": "CLASIFICACION",
                "resumen": "RESUMEN",
                "materias": "MATERIAS",
                "notas": "NOTAS",
                "codigo_barras": "CODIGO_BARRAS",
                "signatura": "SIGNATURA",
                "ubicacion_fisica": "UBICACION_FISICA",
                "tipo_material": "TIPO_MATERIAL"
            }
        }

        with open(config_file, 'w', encoding='utf-8') as f:
            json.dump(config_ejemplo, f, indent=2, ensure_ascii=False)

    def conectar_firebird(self):
        """Conecta a la base de datos Firebird local"""
        try:
            print(f"\n🔌 Conectando a Firebird...")
            print(f"   Host: {self.config['firebird']['host']}")
            print(f"   Base de datos: {self.config['firebird']['database']}")

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
            print(f"\n❌ Error de conexión: {e}")
            print("\nVerifique:")
            print("  1. Que Firebird esté ejecutándose")
            print("  2. Que la ruta de la base de datos sea correcta")
            print("  3. Que el usuario/password sean correctos")
            sys.exit(1)

    def construir_query(self):
        """Construye el SQL query basado en la configuración"""
        mapeo = self.config['mapeo_campos']
        tabla_bib = self.config['mapeo_tablas']['tabla_bibliograficos']
        tabla_ej = self.config['mapeo_tablas']['tabla_ejemplares']

        query = f"""
            SELECT
                b.{mapeo['id_registro']} as id_registro,
                b.{mapeo['titulo']} as titulo,
                b.{mapeo.get('subtitulo', 'NULL')} as sub_titulo,
                b.{mapeo['autor']} as autor,
                b.{mapeo['editorial']} as editorial,
                b.{mapeo['ano_publicacion']} as publicacion,
                b.{mapeo['lugar_publicacion']} as procedencia,
                b.{mapeo.get('isbn', 'NULL')} as isbn,
                b.{mapeo.get('clasificacion', 'NULL')} as ubicacion,
                b.{mapeo.get('resumen', 'NULL')} as sintesis,
                b.{mapeo.get('materias', 'NULL')} as temas_descrip,
                b.{mapeo.get('notas', 'NULL')} as notas,
                e.{mapeo.get('codigo_barras', 'NULL')} as nroacceso,
                e.{mapeo.get('signatura', 'NULL')} as ubicacion_topografica,
                e.{mapeo.get('ubicacion_fisica', 'NULL')} as loc,
                e.{mapeo.get('tipo_material', 'NULL')} as tipomaterial
            FROM {tabla_bib} b
            LEFT JOIN {tabla_ej} e ON b.{mapeo['id_registro']} = e.ID_BIBLIO
            ORDER BY b.{mapeo['id_registro']}
        """

        limite = self.config['exportacion'].get('limite_registros')
        if limite:
            query += f"\nFETCH FIRST {limite} ROWS ONLY"

        return query

    def normalizar_valor(self, valor):
        """Normaliza valores para CSV"""
        if valor is None:
            return ""

        if isinstance(valor, bytes):
            try:
                valor = valor.decode('utf-8')
            except:
                valor = valor.decode('latin-1', errors='ignore')

        valor = str(valor).strip()
        valor = valor.replace('\r\n', ' ').replace('\n', ' ').replace('\r', ' ')
        return ' '.join(valor.split())

    def exportar(self):
        """Ejecuta la exportación"""
        print("="*70)
        print(f"EXPORTACIÓN DE DATOS - {self.config['biblioteca']['nombre']}")
        print("="*70)
        print()

        # Conectar
        conn = self.conectar_firebird()
        cursor = conn.cursor()

        # Construir query
        print("📝 Generando consulta SQL...")
        query = self.construir_query()
        print("   ✓ Consulta construida\n")

        # Ejecutar query
        print("🔍 Consultando base de datos...")
        cursor.execute(query)
        print("   ✓ Consulta ejecutada\n")

        # Obtener columnas
        columnas = [desc[0].lower() for desc in cursor.description]
        columnas_con_codigo = ['codbiblio'] + columnas

        # Crear archivo CSV
        archivo_salida = self.config['exportacion']['archivo_salida']
        print(f"💾 Creando archivo: {archivo_salida}")

        with open(archivo_salida, 'w', encoding='utf-8', newline='') as csvfile:
            writer = csv.DictWriter(
                csvfile,
                fieldnames=columnas_con_codigo,
                delimiter=';',
                quotechar='"',
                quoting=csv.QUOTE_MINIMAL
            )

            writer.writeheader()

            # Procesar filas
            batch_size = 100
            batch = []
            total = 0

            for row in cursor:
                row_dict = {'codbiblio': self.config['biblioteca']['codigo']}

                for i, col in enumerate(columnas):
                    row_dict[col] = self.normalizar_valor(row[i])

                # Validación básica
                if not row_dict.get('titulo'):
                    self.stats['advertencias'].append(
                        f"Registro {row_dict.get('id_registro')} sin título"
                    )
                    continue

                batch.append(row_dict)
                total += 1

                # Escribir en lotes
                if len(batch) >= batch_size:
                    writer.writerows(batch)
                    self.stats['registros_exportados'] += len(batch)
                    print(f"   Progreso: {self.stats['registros_exportados']} registros...", end='\r')
                    batch = []

            # Escribir últimos registros
            if batch:
                writer.writerows(batch)
                self.stats['registros_exportados'] += len(batch)

        print(f"\n   ✓ Archivo creado exitosamente\n")

        conn.close()

        # Mostrar estadísticas
        self.mostrar_estadisticas()

        # Mostrar próximos pasos
        self.mostrar_proximos_pasos()

    def mostrar_estadisticas(self):
        """Muestra estadísticas de la exportación"""
        print("="*70)
        print("ESTADÍSTICAS DE EXPORTACIÓN")
        print("="*70)
        print(f"Biblioteca: {self.config['biblioteca']['nombre']}")
        print(f"Código: {self.config['biblioteca']['codigo']}")
        print(f"Registros exportados: {self.stats['registros_exportados']:,}")
        print(f"Errores: {self.stats['errores']}")

        if self.stats['advertencias']:
            print(f"\nAdvertencias: {len(self.stats['advertencias'])}")
            for adv in self.stats['advertencias'][:5]:
                print(f"  ⚠️  {adv}")
            if len(self.stats['advertencias']) > 5:
                print(f"  ... y {len(self.stats['advertencias']) - 5} más")

        print("="*70)

    def mostrar_proximos_pasos(self):
        """Muestra instrucciones de próximos pasos"""
        archivo_salida = self.config['exportacion']['archivo_salida']

        print("\n✅ EXPORTACIÓN COMPLETADA")
        print("\n📧 PRÓXIMOS PASOS:")
        print(f"\n1. Verificar el archivo generado:")
        print(f"   {os.path.abspath(archivo_salida)}")
        print(f"\n2. Ejecutar el validador:")
        print(f"   python3 verificar_exportacion.py")
        print(f"\n3. Enviar el archivo CSV al equipo central:")
        print(f"   Email: soporte.biblioteca@una.py")
        print(f"   Asunto: Datos para migración - {self.config['biblioteca']['codigo']}")
        print(f"   Adjuntar: {archivo_salida}")
        print(f"\n4. Contacto para consultas:")
        print(f"   {self.config['biblioteca']['contacto']}")
        print()


def main():
    """Función principal"""
    print("""
    ╔══════════════════════════════════════════════════════════════╗
    ║                                                              ║
    ║     EXPORTADOR LOCAL DE DATOS BIBLIOGRÁFICOS                 ║
    ║     Universidad Nacional de Asunción                         ║
    ║     Sistema de Migración a Koha                              ║
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝
    """)

    try:
        exportador = ExportadorLocal()
        exportador.exportar()

        print("\n✓ Proceso completado exitosamente")
        print("\n📝 Recuerde enviar el archivo CSV al equipo central\n")

    except KeyboardInterrupt:
        print("\n\n⚠️  Exportación cancelada por el usuario")
        sys.exit(1)
    except Exception as e:
        print(f"\n\n❌ Error inesperado: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
```

---

## 📋 README_BIBLIOTECA.txt

```
═══════════════════════════════════════════════════════════════
  INSTRUCCIONES PARA EXPORTAR DATOS DE SU BIBLIOTECA
═══════════════════════════════════════════════════════════════

🎯 OBJETIVO

Este script le permite exportar los datos bibliográficos de su
biblioteca desde su servidor Firebird local y prepararlos para
el catálogo unificado de la UNA en Koha.

NO requiere dar acceso remoto a su servidor.

═══════════════════════════════════════════════════════════════
📦 REQUISITOS

1. Python 3.8 o superior instalado
2. Acceso a su servidor Firebird (local)
3. Conocer:
   - Ubicación del archivo .fdb
   - Usuario y password de Firebird
   - Nombres de sus tablas

═══════════════════════════════════════════════════════════════
🚀 PASOS PARA EJECUTAR

PASO 1: Instalar dependencia

  Windows:
    pip install fdb

  Linux:
    pip3 install fdb

PASO 2: Primera ejecución (genera configuración)

  python3 exportar_mis_datos.py

  Esto creará el archivo: config_biblioteca.json

PASO 3: Editar config_biblioteca.json

  Abrir con cualquier editor de texto y completar:

  {
    "biblioteca": {
      "codigo": "FACXX",              ← Cambiar por su código
      "nombre": "Mi Facultad",        ← Nombre completo
      "contacto": "email@facultad.py" ← Su email
    },
    "firebird": {
      "host": "localhost",
      "database": "/ruta/a/base.fdb", ← RUTA REAL de su BD
      "user": "SYSDBA",               ← Usuario Firebird
      "password": "masterkey"         ← Password Firebird
    },
    ...
  }

  IMPORTANTE: Verificar nombres de tablas y campos

PASO 4: Ejecutar exportación

  python3 exportar_mis_datos.py

  Esto generará: datos_FACXX.csv

PASO 5: Verificar exportación

  python3 verificar_exportacion.py

PASO 6: Enviar archivo CSV

  Email a: soporte.biblioteca@una.py
  Asunto: Datos para migración - FACXX
  Adjuntar: datos_FACXX.csv

═══════════════════════════════════════════════════════════════
❓ AYUDA

Si tiene problemas:

1. Error de conexión a Firebird:
   - Verificar que Firebird esté ejecutándose
   - Verificar ruta de base de datos
   - Verificar usuario/password

2. Campos no coinciden:
   - Editar mapeo_campos en config_biblioteca.json
   - Usar nombres exactos de SU base de datos

3. Consultas:
   Email: soporte.biblioteca@una.py
   Teléfono: XXX-XXXX

═══════════════════════════════════════════════════════════════
✅ CHECKLIST

□ Python instalado
□ fdb instalado (pip install fdb)
□ config_biblioteca.json editado
□ Ruta de base de datos correcta
□ Usuario/password correctos
□ Nombres de tablas correctos
□ Exportación ejecutada sin errores
□ Archivo CSV verificado
□ Archivo CSV enviado

═══════════════════════════════════════════════════════════════

Versión: 1.0
Fecha: 2025-01-15
Sistema: Migración a Koha UNA
```

---

## 🔍 verificar_exportacion.py

```python
#!/usr/bin/env python3
"""
Verificador de exportación
Valida que el archivo CSV generado sea correcto
"""

import csv
import sys


def verificar_csv(archivo='datos_FACXX.csv'):
    """Verifica el archivo CSV"""

    print("\n" + "="*70)
    print("VERIFICACIÓN DE EXPORTACIÓN")
    print("="*70 + "\n")

    try:
        with open(archivo, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter=';')

            registros = list(reader)
            total = len(registros)

            print(f"✓ Archivo: {archivo}")
            print(f"✓ Total de registros: {total:,}")
            print()

            # Verificar campos obligatorios
            print("Verificando campos obligatorios...")

            sin_titulo = sum(1 for r in registros if not r.get('titulo'))
            sin_codigo = sum(1 for r in registros if not r.get('codbiblio'))

            if sin_titulo > 0:
                print(f"  ⚠️  {sin_titulo} registros sin título")
            else:
                print(f"  ✓ Todos los registros tienen título")

            if sin_codigo > 0:
                print(f"  ⚠️  {sin_codigo} registros sin código de biblioteca")
            else:
                print(f"  ✓ Todos los registros tienen código")

            # Muestreo
            print(f"\nMuestra de primeros 3 registros:")
            print("-"*70)

            for i, reg in enumerate(registros[:3], 1):
                print(f"\nRegistro {i}:")
                print(f"  ID: {reg.get('id_registro', 'N/A')}")
                print(f"  Título: {reg.get('titulo', 'N/A')[:60]}...")
                print(f"  Autor: {reg.get('autor', 'N/A')}")
                print(f"  Biblioteca: {reg.get('codbiblio', 'N/A')}")

            print("\n" + "="*70)
            print("✅ VERIFICACIÓN COMPLETADA")
            print("\nEl archivo está listo para enviarse al equipo central")
            print("="*70 + "\n")

            return True

    except FileNotFoundError:
        print(f"❌ No se encontró el archivo: {archivo}")
        print("Ejecute primero: python3 exportar_mis_datos.py")
        return False
    except Exception as e:
        print(f"❌ Error: {e}")
        return False


if __name__ == '__main__':
    archivo = sys.argv[1] if len(sys.argv) > 1 else 'datos_FACXX.csv'
    verificar_csv(archivo)
```

---

## 📧 PROCESO COMPLETO

### En la Biblioteca (Local)

```
┌─────────────────────────────────────┐
│  SERVIDOR DE LA BIBLIOTECA          │
│                                     │
│  1. Descargar paquete               │
│  2. Editar config_biblioteca.json   │
│  3. Ejecutar:                       │
│     python3 exportar_mis_datos.py   │
│  4. Verificar:                      │
│     python3 verificar_exportacion.py│
│  5. Enviar datos_FACXX.csv por email│
└─────────────────────────────────────┘
          │
          │ Email con CSV
          ↓
┌─────────────────────────────────────┐
│  EQUIPO CENTRAL                     │
│                                     │
│  1. Recibir datos_FACXX.csv         │
│  2. Validar datos                   │
│  3. Convertir a MARCXML:            │
│     opac_exportar.py                │
│  4. Importar a Koha                 │
│  5. Notificar a biblioteca          │
└─────────────────────────────────────┘
```

---

## 📅 CRONOGRAMA SUGERIDO

| Semana | Biblioteca | Acción |
|--------|-----------|---------|
| 1 | TODAS | Enviar paquete exportador |
| 2-3 | TODAS | Ejecutar exportación local |
| 3-4 | Central | Procesar CSVs recibidos |
| 5 | Central | Importar a Koha |
| 6 | TODAS | Verificación y ajustes |

---

## ✅ VENTAJAS DE ESTE ENFOQUE

1. **Seguridad:** No se comparten passwords
2. **Autonomía:** Cada biblioteca controla cuándo exportar
3. **Simple:** Solo ejecutar un script
4. **Verificable:** Pueden revisar qué datos se envían
5. **Escalable:** Funciona para 5 o 50 bibliotecas
6. **Sin dependencias:** No requiere red entre servidores

---

**¿Quieres que genere el paquete completo listo para distribuir?**
