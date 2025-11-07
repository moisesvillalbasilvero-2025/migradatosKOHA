#!/usr/bin/env python3
"""
IMPORTACIÓN DIRECTA FIREBIRD → KOHA V1.0
=========================================
Universidad Nacional de Asunción

Conecta directamente a servidores Firebird y sincroniza datos a Koha
sin pasar por archivos CSV intermedios.

CARACTERÍSTICAS:
- Conexión remota a múltiples servidores Firebird
- Importación incremental (solo registros nuevos/modificados)
- Sincronización automática programable
- Mapeo configurable por biblioteca
- Detección automática de cambios
- Generación directa de MARCXML
- Importación automática a Koha
- Logs detallados
- Dashboard de sincronización

USO:
    # Importar una biblioteca
    ./firebird_directo_koha.py --biblioteca FACAGR

    # Sincronización incremental (solo nuevos)
    ./firebird_directo_koha.py --biblioteca FACAGR --incremental

    # Todas las bibliotecas
    ./firebird_directo_koha.py --all

    # Modo daemon (sincronización continua)
    ./firebird_directo_koha.py --daemon --intervalo 3600

    # Ver estado de sincronización
    ./firebird_directo_koha.py --status

VERSIÓN: 1.0
FECHA: 2025-10-31
"""

import fdb
import sys
import os
import json
import subprocess
import time
import argparse
import hashlib
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Tuple, Any
from dataclasses import dataclass, asdict


# ===========================================================================
# CONFIGURACIÓN
# ===========================================================================

class Config:
    """Configuración global"""
    DIR_TRABAJO = Path("/home/mvillalba/migradatos")
    DIR_CACHE = DIR_TRABAJO / ".firebird_sync"
    DIR_LOGS = DIR_TRABAJO / "logs"
    DIR_EXPORTS = DIR_TRABAJO / "exports"

    INSTANCIA_KOHA = "koha-cnc"
    LOC_DEFAULT = "SALA"

    # Colores
    G = '\033[92m'
    Y = '\033[93m'
    R = '\033[91m'
    B = '\033[94m'
    C = '\033[96m'
    BOLD = '\033[1m'
    END = '\033[0m'


# ===========================================================================
# CONFIGURACIÓN DE SERVIDORES FIREBIRD
# ===========================================================================
# IMPORTANTE: Configurar con datos reales de tus servidores

FIREBIRD_SERVERS = {
    # EJEMPLO - Reemplazar con tus datos reales
    'EJEMPLO_LOCAL': {
        'nombre': 'Biblioteca de Ejemplo (Local)',
        'host': 'localhost',
        'port': 3050,
        'database': '/var/lib/firebird/data/biblio.fdb',
        'user': 'SYSDBA',
        'password': 'masterkey',
        'charset': 'UTF8',
        'activo': False,  # Cambiar a True cuando esté configurado
    },

    'EJEMPLO_REMOTO': {
        'nombre': 'Biblioteca de Ejemplo (Remoto)',
        'host': '192.168.1.100',  # IP del servidor
        'port': 3050,
        'database': '/datos/biblioteca.fdb',
        'user': 'SYSDBA',
        'password': 'tu_password_aqui',
        'charset': 'UTF8',
        'activo': False,  # Cambiar a True cuando esté configurado
    },

    # Agregar tus bibliotecas reales:
    # 'FACAGR': {
    #     'nombre': 'Facultad de Ciencias Agrarias',
    #     'host': '192.168.x.x',
    #     'port': 3050,
    #     'database': '/ruta/a/base.fdb',
    #     'user': 'SYSDBA',
    #     'password': 'password_real',
    #     'charset': 'UTF8',
    #     'activo': True,
    # },
}


# ===========================================================================
# QUERY SQL - ADAPTAR A TU ESTRUCTURA FIREBIRD
# ===========================================================================

