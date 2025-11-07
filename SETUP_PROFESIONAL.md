# 🎓 SETUP PROFESIONAL: SINCRONIZACIÓN SEGURA SIN CSV

**Universidad Nacional de Asunción**
**Guía Paso a Paso - Profesional y Didáctica**

---

## 📋 **Introducción**

Esta guía te llevará desde cero hasta tener un sistema de sincronización automática, segura y sin archivos CSV intermedios entre tus servidores Firebird y Koha.

### **¿Qué vamos a lograr?**

```
ANTES (CSV Manual):
  Firebird → Exportar CSV → Copiar archivo → Importar CSV → Koha
  ⏱️  Tiempo: 30-60 minutos
  👤 Requiere: Intervención manual
  📁 Archivos: CSV en disco

DESPUÉS (SSH Automático):
  Firebird ←──[Túnel SSH Encriptado]──→ Koha (Directo a BD)
  ⏱️  Tiempo: 2-5 minutos
  👤 Requiere: Cero intervención
  📁 Archivos: Sin CSV (memoria)
  🔒 Seguridad: Máxima (AES-256)
```

### **Requisitos Previos**

✅ Acceso SSH al servidor Firebird remoto
✅ Usuario con privilegios (para configurar SSH)
✅ Datos de conexión Firebird (IP, ruta .gdb, usuario/password)
✅ 30-45 minutos para setup inicial

---

## 🗺️ **MAPA DEL PROCESO (Vista General)**

```
┌─────────────────────────────────────────────────────────────────┐
│                      PROCESO COMPLETO                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  FASE 1: Preparación del Entorno                               │
│  └─ Verificar sistema y dependencias                           │
│                                                                 │
│  FASE 2: Configuración SSH Segura                              │
│  └─ Generar claves SSH 4096 bits                               │
│  └─ Distribuir claves a servidores                             │
│  └─ Configurar archivo ~/.ssh/config                           │
│                                                                 │
│  FASE 3: Prueba de Conectividad                                │
│  └─ Probar SSH sin password                                    │
│  └─ Probar conexión Firebird remoto                            │
│  └─ Verificar estructura de BD                                 │
│                                                                 │
│  FASE 4: Configuración de Scripts                              │
│  └─ Configurar tunel_firebird.sh                               │
│  └─ Configurar firebird_directo_koha.py                        │
│  └─ Adaptar queries SQL a tu BD                                │
│                                                                 │
│  FASE 5: Primera Sincronización                                │
│  └─ Crear túnel SSH                                            │
│  └─ Sincronizar datos de prueba                                │
│  └─ Verificar importación en Koha                              │
│                                                                 │
│  FASE 6: Automatización                                        │
│  └─ Configurar cron para sincronización periódica              │
│  └─ Configurar logs y monitoreo                                │
│  └─ Documentar proceso                                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📊 **FASE 1: PREPARACIÓN DEL ENTORNO**

### **Objetivo**: Verificar que todo está listo antes de empezar

### **Paso 1.1: Verificar Sistema Actual**

```bash
# Verificar que estamos en el directorio correcto
pwd
# Debe mostrar: /home/mvillalba/migradatos

# Verificar archivos necesarios
ls -lh firebird_directo_koha.py tunel_firebird.sh test_firebird_remoto.py
```

**Salida esperada**: Todos los archivos deben existir y ser ejecutables (x)

### **Paso 1.2: Verificar Driver FDB**

```bash
# Verificar que fdb está instalado
python3 -c "import fdb; print(f'✓ fdb {fdb.__version__} instalado correctamente')"
```

**Salida esperada**: `✓ fdb 2.0.4 instalado correctamente`

Si falla, instalar:
```bash
pip3 install --break-system-packages fdb
```

### **Paso 1.3: Verificar Conectividad de Red**

Necesito los datos de tu servidor Firebird:

```
┌─────────────────────────────────────────────────────────────────┐
│  INFORMACIÓN REQUERIDA DEL SERVIDOR FIREBIRD                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. Dirección IP o hostname: _______________________________   │
│                                                                 │
│  2. Puerto SSH (generalmente 22): ________                     │
│                                                                 │
│  3. Usuario SSH: __________________________________________    │
│                                                                 │
│  4. Ruta del archivo .gdb: _________________________________   │
│     Ejemplo: /datos/biblioteca.gdb                             │
│                                                                 │
│  5. Usuario Firebird: ______________________________________   │
│     Ejemplo: SYSDBA                                            │
│                                                                 │
│  6. Password Firebird: _____________________________________   │
│                                                                 │
│  7. Código de biblioteca (3-8 letras): ____________________   │
│     Ejemplo: FACAGR, FACMED, etc.                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

