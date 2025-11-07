# 🔒 PLAN B: IMPORTACIÓN VÍA SSH + FIREBIRD

**Universidad Nacional de Asunción**
**Sistema de Importación Alternativo con SSH**

---

## 📋 **Plan A vs Plan B**

| Aspecto | **Plan A** (Directo) | **Plan B** (SSH) |
|---------|---------------------|------------------|
| **Conexión** | TCP/IP directo a Firebird | Túnel SSH encriptado |
| **Seguridad** | Puerto 3050 expuesto | Solo puerto 22 (SSH) |
| **Requisitos** | Firebird accesible remotamente | Solo SSH habilitado |
| **Firewall** | Abrir puerto 3050 | Solo puerto 22 (estándar) |
| **Simplicidad** | ✅ Más simple | Requiere SSH configurado |
| **Uso** | Internet/LAN | Internet (más seguro) |

### **¿Cuándo usar cada Plan?**

**Usar Plan A (Directo)** cuando:
- ✅ Estás en red local confiable
- ✅ Puerto 3050 es accesible
- ✅ No hay restricciones de firewall
- ✅ Quieres la máxima simplicidad

**Usar Plan B (SSH)** cuando:
- ✅ Conexión por internet público
- ✅ Solo puerto SSH (22) está abierto
- ✅ Necesitas máxima seguridad
- ✅ Firewall corporativo restringe puertos

---

## 🎯 **Métodos del Plan B**

El Plan B ofrece **2 métodos**:

### **Método B1: Túnel SSH a Firebird**
```
Tu Koha → Túnel SSH → Servidor → Firebird local
        (puerto 22)              (puerto 3050)
```
**Ventaja**: Usa el mismo `firebird_directo_koha.py` sin modificar

### **Método B2: Importación Remota SSH**
```
Tu Koha → SSH → Servidor ejecuta exportación → Descarga CSV → Importa
```
**Ventaja**: No requiere que Firebird acepte conexiones de red

---

## 🚀 **Método B1: Túnel SSH a Firebird**

### **¿Cómo funciona?**

1. Creas un **túnel SSH** que redirige puerto local → Firebird remoto
2. Tu script Python conecta a `localhost:3050`
3. SSH reenvía la conexión al Firebird remoto
4. Todo el tráfico va **encriptado** por SSH

### **Paso 1: Configurar Autenticación SSH sin Password**

```bash
# Generar clave SSH (si no tienes)
ssh-keygen -t rsa -b 4096 -C "koha@universidad.edu.py"

# Copiar clave al servidor Firebird
ssh-copy-id -p 22 usuario@192.168.1.100

# Probar conexión sin password
ssh usuario@192.168.1.100 exit
# Debe conectar sin pedir password
```

### **Paso 2: Crear Túnel SSH**

```bash
# Ejecutar script de túnel
./tunel_firebird.sh FACAGR
```

Esto crea un túnel:
- **Puerto local**: 3050 (o el que configures)
- **Reenviado a**: localhost:3050 en servidor remoto
- **Vía SSH**: Conexión encriptada

### **Paso 3: Configurar firebird_directo_koha.py**

Editar `firebird_directo_koha.py`:

```python
FIREBIRD_SERVERS = {
    'FACAGR': {
        'nombre': 'Facultad de Ciencias Agrarias',
        'host': 'localhost',           # ← LOCALHOST (túnel)
        'port': 3050,                  # ← Puerto local del túnel
        'database': '/datos/facagr.gdb',
        'user': 'SYSDBA',
        'password': 'masterkey',
        'charset': 'WIN1252',
        'activo': True,
    },
}
```

### **Paso 4: Importar Normalmente**

```bash
# Con túnel activo, importar normal
./firebird_directo_koha.py --biblioteca FACAGR
```

### **Paso 5: Cerrar Túnel**

```bash
./cerrar_tunel.sh 3050
```

### **Comandos Rápidos - Método B1**

```bash
# 1. Crear túnel
./tunel_firebird.sh FACAGR

# 2. Probar conexión
./firebird_directo_koha.py --test

# 3. Importar
./firebird_directo_koha.py --biblioteca FACAGR

# 4. Cerrar túnel
./cerrar_tunel.sh 3050
```

