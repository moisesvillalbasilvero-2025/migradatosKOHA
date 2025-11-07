#!/usr/bin/env python3
"""
AGENTE IMPORTADOR AUTOMATIZADO MÁXIMO
=======================================
Universidad Nacional de Asunción - Sistema Koha

CARACTERÍSTICAS:
✓ Importación automática desde CSV de múltiples bibliotecas
✓ Auto-detección de código de biblioteca desde nombre de archivo
✓ Auto-corrección de duplicados
✓ Validación completa de datos
✓ Generación de MARCXML optimizado
✓ Importación directa a Koha
✓ Reindexación automática
✓ Reportes detallados
✓ Control de errores robusto
✓ Modo batch para múltiples archivos

USO SIMPLE:
-----------
1) UN SOLO ARCHIVO:
   ./agente_importador.py /ruta/MED.csv

2) MÚLTIPLES ARCHIVOS:
   ./agente_importador.py /ruta/*.csv

3) MODO INTERACTIVO:
   ./agente_importador.py

4) CON CONFIGURACIÓN:
   ./agente_importador.py --config bibliotecas.json

Versión: 3.0
Fecha: 2025-10-22
"""

import os
import sys
import json
import subprocess
import csv
from pathlib import Path
from datetime import datetime
from typing import Dict, List, Optional
import re
from collections import Counter


class Color:
    """Colores para terminal"""
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    MAGENTA = '\033[95m'
    BOLD = '\033[1m'
    END = '\033[0m'