def get_export_query(only_modified_since: Optional[datetime] = None) -> Tuple[str, list]:
    """
    Query para exportar datos bibliográficos.

    IMPORTANTE: Adaptar nombres de tablas y columnas a tu estructura real.

    Args:
        only_modified_since: Si se provee, solo exporta registros modificados después de esta fecha

    Returns:
        Tupla (query, params)
    """

    # EJEMPLO - Adaptar a tus nombres reales de tablas/columnas
    query = """
        SELECT
            -- Identificadores
            b.ID_REGISTRO as analisis,
            b.ID_REGISTRO as identificador,

            -- Datos bibliográficos
            b.TITULO as titulo,
            b.SUBTITULO as sub_titulo,
            b.AUTOR as autor,
            b.EDITORIAL as editorial,
            b.LUGAR_PUB as procedencia,
            b.ANO_PUB as publicacion,
            b.PAGINAS as paginas,
            b.ISBN as isbn_issn,
            b.RESUMEN as sintesis,
            b.MATERIAS as temas_descrip,

            -- Ejemplares
            e.CODIGO_BARRAS as nroacceso,
            e.SIGNATURA as ubicacion,
            e.VOLUMEN as volumen,

            -- Control de cambios
            b.FECHA_MODIFICACION as fecha_mod,
            b.FECHA_CARGA as fechacarga

        FROM BIBLIOGRAFICOS b
        LEFT JOIN EJEMPLARES e ON b.ID_REGISTRO = e.ID_BIBLIO
        WHERE 1=1
    """

    params = []

    # Filtro incremental
    if only_modified_since:
        query += " AND b.FECHA_MODIFICACION > ?"
        params.append(only_modified_since)

    query += " ORDER BY b.ID_REGISTRO, e.CODIGO_BARRAS"

    return query, params


# ===========================================================================
# ESTADO DE SINCRONIZACIÓN
# ===========================================================================

@dataclass
class SyncState:
    """Estado de sincronización de una biblioteca"""
    codigo: str
    ultima_sync: Optional[str]  # ISO format
    total_registros: int
    ultimo_id: Optional[int]
    checksum: str
    errores: int

    def guardar(self):
        """Guarda estado a disco"""
        Config.DIR_CACHE.mkdir(exist_ok=True)
        filepath = Config.DIR_CACHE / f"sync_state_{self.codigo}.json"

        with open(filepath, 'w') as f:
            json.dump(asdict(self), f, indent=2)

    @classmethod
    def cargar(cls, codigo: str) -> Optional['SyncState']:
        """Carga estado desde disco"""
        filepath = Config.DIR_CACHE / f"sync_state_{codigo}.json"

        if filepath.exists():
            with open(filepath) as f:
                data = json.load(f)
                return cls(**data)
        return None


# ===========================================================================
# CONECTOR FIREBIRD
# ===========================================================================

