#!/usr/bin/env python3
"""
AGENTE IMPORTADOR AUTOMÁTICO V2.0
==================================
Sistema inteligente de importación automática a Koha OPAC

CARACTERÍSTICAS:
- Detección automática de código de biblioteca desde nombre de archivo
- Validación completa de requisitos previos
- Corrección automática de duplicados
- Generación y validación de MARCXML
- Importación y reindexación automática
- Logs detallados y reportes completos
- Manejo robusto de errores

REQUISITOS DEL ARCHIVO CSV:
- Nombre debe contener código de biblioteca (ej: MED.csv, VET_2025.csv, ING_octubre.csv)
- Campos obligatorios: titulo, nroacceso
- La biblioteca debe existir previamente en Koha

USO:
    # Procesar un archivo específico:
    python3 agente_importador_v2.py /ruta/archivo.csv

    # Procesar múltiples archivos:
    python3 agente_importador_v2.py archivo1.csv archivo2.csv archivo3.csv

    # Modo vigilancia (monitorea carpeta importar_aqui/):
    python3 agente_importador_v2.py --watch

    # Ver ayuda:
    python3 agente_importador_v2.py --help

EJEMPLOS:
    ./agente_importador_v2.py MED.csv
    ./agente_importador_v2.py VET_2025_octubre.csv ING_completo.csv
    ./agente_importador_v2.py --watch

AUTOR: Universidad Nacional de Asunción
VERSIÓN: 2.0
FECHA: 2025-10-24
"""

import os
import sys
import csv
import subprocess
import re
import json
import time
import argparse
from pathlib import Path
from collections import Counter
from datetime import datetime
from typing import Dict, List, Optional, Tuple


# ==================== CONFIGURACIÓN ====================
class Config:
    """Configuración global del sistema"""
    DIR_TRABAJO = Path("/home/mvillalba/migradatos")
    DIR_VIGILAR = DIR_TRABAJO / "importar_aqui"
    DIR_PROCESADOS = DIR_TRABAJO / "procesados"
    DIR_ERRORES = DIR_TRABAJO / "errores"
    DIR_EXPORTS = DIR_TRABAJO / "exports"
    DIR_LOGS = DIR_TRABAJO / "logs"
    INSTANCIA_KOHA = "koha-cnc"
    LOC_DEFAULT = "SALA"
    COMMIT_SIZE = 1000
    MAX_RECORDS_PER_FILE = 5000
    TIMEOUT_CORRECCION = 300
    TIMEOUT_MARCXML = 600
    TIMEOUT_IMPORT = 1800
    TIMEOUT_REINDEX = 900

    # Colores ANSI
    G = '\033[92m'   # Verde
    Y = '\033[93m'   # Amarillo
    R = '\033[91m'   # Rojo
    B = '\033[94m'   # Azul
    C = '\033[96m'   # Cyan
    M = '\033[95m'   # Magenta
    BOLD = '\033[1m'
    END = '\033[0m'


# ==================== UTILIDADES ====================
class Logger:
    """Sistema de logging con colores y archivo"""

    def __init__(self, log_file: Optional[Path] = None):
        self.log_file = log_file
        self.mensajes = []

    def log(self, msg: str, color: str = "", nivel: str = "INFO", guardar: bool = True):
        """Imprime mensaje con color y opcionalmente lo guarda"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        mensaje_completo = f"[{timestamp}] [{nivel}] {msg}"

        # Mostrar en consola con color
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

    def generar_reporte(self, datos: Dict) -> str:
        """Genera reporte completo de la importación"""
        reporte = f"""
{'═'*80}
REPORTE DE IMPORTACIÓN AUTOMÁTICA
{'═'*80}