---

## 🔄 **Método B2: Importación Remota SSH**

### **¿Cómo funciona?**

1. Te conectas por SSH al servidor Firebird
2. Ejecutas exportación CSV **en el servidor** (local a Firebird)
3. Descargas el CSV generado vía SCP
4. Importas el CSV a Koha

**Ventaja**: Firebird no necesita aceptar conexiones remotas.

### **Paso 1: Instalar fdb en Servidor Remoto**

```bash
# Conectar al servidor Firebird
ssh usuario@192.168.1.100

# Instalar driver Python para Firebird
sudo pip3 install fdb
# O
sudo apt install python3-fdb

exit
```

### **Paso 2: Configurar importar_remoto_ssh.sh**

Editar el script y agregar tu servidor:

```bash
nano importar_remoto_ssh.sh
```

Agregar en la sección de configuración:

```bash
case "$SERVIDOR_CODIGO" in
    FACAGR)
        SSH_HOST="192.168.1.100"
        SSH_USER="usuario"
        SSH_PORT="22"
        FIREBIRD_DB="/datos/biblioteca.gdb"
        FIREBIRD_USER="SYSDBA"
        FIREBIRD_PASS="masterkey"
        DESCRIPCION="Facultad de Ciencias Agrarias"
        ;;
esac
```

### **Paso 3: Ejecutar Importación Remota**

```bash
./importar_remoto_ssh.sh FACAGR
```

Este script:
1. ✅ Se conecta por SSH
2. ✅ Envía script de exportación Python
3. ✅ Ejecuta exportación en servidor (local a Firebird)
4. ✅ Descarga CSV generado
5. ✅ Importa a Koha local

### **Comandos Rápidos - Método B2**

```bash
# Todo en un comando
./importar_remoto_ssh.sh FACAGR

# El CSV queda en:
#   ./temp_remoto_FACAGR/FACAGR_20250131_143022.csv

# Limpiar temporales
rm -rf temp_remoto_FACAGR
```

---

## 🛠️ **Scripts Creados**

| Script | Método | Descripción |
|--------|--------|-------------|
| **tunel_firebird.sh** | B1 | Crea túnel SSH a Firebird |
| **cerrar_tunel.sh** | B1 | Cierra túneles SSH activos |
| **importar_remoto_ssh.sh** | B2 | Importación remota completa |

---

## 📊 **Comparación Detallada de Métodos**

### **Plan A: Conexión Directa TCP/IP**

```python
# firebird_directo_koha.py
FIREBIRD_SERVERS = {
    'FACAGR': {
        'host': '192.168.1.100',  # IP real del servidor
        'port': 3050,
        ...
    }
}
```

**Requisitos**:
- ✅ Puerto 3050 abierto en firewall
- ✅ Firebird configurado para aceptar conexiones remotas
- ✅ Driver fdb instalado localmente

**Ventajas**:
- ✅ Más simple
- ✅ Más rápido (conexión directa)
- ✅ Sin configuración SSH

**Desventajas**:
- ❌ Puerto 3050 expuesto
- ❌ Tráfico sin encriptar adicional
- ❌ Puede ser bloqueado por firewall

---

### **Plan B1: Túnel SSH**

```python
# firebird_directo_koha.py (igual que Plan A)
FIREBIRD_SERVERS = {
    'FACAGR': {
        'host': 'localhost',      # ← Cambio: localhost
        'port': 3050,
        ...
    }
}
```

```bash
# Antes de importar
./tunel_firebird.sh FACAGR
```

**Requisitos**:
- ✅ Solo puerto 22 (SSH) abierto
- ✅ Autenticación SSH configurada
- ✅ Driver fdb instalado localmente

**Ventajas**:
- ✅ Tráfico 100% encriptado
- ✅ Solo puerto SSH (estándar)
- ✅ Seguro para internet
- ✅ Usa mismo script de importación

**Desventajas**:
- ❌ Requiere configurar SSH
- ❌ Paso adicional (crear túnel)

---

### **Plan B2: Importación Remota**

```bash
# Todo en un comando
./importar_remoto_ssh.sh FACAGR
```

