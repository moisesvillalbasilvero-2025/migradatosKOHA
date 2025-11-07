# 🎓 GUÍA PASO A PASO: SINCRONIZACIÓN AUTOMÁTICA SIN CSV

**Universidad Nacional de Asunción**
**Guía Didáctica Detallada - Del Punto A al Punto Z**

---

## 🎯 **¿QUÉ VAS A LOGRAR?**

Al final de esta guía tendrás:

✅ **Conexión segura** entre Koha y Firebird (encriptada SSH)
✅ **Sincronización automática** sin tocar archivos CSV
✅ **Un comando simple** para importar miles de registros
✅ **Sistema profesional** listo para producción

**Tiempo estimado**: 45-60 minutos (la primera vez)

---

## 📚 **ANTES DE EMPEZAR**

### **¿Qué necesitas tener a mano?**

📋 **Información del servidor Firebird:**
- [ ] Dirección IP (ejemplo: `192.168.1.100`)
- [ ] Usuario para conectar por SSH (ejemplo: `biblioteca`)
- [ ] Password SSH (lo usarás UNA sola vez)
- [ ] Ruta del archivo .gdb (ejemplo: `/datos/biblioteca.gdb`)
- [ ] Usuario Firebird (generalmente `SYSDBA`)
- [ ] Password de Firebird

📋 **En tu servidor Koha (donde estás ahora):**
- [ ] Acceso al terminal (ya lo tienes)
- [ ] Permisos para ejecutar comandos
- [ ] 45-60 minutos de tiempo sin interrupciones

### **¿Qué es lo que NO necesitas?**

❌ NO necesitas saber programación
❌ NO necesitas entender SSH a fondo
❌ NO necesitas modificar Firebird
❌ NO necesitas cambiar tu método CSV actual

---

## 🗺️ **MAPA DEL VIAJE**

```
INICIO
  ↓
┌─────────────────────┐
│ PASO 1 (5 min)      │  Verificar que todo esté listo
│ Preparación         │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│ PASO 2 (10 min)     │  Crear "llave digital" SSH
│ Configurar SSH      │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│ PASO 3 (10 min)     │  Probar que llegas a Firebird
│ Probar Conexión     │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│ PASO 4 (15 min)     │  Configurar tus datos reales
│ Configurar Scripts  │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│ PASO 5 (10 min)     │  Importar primeros registros
│ Primera Importación │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│ PASO 6 (5 min)      │  Programar automático
│ Automatizar         │
└──────────┬──────────┘
           ↓
       ¡LISTO! 🎉
```

---

## 📍 **PASO 1: PREPARACIÓN (5 minutos)**

### **¿Qué vamos a hacer?**
Verificar que tienes todo instalado y que estás en el lugar correcto.

### **1.1 - Verificar ubicación**

```bash
# ¿Dónde estás?
pwd
```

**✅ Debe mostrar**: `/home/mvillalba/migradatos`

**❌ Si no estás ahí**:
```bash
cd /home/mvillalba/migradatos
```

### **1.2 - Verificar archivos del sistema**

```bash
# Ver archivos principales
ls -lh firebird_directo_koha.py tunel_firebird.sh test_firebird_remoto.py
```

**✅ Debe mostrar** algo como:
```
-rwxr-xr-x 1 mvillalba mvillalba  24K fecha firebird_directo_koha.py
-rwxr-xr-x 1 mvillalba mvillalba 8.5K fecha tunel_firebird.sh
-rwxr-xr-x 1 mvillalba mvillalba  10K fecha test_firebird_remoto.py
```

**❌ Si algún archivo no existe**: Algo salió mal en la creación.

### **1.3 - Verificar driver Firebird**

```bash
# ¿Está instalado el driver?
python3 -c "import fdb; print('✓ Driver fdb versión:', fdb.__version__)"
```

**✅ Debe mostrar**: `✓ Driver fdb versión: 2.0.4`

**❌ Si sale error**: Instalar con:
```bash
pip3 install --break-system-packages fdb
```

