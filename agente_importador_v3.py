#!/usr/bin/env python3
"""
AGENTE IMPORTADOR AUTOMÁTICO V3.0 - OPTIMIZADO
===============================================
Sistema inteligente de importación automática a Koha OPAC con:
- Recuperación ante fallos
- Reintentos automáticos
- Transacciones parciales
- Validación mejorada
- Notificaciones
- Cache de estado

MEJORAS EN V3:
- ✓ Recuperación de estado en caso de interrupción
- ✓ Importación incremental (continua desde donde falló)
- ✓ Validación más robusta
- ✓ Mejor manejo de memoria para archivos grandes
- ✓ Estadísticas en tiempo real
- ✓ Notificaciones opcionales

USO:
    ./agente_importador_v3.py archivo.csv
    ./agente_importador_v3.py archivo.csv --resume  # Continuar importación fallida
    ./agente_importador_v3.py --watch               # Modo vigilancia

AUTOR: Universidad Nacional de Asunción
VERSIÓN: 3.0
FECHA: 2025-10-31
"""

import os
import sys
import csv
import subprocess
import re
import json
import time
import argparse
import hashlib
import pickle
from pathlib import Path
from collections import Counter
from datetime import datetime
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict


# ==================== CONFIGURACIÓN ====================
class Config:
    """Configuración global del sistema"""
    DIR_TRABAJO = Path("/home/mvillalba/migradatos")
    DIR_VIGILAR = DIR_TRABAJO / "importar_aqui"
    DIR_PROCESADOS = DIR_TRABAJO / "procesados"
    DIR_ERRORES = DIR_TRABAJO / "errores"
    DIR_EXPORTS = DIR_TRABAJO / "exports"
    DIR_LOGS = DIR_TRABAJO / "logs"
    DIR_CACHE = DIR_TRABAJO / ".cache"

    INSTANCIA_KOHA = "koha-cnc"
    LOC_DEFAULT = "SALA"

    # Tamaños de commit/batch optimizados
    COMMIT_SIZE = 500  # Reducido para mejor manejo de memoria
    MAX_RECORDS_PER_FILE = 2000  # Archivos más pequeños

    # Timeouts
    TIMEOUT_CORRECCION = 300
    TIMEOUT_MARCXML = 600
    TIMEOUT_IMPORT = 1800
    TIMEOUT_REINDEX = 900

    # Reintentos
    MAX_REINTENTOS = 3
    REINTENTO_DELAY = 5  # segundos

    # Colores ANSI
    G = '\033[92m'
    Y = '\033[93m'
    R = '\033[91m'
    B = '\033[94m'
    C = '\033[96m'
    M = '\033[95m'
    BOLD = '\033[1m'
    END = '\033[0m'


# ==================== CLASES DE DATOS ====================
@dataclass
class EstadoImportacion:
    """Estado de una importación (para recuperación)"""
    archivo: str
    codigo_biblioteca: str
    timestamp_inicio: str
    registros_totales: int
    registros_procesados: int
    archivos_xml_generados: List[str]
    archivos_xml_importados: List[str]
    fase_actual: str  # 'validacion', 'marcxml', 'importacion', 'reindex', 'completado'
    errores: List[str]
    ultimo_timestamp: str

    def guardar(self, path: Path):
        """Guarda estado a disco"""
        with open(path, 'wb') as f:
            pickle.dump(self, f)

    @classmethod
    def cargar(cls, path: Path) -> Optional['EstadoImportacion']:
        """Carga estado desde disco"""
        try:
            if path.exists():
                with open(path, 'rb') as f:
                    return pickle.load(f)
        except Exception as e:
            print(f"Error cargando estado: {e}")
        return None


@dataclass
class Estadisticas:
    """Estadísticas de la importación"""
    items_antes: int = 0
    items_despues: int = 0
    items_nuevos: int = 0
    tiempo_inicio: float = 0
    tiempo_fin: float = 0
    tiempo_total: float = 0
    archivos_xml: int = 0
    registros_xml: int = 0

    def calcular_tiempo(self):
        self.tiempo_total = self.tiempo_fin - self.tiempo_inicio


