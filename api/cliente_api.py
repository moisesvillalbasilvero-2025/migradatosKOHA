#!/usr/bin/env python3
"""
════════════════════════════════════════════════════════════════════════════
CLIENTE API - SISTEMA DE IMPORTACIÓN KOHA
════════════════════════════════════════════════════════════════════════════

Cliente Python simple y didáctico para interactuar con la API de importación.

CARACTERÍSTICAS:
✓ Interfaz simple y clara
✓ Manejo automático de errores
✓ Progress tracking en tiempo real
✓ Ejemplos de uso incluidos
✓ Documentación completa

USO BÁSICO:
    from cliente_api import KohaAPIClient

    # Crear cliente
    client = KohaAPIClient(
        base_url="http://localhost:8000",
        api_key="una-koha-api-key-segura-2025"
    )

    # Importar archivo
    job_id = client.import_file("MED.csv")

    # Ver estado
    status = client.get_job_status(job_id)
    print(f"Estado: {status['status']}")

AUTORES: Universidad Nacional de Asunción
VERSIÓN: 1.0.0
FECHA: 2025-11-07
════════════════════════════════════════════════════════════════════════════
"""

import requests
import time
from pathlib import Path
from typing import Dict, List, Optional
from enum import Enum


class ImportMode(str, Enum):
    """Modos de importación"""
    NORMAL = "normal"
    DRY_RUN = "dry_run"
    VALIDATE_ONLY = "validate_only"


class JobStatus(str, Enum):
    """Estados de trabajo"""
    PENDING = "pending"
    VALIDATING = "validating"
    PROCESSING = "processing"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class KohaAPIClient:
    """
    Cliente para la API de importación Koha.

    Examples:
        >>> client = KohaAPIClient("http://localhost:8000", "your-api-key")
        >>> job_id = client.import_file("MED.csv")
        >>> client.wait_for_completion(job_id)
    """

    def __init__(self, base_url: str, api_key: str, timeout: int = 60):
        """
        Inicializa el cliente.

        Args:
            base_url: URL base de la API (ej: http://localhost:8000)
            api_key: API key para autenticación
            timeout: Timeout en segundos para requests (default: 60)
        """
        self.base_url = base_url.rstrip('/')
        self.api_key = api_key
        self.timeout = timeout
        self.session = requests.Session()
        self.session.headers.update({'X-API-Key': api_key})

    def _get(self, endpoint: str) -> Dict:
        """Realiza GET request"""
        url = f"{self.base_url}{endpoint}"
        response = self.session.get(url, timeout=self.timeout)
        response.raise_for_status()
        return response.json()

    def _post(self, endpoint: str, **kwargs) -> Dict:
        """Realiza POST request"""
        url = f"{self.base_url}{endpoint}"
        response = self.session.post(url, timeout=self.timeout, **kwargs)
        response.raise_for_status()
        return response.json()

    def _delete(self, endpoint: str) -> Dict:
        """Realiza DELETE request"""
        url = f"{self.base_url}{endpoint}"
        response = self.session.delete(url, timeout=self.timeout)
        response.raise_for_status()
        return response.json()

    def health_check(self) -> Dict:
        """
        Verifica si el servidor está saludable.

        Returns:
            Dict con información de salud del servidor

        Example:
            >>> client.health_check()
            {'status': 'healthy', 'timestamp': '2025-11-07T10:30:00', ...}
        """
        return self._get('/api/v1/health')

    def import_file(
        self,
        filepath: str,
        mode: ImportMode = ImportMode.NORMAL,
        webhook_url: Optional[str] = None
    ) -> str:
        """
        Importa un archivo CSV a Koha.

        Args:
            filepath: Ruta al archivo CSV
            mode: Modo de importación (normal, dry_run, validate_only)
            webhook_url: URL opcional para notificación al completar

        Returns:
            job_id: ID del trabajo creado

        Example:
            >>> job_id = client.import_file("MED.csv")
            >>> print(f"Trabajo creado: {job_id}")
        """
        filepath = Path(filepath)

        if not filepath.exists():
            raise FileNotFoundError(f"Archivo no encontrado: {filepath}")

        with open(filepath, 'rb') as f:
            files = {'file': (filepath.name, f, 'text/csv')}
            data = {'mode': mode.value}
            if webhook_url:
                data['webhook_url'] = webhook_url

            response = self._post('/api/v1/import', files=files, data=data)

        return response['job_id']

    def validate_file(self, filepath: str) -> Dict:
        """
        Valida un archivo CSV sin importarlo.

        Args:
            filepath: Ruta al archivo CSV

        Returns:
            Dict con resultado de validación

        Example:
            >>> result = client.validate_file("MED.csv")
            >>> if result['valid']:
            ...     print("✓ Archivo válido")
            >>> else:
            ...     print("✗ Errores:", result['errors'])
        """
        filepath = Path(filepath)

        if not filepath.exists():
            raise FileNotFoundError(f"Archivo no encontrado: {filepath}")

        with open(filepath, 'rb') as f:
            files = {'file': (filepath.name, f, 'text/csv')}
            response = self._post('/api/v1/validate', files=files)

        return response

    def get_job_status(self, job_id: str) -> Dict:
        """
        Obtiene el estado de un trabajo.

        Args:
            job_id: ID del trabajo

        Returns:
            Dict con información del trabajo

        Example:
            >>> status = client.get_job_status(job_id)
            >>> print(f"Estado: {status['status']}")
            >>> print(f"Progreso: {status['progress']}%")
        """
        return self._get(f'/api/v1/jobs/{job_id}')

    def list_jobs(self, limit: int = 50, status: Optional[JobStatus] = None) -> List[Dict]:
        """
        Lista todos los trabajos.

        Args:
            limit: Número máximo de trabajos
            status: Filtrar por estado (opcional)

        Returns:
            Lista de trabajos

        Example:
            >>> jobs = client.list_jobs(limit=10)
            >>> for job in jobs:
            ...     print(f"{job['job_id']}: {job['status']}")
        """
        endpoint = f'/api/v1/jobs?limit={limit}'
        if status:
            endpoint += f'&status={status.value}'

        return self._get(endpoint)

    def cancel_job(self, job_id: str) -> Dict:
        """
        Cancela un trabajo pendiente.

        Args:
            job_id: ID del trabajo

        Returns:
            Dict con confirmación

        Example:
            >>> client.cancel_job(job_id)
            {'message': 'Trabajo cancelado', 'job_id': '...'}
        """
        return self._delete(f'/api/v1/jobs/{job_id}')

    def wait_for_completion(
        self,
        job_id: str,
        poll_interval: int = 2,
        timeout: int = 3600,
        show_progress: bool = True
    ) -> Dict:
        """
        Espera a que un trabajo se complete.

        Args:
            job_id: ID del trabajo
            poll_interval: Intervalo de polling en segundos
            timeout: Timeout máximo en segundos
            show_progress: Si True, muestra progreso en consola

        Returns:
            Dict con resultado final del trabajo

        Raises:
            TimeoutError: Si excede el timeout
            RuntimeError: Si el trabajo falla

        Example:
            >>> job_id = client.import_file("MED.csv")
            >>> result = client.wait_for_completion(job_id)
            >>> print(f"✓ Completado! Items nuevos: {result['result']['items_nuevos']}")
        """
        start_time = time.time()

        while True:
            # Verificar timeout
            if time.time() - start_time > timeout:
                raise TimeoutError(f"Timeout esperando trabajo {job_id}")

            # Obtener estado
            status = self.get_job_status(job_id)

            # Mostrar progreso
            if show_progress:
                estado = status['status']
                progreso = status['progress']
                mensaje = status.get('message', '')
                print(f"\r{estado}: {progreso:.1f}% - {mensaje}          ", end='', flush=True)

            # Verificar si completó
            if status['status'] == JobStatus.COMPLETED:
                if show_progress:
                    print()  # Nueva línea
                return status

            # Verificar si falló
            if status['status'] == JobStatus.FAILED:
                if show_progress:
                    print()  # Nueva línea
                error = status.get('error', 'Error desconocido')
                raise RuntimeError(f"Trabajo falló: {error}")

            # Verificar si fue cancelado
            if status['status'] == JobStatus.CANCELLED:
                if show_progress:
                    print()  # Nueva línea
                raise RuntimeError("Trabajo cancelado")

            # Esperar antes del próximo poll
            time.sleep(poll_interval)