### **1.4 - Probar conectividad básica a Firebird**

**IMPORTANTE**: Necesitas la IP de tu servidor Firebird.

```bash
# Reemplaza 192.168.1.100 con TU IP real
ping -c 3 192.168.1.100
```

**✅ Debe mostrar**:
```
3 packets transmitted, 3 received, 0% packet loss
```

**❌ Si sale error**:
- Verifica la IP
- Verifica que el servidor esté encendido
- Verifica que haya red entre servidores

### **📋 CHECKLIST PASO 1**
- [ ] Estoy en `/home/mvillalba/migradatos`
- [ ] Los 3 archivos principales existen
- [ ] Driver fdb instalado (versión 2.0.4)
- [ ] Ping al servidor Firebird funciona

---

## 🔐 **PASO 2: CONFIGURAR SSH (10 minutos)**

### **¿Qué vamos a hacer?**
Crear una "llave digital" para conectar sin passwords.

### **💡 CONCEPTO: ¿Qué es SSH?**

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  SSH = Secure Shell (Cáscara Segura)                   │
│                                                         │
│  Imagina que es como una "llamada telefónica           │
│  encriptada" entre dos computadoras.                   │
│                                                         │
│  Tu Koha ←─[túnel encriptado]─→ Servidor Firebird     │
│                                                         │
│  TODO lo que viaja por ese túnel está encriptado.     │
│  Nadie puede "escuchar" la conversación.               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### **💡 CONCEPTO: Claves SSH**

```
┌─────────────────────────────────────────────────────────┐
│  CLAVE PRIVADA (tu_clave)                               │
│  • Se queda en TU servidor (Koha)                      │
│  • NUNCA la compartes                                   │
│  • Es como la llave de tu casa                         │
│                                                         │
│  CLAVE PÚBLICA (tu_clave.pub)                          │
│  • Se copia al servidor Firebird                       │
│  • Segura para compartir                               │
│  • Es como la cerradura de la puerta                   │
│                                                         │
│  Solo con AMBAS puede abrirse la conexión              │
└─────────────────────────────────────────────────────────┘
```

### **2.1 - Crear directorio SSH (si no existe)**

```bash
# Crear directorio para claves SSH
mkdir -p ~/.ssh

# Configurar permisos correctos
chmod 700 ~/.ssh

# Verificar
ls -ld ~/.ssh
```

**✅ Debe mostrar**: `drwx------ ... .ssh`

### **2.2 - Generar par de claves**

```bash
# Generar clave RSA de 4096 bits
ssh-keygen -t rsa -b 4096 \
  -C "koha-sync@una.edu.py" \
  -f ~/.ssh/koha_firebird_sync
```

**Te preguntará**:

```
Enter passphrase (empty for no passphrase):
```

**¿Qué es passphrase?** Una contraseña adicional para tu clave.

**Para empezar (más fácil)**: Presiona `Enter` (vacío)
**Para más seguridad**: Escribe una frase como `MiKoha2025Segura!`

```
Enter passphrase: [PRESIONA ENTER]
Enter same passphrase again: [PRESIONA ENTER]
```

**✅ Debe mostrar**:
```
Your identification has been saved in /home/mvillalba/.ssh/koha_firebird_sync
Your public key has been saved in /home/mvillalba/.ssh/koha_firebird_sync.pub
The key fingerprint is:
SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx koha-sync@una.edu.py
```

### **2.3 - Verificar claves creadas**

```bash
# Ver las dos claves
ls -lh ~/.ssh/koha_firebird_sync*
```

**✅ Debe mostrar**:
```
-rw-------  koha_firebird_sync       (privada - solo tú)
-rw-r--r--  koha_firebird_sync.pub   (pública - compartible)
```

### **2.4 - Copiar clave al servidor Firebird**

**IMPORTANTE**: Necesitas estos datos de tu servidor Firebird:
- IP: `_____________`
- Usuario SSH: `_____________`

```bash
# Reemplaza:
#   usuario     → tu usuario SSH real
#   192.168.1.100 → tu IP real

ssh-copy-id -i ~/.ssh/koha_firebird_sync.pub usuario@192.168.1.100
```