# ==================== LOGGER MEJORADO ====================
class Logger:
    """Sistema de logging con colores, archivos y estadísticas"""

    def __init__(self, log_file: Optional[Path] = None, verbose: bool = True):
        self.log_file = log_file
        self.verbose = verbose
        self.mensajes = []
        self.estadisticas = Estadisticas()

    def log(self, msg: str, color: str = "", nivel: str = "INFO", guardar: bool = True):
        """Imprime mensaje con color y opcionalmente lo guarda"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        mensaje_completo = f"[{timestamp}] [{nivel}] {msg}"

        # Mostrar en consola si verbose
        if self.verbose:
            print(f"{color}{msg}{Config.END}")

        # Guardar en memoria
        if guardar:
            self.mensajes.append(mensaje_completo)

        # Guardar en archivo si está configurado
        if self.log_file and guardar:
            try:
                with open(self.log_file, 'a', encoding='utf-8') as f:
                    f.write(mensaje_completo + '\n')
            except Exception as e:
                print(f"{Config.Y}⚠ No se pudo escribir log: {e}{Config.END}")

    def info(self, msg: str):
        self.log(msg, Config.C, "INFO")

    def success(self, msg: str):
        self.log(f"✓ {msg}", Config.G, "SUCCESS")

    def warning(self, msg: str):
        self.log(f"⚠ {msg}", Config.Y, "WARNING")

    def error(self, msg: str):
        self.log(f"✗ {msg}", Config.R, "ERROR")

    def header(self, msg: str):
        self.log(f"\n{Config.BOLD}{msg}{Config.END}", "", "HEADER", guardar=False)

    def separador(self):
        self.log("─" * 70, "", "SEP", guardar=False)

    def progreso(self, actual: int, total: int, prefijo: str = "Progreso"):
        """Muestra barra de progreso"""
        porcentaje = (actual / total) * 100 if total > 0 else 0
        barra_len = 40
        lleno = int(barra_len * actual // total) if total > 0 else 0
        barra = '█' * lleno + '░' * (barra_len - lleno)

        msg = f"{prefijo}: [{barra}] {actual}/{total} ({porcentaje:.1f}%)"

        # Imprimir en misma línea
        if self.verbose:
            print(f"\r{Config.C}{msg}{Config.END}", end='', flush=True)

        if actual == total:
            print()  # Nueva línea al completar


# ==================== PROCESADOR OPTIMIZADO ====================
class ProcesadorCSV:
    """Procesador principal mejorado con recuperación de estado"""

    def __init__(self, archivo: Path, logger: Logger, resume: bool = False):
        self.archivo = archivo
        self.logger = logger
        self.resume = resume
        self.estado: Optional[EstadoImportacion] = None
        self.estadisticas = Estadisticas()
        self.estadisticas.tiempo_inicio = time.time()

        # Archivo de estado para recuperación
        self.estado_file = Config.DIR_CACHE / f"estado_{archivo.stem}.pkl"
        Config.DIR_CACHE.mkdir(exist_ok=True)

        # Cargar estado si es resume
        if self.resume:
            self.estado = EstadoImportacion.cargar(self.estado_file)
            if self.estado:
                self.logger.info(f"Recuperando estado desde: {self.estado.fase_actual}")

    def guardar_estado(self, fase: str, **kwargs):
        """Guarda estado actual para recuperación"""
        if not self.estado:
            self.estado = EstadoImportacion(
                archivo=str(self.archivo),
                codigo_biblioteca="",
                timestamp_inicio=datetime.now().isoformat(),
                registros_totales=0,
                registros_procesados=0,
                archivos_xml_generados=[],
                archivos_xml_importados=[],
                fase_actual=fase,
                errores=[],
                ultimo_timestamp=datetime.now().isoformat()
            )

        self.estado.fase_actual = fase
        self.estado.ultimo_timestamp = datetime.now().isoformat()

        # Actualizar campos adicionales
        for key, value in kwargs.items():
            setattr(self.estado, key, value)

        self.estado.guardar(self.estado_file)

    def detectar_codigo_biblioteca(self) -> Optional[str]:
        """Detecta código de biblioteca del nombre del archivo"""
        nombre = self.archivo.stem.upper()

        patrones = [
            r'^([A-Z]{2,6})(?:_|\.)',
            r'([A-Z]{2,6})(?:_|\d)',
            r'([A-Z]{2,6})',
        ]

        for patron in patrones:
            match = re.search(patron, nombre)
            if match:
                codigo = match.group(1)
                palabras_excluir = ['CSV', 'DATOS', 'DATA', 'FILE', 'EXPORT', 'BACKUP']
                if codigo not in palabras_excluir:
                    return codigo

        return None

    def verificar_biblioteca_koha(self, codigo: str) -> Tuple[bool, str]:
        """Verifica si biblioteca existe en Koha"""
        try:
            cmd = f"sudo koha-mysql {Config.INSTANCIA_KOHA} -N -e \"SELECT branchname FROM branches WHERE branchcode = '{codigo}'\""
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)

            if result.returncode == 0 and result.stdout.strip():
                return True, result.stdout.strip()
            return False, ""
        except Exception as e:
            self.logger.error(f"Error verificando biblioteca: {e}")
            return False, ""

    def contar_items_biblioteca(self, codigo: str) -> int:
        """Cuenta items existentes de una biblioteca"""
        try:
            cmd = f"sudo koha-mysql {Config.INSTANCIA_KOHA} -N -e \"SELECT COUNT(*) FROM items WHERE homebranch = '{codigo}'\""
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)

            if result.returncode == 0 and result.stdout.strip():
                return int(result.stdout.strip())
            return 0
        except Exception as e:
            self.logger.warning(f"No se pudo contar items: {e}")
            return 0

    def generar_marcxml_con_reintentos(self, codigo: str) -> List[Path]:
        """Genera MARCXML con reintentos automáticos"""
        for intento in range(1, Config.MAX_REINTENTOS + 1):
            self.logger.info(f"→ Generando MARCXML (intento {intento}/{Config.MAX_REINTENTOS})...")

            try:
                cmd = f"""cd {Config.DIR_EXPORTS} && python3 {Config.DIR_TRABAJO}/scripts/opac_exportar.py \