# ════════════════════════════════════════════════════════════════════════════
# EJEMPLOS DE USO
# ════════════════════════════════════════════════════════════════════════════

def ejemplo_basico():
    """Ejemplo básico de uso"""
    print("═" * 70)
    print("EJEMPLO 1: Importación Básica")
    print("═" * 70)

    # Crear cliente
    client = KohaAPIClient(
        base_url="http://localhost:8000",
        api_key="una-koha-api-key-segura-2025"
    )

    # Verificar salud del servidor
    print("\n1. Verificando servidor...")
    health = client.health_check()
    print(f"   ✓ Servidor saludable: {health['status']}")

    # Importar archivo
    print("\n2. Importando archivo...")
    job_id = client.import_file("MED.csv")
    print(f"   ✓ Trabajo creado: {job_id}")

    # Esperar a que complete
    print("\n3. Esperando completación...")
    resultado = client.wait_for_completion(job_id)

    # Mostrar resultados
    print("\n4. Resultados:")
    print(f"   ✓ Estado: {resultado['status']}")
    if resultado.get('result'):
        print(f"   ✓ Items nuevos: {resultado['result']['items_nuevos']}")
        print(f"   ✓ Tiempo: {resultado['result']['tiempo_total']:.1f}s")


def ejemplo_dry_run():
    """Ejemplo de simulación (dry-run)"""
    print("\n" + "═" * 70)
    print("EJEMPLO 2: Simulación (Dry-Run)")
    print("═" * 70)

    client = KohaAPIClient(
        base_url="http://localhost:8000",
        api_key="una-koha-api-key-segura-2025"
    )

    # Simular importación
    print("\n1. Simulando importación (no modifica BD)...")
    job_id = client.import_file("MED.csv", mode=ImportMode.DRY_RUN)

    print("\n2. Esperando...")
    resultado = client.wait_for_completion(job_id)

    print("\n3. Resultado de simulación:")
    print(f"   ✓ {resultado['message']}")