**Te pedirá**: El **password SSH** del servidor (ÚLTIMA VEZ)

```
usuario@192.168.1.100's password: [ESCRIBE PASSWORD SSH]
```

**✅ Debe mostrar**:
```
Number of key(s) added: 1

Now try logging into the machine...
```

### **2.5 - Probar conexión sin password**

```bash
# Reemplaza con tus datos reales
ssh -i ~/.ssh/koha_firebird_sync usuario@192.168.1.100 'echo "✓ SSH funciona sin password"'
```

**✅ Debe mostrar**: `✓ SSH funciona sin password` (SIN pedir password)

**❌ Si pide password**: Algo falló. Verifica:
1. ¿La clave se copió correctamente?
2. ¿Los permisos son correctos?

### **2.6 - Crear archivo de configuración SSH**

Esto hace tu vida MÁS FÁCIL.

```bash
# Crear/editar configuración
nano ~/.ssh/config
```

**Copia y pega esto** (reemplaza con TUS datos):

```
# ============================================================================
# Servidor Firebird - Biblioteca
# ============================================================================
Host mi-firebird
    HostName 192.168.1.100           # ← TU IP
    User usuario                      # ← TU USUARIO
    Port 22
    IdentityFile ~/.ssh/koha_firebird_sync
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
```

**Guardar**: `Ctrl + O`, `Enter`, `Ctrl + X`

**Configurar permisos**:
```bash
chmod 600 ~/.ssh/config
```

### **2.7 - Probar con alias**

Ahora es súper fácil:

```bash
# Conectar usando alias
ssh mi-firebird 'hostname'
```

**✅ Debe mostrar**: El nombre del servidor remoto (sin pedir password)

### **📋 CHECKLIST PASO 2**
- [ ] Claves SSH generadas (privada y pública)
- [ ] Clave pública copiada a servidor Firebird
- [ ] Conexión SSH sin password funciona
- [ ] Archivo ~/.ssh/config creado
- [ ] Alias `mi-firebird` funciona

---

## 🧪 **PASO 3: PROBAR CONEXIÓN A FIREBIRD (10 minutos)**

### **¿Qué vamos a hacer?**
Verificar que podemos leer datos de tu base de datos Firebird.

### **💡 CONCEPTO: Túnel SSH**

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│  Tu Koha                        Servidor Firebird      │
│  ┌──────┐                       ┌──────┐              │
│  │Python│                       │.gdb  │              │
│  └───┬──┘                       └──▲───┘              │
│      │                             │                   │
│      │  Conecta a localhost:3050  │                   │
│      └─────────┐         ┌─────────┘                  │
│                │         │                             │
│        ┌───────▼─────────▼────────┐                   │
│        │   TÚNEL SSH (puerto 22)  │                   │
│        │   [TODO encriptado]      │                   │
│        └──────────────────────────┘                   │
│                                                         │
│  El túnel "reenvía" la conexión de forma segura        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### **3.1 - Crear túnel SSH manual (para entender)**

```bash
# Crear túnel en background
# Puerto local 3050 → Puerto remoto 3050
ssh -f -N -L 3050:localhost:3050 mi-firebird
```

**Explicación**:
- `-f`: Ejecutar en background (no bloquea terminal)
- `-N`: Solo túnel, no ejecutar comandos
- `-L 3050:localhost:3050`: Reenviar puerto
- `mi-firebird`: Tu alias SSH

**✅ Sin mensajes** = Éxito

### **3.2 - Verificar que túnel está activo**

```bash
# Ver procesos escuchando en puerto 3050
lsof -i :3050
```

**✅ Debe mostrar**:
```
COMMAND   PID      USER   FD   TYPE  DEVICE SIZE/OFF NODE NAME
ssh     12345  mvillalba    3u  IPv4  ...           TCP localhost:3050 (LISTEN)
```

### **3.3 - Probar conexión a Firebird**

Ahora usamos el script de prueba:

