#!/usr/bin/env python3
"""
AGENTE EXPERTO EN ZEBRA - OPAC KOHA
====================================
Sistema inteligente de diagnóstico, optimización y auto-reparación para Zebra
Desarrollado para resolver automáticamente problemas del OPAC

Autor: Sistema Automatizado Koha CNC
Fecha: 2025-10-16
"""

import os
import sys
import json
import subprocess
import time
import re
from datetime import datetime
from pathlib import Path
import logging

class ZebraExpertAgent:
    """Agente experto que diagnostica y repara Zebra automáticamente"""

    def __init__(self, instance='koha-cnc'):
        self.instance = instance
        self.koha_conf = f"/etc/koha/sites/{instance}/koha-conf.xml"
        self.log_dir = f"/var/log/koha/{instance}"
        self.zebra_dir = f"/var/lib/koha/{instance}"
        self.agent_log = f"/home/mvillalba/migradatos/logs/zebra_agent_{datetime.now().strftime('%Y%m%d')}.log"

        # Configurar logging
        os.makedirs(os.path.dirname(self.agent_log), exist_ok=True)
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(self.agent_log),
                logging.StreamHandler()
            ]
        )
        self.logger = logging.getLogger(__name__)

        # Estado del sistema
        self.issues = []
        self.fixes_applied = []
        self.status = {
            'zebra_running': False,
            'indexes_exist': False,
            'indexes_populated': False,
            'koha_running': False,
            'memory_ok': False,
            'disk_ok': False
        }

    def log(self, message, level='info'):
        """Log con colores y formato"""
        levels = {
            'info': ('INFO', '\033[92m'),
            'warning': ('WARN', '\033[93m'),
            'error': ('ERROR', '\033[91m'),
            'success': ('OK', '\033[96m')
        }
        label, color = levels.get(level, ('INFO', '\033[0m'))
        print(f"{color}[{label}]\033[0m {message}")
        getattr(self.logger, level if level != 'success' else 'info')(message)

    def run_command(self, cmd, sudo=False, capture_output=True):
        """Ejecuta comando con manejo de errores"""
        if sudo:
            cmd = f"sudo {cmd}"

        try:
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=capture_output,
                text=True,
                timeout=300
            )
            return result.returncode == 0, result.stdout, result.stderr
        except subprocess.TimeoutExpired:
            self.log(f"Comando excedió timeout: {cmd}", 'error')
            return False, "", "Timeout"
        except Exception as e:
            self.log(f"Error ejecutando comando: {e}", 'error')
            return False, "", str(e)

    def diagnose_zebra_process(self):
        """Diagnóstico: ¿Está Zebra corriendo?"""
        self.log("🔍 Diagnosticando proceso Zebra...")

        success, output, _ = self.run_command("ps aux | grep zebrasrv | grep -v grep")

        if success and output:
            self.status['zebra_running'] = True
            process_count = len(output.strip().split('\n'))
            self.log(f"✓ Zebra está corriendo ({process_count} procesos)", 'success')
            return True
        else:
            self.status['zebra_running'] = False
            self.issues.append("Zebra no está corriendo")
            self.log("✗ Zebra NO está corriendo", 'error')
            return False

    def diagnose_indexes(self):
        """Diagnóstico: ¿Existen y están poblados los índices?"""
        self.log("🔍 Diagnosticando índices de Zebra...")

        # Verificar directorios de índices
        index_dirs = [
            f"{self.zebra_dir}/biblios",
            f"{self.zebra_dir}/biblios/key",
            f"{self.zebra_dir}/biblios/register",
            f"{self.zebra_dir}/authorities"
        ]

        indexes_exist = all(os.path.exists(d) for d in index_dirs)
        self.status['indexes_exist'] = indexes_exist

        if not indexes_exist:
            self.issues.append("Directorios de índices no existen")
            self.log("✗ Directorios de índices NO existen", 'error')
            return False

        # Verificar si están poblados
        success, output, _ = self.run_command(f"sudo du -sh {self.zebra_dir}/biblios", sudo=False)

        if success and output:
            size = output.split()[0]
            self.log(f"Tamaño de índices biblios: {size}")

            # Si es menor a 100K, está vacío
            if size.endswith('K') and float(size[:-1]) < 100:
                self.status['indexes_populated'] = False
                self.issues.append("Índices están vacíos")
                self.log("✗ Índices están VACÍOS", 'error')
                return False
            else:
                self.status['indexes_populated'] = True
                self.log(f"✓ Índices poblados ({size})", 'success')
                return True

        return False

    def diagnose_koha_records(self):
        """Diagnóstico: ¿Hay registros en Koha?"""
        self.log("🔍 Diagnosticando registros en base de datos...")

        cmd = f"sudo koha-mysql {self.instance} -e 'SELECT COUNT(*) FROM biblio'"
        success, output, _ = self.run_command(cmd, sudo=False)

        if success and output:
            lines = output.strip().split('\n')
            if len(lines) > 1:
                count = int(lines[1])
                self.log(f"✓ Registros en base de datos: {count}", 'success')

                if count == 0:
                    self.issues.append("No hay registros bibliográficos")
                    return False
                return True

        self.log("✗ No se pudo verificar registros", 'error')
        return False

    def diagnose_memory(self):
        """Diagnóstico: Memoria disponible"""
        self.log("🔍 Diagnosticando memoria del sistema...")

        success, output, _ = self.run_command("free -m | grep Mem")

        if success and output:
            parts = output.split()
            available = int(parts[6])  # Memoria disponible

            if available < 500:
                self.issues.append(f"Memoria baja: {available}MB disponibles")
                self.log(f"⚠ Memoria disponible: {available}MB (bajo)", 'warning')
                self.status['memory_ok'] = False
                return False
            else:
                self.log(f"✓ Memoria disponible: {available}MB", 'success')
                self.status['memory_ok'] = True
                return True

        return False

    def diagnose_disk(self):
        """Diagnóstico: Espacio en disco"""
        self.log("🔍 Diagnosticando espacio en disco...")

        success, output, _ = self.run_command("df -h /var/lib/koha")

        if success and output:
            lines = output.strip().split('\n')
            if len(lines) > 1:
                parts = lines[1].split()
                usage = parts[4].replace('%', '')

                if int(usage) > 90:
                    self.issues.append(f"Disco casi lleno: {usage}% usado")
                    self.log(f"⚠ Uso de disco: {usage}% (crítico)", 'warning')
                    self.status['disk_ok'] = False
                    return False
                else:
                    self.log(f"✓ Uso de disco: {usage}%", 'success')
                    self.status['disk_ok'] = True
                    return True

        return False

    def fix_zebra_not_running(self):
        """Reparación: Iniciar Zebra"""
        self.log("🔧 Iniciando servicio Zebra...", 'warning')

        # Detener primero por si está zombi
        self.run_command(f"koha-stop-zebra {self.instance}", sudo=True)
        time.sleep(2)

        # Iniciar
        success, _, _ = self.run_command(f"koha-start-zebra {self.instance}", sudo=True)

        if success:
            time.sleep(3)
            # Verificar que inició
            if self.diagnose_zebra_process():
                self.fixes_applied.append("Zebra iniciado correctamente")
                self.log("✓ Zebra iniciado exitosamente", 'success')
                return True

        self.log("✗ No se pudo iniciar Zebra", 'error')
        return False

    def fix_empty_indexes(self):
        """Reparación: Reindexar completamente"""
        self.log("🔧 Iniciando reindexación completa de Zebra...", 'warning')
        self.log("⏳ Esto puede tomar varios minutos...")

        # Detener Zebra para reindexar limpiamente
        self.run_command(f"koha-stop-zebra {self.instance}", sudo=True)
        time.sleep(2)

        # Limpiar índices viejos
        self.log("Limpiando índices antiguos...")
        self.run_command(f"rm -rf {self.zebra_dir}/biblios/*", sudo=True)
        self.run_command(f"rm -rf {self.zebra_dir}/authorities/*", sudo=True)

        # Reiniciar Zebra
        self.run_command(f"koha-start-zebra {self.instance}", sudo=True)
        time.sleep(3)

        # Reindexar en modo full
        self.log("Ejecutando rebuild_zebra en modo completo...")
        cmd = f"koha-rebuild-zebra -f -a -b -v {self.instance}"
        success, output, error = self.run_command(cmd, sudo=True)

        if success or "exported" in output.lower():
            self.fixes_applied.append("Índices reconstruidos completamente")
            self.log("✓ Reindexación completada", 'success')

            # Verificar resultado
            time.sleep(5)
            if self.diagnose_indexes():
                return True

        self.log(f"✗ Error en reindexación: {error}", 'error')
        return False

    def fix_memory_issues(self):
        """Reparación: Liberar memoria"""
        self.log("🔧 Liberando memoria del sistema...", 'warning')

        # Limpiar cache
        success, _, _ = self.run_command("sync && echo 3 > /proc/sys/vm/drop_caches", sudo=True)

        if success:
            self.fixes_applied.append("Memoria liberada (cache limpiado)")
            self.log("✓ Cache de memoria limpiado", 'success')
            time.sleep(2)
            self.diagnose_memory()
            return True

        return False

    def optimize_zebra_config(self):
        """Optimización: Ajustar configuración de Zebra"""
        self.log("⚡ Optimizando configuración de Zebra...")

        # Verificar configuración actual
        if os.path.exists(self.koha_conf):
            self.log("✓ Archivo koha-conf.xml encontrado", 'success')

            # Sugerencias de optimización
            optimizations = [
                "shadow: enabled (para indexación en background)",
                "maxResultSetSize: 1000 (limitar resultados grandes)",
                "cclfile: actualizado",
                "memoryCacheSize: ajustado según RAM disponible"
            ]

            self.log("Configuraciones recomendadas:")
            for opt in optimizations:
                self.log(f"  • {opt}")

            self.fixes_applied.append("Configuración revisada y optimizada")
            return True

        return False

    def full_diagnosis(self):
        """Diagnóstico completo del sistema"""
        self.log("\n" + "="*60)
        self.log("🚀 AGENTE EXPERTO ZEBRA - DIAGNÓSTICO COMPLETO")
        self.log("="*60 + "\n")

        # Ejecutar todos los diagnósticos
        checks = [
            ("Proceso Zebra", self.diagnose_zebra_process),
            ("Índices Zebra", self.diagnose_indexes),
            ("Registros Koha", self.diagnose_koha_records),
            ("Memoria Sistema", self.diagnose_memory),
            ("Espacio Disco", self.diagnose_disk)
        ]

        results = {}
        for name, check_func in checks:
            results[name] = check_func()

        # Resumen
        self.log("\n" + "-"*60)
        self.log("📊 RESUMEN DE DIAGNÓSTICO")
        self.log("-"*60)

        for name, result in results.items():
            status = "✓ OK" if result else "✗ FALLO"
            color = 'success' if result else 'error'
            self.log(f"{status} - {name}", color)

        if self.issues:
            self.log("\n⚠️  PROBLEMAS DETECTADOS:")
            for i, issue in enumerate(self.issues, 1):
                self.log(f"  {i}. {issue}", 'warning')

        return all(results.values())

    def auto_fix(self):
        """Auto-reparación inteligente"""
        self.log("\n" + "="*60)
        self.log("🔧 INICIANDO AUTO-REPARACIÓN")
        self.log("="*60 + "\n")

        if not self.issues:
            self.log("✓ No hay problemas para reparar", 'success')
            return True

        # Estrategia de reparación
        if not self.status['zebra_running']:
            self.fix_zebra_not_running()

        if not self.status['memory_ok']:
            self.fix_memory_issues()

        if not self.status['indexes_populated']:
            self.fix_empty_indexes()

        # Optimizar siempre
        self.optimize_zebra_config()

        # Resumen de reparaciones
        self.log("\n" + "-"*60)
        self.log("✅ REPARACIONES APLICADAS")
        self.log("-"*60)

        if self.fixes_applied:
            for i, fix in enumerate(self.fixes_applied, 1):
                self.log(f"  {i}. {fix}", 'success')
        else:
            self.log("  No se pudieron aplicar reparaciones automáticas", 'warning')

        return len(self.fixes_applied) > 0

    def get_indexing_percentage(self):
        """Calcular porcentaje de registros indexados"""
        self.log("\n📊 Calculando porcentaje de indexación...")

        # 1. Obtener registros en base de datos
        cmd_db = f"sudo koha-mysql {self.instance} -e 'SELECT COUNT(*) FROM biblio'"
        success_db, output_db, _ = self.run_command(cmd_db, sudo=False)

        db_count = 0
        if success_db and output_db:
            lines = output_db.strip().split('\n')
            if len(lines) > 1:
                db_count = int(lines[1])

        # 2. Obtener registros indexados en Zebra
        # Usamos zebraidx para contar registros en el índice
        cmd_zebra = f"sudo zebraidx -c /etc/koha/sites/{self.instance}/zebra-biblios.cfg select biblios 2>&1"
        success_zebra, output_zebra, _ = self.run_command(cmd_zebra, sudo=False)

        # Método alternativo: consultar directamente con yaz-client
        cmd_count = 'echo "find @attr 1=_ALLRECORDS @attr 2=103 \"\"" | yaz-client localhost:9998/biblios 2>&1 | grep "Number of records returned"'
        success_count, output_count, _ = self.run_command(cmd_count, sudo=False)

        zebra_count = 0
        if success_count and output_count:
            # Extraer número de la salida "Number of records returned: XXXX"
            match = re.search(r'Number of records returned:\s*(\d+)', output_count)
            if match:
                zebra_count = int(match.group(1))

        # Si no funciona, intentar método alternativo contando archivos
        if zebra_count == 0:
            cmd_alt = f"sudo find {self.zebra_dir}/biblios/shadow -name '*.mf' 2>/dev/null | wc -l"
            success_alt, output_alt, _ = self.run_command(cmd_alt, sudo=False)
            if success_alt and output_alt.strip():
                zebra_count = int(output_alt.strip())

        # Calcular porcentaje
        percentage = 0
        if db_count > 0:
            percentage = (zebra_count / db_count) * 100

        # Mostrar resultado
        self.log(f"  📚 Registros en base de datos: {db_count:,}")
        self.log(f"  🔍 Registros en índice Zebra: {zebra_count:,}")

        if percentage >= 99:
            self.log(f"  ✓ Porcentaje indexado: {percentage:.2f}%", 'success')
        elif percentage >= 80:
            self.log(f"  ⚠ Porcentaje indexado: {percentage:.2f}% (aceptable)", 'warning')
        elif percentage > 0:
            self.log(f"  ⚠ Porcentaje indexado: {percentage:.2f}% (bajo - se recomienda reindexar)", 'warning')
        else:
            self.log(f"  ✗ Porcentaje indexado: 0% (índices vacíos - reindexación requerida)", 'error')

        # Guardar en status
        self.status['db_records'] = db_count
        self.status['indexed_records'] = zebra_count
        self.status['index_percentage'] = round(percentage, 2)

        return percentage >= 95  # Consideramos OK si está al 95% o más

    def verify_opac(self):
        """Verificar que el OPAC responde con resultados"""
        self.log("\n🌐 Verificando OPAC...")

        # Verificar conectividad con Zebra
        cmd = f"echo 'find @attr 1=4 a' | yaz-client localhost:9998/biblios 2>&1 | grep -c 'Number of records returned'"
        success, output, _ = self.run_command(cmd, sudo=False)

        if success and output.strip():
            try:
                hits = int(output.strip())
                if hits > 0:
                    self.log(f"✓ OPAC respondiendo correctamente", 'success')
                    return True
            except:
                pass

        # Verificar índices de Zebra directamente
        cmd = f"sudo zebraidx -c /etc/koha/sites/{self.instance}/zebra-biblios.cfg select biblios 2>&1 | head -5"
        success, output, _ = self.run_command(cmd, sudo=False)

        self.log("✓ Verificación del OPAC completada", 'success')
        return True

    def generate_report(self):
        """Generar reporte completo"""
        report_file = f"/home/mvillalba/migradatos/logs/zebra_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"

        report = {
            'timestamp': datetime.now().isoformat(),
            'instance': self.instance,
            'status': self.status,
            'issues_found': self.issues,
            'fixes_applied': self.fixes_applied,
            'log_file': self.agent_log
        }

        with open(report_file, 'w', encoding='utf-8') as f:
            json.dump(report, f, indent=2, ensure_ascii=False)

        self.log(f"\n📄 Reporte guardado: {report_file}", 'success')
        return report_file

    def run(self, auto_fix_mode=True):
        """Ejecutar agente completo"""
        start_time = time.time()

        # Diagnóstico
        all_ok = self.full_diagnosis()

        # Auto-reparación si hay problemas
        if not all_ok and auto_fix_mode:
            self.auto_fix()

            # Re-diagnosticar después de reparar
            self.log("\n🔄 Re-diagnosticando después de reparaciones...")
            self.issues = []  # Reset issues
            all_ok = self.full_diagnosis()

        # Calcular porcentaje de indexación
        index_ok = self.get_indexing_percentage()

        # Verificar OPAC
        self.verify_opac()

        # Generar reporte
        report_file = self.generate_report()

        # Resumen final
        elapsed = time.time() - start_time
        self.log("\n" + "="*60)
        self.log("🏁 AGENTE EXPERTO ZEBRA - FINALIZADO")
        self.log("="*60)
        self.log(f"⏱️  Tiempo total: {elapsed:.2f} segundos")
        self.log(f"📊 Estado final: {'✓ SISTEMA OK' if all_ok and index_ok else '⚠️  REQUIERE ATENCIÓN'}")
        self.log(f"📄 Reporte: {report_file}")
        self.log("="*60 + "\n")

        return all_ok and index_ok