Una vez que tengas estos datos, probamos conectividad básica:

```bash
# Reemplaza 192.168.1.100 con tu IP
ping -c 3 192.168.1.100
```

**Salida esperada**: Respuestas exitosas (0% packet loss)

### **Paso 1.4: Crear Estructura de Directorios**

```bash
# Crear directorios para organización profesional
mkdir -p ~/.ssh/backup
mkdir -p logs/ssh
mkdir -p .firebird_sync

# Verificar
ls -la ~/.ssh
ls -la logs/
```

**✅ CHECKLIST FASE 1**:
- [ ] En directorio correcto (`/home/mvillalba/migradatos`)
- [ ] Driver fdb instalado y funcional
- [ ] Datos del servidor Firebird recopilados
- [ ] Conectividad de red verificada
- [ ] Directorios creados

---

## 🔐 **FASE 2: CONFIGURACIÓN SSH SEGURA**

### **Objetivo**: Establecer autenticación SSH con claves (sin passwords)

### **Conceptos Clave** 📚

```
┌─────────────────────────────────────────────────────────────────┐
│  ¿QUÉ ES UNA CLAVE SSH?                                         │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Par de archivos criptográficos:                               │
│                                                                 │
│  • CLAVE PRIVADA (id_rsa):                                      │
│    - Se queda en TU servidor (Koha)                            │
│    - NUNCA compartir                                            │
│    - Como tu llave de casa                                      │
│                                                                 │
│  • CLAVE PÚBLICA (id_rsa.pub):                                  │
│    - Se copia al servidor remoto (Firebird)                    │
│    - Seguro compartir                                           │
│    - Como la cerradura de la puerta                            │
│                                                                 │
│  Ventajas:                                                      │
│  ✅ Sin passwords (más seguro)                                  │
│  ✅ Imposible de adivinar                                       │
│  ✅ 4096 bits = 2^4096 combinaciones posibles                   │
│  ✅ Automatización segura                                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### **Paso 2.1: Backup de Configuración SSH Actual (Seguridad)**

```bash
# Siempre backup antes de modificar
date=$(date +%Y%m%d_%H%M%S)

# Backup de claves existentes (si existen)
if [ -d ~/.ssh ]; then
    cp -r ~/.ssh ~/.ssh/backup_${date}
    echo "✓ Backup creado en: ~/.ssh/backup_${date}"
else
    mkdir -p ~/.ssh
    echo "✓ Directorio .ssh creado"
fi
```

### **Paso 2.2: Generar Par de Claves SSH (4096 bits)**

```bash
# Generar clave RSA de 4096 bits (máxima seguridad)
ssh-keygen -t rsa -b 4096 \
  -C "koha-firebird-sync@una.edu.py" \
  -f ~/.ssh/koha_firebird_sync
```

**Preguntas Interactivas**:

```
Enter passphrase (empty for no passphrase):
```

**Opciones**:

**A) Sin passphrase** (más simple, para empezar):
- Presiona Enter (vacío)
- Ventaja: Scripts automáticos sin intervención
- Desventaja: Si alguien roba el archivo, puede usarlo

**B) Con passphrase** (más seguro, recomendado):
- Escribe una frase fuerte: `Mi-K0ha-UNA-2025!Segur0`
- Ventaja: Doble protección
- Desventaja: Hay que ingresarla (pero se puede usar ssh-agent)

**Recomendación**: Empezar sin passphrase para aprender, luego regenerar con passphrase.

```
Enter passphrase: [PRESIONA ENTER para vacío]
Enter same passphrase again: [PRESIONA ENTER]
```

**Salida esperada**:
```
Your identification has been saved in /home/mvillalba/.ssh/koha_firebird_sync
Your public key has been saved in /home/mvillalba/.ssh/koha_firebird_sync.pub
The key fingerprint is:
SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx koha-firebird-sync@una.edu.py
The key's randomart image is:
+---[RSA 4096]----+
|                 |
|   . .           |
|  . o            |
[... arte ASCII ...]
+----[SHA256]-----+
```

### **Paso 2.3: Verificar Claves Generadas**

```bash
# Ver claves creadas
ls -lh ~/.ssh/koha_firebird_sync*

