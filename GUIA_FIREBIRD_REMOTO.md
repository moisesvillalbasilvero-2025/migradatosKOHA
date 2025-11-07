# 🔥 GUÍA: CONEXIÓN REMOTA A FIREBIRD

**Universidad Nacional de Asunción**
**Importación Directa desde Firebird Remoto a Koha**

---

## ✅ **SÍ, FIREBIRD SOPORTA CONEXIONES REMOTAS**

Firebird fue diseñado específicamente para conexiones remotas de cliente-servidor. **No necesitas archivos CSV intermedios**.

---

## 🎯 **Cómo Funciona**

```
┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
│  SERVIDOR       │  Red    │  SERVIDOR KOHA  │         │  KOHA DB        │
│  FIREBIRD       │ <────>  │  (Python Script)│  ────>  │  (MySQL)        │
│  (Remoto)       │ TCP/IP  │                 │         │                 │
│  192.168.1.100  │  3050   │  firebird_      │         │                 │
│                 │         │  directo_koha.py│         │                 │
└─────────────────┘         └─────────────────┘         └─────────────────┘

PASO 1: Script Python           PASO 2: Script Python        PASO 3: Script importa
conecta a Firebird remoto    → lee datos y genera MARCXML → directamente a Koha
```

---

## 📋 **Requisitos**

### En el Servidor Firebird (Remoto):

✅ Firebird instalado y corriendo
✅ Puerto 3050 abierto (puerto por defecto de Firebird)
✅ Usuario con permisos de lectura
✅ Firewall configurado para permitir conexiones

### En el Servidor Koha (Local):

✅ Python 3.8+
✅ Módulo `fdb` (driver Python para Firebird)
✅ Acceso de red al servidor Firebird
✅ Koha funcionando

---

## 🔧 **Instalación**

### 1. Instalar Driver Python para Firebird

```bash
# Opción 1: Con pip
pip3 install fdb

# Opción 2: Con apt (Ubuntu/Debian)
sudo apt update
sudo apt install python3-fdb

# Opción 3: Si tienes problemas, instalar desde source
pip3 install git+https://github.com/FirebirdSQL/fdb.git
```

### 2. Verificar Instalación

```bash
python3 -c "import fdb; print(f'fdb versión: {fdb.__version__}')"
```

Debería mostrar algo como: `fdb versión: 2.0.2`

---

## 🌐 **Configuración de Conexión Remota**

### Formato de Conexión

```python
import fdb

conexion = fdb.connect(
    host='192.168.1.100',              # IP o hostname del servidor Firebird
    port=3050,                          # Puerto (3050 por defecto)
    database='/datos/biblioteca.fdb',   # Ruta AL ARCHIVO en el servidor remoto
    user='SYSDBA',                      # Usuario
    password='tu_password',             # Password
    charset='UTF8'                      # Encoding
)
```

### Ejemplos de Conexión:

#### **Servidor en la misma red local:**
```python
host='192.168.1.100'          # IP privada
```

#### **Servidor en internet (VPN/Túnel):**
```python
host='vpn.universidad.edu.py' # Hostname
```

#### **Servidor local (mismo equipo):**
```python
host='localhost'              # o '127.0.0.1'
```

---

## 🔐 **Configuración del Servidor Firebird**

### 1. Verificar que Firebird Acepta Conexiones Remotas

Editar `firebird.conf` en el servidor Firebird:

```bash
# En el servidor Firebird
sudo nano /etc/firebird/3.0/firebird.conf
```

Buscar y configurar:

```ini
# Permitir conexiones remotas
RemoteBindAddress = 0.0.0.0

# O específicamente tu IP de Koha
RemoteBindAddress = 192.168.1.50
```

Reiniciar Firebird:

```bash
sudo systemctl restart firebird3.0
```

### 2. Abrir Puerto en Firewall

```bash
# Ubuntu/Debian con ufw
sudo ufw allow 3050/tcp
sudo ufw reload

# CentOS/RHEL con firewalld
sudo firewall-cmd --permanent --add-port=3050/tcp
sudo firewall-cmd --reload
```

### 3. Verificar que Firebird Está Escuchando

```bash
# En el servidor Firebird
sudo netstat -tlnp | grep 3050
```

Debería mostrar:
```
tcp        0      0 0.0.0.0:3050            0.0.0.0:*               LISTEN      1234/fb_inet_server
```