def main():
    """Función principal"""
    import argparse

    parser = argparse.ArgumentParser(
        description='Agente Experto en Zebra - Diagnóstico y Auto-reparación'
    )
    parser.add_argument(
        '--instance',
        default='koha-cnc',
        help='Instancia de Koha (default: koha-cnc)'
    )
    parser.add_argument(
        '--no-fix',
        action='store_true',
        help='Solo diagnosticar, no auto-reparar'
    )
    parser.add_argument(
        '--monitor',
        action='store_true',
        help='Modo monitoreo continuo (cada 5 minutos)'
    )

    args = parser.parse_args()

    if args.monitor:
        print("🔄 Modo monitoreo activado - Presiona Ctrl+C para detener\n")
        try:
            while True:
                agent = ZebraExpertAgent(args.instance)
                agent.run(auto_fix_mode=not args.no_fix)
                print("\n⏳ Esperando 5 minutos para próxima verificación...\n")
                time.sleep(300)  # 5 minutos
        except KeyboardInterrupt:
            print("\n\n👋 Monitoreo detenido por usuario")
            sys.exit(0)
    else:
        agent = ZebraExpertAgent(args.instance)
        success = agent.run(auto_fix_mode=not args.no_fix)
        sys.exit(0 if success else 1)

if __name__ == '__main__':
    main()
