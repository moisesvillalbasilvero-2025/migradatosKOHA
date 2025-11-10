#!/usr/bin/env python3
"""
DASHBOARD WEB SIMPLE - MONITOR DE IMPORTACIONES KOHA
=====================================================
Dashboard web minimalista para monitorear importaciones en tiempo real

CARACTERÍSTICAS:
- Estado del sistema en tiempo real
- Logs recientes
- Estadísticas de bibliotecas
- Historial de importaciones
- API REST simple

USO:
    ./dashboard.py                    # Iniciar en puerto 5000
    ./dashboard.py --port 8888        # Puerto personalizado
    ./dashboard.py --host 0.0.0.0     # Acceso desde red

ACCESO:
    http://localhost:5000

AUTOR: Universidad Nacional de Asunción
VERSIÓN: 1.0
FECHA: 2025-10-31
"""

import os
import sys
import json
import subprocess
import time
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Any
from http.server import HTTPServer, BaseHTTPRequestHandler
import urllib.parse
import argparse

# Importar gestor de configuración centralizado
try:
    from config_manager import get_config
    config = get_config()
except ImportError:
    print("⚠ Error: No se pudo importar config_manager.py")
    print("  Asegúrate de que config_manager.py esté en el mismo directorio")
    print("  Dashboard funcionará con configuración por defecto limitada")
    # Configuración mínima de fallback
    from pathlib import Path
    class _FallbackConfig:
        DIR_TRABAJO = Path.cwd()
        DIR_LOGS = DIR_TRABAJO / "logs"
        DIR_REPORTES = DIR_TRABAJO / "reportes"
        INSTANCIA_KOHA = "koha-cnc"
    config = _FallbackConfig()


# ==================== CONFIGURACIÓN ====================
# NOTA: La configuración ahora se carga desde config_manager.py
# Wrapper de compatibilidad
Config = config