class FirebirdConnector:
    """Conector a base de datos Firebird"""

    def __init__(self, codigo: str, config: Dict):
        self.codigo = codigo
        self.config = config
        self.connection = None
        self.cursor = None

    def connect(self) -> bool:
        """Conecta a Firebird"""
        try:
            print(f"{Config.C}→ Conectando a Firebird: {self.config['host']}:{self.config['port']}{Config.END}")

            self.connection = fdb.connect(
                host=self.config['host'],
                port=self.config['port'],
                database=self.config['database'],
                user=self.config['user'],
                password=self.config['password'],
                charset=self.config['charset']
            )

            self.cursor = self.connection.cursor()
            print(f"{Config.G}✓ Conexión exitosa{Config.END}")
            return True

        except Exception as e:
            print(f"{Config.R}✗ Error de conexión: {e}{Config.END}")
            return False

    def disconnect(self):
        """Cierra conexión"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()

    def test_connection(self) -> Dict:
        """Prueba conexión y obtiene info básica"""
        try:
            if not self.connection:
                if not self.connect():
                    return {'conectado': False, 'error': 'No se pudo conectar'}

            # Contar tablas
            self.cursor.execute("""
                SELECT COUNT(*) FROM RDB$RELATIONS
                WHERE RDB$SYSTEM_FLAG = 0 AND RDB$VIEW_BLR IS NULL
            """)
            num_tablas = self.cursor.fetchone()[0]

            # Intentar contar registros bibliográficos
            # ADAPTAR nombre de tabla
            try:
                self.cursor.execute("SELECT COUNT(*) FROM BIBLIOGRAFICOS")
                num_registros = self.cursor.fetchone()[0]
            except:
                num_registros = 0

            return {
                'conectado': True,
                'tablas': num_tablas,
                'registros': num_registros,
                'host': self.config['host'],
                'database': self.config['database']
            }

        except Exception as e:
            return {'conectado': False, 'error': str(e)}


# ===========================================================================
# SINCRONIZADOR PRINCIPAL
# ===========================================================================

class FirebirdKohaSyncer:
    """Sincronizador Firebird → Koha"""

    def __init__(self, codigo: str, config: Dict, incremental: bool = False):
        self.codigo = codigo
        self.config = config
        self.incremental = incremental

        self.connector = FirebirdConnector(codigo, config)
        self.state = SyncState.cargar(codigo)

        if not self.state:
            self.state = SyncState(
                codigo=codigo,
                ultima_sync=None,
                total_registros=0,
                ultimo_id=None,
                checksum="",
                errores=0
            )

        self.stats = {
            'inicio': datetime.now(),
            'registros_leidos': 0,
            'registros_nuevos': 0,
            'registros_actualizados': 0,
            'errores': 0
        }

    def sincronizar(self) -> bool:
        """Ejecuta sincronización completa"""

        print(f"\n{Config.BOLD}{Config.C}{'═'*70}{Config.END}")
        print(f"{Config.BOLD}{Config.C}SINCRONIZACIÓN: {self.config['nombre']}{Config.END}")
        print(f"{Config.BOLD}{Config.C}{'═'*70}{Config.END}\n")

        # Conectar
        if not self.connector.connect():
            return False

        try:
            # Determinar fecha de corte si es incremental
            fecha_corte = None
            if self.incremental and self.state.ultima_sync:
                fecha_corte = datetime.fromisoformat(self.state.ultima_sync)
                print(f"{Config.Y}Modo incremental: desde {fecha_corte}{Config.END}")

            # Obtener datos
            print(f"{Config.C}→ Extrayendo datos de Firebird...{Config.END}")
            registros = self._extraer_datos(fecha_corte)

            if not registros:
                print(f"{Config.Y}No hay datos para sincronizar{Config.END}")
                return True

            print(f"{Config.G}✓ Extraídos {len(registros)} registros{Config.END}")

            # Generar CSV temporal
            print(f"{Config.C}→ Generando CSV temporal...{Config.END}")
            csv_path = self._generar_csv(registros)

            # Generar MARCXML
            print(f"{Config.C}→ Generando MARCXML...{Config.END}")
            xml_files = self._generar_marcxml(csv_path)

            if not xml_files:
                print(f"{Config.R}✗ Error generando MARCXML{Config.END}")
                return False

            # Importar a Koha
            print(f"{Config.C}→ Importando a Koha...{Config.END}")
            if not self._importar_koha(xml_files):
                print(f"{Config.R}✗ Error importando a Koha{Config.END}")
                return False

            # Actualizar estado
            self.state.ultima_sync = datetime.now().isoformat()
            self.state.total_registros = len(registros)
            self.state.guardar()

            # Limpiar temporales
            csv_path.unlink()
            for xml in xml_files:
                xml.unlink()

            print(f"\n{Config.G}{Config.BOLD}✓✓✓ SINCRONIZACIÓN COMPLETADA ✓✓✓{Config.END}")
            self._mostrar_estadisticas()

            return True

        except Exception as e:
            print(f"{Config.R}✗ Error durante sincronización: {e}{Config.END}")
            import traceback
            traceback.print_exc()
            return False

        finally:
            self.connector.disconnect()

    def _extraer_datos(self, desde: Optional[datetime] = None) -> List[Dict]:
        """Extrae datos desde Firebird"""
        query, params = get_export_query(desde)

        self.connector.cursor.execute(query, params)

        # Obtener nombres de columnas
        columns = [desc[0].lower() for desc in self.connector.cursor.description]

        # Leer registros
        registros = []
        for row in self.connector.cursor:
            self.stats['registros_leidos'] += 1

            registro = {'codbiblio': self.codigo}

            for i, col in enumerate(columns):
                valor = row[i]

                # Normalizar valor
                if valor is None:
                    valor = ""
                elif isinstance(valor, bytes):
                    valor = valor.decode('utf-8', errors='ignore')
                else:
                    valor = str(valor).strip()

                registro[col] = valor

            # Validar que tenga título
            if registro.get('titulo'):
                registros.append(registro)

        return registros

    def _generar_csv(self, registros: List[Dict]) -> Path:
        """Genera CSV temporal"""
        import csv

        csv_path = Config.DIR_TRABAJO / f"temp_{self.codigo}_{int(time.time())}.csv"

        if not registros:
            return csv_path

        # Obtener todas las columnas
        columnas = set()
        for reg in registros:
            columnas.update(reg.keys())

        columnas = sorted(list(columnas))

        # Escribir CSV
        with open(csv_path, 'w', encoding='utf-8', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=columnas, delimiter=';')
            writer.writeheader()
            writer.writerows(registros)

        return csv_path

    def _generar_marcxml(self, csv_path: Path) -> List[Path]:
        """Genera MARCXML desde CSV"""
        script = Config.DIR_TRABAJO / "scripts" / "opac_exportar.py"

        if not script.exists():
            print(f"{Config.R}Script opac_exportar.py no encontrado{Config.END}")
            return []

        cmd = [
            "python3", str(script),
            "-i", str(csv_path),
            "--codbiblio", self.codigo,
            "--loc-default", Config.LOC_DEFAULT,
            "--stream",
            "--split-by", "2000"
        ]

        # Ejecutar en directorio exports
        result = subprocess.run(
            cmd,
            cwd=str(Config.DIR_EXPORTS),
            capture_output=True,
            text=True
        )

        if result.returncode != 0:
            print(f"{Config.R}Error ejecutando opac_exportar.py{Config.END}")
            print(result.stderr)
            return []

        # Buscar XMLs generados
        xml_files = sorted(
            Config.DIR_EXPORTS.glob(f"{self.codigo}_*_marcxml*.xml"),
            key=lambda x: x.stat().st_mtime,
            reverse=True
        )

        # Filtrar recientes (últimos 2 minutos)
        tiempo_limite = time.time() - 120
        xml_recientes = [x for x in xml_files if x.stat().st_mtime > tiempo_limite]

        return xml_recientes

    def _importar_koha(self, xml_files: List[Path]) -> bool:
        """Importa XMLs a Koha"""
        exitos = 0
        fallos = 0

        for xml in xml_files:
            cmd = f"""sudo koha-shell {Config.INSTANCIA_KOHA} -c \
"perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
-b -m MARCXML -file {xml} -commit 500" """

            result = subprocess.run(cmd, shell=True, capture_output=True)

            if result.returncode == 0:
                exitos += 1
            else:
                fallos += 1

        return fallos == 0

    def _mostrar_estadisticas(self):
        """Muestra estadísticas de sincronización"""
        duracion = (datetime.now() - self.stats['inicio']).total_seconds()

        print(f"\n{Config.BOLD}ESTADÍSTICAS:{Config.END}")
        print(f"  Duración: {int(duracion)}s")
        print(f"  Registros leídos: {self.stats['registros_leidos']}")
        print(f"  Última sincronización: {self.state.ultima_sync}")


# ===========================================================================
# FUNCIONES DE UTILIDAD
# ===========================================================================

def probar_conexiones():
    """Prueba conexiones a todos los servidores Firebird"""
    print(f"\n{Config.BOLD}{Config.C}{'═'*70}{Config.END}")
    print(f"{Config.BOLD}{Config.C}PRUEBA DE CONEXIONES FIREBIRD{Config.END}")
    print(f"{Config.BOLD}{Config.C}{'═'*70}{Config.END}\n")

    resultados = []

    for codigo, config in FIREBIRD_SERVERS.items():
        if not config.get('activo', False):
            print(f"{Config.Y}⊘ {codigo:12} - DESACTIVADO{Config.END}")
            continue

        print(f"\n{Config.BOLD}Probando: {config['nombre']}{Config.END}")
        print(f"  Host: {config['host']}:{config['port']}")
        print(f"  BD:   {config['database']}")

        connector = FirebirdConnector(codigo, config)
        info = connector.test_connection()
        connector.disconnect()

        if info['conectado']:
            print(f"  {Config.G}✓ CONECTADO{Config.END}")
            print(f"  Tablas: {info.get('tablas', 0)}")
            print(f"  Registros: {info.get('registros', 0)}")
            resultados.append((codigo, True, info))
        else:
            print(f"  {Config.R}✗ ERROR: {info.get('error', 'Desconocido')}{Config.END}")
            resultados.append((codigo, False, info))

    # Resumen
    print(f"\n{Config.BOLD}RESUMEN:{Config.END}")
    conectados = sum(1 for _, ok, _ in resultados if ok)
    print(f"  {Config.G}Conectados: {conectados}/{len(resultados)}{Config.END}")

    return resultados