```bash
./test_firebird_remoto.py
```

**Te preguntará** (responde con ESTOS valores):

```
Host del servidor Firebird: localhost
  ↑ IMPORTANTE: "localhost" porque usamos túnel

Puerto (Enter para 3050): [PRESIONA ENTER]

Ruta de la base de datos: /datos/biblioteca.gdb
  ↑ TU RUTA REAL del .gdb

Usuario (Enter para SYSDBA): [PRESIONA ENTER o tu usuario]

Password: [TU PASSWORD FIREBIRD]
  ↑ No se ve al escribir (es normal)

Charset (Enter para UTF8): WIN1252
  ↑ Escribe "WIN1252" para Firebird 2.5.7
```

### **✅ SI TODO SALE BIEN**:

```
✓ Módulo fdb instalado (versión 2.0.4)

✓ CONEXIÓN EXITOSA

════════════════════════════════════════════════════════════
INFORMACIÓN DEL SERVIDOR FIREBIRD
════════════════════════════════════════════════════════════

  Versión Firebird:  2.5.7
  Base de datos:     /datos/biblioteca.gdb
  Total de tablas:   15

════════════════════════════════════════════════════════════
TABLAS EN LA BASE DE DATOS
════════════════════════════════════════════════════════════

  Encontradas 15 tablas:

    1. BIBLIOGRAFICOS                      1,234 registros
    2. EJEMPLARES                          2,456 registros
    3. AUTORES                              567 registros
    [...]

Tablas que podrían contener datos bibliográficos:
  → BIBLIOGRAFICOS
  → EJEMPLARES

✓ Información guardada en: config_firebird_localhost.txt
```

### **🎉 ¡EXCELENTE!**

Has logrado:
1. ✅ Crear túnel SSH encriptado
2. ✅ Conectar a Firebird remoto
3. ✅ Ver tus tablas y datos

### **3.4 - Revisar información guardada**

```bash
# Ver archivo de configuración generado
cat config_firebird_localhost.txt
```

**Anota**:
- ¿Cuál es la tabla principal? (ej: `BIBLIOGRAFICOS`)
- ¿Cuál es la tabla de ejemplares? (ej: `EJEMPLARES`)
- ¿Cuántos registros hay?

### **3.5 - Cerrar túnel (limpieza)**

```bash
# Encontrar proceso del túnel
PID=$(lsof -ti:3050)

# Cerrar túnel
kill $PID

# Verificar que cerró
lsof -i :3050
```

**✅ No debe mostrar nada** (túnel cerrado)

### **📋 CHECKLIST PASO 3**
- [ ] Túnel SSH creado correctamente
- [ ] Script test_firebird_remoto.py ejecutado
- [ ] Conexión exitosa a Firebird
- [ ] Listado de tablas obtenido
- [ ] Nombres de tablas anotados
- [ ] Túnel cerrado

---

## ⚙️ **PASO 4: CONFIGURAR SCRIPTS (15 minutos)**

### **¿Qué vamos a hacer?**
Poner TUS datos reales en los scripts para que funcionen con tu Firebird.

### **4.1 - Elegir código de biblioteca**

Elige un código corto para tu biblioteca (3-8 letras mayúsculas):

**Ejemplos**:
- FACAGR (Facultad Agrarias)
- FACMED (Facultad Medicina)
- BIBLIO1 (Biblioteca 1)
- CENTRAL (Biblioteca Central)

**Tu código será**: `______________` (anótalo)

### **4.2 - Configurar tunel_firebird.sh**

```bash
# Editar script de túneles
nano tunel_firebird.sh
```

**Busca la línea** (aproximadamente línea 36):

```bash
case "$SERVIDOR_CODIGO" in
```

**BORRA** la sección de ejemplo y pon esto:

