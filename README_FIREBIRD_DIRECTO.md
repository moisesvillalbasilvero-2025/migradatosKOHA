# 🔥 IMPORTACIÓN DIRECTA FIREBIRD → KOHA

**Universidad Nacional de Asunción**
**Sistema de Importación sin CSV Intermedios**

---

## ✅ **SÍ, FUNCIONA CON FIREBIRD REMOTO**

**Firebird soporta conexiones remotas de forma nativa**. No necesitas:
- ❌ Exportar CSV manualmente
- ❌ Copiar archivos entre servidores
- ❌ Acceso físico al servidor Firebird

**Todo es automático y remoto** 🎯

---

## 🎯 **¿Cómo Funciona?**

```
ANTES (con CSV):
  Servidor Firebird → Exportar CSV → Copiar a Koha → Importar CSV → Koha DB
  ❌ Manual
  ❌ Propenso a errores
  ❌ Archivos intermedios

AHORA (Directo):
  Servidor Firebird ──────remoto TCP/IP──────> Script Python ──> Koha DB
  ✅ Automático
  ✅ Sincronización programable
  ✅ Sin archivos intermedios
```

---

## 📦 **Archivos Creados**

| Archivo | Descripción | Uso |
|---------|-------------|-----|
| **`firebird_directo_koha.py`** | Sistema completo de sincronización | Script principal |
| **`test_firebird_remoto.py`** | Prueba de conexión interactiva | Primer paso |
| **`GUIA_FIREBIRD_REMOTO.md`** | Guía completa paso a paso | Documentación |
| **`firebird_structure_analyzer.py`** | Analiza estructura de BD | Herramienta |
| **`firebird_exporter.py`** | Exportador a CSV (opcional) | Legacy |

---

## 🚀 **Inicio Rápido (5 Pasos)**

### **1. Instalar Driver Python para Firebird**

```bash
# Opción 1 (recomendada)
sudo apt install python3-fdb

# Opción 2
pip3 install fdb
```

### **2. Probar Conexión**

```bash
./test_firebird_remoto.py
```

Te pedirá:
- Host (ej: `192.168.1.100`)
- Puerto (por defecto: `3050`)
- Ruta de BD (ej: `/datos/biblioteca.fdb`)
- Usuario (por defecto: `SYSDBA`)
- Password

**Si conecta**: ✅ Te muestra todas las tablas

**Si falla**: ❌ Te da diagnóstico del problema

### **3. Analizar Estructura de Tu Firebird**

```bash
cp _obsoletos/firebird_structure_analyzer.py ./

./firebird_structure_analyzer.py \
  --host 192.168.1.100 \
  --database /datos/biblioteca.fdb \
  --user SYSDBA \
  --password tu_password \
  --detailed
```

Esto te muestra:
- Nombres de tablas
- Columnas de cada tabla
- Tipos de datos
- Datos de ejemplo

### **4. Configurar `firebird_directo_koha.py`**

Editar el archivo y configurar tus servidores:

```python
FIREBIRD_SERVERS = {
    'FACAGR': {  # ← TU CÓDIGO
        'nombre': 'Facultad de Ciencias Agrarias',
        'host': '192.168.1.100',           # ← TU IP
        'port': 3050,
        'database': '/datos/facagr.fdb',   # ← TU BD
        'user': 'SYSDBA',                  # ← TU USUARIO
        'password': 'tu_password',         # ← TU PASSWORD
        'charset': 'UTF8',
        'activo': True,  # ← IMPORTANTE: True para activar
    },
}
```

**Adaptar Query SQL** a tus nombres de tablas:

```python
def get_export_query(only_modified_since=None):
    query = """
        SELECT
            b.ID_REGISTRO as analisis,      # ← TUS NOMBRES REALES
            b.TITULO as titulo,
            b.AUTOR as autor,
            e.CODIGO_BARRAS as nroacceso
        FROM BIBLIOGRAFICOS b                # ← TU TABLA REAL
        LEFT JOIN EJEMPLARES e ON ...
    """
```

### **5. Ejecutar Primera Importación**

```bash
# Probar conexiones
./firebird_directo_koha.py --test

# Ver estado
./firebird_directo_koha.py --status

# Primera importación
./firebird_directo_koha.py --biblioteca FACAGR
```

---

## 💡 **Casos de Uso**

### **Caso 1: Importación Única**

```bash
./firebird_directo_koha.py --biblioteca FACAGR
```

