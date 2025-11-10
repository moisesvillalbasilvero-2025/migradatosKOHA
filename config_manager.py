#!/usr/bin/env python3
"""
GESTOR DE CONFIGURACIÓN CENTRALIZADO
====================================
Sistema de configuración centralizado para el proyecto de migración a Koha.

Este módulo proporciona:
- Carga de variables de entorno desde archivo .env
- Lectura de configuración desde migracion_config.json
- API unificada para acceso a configuración
- Validación de configuración
- Backward compatibility con scripts antiguos
- Gestión segura de credenciales

USO:
    from config_manager import get_config

    config = get_config()
    print(config.DIR_TRABAJO)
    print(config.INSTANCIA_KOHA)

AUTOR: Universidad Nacional de Asunción
VERSIÓN: 1.0
FECHA: 2025-11-10
"""

import os
import sys
import json
from pathlib import Path
from typing import Dict, Any, Optional
from dataclasses import dataclass, field
import multiprocessing as mp

# Intentar importar dotenv, pero no fallar si no está disponible
try:
    from dotenv import load_dotenv
    DOTENV_AVAILABLE = True
except ImportError:
    DOTENV_AVAILABLE = False
    print("⚠ python-dotenv no disponible. Las variables de entorno se cargarán del sistema.")


# ============================================================================
# CLASE DE CONFIGURACIÓN
# ============================================================================