```bash
case "$SERVIDOR_CODIGO" in
    TU_CODIGO)                         # ← Cambia "TU_CODIGO" por tu código real
        SSH_HOST="mi-firebird"         # ← Alias que creaste en ~/.ssh/config
        SSH_USER="usuario"             # ← Tu usuario SSH (debe coincidir con config)
        SSH_PORT="22"
        FIREBIRD_PORT="3050"
        LOCAL_PORT="3050"
        DESCRIPCION="Mi Biblioteca"    # ← Nombre descriptivo
        ;;

    *)
        echo "✗ Servidor desconocido: $SERVIDOR_CODIGO"
        echo ""
        echo "Servidores configurados:"
        echo "  TU_CODIGO"               # ← Tu código
        echo ""
        exit 1
        ;;
esac
```

**Ejemplo real**:
```bash
    FACAGR)
        SSH_HOST="mi-firebird"
        SSH_USER="biblioteca"
        SSH_PORT="22"
        FIREBIRD_PORT="3050"
        LOCAL_PORT="3050"
        DESCRIPCION="Facultad de Ciencias Agrarias"
        ;;
```

**Guardar**: `Ctrl + O`, `Enter`, `Ctrl + X`

### **4.3 - Probar script de túnel**

```bash
# Probar con tu código
./tunel_firebird.sh TU_CODIGO
```

**Reemplaza `TU_CODIGO` con tu código real**

**✅ Debe mostrar**:
```
════════════════════════════════════════════════════════════
TÚNEL SSH A FIREBIRD
════════════════════════════════════════════════════════════

Servidor:      Mi Biblioteca (TU_CODIGO)
SSH:           usuario@mi-firebird:22
Firebird:      localhost:3050 → remoto:3050

✓ Conectividad SSH OK

Creando túnel SSH...
✓ Túnel SSH creado exitosamente (PID: 12345)

════════════════════════════════════════════════════════════
TÚNEL ACTIVO
════════════════════════════════════════════════════════════

Conecta a Firebird en:
  Host:   localhost
  Puerto: 3050
```

**Deja el túnel ACTIVO** (no cierres) para el siguiente paso.

### **4.4 - Configurar firebird_directo_koha.py**

```bash
# Editar script principal
nano firebird_directo_koha.py
```

**Presiona `Ctrl + W` para buscar**, escribe: `FIREBIRD_SERVERS`

**Llegarás a la línea 84**, verás:

```python
FIREBIRD_SERVERS = {
```

**BORRA desde ahí hasta el `}` que cierra** (aproximadamente 30 líneas)

**Pon esto** (con TUS datos):

```python
FIREBIRD_SERVERS = {
    'TU_CODIGO': {                         # ← TU código (igual que en tunel_firebird.sh)
        'nombre': 'Mi Biblioteca',
        'host': 'localhost',                # ← localhost (usa túnel)
        'port': 3050,
        'database': '/datos/biblioteca.gdb',  # ← TU RUTA REAL del .gdb
        'user': 'SYSDBA',                   # ← Tu usuario Firebird
        'password': 'tu_password_firebird', # ← Tu password Firebird
        'charset': 'WIN1252',               # ← WIN1252 para Firebird 2.5.7
        'activo': True,
    },
}
```

**Ejemplo real**:
```python
FIREBIRD_SERVERS = {
    'FACAGR': {
        'nombre': 'Facultad de Ciencias Agrarias',
        'host': 'localhost',
        'port': 3050,
        'database': '/opt/firebird/data/facagr.gdb',
        'user': 'SYSDBA',
        'password': 'masterkey',
        'charset': 'WIN1252',
        'activo': True,
    },
}
```

**NO GUARDES TODAVÍA** - Falta adaptar el query SQL.

### **4.5 - Adaptar query SQL**

**Busca** (Ctrl + W): `def get_export_query`

**Llegarás aproximadamente a la línea 300**, verás:

```python
def get_export_query(only_modified_since=None):
    """Query SQL para extraer datos de Firebird"""
    query = """
        SELECT
```

**Este query debe adaptarse a TUS tablas**. Necesitas saber:
- ¿Cómo se llama tu tabla principal? (ej: BIBLIOGRAFICOS)
- ¿Qué columnas tiene? (ID, TITULO, AUTOR, etc.)