# Ver permisos (deben ser restrictivos)
ls -l ~/.ssh/koha_firebird_sync
# Debe mostrar: -rw------- (600) - solo tu usuario puede leer

# Ver contenido de clave PÚBLICA (seguro mostrar)
cat ~/.ssh/koha_firebird_sync.pub
```

**Salida esperada**: Una línea larga que empieza con `ssh-rsa AAAAB3Nza...`

### **Paso 2.4: Copiar Clave Pública al Servidor Firebird**

**IMPORTANTE**: Necesito los datos que recopilaste en Fase 1:
- IP del servidor Firebird: `__________`
- Usuario SSH: `__________`
- Puerto SSH: `__________` (generalmente 22)

```bash
# Reemplaza con TUS datos:
#   usuario   → tu usuario SSH
#   192.168.1.100 → IP de tu servidor Firebird

ssh-copy-id -i ~/.ssh/koha_firebird_sync.pub \
  -p 22 \
  usuario@192.168.1.100
```

**Te pedirá**: Password SSH del servidor Firebird (ÚLTIMA VEZ que usas password)

**Salida esperada**:
```
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s)
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed
usuario@192.168.1.100's password: [INGRESA PASSWORD]

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh -p '22' 'usuario@192.168.1.100'"
and check to make sure that only the key(s) you wanted were added.
```

### **Paso 2.5: Probar Conexión SSH sin Password**

```bash
# Probar conexión (NO debe pedir password)
ssh -i ~/.ssh/koha_firebird_sync \
  -p 22 \
  usuario@192.168.1.100 \
  'echo "✓ Conexión SSH exitosa sin password"'
```

**Salida esperada**: `✓ Conexión SSH exitosa sin password` (sin pedir password)

Si pide password, algo falló. Revisar:
1. ¿La clave pública se copió correctamente?
2. ¿Los permisos de ~/.ssh son correctos en ambos servidores?

### **Paso 2.6: Configurar ~/.ssh/config (Profesional)**

```bash
# Crear/editar archivo de configuración SSH
nano ~/.ssh/config
```

**Contenido** (reemplaza con TUS datos):

```
# ============================================================================
# CONFIGURACIÓN SSH - SERVIDORES FIREBIRD
# Universidad Nacional de Asunción - Sistema Koha
# ============================================================================

# Configuración global
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    ConnectTimeout 10

# ============================================================================
# SERVIDOR FIREBIRD 1 - [NOMBRE DE TU BIBLIOTECA]
# ============================================================================
Host firebird-1
    HostName 192.168.1.100           # ← TU IP
    User usuario                      # ← TU USUARIO SSH
    Port 22
    IdentityFile ~/.ssh/koha_firebird_sync
    StrictHostKeyChecking accept-new
    LogLevel INFO

# ============================================================================
# SERVIDOR FIREBIRD 2 - [OTRA BIBLIOTECA] (si tienes más)
# ============================================================================
# Host firebird-2
#     HostName 192.168.1.101
#     User admin
#     Port 22
#     IdentityFile ~/.ssh/koha_firebird_sync
#     StrictHostKeyChecking accept-new
#     LogLevel INFO

# Agregar más servidores aquí según necesites...
```

**Guardar**: Ctrl+O, Enter, Ctrl+X

**Configurar permisos**:
```bash
chmod 600 ~/.ssh/config
```

### **Paso 2.7: Probar Configuración Simplificada**

Ahora con el alias configurado:

```bash
# Conectar usando alias (mucho más simple)
ssh firebird-1 'hostname && echo "✓ Alias SSH funcionando"'
```

**Salida esperada**: Nombre del servidor remoto + mensaje de éxito

**✅ CHECKLIST FASE 2**:
- [ ] Par de claves SSH generado (4096 bits)
- [ ] Clave pública copiada a servidor Firebird
- [ ] Conexión SSH sin password funciona
- [ ] Archivo ~/.ssh/config configurado
- [ ] Alias SSH probado y funcional

---

## 🔍 **FASE 3: PRUEBA DE CONECTIVIDAD FIREBIRD**

### **Objetivo**: Verificar que podemos conectar a la base de datos Firebird

### **Paso 3.1: Probar Conexión Firebird Interactivamente**

```bash
# Script interactivo de prueba
./test_firebird_remoto.py
```

**Te pedirá**:

```
Host del servidor Firebird: localhost
  ↑ IMPORTANTE: Escribe "localhost" (vamos a usar túnel)