Importa todos los registros de FACAGR.

### **Caso 2: Sincronización Incremental**

```bash
./firebird_directo_koha.py --biblioteca FACAGR --incremental
```

Solo importa registros **nuevos o modificados** desde última sincronización.

### **Caso 3: Todas las Bibliotecas**

```bash
./firebird_directo_koha.py --all --incremental
```

Sincroniza todas las bibliotecas configuradas con `'activo': True`.

### **Caso 4: Sincronización Automática Continua**

```bash
# Cada hora
./firebird_directo_koha.py --daemon --intervalo 3600
```

Modo daemon que sincroniza automáticamente cada X segundos.

### **Caso 5: Con Cron (Automatización)**

```bash
# Editar crontab
crontab -e

# Sincronización diaria a las 2 AM
0 2 * * * cd /home/mvillalba/migradatos && ./firebird_directo_koha.py --all --incremental
```

---

## 🔒 **Requisitos del Servidor Firebird**

### **1. Puerto 3050 Abierto**

```bash
# En servidor Firebird
sudo ufw allow 3050/tcp
```

### **2. Firebird Acepta Conexiones Remotas**

Editar `/etc/firebird/3.0/firebird.conf`:

```ini
RemoteBindAddress = 0.0.0.0
```

Reiniciar:
```bash
sudo systemctl restart firebird3.0
```

### **3. Usuario con Permisos**

Puedes usar `SYSDBA` o crear usuario específico:

```sql
CREATE USER koha_readonly PASSWORD 'password_seguro';
GRANT SELECT ON BIBLIOGRAFICOS TO koha_readonly;
GRANT SELECT ON EJEMPLARES TO koha_readonly;
```

---

## 🔍 **Verificación**

### **Probar Conectividad de Red**

```bash
# Ping
ping 192.168.1.100

# Telnet al puerto
telnet 192.168.1.100 3050

# Nmap (si está instalado)
nmap -p 3050 192.168.1.100
```

### **Conectar con Cliente Firebird**

```bash
# Instalar cliente
sudo apt install firebird3.0-utils

# Conectar
isql-fb -user SYSDBA -password masterkey \
  192.168.1.100:/datos/biblioteca.fdb
```

---

## 📊 **Ventajas vs CSV Manual**

| Aspecto | CSV Manual | Firebird Directo |
|---------|-----------|------------------|
| **Proceso** | Manual | Automático |
| **Archivos intermedios** | Sí (CSV, XML) | No |
| **Sincronización** | Manual | Programable |
| **Incremental** | ❌ Todo siempre | ✅ Solo cambios |
| **Errores** | Muchos pasos | Un comando |
| **Tiempo** | Horas | Minutos |
| **Actualidad** | Depende de cuándo exportas | Tiempo real |
| **Múltiples servidores** | Uno por uno | Todos juntos |

---

## 🛡️ **Seguridad**

### **1. No Hardcodear Passwords**

Usar variables de entorno:

```bash
# Crear archivo .env
echo "FACAGR_PASSWORD=tu_password_real" > .env
chmod 600 .env

# En el script, cargar desde .env
pip3 install python-dotenv
```

### **2. VPN/Túnel SSH para Internet**

Si tu Firebird está en internet (no red local):

```bash
# Crear túnel SSH
ssh -L 3050:localhost:3050 usuario@servidor-firebird.edu.py

# Luego conectar a localhost
host='localhost'
```

### **3. Firewall Restrictivo**

Solo permitir IP del servidor Koha:

```bash
# En servidor Firebird
sudo ufw allow from 192.168.1.50 to any port 3050
```

---

## 🔧 **Solución de Problemas Comunes**

### **Error: "Unable to complete network request"**

```bash
# Verificar que servidor responde
ping 192.168.1.100

# Verificar puerto
telnet 192.168.1.100 3050
```

### **Error: "Your user name and password are not defined"**

- Verificar usuario/password
- Probar primero con `SYSDBA` / `masterkey`

### **Error: "I/O error during 'open' operation"**

- Ruta de BD incorrecta
- Archivo no existe
- Sin permisos

```bash
# En servidor Firebird, verificar:
ls -la /datos/biblioteca.fdb
```

### **Error: "Connection rejected by remote interface"**

Firebird no acepta conexiones remotas:

```bash
# Editar firebird.conf
sudo nano /etc/firebird/3.0/firebird.conf

# Cambiar:
RemoteBindAddress = 0.0.0.0

# Reiniciar
sudo systemctl restart firebird3.0
```