**Query de EJEMPLO** (adáptalo a tu BD):

```python
def get_export_query(only_modified_since=None):
    """Query SQL para extraer datos de Firebird"""

    # Query base - ADAPTAR a tus nombres de tablas y columnas
    query = """
        SELECT FIRST 10
            b.ID as analisis,
            b.TITULO as titulo,
            b.AUTOR as autor,
            b.EDITORIAL as editorial,
            b.ANO_PUBLICACION as ano,
            b.ISBN as isbn,
            e.CODIGO_BARRA as nroacceso,
            b.FECHA_ALTA as fecha_alta
        FROM BIBLIOGRAFICOS b
        LEFT JOIN EJEMPLARES e ON e.ID_BIBLIOGRAFICO = b.ID
        WHERE b.ID IS NOT NULL
        ORDER BY b.ID
    """

    return query, []
```

**NOTA**: `SELECT FIRST 10` limita a 10 registros para PRUEBA inicial.

**Guardar**: `Ctrl + O`, `Enter`, `Ctrl + X`

### **4.6 - Probar configuración**

```bash
# Con túnel ACTIVO, probar configuración
./firebird_directo_koha.py --test
```

**✅ Debe mostrar**:
```
════════════════════════════════════════════════════════════
PRUEBA DE CONEXIÓN A SERVIDORES FIREBIRD
════════════════════════════════════════════════════════════

Probando TU_CODIGO...
  ✓ Conexión exitosa
  ✓ Query SQL funciona
  ✓ Se obtuvieron 10 registros

════════════════════════════════════════════════════════════
RESUMEN
════════════════════════════════════════════════════════════

Total servidores: 1
Activos: 1
Exitosos: 1
Fallidos: 0

✓ Todos los servidores activos funcionan correctamente
```

### **📋 CHECKLIST PASO 4**
- [ ] Código de biblioteca elegido
- [ ] tunel_firebird.sh configurado con tu código
- [ ] Script de túnel probado y funciona
- [ ] firebird_directo_koha.py configurado con tus datos
- [ ] Query SQL adaptado a tus tablas
- [ ] Prueba con --test exitosa

---

## 🎯 **PASO 5: PRIMERA SINCRONIZACIÓN (10 minutos)**

### **¿Qué vamos a hacer?**
Importar tus primeros registros reales de Firebird a Koha.

### **5.1 - Verificar túnel activo**

```bash
# ¿Está el túnel activo?
lsof -i :3050
```

**Si NO está activo**:
```bash
./tunel_firebird.sh TU_CODIGO
```

### **5.2 - Ver estado antes de importar**

```bash
# Ver estado actual de sincronización
./firebird_directo_koha.py --status
```

**Primera vez mostrará**: Sin sincronizaciones previas

### **5.3 - Importar primeros 10 registros (PRUEBA)**

```bash
# Importar registros de prueba
./firebird_directo_koha.py --biblioteca TU_CODIGO
```

**Verás**:
```
════════════════════════════════════════════════════════════
SINCRONIZACIÓN FIREBIRD → KOHA
════════════════════════════════════════════════════════════

Biblioteca: Mi Biblioteca (TU_CODIGO)

──────────────────────────────────────────────────────────
FASE 1: Conexión a Firebird
──────────────────────────────────────────────────────────

✓ Conectado a: localhost:3050
✓ Base de datos: /datos/biblioteca.gdb

──────────────────────────────────────────────────────────
FASE 2: Extracción de datos
──────────────────────────────────────────────────────────

Ejecutando query SQL...
✓ 10 registros obtenidos

──────────────────────────────────────────────────────────
FASE 3: Generación de MARCXML
──────────────────────────────────────────────────────────

Convirtiendo a MARCXML...
✓ 10 registros convertidos

──────────────────────────────────────────────────────────
FASE 4: Importación a Koha
──────────────────────────────────────────────────────────

Importando a Koha...
✓ 10 registros importados

════════════════════════════════════════════════════════════
SINCRONIZACIÓN COMPLETADA
════════════════════════════════════════════════════════════

Registros procesados: 10
Tiempo total: 15 segundos
```

