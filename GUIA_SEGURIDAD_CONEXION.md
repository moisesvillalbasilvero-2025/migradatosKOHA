# 🔒 GUÍA DE SEGURIDAD: CONEXIÓN A FIREBIRD

**Universidad Nacional de Asunción**
**Conexiones Seguras sin CSV**

---

## 🎯 **Resumen: Niveles de Seguridad**

| Método | Seguridad | Cuándo Usar |
|--------|-----------|-------------|
| **Conexión Directa TCP/IP** | ⭐⭐ Media | Red local confiable (LAN interna) |
| **Túnel SSH** | ⭐⭐⭐ Alta | Internet, máxima seguridad |
| **SSH + VPN** | ⭐⭐⭐⭐ Muy Alta | Datos críticos, compliance |

---

## 🔒 **MÉTODO RECOMENDADO: TÚNEL SSH (Alta Seguridad)**

### **¿Cómo Funciona?**

```
┌──────────────────────────────────────────────────────────────────┐
│                    TÚNEL SSH ENCRIPTADO                          │
├──────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Servidor Koha                     Servidor Firebird            │
│  ┌─────────────┐                   ┌─────────────┐             │
│  │   Python    │                   │  Firebird   │             │
│  │   Script    │                   │  Process    │             │
│  └──────┬──────┘                   └──────▲──────┘             │
│         │                                  │                     │
│         │ Conecta a                        │ Recibe en          │
│         │ localhost:3050                   │ localhost:3050     │
│         │                                  │                     │
│         ▼                                  │                     │
│  ┌─────────────────────────────────────────────────┐            │
│  │         TÚNEL SSH (Puerto 22)                   │            │
│  │         [Todo el tráfico encriptado]            │            │
│  │         AES-256, RSA-4096                       │            │
│  └─────────────────────────────────────────────────┘            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### **Seguridad Garantizada**

✅ **Encriptación de extremo a extremo**
- Todo el tráfico va por SSH (puerto 22)
- Encriptación AES-256 o ChaCha20
- Autenticación RSA-4096 bits

✅ **Sin puerto Firebird expuesto**
- Puerto 3050 NO necesita estar abierto a internet
- Solo puerto SSH (22) abierto
- Firebird solo escucha en localhost del servidor remoto

✅ **Autenticación fuerte**
- Clave SSH pública/privada (no passwords)
- Opcionalmente: passphrase en clave
- Opcionalmente: autenticación de dos factores (2FA)

✅ **Sin datos en disco**
- No se crean archivos CSV en ningún momento
- Datos viajan en memoria encriptada
- Solo se escriben en Koha DB (destino final)

---

## 🚀 **Implementación Paso a Paso (SSH Seguro)**

### **Paso 1: Generar Par de Claves SSH (Máxima Seguridad)**

```bash
# En tu servidor Koha (donde estás ahora)
cd ~/.ssh

# Generar clave RSA de 4096 bits con passphrase
ssh-keygen -t rsa -b 4096 -C "koha-sync@universidad.edu.py"

# Preguntas:
# Enter file in which to save the key: firebird_sync_rsa
# Enter passphrase: [IMPORTANTE: Usa passphrase fuerte]
# Enter same passphrase again: [Repetir]

# Esto genera:
#   ~/.ssh/firebird_sync_rsa       (clave privada - NUNCA compartir)
#   ~/.ssh/firebird_sync_rsa.pub   (clave pública - enviar a servidores)
```

**Recomendaciones de passphrase**:
- Mínimo 20 caracteres
- Mezcla de mayúsculas, minúsculas, números, símbolos
- Ejemplo: `Koha-F1r3b1rd$2025!UNA-Segur0`

### **Paso 2: Configurar Servidor Firebird (Solo SSH)**

```bash
# Copiar clave pública a cada servidor Firebird
ssh-copy-id -i ~/.ssh/firebird_sync_rsa.pub usuario@servidor-firebird-1
ssh-copy-id -i ~/.ssh/firebird_sync_rsa.pub usuario@servidor-firebird-2

# Configurar SSH para usar esta clave
nano ~/.ssh/config
```

Agregar configuración SSH:

```
# Servidor Firebird 1 - Facultad de Agrarias
Host firebird-facagr
    HostName 192.168.1.100
    User biblioteca
    Port 22
    IdentityFile ~/.ssh/firebird_sync_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes

# Servidor Firebird 2 - Facultad de Medicina
Host firebird-facmed
    HostName 192.168.1.101
    User admin
    Port 22
    IdentityFile ~/.ssh/firebird_sync_rsa
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes

# Agregar más servidores aquí...
```

### **Paso 3: Probar Conexión SSH Segura**

```bash
# Probar cada servidor
ssh firebird-facagr exit
# Te pedirá passphrase de tu clave (si configuraste)
# Debe conectar sin pedir password del servidor

ssh firebird-facmed exit
# Igual, solo passphrase local

# Verificar que NO pide password del servidor (solo passphrase de clave)
```

### **Paso 4: Configurar Túneles SSH Seguros**

Editar `tunel_firebird.sh` con tus servidores:

```bash
nano tunel_firebird.sh
```

Configurar:

```bash
case "$SERVIDOR_CODIGO" in
    FACAGR)
        SSH_HOST="firebird-facagr"    # Usa alias de ~/.ssh/config
        SSH_USER="biblioteca"         # Usuario SSH
        SSH_PORT="22"
        FIREBIRD_PORT="3050"
        LOCAL_PORT="3050"
        DESCRIPCION="Facultad de Ciencias Agrarias"
        ;;

    FACMED)
        SSH_HOST="firebird-facmed"
        SSH_USER="admin"
        SSH_PORT="22"
        FIREBIRD_PORT="3050"
        LOCAL_PORT="3051"  # Puerto local diferente
        DESCRIPCION="Facultad de Medicina"
        ;;
esac
```

### **Paso 5: Configurar firebird_directo_koha.py**

```bash
nano firebird_directo_koha.py
```

Configurar para usar localhost (el túnel):

```python
FIREBIRD_SERVERS = {
    'FACAGR': {
        'nombre': 'Facultad de Ciencias Agrarias',
        'host': 'localhost',           # ← localhost (túnel SSH)
        'port': 3050,                  # ← Puerto local del túnel
        'database': '/datos/biblio.gdb',
        'user': 'SYSDBA',
        'password': 'masterkey',       # Password Firebird (no SSH)
        'charset': 'WIN1252',
        'activo': True,
    },

    'FACMED': {
        'nombre': 'Facultad de Medicina',
        'host': 'localhost',
        'port': 3051,                  # ← Puerto local diferente
        'database': '/opt/firebird/medicina.gdb',
        'user': 'SYSDBA',
        'password': 'otra_password',
        'charset': 'WIN1252',
        'activo': True,
    },
}
```

### **Paso 6: Uso Seguro Completo**

```bash
# 1. Crear túnel SSH encriptado
./tunel_firebird.sh FACAGR
# Te pedirá passphrase de tu clave SSH

# Verás:
#   ✓ Conectividad SSH OK
#   ✓ Túnel SSH creado exitosamente (PID: 12345)
#   Conecta a Firebird en: localhost:3050

# 2. Sincronizar (sin CSV, todo encriptado)
./firebird_directo_koha.py --biblioteca FACAGR --incremental

# 3. Cerrar túnel
./cerrar_tunel.sh 3050
```

---

## 🔐 **Detalles de Seguridad del Túnel SSH**

### **Encriptación en Tránsito**

Cuando creas el túnel SSH, **TODO** el tráfico está encriptado:

```
Datos en Firebird → SSH encripta → Viaja por red → SSH desencripta → Python
     (servidor)      [AES-256]     [Seguro]      [AES-256]       (Koha)

❌ Nadie puede interceptar datos legibles
❌ No hay archivos CSV en disco
❌ No hay puerto 3050 expuesto
✅ Solo puerto 22 (SSH estándar y seguro)
```

### **Autenticación Multi-Factor (Opcional)**

Puedes agregar seguridad adicional:

```bash
# En servidor Firebird, configurar 2FA con Google Authenticator
sudo apt install libpam-google-authenticator

# Configurar SSH para requerir 2FA
sudo nano /etc/ssh/sshd_config

# Agregar:
ChallengeResponseAuthentication yes
AuthenticationMethods publickey,keyboard-interactive

# Reiniciar SSH
sudo systemctl restart sshd
```

Ahora para conectar necesitas:
1. Tu clave SSH privada ✅
2. Passphrase de la clave ✅
3. Código de Google Authenticator ✅

---

## 🛡️ **Medidas de Seguridad Adicionales**

### **1. Proteger Clave Privada SSH**

```bash
# Permisos correctos (crítico)
chmod 600 ~/.ssh/firebird_sync_rsa
chmod 644 ~/.ssh/firebird_sync_rsa.pub

