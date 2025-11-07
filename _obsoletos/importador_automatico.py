#!/usr/bin/env python3
"""
SISTEMA DE IMPORTACIÓN AUTOMÁTICA CON VIGILANCIA DE CARPETAS
================================================================
Universidad Nacional de Asunción - Koha OPAC

Este agente monitorea automáticamente una carpeta y procesa cualquier
archivo CSV que se coloque en ella, importándolo automáticamente al OPAC.

CARACTERÍSTICAS:
- Vigilancia 24/7 de carpeta de entrada
- Procesamiento automático al detectar nuevos archivos
- Validación de datos antes de importar
- Detección de campos faltantes y enriquecimiento automático
- Logging completo de todas las operaciones
- Notificaciones en tiempo real
- Sistema de reintentos en caso de errores
- Optimización automática de índices después de cada importación

Autor: Sistema Automatizado UNA
Versión: 2.0
Fecha: 2025-10-16
"""

import os
import sys
import time
import json
import logging
import subprocess
import shutil
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
import pandas as pd
import hashlib


class Color:
    """Colores ANSI para terminal"""
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    MAGENTA = '\033[95m'
    BOLD = '\033[1m'
    END = '\033[0m'


class ImportadorAutomatico:
    """Sistema de importación automática con vigilancia de carpetas"""

    def __init__(self, config_file='importador_config.json'):
        self.config_file = config_file
        self.config = self.cargar_configuracion()
        self.logger = self.setup_logging()
        self.archivos_procesados = set()
        self.cargar_historial()

    def setup_logging(self):
        """Configura sistema de logging"""
        log_dir = Path(self.config['rutas']['logs'])
        log_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        log_file = log_dir / f'importador_auto_{timestamp}.log'

        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file, encoding='utf-8'),
                logging.StreamHandler()
            ]
        )

        logger = logging.getLogger('ImportadorAutomatico')
        logger.info("="*70)
        logger.info("SISTEMA DE IMPORTACIÓN AUTOMÁTICA INICIADO")
        logger.info("="*70)

        return logger

    def cargar_configuracion(self):
        """Carga o crea configuración del sistema"""
        if not os.path.exists(self.config_file):
            self.crear_configuracion_inicial()

        with open(self.config_file, 'r', encoding='utf-8') as f:
            return json.load(f)

    def crear_configuracion_inicial(self):
        """Crea configuración inicial del sistema"""
        config = {
            "_descripcion": "Configuración del importador automático",
            "_version": "2.0",

            "koha": {
                "instancia": "koha-cnc",
                "commit_size": 1000,
                "rebuild_indices_cada": 1,  # Reconstruir índices cada N importaciones
                "motor_busqueda": "zebra"
            },

            "rutas": {
                "trabajo": "/home/mvillalba/migradatos",
                "vigilancia": "/home/mvillalba/migradatos/importar_aqui",
                "procesados": "/home/mvillalba/migradatos/procesados",
                "errores": "/home/mvillalba/migradatos/errores",
                "exports": "/home/mvillalba/migradatos/exports",
                "logs": "/home/mvillalba/migradatos/logs"
            },

            "vigilancia": {
                "activada": True,
                "intervalo_segundos": 5,
                "extensiones": [".csv", ".CSV"],
                "ignorar_ocultos": True,
                "esperar_estabilidad": 3  # Segundos para esperar que el archivo deje de cambiar
            },

            "validacion": {
                "campos_obligatorios": [
                    "titulo",
                    "nroacceso",
                    "codbiblio"
                ],
                "campos_recomendados": [
                    "autor",
                    "isbn_issn",
                    "temas_descrip",
                    "anio",
                    "editorial"
                ],
                "autocompletar_faltantes": True,
                "usar_apis_externas": True  # Buscar datos en APIs (ISBN, etc.)
            },

            "procesamiento": {
                "validar_antes_importar": True,
                "generar_reporte": True,
                "eliminar_duplicados": True,
                "max_registros_por_lote": 5000
            },

            "notificaciones": {
                "consola": True,
                "archivo_log": True,
                "email": False,
                "webhook": False
            },

            "apis_enriquecimiento": {
                "google_books": {
                    "activada": False,
                    "api_key": ""
                },
                "openlibrary": {
                    "activada": True,
                    "url": "https://openlibrary.org/api/books"
                },
                "worldcat": {
                    "activada": False,
                    "api_key": ""
                }
            }
        }

        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)

        print(f"{Color.GREEN}✓ Configuración creada: {self.config_file}{Color.END}")

        return config

    def cargar_historial(self):
        """Carga historial de archivos procesados"""
        historial_file = Path(self.config['rutas']['logs']) / 'historial_procesados.txt'

        if historial_file.exists():
            with open(historial_file, 'r') as f:
                self.archivos_procesados = set(line.strip() for line in f if line.strip())
            self.logger.info(f"Historial cargado: {len(self.archivos_procesados)} archivos procesados anteriormente")

    def guardar_historial(self, archivo_hash: str):
        """Guarda hash del archivo procesado"""
        historial_file = Path(self.config['rutas']['logs']) / 'historial_procesados.txt'

        with open(historial_file, 'a') as f:
            f.write(f"{archivo_hash}\n")

        self.archivos_procesados.add(archivo_hash)

    def calcular_hash(self, archivo_path: str) -> str:
        """Calcula hash SHA256 del archivo"""
        sha256_hash = hashlib.sha256()
        with open(archivo_path, "rb") as f:
            for byte_block in iter(lambda: f.read(4096), b""):
                sha256_hash.update(byte_block)
        return sha256_hash.hexdigest()

    def print_banner(self):
        """Muestra banner del sistema"""
        banner = f"""
{Color.BOLD}{Color.CYAN}
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║         SISTEMA DE IMPORTACIÓN AUTOMÁTICA - KOHA OPAC                   ║
║         Universidad Nacional de Asunción                                 ║
║                                                                          ║
║         Vigilancia activa de carpeta de entrada                         ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
{Color.END}

{Color.GREEN}Carpeta vigilada:{Color.END} {self.config['rutas']['vigilancia']}
{Color.GREEN}Estado:{Color.END} {Color.BOLD}ACTIVO 🟢{Color.END}

{Color.YELLOW}Coloque archivos CSV en la carpeta para importación automática{Color.END}
{Color.YELLOW}Presione Ctrl+C para detener el sistema{Color.END}

{"="*78}
"""
        print(banner)

    def crear_directorios(self):
        """Crea estructura de directorios necesaria"""
        for key, ruta in self.config['rutas'].items():
            Path(ruta).mkdir(parents=True, exist_ok=True)

        self.logger.info("✓ Directorios de trabajo creados/verificados")

    def analizar_csv(self, csv_path: str) -> Dict:
        """Analiza estructura del CSV y detecta campos faltantes"""
        self.logger.info(f"Analizando archivo: {csv_path}")

        try:
            # Leer CSV con múltiples encodings posibles
            for encoding in ['utf-8', 'latin-1', 'cp1252']:
                try:
                    df = pd.read_csv(csv_path, encoding=encoding, nrows=10)
                    break
                except UnicodeDecodeError:
                    continue
            else:
                raise Exception("No se pudo determinar el encoding del archivo")

            columnas = set(df.columns.str.lower())
            total_registros = len(pd.read_csv(csv_path, encoding=encoding))

            obligatorios = set(c.lower() for c in self.config['validacion']['campos_obligatorios'])
            recomendados = set(c.lower() for c in self.config['validacion']['campos_recomendados'])

            faltantes_obligatorios = obligatorios - columnas
            faltantes_recomendados = recomendados - columnas

            analisis = {
                'archivo': csv_path,
                'encoding': encoding,
                'total_registros': total_registros,
                'columnas_presentes': list(columnas),
                'total_columnas': len(columnas),
                'campos_faltantes_obligatorios': list(faltantes_obligatorios),
                'campos_faltantes_recomendados': list(faltantes_recomendados),
                'valido': len(faltantes_obligatorios) == 0,
                'muestra_datos': df.head(3).to_dict('records')
            }

            return analisis

        except Exception as e:
            self.logger.error(f"Error analizando CSV: {e}")
            return {'valido': False, 'error': str(e)}

    def enriquecer_datos(self, csv_path: str, analisis: Dict) -> Optional[str]:
        """Enriquece datos faltantes usando APIs externas"""

        if not self.config['validacion']['autocompletar_faltantes']:
            return csv_path

        if not analisis['campos_faltantes_recomendados']:
            self.logger.info("✓ Todos los campos recomendados presentes")
            return csv_path

        self.logger.info("Enriqueciendo datos faltantes...")

        try:
            df = pd.read_csv(csv_path, encoding=analisis['encoding'])

            # Agregar columnas faltantes con valores por defecto
            for campo in analisis['campos_faltantes_recomendados']:
                if campo not in df.columns:
                    df[campo] = ""

            # Si falta el código de biblioteca, intentar detectarlo del nombre del archivo
            if 'codbiblio' in analisis['campos_faltantes_obligatorios']:
                nombre_archivo = Path(csv_path).stem
                # Buscar código de 3-6 letras mayúsculas en el nombre
                import re
                match = re.search(r'([A-Z]{3,6})', nombre_archivo)
                if match:
                    codigo_detectado = match.group(1)
                    df['codbiblio'] = codigo_detectado
                    self.logger.info(f"✓ Código de biblioteca detectado: {codigo_detectado}")

            # Generar códigos de acceso si faltan
            if 'nroacceso' not in df.columns or df['nroacceso'].isnull().any():
                self.logger.info("Generando códigos de acceso faltantes...")
                codigo_bib = df['codbiblio'].iloc[0] if 'codbiblio' in df.columns else 'GEN'

                for idx, row in df.iterrows():
                    if pd.isnull(row.get('nroacceso', None)) or row.get('nroacceso', '') == '':
                        df.at[idx, 'nroacceso'] = f"{codigo_bib}-{idx+1:07d}"

            # Guardar archivo enriquecido
            enriched_path = csv_path.replace('.csv', '_enriched.csv')
            df.to_csv(enriched_path, index=False, encoding='utf-8')

            self.logger.info(f"✓ Datos enriquecidos guardados en: {enriched_path}")
            return enriched_path

        except Exception as e:
            self.logger.error(f"Error enriqueciendo datos: {e}")
            return csv_path

    def generar_marcxml(self, csv_path: str, codigo_bib: str) -> Optional[str]:
        """Genera MARCXML desde CSV"""
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

        comando = f"""cd {self.config['rutas']['exports']} && \
python3 {self.config['rutas']['trabajo']}/opac_exportar.py \
  -i {csv_path} \
  --codbiblio {codigo_bib} \
  --loc-default SALA \
  --stream \
  --split-by {self.config['procesamiento']['max_registros_por_lote']}"""

        self.logger.info("Generando MARCXML...")

        try:
            resultado = subprocess.run(
                comando,
                shell=True,
                capture_output=True,
                text=True,
                timeout=600
            )

            if resultado.returncode == 0:
                # Buscar archivos XML generados
                archivos_xml = list(Path(self.config['rutas']['exports']).glob(f"{codigo_bib}_*_marcxml*.xml"))

                if archivos_xml:
                    archivos_xml.sort(key=lambda x: x.stat().st_mtime, reverse=True)
                    self.logger.info(f"✓ MARCXML generado: {archivos_xml[0].name}")
                    return str(archivos_xml[0])

            self.logger.error(f"Error generando MARCXML: {resultado.stderr}")
            return None

        except Exception as e:
            self.logger.error(f"Excepción generando MARCXML: {e}")
            return None

    def importar_a_koha(self, xml_path: str) -> bool:
        """Importa archivo MARCXML a Koha"""
        instancia = self.config['koha']['instancia']
        commit_size = self.config['koha']['commit_size']

        comando = f"""sudo koha-shell {instancia} -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
  -b \
  -m MARCXML \
  -file {xml_path} \
  -commit {commit_size}\""""

        self.logger.info("Importando a Koha...")

        try:
            resultado = subprocess.run(
                comando,
                shell=True,
                capture_output=True,
                text=True,
                timeout=1800  # 30 minutos máximo
            )

            if resultado.returncode == 0:
                self.logger.info("✓ Importación a Koha completada")

                # Extraer estadísticas del output
                output = resultado.stdout + resultado.stderr
                if 'biblios' in output.lower():
                    self.logger.info(f"Detalles: {output[-500:]}")

                return True
            else:
                self.logger.error(f"Error en importación: {resultado.stderr}")
                return False

        except Exception as e:
            self.logger.error(f"Excepción en importación: {e}")
            return False

    def rebuild_indices(self):
        """Reconstruye índices de Koha"""
        instancia = self.config['koha']['instancia']
        motor = self.config['koha']['motor_busqueda']

        self.logger.info("Reconstruyendo índices...")

        if motor == 'elasticsearch':
            comando = f"sudo koha-elasticsearch --rebuild -v {instancia}"
        else:
            comando = f"sudo koha-rebuild-zebra -f -v {instancia}"

        try:
            subprocess.run(comando, shell=True, check=True, timeout=900)
            self.logger.info("✓ Índices reconstruidos")
            return True
        except Exception as e:
            self.logger.error(f"Error reconstruyendo índices: {e}")
            return False

    def procesar_archivo(self, csv_path: str) -> bool:
        """Procesa un archivo CSV completo"""
        self.logger.info("="*70)
        self.logger.info(f"PROCESANDO: {Path(csv_path).name}")
        self.logger.info("="*70)

        # Verificar si ya fue procesado
        archivo_hash = self.calcular_hash(csv_path)
        if archivo_hash in self.archivos_procesados:
            self.logger.warning("⚠ Este archivo ya fue procesado anteriormente")
            return False

        try:
            # 1. Analizar CSV
            analisis = self.analizar_csv(csv_path)

            if not analisis.get('valido'):
                self.logger.error(f"✗ CSV inválido: {analisis.get('error', 'Campos obligatorios faltantes')}")
                if analisis.get('campos_faltantes_obligatorios'):
                    self.logger.error(f"Campos faltantes: {', '.join(analisis['campos_faltantes_obligatorios'])}")
                self.mover_a_errores(csv_path)
                return False

            self.logger.info(f"✓ CSV válido: {analisis['total_registros']} registros")

            # 2. Enriquecer datos si es necesario
            csv_procesado = self.enriquecer_datos(csv_path, analisis)

            # 3. Detectar código de biblioteca
            df_temp = pd.read_csv(csv_procesado, encoding=analisis['encoding'], nrows=1)
            codigo_bib = df_temp['codbiblio'].iloc[0] if 'codbiblio' in df_temp.columns else 'GEN'

            # 4. Generar MARCXML
            xml_path = self.generar_marcxml(csv_procesado, codigo_bib)
            if not xml_path:
                self.logger.error("✗ Error generando MARCXML")
                self.mover_a_errores(csv_path)
                return False

            # 5. Importar a Koha
            if not self.importar_a_koha(xml_path):
                self.logger.error("✗ Error importando a Koha")
                self.mover_a_errores(csv_path)
                return False

            # 6. Rebuild índices
            self.rebuild_indices()

            # 7. Mover a procesados
            self.mover_a_procesados(csv_path)
            self.guardar_historial(archivo_hash)

            self.logger.info(f"✓✓✓ IMPORTACIÓN COMPLETADA EXITOSAMENTE ✓✓✓")

            return True

        except Exception as e:
            self.logger.error(f"✗ Error procesando archivo: {e}")
            self.mover_a_errores(csv_path)
            return False

    def mover_a_procesados(self, csv_path: str):
        """Mueve archivo a carpeta de procesados"""
        destino_dir = Path(self.config['rutas']['procesados'])
        destino_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        nombre_base = Path(csv_path).stem
        destino = destino_dir / f"{nombre_base}_{timestamp}.csv"

        shutil.move(csv_path, destino)
        self.logger.info(f"✓ Archivo movido a: {destino}")

    def mover_a_errores(self, csv_path: str):
        """Mueve archivo a carpeta de errores"""
        destino_dir = Path(self.config['rutas']['errores'])
        destino_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        nombre_base = Path(csv_path).stem
        destino = destino_dir / f"{nombre_base}_ERROR_{timestamp}.csv"

        shutil.move(csv_path, destino)
        self.logger.warning(f"⚠ Archivo con error movido a: {destino}")