# ==================== RECOLECTOR DE DATOS ====================
class DatosKoha:
    """Recolecta datos del sistema Koha"""

    @staticmethod
    def obtener_estadisticas_bibliotecas() -> List[Dict]:
        """Obtiene estadísticas de items por biblioteca"""
        try:
            cmd = f"""sudo koha-mysql {Config.INSTANCIA_KOHA} -e "
SELECT
    b.branchcode,
    b.branchname,
    COUNT(DISTINCT i.biblionumber) as titulos,
    COUNT(i.itemnumber) as ejemplares
FROM branches b
LEFT JOIN items i ON b.branchcode = i.homebranch
GROUP BY b.branchcode, b.branchname
HAVING COUNT(i.itemnumber) > 0
ORDER BY COUNT(i.itemnumber) DESC
LIMIT 20
" --skip-column-names --batch """

            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)

            if result.returncode == 0:
                bibliotecas = []
                for linea in result.stdout.strip().split('\n'):
                    if linea:
                        partes = linea.split('\t')
                        if len(partes) >= 4:
                            bibliotecas.append({
                                'codigo': partes[0],
                                'nombre': partes[1],
                                'titulos': int(partes[2]),
                                'ejemplares': int(partes[3])
                            })
                return bibliotecas
        except Exception as e:
            print(f"Error obteniendo estadísticas: {e}")

        return []

    @staticmethod
    def obtener_total_sistema() -> Dict:
        """Obtiene totales del sistema"""
        try:
            cmd = f"""sudo koha-mysql {Config.INSTANCIA_KOHA} -N -e "
SELECT
    (SELECT COUNT(*) FROM biblio) as biblios,
    (SELECT COUNT(*) FROM items) as items,
    (SELECT COUNT(*) FROM branches) as bibliotecas
" """
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)

            if result.returncode == 0:
                partes = result.stdout.strip().split('\t')
                if len(partes) >= 3:
                    return {
                        'biblios': int(partes[0]),
                        'items': int(partes[1]),
                        'bibliotecas': int(partes[2])
                    }
        except Exception as e:
            print(f"Error obteniendo totales: {e}")

        return {'biblios': 0, 'items': 0, 'bibliotecas': 0}

    @staticmethod
    def obtener_logs_recientes(limit: int = 20) -> List[Dict]:
        """Obtiene logs recientes de importación"""
        logs = []

        try:
            archivos_log = sorted(
                Config.DIR_LOGS.glob("maestro_*.log"),
                key=lambda x: x.stat().st_mtime,
                reverse=True
            )[:limit]

            for log_file in archivos_log:
                try:
                    stat = log_file.stat()
                    logs.append({
                        'archivo': log_file.name,
                        'fecha': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S'),
                        'tamano': stat.st_size,
                        'ruta': str(log_file)
                    })
                except:
                    pass
        except Exception as e:
            print(f"Error obteniendo logs: {e}")

        return logs

    @staticmethod
    def obtener_ultimas_importaciones(limit: int = 10) -> List[Dict]:
        """Obtiene últimas importaciones desde reportes"""
        importaciones = []

        try:
            archivos_reporte = sorted(
                Config.DIR_REPORTES.glob("reporte_*.txt"),
                key=lambda x: x.stat().st_mtime,
                reverse=True
            )[:limit]

            for reporte in archivos_reporte:
                try:
                    stat = reporte.stat()
                    nombre = reporte.stem

                    # Extraer código de biblioteca del nombre
                    partes = nombre.split('_')
                    codigo = partes[1] if len(partes) > 1 else 'N/A'

                    importaciones.append({
                        'codigo': codigo,
                        'fecha': datetime.fromtimestamp(stat.st_mtime).strftime('%Y-%m-%d %H:%M:%S'),
                        'archivo': reporte.name
                    })
                except:
                    pass
        except Exception as e:
            print(f"Error obteniendo importaciones: {e}")

        return importaciones

    @staticmethod
    def obtener_estado_sistema() -> Dict:
        """Obtiene estado general del sistema"""
        try:
            # Espacio en disco
            df_output = subprocess.run(
                f"df -h {Config.DIR_TRABAJO}",
                shell=True, capture_output=True, text=True
            )

            espacio_libre = "N/A"
            if df_output.returncode == 0:
                lineas = df_output.stdout.strip().split('\n')
                if len(lineas) > 1:
                    campos = lineas[1].split()
                    if len(campos) >= 4:
                        espacio_libre = campos[3]

            # Procesos activos
            procesos = subprocess.run(
                "ps aux | grep -c bulkmarcimport | grep -v grep || echo 0",
                shell=True, capture_output=True, text=True
            )

            num_procesos = 0
            try:
                num_procesos = int(procesos.stdout.strip())
            except:
                pass

            return {
                'espacio_libre': espacio_libre,
                'procesos_activos': num_procesos,
                'hora_servidor': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
                'koha_activo': True  # Simplificado
            }
        except Exception as e:
            print(f"Error obteniendo estado: {e}")
            return {}