@dataclass
class Config:
    """
    Configuración centralizada del sistema.

    Esta clase almacena toda la configuración del sistema y proporciona
    valores por defecto seguros. Los valores pueden ser sobrescritos por:
    1. Variables de entorno (desde .env o sistema)
    2. Archivo migracion_config.json
    3. Parámetros pasados al constructor
    """

    # -------------------- Rutas del sistema --------------------
    DIR_TRABAJO: Path = None
    DIR_VIGILAR: Path = None
    DIR_PROCESADOS: Path = None
    DIR_ERRORES: Path = None
    DIR_EXPORTS: Path = None
    DIR_LOGS: Path = None
    DIR_CACHE: Path = None
    DIR_REPORTES: Path = None
    DIR_BACKUPS: Path = None

    # -------------------- Configuración Koha --------------------
    INSTANCIA_KOHA: str = "koha-cnc"
    LOC_DEFAULT: str = "SALA"

    # -------------------- Tamaños y límites --------------------
    COMMIT_SIZE: int = 1000
    CHUNK_SIZE: int = 2000
    MAX_RECORDS_PER_FILE: int = 5000

    # -------------------- Procesamiento paralelo ----------------
    NUM_WORKERS: int = 0  # 0 = auto-detectar

    # -------------------- Timeouts (segundos) -------------------
    TIMEOUT_MARCXML: int = 900
    TIMEOUT_IMPORT: int = 2400
    TIMEOUT_REINDEX: int = 1200
    TIMEOUT_CORRECCION: int = 300

    # -------------------- Reintentos ----------------------------
    MAX_REINTENTOS: int = 3
    REINTENTO_DELAY: int = 5

    # -------------------- Caché ---------------------------------
    CACHE_VERIFICACIONES: bool = True
    CACHE_TTL: int = 3600

    # -------------------- Colores ANSI --------------------------
    G: str = '\033[92m'
    Y: str = '\033[93m'
    R: str = '\033[91m'
    B: str = '\033[94m'
    C: str = '\033[96m'
    M: str = '\033[95m'
    BOLD: str = '\033[1m'
    END: str = '\033[0m'

    # -------------------- Email (opcional) ----------------------
    EMAIL_ENABLED: bool = False
    EMAIL_SMTP_SERVER: str = ""
    EMAIL_SMTP_PORT: int = 587
    EMAIL_USER: str = ""
    EMAIL_PASSWORD: str = ""
    EMAIL_RECIPIENTS: list = field(default_factory=list)

    # -------------------- Configuración adicional ---------------
    LOG_LEVEL: str = "INFO"
    LOG_VERBOSE: bool = True
    VALIDATION_STRICT: bool = False
    BACKUP_BEFORE_IMPORT: bool = True
    PAUSE_BETWEEN_IMPORTS: int = 5

    # -------------------- Datos de bibliotecas -----------------
    bibliotecas: Dict[str, Any] = field(default_factory=dict)

    def __post_init__(self):
        """Inicialización post-creación"""
        # Si DIR_TRABAJO es None, usar directorio actual del proyecto
        if self.DIR_TRABAJO is None:
            # Intentar detectar el directorio del proyecto
            script_dir = Path(__file__).parent.absolute()
            self.DIR_TRABAJO = script_dir

        # Asegurar que DIR_TRABAJO sea Path
        if not isinstance(self.DIR_TRABAJO, Path):
            self.DIR_TRABAJO = Path(self.DIR_TRABAJO)

        # Crear rutas derivadas si no están establecidas
        if self.DIR_VIGILAR is None:
            self.DIR_VIGILAR = self.DIR_TRABAJO / "importar_aqui"
        if self.DIR_PROCESADOS is None:
            self.DIR_PROCESADOS = self.DIR_TRABAJO / "procesados"
        if self.DIR_ERRORES is None:
            self.DIR_ERRORES = self.DIR_TRABAJO / "errores"
        if self.DIR_EXPORTS is None:
            self.DIR_EXPORTS = self.DIR_TRABAJO / "exports"
        if self.DIR_LOGS is None:
            self.DIR_LOGS = self.DIR_TRABAJO / "logs"
        if self.DIR_CACHE is None:
            self.DIR_CACHE = self.DIR_TRABAJO / ".cache"
        if self.DIR_REPORTES is None:
            self.DIR_REPORTES = self.DIR_TRABAJO / "reportes"
        if self.DIR_BACKUPS is None:
            self.DIR_BACKUPS = self.DIR_TRABAJO / "backups"

        # Convertir todas las rutas a Path
        for attr in ['DIR_VIGILAR', 'DIR_PROCESADOS', 'DIR_ERRORES',
                     'DIR_EXPORTS', 'DIR_LOGS', 'DIR_CACHE',
                     'DIR_REPORTES', 'DIR_BACKUPS']:
            value = getattr(self, attr)
            if not isinstance(value, Path):
                setattr(self, attr, Path(value))

        # Auto-detectar workers si es 0
        if self.NUM_WORKERS == 0:
            self.NUM_WORKERS = max(1, mp.cpu_count() - 1)

    def crear_directorios(self):
        """Crea todos los directorios necesarios"""
        directorios = [
            self.DIR_TRABAJO,
            self.DIR_VIGILAR,
            self.DIR_PROCESADOS,
            self.DIR_ERRORES,
            self.DIR_EXPORTS,
            self.DIR_LOGS,
            self.DIR_CACHE,
            self.DIR_REPORTES,
            self.DIR_BACKUPS
        ]

        for directorio in directorios:
            try:
                directorio.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                print(f"⚠ No se pudo crear directorio {directorio}: {e}")

    def get_firebird_config(self, codigo_biblioteca: str) -> Optional[Dict[str, Any]]:
        """
        Obtiene configuración de Firebird para una biblioteca.

        Busca primero en variables de entorno, luego en migracion_config.json

        Args:
            codigo_biblioteca: Código de la biblioteca (ej: "FACAGR")

        Returns:
            Diccionario con configuración de Firebird o None si no existe
        """
        # Intentar cargar desde variables de entorno
        env_prefix = f"FIREBIRD_{codigo_biblioteca}_"

        if os.getenv(f"{env_prefix}HOST"):
            return {
                'host': os.getenv(f"{env_prefix}HOST"),
                'port': int(os.getenv(f"{env_prefix}PORT", "3050")),
                'database': os.getenv(f"{env_prefix}DATABASE"),
                'user': os.getenv(f"{env_prefix}USER", "SYSDBA"),
                'password': os.getenv(f"{env_prefix}PASSWORD", ""),
                'charset': os.getenv(f"{env_prefix}CHARSET", "UTF8"),
            }

        # Intentar cargar desde bibliotecas
        if codigo_biblioteca in self.bibliotecas:
            bib_config = self.bibliotecas[codigo_biblioteca]
            if 'firebird' in bib_config:
                return bib_config['firebird']

        return None

    def validar(self) -> bool:
        """
        Valida la configuración.

        Returns:
            True si la configuración es válida, False en caso contrario
        """
        errores = []

        # Validar que DIR_TRABAJO existe o puede ser creado
        if not self.DIR_TRABAJO.exists():
            try:
                self.DIR_TRABAJO.mkdir(parents=True, exist_ok=True)
            except Exception as e:
                errores.append(f"No se puede crear DIR_TRABAJO: {e}")

        # Validar valores numéricos
        if self.COMMIT_SIZE <= 0:
            errores.append("COMMIT_SIZE debe ser > 0")

        if self.NUM_WORKERS < 0:
            errores.append("NUM_WORKERS debe ser >= 0")

        # Mostrar errores si los hay
        if errores:
            print(f"{self.R}Errores de configuración:{self.END}")
            for error in errores:
                print(f"  ✗ {error}")
            return False

        return True