---

## 🧪 **Probar Conexión Remota**

### Método 1: Con Script de Prueba

Crear `test_firebird.py`:

```python
#!/usr/bin/env python3
import fdb
import sys

# CONFIGURAR CON TUS DATOS
config = {
    'host': '192.168.1.100',           # ← TU IP DEL SERVIDOR FIREBIRD
    'port': 3050,
    'database': '/datos/biblio.fdb',   # ← RUTA DE TU BASE DE DATOS
    'user': 'SYSDBA',                  # ← TU USUARIO
    'password': 'masterkey',           # ← TU PASSWORD
    'charset': 'UTF8'
}

print("Probando conexión a Firebird...")
print(f"Host: {config['host']}:{config['port']}")
print(f"Base de datos: {config['database']}")
print()

try:
    # Intentar conectar
    conn = fdb.connect(**config)
    print("✓ CONEXIÓN EXITOSA")

    # Probar query
    cursor = conn.cursor()

    # Ver versión de Firebird
    cursor.execute("SELECT rdb$get_context('SYSTEM', 'ENGINE_VERSION') FROM RDB$DATABASE")
    version = cursor.fetchone()[0]
    print(f"✓ Versión Firebird: {version}")

    # Listar tablas
    cursor.execute("""
        SELECT RDB$RELATION_NAME
        FROM RDB$RELATIONS
        WHERE RDB$SYSTEM_FLAG = 0
        AND RDB$VIEW_BLR IS NULL
        ORDER BY RDB$RELATION_NAME
    """)

    tablas = [row[0].strip() for row in cursor.fetchall()]
    print(f"✓ Tablas encontradas: {len(tablas)}")

    if tablas:
        print("\nPrimeras 10 tablas:")
        for tabla in tablas[:10]:
            print(f"  - {tabla}")

    # Cerrar
    cursor.close()
    conn.close()

    print("\n✓✓✓ PRUEBA EXITOSA ✓✓✓")
    print("\nPuedes proceder con la configuración del importador")

except Exception as e:
    print(f"✗ ERROR: {e}")
    print("\nPosibles causas:")
    print("  1. IP/puerto incorrectos")
    print("  2. Firewall bloqueando puerto 3050")
    print("  3. Usuario/password incorrectos")
    print("  4. Firebird no acepta conexiones remotas")
    print("  5. Ruta de base de datos incorrecta")
    sys.exit(1)
```

Ejecutar:
```bash
chmod +x test_firebird.py
./test_firebird.py
```

### Método 2: Con Herramienta `isql-fb`

```bash
# Instalar cliente Firebird
sudo apt install firebird3.0-utils

# Conectar remotamente
isql-fb -user SYSDBA -password masterkey \
  192.168.1.100:/datos/biblioteca.fdb

# Dentro de isql-fb:
SQL> SHOW TABLES;
SQL> SELECT COUNT(*) FROM BIBLIOGRAFICOS;
SQL> EXIT;
```

---

## 📝 **Configurar Tu Sistema**

### 1. Editar `firebird_directo_koha.py`

Abrir el archivo y configurar en la sección `FIREBIRD_SERVERS`:

```python
FIREBIRD_SERVERS = {
    'FACAGR': {
        'nombre': 'Facultad de Ciencias Agrarias',
        'host': '192.168.1.100',           # ← TU IP REAL
        'port': 3050,
        'database': '/datos/facagr.fdb',   # ← RUTA REAL DE TU BD
        'user': 'SYSDBA',                  # ← TU USUARIO
        'password': 'tu_password_real',    # ← TU PASSWORD
        'charset': 'UTF8',
        'activo': True,                    # ← ACTIVAR
    },

    'FACEN': {
        'nombre': 'Facultad de Ciencias Exactas',
        'host': '192.168.1.101',
        'port': 3050,
        'database': '/var/lib/firebird/facen.fdb',
        'user': 'SYSDBA',
        'password': 'otro_password',
        'charset': 'UTF8',
        'activo': True,
    },
}
```

### 2. Adaptar Query SQL

En la función `get_export_query()`, adaptar nombres de tablas/columnas:

