# 🔥 CONEXIÓN A FIREBIRD 2.5.7 CON ARCHIVOS .GDB

**Universidad Nacional de Asunción**

---

## ✅ **SÍ, FUNCIONA CON FIREBIRD 2.5.7 Y ARCHIVOS .GDB**

El driver Python `fdb 2.0.4` que instalamos **soporta completamente**:
- ✅ Firebird 2.5.x (incluye 2.5.7)
- ✅ Archivos `.gdb` (formato antiguo)
- ✅ Archivos `.fdb` (formato nuevo)
- ✅ Conexiones remotas TCP/IP
- ✅ Conexiones locales

---

## 📋 **Diferencia entre .GDB y .FDB**

| Aspecto | .GDB | .FDB |
|---------|------|------|
| **Uso** | Firebird ≤ 2.x (antiguo) | Firebird ≥ 2.x (nuevo) |
| **Funcionalidad** | Idéntica | Idéntica |
| **Compatibilidad** | ✅ Funciona igual | ✅ Funciona igual |

**No hay diferencia funcional**, solo cambio de extensión por nomenclatura.

---

## 🚀 **Inicio Rápido - Firebird 2.5.7 (.gdb)**

### **Paso 1: Probar Conexión**

```bash
./test_firebird_remoto.py
```

**Ejemplo de datos para Firebird 2.5.7 con .gdb:**

```
Host del servidor Firebird: 192.168.1.100
Puerto (Enter para 3050): 3050
Ruta de la base de datos: /datos/biblioteca.gdb    # ← .gdb en lugar de .fdb
Usuario (Enter para SYSDBA): SYSDBA
Password: masterkey
Charset (Enter para UTF8): WIN1252                 # ← Importante para 2.5.x
```

### **Paso 2: Configurar firebird_directo_koha.py**

Editar la sección `FIREBIRD_SERVERS`:

```python
FIREBIRD_SERVERS = {
    'TU_BIBLIOTECA': {
        'nombre': 'Nombre de Tu Biblioteca',
        'host': '192.168.1.100',              # IP del servidor
        'port': 3050,
        'database': '/datos/biblioteca.gdb',  # ← ARCHIVO .GDB
        'user': 'SYSDBA',
        'password': 'tu_password_real',
        'charset': 'WIN1252',                 # ← Para Firebird 2.5.x
        'activo': True,
    },
}
```

### **Paso 3: Probar Configuración**

```bash
./firebird_directo_koha.py --test
```

Si conecta OK, verás:
```
✓ TU_BIBLIOTECA: Conexión exitosa (192.168.1.100:/datos/biblioteca.gdb)
```

### **Paso 4: Primera Importación**

```bash
./firebird_directo_koha.py --biblioteca TU_BIBLIOTECA
```

---

## ⚙️ **Diferencias Importantes Firebird 2.5.7**

### **1. Charset Recomendado**

Firebird 2.5.x frecuentemente usa `WIN1252` en lugar de `UTF8`:

```python
# Si ves errores de encoding, prueba:
'charset': 'WIN1252'    # Para datos en español
'charset': 'ISO8859_1'  # Alternativa
'charset': 'UTF8'       # Si tu BD fue creada con UTF8
```

### **2. Sintaxis SQL Compatible**

Firebird 2.5.7 **NO soporta**:
- ❌ `BOOLEAN` (usar `SMALLINT` o `CHAR(1)`)
- ❌ Algunas funciones modernas de Firebird 3.x

**Usar sintaxis compatible:**

```sql
-- ✅ CORRECTO para Firebird 2.5.x
SELECT
    b.ID_REGISTRO,
    b.TITULO,
    b.AUTOR,
    CAST(b.FECHA_REGISTRO AS DATE) as fecha_alta
FROM BIBLIOGRAFICOS b
WHERE b.FECHA_REGISTRO > ?

-- ❌ EVITAR (solo Firebird 3.x)
SELECT
    b.ID_REGISTRO,
    b.FECHA_REGISTRO AT TIME ZONE 'UTC'
FROM BIBLIOGRAFICOS b
```

### **3. Comandos de Conexión**

Para **Firebird 2.5.x** en Linux:

```bash
# Cliente de línea de comandos
isql-fb /datos/biblioteca.gdb -user SYSDBA -password masterkey

# Conexión remota
isql-fb 192.168.1.100:/datos/biblioteca.gdb -user SYSDBA
```

---

## 🔍 **Verificar Versión de Firebird**

### **Desde Línea de Comandos (en servidor Firebird):**

```bash
# Ver versión instalada
firebird-superserver --version
# O
fb_inet_server --version
```

### **Desde Python:**

```python
import fdb

conn = fdb.connect(
    host='192.168.1.100',
    database='/datos/biblioteca.gdb',
    user='SYSDBA',
    password='masterkey',
    charset='WIN1252'
)

cursor = conn.cursor()
cursor.execute("SELECT rdb$get_context('SYSTEM', 'ENGINE_VERSION') FROM RDB$DATABASE")
version = cursor.fetchone()[0]
print(f"Firebird versión: {version}")
conn.close()
```

---

## 🛡️ **Requisitos del Servidor Firebird 2.5.7**

### **1. Puerto Abierto (default: 3050)**

```bash
# En servidor Firebird
sudo ufw allow 3050/tcp
```

### **2. Configuración de firebird.conf**

Ubicación: `/etc/firebird/2.5/firebird.conf`

Verificar:
```ini
# Permitir conexiones remotas
RemoteBindAddress =

# O específicamente
RemoteBindAddress = 0.0.0.0
```