# ============================================================================
# GESTOR DE CONFIGURACIÓN
# ============================================================================

class ConfigManager:
    """
    Gestor centralizado de configuración.

    Carga configuración desde múltiples fuentes en orden de prioridad:
    1. Variables de entorno (desde .env o sistema)
    2. Archivo migracion_config.json
    3. Valores por defecto
    """

    _instance = None
    _config = None

    def __new__(cls):
        """Singleton para asegurar una sola instancia"""
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        """Inicializa el gestor (solo una vez)"""
        if self._config is None:
            self._config = self._cargar_configuracion()

    def _cargar_configuracion(self) -> Config:
        """Carga configuración desde todas las fuentes"""

        # Paso 1: Cargar .env si está disponible
        self._cargar_dotenv()

        # Paso 2: Crear configuración base con variables de entorno
        config = self._crear_config_desde_env()

        # Paso 3: Cargar y fusionar migracion_config.json
        self._cargar_json_config(config)

        # Paso 4: Validar configuración
        if not config.validar():
            print(f"{config.Y}⚠ Advertencia: Configuración con problemas{config.END}")

        return config

    def _cargar_dotenv(self):
        """Carga variables de entorno desde archivo .env"""
        if not DOTENV_AVAILABLE:
            return

        # Buscar .env en el directorio del script o directorio actual
        script_dir = Path(__file__).parent
        env_paths = [
            script_dir / ".env",
            Path.cwd() / ".env",
        ]

        for env_path in env_paths:
            if env_path.exists():
                load_dotenv(env_path)
                print(f"✓ Variables de entorno cargadas desde: {env_path}")
                return

        # No encontró .env, usar variables del sistema
        print("ℹ No se encontró archivo .env, usando variables del sistema")

    def _crear_config_desde_env(self) -> Config:
        """Crea objeto Config desde variables de entorno"""

        def get_env(key: str, default: Any = None, cast_type: type = str) -> Any:
            """Helper para obtener variable de entorno con casting"""
            value = os.getenv(key)
            if value is None:
                return default

            try:
                if cast_type == bool:
                    return value.lower() in ('true', '1', 'yes', 'si')
                elif cast_type == int:
                    return int(value)
                elif cast_type == Path:
                    return Path(value)
                elif cast_type == list:
                    return [x.strip() for x in value.split(',') if x.strip()]
                else:
                    return cast_type(value)
            except (ValueError, TypeError):
                return default

        # Determinar DIR_TRABAJO
        dir_trabajo = get_env('KOHA_MIGRA_HOME', cast_type=Path)
        if dir_trabajo is None:
            # Si no está definido, usar directorio del script
            dir_trabajo = Path(__file__).parent.absolute()

        return Config(
            # Rutas
            DIR_TRABAJO=dir_trabajo,
            DIR_EXPORTS=get_env('KOHA_MIGRA_EXPORTS', cast_type=Path),
            DIR_LOGS=get_env('KOHA_MIGRA_LOGS', cast_type=Path),
            DIR_CACHE=get_env('KOHA_MIGRA_CACHE', cast_type=Path),
            DIR_VIGILAR=get_env('KOHA_MIGRA_WATCH_DIR', cast_type=Path),

            # Koha
            INSTANCIA_KOHA=get_env('KOHA_INSTANCE', 'koha-cnc'),
            LOC_DEFAULT=get_env('KOHA_LOC_DEFAULT', 'SALA'),

            # Tamaños
            CHUNK_SIZE=get_env('KOHA_CHUNK_SIZE', 2000, int),
            COMMIT_SIZE=get_env('KOHA_COMMIT_SIZE', 1000, int),
            MAX_RECORDS_PER_FILE=get_env('KOHA_MAX_RECORDS_PER_FILE', 5000, int),

            # Workers
            NUM_WORKERS=get_env('KOHA_NUM_WORKERS', 0, int),

            # Timeouts
            TIMEOUT_MARCXML=get_env('KOHA_TIMEOUT_MARCXML', 900, int),
            TIMEOUT_IMPORT=get_env('KOHA_TIMEOUT_IMPORT', 2400, int),
            TIMEOUT_REINDEX=get_env('KOHA_TIMEOUT_REINDEX', 1200, int),

            # Caché
            CACHE_VERIFICACIONES=get_env('KOHA_CACHE_ENABLED', True, bool),
            CACHE_TTL=get_env('KOHA_CACHE_TTL', 3600, int),

            # Email
            EMAIL_ENABLED=get_env('EMAIL_ENABLED', False, bool),
            EMAIL_SMTP_SERVER=get_env('EMAIL_SMTP_SERVER', ''),
            EMAIL_SMTP_PORT=get_env('EMAIL_SMTP_PORT', 587, int),
            EMAIL_USER=get_env('EMAIL_USER', ''),
            EMAIL_PASSWORD=get_env('EMAIL_PASSWORD', ''),
            EMAIL_RECIPIENTS=get_env('EMAIL_RECIPIENTS', [], list),

            # Logging
            LOG_LEVEL=get_env('LOG_LEVEL', 'INFO'),
            LOG_VERBOSE=get_env('LOG_VERBOSE', True, bool),

            # Validación y seguridad
            VALIDATION_STRICT=get_env('VALIDATION_STRICT', False, bool),
            BACKUP_BEFORE_IMPORT=get_env('BACKUP_BEFORE_IMPORT', True, bool),
            PAUSE_BETWEEN_IMPORTS=get_env('PAUSE_BETWEEN_IMPORTS', 5, int),
            MAX_REINTENTOS=get_env('MAX_RETRIES', 3, int),
        )

    def _cargar_json_config(self, config: Config):
        """Carga y fusiona configuración desde migracion_config.json"""
        json_path = config.DIR_TRABAJO / "config" / "migracion_config.json"

        if not json_path.exists():
            print(f"ℹ No se encontró {json_path}, usando solo variables de entorno")
            return

        try:
            with open(json_path, 'r', encoding='utf-8') as f:
                json_config = json.load(f)

            # Fusionar configuración de Koha
            if 'koha' in json_config:
                koha_cfg = json_config['koha']
                if 'instancia' in koha_cfg:
                    config.INSTANCIA_KOHA = koha_cfg['instancia']
                if 'commit_size' in koha_cfg:
                    config.COMMIT_SIZE = koha_cfg['commit_size']

            # Fusionar configuración de rutas (solo si no están en env)
            if 'rutas' in json_config and os.getenv('KOHA_MIGRA_HOME') is None:
                rutas_cfg = json_config['rutas']
                if 'trabajo' in rutas_cfg:
                    config.DIR_TRABAJO = Path(rutas_cfg['trabajo'])
                    # Recalcular rutas derivadas
                    config.__post_init__()

            # Cargar bibliotecas
            if 'bibliotecas' in json_config:
                config.bibliotecas = json_config['bibliotecas']

            print(f"✓ Configuración cargada desde: {json_path}")

        except json.JSONDecodeError as e:
            print(f"⚠ Error al parsear {json_path}: {e}")
        except Exception as e:
            print(f"⚠ Error cargando {json_path}: {e}")

    def get_config(self) -> Config:
        """Obtiene la configuración actual"""
        return self._config

    def reload(self):
        """Recarga la configuración"""
        self._config = self._cargar_configuracion()