### **5.4 - Verificar en Koha**

```bash
# Ver últimos registros importados en Koha
sudo koha-mysql koha-cnc -e "
SELECT biblionumber, title, author
FROM biblio
ORDER BY biblionumber DESC
LIMIT 10;
"
```

**✅ Debes ver** tus 10 registros importados.

### **5.5 - Importar MÁS registros**

Si la prueba salió bien, importar más:

**Editar query para quitar límite**:
```bash
nano firebird_directo_koha.py
```

**Buscar**: `SELECT FIRST 10`

**Cambiar a**: `SELECT FIRST 100` (o sin límite: solo `SELECT`)

**Guardar y ejecutar**:
```bash
./firebird_directo_koha.py --biblioteca TU_CODIGO
```

### **5.6 - Ver estadísticas**

```bash
# Ver estado después de importar
./firebird_directo_koha.py --status
```

**Verás**:
```
════════════════════════════════════════════════════════════
ESTADO DE SINCRONIZACIÓN
════════════════════════════════════════════════════════════

TU_CODIGO - Mi Biblioteca
  Última sincronización: 2025-01-31 14:30:25
  Registros sincronizados: 100
  Estado: ✓ Exitosa
```

### **📋 CHECKLIST PASO 5**
- [ ] Túnel activo verificado
- [ ] Primera importación (10 registros) exitosa
- [ ] Registros verificados en Koha
- [ ] Importación completa exitosa
- [ ] Estado de sincronización verificado

---

## 🤖 **PASO 6: AUTOMATIZAR (5 minutos)**

### **¿Qué vamos a hacer?**
Programar sincronización automática diaria.

### **6.1 - Crear script wrapper**

```bash
# Crear script que hace todo automático
nano ~/sync_firebird_auto.sh
```

**Copiar esto**:

```bash
#!/bin/bash
# Script de sincronización automática
# Universidad Nacional de Asunción

set -euo pipefail

CODIGO_BIBLIOTECA="TU_CODIGO"  # ← TU CÓDIGO
DIR_TRABAJO="/home/mvillalba/migradatos"

cd "$DIR_TRABAJO"

echo "════════════════════════════════════════════════════════════"
echo "Sincronización automática - $(date)"
echo "════════════════════════════════════════════════════════════"

# 1. Crear túnel SSH
echo "Creando túnel SSH..."
./tunel_firebird.sh "$CODIGO_BIBLIOTECA"

# Esperar a que túnel esté listo
sleep 3

# 2. Sincronizar (solo cambios)
echo "Sincronizando..."
./firebird_directo_koha.py --biblioteca "$CODIGO_BIBLIOTECA" --incremental

# 3. Cerrar túnel
echo "Cerrando túnel..."
./cerrar_tunel.sh 3050

echo "✓ Sincronización completada"
```

**Guardar**: `Ctrl + O`, `Enter`, `Ctrl + X`

**Hacer ejecutable**:
```bash
chmod +x ~/sync_firebird_auto.sh
```

### **6.2 - Probar script automático**

```bash
# Ejecutar script completo
~/sync_firebird_auto.sh
```

**✅ Debe ejecutar**: túnel → sincronizar → cerrar túnel

### **6.3 - Configurar cron (automático diario)**

```bash
# Editar cron
crontab -e
```

**Agregar al final**:

```bash
# Sincronización automática Firebird → Koha
# Todos los días a las 2:00 AM
0 2 * * * /home/mvillalba/sync_firebird_auto.sh >> /home/mvillalba/migradatos/logs/sync_auto.log 2>&1
```

**Guardar**: `Ctrl + O`, `Enter`, `Ctrl + X`

### **6.4 - Verificar cron**

```bash
# Ver tareas programadas
crontab -l
```

**✅ Debe mostrar** tu línea de cron.

### **📋 CHECKLIST PASO 6**
- [ ] Script wrapper creado
- [ ] Script probado manualmente
- [ ] Cron configurado
- [ ] Tarea cron verificada

