#!/usr/bin/env python3
"""
SISTEMA AUTOMATIZADO DE MIGRACIÓN KOHA
=======================================
Orquestador maestro que automatiza TODO el proceso de migración
desde múltiples fuentes (CSV, Firebird local, Firebird remoto)
hasta Koha, con validación, importación y verificación automática.

Universidad Nacional de Asunción
Versión: 1.0 - Sistema Totalmente Automatizado
Fecha: 2025-01-15
"""

import os
import sys
import json
import subprocess
import argparse
import logging
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional
import time


class Color:
    """Colores para terminal"""
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    RED = '\033[91m'
    BLUE = '\033[94m'
    CYAN = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'


class MigracionAutomatizada:
    """Orquestador principal de migración automatizada"""

    def __init__(self, config_file='migracion_config.json'):
        self.config_file = config_file
        self.logger = None  # Initialize logger as None first
        self.config = self.cargar_configuracion()
        self.logger = self.setup_logging()
        self.stats = {
            'bibliotecas_procesadas': 0,
            'bibliotecas_exitosas': 0,
            'bibliotecas_fallidas': 0,
            'total_registros': 0,
            'inicio': datetime.now()
        }

    def setup_logging(self):
        """Configura logging centralizado"""
        log_dir = Path(self.config.get('rutas', {}).get('logs', './logs'))
        log_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        log_file = log_dir / f'migracion_auto_{timestamp}.log'

        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(log_file, encoding='utf-8'),
                logging.StreamHandler()
            ]
        )
        return logging.getLogger('MigracionKoha')

    def cargar_configuracion(self):
        """Carga configuración del sistema"""
        if not os.path.exists(self.config_file):
            self.crear_configuracion_inicial()

        with open(self.config_file, 'r', encoding='utf-8') as f:
            return json.load(f)

    def crear_configuracion_inicial(self):
        """Crea configuración inicial con todas las bibliotecas"""
        config = {
            "_descripcion": "Configuración del sistema automatizado de migración",
            "_version": "1.0",

            "koha": {
                "instancia": "koha-cnc",
                "usuario_shell": "root",
                "commit_size": 1000,
                "rebuild_indices": True,
                "motor_busqueda": "zebra"  # o "elasticsearch"
            },

            "rutas": {
                "trabajo": "/home/mvillalba/migradatos",
                "exports": "/home/mvillalba/migradatos/exports",
                "logs": "/home/mvillalba/migradatos/logs",
                "backups": "/home/mvillalba/migradatos/backups"
            },

            "automatizacion": {
                "validar_antes_importar": True,
                "crear_backup_antes": True,
                "notificar_email": True,
                "pausar_entre_bibliotecas": 5,
                "reintentos_en_error": 2
            },

            "email": {
                "activado": False,
                "smtp_server": "smtp.una.py",
                "smtp_port": 587,
                "usuario": "biblioteca@una.py",
                "password": "",
                "destinatarios": ["admin@una.py"]
            },

            "bibliotecas": {
                "POL": {
                    "nombre": "Biblioteca Politécnica",
                    "tipo_fuente": "csv",
                    "archivo_csv": "POL.csv",
                    "codigo_koha": "POL",
                    "loc_default": "SALA",
                    "activa": True,
                    "prioridad": 1
                },
                "ARQ": {
                    "nombre": "Arquitectura",
                    "tipo_fuente": "csv",
                    "archivo_csv": "ARQ.csv",
                    "codigo_koha": "ARQ",
                    "loc_default": "SALA",
                    "activa": True,
                    "prioridad": 2
                },
                "FACAGR": {
                    "nombre": "Facultad de Ciencias Agrarias",
                    "tipo_fuente": "firebird_remoto",
                    "firebird": {
                        "host": "192.168.1.10",
                        "port": 3050,
                        "database": "/datos/biblio.fdb",
                        "user": "SYSDBA",
                        "password": "masterkey"
                    },
                    "codigo_koha": "FACAGR",
                    "loc_default": "SALA",
                    "activa": False,
                    "prioridad": 3
                }
            }
        }

        with open(self.config_file, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)

        self.print_success(f"Configuración creada: {self.config_file}")
        self.print_info("Edite el archivo para activar/desactivar bibliotecas")

    def print_header(self, texto):
        """Imprime cabecera destacada"""
        print(f"\n{Color.BOLD}{Color.CYAN}{'='*70}")
        print(f"{texto:^70}")
        print(f"{'='*70}{Color.END}\n")

    def print_success(self, texto):
        """Mensaje de éxito"""
        print(f"{Color.GREEN}✓ {texto}{Color.END}")
        if self.logger:
            self.logger.info(texto)

    def print_error(self, texto):
        """Mensaje de error"""
        print(f"{Color.RED}✗ {texto}{Color.END}")
        if self.logger:
            self.logger.error(texto)

    def print_info(self, texto):
        """Mensaje informativo"""
        print(f"{Color.BLUE}ℹ {texto}{Color.END}")
        if self.logger:
            self.logger.info(texto)

    def print_warning(self, texto):
        """Mensaje de advertencia"""
        print(f"{Color.YELLOW}⚠ {texto}{Color.END}")
        if self.logger:
            self.logger.warning(texto)

    def ejecutar_comando(self, comando: str, descripcion: str = "") -> bool:
        """Ejecuta comando de shell y captura salida"""
        if descripcion:
            self.print_info(f"{descripcion}...")

        try:
            resultado = subprocess.run(
                comando,
                shell=True,
                capture_output=True,
                text=True,
                timeout=3600  # 1 hora max
            )

            if resultado.returncode == 0:
                if descripcion:
                    self.print_success(f"{descripcion} completado")
                return True
            else:
                self.print_error(f"Error: {resultado.stderr[:200]}")
                return False

        except subprocess.TimeoutExpired:
            self.print_error(f"Timeout ejecutando: {descripcion}")
            return False
        except Exception as e:
            self.print_error(f"Error: {e}")
            return False

    def verificar_requisitos(self) -> bool:
        """Verifica que todos los requisitos estén instalados"""
        self.print_header("VERIFICANDO REQUISITOS")

        requisitos = {
            'Python 3': 'python3 --version',
            'Koha': f'sudo koha-list | grep {self.config["koha"]["instancia"]}',
            'xmllint': 'xmllint --version',
            'Librería fdb': 'python3 -c "import fdb"'
        }

        todos_ok = True
        for nombre, comando in requisitos.items():
            if self.ejecutar_comando(comando, f"Verificando {nombre}"):
                self.print_success(f"{nombre} disponible")
            else:
                self.print_error(f"{nombre} NO disponible")
                todos_ok = False

        return todos_ok

    def crear_directorios(self):
        """Crea estructura de directorios necesaria"""
        for key, ruta in self.config['rutas'].items():
            Path(ruta).mkdir(parents=True, exist_ok=True)
        self.print_success("Directorios de trabajo creados")

    def crear_backup_koha(self) -> bool:
        """Crea backup de Koha antes de importar"""
        if not self.config['automatizacion']['crear_backup_antes']:
            return True

        self.print_info("Creando backup de Koha...")

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        backup_file = f"{self.config['rutas']['backups']}/koha_backup_{timestamp}.sql"

        comando = f"sudo koha-dump {self.config['koha']['instancia']} > {backup_file}"

        if self.ejecutar_comando(comando, "Generando backup"):
            self.print_success(f"Backup creado: {backup_file}")
            return True
        else:
            self.print_warning("No se pudo crear backup (continuando de todas formas)")
            return False

    def generar_marcxml_desde_csv(self, biblioteca_cod: str, config_bib: Dict) -> Optional[str]:
        """Genera MARCXML desde CSV"""
        csv_file = config_bib['archivo_csv']
        ruta_csv = os.path.join(self.config['rutas']['trabajo'], csv_file)

        if not os.path.exists(ruta_csv):
            self.print_error(f"No se encontró: {ruta_csv}")
            return None

        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        output_base = f"{biblioteca_cod}_{timestamp}_marcxml"

        comando = f"""cd {self.config['rutas']['exports']} && \
python3 {self.config['rutas']['trabajo']}/opac_exportar.py \
  -i {ruta_csv} \
  --codbiblio {config_bib['codigo_koha']} \
  --loc-default {config_bib['loc_default']} \
  --stream \
  --split-by 5000"""

        if self.ejecutar_comando(comando, f"Generando MARCXML de {biblioteca_cod}"):
            # Buscar archivos generados
            archivos = list(Path(self.config['rutas']['exports']).glob(f"{biblioteca_cod}_*_marcxml*.xml"))
            if archivos:
                return str(archivos[0])
        return None

    def validar_marcxml(self, archivo_xml: str) -> bool:
        """Valida archivo MARCXML"""
        comando = f"xmllint --noout {archivo_xml}"
        return self.ejecutar_comando(comando, f"Validando {Path(archivo_xml).name}")

    def importar_a_koha(self, archivo_xml: str, biblioteca_cod: str) -> bool:
        """Importa archivo MARCXML a Koha"""
        instancia = self.config['koha']['instancia']
        commit_size = self.config['koha']['commit_size']

        comando = f"""sudo koha-shell {instancia} -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
  -b \
  -m MARCXML \
  -file {archivo_xml} \
  -commit {commit_size}\""""

        return self.ejecutar_comando(comando, f"Importando {biblioteca_cod} a Koha")

    def rebuild_indices(self) -> bool:
        """Reconstruye índices de Koha"""
        instancia = self.config['koha']['instancia']
        motor = self.config['koha']['motor_busqueda']

        if motor == 'elasticsearch':
            comando = f"sudo koha-elasticsearch --rebuild -v {instancia}"
        else:
            comando = f"sudo koha-rebuild-zebra -f -v {instancia}"

        return self.ejecutar_comando(comando, "Reconstruyendo índices")

    def verificar_importacion(self, biblioteca_cod: str) -> Dict:
        """Verifica que la importación fue exitosa"""
        instancia = self.config['koha']['instancia']

        # Contar registros en Koha
        comando = f"""sudo koha-mysql {instancia} -e "
SELECT
    homebranch,
    COUNT(*) as total_items
FROM items
WHERE homebranch = '{biblioteca_cod}'
GROUP BY homebranch"
"""

        resultado = subprocess.run(comando, shell=True, capture_output=True, text=True)

        if resultado.returncode == 0 and resultado.stdout:
            lineas = resultado.stdout.strip().split('\n')
            if len(lineas) > 1:
                datos = lineas[1].split('\t')
                if len(datos) >= 2:
                    return {
                        'biblioteca': datos[0],
                        'items': int(datos[1])
                    }

        return {'biblioteca': biblioteca_cod, 'items': 0}

    def procesar_biblioteca(self, codigo: str, config: Dict) -> bool:
        """Procesa una biblioteca completa"""
        self.print_header(f"PROCESANDO: {config['nombre']}")

        try:
            # 1. Generar MARCXML
            if config['tipo_fuente'] == 'csv':
                archivo_xml = self.generar_marcxml_desde_csv(codigo, config)
            elif config['tipo_fuente'] == 'firebird_remoto':
                # TODO: Implementar extracción desde Firebird
                self.print_warning("Firebird remoto aún no implementado")
                return False
            else:
                self.print_error(f"Tipo de fuente desconocido: {config['tipo_fuente']}")
                return False

            if not archivo_xml:
                self.print_error("No se pudo generar MARCXML")
                return False

            # 2. Validar MARCXML
            if self.config['automatizacion']['validar_antes_importar']:
                if not self.validar_marcxml(archivo_xml):
                    self.print_error("Validación de XML falló")
                    return False

            # 3. Importar a Koha
            if not self.importar_a_koha(archivo_xml, codigo):
                self.print_error("Importación a Koha falló")
                return False

            # 4. Verificar
            verificacion = self.verificar_importacion(codigo)
            self.print_success(f"Importados {verificacion['items']} ítems de {codigo}")

            self.stats['total_registros'] += verificacion['items']
            self.stats['bibliotecas_exitosas'] += 1

            return True

        except Exception as e:
            self.print_error(f"Error procesando {codigo}: {e}")
            self.stats['bibliotecas_fallidas'] += 1
            return False

    def ejecutar_migracion_completa(self):
        """Ejecuta migración completa de todas las bibliotecas activas"""
        self.print_header("SISTEMA AUTOMATIZADO DE MIGRACIÓN KOHA")
        self.print_info(f"Inicio: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

        # 1. Verificar requisitos
        if not self.verificar_requisitos():
            self.print_error("Faltan requisitos. Abortando.")
            return False

        # 2. Crear directorios
        self.crear_directorios()

        # 3. Backup de Koha
        self.crear_backup_koha()

        # 4. Obtener bibliotecas activas y ordenar por prioridad
        bibliotecas_activas = {
            cod: cfg for cod, cfg in self.config['bibliotecas'].items()
            if cfg.get('activa', False)
        }

        bibliotecas_ordenadas = sorted(
            bibliotecas_activas.items(),
            key=lambda x: x[1].get('prioridad', 999)
        )

        total_bibliotecas = len(bibliotecas_ordenadas)

        if total_bibliotecas == 0:
            self.print_warning("No hay bibliotecas activas para procesar")
            return False

        self.print_info(f"Bibliotecas a procesar: {total_bibliotecas}")

        # 5. Procesar cada biblioteca
        for idx, (codigo, config) in enumerate(bibliotecas_ordenadas, 1):
            self.print_info(f"\nProcesando biblioteca {idx}/{total_bibliotecas}")

            self.stats['bibliotecas_procesadas'] += 1

            exito = self.procesar_biblioteca(codigo, config)

            if exito:
                self.print_success(f"{config['nombre']} procesada exitosamente")
            else:
                self.print_error(f"{config['nombre']} falló")

            # Pausa entre bibliotecas
            if idx < total_bibliotecas:
                pausa = self.config['automatizacion']['pausar_entre_bibliotecas']
                self.print_info(f"Pausa de {pausa} segundos...")
                time.sleep(pausa)

        # 6. Rebuild índices global
        if self.config['koha']['rebuild_indices']:
            self.rebuild_indices()

        # 7. Mostrar resumen
        self.mostrar_resumen()

        return True

    def mostrar_resumen(self):
        """Muestra resumen final de la migración"""
        fin = datetime.now()
        duracion = fin - self.stats['inicio']

        self.print_header("RESUMEN DE MIGRACIÓN")

        print(f"Inicio: {self.stats['inicio'].strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Fin: {fin.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"Duración: {duracion}")
        print()
        print(f"Bibliotecas procesadas: {self.stats['bibliotecas_procesadas']}")
        print(f"  {Color.GREEN}✓ Exitosas: {self.stats['bibliotecas_exitosas']}{Color.END}")
        print(f"  {Color.RED}✗ Fallidas: {self.stats['bibliotecas_fallidas']}{Color.END}")
        print()
        print(f"Total de registros importados: {self.stats['total_registros']:,}")
        print()

        if self.stats['bibliotecas_fallidas'] == 0:
            self.print_success("¡MIGRACIÓN COMPLETADA EXITOSAMENTE!")
        else:
            self.print_warning("Migración completada con algunos errores")

        print()


def main():
    """Función principal"""
    parser = argparse.ArgumentParser(
        description='Sistema Automatizado de Migración a Koha',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Ejemplos de uso:

  # Ejecutar migración completa automática
  python3 migracion_automatizada.py --auto

  # Verificar requisitos solamente
  python3 migracion_automatizada.py --verificar

  # Procesar una biblioteca específica
  python3 migracion_automatizada.py --biblioteca POL

  # Crear configuración inicial
  python3 migracion_automatizada.py --init

Modo automático:
  El sistema procesará todas las bibliotecas marcadas como activas
  en migracion_config.json, en orden de prioridad, con validación
  y verificación automática.
        '''
    )

    parser.add_argument('--auto', action='store_true', help='Ejecutar migración automática completa')
    parser.add_argument('--verificar', action='store_true', help='Solo verificar requisitos')
    parser.add_argument('--biblioteca', type=str, help='Procesar una biblioteca específica')
    parser.add_argument('--init', action='store_true', help='Crear configuración inicial')
    parser.add_argument('--config', type=str, default='migracion_config.json', help='Archivo de configuración')

    args = parser.parse_args()

    sistema = MigracionAutomatizada(args.config)

    if args.init:
        print("✓ Configuración creada")
        print(f"\nEdite {args.config} y luego ejecute:")
        print("  python3 migracion_automatizada.py --auto")
        return

    if args.verificar:
        if sistema.verificar_requisitos():
            sistema.print_success("Todos los requisitos están disponibles")
        else:
            sistema.print_error("Faltan algunos requisitos")
        return

    if args.biblioteca:
        if args.biblioteca in sistema.config['bibliotecas']:
            config = sistema.config['bibliotecas'][args.biblioteca]
            sistema.procesar_biblioteca(args.biblioteca, config)
        else:
            sistema.print_error(f"Biblioteca '{args.biblioteca}' no encontrada en configuración")
        return

    if args.auto:
        sistema.ejecutar_migracion_completa()
        return

    # Si no hay argumentos, mostrar ayuda
    parser.print_help()


if __name__ == '__main__':
    main()