Puerto (Enter para 3050): 3050
  ↑ Presiona Enter (usar default)

Ruta de la base de datos: /datos/biblioteca.gdb
  ↑ TU RUTA REAL del archivo .gdb

Usuario (Enter para SYSDBA): SYSDBA
  ↑ O tu usuario Firebird

Password: [tu_password_firebird]
  ↑ No se verá al escribir (normal)

Charset (Enter para UTF8): WIN1252
  ↑ Para Firebird 2.5.7 usar WIN1252
```

**PERO ANTES**: Necesitamos crear el túnel SSH primero.

### **Paso 3.2: Crear Túnel SSH Manual (Primera Vez)**

```bash
# Crear túnel SSH manualmente para entender el proceso
# Reemplaza 'firebird-1' con tu alias configurado

ssh -f -N \
  -L 3050:localhost:3050 \
  firebird-1

# Explicación:
#   -f: ejecutar en background
#   -N: no ejecutar comandos, solo túnel
#   -L 3050:localhost:3050: puerto local 3050 → remoto 3050
#   firebird-1: alias configurado en ~/.ssh/config
```

**Sin salida** significa éxito. Verificar:

```bash
# Verificar que túnel está activo
lsof -i :3050

# Debe mostrar algo como:
# ssh    12345  mvillalba   3u  IPv4  ...  localhost:3050 (LISTEN)
```

### **Paso 3.3: Ahora Sí, Probar Firebird**

```bash
./test_firebird_remoto.py
```

Con el túnel activo, ingresar:
- **Host**: `localhost` (importante)
- **Puerto**: `3050`
- **BD**: Tu ruta real `/datos/biblioteca.gdb`
- **Usuario**: `SYSDBA` (o tu usuario)
- **Password**: Tu password Firebird
- **Charset**: `WIN1252` (para FB 2.5.7)

**Salida esperada**:
```
✓ Módulo fdb instalado (versión 2.0.4)
✓ CONEXIÓN EXITOSA

──────────────────────────────────────────────────────────
INFORMACIÓN DEL SERVIDOR FIREBIRD
──────────────────────────────────────────────────────────

  Versión Firebird:  2.5.7
  Base de datos:     /datos/biblioteca.gdb
  Total de tablas:   15

──────────────────────────────────────────────────────────
TABLAS EN LA BASE DE DATOS
──────────────────────────────────────────────────────────

  Encontradas 15 tablas:

    1. BIBLIOGRAFICOS                          1,234 registros
    2. EJEMPLARES                              2,345 registros
    3. USUARIOS                                  567 registros
    [...]

Tablas que podrían contener datos bibliográficos:
  → BIBLIOGRAFICOS
  → EJEMPLARES

✓ Información guardada en: config_firebird_localhost.txt
```

### **Paso 3.4: Revisar Estructura de Tablas**

El script anterior guardó info en `config_firebird_localhost.txt`:

```bash
cat config_firebird_localhost.txt
```

**Identificar**:
1. ¿Qué tabla tiene los registros bibliográficos? (ej: BIBLIOGRAFICOS)
2. ¿Qué tabla tiene los ejemplares? (ej: EJEMPLARES)
3. ¿Nombres de columnas importantes? (ID, TITULO, AUTOR, etc.)

### **Paso 3.5: Cerrar Túnel (Limpieza)**

```bash
# Encontrar PID del túnel
PID=$(lsof -ti:3050)

# Cerrar túnel
kill $PID

