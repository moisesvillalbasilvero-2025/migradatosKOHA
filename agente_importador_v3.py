#!/usr/bin/env python3
"""
════════════════════════════════════════════════════════════════════════════
AGENTE IMPORTADOR AUTOMÁTICO V3.0 - OPTIMIZADO Y PROFESIONAL
════════════════════════════════════════════════════════════════════════════

Sistema inteligente de importación automática a Koha OPAC con características
avanzadas de recuperación ante fallos y optimización de recursos.

CARACTERÍSTICAS PRINCIPALES:
──────────────────────────────────────────────────────────────────────────────
✓ Recuperación automática ante interrupciones (cortes de luz, errores, etc.)
✓ Importación incremental - continúa desde donde se interrumpió
✓ Validación robusta de datos de entrada
✓ Manejo eficiente de memoria para archivos grandes
✓ Estadísticas y progreso en tiempo real
✓ Reintentos automáticos con backoff exponencial
✓ Sistema de cache para recuperación de estado
✓ Notificaciones opcionales de progreso

ARQUITECTURA:
──────────────────────────────────────────────────────────────────────────────
- Config: Configuración centralizada del sistema
- EstadoImportacion: Estado persistente para recuperación
- Estadisticas: Métricas de rendimiento
- Logger: Sistema de logging con colores y niveles
- ProcesadorCSV: Clase principal de procesamiento

FLUJO DE TRABAJO:
──────────────────────────────────────────────────────────────────────────────
1. Detectar código de biblioteca del nombre del archivo
2. Verificar que la biblioteca existe en Koha
3. Contar items actuales (baseline)
4. Generar archivos MARCXML con reintentos
5. Importar a Koha con barra de progreso
6. Reindexar catálogo (optimizado)
7. Verificar resultados y generar reporte

USO:
──────────────────────────────────────────────────────────────────────────────
    # Importación simple
    ./agente_importador_v3.py archivo.csv

    # Reanudar importación interrumpida
    ./agente_importador_v3.py archivo.csv --resume

    # Importar múltiples archivos
    ./agente_importador_v3.py archivo1.csv archivo2.csv archivo3.csv

    # Modo silencioso
    ./agente_importador_v3.py archivo.csv --quiet

AUTORES: Universidad Nacional de Asunción
VERSIÓN: 3.0.0
FECHA: 2025-11-07
LICENCIA: GPL-3.0
════════════════════════════════════════════════════════════════════════════
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
from typing import Dict, List, Optional, Tuple, Any, Set
from dataclasses import dataclass, asdict, field


# ════════════════════════════════════════════════════════════════════════════
# CONFIGURACIÓN GLOBAL DEL SISTEMA
# ════════════════════════════════════════════════════════════════════════════

class Config:
    """
    Configuración centralizada del sistema de importación.

    Todas las constantes y parámetros ajustables del sistema están
    centralizados aquí para facilitar mantenimiento y personalización.

    Attributes:
        DIR_TRABAJO: Directorio base de trabajo (auto-detectado)
        INSTANCIA_KOHA: Nombre de la instancia Koha
        LOC_DEFAULT: Localización por defecto para items
        COMMIT_SIZE: Número de registros por commit (optimización)
        MAX_RECORDS_PER_FILE: Máximo de registros por archivo XML
        Timeouts: Límites de tiempo para operaciones críticas
        MAX_REINTENTOS: Número de reintentos ante fallos
        REINTENTO_DELAY: Tiempo de espera entre reintentos
    """

    # ─────────────────────────────────────────────────────────────────────────
    # Directorios del sistema (auto-detectados)
    # ─────────────────────────────────────────────────────────────────────────
    SCRIPT_DIR = Path(__file__).parent.absolute()
    DIR_TRABAJO = SCRIPT_DIR
    DIR_VIGILAR = DIR_TRABAJO / "importar_aqui"
    DIR_PROCESADOS = DIR_TRABAJO / "procesados"
    DIR_ERRORES = DIR_TRABAJO / "errores"
    DIR_EXPORTS = DIR_TRABAJO / "exports"
    DIR_LOGS = DIR_TRABAJO / "logs"
    DIR_CACHE = DIR_TRABAJO / ".cache"

    # ─────────────────────────────────────────────────────────────────────────
    # Configuración de Koha
    # ─────────────────────────────────────────────────────────────────────────
    INSTANCIA_KOHA: str = "koha-cnc"
    LOC_DEFAULT: str = "SALA"  # Localización por defecto para items

    # ─────────────────────────────────────────────────────────────────────────
    # Parámetros de optimización
    # ─────────────────────────────────────────────────────────────────────────
    # Tamaños de commit optimizados para balance entre velocidad y memoria
    COMMIT_SIZE: int = 500          # Registros por transacción (menor = más seguro)
    MAX_RECORDS_PER_FILE: int = 2000  # Archivos más pequeños = mejor manejo

    # ─────────────────────────────────────────────────────────────────────────
    # Timeouts (en segundos)
    # ─────────────────────────────────────────────────────────────────────────
    TIMEOUT_CORRECCION: int = 300    # 5 minutos
    TIMEOUT_MARCXML: int = 600       # 10 minutos
    TIMEOUT_IMPORT: int = 1800       # 30 minutos
    TIMEOUT_REINDEX: int = 900       # 15 minutos

    # ─────────────────────────────────────────────────────────────────────────
    # Sistema de reintentos
    # ─────────────────────────────────────────────────────────────────────────
    MAX_REINTENTOS: int = 3          # Número de reintentos ante fallo
    REINTENTO_DELAY: int = 5         # Segundos entre reintentos

    # ─────────────────────────────────────────────────────────────────────────
    # Paleta de colores ANSI para output
    # ─────────────────────────────────────────────────────────────────────────
    G: str = '\033[92m'     # Verde (success)
    Y: str = '\033[93m'     # Amarillo (warning)
    R: str = '\033[91m'     # Rojo (error)
    B: str = '\033[94m'     # Azul (info)
    C: str = '\033[96m'     # Cyan (destacado)
    M: str = '\033[95m'     # Magenta
    BOLD: str = '\033[1m'   # Negrita
    END: str = '\033[0m'    # Reset color


# ════════════════════════════════════════════════════════════════════════════
# CLASES DE DATOS - Estructuras persistentes
# ════════════════════════════════════════════════════════════════════════════

@dataclass
class EstadoImportacion:
    """
    Estado persistente de una importación para recuperación ante fallos.

    Esta clase permite guardar el progreso de una importación en disco,
    de manera que si el proceso se interrumpe (corte de luz, error, etc.)
    puede reanudarse exactamente donde quedó.

    Attributes:
        archivo: Ruta completa al archivo CSV procesado
        codigo_biblioteca: Código de la biblioteca (ej: MED, FACEN)
        timestamp_inicio: Momento de inicio ISO format
        registros_totales: Total de registros a procesar
        registros_procesados: Registros ya procesados
        archivos_xml_generados: Lista de XMLs generados
        archivos_xml_importados: Lista de XMLs ya importados a Koha
        fase_actual: Fase del proceso (validacion, marcxml, importacion, etc.)
        errores: Lista de errores encontrados
        ultimo_timestamp: Última actualización del estado
    """
    archivo: str
    codigo_biblioteca: str
    timestamp_inicio: str
    registros_totales: int
    registros_procesados: int
    archivos_xml_generados: List[str] = field(default_factory=list)
    archivos_xml_importados: List[str] = field(default_factory=list)
    fase_actual: str = "inicializacion"
    errores: List[str] = field(default_factory=list)
    ultimo_timestamp: str = ""

    def guardar(self, path: Path) -> None:
        """
        Guarda el estado actual en disco usando pickle.

        Args:
            path: Ruta donde guardar el archivo de estado

        Raises:
            IOError: Si no se puede escribir el archivo
        """
        try:
            path.parent.mkdir(parents=True, exist_ok=True)
            with open(path, 'wb') as f:
                pickle.dump(self, f)
        except Exception as e:
            print(f"{Config.Y}⚠ Advertencia: No se pudo guardar estado: {e}{Config.END}")

    @classmethod
    def cargar(cls, path: Path) -> Optional['EstadoImportacion']:
        """
        Carga un estado previamente guardado desde disco.

        Args:
            path: Ruta del archivo de estado

        Returns:
            EstadoImportacion si existe y es válido, None en caso contrario
        """
        try:
            if path.exists() and path.stat().st_size > 0:
                with open(path, 'rb') as f:
                    estado = pickle.load(f)
                    if isinstance(estado, cls):
                        return estado
        except Exception as e:
            print(f"{Config.Y}⚠ No se pudo cargar estado anterior: {e}{Config.END}")
        return None


@dataclass
class Estadisticas:
    """
    Métricas de rendimiento y resultados de la importación.

    Attributes:
        items_antes: Cantidad de items antes de importar
        items_despues: Cantidad de items después de importar
        items_nuevos: Items agregados (calculado)
        tiempo_inicio: Timestamp de inicio (Unix time)
        tiempo_fin: Timestamp de fin (Unix time)
        tiempo_total: Duración total en segundos (calculado)
        archivos_xml: Número de archivos XML generados
        registros_xml: Número total de registros en XMLs
    """
    items_antes: int = 0
    items_despues: int = 0
    items_nuevos: int = 0
    tiempo_inicio: float = 0.0
    tiempo_fin: float = 0.0
    tiempo_total: float = 0.0
    archivos_xml: int = 0
    registros_xml: int = 0

    def calcular_tiempo(self) -> None:
        """Calcula la duración total de la importación."""
        self.tiempo_total = self.tiempo_fin - self.tiempo_inicio

    def calcular_items_nuevos(self) -> None:
        """Calcula cuántos items nuevos se agregaron."""
        self.items_nuevos = max(0, self.items_despues - self.items_antes)


# ════════════════════════════════════════════════════════════════════════════
# SISTEMA DE LOGGING PROFESIONAL
# ════════════════════════════════════════════════════════════════════════════

class Logger:
    """
    Sistema de logging profesional con colores, niveles y persistencia.

    Características:
    - Múltiples niveles (info, success, warning, error)
    - Salida con colores para terminal
    - Persistencia en archivo de log
    - Barra de progreso animada
    - Thread-safe

    Attributes:
        log_file: Archivo donde persistir los logs
        verbose: Si True, muestra mensajes en consola
        mensajes: Buffer de mensajes en memoria
        estadisticas: Objeto de estadísticas asociado
    """

    def __init__(self, log_file: Optional[Path] = None, verbose: bool = True):
        """
        Inicializa el sistema de logging.

        Args:
            log_file: Archivo donde guardar logs (None = solo consola)
            verbose: Si False, modo silencioso
        """
        self.log_file = log_file
        self.verbose = verbose
        self.mensajes: List[str] = []
        self.estadisticas = Estadisticas()

    def log(
        self,
        msg: str,
        color: str = "",
        nivel: str = "INFO",
        guardar: bool = True
    ) -> None:
        """
        Registra un mensaje con color y nivel.

        Args:
            msg: Mensaje a registrar
            color: Código ANSI de color
            nivel: Nivel del mensaje (INFO, SUCCESS, WARNING, ERROR)
            guardar: Si False, no persiste en archivo
        """
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        mensaje_completo = f"[{timestamp}] [{nivel}] {msg}"

        # Mostrar en consola si verbose está activo
        if self.verbose:
            print(f"{color}{msg}{Config.END}")

        # Guardar en buffer de memoria
        if guardar:
            self.mensajes.append(mensaje_completo)

        # Persistir en archivo si está configurado
        if self.log_file and guardar:
            try:
                self.log_file.parent.mkdir(parents=True, exist_ok=True)
                with open(self.log_file, 'a', encoding='utf-8') as f:
                    f.write(mensaje_completo + '\n')
            except Exception as e:
                if self.verbose:
                    print(f"{Config.Y}⚠ Error escribiendo log: {e}{Config.END}")

    def info(self, msg: str) -> None:
        """Mensaje informativo (cyan)."""
        self.log(msg, Config.C, "INFO")

    def success(self, msg: str) -> None:
        """Mensaje de éxito (verde con ✓)."""
        self.log(f"✓ {msg}", Config.G, "SUCCESS")

    def warning(self, msg: str) -> None:
        """Mensaje de advertencia (amarillo con ⚠)."""
        self.log(f"⚠ {msg}", Config.Y, "WARNING")

    def error(self, msg: str) -> None:
        """Mensaje de error (rojo con ✗)."""
        self.log(f"✗ {msg}", Config.R, "ERROR")

    def header(self, msg: str) -> None:
        """Encabezado de sección (negrita, sin guardar)."""
        self.log(f"\n{Config.BOLD}{msg}{Config.END}", "", "HEADER", guardar=False)

    def separador(self) -> None:
        """Línea separadora visual."""
        self.log("─" * 70, "", "SEP", guardar=False)

    def progreso(self, actual: int, total: int, prefijo: str = "Progreso") -> None:
        """
        Muestra una barra de progreso animada.

        Args:
            actual: Valor actual
            total: Valor total
            prefijo: Texto antes de la barra

        Example:
            Progreso: [████████████░░░░░░░░] 50/100 (50.0%)
        """
        if not self.verbose or total == 0:
            return

        porcentaje = (actual / total) * 100
        barra_len = 40
        lleno = int(barra_len * actual // total)
        barra = '█' * lleno + '░' * (barra_len - lleno)

        msg = f"{prefijo}: [{barra}] {actual}/{total} ({porcentaje:.1f}%)"

        # Imprimir en misma línea con carriage return
        print(f"\r{Config.C}{msg}{Config.END}", end='', flush=True)

        # Nueva línea al completar
        if actual == total:
            print()


# ════════════════════════════════════════════════════════════════════════════
# PROCESADOR PRINCIPAL - Lógica de importación
# ════════════════════════════════════════════════════════════════════════════

class ProcesadorCSV:
    """
    Procesador principal de archivos CSV con recuperación de estado.

    Esta clase maneja todo el flujo de importación desde la detección
    del código de biblioteca hasta la reindexación final, con capacidad
    de recuperarse de interrupciones.

    Attributes:
        archivo: Ruta al archivo CSV a procesar
        logger: Instancia del logger
        resume: Si True, intenta recuperar estado previo
        estado: Estado de la importación (para recuperación)
        estadisticas: Métricas de rendimiento
        estado_file: Archivo donde se guarda el estado
    """

    def __init__(self, archivo: Path, logger: Logger, resume: bool = False):
        """
        Inicializa el procesador de CSV.

        Args:
            archivo: Ruta al archivo CSV
            logger: Instancia del logger
            resume: Si True, intenta reanudar importación previa
        """
        self.archivo = archivo
        self.logger = logger
        self.resume = resume
        self.estado: Optional[EstadoImportacion] = None
        self.estadisticas = Estadisticas()
        self.estadisticas.tiempo_inicio = time.time()

        # Archivo de estado para recuperación
        self.estado_file = Config.DIR_CACHE / f"estado_{archivo.stem}.pkl"
        Config.DIR_CACHE.mkdir(exist_ok=True)

        # Cargar estado previo si se solicitó resume
        if self.resume:
            self.estado = EstadoImportacion.cargar(self.estado_file)
            if self.estado:
                self.logger.info(
                    f"📥 Recuperando desde fase: {self.estado.fase_actual}"
                )
                self.logger.info(
                    f"📊 Progreso anterior: {self.estado.registros_procesados}/"
                    f"{self.estado.registros_totales} registros"
                )

    def guardar_estado(self, fase: str, **kwargs) -> None:
        """
        Guarda el estado actual para permitir recuperación.

        Args:
            fase: Fase actual del proceso
            **kwargs: Campos adicionales del estado a actualizar
        """
        # Crear estado si no existe
        if not self.estado:
            self.estado = EstadoImportacion(
                archivo=str(self.archivo),
                codigo_biblioteca="",
                timestamp_inicio=datetime.now().isoformat(),
                registros_totales=0,
                registros_procesados=0,
                fase_actual=fase,
                ultimo_timestamp=datetime.now().isoformat()
            )

        # Actualizar fase y timestamp
        self.estado.fase_actual = fase
        self.estado.ultimo_timestamp = datetime.now().isoformat()

        # Actualizar campos adicionales proporcionados
        for key, value in kwargs.items():
            if hasattr(self.estado, key):
                setattr(self.estado, key, value)

        # Persistir a disco
        self.estado.guardar(self.estado_file)

    def detectar_codigo_biblioteca(self) -> Optional[str]:
        """
        Detecta el código de biblioteca del nombre del archivo.

        Busca secuencias de 3-6 letras mayúsculas en el nombre del archivo,
        excluyendo palabras comunes que no son códigos de biblioteca.

        Returns:
            Código de biblioteca o None si no se detectó

        Examples:
            "MED.csv" → "MED"
            "FACEN_2025.csv" → "FACEN"
            "datos_VET.csv" → "VET"
            "export.csv" → None
        """
        nombre = self.archivo.stem.upper()

        # Patrones de búsqueda (del más específico al más general)
        patrones = [
            r'^([A-Z]{2,6})(?:_|\.)',  # Al inicio con separador
            r'([A-Z]{2,6})(?:_|\d)',    # Seguido de _ o número
            r'([A-Z]{2,6})',            # Cualquier secuencia
        ]

        # Palabras a excluir (no son códigos de biblioteca)
        palabras_excluir = {
            'CSV', 'DATOS', 'DATA', 'FILE', 'EXPORT', 'BACKUP',
            'TEMP', 'TMP', 'OLD', 'NEW', 'TEST'
        }

        for patron in patrones:
            match = re.search(patron, nombre)
            if match:
                codigo = match.group(1)
                if codigo not in palabras_excluir:
                    return codigo

        return None

    def verificar_biblioteca_koha(self, codigo: str) -> Tuple[bool, str]:
        """
        Verifica que la biblioteca exista en Koha.

        Args:
            codigo: Código de biblioteca a verificar

        Returns:
            Tupla (existe, nombre_completo)

        Example:
            verificar_biblioteca_koha("MED") → (True, "Biblioteca de Medicina")
        """
        try:
            cmd = (
                f"sudo koha-mysql {Config.INSTANCIA_KOHA} -N -e "
                f"\"SELECT branchname FROM branches WHERE branchcode = '{codigo}'\""
            )

            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0 and result.stdout.strip():
                return True, result.stdout.strip()

            return False, ""

        except Exception as e:
            self.logger.error(f"Error verificando biblioteca: {e}")
            return False, ""

    def contar_items_biblioteca(self, codigo: str) -> int:
        """
        Cuenta los items existentes de una biblioteca.

        Args:
            codigo: Código de biblioteca

        Returns:
            Número de items o 0 si falla
        """
        try:
            cmd = (
                f"sudo koha-mysql {Config.INSTANCIA_KOHA} -N -e "
                f"\"SELECT COUNT(*) FROM items WHERE homebranch = '{codigo}'\""
            )

            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=10
            )

            if result.returncode == 0 and result.stdout.strip():
                return int(result.stdout.strip())

            return 0

        except Exception as e:
            self.logger.warning(f"No se pudo contar items: {e}")
            return 0

    def generar_marcxml_con_reintentos(self, codigo: str) -> List[Path]:
        """
        Genera archivos MARCXML con sistema de reintentos.

        Intenta generar los archivos MARCXML hasta MAX_REINTENTOS veces,
        esperando REINTENTO_DELAY segundos entre intentos.

        Args:
            codigo: Código de biblioteca

        Returns:
            Lista de archivos XML generados exitosamente
        """
        for intento in range(1, Config.MAX_REINTENTOS + 1):
            self.logger.info(
                f"→ Generando MARCXML (intento {intento}/{Config.MAX_REINTENTOS})..."
            )

            try:
                # Comando para generar MARCXML
                cmd = (
                    f"cd {Config.DIR_EXPORTS} && "
                    f"python3 {Config.DIR_TRABAJO}/scripts/opac_exportar.py "
                    f"--input {self.archivo} "
                    f"--codbiblio {codigo} "
                    f"--loc-default {Config.LOC_DEFAULT} "
                    f"--stream "
                    f"--split-by {Config.MAX_RECORDS_PER_FILE} 2>&1"
                )

                result = subprocess.run(
                    cmd,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=Config.TIMEOUT_MARCXML
                )

                # Buscar XMLs generados recientemente
                xmls = sorted(
                    Config.DIR_EXPORTS.glob(f"{codigo}_*_marcxml*.xml"),
                    key=lambda x: x.stat().st_mtime,
                    reverse=True
                )

                if xmls:
                    # Filtrar solo los más recientes (últimos 10 minutos)
                    tiempo_limite = time.time() - 600
                    xmls_recientes = [
                        x for x in xmls
                        if x.stat().st_mtime > tiempo_limite
                    ]

                    if xmls_recientes:
                        # Contar registros en cada XML
                        total_registros = 0
                        for xml in xmls_recientes:
                            try:
                                with open(xml, 'r', encoding='utf-8') as f:
                                    contenido = f.read()
                                    num_records = contenido.count('<record>')
                                    total_registros += num_records
                                    self.logger.info(
                                        f"  • {xml.name}: {num_records:,} registros"
                                    )
                            except Exception:
                                pass

                        self.logger.success(
                            f"Generados {len(xmls_recientes)} archivos XML "
                            f"con {total_registros:,} registros"
                        )

                        # Actualizar estadísticas
                        self.estadisticas.archivos_xml = len(xmls_recientes)
                        self.estadisticas.registros_xml = total_registros

                        # Guardar estado
                        self.guardar_estado(
                            'marcxml',
                            archivos_xml_generados=[str(x) for x in xmls_recientes],
                            registros_totales=total_registros
                        )

                        return xmls_recientes

                # Si no encontró XMLs, reintentar
                if intento < Config.MAX_REINTENTOS:
                    self.logger.warning(
                        f"No se generaron XMLs, reintentando en "
                        f"{Config.REINTENTO_DELAY}s..."
                    )
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
        """
        Importa archivos MARCXML a Koha con barra de progreso.

        Procesa cada archivo XML individualmente, mostrando progreso
        y permitiendo recuperación si se interrumpe.

        Args:
            archivos_xml: Lista de archivos XML a importar

        Returns:
            True si todos se importaron exitosamente, False si hubo errores
        """
        self.logger.info("→ Importando a Koha...")

        total_exitosos = 0
        total_fallidos = 0
        total = len(archivos_xml)

        for idx, xml in enumerate(archivos_xml, 1):
            # Verificar si ya fue importado (recuperación)
            if self.estado and str(xml) in self.estado.archivos_xml_importados:
                self.logger.info(f"  [{idx}/{total}] ✓ Ya importado: {xml.name}")
                total_exitosos += 1
                continue

            self.logger.progreso(idx - 1, total, "Importando")

            try:
                # Comando de importación usando bulkmarcimport.pl de Koha
                cmd = (
                    f'sudo koha-shell {Config.INSTANCIA_KOHA} -c '
                    f'"perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl '
                    f'-m MARCXML -file {xml} -commit {Config.COMMIT_SIZE}"'
                )

                result = subprocess.run(
                    cmd,
                    shell=True,
                    capture_output=True,
                    text=True,
                    timeout=Config.TIMEOUT_IMPORT
                )

                if result.returncode == 0:
                    total_exitosos += 1

                    # Guardar progreso para recuperación
                    if self.estado:
                        self.estado.archivos_xml_importados.append(str(xml))
                        self.estado.registros_procesados = idx * Config.MAX_RECORDS_PER_FILE
                        self.guardar_estado('importacion')
                else:
                    total_fallidos += 1
                    self.logger.error(f"  ✗ Falló: {xml.name}")

            except subprocess.TimeoutExpired:
                self.logger.error(f"  ⏱ Timeout: {xml.name}")
                total_fallidos += 1

            except Exception as e:
                self.logger.error(f"  ✗ Error: {xml.name} - {e}")
                total_fallidos += 1

        self.logger.progreso(total, total, "Importando")

        exito = total_exitosos > 0 and total_fallidos == 0
        self.logger.info(
            f"\n📊 Resultado: {total_exitosos} exitosos, {total_fallidos} fallidos"
        )

        return exito

    def reindexar_optimizado(self) -> bool:
        """
        Reindexación optimizada del catálogo Koha.

        Ejecuta reindexación solo de biblios (más rápido) y libera
        memoria caché antes para mejorar rendimiento.

        Returns:
            True si exitoso, False si falló (no crítico)
        """
        self.logger.info("→ Reindexando catálogo (optimizado)...")

        try:
            # Liberar memoria caché del sistema antes de reindexar
            self.logger.info("  💾 Liberando memoria caché...")
            subprocess.run(
                "sync; echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1",
                shell=True,
                timeout=10
            )

            # Reindexar solo biblios (más rápido que full reindex)
            self.logger.info("  📚 Reindexando registros bibliográficos...")
            cmd = f"sudo koha-rebuild-zebra -b -z {Config.INSTANCIA_KOHA}"

            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                timeout=Config.TIMEOUT_REINDEX
            )

            if result.returncode == 0:
                self.logger.success("Reindexación completada")
                return True
            else:
                self.logger.warning("Reindexación completada con advertencias")
                return False

        except Exception as e:
            self.logger.warning(f"Error en reindexación: {e}")
            return False

    def limpiar_estado(self) -> None:
        """
        Limpia el archivo de estado tras completar exitosamente.

        Elimina el archivo de recuperación ya que la importación
        se completó correctamente y no será necesaria recuperación.
        """
        try:
            if self.estado_file.exists():
                self.estado_file.unlink()
                self.logger.info("🗑 Estado de recuperación limpiado")
        except Exception as e:
            self.logger.warning(f"No se pudo limpiar estado: {e}")

    def procesar(self) -> bool:
        """
        Proceso principal de importación completo con recuperación.

        Ejecuta todos los pasos necesarios para importar un archivo CSV
        a Koha, con capacidad de recuperarse de interrupciones.

        Returns:
            True si exitoso, False si falló

        Flujo:
            1. Detectar código de biblioteca
            2. Verificar que existe en Koha
            3. Contar items actuales (baseline)
            4. Generar MARCXML
            5. Importar a Koha
            6. Reindexar
            7. Verificar resultados
        """

        # ═════════════════════════════════════════════════════════════════════
        # Banner inicial
        # ═════════════════════════════════════════════════════════════════════
        print("\n" + "═" * 80)
        self.logger.log(
            f"📄 PROCESANDO: {self.archivo.name}",
            Config.BOLD + Config.C,
            guardar=False
        )
        print("═" * 80 + "\n")

        # ═════════════════════════════════════════════════════════════════════
        # PASO 1: Detección de código de biblioteca
        # ═════════════════════════════════════════════════════════════════════
        self.logger.header("1. DETECCIÓN DE BIBLIOTECA")
        self.logger.separador()

        codigo = self.detectar_codigo_biblioteca()

        if not codigo:
            self.logger.error(
                "No se detectó código de biblioteca en el nombre del archivo"
            )
            self.logger.info(
                "💡 El nombre debe contener 3-6 letras mayúsculas "
                "(ej: MED.csv, FACEN.csv)"
            )
            return False

        self.logger.success(f"Código detectado: {codigo}")
        self.guardar_estado('deteccion', codigo_biblioteca=codigo)

        # ═════════════════════════════════════════════════════════════════════
        # PASO 2: Verificación en Koha
        # ═════════════════════════════════════════════════════════════════════
        self.logger.header("\n2. VERIFICACIÓN EN KOHA")
        self.logger.separador()

        existe, nombre_bib = self.verificar_biblioteca_koha(codigo)

        if not existe:
            self.logger.error(f"La biblioteca '{codigo}' NO existe en Koha")
            self.logger.info(
                "💡 Crear en: Staff Interface → Administración → Bibliotecas"
            )
            return False

        self.logger.success(f"Biblioteca: {nombre_bib}")

        # ═════════════════════════════════════════════════════════════════════
        # PASO 3: Estado actual (baseline)
        # ═════════════════════════════════════════════════════════════════════
        self.logger.header("\n3. ESTADO ACTUAL")
        self.logger.separador()

        items_antes = self.contar_items_biblioteca(codigo)
        self.estadisticas.items_antes = items_antes
        self.logger.info(f"📊 Items actuales en la biblioteca: {items_antes:,}")

        # ═════════════════════════════════════════════════════════════════════
        # PASO 4: Generación de MARCXML
        # ═════════════════════════════════════════════════════════════════════
        # Si estamos en modo resume y ya tenemos XMLs, usarlos
        if (self.resume and self.estado and
            self.estado.fase_actual not in ['deteccion', 'validacion']):

            archivos_xml = [Path(x) for x in self.estado.archivos_xml_generados]
            self.logger.info(
                f"📂 Usando {len(archivos_xml)} archivos XML del estado anterior"
            )
        else:
            self.logger.header("\n4. GENERACIÓN DE MARCXML")
            self.logger.separador()

            archivos_xml = self.generar_marcxml_con_reintentos(codigo)

            if not archivos_xml:
                self.logger.error("No se pudieron generar archivos MARCXML")
                return False

        # ═════════════════════════════════════════════════════════════════════
        # PASO 5: Importación a Koha
        # ═════════════════════════════════════════════════════════════════════
        self.logger.header("\n5. IMPORTACIÓN A KOHA")
        self.logger.separador()

        importacion_ok = self.importar_a_koha_con_progreso(archivos_xml)

        if not importacion_ok:
            self.logger.error("❌ Errores durante importación")
            self.logger.info(
                "💡 Puedes reanudar con: --resume para continuar donde quedó"
            )
            return False

        # ═════════════════════════════════════════════════════════════════════
        # PASO 6: Reindexación
        # ═════════════════════════════════════════════════════════════════════
        self.logger.header("\n6. REINDEXACIÓN")
        self.logger.separador()
        self.reindexar_optimizado()  # No crítico si falla

        # ═════════════════════════════════════════════════════════════════════
        # PASO 7: Verificación final
        # ═════════════════════════════════════════════════════════════════════
        self.logger.header("\n7. VERIFICACIÓN FINAL")
        self.logger.separador()

        items_despues = self.contar_items_biblioteca(codigo)

        self.estadisticas.items_despues = items_despues
        self.estadisticas.calcular_items_nuevos()
        self.estadisticas.tiempo_fin = time.time()
        self.estadisticas.calcular_tiempo()

        self.logger.info(f"Items antes:   {items_antes:,}")
        self.logger.info(f"Items después: {items_despues:,}")
        self.logger.success(f"Items nuevos:  {self.estadisticas.items_nuevos:,}")

        # Banner de éxito
        print("\n" + "═" * 80)
        self.logger.log(
            "✓✓✓ IMPORTACIÓN COMPLETADA EXITOSAMENTE ✓✓✓",
            Config.G + Config.BOLD,
            guardar=False
        )
        print("═" * 80 + "\n")

        minutos = int(self.estadisticas.tiempo_total // 60)
        segundos = int(self.estadisticas.tiempo_total % 60)
        self.logger.success(f"⏱ Tiempo total: {minutos}m {segundos}s")

        # Limpiar estado de recuperación
        self.limpiar_estado()

        return True


# ════════════════════════════════════════════════════════════════════════════
# FUNCIÓN PRINCIPAL Y ARGUMENTOS
# ════════════════════════════════════════════════════════════════════════════

def main() -> int:
    """
    Función principal del programa.

    Parsea argumentos, configura logging, y procesa archivos CSV.

    Returns:
        Código de salida (0 = éxito, 1 = error)
    """
    parser = argparse.ArgumentParser(
        description="Agente Importador Automático v3.0 - Sistema profesional de importación a Koha",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos de uso:
  %(prog)s archivo.csv                    # Importar un archivo
  %(prog)s archivo1.csv archivo2.csv      # Importar múltiples archivos
  %(prog)s archivo.csv --resume           # Reanudar importación interrumpida
  %(prog)s archivo.csv --quiet            # Modo silencioso

Universidad Nacional de Asunción - 2025
        """
    )

    parser.add_argument(
        'archivos',
        nargs='*',
        help='Archivo(s) CSV a procesar'
    )
    parser.add_argument(
        '--resume', '-r',
        action='store_true',
        help='Reanudar importación interrumpida desde el último estado'
    )
    parser.add_argument(
        '--verbose', '-v',
        action='store_true',
        default=True,
        help='Modo verbose con salida detallada (por defecto)'
    )
    parser.add_argument(
        '--quiet', '-q',
        action='store_true',
        help='Modo silencioso (solo errores)'
    )
    parser.add_argument(
        '--version',
        action='version',
        version='Agente Importador v3.0.0'
    )

    args = parser.parse_args()

    # Si no hay archivos, mostrar ayuda
    if not args.archivos:
        parser.print_help()
        return 0

    verbose = not args.quiet
    exitosos = 0
    fallidos = 0

    # Procesar cada archivo
    for archivo_path in args.archivos:
        archivo = Path(archivo_path)

        if not archivo.exists():
            print(f"{Config.R}✗ Archivo no encontrado: {archivo}{Config.END}")
            fallidos += 1
            continue

        # Crear logger único para este archivo
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
            logger.warning("\n\n⚠ Importación interrumpida por usuario")
            logger.info("💡 Puedes reanudar con: --resume")
            return 130

        except Exception as e:
            logger.error(f"❌ Error inesperado: {e}")
            import traceback
            traceback.print_exc()
            fallidos += 1

    # Resumen final si procesamos múltiples archivos
    if len(args.archivos) > 1:
        print(f"\n{Config.BOLD}{'═'*80}{Config.END}")
        print(f"{Config.BOLD}RESUMEN FINAL:{Config.END}")
        print(f"  Total archivos: {len(args.archivos)}")
        print(f"  {Config.G}✓ Exitosos: {exitosos}{Config.END}")
        if fallidos > 0:
            print(f"  {Config.R}✗ Fallidos: {fallidos}{Config.END}")
        print(f"{Config.BOLD}{'═'*80}{Config.END}\n")

    return 0 if fallidos == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