Reiniciar servicio:
```bash
sudo service firebird2.5-super restart
# O
sudo /etc/init.d/firebird2.5-super restart
```

### **3. Permisos de Archivo .gdb**

```bash
# Verificar permisos
ls -la /datos/biblioteca.gdb

# Usuario firebird debe poder leer/escribir
sudo chown firebird:firebird /datos/biblioteca.gdb
sudo chmod 660 /datos/biblioteca.gdb
```

---

## 🔧 **Solución de Problemas Específicos**

### **Error: "Character set WIN1252 is not defined"**

**Solución**: Cambiar charset a uno disponible:

```python
'charset': 'ISO8859_1'  # Prueba este
```

### **Error: "Cannot transliterate character"**

**Causa**: Encoding incorrecto en los datos

**Solución**: Probar diferentes charsets:

```python
# Orden de prioridad para español en Firebird 2.5.x
1. 'charset': 'WIN1252'      # Primero probar
2. 'charset': 'ISO8859_1'    # Si falla
3. 'charset': 'UTF8'         # Si fue creada con UTF8
4. 'charset': 'NONE'         # Último recurso (no recomendado)
```

### **Error: "Your user name and password are not defined"**

```bash
# Verificar usuario en servidor Firebird
gsec -database /datos/biblioteca.gdb -user SYSDBA -password masterkey
GSEC> display SYSDBA
GSEC> display
GSEC> quit
```

### **Error: "Unable to complete network request"**

**Verificar conectividad:**

```bash
# 1. Ping
ping 192.168.1.100

# 2. Puerto abierto
telnet 192.168.1.100 3050

# 3. Firewall
sudo ufw status | grep 3050
```

---

## 📊 **Ejemplo Completo de Uso**

```bash
# 1. Probar conexión con tu .gdb
./test_firebird_remoto.py

# Ingresar datos cuando lo solicite:
#   Host: 192.168.1.100
#   Puerto: 3050
#   BD: /datos/biblioteca.gdb
#   Usuario: SYSDBA
#   Password: (tu password)
#   Charset: WIN1252

# 2. Si conecta OK, configurar firebird_directo_koha.py
nano firebird_directo_koha.py

# Editar FIREBIRD_SERVERS con tus datos reales

# 3. Probar configuración
./firebird_directo_koha.py --test

# 4. Ver estado actual
./firebird_directo_koha.py --status

# 5. Primera importación
./firebird_directo_koha.py --biblioteca TU_CODIGO

# 6. Sincronización incremental
./firebird_directo_koha.py --biblioteca TU_CODIGO --incremental
```

---

## 🎯 **Configuración Típica para Firebird 2.5.7**

```python
# En firebird_directo_koha.py

FIREBIRD_SERVERS = {
    'FACAGR': {
        'nombre': 'Facultad de Ciencias Agrarias',
        'host': '192.168.10.50',
        'port': 3050,
        'database': '/opt/firebird/datos/facagr.gdb',  # Ruta típica
        'user': 'SYSDBA',
        'password': 'masterkey',                       # Cambiar
        'charset': 'WIN1252',                          # Para español
        'activo': True,
    },

    'FACMED': {
        'nombre': 'Facultad de Medicina',
        'host': '192.168.10.51',
        'port': 3050,
        'database': 'C:\\Datos\\Biblioteca\\medicina.gdb',  # Windows
        'user': 'SYSDBA',
        'password': 'password_seguro',
        'charset': 'WIN1252',
        'activo': True,
    },
}
```

---

## 📚 **Recursos Adicionales**

| Documento | Contenido |
|-----------|-----------|
| `README_FIREBIRD_DIRECTO.md` | Guía general (todas versiones) |
| `GUIA_FIREBIRD_REMOTO.md` | Guía completa paso a paso |
| `test_firebird_remoto.py` | Script de prueba interactivo |
| `firebird_directo_koha.py` | Sistema completo |

---

## ❓ **FAQ - Firebird 2.5.7**

### **¿El driver fdb funciona con Firebird 2.5.7?**
✅ **Sí**, fdb 2.0.4 soporta completamente Firebird 2.5.x

### **¿Debo convertir .gdb a .fdb?**
❌ **No**, ambas extensiones funcionan idénticamente

### **¿Qué charset uso?**
**WIN1252** es el más común en Firebird 2.5.x para español

### **¿Funciona con Firebird en Windows?**
✅ **Sí**, el protocolo es el mismo en Linux/Windows

### **¿Puedo conectar desde Linux a Firebird Windows?**
✅ **Sí**, el driver fdb es multiplataforma

### **¿La ruta del .gdb debe ser local o remota?**
**Remota**: La ruta es en el servidor Firebird, no en tu máquina local

Ejemplo:
- ✅ `database: '/opt/datos/biblio.gdb'` (ruta en servidor remoto)
- ✅ `database: 'C:\\Datos\\biblio.gdb'` (servidor Windows)
- ❌ `database: '/home/mvillalba/biblio.gdb'` (ruta local - incorrecto)

---

## ✅ **Checklist Pre-Conexión Firebird 2.5.7**

- [ ] Driver fdb instalado (`pip3 install --break-system-packages fdb`)
- [ ] IP/hostname del servidor Firebird conocida
- [ ] Puerto 3050 accesible (probar con telnet)
- [ ] Ruta completa del archivo .gdb en servidor
- [ ] Usuario/password válidos (generalmente SYSDBA)
- [ ] Charset determinado (WIN1252, ISO8859_1, o UTF8)
- [ ] Probado con `./test_firebird_remoto.py`

---

**¡Sistema listo para Firebird 2.5.7 con archivos .GDB! 🔥**

Universidad Nacional de Asunción - 2025