```python
def get_export_query(only_modified_since: Optional[datetime] = None):
    # EJEMPLO - Reemplazar con tus nombres reales

    query = """
        SELECT
            b.ID as analisis,                   # ← TUS NOMBRES REALES
            b.TITULO as titulo,
            b.AUTOR as autor,
            e.CODIGO_BARRAS as nroacceso,
            b.FECHA_MOD as fecha_mod

        FROM BIBLIOGRAFICOS b                   # ← TU TABLA REAL
        LEFT JOIN EJEMPLARES e ON b.ID = e.ID_BIBLIO
        WHERE 1=1
    """
```

---

## 🚀 **Uso del Sistema**

### 1. Probar Conexiones

```bash
./firebird_directo_koha.py --test
```

Verás:
```
╔════════════════════════════════════════════════════════════════════╗
║                  PRUEBA DE CONEXIONES FIREBIRD                     ║
╚════════════════════════════════════════════════════════════════════╝

Probando: Facultad de Ciencias Agrarias
  Host: 192.168.1.100:3050
  BD:   /datos/facagr.fdb
  ✓ CONECTADO
  Tablas: 15
  Registros: 37,226
```

### 2. Ver Estado de Sincronización

```bash
./firebird_directo_koha.py --status
```

### 3. Sincronizar una Biblioteca

```bash
# Primera vez (importación completa)
./firebird_directo_koha.py --biblioteca FACAGR

# Siguientes veces (solo nuevos registros)
./firebird_directo_koha.py --biblioteca FACAGR --incremental
```

### 4. Sincronizar Todas

```bash
./firebird_directo_koha.py --all --incremental
```

### 5. Modo Automático (Daemon)

```bash
# Sincroniza cada hora automáticamente
./firebird_directo_koha.py --daemon --intervalo 3600

# En segundo plano
nohup ./firebird_directo_koha.py --daemon --intervalo 3600 &
```

---

## 🔍 **Descubrir Estructura de Tu Firebird**

Si no conoces la estructura de tu BD, usa el analizador:

```bash
# Copiar desde obsoletos
cp _obsoletos/firebird_structure_analyzer.py ./

# Ejecutar
./firebird_structure_analyzer.py \
  --host 192.168.1.100 \
  --database /datos/biblioteca.fdb \
  --user SYSDBA \
  --password tu_password \
  --detailed
```

Esto te mostrará:
- Nombres de todas las tablas
- Columnas de cada tabla
- Tipos de datos
- Relaciones (foreign keys)
- Datos de ejemplo

---

## 🛡️ **Seguridad**

### 1. No Hardcodear Passwords

Crear archivo `.env`:

```bash
# .env (NO subir a git)
FACAGR_HOST=192.168.1.100
FACAGR_DB=/datos/facagr.fdb
FACAGR_USER=SYSDBA
FACAGR_PASSWORD=tu_password_secreto
```

Usar en el script:

```python
import os
from dotenv import load_dotenv

load_dotenv()

FIREBIRD_SERVERS = {
    'FACAGR': {
        'host': os.getenv('FACAGR_HOST'),
        'database': os.getenv('FACAGR_DB'),
        'user': os.getenv('FACAGR_USER'),
        'password': os.getenv('FACAGR_PASSWORD'),
        # ...
    }
}
```

Instalar python-dotenv:
```bash
pip3 install python-dotenv
```

### 2. Usar Usuario de Solo Lectura

En Firebird, crear usuario con permisos limitados:

```sql
-- En el servidor Firebird
CREATE USER koha_readonly PASSWORD 'password_seguro';
GRANT SELECT ON BIBLIOGRAFICOS TO koha_readonly;
GRANT SELECT ON EJEMPLARES TO koha_readonly;
```

### 3. VPN/Túnel SSH

Para servidores en internet, usar túnel SSH:

```bash
# Crear túnel SSH
ssh -L 3050:localhost:3050 usuario@servidor-remoto.edu.py

# Luego conectar a localhost en el script
host='localhost'
port=3050
```

---

## 🔧 **Solución de Problemas**

### Problema 1: "Unable to complete network request"

**Causa**: No puede conectar al servidor

**Solución**:
```bash
# 1. Verificar que servidor es accesible
ping 192.168.1.100

# 2. Verificar que puerto 3050 está abierto
telnet 192.168.1.100 3050

# O con nmap
nmap -p 3050 192.168.1.100

# 3. Verificar firewall
sudo ufw status
```