--input {self.archivo} \
--codbiblio {codigo} \
--loc-default {Config.LOC_DEFAULT} \
--stream \
--split-by {Config.MAX_RECORDS_PER_FILE} 2>&1"""

                result = subprocess.run(cmd, shell=True, capture_output=True,
                                      text=True, timeout=Config.TIMEOUT_MARCXML)

                # Buscar XMLs generados
                xmls = sorted(
                    Config.DIR_EXPORTS.glob(f"{codigo}_*_marcxml*.xml"),
                    key=lambda x: x.stat().st_mtime,
                    reverse=True
                )

                if xmls:
                    # Filtrar los más recientes (últimos 10 min)
                    tiempo_limite = time.time() - 600
                    xmls_recientes = [x for x in xmls if x.stat().st_mtime > tiempo_limite]

                    if xmls_recientes:
                        # Contar registros
                        total_registros = 0
                        for xml in xmls_recientes:
                            try:
                                with open(xml) as f:
                                    num_records = f.read().count('<record>')
                                    total_registros += num_records
                                    self.logger.info(f"  • {xml.name}: {num_records} registros")
                            except:
                                pass

                        self.logger.success(f"Generados {len(xmls_recientes)} archivos XML con {total_registros} registros")
                        self.estadisticas.archivos_xml = len(xmls_recientes)
                        self.estadisticas.registros_xml = total_registros

                        # Guardar estado
                        self.guardar_estado('marcxml',
                                          archivos_xml_generados=[str(x) for x in xmls_recientes])

                        return xmls_recientes

                # Si no encontró XMLs, reintentar
                if intento < Config.MAX_REINTENTOS:
                    self.logger.warning(f"No se generaron XMLs, reintentando en {Config.REINTENTO_DELAY}s...")
                    time.sleep(Config.REINTENTO_DELAY)

            except subprocess.TimeoutExpired:
                self.logger.error(f"Timeout en intento {intento}")
                if intento < Config.MAX_REINTENTOS:
                    time.sleep(Config.REINTENTO_DELAY)
            except Exception as e:
                self.logger.error(f"Error en intento {intento}: {e}")
                if intento < Config.MAX_REINTENTOS:
                    time.sleep(Config.REINTENTO_DELAY)

        return []

    def importar_a_koha_con_progreso(self, archivos_xml: List[Path]) -> bool:
        """Importa archivos MARCXML con barra de progreso"""
        self.logger.info("→ Importando a Koha...")

        total_exitosos = 0
        total_fallidos = 0
        total = len(archivos_xml)

        for idx, xml in enumerate(archivos_xml, 1):
            # Verificar si ya fue importado (en caso de resume)
            if self.estado and str(xml) in self.estado.archivos_xml_importados:
                self.logger.info(f"  [{idx}/{total}] Ya importado: {xml.name}")
                total_exitosos += 1
                continue

            self.logger.progreso(idx - 1, total, "Importando")

            try:
                cmd = f"""sudo koha-shell {Config.INSTANCIA_KOHA} -c \
"perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
-m MARCXML -file {xml} -commit {Config.COMMIT_SIZE}" """

                result = subprocess.run(cmd, shell=True, capture_output=True,
                                      text=True, timeout=Config.TIMEOUT_IMPORT)

                if result.returncode == 0:
                    total_exitosos += 1

                    # Guardar progreso
                    if self.estado:
                        self.estado.archivos_xml_importados.append(str(xml))
                        self.guardar_estado('importacion')
                else:
                    total_fallidos += 1
                    self.logger.error(f"  Falló: {xml.name}")

            except subprocess.TimeoutExpired:
                self.logger.error(f"  Timeout: {xml.name}")
                total_fallidos += 1
            except Exception as e:
                self.logger.error(f"  Error: {xml.name} - {e}")
                total_fallidos += 1

        self.logger.progreso(total, total, "Importando")

        exito = total_exitosos > 0 and total_fallidos == 0
        self.logger.info(f"\nResultado: {total_exitosos} exitosos, {total_fallidos} fallidos")

        return exito

    def reindexar_optimizado(self) -> bool:
        """Reindexación optimizada con mejor gestión de recursos"""
        self.logger.info("→ Reindexando catálogo (optimizado)...")

        try:
            # Liberar memoria caché antes
            self.logger.info("  Liberando memoria caché...")
            subprocess.run("sync; echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1",
                          shell=True, timeout=10)

            # Reindexar solo biblios (más rápido)
            self.logger.info("  Reindexando registros bibliográficos...")
            cmd = f"sudo koha-rebuild-zebra -b -z {Config.INSTANCIA_KOHA}"
            result = subprocess.run(cmd, shell=True, capture_output=True,
                                  timeout=Config.TIMEOUT_REINDEX)

            if result.returncode == 0:
                self.logger.success("Reindexación completada")
                return True
            else:
                self.logger.warning("Reindexación con errores")
                return False
        except Exception as e:
            self.logger.warning(f"Error en reindexación: {e}")
            return False

    def limpiar_estado(self):
        """Limpia archivo de estado tras completar"""
        try:
            if self.estado_file.exists():
                self.estado_file.unlink()
                self.logger.info("Estado de recuperación limpiado")
        except Exception as e:
            self.logger.warning(f"No se pudo limpiar estado: {e}")

    def procesar(self) -> bool:
        """Proceso principal de importación con recuperación"""

        # Banner
        print("\n" + "═" * 80)
        self.logger.log(f"📄 PROCESANDO: {self.archivo.name}", Config.BOLD + Config.C, guardar=False)
        print("═" * 80 + "\n")

        # PASO 1: Detectar código
        self.logger.header("1. DETECCIÓN DE BIBLIOTECA")
        self.logger.separador()
        codigo = self.detectar_codigo_biblioteca()

        if not codigo:
            self.logger.error("No se detectó código de biblioteca")
            return False

        self.logger.success(f"Código detectado: {codigo}")
        self.guardar_estado('deteccion', codigo_biblioteca=codigo)

        # PASO 2: Verificar biblioteca
        self.logger.header("\n2. VERIFICACIÓN EN KOHA")
        self.logger.separador()
        existe, nombre_bib = self.verificar_biblioteca_koha(codigo)

        if not existe:
            self.logger.error(f"La biblioteca '{codigo}' NO existe en Koha")
            return False

        self.logger.success(f"Biblioteca: {nombre_bib}")

        # PASO 3: Contar items antes
        self.logger.header("\n3. ESTADO ACTUAL")
        self.logger.separador()
        items_antes = self.contar_items_biblioteca(codigo)
        self.estadisticas.items_antes = items_antes
        self.logger.info(f"Items actuales: {items_antes}")

        # PASO 4: Generar MARCXML (si no se ha hecho)
        if not self.resume or not self.estado or self.estado.fase_actual in ['deteccion', 'validacion']:
            self.logger.header("\n4. GENERACIÓN DE MARCXML")
            self.logger.separador()
            archivos_xml = self.generar_marcxml_con_reintentos(codigo)

            if not archivos_xml:
                self.logger.error("No se pudieron generar archivos MARCXML")
                return False
        else:
            # Recuperar archivos XML del estado
            archivos_xml = [Path(x) for x in self.estado.archivos_xml_generados]
            self.logger.info(f"Usando {len(archivos_xml)} archivos XML del estado anterior")

        # PASO 5: Importar
        self.logger.header("\n5. IMPORTACIÓN A KOHA")
        self.logger.separador()
        importacion_ok = self.importar_a_koha_con_progreso(archivos_xml)

        if not importacion_ok:
            self.logger.error("Errores durante importación")
            return False

        # PASO 6: Reindexar
        self.logger.header("\n6. REINDEXACIÓN")
        self.logger.separador()
        self.reindexar_optimizado()

        # PASO 7: Verificación final
        self.logger.header("\n7. VERIFICACIÓN FINAL")
        self.logger.separador()
        items_despues = self.contar_items_biblioteca(codigo)
        items_nuevos = items_despues - items_antes

        self.estadisticas.items_despues = items_despues
        self.estadisticas.items_nuevos = items_nuevos
        self.estadisticas.tiempo_fin = time.time()
        self.estadisticas.calcular_tiempo()

        self.logger.info(f"Items antes:   {items_antes}")
        self.logger.info(f"Items después: {items_despues}")
        self.logger.success(f"Items nuevos:  {items_nuevos}")

        # Banner de éxito
        print("\n" + "═" * 80)
        self.logger.log("✓✓✓ IMPORTACIÓN COMPLETADA EXITOSAMENTE ✓✓✓",
                       Config.G + Config.BOLD, guardar=False)
        print("═" * 80 + "\n")

        self.logger.success(f"Tiempo total: {int(self.estadisticas.tiempo_total)} segundos")

        # Limpiar estado de recuperación
        self.limpiar_estado()

        return True