---

## 🎉 **¡FELICIDADES! LO LOGRASTE**

### **✅ ¿Qué has conseguido?**

```
┌─────────────────────────────────────────────────────────┐
│  ANTES                                                  │
├─────────────────────────────────────────────────────────┤
│  1. Exportar CSV manualmente en Firebird               │
│  2. Copiar archivo a Koha                              │
│  3. Importar CSV con scripts                           │
│  ⏱️  Tiempo: 30-60 minutos                             │
│  👤 Manual                                              │
└─────────────────────────────────────────────────────────┘

         ↓↓↓ TRANSFORMADO EN ↓↓↓

┌─────────────────────────────────────────────────────────┐
│  AHORA                                                  │
├─────────────────────────────────────────────────────────┤
│  1. Cron ejecuta automático cada noche                 │
│  2. O ejecutas: ~/sync_firebird_auto.sh               │
│  ⏱️  Tiempo: 2-5 minutos                               │
│  👤 Automático                                          │
│  🔒 Encriptado SSH                                      │
│  📁 Sin archivos CSV                                    │
└─────────────────────────────────────────────────────────┘
```

---

## 📚 **COMANDOS ÚTILES PARA EL DÍA A DÍA**

### **Sincronización Manual**

```bash
# Todo automático (túnel + sync + cerrar)
~/sync_firebird_auto.sh
```

### **Sincronización Paso a Paso**

```bash
# 1. Crear túnel
./tunel_firebird.sh TU_CODIGO

# 2. Sincronizar (solo cambios)
./firebird_directo_koha.py --biblioteca TU_CODIGO --incremental

# 3. Cerrar túnel
./cerrar_tunel.sh 3050
```

### **Ver Estado**

```bash
# Ver última sincronización
./firebird_directo_koha.py --status

# Ver logs
tail -f logs/sync_auto.log
```

### **Probar Conexión**

```bash
# Probar que todo funciona
./firebird_directo_koha.py --test
```

---

## 🆘 **¿ALGO SALIÓ MAL?**

### **Error: "No se puede conectar a Firebird"**

```bash
# 1. ¿Está el túnel activo?
lsof -i :3050

# Si no: Crear túnel
./tunel_firebird.sh TU_CODIGO

# 2. ¿SSH funciona?
ssh mi-firebird 'echo OK'

# Debe mostrar: OK
```

### **Error: "Permission denied"**

```bash
# Verificar permisos de claves SSH
ls -la ~/.ssh/koha_firebird_sync

# Debe ser: -rw------- (600)

# Corregir permisos
chmod 600 ~/.ssh/koha_firebird_sync
```

### **Error: "Cannot find module fdb"**

```bash
# Reinstalar driver
pip3 install --break-system-packages fdb
```

### **¿Necesitas ayuda?**

Ver logs:
```bash
ls -lht logs/ | head
tail -100 logs/sync_TU_CODIGO_*.log
```

---

## 📖 **DOCUMENTACIÓN ADICIONAL**

| Documento | Para Qué |
|-----------|----------|
| `GUIA_SEGURIDAD_CONEXION.md` | Detalles de seguridad SSH |
| `README_FIREBIRD_DIRECTO.md` | Referencia rápida |
| `FIREBIRD_25_GDB.md` | Específico Firebird 2.5.7 |
| `README_METODOS_IMPORTACION.md` | Comparación de métodos |

---

## ✅ **RESUMEN FINAL**

**Tu método CSV actual**: ✅ Sigue funcionando igual (no se toca)

**Método nuevo agregado**:
- ✅ Conexión SSH segura (encriptada)
- ✅ Sin archivos CSV intermedios
- ✅ Sincronización automática
- ✅ Modo incremental (solo cambios)
- ✅ Un comando simple

**Comando mágico**:
```bash
~/sync_firebird_auto.sh
```

**Automático diario**: Cron a las 2 AM

---

**¡SISTEMA LISTO PARA PRODUCCIÓN! 🚀**

**Universidad Nacional de Asunción - 2025**