# ==================== SERVIDOR HTTP ====================
class DashboardHandler(BaseHTTPRequestHandler):
    """Manejador de peticiones HTTP"""

    def do_GET(self):
        """Maneja peticiones GET"""

        path = urllib.parse.urlparse(self.path).path

        # Rutas API
        if path == '/api/stats':
            self.api_estadisticas()
        elif path == '/api/logs':
            self.api_logs()
        elif path == '/api/importaciones':
            self.api_importaciones()
        elif path == '/api/estado':
            self.api_estado()
        elif path == '/':
            self.servir_dashboard()
        else:
            self.send_error(404)

    def api_estadisticas(self):
        """API: Estadísticas de bibliotecas"""
        datos = {
            'bibliotecas': DatosKoha.obtener_estadisticas_bibliotecas(),
            'totales': DatosKoha.obtener_total_sistema()
        }

        self.enviar_json(datos)

    def api_logs(self):
        """API: Logs recientes"""
        datos = {
            'logs': DatosKoha.obtener_logs_recientes()
        }

        self.enviar_json(datos)

    def api_importaciones(self):
        """API: Últimas importaciones"""
        datos = {
            'importaciones': DatosKoha.obtener_ultimas_importaciones()
        }

        self.enviar_json(datos)

    def api_estado(self):
        """API: Estado del sistema"""
        datos = DatosKoha.obtener_estado_sistema()
        self.enviar_json(datos)

    def enviar_json(self, datos: Dict):
        """Envía respuesta JSON"""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()

        json_data = json.dumps(datos, ensure_ascii=False, indent=2)
        self.wfile.write(json_data.encode('utf-8'))

    def servir_dashboard(self):
        """Sirve el dashboard HTML"""
        html = self.generar_html()

        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.end_headers()
        self.wfile.write(html.encode('utf-8'))

    def generar_html(self) -> str:
        """Genera HTML del dashboard"""
        return """<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - Importaciones Koha</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        .header {
            background: white;
            padding: 30px;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .header h1 {
            color: #667eea;
            font-size: 32px;
            margin-bottom: 10px;
        }
        .header p {
            color: #666;
            font-size: 14px;
        }
        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 20px;
        }
        .stat-card {
            background: white;
            padding: 25px;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
        }
        .stat-card h3 {
            color: #666;
            font-size: 14px;
            font-weight: 600;
            text-transform: uppercase;
            margin-bottom: 10px;
        }
        .stat-card .value {
            font-size: 36px;
            font-weight: bold;
            color: #667eea;
        }
        .section {
            background: white;
            padding: 25px;
            border-radius: 12px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            margin-bottom: 20px;
        }
        .section h2 {
            color: #667eea;
            margin-bottom: 20px;
            font-size: 24px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
        }
        th {
            background: #f7fafc;
            padding: 12px;
            text-align: left;
            font-weight: 600;
            color: #4a5568;
            border-bottom: 2px solid #e2e8f0;
        }
        td {
            padding: 12px;
            border-bottom: 1px solid #e2e8f0;
        }
        tr:hover {
            background: #f7fafc;
        }
        .badge {
            display: inline-block;
            padding: 4px 12px;
            border-radius: 12px;
            font-size: 12px;
            font-weight: 600;
        }
        .badge-success {
            background: #c6f6d5;
            color: #22543d;
        }
        .badge-info {
            background: #bee3f8;
            color: #2c5282;
        }
        .loading {
            text-align: center;
            padding: 40px;
            color: #667eea;
        }
        .timestamp {
            text-align: center;
            color: #666;
            font-size: 12px;
            margin-top: 20px;
        }
        .progress-bar {
            height: 8px;
            background: #e2e8f0;
            border-radius: 4px;
            overflow: hidden;
            margin-top: 8px;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #667eea, #764ba2);
            transition: width 0.3s ease;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Dashboard de Importaciones Koha</h1>
            <p>Universidad Nacional de Asunción - Monitoreo en tiempo real</p>
        </div>

        <div class="stats-grid">
            <div class="stat-card">
                <h3>Total Biblios</h3>
                <div class="value" id="total-biblios">-</div>
            </div>
            <div class="stat-card">
                <h3>Total Items</h3>
                <div class="value" id="total-items">-</div>
            </div>
            <div class="stat-card">
                <h3>Bibliotecas</h3>
                <div class="value" id="total-bibliotecas">-</div>
            </div>
            <div class="stat-card">
                <h3>Espacio Libre</h3>
                <div class="value" id="espacio-libre" style="font-size: 28px;">-</div>
            </div>
        </div>

        <div class="section">
            <h2>📚 Bibliotecas con más Items</h2>
            <table id="tabla-bibliotecas">
                <thead>
                    <tr>
                        <th>Código</th>
                        <th>Nombre</th>
                        <th>Títulos</th>
                        <th>Ejemplares</th>
                        <th>Distribución</th>
                    </tr>
                </thead>
                <tbody>
                    <tr><td colspan="5" class="loading">Cargando datos...</td></tr>
                </tbody>
            </table>
        </div>

        <div class="section">
            <h2>📥 Últimas Importaciones</h2>
            <table id="tabla-importaciones">
                <thead>
                    <tr>
                        <th>Biblioteca</th>
                        <th>Fecha</th>
                        <th>Estado</th>
                    </tr>
                </thead>
                <tbody>
                    <tr><td colspan="3" class="loading">Cargando datos...</td></tr>
                </tbody>
            </table>
        </div>

        <div class="timestamp" id="ultima-actualizacion">
            Actualizado: -
        </div>
    </div>

    <script>
        async function cargarDatos() {
            try {
                // Estadísticas
                const respStats = await fetch('/api/stats');
                const stats = await respStats.json();

                document.getElementById('total-biblios').textContent =
                    stats.totales.biblios.toLocaleString();
                document.getElementById('total-items').textContent =
                    stats.totales.items.toLocaleString();
                document.getElementById('total-bibliotecas').textContent =
                    stats.totales.bibliotecas;

                // Estado del sistema
                const respEstado = await fetch('/api/estado');
                const estado = await respEstado.json();

                document.getElementById('espacio-libre').textContent =
                    estado.espacio_libre || 'N/A';

                // Tabla de bibliotecas
                const tbody = document.querySelector('#tabla-bibliotecas tbody');
                tbody.innerHTML = '';

                const maxEjemplares = Math.max(...stats.bibliotecas.map(b => b.ejemplares));

                stats.bibliotecas.forEach(bib => {
                    const porcentaje = (bib.ejemplares / maxEjemplares) * 100;

                    const tr = document.createElement('tr');
                    tr.innerHTML = `
                        <td><strong>${bib.codigo}</strong></td>
                        <td>${bib.nombre}</td>
                        <td>${bib.titulos.toLocaleString()}</td>
                        <td>${bib.ejemplares.toLocaleString()}</td>
                        <td>
                            <div class="progress-bar">
                                <div class="progress-fill" style="width: ${porcentaje}%"></div>
                            </div>
                        </td>
                    `;
                    tbody.appendChild(tr);
                });

                // Importaciones recientes
                const respImp = await fetch('/api/importaciones');
                const importaciones = await respImp.json();

                const tbodyImp = document.querySelector('#tabla-importaciones tbody');
                tbodyImp.innerHTML = '';

                if (importaciones.importaciones.length === 0) {
                    tbodyImp.innerHTML = '<tr><td colspan="3">No hay importaciones recientes</td></tr>';
                } else {
                    importaciones.importaciones.forEach(imp => {
                        const tr = document.createElement('tr');
                        tr.innerHTML = `
                            <td><span class="badge badge-info">${imp.codigo}</span></td>
                            <td>${imp.fecha}</td>
                            <td><span class="badge badge-success">✓ Exitoso</span></td>
                        `;
                        tbodyImp.appendChild(tr);
                    });
                }

                // Actualizar timestamp
                document.getElementById('ultima-actualizacion').textContent =
                    'Actualizado: ' + new Date().toLocaleString('es-ES');

            } catch (error) {
                console.error('Error cargando datos:', error);
            }
        }

        // Cargar datos al inicio
        cargarDatos();

        // Actualizar cada 30 segundos
        setInterval(cargarDatos, 30000);
    </script>
</body>
</html>
"""

    def log_message(self, format, *args):
        """Suprimir logs de acceso detallados"""
        pass