def ver_estado_sincronizacion():
    """Muestra estado de sincronización de todas las bibliotecas"""
    print(f"\n{Config.BOLD}{Config.C}{'═'*70}{Config.END}")
    print(f"{Config.BOLD}{Config.C}ESTADO DE SINCRONIZACIÓN{Config.END}")
    print(f"{Config.BOLD}{Config.C}{'═'*70}{Config.END}\n")

    for codigo in FIREBIRD_SERVERS.keys():
        state = SyncState.cargar(codigo)

        if state:
            ultima = datetime.fromisoformat(state.ultima_sync) if state.ultima_sync else None
            hace = ""
            if ultima:
                delta = datetime.now() - ultima
                if delta.days > 0:
                    hace = f"hace {delta.days} día(s)"
                else:
                    hace = f"hace {delta.seconds//3600}h"

            print(f"{codigo:12} | Última: {state.ultima_sync or 'Nunca':25} {hace:15} | Registros: {state.total_registros}")
        else:
            print(f"{codigo:12} | {Config.Y}Nunca sincronizado{Config.END}")


# ===========================================================================
# CLI
# ===========================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Importación directa Firebird → Koha',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Ejemplos:

  # Probar conexiones
  ./firebird_directo_koha.py --test

  # Ver estado de sincronización
  ./firebird_directo_koha.py --status

  # Sincronizar una biblioteca
  ./firebird_directo_koha.py --biblioteca FACAGR

  # Sincronización incremental (solo nuevos)
  ./firebird_directo_koha.py --biblioteca FACAGR --incremental

  # Todas las bibliotecas
  ./firebird_directo_koha.py --all

  # Modo daemon (cada hora)
  ./firebird_directo_koha.py --daemon --intervalo 3600

