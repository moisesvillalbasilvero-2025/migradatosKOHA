#!/usr/bin/env python3
"""
AUTO-IMPORTADOR SIMPLE
======================
Coloca un CSV → Se analiza → Se importa automáticamente

Requisitos:
- Nombre del archivo debe contener código de biblioteca (ej: MED.csv, VET.csv)
- Formato CSV correcto
- Biblioteca debe existir en Koha

Uso:
    python3 auto_importar.py               # Vigila carpeta
    python3 auto_importar.py MED.csv       # Procesa un archivo
"""

import os
import sys
import csv
import subprocess
import re
from pathlib import Path
from collections import Counter
from datetime import datetime


# ==================== CONFIGURACIÓN ====================
DIR_TRABAJO = Path("/home/mvillalba/migradatos")
DIR_VIGILAR = DIR_TRABAJO / "importar_aqui"
DIR_PROCESADOS = DIR_TRABAJO / "procesados"
DIR_ERRORES = DIR_TRABAJO / "errores"
DIR_EXPORTS = DIR_TRABAJO / "exports"
INSTANCIA_KOHA = "koha-cnc"

# Colores
G = '\033[92m'  # Verde
Y = '\033[93m'  # Amarillo
R = '\033[91m'  # Rojo
B = '\033[94m'  # Azul
C = '\033[96m'  # Cyan
BOLD = '\033[1m'
END = '\033[0m'


# ==================== FUNCIONES ====================

def log(msg, color=""):
    """Imprime mensaje con color"""
    print(f"{color}{msg}{END}")


def detectar_codigo(csv_path):
    """Detecta código de biblioteca del nombre del archivo"""
    nombre = Path(csv_path).stem

    # Buscar 3-6 letras mayúsculas
    match = re.search(r'([A-Z]{3,6})', nombre.upper())
    if match:
        return match.group(1)

    return None


def verificar_biblioteca_koha(codigo):
    """Verifica si biblioteca existe en Koha"""
    try:
        cmd = f"sudo koha-mysql {INSTANCIA_KOHA} -N -e \"SELECT branchname FROM branches WHERE branchcode = '{codigo}'\""
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=10)

        if result.returncode == 0 and result.stdout.strip():
            nombre = result.stdout.strip()
            log(f"✓ Biblioteca: {nombre}", G)
            return True
        else:
            log(f"✗ Biblioteca '{codigo}' NO existe en Koha", R)
            return False
    except Exception as e:
        log(f"✗ Error verificando: {e}", R)
        return False


def analizar_csv(csv_path):
    """Analiza CSV: estructura, duplicados, registros"""
    try:
        with open(csv_path, 'r', encoding='utf-8') as f:
            primera = f.readline()
            sep = ';' if ';' in primera else ','
            f.seek(0)

            reader = csv.DictReader(f, delimiter=sep)
            columnas = reader.fieldnames

            # Verificar campos obligatorios
            campos_necesarios = ['titulo', 'nroacceso']
            faltantes = [c for c in campos_necesarios if c not in [col.lower() for col in columnas]]

            if faltantes:
                log(f"✗ Faltan campos: {', '.join(faltantes)}", R)
                return None

            # Contar registros y duplicados
            registros = list(reader)
            total = len(registros)

            codigos = [r.get('nroacceso', '').strip() for r in registros if r.get('nroacceso', '').strip()]
            duplicados = sum(1 for k, v in Counter(codigos).items() if v > 1)

            return {
                'total': total,
                'duplicados': duplicados,
                'necesita_correccion': duplicados > 100
            }

    except Exception as e:
        log(f"✗ Error analizando CSV: {e}", R)
        return None


def corregir_duplicados(csv_path):
    """Corrige duplicados si es necesario"""
    log("→ Corrigiendo duplicados...", Y)

    try:
        cmd = f"python3 {DIR_TRABAJO}/corregir_codigos_vet.py {csv_path}"
        subprocess.run(cmd, shell=True, capture_output=True, timeout=300)

        # Buscar archivo corregido
        corregido = csv_path.parent / f"{csv_path.stem}_corregido.csv"
        if corregido.exists():
            log(f"✓ Corregido: {corregido.name}", G)
            return corregido

        return csv_path

    except Exception as e:
        log(f"⚠ No se pudo corregir: {e}", Y)
        return csv_path