# Solo tu usuario puede leer la clave privada
ls -la ~/.ssh/firebird_sync_rsa
# Debe mostrar: -rw------- (600)
```

### **2. Configurar Firewall en Servidor Firebird**

```bash
# En servidor Firebird, solo permitir SSH desde IP de Koha
sudo ufw allow from 192.168.1.50 to any port 22
sudo ufw enable

# Verificar
sudo ufw status
```

### **3. Deshabilitar Password SSH (Solo Claves)**

```bash
# En servidor Firebird
sudo nano /etc/ssh/sshd_config

# Cambiar:
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no

# Reiniciar
sudo systemctl restart sshd
```

Ahora es **imposible** conectar sin clave SSH.

### **4. Usar ssh-agent para Passphrase**

Para no escribir passphrase cada vez:

```bash
# Iniciar ssh-agent
eval $(ssh-agent)

# Agregar clave (pide passphrase UNA vez)
ssh-add ~/.ssh/firebird_sync_rsa

# Ahora túneles se crean sin pedir passphrase
./tunel_firebird.sh FACAGR
```

La passphrase queda en memoria encriptada, no en disco.

### **5. Logs de Auditoría**

Todos los accesos quedan registrados:

```bash
# En servidor Firebird, ver quién se conectó
sudo tail -f /var/log/auth.log | grep sshd

# En servidor Koha, logs de sincronización
tail -f logs/sync_FACAGR_*.log
```

---

## 📊 **Comparación de Seguridad**

### **Método CSV Actual (Tu Proceso)**

```
Firebird → Exportar CSV → Archivo en disco → Copiar (SCP/USB) → Importar
           [Sin encriptar]  [Visible]        [Puede interceptarse]

Riesgos:
⚠️  CSV puede contener datos sensibles
⚠️  Archivo puede copiarse/filtrarse
⚠️  Si SCP, password puede interceptarse
⚠️  CSV queda en múltiples lugares
```

### **Túnel SSH (Método Nuevo)**

```
Firebird → SSH encripta → Viaja encriptado → SSH desencripta → Koha DB
           [AES-256]       [Imposible leer]   [AES-256]        [Final]

Ventajas:
✅ Todo encriptado extremo a extremo
✅ Sin archivos intermedios
✅ Solo puerto 22 (estándar)
✅ Autenticación fuerte (claves SSH)
✅ Auditoría completa
✅ Datos solo en origen y destino
```

---

## 🎓 **Mejores Prácticas de Seguridad**

### **1. Rotación de Claves SSH**

```bash
# Cada 6-12 meses, generar nuevas claves
ssh-keygen -t rsa -b 4096 -C "koha-sync-2026@universidad.edu.py"

# Distribuir nueva clave pública
ssh-copy-id -i ~/.ssh/firebird_sync_rsa_2026.pub usuario@servidor

# Actualizar ~/.ssh/config
# Eliminar clave antigua después de verificar
```

### **2. Monitoreo de Accesos**

```bash
# Script de monitoreo (ejecutar diario)
#!/bin/bash
# monitor_ssh.sh

echo "Accesos SSH últimas 24 horas:"
ssh firebird-facagr "last -i -s yesterday | grep biblioteca"
ssh firebird-facmed "last -i -s yesterday | grep admin"