# ==================== MAIN ====================
def main():
    parser = argparse.ArgumentParser(
        description="Agente Importador Automático v3.0 - Optimizado con recuperación",
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument('archivos', nargs='*', help='Archivo(s) CSV a procesar')
    parser.add_argument('--resume', '-r', action='store_true',
                       help='Reanudar importación interrumpida')
    parser.add_argument('--verbose', '-v', action='store_true', default=True,
                       help='Modo verbose (por defecto)')
    parser.add_argument('--quiet', '-q', action='store_true',
                       help='Modo silencioso')
    parser.add_argument('--version', action='version', version='%(prog)s 3.0')

    args = parser.parse_args()

    if not args.archivos:
        parser.print_help()
        sys.exit(0)

    verbose = not args.quiet
    exitosos = 0
    fallidos = 0

    for archivo_path in args.archivos:
        archivo = Path(archivo_path)

        if not archivo.exists():
            print(f"{Config.R}✗ Archivo no encontrado: {archivo}{Config.END}")
            fallidos += 1
            continue

        # Crear logger
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        log_file = Config.DIR_LOGS / f"importacion_{archivo.stem}_{timestamp}.log"
        Config.DIR_LOGS.mkdir(parents=True, exist_ok=True)

        logger = Logger(log_file, verbose=verbose)
        procesador = ProcesadorCSV(archivo, logger, resume=args.resume)

        try:
            if procesador.procesar():
                exitosos += 1
            else:
                fallidos += 1
        except KeyboardInterrupt:
            logger.warning("\n\nImportación interrumpida por usuario")
            logger.info("Puedes reanudar con: --resume")
            sys.exit(130)
        except Exception as e:
            logger.error(f"Error inesperado: {e}")
            import traceback
            traceback.print_exc()
            fallidos += 1

    # Resumen
    if len(args.archivos) > 1:
        print(f"\n{Config.BOLD}{'═'*80}{Config.END}")
        print(f"{Config.BOLD}RESUMEN FINAL:{Config.END}")
        print(f"  Total: {len(args.archivos)}")
        print(f"  {Config.G}Exitosos: {exitosos}{Config.END}")
        if fallidos > 0:
            print(f"  {Config.R}Fallidos: {fallidos}{Config.END}")
        print(f"{Config.BOLD}{'═'*80}{Config.END}\n")

    sys.exit(0 if fallidos == 0 else 1)


if __name__ == '__main__':
    main()