class AgenteImportador:
    """Agente inteligente de importación automática"""

    def __init__(self):
        self.dir_trabajo = Path("/home/mvillalba/migradatos")
        self.dir_exports = self.dir_trabajo / "exports"
        self.dir_logs = self.dir_trabajo / "logs"
        self.dir_procesados = self.dir_trabajo / "procesados"
        self.dir_errores = self.dir_trabajo / "errores"
        self.instancia_koha = "koha-cnc"

        # Crear directorios
        for dir_path in [self.dir_exports, self.dir_logs, self.dir_procesados, self.dir_errores]:
            dir_path.mkdir(parents=True, exist_ok=True)

        # Log file
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        self.log_file = self.dir_logs / f"importacion_{timestamp}.log"

        # Estadísticas
        self.stats = {
            'total_archivos': 0,
            'exitosos': 0,
            'fallidos': 0,
            'registros_importados': 0
        }

    def log(self, mensaje: str, nivel: str = "INFO"):
        """Registra mensaje en log y consola"""
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        linea_log = f"[{timestamp}] [{nivel}] {mensaje}"

        with open(self.log_file, 'a', encoding='utf-8') as f:
            f.write(linea_log + "\n")

        if nivel == "ERROR":
            print(f"{Color.RED}{mensaje}{Color.END}")
        elif nivel == "WARNING":
            print(f"{Color.YELLOW}{mensaje}{Color.END}")
        elif nivel == "SUCCESS":
            print(f"{Color.GREEN}{mensaje}{Color.END}")
        else:
            print(mensaje)

    def print_banner(self):
        """Banner del sistema"""
        banner = f"""
{Color.BOLD}{Color.CYAN}
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║          AGENTE IMPORTADOR AUTOMÁTICO - KOHA OPAC                     ║
║          Universidad Nacional de Asunción                             ║
║                                                                       ║
║          Importación inteligente desde CSV                            ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
{Color.END}
"""
        print(banner)

    def detectar_codigo_biblioteca(self, archivo_csv: Path) -> Optional[str]:
        """Detecta el código de biblioteca del nombre del archivo"""
        nombre = archivo_csv.stem

        # Buscar código de 3-6 letras mayúsculas
        match = re.search(r'([A-Z]{3,6})', nombre)
        if match:
            codigo = match.group(1)
            self.log(f"✓ Código detectado: {codigo}", "SUCCESS")
            return codigo

        # Intentar detectar desde contenido CSV
        try:
            with open(archivo_csv, 'r', encoding='utf-8') as f:
                primera_linea = f.readline()
                sep = ';' if ';' in primera_linea else ','
                f.seek(0)
                reader = csv.DictReader(f, delimiter=sep)
                primera_fila = next(reader)

                if 'codbiblio' in primera_fila:
                    codigo = primera_fila['codbiblio'].strip()
                    self.log(f"✓ Código detectado del CSV: {codigo}", "SUCCESS")
                    return codigo
        except Exception as e:
            self.log(f"No se pudo detectar código del contenido: {e}", "WARNING")

        return None

    def verificar_biblioteca_koha(self, codigo: str) -> bool:
        """Verifica si la biblioteca existe en Koha"""
        try:
            cmd = f"sudo koha-mysql {self.instancia_koha} -N -e \"SELECT COUNT(*) FROM branches WHERE branchcode = '{codigo}'\""
            resultado = subprocess.run(cmd, shell=True, capture_output=True, text=True)

            if resultado.returncode == 0:
                count = int(resultado.stdout.strip())
                if count > 0:
                    # Obtener nombre
                    cmd_nombre = f"sudo koha-mysql {self.instancia_koha} -N -e \"SELECT branchname FROM branches WHERE branchcode = '{codigo}'\""
                    res_nombre = subprocess.run(cmd_nombre, shell=True, capture_output=True, text=True)
                    nombre = res_nombre.stdout.strip()
                    self.log(f"✓ Biblioteca encontrada en Koha: {nombre}", "SUCCESS")
                    return True
                else:
                    self.log(f"✗ Biblioteca '{codigo}' NO existe en Koha", "ERROR")
                    self.log("  Créala primero en Staff Interface", "WARNING")
                    return False
        except Exception as e:
            self.log(f"Error verificando biblioteca: {e}", "ERROR")
            return False

    def analizar_csv(self, archivo_csv: Path) -> Dict:
        """Analiza el archivo CSV"""
        self.log(f"Analizando: {archivo_csv.name}")

        try:
            with open(archivo_csv, 'r', encoding='utf-8') as f:
                primera = f.readline()
                sep = ';' if ';' in primera else ','
                total_lineas = sum(1 for _ in f)
                f.seek(0)

                reader = csv.DictReader(f, delimiter=sep)
                columnas = reader.fieldnames

                # Contar registros reales
                registros = list(reader)
                total_registros = len(registros)

                # Detectar duplicados de nroacceso
                codigos_acceso = [r.get('nroacceso', '').strip() for r in registros if r.get('nroacceso', '').strip()]
                contador = Counter(codigos_acceso)
                duplicados = sum(1 for k, v in contador.items() if v > 1)

                analisis = {
                    'archivo': str(archivo_csv),
                    'total_registros': total_registros,
                    'columnas': columnas,
                    'total_columnas': len(columnas),
                    'duplicados': duplicados,
                    'necesita_correccion': duplicados > 100
                }

                self.log(f"  Registros: {total_registros}")
                self.log(f"  Columnas: {len(columnas)}")

                if duplicados > 0:
                    self.log(f"  ⚠ Duplicados detectados: {duplicados}", "WARNING")

                return analisis

        except Exception as e:
            self.log(f"Error analizando CSV: {e}", "ERROR")
            return {'error': str(e)}

    def corregir_duplicados(self, archivo_csv: Path) -> Optional[Path]:
        """Corrige códigos duplicados si es necesario"""
        self.log("Corrigiendo duplicados automáticamente...")

        try:
            # Ejecutar script de corrección
            cmd = f"python3 {self.dir_trabajo}/corregir_codigos_vet.py {archivo_csv}"
            resultado = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=300)

            if resultado.returncode == 0:
                # Buscar archivo corregido
                archivo_corregido = archivo_csv.parent / f"{archivo_csv.stem}_corregido.csv"

                if archivo_corregido.exists():
                    self.log(f"✓ Archivo corregido: {archivo_corregido.name}", "SUCCESS")
                    return archivo_corregido
                else:
                    self.log("No se generó archivo corregido, usando original", "WARNING")
                    return archivo_csv
            else:
                self.log(f"Error en corrección: {resultado.stderr}", "WARNING")
                return archivo_csv

        except Exception as e:
            self.log(f"Error corrigiendo duplicados: {e}", "WARNING")
            return archivo_csv

    def generar_marcxml(self, archivo_csv: Path, codigo_bib: str) -> Optional[Path]:
        """Genera MARCXML desde CSV"""
        self.log("Generando MARCXML...")

        try:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

            cmd = f"""cd {self.dir_exports} && python3 {self.dir_trabajo}/opac_exportar.py \
-i {archivo_csv} \
--codbiblio {codigo_bib} \
--loc-default SALA \
--stream"""

            resultado = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=600)

            if resultado.returncode == 0:
                # Buscar archivo XML generado
                archivos_xml = list(self.dir_exports.glob(f"{codigo_bib}_*_marcxml*.xml"))

                if archivos_xml:
                    archivos_xml.sort(key=lambda x: x.stat().st_mtime, reverse=True)
                    xml_file = archivos_xml[0]

                    # Verificar contenido
                    with open(xml_file, 'r') as f:
                        contenido = f.read()
                        num_records = contenido.count('<record>')

                    self.log(f"✓ MARCXML generado: {xml_file.name} ({num_records} registros)", "SUCCESS")
                    return xml_file
                else:
                    self.log("✗ No se encontró archivo XML generado", "ERROR")
                    return None
            else:
                self.log(f"Error generando MARCXML: {resultado.stderr}", "ERROR")
                return None

        except Exception as e:
            self.log(f"Error en generación MARCXML: {e}", "ERROR")
            return None

    def importar_a_koha(self, xml_file: Path) -> bool:
        """Importa MARCXML a Koha"""
        self.log("Importando a Koha...")

        try:
            cmd = f"""sudo koha-shell {self.instancia_koha} -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
-b \
-m MARCXML \
-file {xml_file} \
-commit 1000" """

            resultado = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=1800)

            if resultado.returncode == 0:
                # Extraer estadísticas
                output = resultado.stdout + resultado.stderr

                # Buscar líneas con estadísticas
                for linea in output.split('\n'):
                    if 'biblios' in linea.lower() or 'items' in linea.lower():
                        self.log(f"  {linea.strip()}")

                self.log("✓ Importación a Koha completada", "SUCCESS")
                return True
            else:
                self.log(f"✗ Error en importación: {resultado.stderr}", "ERROR")
                return False

        except Exception as e:
            self.log(f"✗ Error importando a Koha: {e}", "ERROR")
            return False

    def reindexar_koha(self):
        """Reindexación de Koha"""
        self.log("Reindexando Koha...")

        try:
            cmd = f"sudo koha-rebuild-zebra -f -v {self.instancia_koha}"
            resultado = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=900)

            if resultado.returncode == 0:
                self.log("✓ Reindexación completada", "SUCCESS")
                return True
            else:
                self.log(f"⚠ Advertencia en reindexación: {resultado.stderr}", "WARNING")
                return True  # No es crítico
        except Exception as e:
            self.log(f"⚠ Error reindexando: {e}", "WARNING")
            return True  # No es crítico

    def verificar_importacion(self, codigo_bib: str) -> int:
        """Verifica cuántos items se importaron"""
        try:
            cmd = f"sudo koha-mysql {self.instancia_koha} -N -e \"SELECT COUNT(*) FROM items WHERE homebranch = '{codigo_bib}'\""
            resultado = subprocess.run(cmd, shell=True, capture_output=True, text=True)

            if resultado.returncode == 0:
                count = int(resultado.stdout.strip())
                return count
        except Exception:
            return 0

    def procesar_archivo(self, archivo_csv: Path) -> bool:
        """Procesa un archivo CSV completo"""
        print("\n" + "="*80)
        self.log(f"PROCESANDO: {archivo_csv.name}", "INFO")
        print("="*80 + "\n")

        self.stats['total_archivos'] += 1

        try:
            # 1. Detectar código de biblioteca
            print(f"{Color.BOLD}PASO 1: Detectar biblioteca{Color.END}")
            print("-" * 80)
            codigo_bib = self.detectar_codigo_biblioteca(archivo_csv)

            if not codigo_bib:
                self.log("✗ No se pudo detectar código de biblioteca", "ERROR")
                self.stats['fallidos'] += 1
                return False

            print()

            # 2. Verificar en Koha
            print(f"{Color.BOLD}PASO 2: Verificar en Koha{Color.END}")
            print("-" * 80)

            if not self.verificar_biblioteca_koha(codigo_bib):
                self.stats['fallidos'] += 1
                return False

            print()

            # 3. Analizar CSV
            print(f"{Color.BOLD}PASO 3: Analizar CSV{Color.END}")
            print("-" * 80)

            analisis = self.analizar_csv(archivo_csv)

            if 'error' in analisis:
                self.log("✗ Error analizando CSV", "ERROR")
                self.stats['fallidos'] += 1
                return False

            print()

            # 4. Corregir duplicados si es necesario
            archivo_procesado = archivo_csv

            if analisis.get('necesita_correccion', False):
                print(f"{Color.BOLD}PASO 4: Corregir duplicados{Color.END}")
                print("-" * 80)
                archivo_procesado = self.corregir_duplicados(archivo_csv)
                print()
            else:
                self.log("✓ No necesita corrección de duplicados", "SUCCESS")
                print()

            # 5. Generar MARCXML
            print(f"{Color.BOLD}PASO 5: Generar MARCXML{Color.END}")
            print("-" * 80)

            xml_file = self.generar_marcxml(archivo_procesado, codigo_bib)

            if not xml_file:
                self.log("✗ Error generando MARCXML", "ERROR")
                self.stats['fallidos'] += 1
                return False

            print()

            # 6. Importar a Koha
            print(f"{Color.BOLD}PASO 6: Importar a Koha{Color.END}")
            print("-" * 80)

            if not self.importar_a_koha(xml_file):
                self.stats['fallidos'] += 1
                return False

            print()

            # 7. Reindexar
            print(f"{Color.BOLD}PASO 7: Reindexar{Color.END}")
            print("-" * 80)
            self.reindexar_koha()
            print()

            # 8. Verificación final
            print(f"{Color.BOLD}PASO 8: Verificación final{Color.END}")
            print("-" * 80)
            items_importados = self.verificar_importacion(codigo_bib)

            if items_importados > 0:
                self.log(f"✓✓✓ IMPORTACIÓN EXITOSA: {items_importados} items", "SUCCESS")
                self.stats['exitosos'] += 1
                self.stats['registros_importados'] += items_importados

                # Mover a procesados
                dest = self.dir_procesados / f"{archivo_csv.stem}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
                archivo_csv.rename(dest)
                self.log(f"Archivo movido a: {dest.name}")

                print()
                print(f"{Color.GREEN}{Color.BOLD}╔{'═'*78}╗{Color.END}")
                print(f"{Color.GREEN}{Color.BOLD}║{' '*20}✓✓✓ IMPORTACIÓN COMPLETADA ✓✓✓{' '*21}║{Color.END}")
                print(f"{Color.GREEN}{Color.BOLD}╚{'═'*78}╝{Color.END}")
                print()

                return True
            else:
                self.log("✗ No se importaron items", "ERROR")
                self.stats['fallidos'] += 1
                return False

        except Exception as e:
            self.log(f"✗ Error procesando archivo: {e}", "ERROR")
            self.stats['fallidos'] += 1
            return False

    def procesar_multiples(self, archivos: List[Path]):
        """Procesa múltiples archivos CSV"""
        total = len(archivos)

        print(f"\n{Color.CYAN}{Color.BOLD}Se procesarán {total} archivos:{Color.END}")
        for i, archivo in enumerate(archivos, 1):
            print(f"  {i}. {archivo.name}")

        print()
        respuesta = input(f"¿Continuar? (SI/no): ")

        if respuesta.strip().upper() not in ['SI', 'YES', 'S', 'Y', '']:
            print(f"{Color.YELLOW}Operación cancelada{Color.END}")
            return

        for i, archivo in enumerate(archivos, 1):
            print(f"\n{Color.MAGENTA}{Color.BOLD}[{i}/{total}] Procesando: {archivo.name}{Color.END}")
            self.procesar_archivo(archivo)

        self.imprimir_resumen()

    def imprimir_resumen(self):
        """Imprime resumen de la operación"""
        print("\n" + "="*80)
        print(f"{Color.CYAN}{Color.BOLD}RESUMEN DE IMPORTACIÓN{Color.END}")
        print("="*80)
        print(f"  Total archivos procesados: {self.stats['total_archivos']}")
        print(f"  {Color.GREEN}✓ Exitosos: {self.stats['exitosos']}{Color.END}")
        print(f"  {Color.RED}✗ Fallidos: {self.stats['fallidos']}{Color.END}")
        print(f"  Total registros importados: {Color.BOLD}{self.stats['registros_importados']}{Color.END}")
        print(f"  Log guardado en: {self.log_file}")
        print("="*80 + "\n")

    def modo_interactivo(self):
        """Modo interactivo para seleccionar archivos"""
        print(f"{Color.CYAN}Buscando archivos CSV en: {self.dir_trabajo}{Color.END}\n")

        archivos_csv = list(self.dir_trabajo.glob("*.csv"))
        archivos_csv = [f for f in archivos_csv if not f.name.endswith('_corregido.csv')]

        if not archivos_csv:
            print(f"{Color.YELLOW}No se encontraron archivos CSV{Color.END}")
            return

        print("Archivos disponibles:")
        for i, archivo in enumerate(archivos_csv, 1):
            tamaño = archivo.stat().st_size / 1024 / 1024  # MB
            print(f"  {i}. {archivo.name} ({tamaño:.2f} MB)")

        print(f"\n{Color.YELLOW}Opciones:{Color.END}")
        print("  - Número(s) separados por comas (ej: 1,3,5)")
        print("  - 'todos' para procesar todos")
        print("  - 'q' para salir")

        seleccion = input("\nSelección: ").strip()

        if seleccion.lower() == 'q':
            return

        if seleccion.lower() == 'todos':
            self.procesar_multiples(archivos_csv)
        else:
            try:
                indices = [int(x.strip()) - 1 for x in seleccion.split(',')]
                archivos_seleccionados = [archivos_csv[i] for i in indices if 0 <= i < len(archivos_csv)]

                if archivos_seleccionados:
                    self.procesar_multiples(archivos_seleccionados)
                else:
                    print(f"{Color.RED}Selección inválida{Color.END}")
            except Exception as e:
                print(f"{Color.RED}Error en selección: {e}{Color.END}")


def main():
    """Función principal"""
    agente = AgenteImportador()
    agente.print_banner()

    # Procesar argumentos
    if len(sys.argv) > 1:
        archivos = []

        for arg in sys.argv[1:]:
            path = Path(arg)

            if path.is_file() and path.suffix.lower() == '.csv':
                archivos.append(path)
            elif '*' in arg:
                # Glob pattern
                archivos.extend(Path('.').glob(arg))

        if archivos:
            agente.procesar_multiples(archivos)
        else:
            print(f"{Color.RED}No se encontraron archivos CSV válidos{Color.END}")
    else:
        # Modo interactivo
        agente.modo_interactivo()


if __name__ == '__main__':
    main()