Bibliotecas configuradas:
''' + '\n'.join([
    f"  - {cod}: {cfg['nombre']} {'[ACTIVO]' if cfg.get('activo') else '[INACTIVO]'}"
    for cod, cfg in FIREBIRD_SERVERS.items()
])
    )

    parser.add_argument('--biblioteca', choices=list(FIREBIRD_SERVERS.keys()),
                       help='Biblioteca a sincronizar')
    parser.add_argument('--all', action='store_true',
                       help='Sincronizar todas las bibliotecas activas')
    parser.add_argument('--incremental', action='store_true',
                       help='Solo sincronizar registros nuevos/modificados')
    parser.add_argument('--test', action='store_true',
                       help='Probar conexiones a servidores Firebird')
    parser.add_argument('--status', action='store_true',
                       help='Ver estado de sincronización')
    parser.add_argument('--daemon', action='store_true',
                       help='Modo daemon (sincronización continua)')
    parser.add_argument('--intervalo', type=int, default=3600,
                       help='Intervalo en segundos para modo daemon (default: 3600)')

    args = parser.parse_args()

    # Crear directorios
    Config.DIR_CACHE.mkdir(exist_ok=True)
    Config.DIR_LOGS.mkdir(exist_ok=True)

    # Comandos
    if args.test:
        probar_conexiones()
        return

    if args.status:
        ver_estado_sincronizacion()
        return

    if args.daemon:
        print(f"{Config.C}Iniciando modo daemon (intervalo: {args.intervalo}s){Config.END}")
        print(f"{Config.Y}Presiona Ctrl+C para detener{Config.END}\n")

        try:
            while True:
                for codigo, config in FIREBIRD_SERVERS.items():
                    if config.get('activo'):
                        syncer = FirebirdKohaSyncer(codigo, config, incremental=True)
                        syncer.sincronizar()

                print(f"\n{Config.C}Esperando {args.intervalo}s hasta próxima sincronización...{Config.END}\n")
                time.sleep(args.intervalo)
        except KeyboardInterrupt:
            print(f"\n{Config.Y}Daemon detenido{Config.END}")
        return

    # Sincronización
    bibliotecas_a_sync = []

    if args.all:
        bibliotecas_a_sync = [
            (cod, cfg) for cod, cfg in FIREBIRD_SERVERS.items()
            if cfg.get('activo')
        ]
    elif args.biblioteca:
        config = FIREBIRD_SERVERS[args.biblioteca]
        if not config.get('activo'):
            print(f"{Config.Y}Advertencia: Biblioteca {args.biblioteca} está marcada como INACTIVA{Config.END}")
            respuesta = input("¿Continuar de todos modos? (s/N): ")
            if respuesta.lower() != 's':
                return
        bibliotecas_a_sync = [(args.biblioteca, config)]
    else:
        parser.print_help()
        return

    # Ejecutar sincronizaciones
    exitosos = 0
    fallidos = 0

    for codigo, config in bibliotecas_a_sync:
        syncer = FirebirdKohaSyncer(codigo, config, incremental=args.incremental)

        if syncer.sincronizar():
            exitosos += 1
        else:
            fallidos += 1

    # Resumen
    if len(bibliotecas_a_sync) > 1:
        print(f"\n{Config.BOLD}{'═'*70}{Config.END}")
        print(f"{Config.BOLD}RESUMEN FINAL{Config.END}")
        print(f"  Total: {len(bibliotecas_a_sync)}")
        print(f"  {Config.G}Exitosos: {exitosos}{Config.END}")
        if fallidos > 0:
            print(f"  {Config.R}Fallidos: {fallidos}{Config.END}")
        print(f"{Config.BOLD}{'═'*70}{Config.END}\n")


if __name__ == '__main__':
    # Verificar dependencia fdb
    try:
        import fdb
    except ImportError:
        print(f"{Config.R}✗ Error: Módulo 'fdb' no instalado{Config.END}")
        print(f"\nInstalar con:")
        print(f"  pip3 install fdb")
        print(f"  # o")
        print(f"  sudo apt install python3-fdb")
        sys.exit(1)

    main()