# ==================== MAIN ====================
def main():
    parser = argparse.ArgumentParser(
        description="Dashboard web para monitoreo de importaciones Koha"
    )

    parser.add_argument('--host', default='0.0.0.0',
                       help='Host (default: 0.0.0.0)')
    parser.add_argument('--port', type=int, default=5000,
                       help='Puerto (default: 5000)')

    args = parser.parse_args()

    server_address = (args.host, args.port)
    httpd = HTTPServer(server_address, DashboardHandler)

    print(f"""
╔════════════════════════════════════════════════════════════════════╗
║          DASHBOARD DE IMPORTACIONES KOHA - INICIADO                ║
╚════════════════════════════════════════════════════════════════════╝

📊 Dashboard disponible en:

    http://{args.host}:{args.port}
    http://localhost:{args.port}

🔄 Actualizaciones automáticas cada 30 segundos

API REST disponible:
    /api/stats           - Estadísticas de bibliotecas
    /api/logs            - Logs recientes
    /api/importaciones   - Últimas importaciones
    /api/estado          - Estado del sistema

Presiona Ctrl+C para detener el servidor
════════════════════════════════════════════════════════════════════
""")

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n\n👋 Deteniendo servidor...")
        httpd.server_close()
        print("Servidor detenido correctamente\n")


if __name__ == '__main__':
    main()