---

## 📚 **Documentación Completa**

| Documento | Contenido | Cuándo Leer |
|-----------|-----------|-------------|
| **Este archivo** | Resumen rápido | Primero |
| **`GUIA_FIREBIRD_REMOTO.md`** | Guía completa paso a paso | Para configurar |
| **`test_firebird_remoto.py`** | Script de prueba | Para probar conexión |
| **`firebird_directo_koha.py`** | Sistema completo | Código fuente |

---

## 🎓 **Ejemplo Completo de Uso**

```bash
# 1. Instalar driver
sudo apt install python3-fdb

# 2. Probar conexión
./test_firebird_remoto.py
# Ingresar: host, BD, usuario, password

# 3. Si conecta OK, ver tablas
./firebird_structure_analyzer.py \
  --host 192.168.1.100 \
  --database /datos/biblioteca.fdb \
  --user SYSDBA \
  --password masterkey \
  --detailed

# 4. Configurar firebird_directo_koha.py
nano firebird_directo_koha.py
# Editar FIREBIRD_SERVERS y get_export_query()

# 5. Probar configuración
./firebird_directo_koha.py --test

# 6. Primera importación
./firebird_directo_koha.py --biblioteca FACAGR

# 7. Configurar cron para automático
crontab -e
# Agregar:
0 2 * * * cd /home/mvillalba/migradatos && ./firebird_directo_koha.py --all --incremental
```

---

## ⚡ **Comandos Rápidos**

```bash
# PROBAR
./test_firebird_remoto.py              # Probar conexión interactiva
./firebird_directo_koha.py --test      # Probar todas las configuradas

# SINCRONIZAR
./firebird_directo_koha.py --biblioteca FACAGR               # Una vez
./firebird_directo_koha.py --biblioteca FACAGR --incremental # Solo nuevos
./firebird_directo_koha.py --all --incremental               # Todas

# AUTOMATIZAR
./firebird_directo_koha.py --daemon --intervalo 3600   # Cada hora (continuo)

# ESTADO
./firebird_directo_koha.py --status    # Ver última sincronización
```

---

## 🎯 **Próximos Pasos**

1. ✅ **Instalar driver**: `sudo apt install python3-fdb`
2. ✅ **Probar conexión**: `./test_firebird_remoto.py`
3. ✅ **Analizar estructura**: Con analyzer si es necesario
4. ✅ **Configurar**: Editar `firebird_directo_koha.py`
5. ✅ **Primera importación**: `--biblioteca XXX`
6. ✅ **Automatizar**: Configurar cron

---

## ❓ **FAQ**

### **¿Puedo importar desde múltiples servidores Firebird?**
✅ Sí, configura múltiples entradas en `FIREBIRD_SERVERS`.

### **¿Funciona con Firebird 2.x y 3.x?**
✅ Sí, el driver `fdb` soporta ambas versiones.

### **¿Necesito acceso físico al servidor Firebird?**
❌ No, solo necesitas conectividad de red y credenciales.

### **¿Puedo sincronizar solo registros nuevos?**
✅ Sí, usa el flag `--incremental`.

### **¿Qué pasa si se cae la red durante sincronización?**
El script falla pero no daña datos. Vuelve a ejecutar.

### **¿Puedo probar sin afectar producción?**
✅ Sí, primero usa `--test` para verificar conexión.

### **¿Funciona en Windows?**
✅ Sí, Python y Firebird son multiplataforma.

---

## 📞 **Soporte**

### **Archivos de Log**

```bash
logs/sync_*.log          # Logs de sincronización
.firebird_sync/          # Estado de sincronización
```

### **Verificar Estado**

```bash
./firebird_directo_koha.py --status
```

---

## ✅ **Checklist Pre-Importación**

- [ ] Driver `fdb` instalado
- [ ] Conexión probada con `test_firebird_remoto.py`
- [ ] Estructura de BD analizada
- [ ] Configuración actualizada en script
- [ ] Query SQL adaptado a tus tablas
- [ ] Primera importación manual exitosa
- [ ] Sincronización incremental probada
- [ ] Cron configurado (opcional)

---

**¡Sistema listo para importar directamente desde Firebird remoto! 🔥**

Universidad Nacional de Asunción - 2025

Para más detalles: `less GUIA_FIREBIRD_REMOTO.md`