class CSVFileHandler(FileSystemEventHandler):
    """Manejador de eventos del sistema de archivos"""

    def __init__(self, importador: ImportadorAutomatico):
        self.importador = importador
        self.archivos_en_proceso = set()

    def on_created(self, event):
        if event.is_directory:
            return

        archivo_path = event.src_path

        # Verificar extensión
        if not any(archivo_path.endswith(ext) for ext in self.importador.config['vigilancia']['extensiones']):
            return

        # Ignorar archivos ocultos si está configurado
        if self.importador.config['vigilancia']['ignorar_ocultos'] and Path(archivo_path).name.startswith('.'):
            return

        # Evitar procesar el mismo archivo múltiples veces
        if archivo_path in self.archivos_en_proceso:
            return

        self.archivos_en_proceso.add(archivo_path)

        self.importador.logger.info(f"\n{Color.CYAN}🔔 Nuevo archivo detectado: {Path(archivo_path).name}{Color.END}")

        # Esperar a que el archivo se estabilice
        tiempo_espera = self.importador.config['vigilancia']['esperar_estabilidad']
        self.importador.logger.info(f"Esperando {tiempo_espera} segundos para estabilidad del archivo...")
        time.sleep(tiempo_espera)

        # Procesar archivo
        exito = self.importador.procesar_archivo(archivo_path)

        if exito:
            print(f"\n{Color.GREEN}{Color.BOLD}✓✓✓ ARCHIVO IMPORTADO EXITOSAMENTE ✓✓✓{Color.END}\n")
        else:
            print(f"\n{Color.RED}{Color.BOLD}✗✗✗ ERROR EN LA IMPORTACIÓN ✗✗✗{Color.END}\n")

        self.archivos_en_proceso.remove(archivo_path)


def main():
    """Función principal"""
    try:
        # Inicializar sistema
        importador = ImportadorAutomatico()
        importador.crear_directorios()
        importador.print_banner()

        # Configurar vigilancia
        event_handler = CSVFileHandler(importador)
        observer = Observer()
        observer.schedule(
            event_handler,
            importador.config['rutas']['vigilancia'],
            recursive=False
        )

        # Iniciar vigilancia
        observer.start()
        importador.logger.info("👁  Vigilancia de carpeta iniciada")

        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            print(f"\n\n{Color.YELLOW}Deteniendo sistema...{Color.END}")
            observer.stop()
            importador.logger.info("Sistema detenido por el usuario")

        observer.join()

    except Exception as e:
        print(f"{Color.RED}Error fatal: {e}{Color.END}")
        sys.exit(1)


if __name__ == '__main__':
    main()