INFORMACIÓN GENERAL
───────────────────
Fecha y hora:        {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
Código biblioteca:   {datos.get('codigo', 'N/A')}
Nombre biblioteca:   {datos.get('nombre_biblioteca', 'N/A')}

ARCHIVO CSV
───────────
Ruta original:       {datos.get('archivo_origen', 'N/A')}
Nombre archivo:      {datos.get('nombre_archivo', 'N/A')}
Total registros:     {datos.get('total_registros', 0)}
Duplicados:          {datos.get('duplicados', 0)}
Corrección aplicada: {datos.get('correccion_aplicada', 'No')}

GENERACIÓN MARCXML
──────────────────
Archivos generados:  {datos.get('archivos_xml', 0)}
Registros en XML:    {datos.get('registros_xml', 0)}
Validación XML:      {datos.get('validacion_xml', 'N/A')}

IMPORTACIÓN KOHA
────────────────
Items antes:         {datos.get('items_antes', 0)}
Items después:       {datos.get('items_despues', 0)}
Items importados:    {datos.get('items_nuevos', 0)}
Estado importación:  {datos.get('estado_importacion', 'N/A')}

REINDEXACIÓN
────────────
Estado reindex:      {datos.get('estado_reindex', 'N/A')}

RESULTADO FINAL
───────────────
Estado:              {datos.get('estado_final', 'N/A')}
Tiempo total:        {datos.get('tiempo_total', 'N/A')} segundos

VERIFICACIÓN
────────────
URL OPAC: http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch={datos.get('codigo', '')}

{'═'*80}
"""
        return reporte


# ==================== PROCESADOR DE ARCHIVOS ====================
class ProcesadorCSV:
    """Procesador principal de archivos CSV"""

    def __init__(self, archivo: Path, logger: Logger):
        self.archivo = archivo
        self.logger = logger
        self.datos_reporte = {
            'archivo_origen': str(archivo),
            'nombre_archivo': archivo.name
        }
        self.tiempo_inicio = time.time()

    def detectar_codigo_biblioteca(self) -> Optional[str]:
        """Detecta código de biblioteca del nombre del archivo"""
        nombre = self.archivo.stem.upper()

        # Patrones de búsqueda (del más específico al más general)
        patrones = [
            r'^([A-Z]{2,6})(?:_|\.)',     # Código al inicio seguido de _ o .
            r'([A-Z]{2,6})(?:_|\d)',       # Código seguido de _ o número
            r'([A-Z]{2,6})',               # Cualquier secuencia de 2-6 letras
        ]

        for patron in patrones:
            match = re.search(patron, nombre)
            if match:
                codigo = match.group(1)
                # Validar que no sea una palabra común
                palabras_excluir = ['CSV', 'DATOS', 'DATA', 'FILE', 'EXPORT', 'BACKUP']
                if codigo not in palabras_excluir:
                    return codigo

        return None

    def verificar_biblioteca_koha(self, codigo: str) -> Tuple[bool, str]:
        """Verifica si biblioteca existe en Koha y obtiene su nombre"""
        try:
            cmd = f"sudo koha-mysql {Config.INSTANCIA_KOHA} -N -e \"SELECT branchname FROM branches WHERE branchcode = '{codigo}'\""
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)

            if result.returncode == 0 and result.stdout.strip():
                nombre = result.stdout.strip()
                return True, nombre
            else:
                return False, ""
        except Exception as e:
            self.logger.error(f"Error verificando biblioteca: {e}")
            return False, ""

    def analizar_estructura_csv(self) -> Optional[Dict]:
        """Analiza estructura, validez y contenido del CSV"""
        try:
            with open(self.archivo, 'r', encoding='utf-8') as f:
                primera_linea = f.readline()

                # Detectar separador
                sep = ';' if ';' in primera_linea else ','
                f.seek(0)

                # Leer con DictReader
                reader = csv.DictReader(f, delimiter=sep)
                columnas = reader.fieldnames

                if not columnas:
                    self.logger.error("No se pudieron detectar columnas")
                    return None

                # Normalizar nombres de columnas (minúsculas, sin espacios)
                columnas_norm = [col.lower().strip() for col in columnas]

                # Verificar campos obligatorios
                campos_obligatorios = ['titulo', 'nroacceso']
                faltantes = [c for c in campos_obligatorios if c not in columnas_norm]

                if faltantes:
                    self.logger.error(f"Faltan campos obligatorios: {', '.join(faltantes)}")
                    return None

                # Leer todos los registros
                registros = list(reader)
                total = len(registros)

                if total == 0:
                    self.logger.error("El archivo no contiene registros")
                    return None

                # Analizar duplicados
                codigos_acceso = []
                for r in registros:
                    # Buscar columna nroacceso (case insensitive)
                    for key in r.keys():
                        if key.lower().strip() == 'nroacceso':
                            valor = r[key].strip()
                            if valor:
                                codigos_acceso.append(valor)
                            break

                contador = Counter(codigos_acceso)
                duplicados = sum(1 for v in contador.values() if v > 1)
                registros_duplicados = sum(v - 1 for v in contador.values() if v > 1)

                return {
                    'total': total,
                    'columnas': columnas,
                    'separador': sep,
                    'codigos_unicos': len(contador),
                    'duplicados': duplicados,
                    'registros_duplicados': registros_duplicados,
                    'necesita_correccion': duplicados > 50  # Umbral configurable
                }

        except Exception as e:
            self.logger.error(f"Error analizando CSV: {e}")
            return None

    def corregir_duplicados(self) -> Optional[Path]:
        """Corrige duplicados usando script existente"""
        self.logger.info("→ Iniciando corrección de duplicados...")

        try:
            # Intentar con script específico o genérico
            scripts = [
                Config.DIR_TRABAJO / "corregir_codigos_vet.py",
                Config.DIR_TRABAJO / "corregir_codigos_ing.py"
            ]

            script_usado = None
            for script in scripts:
                if script.exists():
                    script_usado = script
                    break

            if not script_usado:
                self.logger.warning("No se encontró script de corrección, continuando sin corregir")
                return self.archivo

            cmd = f"python3 {script_usado} {self.archivo}"
            result = subprocess.run(cmd, shell=True, capture_output=True,
                                  timeout=Config.TIMEOUT_CORRECCION)

            # Buscar archivo corregido
            archivo_corregido = self.archivo.parent / f"{self.archivo.stem}_corregido.csv"

            if archivo_corregido.exists():
                self.logger.success(f"Archivo corregido: {archivo_corregido.name}")
                self.datos_reporte['correccion_aplicada'] = 'Sí'
                return archivo_corregido
            else:
                self.logger.warning("No se generó archivo corregido, usando original")
                self.datos_reporte['correccion_aplicada'] = 'Intentada pero no aplicada'
                return self.archivo

        except subprocess.TimeoutExpired:
            self.logger.error("Timeout en corrección de duplicados")
            return self.archivo
        except Exception as e:
            self.logger.warning(f"Error en corrección: {e}, continuando con original")
            return self.archivo

    def generar_marcxml(self, codigo: str) -> List[Path]:
        """Genera archivos MARCXML desde CSV"""
        self.logger.info("→ Generando MARCXML...")

        try:
            cmd = f"""cd {Config.DIR_EXPORTS} && python3 {Config.DIR_TRABAJO}/scripts/opac_exportar.py \
-i {self.archivo} \
--codbiblio {codigo} \
--loc-default {Config.LOC_DEFAULT} \
--stream \
--split-by {Config.MAX_RECORDS_PER_FILE} 2>&1"""

            result = subprocess.run(cmd, shell=True, capture_output=True,
                                  text=True, timeout=Config.TIMEOUT_MARCXML)

            # Buscar XMLs generados (los más recientes)
            xmls = sorted(
                Config.DIR_EXPORTS.glob(f"{codigo}_*_marcxml*.xml"),
                key=lambda x: x.stat().st_mtime,
                reverse=True
            )

            if not xmls:
                self.logger.error("No se generaron archivos MARCXML")
                return []

            # Limitar a los generados en esta ejecución (últimos 10 minutos)
            tiempo_limite = time.time() - 600
            xmls_recientes = [x for x in xmls if x.stat().st_mtime > tiempo_limite]

            if not xmls_recientes:
                self.logger.warning("No se encontraron XMLs recientes, usando los más nuevos")
                xmls_recientes = xmls[:10]  # Tomar máximo 10

            # Contar registros
            total_registros = 0
            for xml in xmls_recientes:
                try:
                    with open(xml) as f:
                        num_records = f.read().count('<record>')
                        total_registros += num_records
                        self.logger.info(f"  • {xml.name}: {num_records} registros")
                except Exception as e:
                    self.logger.warning(f"  • {xml.name}: No se pudo contar registros")

            self.logger.success(f"Generados {len(xmls_recientes)} archivo(s) XML con {total_registros} registros")
            self.datos_reporte['archivos_xml'] = len(xmls_recientes)
            self.datos_reporte['registros_xml'] = total_registros

            return xmls_recientes

        except subprocess.TimeoutExpired:
            self.logger.error("Timeout generando MARCXML")
            return []
        except Exception as e:
            self.logger.error(f"Error generando MARCXML: {e}")
            return []

    def validar_xml(self, archivos_xml: List[Path]) -> bool:
        """Valida sintaxis de archivos XML"""
        self.logger.info("→ Validando archivos XML...")

        todos_validos = True
        for xml in archivos_xml:
            try:
                result = subprocess.run(
                    ['xmllint', '--noout', str(xml)],
                    capture_output=True,
                    timeout=30
                )
                if result.returncode == 0:
                    self.logger.success(f"{xml.name} - Válido")
                else:
                    self.logger.error(f"{xml.name} - Inválido")
                    todos_validos = False
            except subprocess.TimeoutExpired:
                self.logger.error(f"{xml.name} - Timeout en validación")
                todos_validos = False
            except FileNotFoundError:
                self.logger.warning("xmllint no disponible, saltando validación")
                break
            except Exception as e:
                self.logger.error(f"{xml.name} - Error: {e}")
                todos_validos = False

        self.datos_reporte['validacion_xml'] = 'Válido' if todos_validos else 'Inválido'
        return todos_validos

    def contar_items_biblioteca(self, codigo: str) -> int:
        """Cuenta items existentes de una biblioteca en Koha"""
        try:
            cmd = f"sudo koha-mysql {Config.INSTANCIA_KOHA} -N -e \"SELECT COUNT(*) FROM items WHERE homebranch = '{codigo}'\""
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)

            if result.returncode == 0 and result.stdout.strip():
                return int(result.stdout.strip())
            return 0
        except Exception as e:
            self.logger.warning(f"No se pudo contar items: {e}")
            return 0

    def importar_a_koha(self, archivos_xml: List[Path]) -> bool:
        """Importa archivos MARCXML a Koha"""
        self.logger.info("→ Importando a Koha...")

        total_exitosos = 0
        total_fallidos = 0

        for xml in archivos_xml:
            self.logger.info(f"  Procesando: {xml.name}")

            try:
                cmd = f"""sudo koha-shell {Config.INSTANCIA_KOHA} -c \
"perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
-b -m MARCXML -file {xml} -commit {Config.COMMIT_SIZE}" """

                result = subprocess.run(cmd, shell=True, capture_output=True,
                                      text=True, timeout=Config.TIMEOUT_IMPORT)

                if result.returncode == 0:
                    # Buscar estadísticas en la salida
                    output = result.stdout + result.stderr
                    for line in output.split('\n'):
                        if 'biblios' in line.lower() or 'items' in line.lower():
                            self.logger.info(f"    {line.strip()}")

                    total_exitosos += 1
                    self.logger.success(f"  {xml.name} importado")
                else:
                    total_fallidos += 1
                    self.logger.error(f"  {xml.name} falló")

            except subprocess.TimeoutExpired:
                self.logger.error(f"  {xml.name} - Timeout")
                total_fallidos += 1
            except Exception as e:
                self.logger.error(f"  {xml.name} - Error: {e}")
                total_fallidos += 1

        exito = total_exitosos > 0 and total_fallidos == 0
        self.datos_reporte['estado_importacion'] = f"{total_exitosos} exitosos, {total_fallidos} fallidos"

        return exito

    def reindexar(self) -> bool:
        """Reindexa catálogo de Koha (optimizado para recursos limitados)"""
        self.logger.info("→ Reindexando catálogo (modo optimizado)...")

        try:
            # Reindexación optimizada para recursos limitados:
            # -a = solo autoridades si es necesario
            # -b = solo biblios
            # -z = no ejecutar zebraidx en segundo plano (más control de recursos)
            # Sin -v (verbose) para reducir uso de memoria

            # Primero: limpiar memoria antes de reindexar
            self.logger.info("  Liberando memoria caché...")
            subprocess.run("sync; echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1",
                          shell=True, timeout=10)

            # Reindexar solo biblios (más eficiente)
            self.logger.info("  Reindexando registros bibliográficos...")
            cmd = f"sudo koha-rebuild-zebra -b -z {Config.INSTANCIA_KOHA}"
            result = subprocess.run(cmd, shell=True, capture_output=True,
                                  timeout=Config.TIMEOUT_REINDEX)

            if result.returncode == 0:
                self.logger.success("Reindexación completada (modo optimizado)")
                self.datos_reporte['estado_reindex'] = 'Exitoso (optimizado)'
                return True
            else:
                self.logger.warning("Reindexación con errores")
                self.datos_reporte['estado_reindex'] = 'Con errores'
                return False
        except subprocess.TimeoutExpired:
            self.logger.error("Timeout en reindexación")
            self.datos_reporte['estado_reindex'] = 'Timeout'
            return False
        except Exception as e:
            self.logger.warning(f"Error en reindexación: {e}")
            self.datos_reporte['estado_reindex'] = f'Error: {e}'
            return False

    def mover_archivo(self, destino_dir: Path, sufijo: str = ""):
        """Mueve archivo procesado a carpeta destino"""
        destino_dir.mkdir(parents=True, exist_ok=True)
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        nombre = self.archivo.stem
        destino = destino_dir / f"{nombre}{sufijo}_{timestamp}.csv"

        try:
            self.archivo.rename(destino)
            self.logger.info(f"→ Archivo movido a: {destino}")
        except Exception as e:
            self.logger.warning(f"No se pudo mover archivo: {e}")

    def procesar(self) -> bool:
        """Proceso principal de importación"""

        # Banner
        print("\n" + "═" * 80)
        self.logger.log(f"📄 PROCESANDO: {self.archivo.name}", Config.BOLD + Config.C, guardar=False)
        print("═" * 80 + "\n")

        # PASO 1: Detectar código
        self.logger.header("1. DETECCIÓN DE BIBLIOTECA")
        self.logger.separador()
        codigo = self.detectar_codigo_biblioteca()

        if not codigo:
            self.logger.error("No se detectó código de biblioteca en el nombre del archivo")
            self.logger.info("El nombre debe contener 3-6 letras (ej: MED.csv, VET_2025.csv)")
            self.mover_archivo(Config.DIR_ERRORES, "_SIN_CODIGO")
            self.datos_reporte['estado_final'] = 'ERROR: Sin código'
            return False

        self.logger.success(f"Código detectado: {codigo}")
        self.datos_reporte['codigo'] = codigo

        # PASO 2: Verificar biblioteca en Koha
        self.logger.header("\n2. VERIFICACIÓN EN KOHA")
        self.logger.separador()
        existe, nombre_bib = self.verificar_biblioteca_koha(codigo)

        if not existe:
            self.logger.error(f"La biblioteca '{codigo}' NO existe en Koha")
            self.logger.info("Créela en: Staff Interface → Administración → Bibliotecas")
            self.mover_archivo(Config.DIR_ERRORES, "_NO_EXISTE_KOHA")
            self.datos_reporte['estado_final'] = 'ERROR: Biblioteca no existe'
            return False

        self.logger.success(f"Biblioteca: {nombre_bib}")
        self.datos_reporte['nombre_biblioteca'] = nombre_bib

        # PASO 3: Analizar CSV
        self.logger.header("\n3. ANÁLISIS DEL CSV")
        self.logger.separador()
        analisis = self.analizar_estructura_csv()

        if not analisis:
            self.logger.error("Formato CSV inválido o incompleto")
            self.mover_archivo(Config.DIR_ERRORES, "_FORMATO_INVALIDO")
            self.datos_reporte['estado_final'] = 'ERROR: Formato inválido'
            return False

        self.logger.success(f"Total de registros: {analisis['total']}")
        self.logger.info(f"Columnas detectadas: {len(analisis['columnas'])}")
        self.logger.info(f"Separador: '{analisis['separador']}'")

        if analisis['duplicados'] > 0:
            self.logger.warning(f"Códigos duplicados: {analisis['duplicados']} ({analisis['registros_duplicados']} registros)")

        self.datos_reporte['total_registros'] = analisis['total']
        self.datos_reporte['duplicados'] = analisis['duplicados']

        # PASO 4: Contar items existentes
        self.logger.header("\n4. VERIFICACIÓN DE ITEMS EXISTENTES")
        self.logger.separador()
        items_antes = self.contar_items_biblioteca(codigo)
        self.logger.info(f"Items actuales en Koha para {codigo}: {items_antes}")
        self.datos_reporte['items_antes'] = items_antes

        if items_antes > 0:
            self.logger.warning(f"Ya existen {items_antes} items. Se agregarán NUEVOS registros")

        # PASO 5: Corregir duplicados si es necesario
        archivo_a_usar = self.archivo
        if analisis['necesita_correccion']:
            self.logger.header("\n5. CORRECCIÓN DE DUPLICADOS")
            self.logger.separador()
            archivo_a_usar = self.corregir_duplicados()
            self.archivo = archivo_a_usar  # Actualizar referencia
        else:
            self.logger.header("\n5. CORRECCIÓN DE DUPLICADOS")
            self.logger.separador()
            self.logger.success("No necesita corrección (duplicados bajo umbral)")
            self.datos_reporte['correccion_aplicada'] = 'No necesaria'

        # PASO 6: Generar MARCXML
        self.logger.header("\n6. GENERACIÓN DE MARCXML")
        self.logger.separador()
        archivos_xml = self.generar_marcxml(codigo)

        if not archivos_xml:
            self.logger.error("No se pudieron generar archivos MARCXML")
            self.mover_archivo(Config.DIR_ERRORES, "_ERROR_MARCXML")
            self.datos_reporte['estado_final'] = 'ERROR: Generación MARCXML'
            return False

        # PASO 7: Validar XML
        self.logger.header("\n7. VALIDACIÓN DE XML")
        self.logger.separador()
        xml_valido = self.validar_xml(archivos_xml)

        if not xml_valido:
            self.logger.error("Archivos XML con errores de validación")
            self.mover_archivo(Config.DIR_ERRORES, "_XML_INVALIDO")
            self.datos_reporte['estado_final'] = 'ERROR: XML inválido'
            return False

        # PASO 8: Importar a Koha
        self.logger.header("\n8. IMPORTACIÓN A KOHA")
        self.logger.separador()
        importacion_ok = self.importar_a_koha(archivos_xml)

        if not importacion_ok:
            self.logger.error("Errores durante la importación")
            self.mover_archivo(Config.DIR_ERRORES, "_ERROR_IMPORT")
            self.datos_reporte['estado_final'] = 'ERROR: Importación'
            return False

        # PASO 9: Reindexar
        self.logger.header("\n9. REINDEXACIÓN")
        self.logger.separador()
        self.reindexar()  # No es crítico si falla

        # PASO 10: Verificación final
        self.logger.header("\n10. VERIFICACIÓN FINAL")
        self.logger.separador()
        items_despues = self.contar_items_biblioteca(codigo)
        items_nuevos = items_despues - items_antes

        self.logger.info(f"Items antes:   {items_antes}")
        self.logger.info(f"Items después: {items_despues}")
        self.logger.success(f"Items nuevos:  {items_nuevos}")

        self.datos_reporte['items_despues'] = items_despues
        self.datos_reporte['items_nuevos'] = items_nuevos

        # Tiempo total
        tiempo_total = int(time.time() - self.tiempo_inicio)
        self.datos_reporte['tiempo_total'] = tiempo_total
        self.datos_reporte['estado_final'] = 'EXITOSO'

        # Banner de éxito
        print("\n" + "═" * 80)
        self.logger.log(f"✓✓✓ IMPORTACIÓN COMPLETADA EXITOSAMENTE ✓✓✓",
                       Config.G + Config.BOLD, guardar=False)
        print("═" * 80 + "\n")

        self.logger.success(f"Tiempo total: {tiempo_total} segundos")
        self.logger.info(f"URL verificación: http://[servidor]:8080/cgi-bin/koha/opac-search.pl?branch={codigo}")

        # Mover a procesados
        self.mover_archivo(Config.DIR_PROCESADOS, "_OK")

        return True


# ==================== MODO VIGILANCIA ====================
class ModoVigilancia:
    """Modo de vigilancia automática de carpeta"""

    def __init__(self, logger: Logger):
        self.logger = logger
        self.procesados = set()

    def vigilar(self):
        """Vigila carpeta y procesa archivos automáticamente"""

        Config.DIR_VIGILAR.mkdir(parents=True, exist_ok=True)

        # Banner
        print(f"\n{Config.C}{Config.BOLD}{'═'*80}{Config.END}")
        print(f"{Config.C}{Config.BOLD}{'  '*10}MODO VIGILANCIA ACTIVADO{Config.END}")
        print(f"{Config.C}{Config.BOLD}{'═'*80}{Config.END}\n")

        self.logger.info(f"👁  Vigilando carpeta: {Config.DIR_VIGILAR}")
        self.logger.info(f"💡 Coloca archivos CSV aquí para procesarlos automáticamente\n")

        # Detectar archivos existentes
        archivos_existentes = list(Config.DIR_VIGILAR.glob("*.csv"))

        if archivos_existentes:
            self.logger.info(f"📋 Archivos detectados: {len(archivos_existentes)}")
            for arch in archivos_existentes:
                self.logger.info(f"   • {arch.name}")

            respuesta = input(f"\n¿Procesar archivos existentes ahora? (SI/no): ").strip().upper()
            if respuesta in ['SI', 'S', 'YES', 'Y', '']:
                for arch in archivos_existentes:
                    self.procesar_con_log(arch)
                    self.procesados.add(arch.name)

        self.logger.info("\n⏳ Esperando nuevos archivos... (Ctrl+C para salir)\n")

        # Loop de vigilancia
        try:
            while True:
                archivos_actuales = list(Config.DIR_VIGILAR.glob("*.csv"))

                for arch in archivos_actuales:
                    if arch.name not in self.procesados:
                        self.logger.info(f"\n🔔 NUEVO ARCHIVO DETECTADO: {arch.name}")
                        time.sleep(2)  # Esperar estabilidad del archivo
                        self.procesar_con_log(arch)
                        self.procesados.add(arch.name)

                time.sleep(5)  # Revisar cada 5 segundos

        except KeyboardInterrupt:
            self.logger.info("\n\n👋 Deteniendo vigilancia...")
            self.logger.info("Hasta pronto!\n")

    def procesar_con_log(self, archivo: Path):
        """Procesa archivo con manejo de errores y logging"""
        # Crear logger específico para este archivo
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        log_file = Config.DIR_LOGS / f"importacion_{archivo.stem}_{timestamp}.log"
        Config.DIR_LOGS.mkdir(parents=True, exist_ok=True)

        file_logger = Logger(log_file)
        procesador = ProcesadorCSV(archivo, file_logger)

        try:
            exito = procesador.procesar()

            # Generar reporte
            reporte = file_logger.generar_reporte(procesador.datos_reporte)

            # Guardar reporte
            reporte_file = Config.DIR_LOGS / f"reporte_{archivo.stem}_{timestamp}.txt"
            with open(reporte_file, 'w', encoding='utf-8') as f:
                f.write(reporte)

            file_logger.success(f"Reporte guardado: {reporte_file}")

            return exito

        except Exception as e:
            file_logger.error(f"Error inesperado: {e}")
            import traceback
            traceback.print_exc()
            return False


# ==================== MAIN ====================
def main():
    """Punto de entrada principal"""

    parser = argparse.ArgumentParser(
        description="Agente Importador Automático v2.0 - Sistema de importación a Koha OPAC",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos de uso:
  %(prog)s MED.csv                    # Procesar un archivo
  %(prog)s archivo1.csv archivo2.csv  # Procesar múltiples archivos
  %(prog)s --watch                    # Modo vigilancia (monitorea carpeta)

Requisitos del archivo CSV:
  - Nombre debe contener código de biblioteca (ej: MED.csv, VET_2025.csv)
  - Campos obligatorios: titulo, nroacceso
  - La biblioteca debe existir en Koha

Universidad Nacional de Asunción - 2025
        """
    )

    parser.add_argument('archivos', nargs='*', help='Archivo(s) CSV a procesar')
    parser.add_argument('--watch', '-w', action='store_true',
                       help='Modo vigilancia: monitorea carpeta importar_aqui/')
    parser.add_argument('--version', action='version', version='%(prog)s 2.0')

    args = parser.parse_args()

    # Si no hay argumentos, mostrar ayuda
    if not args.archivos and not args.watch:
        parser.print_help()
        sys.exit(0)

    # Modo vigilancia
    if args.watch:
        logger = Logger()
        vigilancia = ModoVigilancia(logger)
        vigilancia.vigilar()
        return

    # Modo procesamiento directo
    exitosos = 0
    fallidos = 0

    for archivo_path in args.archivos:
        archivo = Path(archivo_path)

        if not archivo.exists():
            print(f"{Config.R}✗ Archivo no encontrado: {archivo}{Config.END}")
            fallidos += 1
            continue

        # Crear logger con archivo de log
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        log_file = Config.DIR_LOGS / f"importacion_{archivo.stem}_{timestamp}.log"
        Config.DIR_LOGS.mkdir(parents=True, exist_ok=True)

        logger = Logger(log_file)
        procesador = ProcesadorCSV(archivo, logger)

        try:
            exito = procesador.procesar()

            # Generar y guardar reporte
            reporte = logger.generar_reporte(procesador.datos_reporte)
            reporte_file = Config.DIR_LOGS / f"reporte_{archivo.stem}_{timestamp}.txt"

            with open(reporte_file, 'w', encoding='utf-8') as f:
                f.write(reporte)

            logger.success(f"\nReporte guardado: {reporte_file}")
            logger.success(f"Log guardado: {log_file}")

            if exito:
                exitosos += 1
            else:
                fallidos += 1

        except Exception as e:
            logger.error(f"Error inesperado: {e}")
            import traceback
            traceback.print_exc()
            fallidos += 1

    # Resumen final
    if len(args.archivos) > 1:
        print(f"\n{Config.BOLD}{'═'*80}{Config.END}")
        print(f"{Config.BOLD}RESUMEN FINAL:{Config.END}")
        print(f"  Total procesados: {len(args.archivos)}")
        print(f"  {Config.G}Exitosos: {exitosos}{Config.END}")
        if fallidos > 0:
            print(f"  {Config.R}Fallidos: {fallidos}{Config.END}")
        print(f"{Config.BOLD}{'═'*80}{Config.END}\n")

    sys.exit(0 if fallidos == 0 else 1)


if __name__ == '__main__':
    main()