def ejemplo_validacion():
    """Ejemplo de validación"""
    print("\n" + "═" * 70)
    print("EJEMPLO 3: Validación de Archivo")
    print("═" * 70)

    client = KohaAPIClient(
        base_url="http://localhost:8000",
        api_key="una-koha-api-key-segura-2025"
    )

    # Validar archivo
    print("\n1. Validando archivo...")
    resultado = client.validate_file("MED.csv")

    print("\n2. Resultado:")
    if resultado['valid']:
        print(f"   ✓ Archivo válido")
        print(f"   ✓ Código: {resultado.get('codigo_biblioteca')}")
        print(f"   ✓ Registros: {resultado.get('record_count')}")
        print(f"   ✓ Calidad: {resultado.get('quality_score')}/100")
    else:
        print(f"   ✗ Archivo inválido")
        for error in resultado['errors']:
            print(f"     - {error}")


def ejemplo_listar_trabajos():
    """Ejemplo de listar trabajos"""
    print("\n" + "═" * 70)
    print("EJEMPLO 4: Listar Trabajos")
    print("═" * 70)

    client = KohaAPIClient(
        base_url="http://localhost:8000",
        api_key="una-koha-api-key-segura-2025"
    )

    # Listar trabajos
    print("\n1. Listando últimos 10 trabajos...")
    jobs = client.list_jobs(limit=10)

    print(f"\n2. Total: {len(jobs)} trabajos\n")
    for job in jobs:
        print(f"   {job['job_id'][:8]}... | {job['status']:12} | {job['filename']}")


# ════════════════════════════════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════════════════════════════════

if __name__ == '__main__':
    import sys

    if len(sys.argv) < 2:
        print("""
Uso: python3 cliente_api.py <comando> [archivo]

Comandos:
    ejemplo1          - Ejemplo básico de importación
    ejemplo2          - Ejemplo de simulación (dry-run)
    ejemplo3          - Ejemplo de validación
    ejemplo4          - Ejemplo de listar trabajos

    import <archivo>  - Importar un archivo
    validate <archivo> - Validar un archivo
    list              - Listar trabajos
    status <job_id>   - Ver estado de trabajo
    cancel <job_id>   - Cancelar trabajo
    health            - Health check del servidor

Ejemplos:
    python3 cliente_api.py ejemplo1
    python3 cliente_api.py import MED.csv
    python3 cliente_api.py validate MED.csv
    python3 cliente_api.py list
        """)
        sys.exit(0)

    comando = sys.argv[1]

    # Crear cliente
    client = KohaAPIClient(
        base_url="http://localhost:8000",
        api_key="una-koha-api-key-segura-2025"
    )

    try:
        if comando == "ejemplo1":
            ejemplo_basico()
        elif comando == "ejemplo2":
            ejemplo_dry_run()
        elif comando == "ejemplo3":
            ejemplo_validacion()
        elif comando == "ejemplo4":
            ejemplo_listar_trabajos()
        elif comando == "health":
            health = client.health_check()
            print(f"✓ Servidor: {health['status']}")
            print(f"  Trabajos activos: {health['active_jobs']}")
            print(f"  Total trabajos: {health['total_jobs']}")
        elif comando == "import" and len(sys.argv) > 2:
            archivo = sys.argv[2]
            job_id = client.import_file(archivo)
            print(f"✓ Trabajo creado: {job_id}")
            resultado = client.wait_for_completion(job_id)
            print(f"\n✓ Completado!")
        elif comando == "validate" and len(sys.argv) > 2:
            archivo = sys.argv[2]
            resultado = client.validate_file(archivo)
            if resultado['valid']:
                print("✓ Archivo válido")
            else:
                print("✗ Archivo inválido")
                for error in resultado['errors']:
                    print(f"  - {error}")
        elif comando == "list":
            jobs = client.list_jobs(limit=20)
            print(f"Total: {len(jobs)} trabajos\n")
            for job in jobs:
                print(f"{job['job_id'][:12]}... | {job['status']:12} | {job['filename']}")
        elif comando == "status" and len(sys.argv) > 2:
            job_id = sys.argv[2]
            status = client.get_job_status(job_id)
            print(f"Estado: {status['status']}")
            print(f"Progreso: {status['progress']}%")
            print(f"Mensaje: {status.get('message', '')}")
        elif comando == "cancel" and len(sys.argv) > 2:
            job_id = sys.argv[2]
            result = client.cancel_job(job_id)
            print(f"✓ {result['message']}")
        else:
            print("Comando inválido. Usa -h para ver ayuda.")

    except Exception as e:
        print(f"✗ Error: {e}")
        sys.exit(1)