### Problema 2: "I/O error during 'open' operation"

**Causa**: Archivo de base de datos no existe o ruta incorrecta

**Solución**:
```bash
# En el servidor Firebird, verificar ruta
ls -la /datos/biblioteca.fdb

# Verificar que Firebird puede acceder
sudo -u firebird ls -la /datos/biblioteca.fdb
```

### Problema 3: "Your user name and password are not defined"

**Causa**: Credenciales incorrectas

**Solución**:
- Verificar usuario/password
- Verificar que usuario tiene permisos
- Probar con usuario SYSDBA primero

### Problema 4: "Connection rejected by remote interface"

**Causa**: Firebird no acepta conexiones remotas

**Solución**:
```bash
# En servidor Firebird, editar firebird.conf
sudo nano /etc/firebird/3.0/firebird.conf

# Cambiar:
RemoteBindAddress = 0.0.0.0

# Reiniciar
sudo systemctl restart firebird3.0
```

### Problema 5: Lento/Timeout

**Causa**: Red lenta o muchos datos

**Solución**:
- Usar importación incremental
- Aumentar timeout en el script
- Ejecutar en horarios de baja carga

---

## 📊 **Ventajas de Conexión Remota Directa**

✅ **Sin archivos intermedios** - No necesitas exportar CSV manualmente

✅ **Sincronización automática** - Configura y olvida

✅ **Incremental** - Solo importa registros nuevos/modificados

✅ **Tiempo real** - Los cambios en Firebird se reflejan rápido

✅ **Centralizado** - Un servidor Koha sincroniza múltiples Firebirds

✅ **Auditoría** - Logs de todas las sincronizaciones

---

## 📅 **Automatización con Cron**

### Sincronización Diaria a las 2 AM

```bash
# Editar crontab
crontab -e

# Agregar línea:
0 2 * * * cd /home/mvillalba/migradatos && ./firebird_directo_koha.py --all --incremental >> logs/sync_$(date +\%Y\%m\%d).log 2>&1
```

### Sincronización Cada 6 Horas

```bash
0 */6 * * * cd /home/mvillalba/migradatos && ./firebird_directo_koha.py --all --incremental
```

### Como Servicio Systemd

Crear `/etc/systemd/system/firebird-sync.service`:

```ini
[Unit]
Description=Firebird to Koha Sync Service
After=network.target

[Service]
Type=simple
User=mvillalba
WorkingDirectory=/home/mvillalba/migradatos
ExecStart=/home/mvillalba/migradatos/firebird_directo_koha.py --daemon --intervalo 3600
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
```

Activar:
```bash
sudo systemctl enable firebird-sync
sudo systemctl start firebird-sync
sudo systemctl status firebird-sync
```

---

## 📚 **Recursos Adicionales**

### Documentación Firebird:
- https://firebirdsql.org/en/reference-manuals/
- https://firebirdsql.org/en/firebird-3-0-language-reference/

### Driver Python fdb:
- https://github.com/FirebirdSQL/fdb
- https://fdb.readthedocs.io/

### Herramientas GUI para Firebird:
- **FlameRobin**: https://flamerobin.org/
- **DBeaver**: https://dbeaver.io/ (soporta Firebird)

---

## ✅ **Checklist de Configuración**

- [ ] Driver `fdb` instalado
- [ ] Firebird server accesible por red
- [ ] Puerto 3050 abierto en firewall
- [ ] Firebird acepta conexiones remotas
- [ ] Credenciales de acceso obtenidas
- [ ] Ruta de base de datos conocida
- [ ] Conexión probada con `test_firebird.py`
- [ ] Estructura de BD analizada
- [ ] Query SQL adaptado a tu estructura
- [ ] Configuración actualizada en `firebird_directo_koha.py`
- [ ] Primera sincronización probada

---

## 🎯 **Próximos Pasos**

1. ✅ Probar conexión: `./firebird_directo_koha.py --test`
2. ✅ Analizar estructura: `./firebird_structure_analyzer.py ...`
3. ✅ Adaptar query SQL en el script
4. ✅ Primera importación: `./firebird_directo_koha.py --biblioteca XXX`
5. ✅ Configurar sincronización automática

---

**¡Listo para importar directamente desde Firebird remoto! 🔥**

Universidad Nacional de Asunción - 2025