# Enviar por email si hay accesos sospechosos
```

### **3. Backup de Configuración Segura**

```bash
# Backup de configuración SSH (sin claves privadas)
tar czf ssh_config_backup_$(date +%Y%m%d).tar.gz \
    ~/.ssh/config \
    ~/.ssh/*.pub \
    --exclude='*_rsa' \
    --exclude='*_dsa'

# Guardar en ubicación segura
```

### **4. Política de Passwords Firebird**

Aunque SSH está encriptado, passwords de Firebird deben ser fuertes:

```python
# En firebird_directo_koha.py
FIREBIRD_SERVERS = {
    'FACAGR': {
        ...
        'password': 'Fb!2025$FACAGR-UNA-K0h4',  # ← Fuerte
        ...
    }
}

# Permisos del archivo (solo tu usuario puede leer)
chmod 600 firebird_directo_koha.py
```

### **5. Variables de Entorno para Passwords**

Mejor aún, no hardcodear passwords:

```bash
# Crear archivo .env
nano .env

# Contenido:
FACAGR_FB_PASSWORD=Fb!2025$FACAGR-UNA-K0h4
FACMED_FB_PASSWORD=Fb!2025$FACMED-UNA-K0h4

# Permisos restrictivos
chmod 600 .env
```

Modificar script para leer de .env:

```python
import os
from dotenv import load_dotenv

load_dotenv()

FIREBIRD_SERVERS = {
    'FACAGR': {
        ...
        'password': os.getenv('FACAGR_FB_PASSWORD'),
        ...
    }
}
```

---

## 🔍 **Verificación de Seguridad**

### **Checklist de Seguridad Completo**

- [ ] Claves SSH generadas con 4096 bits
- [ ] Passphrase configurada en clave SSH
- [ ] Clave privada con permisos 600
- [ ] Clave pública distribuida a servidores
- [ ] `~/.ssh/config` configurado
- [ ] PasswordAuthentication deshabilitado en servidores
- [ ] Firewall configurado (solo IP Koha)
- [ ] Túnel SSH probado y funciona
- [ ] Conexión Firebird probada (vía túnel)
- [ ] Passwords Firebird fuertes
- [ ] `firebird_directo_koha.py` con permisos 600
- [ ] Logs de auditoría configurados
- [ ] Backup de configuración hecho
- [ ] Documentación de seguridad archivada

### **Test de Seguridad**

```bash
# 1. Verificar que sin túnel NO conecta
./firebird_directo_koha.py --biblioteca FACAGR --test
# Debe fallar si túnel no está activo

# 2. Crear túnel
./tunel_firebird.sh FACAGR

# 3. Ahora sí debe conectar
./firebird_directo_koha.py --biblioteca FACAGR --test
# ✓ FACAGR: Conexión exitosa

# 4. Ver que tráfico va encriptado
sudo tcpdump -i any port 22 -A
# Verás caracteres ilegibles (encriptado)

# 5. Cerrar túnel
./cerrar_tunel.sh 3050

# 6. Verificar que ya no conecta
./firebird_directo_koha.py --biblioteca FACAGR --test
# Debe fallar nuevamente
```

---

## 📖 **Comparación Final: CSV vs SSH**

| Aspecto | CSV Actual | Túnel SSH (SIN CSV) |
|---------|------------|---------------------|
| **Archivos intermedios** | ✅ CSV en disco | ❌ Sin archivos |
| **Encriptación** | ⚠️ SCP (si usas) | ✅ SSH AES-256 |
| **Datos en tránsito** | ⚠️ Pueden leerse | ✅ Encriptados |
| **Puerto expuesto** | ⚠️ 3050 o ninguno | ✅ Solo 22 (SSH) |
| **Autenticación** | ⚠️ Password | ✅ Clave SSH + passphrase |
| **Rastro de datos** | ⚠️ CSV en múltiples lugares | ✅ Solo origen y destino |
| **Auditoría** | ⚠️ Manual | ✅ Logs automáticos |
| **Complejidad** | ⭐ Simple | ⭐⭐ Moderada |
| **Seguridad** | ⭐⭐ Media | ⭐⭐⭐ Alta |

---

## 🎯 **Resumen Ejecutivo**

### **Túnel SSH: Máxima Seguridad SIN CSV**

✅ **Encriptación total**: AES-256, imposible interceptar
✅ **Sin archivos intermedios**: Datos solo en memoria
✅ **Autenticación fuerte**: Claves SSH 4096 bits + passphrase
✅ **Puerto estándar**: Solo SSH (22), no Firebird (3050)
✅ **Auditoría completa**: Logs de todos los accesos
✅ **Certificaciones**: Compatible con compliance de seguridad

### **Proceso de Implementación**

```
Día 1: Generar claves SSH seguras
Día 2: Configurar servidores Firebird
Día 3: Probar túneles y conexiones
Día 4: Primera sincronización segura
Día 5: Automatizar con cron
```

### **Comando Simple, Seguridad Máxima**

```bash
# TODO ESTO:
#   1. Crea túnel SSH encriptado
#   2. Conecta a Firebird remoto
#   3. Lee datos (encriptados)
#   4. Importa a Koha
#   5. Cierra túnel
#   6. Sin CSV en ningún momento

./tunel_firebird.sh FACAGR && \
./firebird_directo_koha.py --biblioteca FACAGR --incremental && \
./cerrar_tunel.sh 3050
```

---

## ✅ **¿Listo para Implementar?**

**Próximos pasos**:

1. **Leer esta guía completa** ✅ (acabas de hacerlo)
2. **Generar claves SSH seguras** → `ssh-keygen -t rsa -b 4096`
3. **Probar conexión SSH** → `./test_firebird_remoto.py`
4. **Configurar túnel** → `./tunel_firebird.sh`
5. **Primera sincronización** → `./firebird_directo_koha.py`

**¿Quieres que te ayude a configurar tu primera conexión SSH segura ahora?**

---

**Universidad Nacional de Asunción - 2025**
**Sistema de Sincronización Segura sin CSV**