def generar_marcxml(csv_path, codigo):
    """Genera MARCXML"""
    log("→ Generando MARCXML...", Y)

    try:
        cmd = f"""cd {DIR_EXPORTS} && python3 {DIR_TRABAJO}/opac_exportar.py \
-i {csv_path} \
--codbiblio {codigo} \
--loc-default SALA \
--stream 2>&1"""

        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=600)

        # Buscar XML generado más reciente
        xmls = list(DIR_EXPORTS.glob(f"{codigo}_*_marcxml*.xml"))
        if xmls:
            xmls.sort(key=lambda x: x.stat().st_mtime, reverse=True)
            xml_file = xmls[0]

            # Contar registros
            with open(xml_file) as f:
                num_records = f.read().count('<record>')

            log(f"✓ MARCXML: {xml_file.name} ({num_records} registros)", G)
            return xml_file

        log("✗ No se generó MARCXML", R)
        return None

    except Exception as e:
        log(f"✗ Error generando MARCXML: {e}", R)
        return None


def importar_koha(xml_path):
    """Importa a Koha"""
    log("→ Importando a Koha...", Y)

    try:
        cmd = f"""sudo koha-shell {INSTANCIA_KOHA} -c "perl /usr/share/koha/bin/migration_tools/bulkmarcimport.pl \
-b -m MARCXML -file {xml_path} -commit 1000" """

        result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=1800)

        if result.returncode == 0:
            # Extraer estadísticas
            output = result.stdout + result.stderr
            for line in output.split('\n'):
                if 'biblios' in line.lower() or 'items' in line.lower():
                    log(f"  {line.strip()}", C)

            log("✓ Importación completada", G)
            return True

        log(f"✗ Error en importación", R)
        return False

    except Exception as e:
        log(f"✗ Error: {e}", R)
        return False


def reindexar():
    """Reindexa Koha"""
    log("→ Reindexando...", Y)

    try:
        cmd = f"sudo koha-rebuild-zebra -f -v {INSTANCIA_KOHA}"
        subprocess.run(cmd, shell=True, capture_output=True, timeout=900)
        log("✓ Reindexación completada", G)
    except Exception as e:
        log(f"⚠ Advertencia reindexando: {e}", Y)


def mover_archivo(origen, destino_dir, sufijo=""):
    """Mueve archivo a carpeta destino"""
    destino_dir.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    nombre = Path(origen).stem
    destino = destino_dir / f"{nombre}{sufijo}_{timestamp}.csv"

    try:
        Path(origen).rename(destino)
        log(f"→ Movido a: {destino.name}", C)
    except Exception as e:
        log(f"⚠ No se pudo mover: {e}", Y)