# ============================================================================
# API PÚBLICA
# ============================================================================

def get_config() -> Config:
    """
    Obtiene la configuración global del sistema.

    Esta es la función principal que deben usar todos los scripts.

    Returns:
        Objeto Config con toda la configuración del sistema

    Ejemplo:
        from config_manager import get_config

        config = get_config()
        print(config.DIR_TRABAJO)
        print(config.INSTANCIA_KOHA)
    """
    manager = ConfigManager()
    return manager.get_config()


def reload_config():
    """Recarga la configuración desde las fuentes"""
    manager = ConfigManager()
    manager.reload()


# ============================================================================
# TESTING Y DIAGNÓSTICO
# ============================================================================

def print_config():
    """Imprime la configuración actual (para debugging)"""
    config = get_config()

    print(f"\n{config.BOLD}{config.C}{'='*70}{config.END}")
    print(f"{config.BOLD}{config.C}CONFIGURACIÓN DEL SISTEMA{config.END}")
    print(f"{config.BOLD}{config.C}{'='*70}{config.END}\n")

    print(f"{config.BOLD}Rutas del Sistema:{config.END}")
    print(f"  DIR_TRABAJO:    {config.DIR_TRABAJO}")
    print(f"  DIR_EXPORTS:    {config.DIR_EXPORTS}")
    print(f"  DIR_LOGS:       {config.DIR_LOGS}")
    print(f"  DIR_CACHE:      {config.DIR_CACHE}")
    print(f"  DIR_VIGILAR:    {config.DIR_VIGILAR}")

    print(f"\n{config.BOLD}Configuración Koha:{config.END}")
    print(f"  INSTANCIA_KOHA: {config.INSTANCIA_KOHA}")
    print(f"  LOC_DEFAULT:    {config.LOC_DEFAULT}")
    print(f"  COMMIT_SIZE:    {config.COMMIT_SIZE}")

    print(f"\n{config.BOLD}Rendimiento:{config.END}")
    print(f"  NUM_WORKERS:    {config.NUM_WORKERS}")
    print(f"  CHUNK_SIZE:     {config.CHUNK_SIZE}")
    print(f"  MAX_RECORDS:    {config.MAX_RECORDS_PER_FILE}")

    print(f"\n{config.BOLD}Bibliotecas configuradas:{config.END}")
    if config.bibliotecas:
        for codigo, info in config.bibliotecas.items():
            nombre = info.get('nombre', 'Sin nombre')
            activa = info.get('activa', False)
            estado = f"{config.G}ACTIVA{config.END}" if activa else f"{config.Y}INACTIVA{config.END}"
            print(f"  {codigo:10} - {nombre:40} [{estado}]")
    else:
        print(f"  {config.Y}No hay bibliotecas configuradas{config.END}")

    print(f"\n{config.BOLD}{config.C}{'='*70}{config.END}\n")


# ============================================================================
# MAIN (para testing)
# ============================================================================

if __name__ == '__main__':
    print("GESTOR DE CONFIGURACIÓN - Sistema de Importación Koha UNA\n")

    # Imprimir configuración
    print_config()

    # Ejemplo de uso
    config = get_config()

    print(f"{config.BOLD}Ejemplo de uso en scripts:{config.END}")
    print("""
from config_manager import get_config

config = get_config()

# Usar configuración
print(f"Trabajando en: {config.DIR_TRABAJO}")
print(f"Instancia Koha: {config.INSTANCIA_KOHA}")

# Obtener configuración de Firebird
fb_config = config.get_firebird_config('FACAGR')
if fb_config:
    print(f"Firebird host: {fb_config['host']}")
    """)