# Verificar que cerró
lsof -i :3050
# No debe mostrar nada
```

**✅ CHECKLIST FASE 3**:
- [ ] Túnel SSH creado manualmente
- [ ] Conexión a Firebird exitosa
- [ ] Listado de tablas obtenido
- [ ] Tablas bibliográficas identificadas
- [ ] Archivo config guardado para referencia
- [ ] Túnel cerrado limpiamente

---

## ⚙️ **FASE 4: CONFIGURACIÓN DE SCRIPTS**

### **Objetivo**: Configurar scripts de sincronización con TUS datos reales

### **Paso 4.1: Configurar tunel_firebird.sh**

```bash
# Editar script de túnel
nano tunel_firebird.sh
```

**Buscar la sección** (línea ~35):

```bash
case "$SERVIDOR_CODIGO" in
```

**Reemplazar el ejemplo** con TUS datos reales:

```bash
case "$SERVIDOR_CODIGO" in
    TU_CODIGO)                         # ← Código de tu biblioteca (ej: FACAGR)
        SSH_HOST="firebird-1"          # ← Alias de ~/.ssh/config
        SSH_USER="usuario"             # ← Tu usuario SSH
        SSH_PORT="22"
        FIREBIRD_PORT="3050"
        LOCAL_PORT="3050"
        DESCRIPCION="Tu Biblioteca"    # ← Nombre descriptivo
        ;;

    # Agregar más bibliotecas aquí si necesitas
    # OTRA_BIBLIO)
    #     SSH_HOST="firebird-2"
    #     SSH_USER="admin"
    #     SSH_PORT="22"
    #     FIREBIRD_PORT="3050"
    #     LOCAL_PORT="3051"  # Puerto local diferente
    #     DESCRIPCION="Otra Biblioteca"
    #     ;;

    *)
        echo "✗ Servidor desconocido: $SERVIDOR_CODIGO"
        echo ""
        echo "Servidores configurados:"
        echo "  TU_CODIGO"               # ← Listar códigos configurados
        echo ""
        exit 1
        ;;
esac
```

**Guardar**: Ctrl+O, Enter, Ctrl+X

### **Paso 4.2: Probar Script de Túnel**

```bash
# Probar con tu código configurado
./tunel_firebird.sh TU_CODIGO
```

**Salida esperada**:
```
════════════════════════════════════════════════════════════
TÚNEL SSH A FIREBIRD
════════════════════════════════════════════════════════════

Servidor:      Tu Biblioteca (TU_CODIGO)
SSH:           usuario@firebird-1:22
Firebird:      localhost:3050 → remoto:3050

✓ Conectividad SSH OK
✓ Túnel SSH creado exitosamente (PID: 12345)

════════════════════════════════════════════════════════════
TÚNEL ACTIVO
════════════════════════════════════════════════════════════

Conecta a Firebird en:
  Host:   localhost
  Puerto: 3050

Para cerrar el túnel:
  kill 12345
  # O usar: ./cerrar_tunel.sh 3050
```

**Dejar el túnel activo** para siguiente paso.

### **Paso 4.3: Configurar firebird_directo_koha.py**

```bash
# Editar script principal
nano firebird_directo_koha.py
```

**Buscar línea 84** (sección `FIREBIRD_SERVERS`):

**Reemplazar** con TUS datos:

```python
FIREBIRD_SERVERS = {
    'TU_CODIGO': {                      # ← Mismo código que en tunel_firebird.sh
        'nombre': 'Tu Biblioteca',
        'host': 'localhost',            # ← localhost (usa túnel)
        'port': 3050,
        'database': '/datos/biblioteca.gdb',  # ← TU RUTA REAL
        'user': 'SYSDBA',               # ← Tu usuario Firebird
        'password': 'tu_password',      # ← Tu password Firebird
        'charset': 'WIN1252',           # ← WIN1252 para Firebird 2.5.7
        'activo': True,                 # ← True para activar
    },

    # Agregar más servidores si necesitas
    # 'OTRA_BIBLIO': {
    #     'nombre': 'Otra Biblioteca',
    #     'host': 'localhost',
    #     'port': 3051,  # Puerto local diferente si es simultáneo
    #     'database': '/opt/firebird/otra.gdb',
    #     'user': 'SYSDBA',
    #     'password': 'otro_password',
    #     'charset': 'WIN1252',
    #     'activo': True,
    # },
}
```

**NO GUARDAR TODAVÍA** - Falta adaptar el query SQL.

---

## 📝 **CONTINUACIÓN EN SIGUIENTE MENSAJE**

La configuración es extensa para mantenerla profesional y didáctica. Vamos bien:

✅ Fase 1: Preparación - LISTA
✅ Fase 2: SSH Seguro - LISTA
✅ Fase 3: Prueba Firebird - LISTA
🔄 Fase 4: Configuración Scripts - EN PROGRESO

**¿Tienes ya los datos de tu servidor Firebird para que continúe con la configuración específica?**

Necesito:
1. IP o hostname del servidor Firebird
2. Ruta del archivo .gdb
3. Usuario y password Firebird
4. Código que quieres usar (ej: FACAGR, BIBLIO1, etc.)