def procesar_archivo(csv_path):
    """PROCESO PRINCIPAL: analiza y procesa CSV automáticamente"""

    csv_path = Path(csv_path)

    print("\n" + "="*70)
    log(f"📄 ARCHIVO: {csv_path.name}", BOLD + C)
    print("="*70)

    # 1. DETECTAR CÓDIGO
    print(f"\n{BOLD}1. DETECTAR BIBLIOTECA{END}")
    codigo = detectar_codigo(csv_path)

    if not codigo:
        log("✗ No se detectó código de biblioteca en el nombre", R)
        mover_archivo(csv_path, DIR_ERRORES, "_SIN_CODIGO")
        return False

    log(f"✓ Código detectado: {codigo}", G)

    # 2. VERIFICAR EN KOHA
    print(f"\n{BOLD}2. VERIFICAR EN KOHA{END}")
    if not verificar_biblioteca_koha(codigo):
        mover_archivo(csv_path, DIR_ERRORES, "_NO_EXISTE")
        return False

    # 3. ANALIZAR CSV
    print(f"\n{BOLD}3. ANALIZAR FORMATO{END}")
    analisis = analizar_csv(csv_path)

    if not analisis:
        log("✗ Formato CSV inválido", R)
        mover_archivo(csv_path, DIR_ERRORES, "_FORMATO_INVALIDO")
        return False

    log(f"✓ Registros: {analisis['total']}", G)

    if analisis['duplicados'] > 0:
        log(f"⚠ Duplicados: {analisis['duplicados']}", Y)

    # 4. CORREGIR SI ES NECESARIO
    csv_usar = csv_path
    if analisis['necesita_correccion']:
        print(f"\n{BOLD}4. CORREGIR DUPLICADOS{END}")
        csv_usar = corregir_duplicados(csv_path)
    else:
        log("\n✓ No necesita corrección", G)

    # 5. GENERAR MARCXML
    print(f"\n{BOLD}5. GENERAR MARCXML{END}")
    xml_file = generar_marcxml(csv_usar, codigo)

    if not xml_file:
        mover_archivo(csv_path, DIR_ERRORES, "_ERROR_MARCXML")
        return False

    # 6. IMPORTAR
    print(f"\n{BOLD}6. IMPORTAR A KOHA{END}")
    if not importar_koha(xml_file):
        mover_archivo(csv_path, DIR_ERRORES, "_ERROR_IMPORT")
        return False

    # 7. REINDEXAR
    print(f"\n{BOLD}7. REINDEXAR{END}")
    reindexar()

    # 8. ÉXITO
    print(f"\n{G}{BOLD}{'='*70}")
    print(f"✓✓✓ IMPORTACIÓN COMPLETADA EXITOSAMENTE ✓✓✓")
    print(f"{'='*70}{END}\n")

    mover_archivo(csv_path, DIR_PROCESADOS, "_OK")

    return True


# ==================== MODO VIGILANCIA ====================

def modo_vigilancia():
    """Vigila carpeta y procesa automáticamente"""

    DIR_VIGILAR.mkdir(parents=True, exist_ok=True)

    print(f"\n{C}{BOLD}╔{'═'*68}╗{END}")
    print(f"{C}{BOLD}║{' '*15}AUTO-IMPORTADOR ACTIVADO{' '*30}║{END}")
    print(f"{C}{BOLD}╚{'═'*68}╝{END}\n")

    log(f"👁  Vigilando: {DIR_VIGILAR}", C)
    log(f"💡 Coloca archivos CSV aquí para procesarlos automáticamente\n", Y)

    # Mostrar archivos existentes
    archivos = list(DIR_VIGILAR.glob("*.csv"))
    if archivos:
        log(f"📋 Archivos detectados: {len(archivos)}", B)
        for arch in archivos:
            log(f"   • {arch.name}", B)

        respuesta = input(f"\n¿Procesar ahora? (SI/no): ")
        if respuesta.strip().upper() in ['SI', 'YES', 'S', 'Y', '']:
            for arch in archivos:
                procesar_archivo(arch)

    log("\n⏳ Esperando nuevos archivos... (Ctrl+C para salir)", Y)

    # Vigilancia simple con bucle
    procesados = set(arch.name for arch in archivos)

    try:
        import time
        while True:
            archivos_actuales = list(DIR_VIGILAR.glob("*.csv"))

            for arch in archivos_actuales:
                if arch.name not in procesados:
                    log(f"\n🔔 NUEVO ARCHIVO: {arch.name}", BOLD + C)
                    time.sleep(2)  # Esperar estabilidad
                    procesar_archivo(arch)
                    procesados.add(arch.name)

            time.sleep(5)

    except KeyboardInterrupt:
        log("\n\n👋 Deteniendo vigilancia...", Y)


# ==================== MAIN ====================

def main():
    """Punto de entrada"""

    if len(sys.argv) > 1:
        # MODO: Procesar archivo específico
        for archivo in sys.argv[1:]:
            if Path(archivo).exists():
                procesar_archivo(archivo)
            else:
                log(f"✗ Archivo no encontrado: {archivo}", R)
    else:
        # MODO: Vigilancia de carpeta
        modo_vigilancia()


if __name__ == '__main__':
    main()