**Requisitos**:
- ✅ Solo puerto 22 (SSH) abierto
- ✅ Python + fdb en servidor remoto
- ✅ Autenticación SSH configurada

**Ventajas**:
- ✅ Firebird no necesita conexiones remotas
- ✅ Exportación local (más rápida)
- ✅ Seguro para internet
- ✅ CSV descargado automáticamente

**Desventajas**:
- ❌ Requiere instalar fdb en servidor remoto
- ❌ Paso adicional (descarga CSV)
- ❌ Genera archivos temporales

---

## 🔒 **Configuración Inicial SSH**

### **1. Generar Clave SSH (Primera Vez)**

```bash
# En tu servidor Koha
ssh-keygen -t rsa -b 4096 -C "koha@universidad.edu.py"

# Enter en todas las preguntas (sin passphrase)
# Genera:
#   ~/.ssh/id_rsa      (clave privada)
#   ~/.ssh/id_rsa.pub  (clave pública)
```

### **2. Copiar Clave a Servidores Firebird**

```bash
# Para cada servidor Firebird
ssh-copy-id -p 22 usuario@192.168.1.100
ssh-copy-id -p 22 admin@192.168.1.101
```

### **3. Probar Conexión sin Password**

```bash
ssh usuario@192.168.1.100 exit
# Debe conectar SIN pedir password
```

### **4. Configuración Opcional: ~/.ssh/config**

Crear `~/.ssh/config` para simplificar conexiones:

```
Host facagr
    HostName 192.168.1.100
    User usuario
    Port 22
    IdentityFile ~/.ssh/id_rsa

Host facmed
    HostName 192.168.1.101
    User admin
    Port 22
```

Ahora puedes usar: `ssh facagr` en lugar de `ssh usuario@192.168.1.100`

---

## 🧪 **Probar Plan B**

### **Probar Método B1 (Túnel)**

```bash
# 1. Crear túnel
./tunel_firebird.sh FACAGR

# Debes ver:
#   ✓ Túnel SSH creado exitosamente (PID: 12345)
#   Conecta a Firebird en:
#     Host:   localhost
#     Puerto: 3050

# 2. Verificar túnel activo
lsof -i :3050
# Debe mostrar proceso ssh

# 3. Probar conexión Firebird
./test_firebird_remoto.py
# Ingresar:
#   Host: localhost
#   Puerto: 3050
#   (resto igual)

# 4. Cerrar túnel
./cerrar_tunel.sh 3050
```

### **Probar Método B2 (Remoto)**

```bash
# 1. Verificar SSH funciona
ssh usuario@192.168.1.100 exit
# Sin password

# 2. Verificar Python+fdb en servidor remoto
ssh usuario@192.168.1.100 "python3 -c 'import fdb; print(fdb.__version__)'"
# Debe mostrar: 2.0.4 (o similar)

# 3. Ejecutar importación remota
./importar_remoto_ssh.sh FACAGR

# Debe ejecutar 5 pasos y descargar CSV
```

---

## 🔧 **Solución de Problemas**

### **Error: "Permission denied (publickey)"**

**Causa**: Clave SSH no configurada

**Solución**:
```bash
ssh-copy-id -p 22 usuario@192.168.1.100
```

### **Error: "Connection refused" en puerto 3050**

**Causa**: Túnel no está activo

**Solución**:
```bash
# Verificar túnel
lsof -i :3050

# Recrear túnel
./tunel_firebird.sh FACAGR
```

### **Error: "Address already in use"**

**Causa**: Ya hay túnel en ese puerto

**Solución**:
```bash
./cerrar_tunel.sh 3050
./tunel_firebird.sh FACAGR
```

### **Error: "fdb not found" en servidor remoto**

**Causa**: Driver fdb no instalado en servidor Firebird

**Solución**:
```bash
ssh usuario@192.168.1.100
sudo pip3 install fdb
exit
```

---

## 📚 **Flujos de Trabajo Completos**

### **Flujo Plan A: Conexión Directa**

```bash
# Configuración (una vez)
1. Instalar fdb local: pip3 install --break-system-packages fdb
2. Abrir puerto 3050 en firewall del servidor Firebird
3. Configurar Firebird para conexiones remotas
4. Configurar firebird_directo_koha.py con IP real

# Uso diario
./firebird_directo_koha.py --biblioteca FACAGR --incremental
```

**Total pasos**: 1 comando

---

### **Flujo Plan B1: Túnel SSH**

```bash
# Configuración (una vez)
1. Instalar fdb local: pip3 install --break-system-packages fdb
2. Configurar autenticación SSH: ssh-copy-id usuario@servidor
3. Configurar firebird_directo_koha.py con 'localhost'

# Uso diario
./tunel_firebird.sh FACAGR
./firebird_directo_koha.py --biblioteca FACAGR --incremental
./cerrar_tunel.sh 3050
```

**Total pasos**: 3 comandos

---

### **Flujo Plan B2: Importación Remota**

```bash
# Configuración (una vez)
1. Instalar fdb en servidor remoto: ssh ... sudo pip3 install fdb
2. Configurar autenticación SSH: ssh-copy-id usuario@servidor
3. Configurar importar_remoto_ssh.sh con datos de servidor

# Uso diario
./importar_remoto_ssh.sh FACAGR
```

**Total pasos**: 1 comando (pero más lento)

---

## 🎯 **Recomendaciones**

### **Red Local (LAN) → Usar Plan A**
- Conexión directa es más simple
- Menor latencia
- Menos configuración

### **Internet Público → Usar Plan B1**
- Seguridad adicional con SSH
- Solo requiere puerto 22
- Usa mismo código de importación

### **Firewall Restrictivo → Usar Plan B2**
- Solo necesita SSH saliente
- No requiere Firebird remoto
- Exportación local (rápida)

---

## 📝 **Checklist Plan B**

### **Método B1 (Túnel SSH)**

- [ ] Clave SSH generada
- [ ] Clave copiada a servidor remoto
- [ ] Conexión SSH sin password funciona
- [ ] Script `tunel_firebird.sh` configurado
- [ ] `firebird_directo_koha.py` usa 'localhost'
- [ ] Túnel probado exitosamente

### **Método B2 (Importación Remota)**

- [ ] Clave SSH generada
- [ ] Clave copiada a servidor remoto
- [ ] Python 3 instalado en servidor remoto
- [ ] fdb instalado en servidor remoto
- [ ] Script `importar_remoto_ssh.sh` configurado
- [ ] Importación remota probada exitosamente

---

## 🚀 **Automatización con Túnel SSH**

Para automatizar con cron usando túnel SSH:

```bash
#!/bin/bash
# sync_facagr_ssh.sh

# Crear túnel
./tunel_firebird.sh FACAGR

# Esperar a que túnel esté listo
sleep 3

# Importar
./firebird_directo_koha.py --biblioteca FACAGR --incremental

# Cerrar túnel
./cerrar_tunel.sh 3050
```

Agregar a cron:
```bash
crontab -e

# Sincronización diaria a las 2 AM vía SSH
0 2 * * * cd /home/mvillalba/migradatos && ./sync_facagr_ssh.sh >> logs/sync_ssh.log 2>&1
```

---

## 📖 **Documentación Relacionada**

| Documento | Contenido |
|-----------|-----------|
| **README_FIREBIRD_DIRECTO.md** | Plan A: Conexión directa |
| **GUIA_FIREBIRD_REMOTO.md** | Guía completa Firebird |
| **FIREBIRD_25_GDB.md** | Específico para Firebird 2.5.7 |
| **README_PLAN_B_SSH.md** | Este documento (Plan B) |

---

## ✅ **Resumen Ejecutivo**

**Plan A (Directo)**: Simple, rápido, para redes locales confiables

**Plan B (SSH)**: Seguro, versátil, para internet o restricciones de firewall

**Ambos planes**:
- ✅ Mantienen sincronización automática
- ✅ Soportan modo incremental
- ✅ Funcionan con Firebird 2.5.7 (.gdb)
- ✅ Compatible con múltiples servidores
- ✅ Logs completos de auditoría

**Elige el plan según tu entorno de red y requisitos de seguridad.**

---

**¡Sistema completo con Plan A y Plan B listos! 🔥🔒**

Universidad Nacional de Asunción - 2025
