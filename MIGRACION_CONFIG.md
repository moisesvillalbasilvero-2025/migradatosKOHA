# 🔧 Guía de Migración de Configuración

**Sistema de Importación a Koha - Universidad Nacional de Asunción**
Versión 2.0 - Configuración Centralizada y Segura

---

## 📋 Tabla de Contenidos

1. [¿Qué ha cambiado?](#qué-ha-cambiado)
2. [¿Por qué estos cambios?](#por-qué-estos-cambios)
3. [Guía de Migración Paso a Paso](#guía-de-migración-paso-a-paso)
4. [Configuración de Variables de Entorno](#configuración-de-variables-de-entorno)
5. [Migración de Bibliotecas Firebird](#migración-de-bibliotecas-firebird)
6. [Preguntas Frecuentes](#preguntas-frecuentes)
7. [Solución de Problemas](#solución-de-problemas)

---

## 🆕 ¿Qué ha cambiado?

### Antes (v1.x)

```python
# agente_importador_v3.py
class Config:
    DIR_TRABAJO = Path("/home/mvillalba/migradatos")  # ❌ Hardcodeado
    INSTANCIA_KOHA = "koha-cnc"
    # ... más configuración hardcodeada
```

```python
# firebird_directo_koha.py
FIREBIRD_SERVERS = {
    'FACAGR': {
        'password': 'masterkey'  # ❌ Contraseña en código fuente!
    }
}
```

### Ahora (v2.0)

```python
# Todos los scripts
from config_manager import get_config
config = get_config()  # ✅ Configuración centralizada

# Lee desde:
# 1. Variables de entorno (.env) ← PREFERIDO
# 2. config/migracion_config.json
# 3. Valores por defecto seguros
```

```bash
# .env (no se commitea a git)
KOHA_MIGRA_HOME=/home/usuario/migradatos
FIREBIRD_FACAGR_PASSWORD=mi_password_segura  # ✅ Seguro!
```

---

## 🎯 ¿Por qué estos cambios?

### Problemas Resueltos

| Problema | Solución |
|----------|----------|
| 🔴 Rutas hardcodeadas `/home/mvillalba/...` | ✅ Variables de entorno configurables |
| 🔴 Contraseñas en código fuente | ✅ Credenciales en `.env` (no versionado) |
| 🔴 Configuración duplicada en cada script | ✅ Módulo `config_manager.py` centralizado |
| 🔴 Difícil portabilidad entre servidores | ✅ Copiar `.env` y listo |
| 🔴 Sin gestión de dependencias | ✅ `requirements.txt` documentado |

### Beneficios

- ✅ **Seguridad**: Credenciales fuera del código fuente
- ✅ **Portabilidad**: Funciona en cualquier servidor sin cambiar código
- ✅ **Mantenibilidad**: Configuración en un solo lugar
- ✅ **Profesionalismo**: Sigue estándares de la industria
- ✅ **Backward Compatible**: Scripts antiguos siguen funcionando

---

## 📝 Guía de Migración Paso a Paso

### Paso 1: Instalar Dependencias

```bash
# Navegar al directorio del proyecto
cd /ruta/a/migradatosKOHA

# Instalar dependencias Python
pip3 install -r requirements.txt

# O con usuario sin privilegios
pip3 install --user -r requirements.txt
```

**Verificar instalación:**

```bash
python3 -c "import fdb, dotenv; print('✅ Dependencias instaladas correctamente')"
```

---

### Paso 2: Crear Archivo .env

```bash
# Copiar template
cp .env.example .env

# Editar con tu editor favorito
nano .env
# o
vim .env
# o
code .env
```

**Configuración mínima necesaria:**

```bash
# .env
KOHA_MIGRA_HOME=/home/TU_USUARIO/migradatos
KOHA_INSTANCE=koha-cnc
```

**¿Tu instalación estaba en `/home/mvillalba/migradatos`?**

Si es así, simplemente usa:

```bash
KOHA_MIGRA_HOME=/home/mvillalba/migradatos
```

O mejor aún, si ya estás en el directorio del proyecto, el sistema detectará automáticamente la ruta. No necesitas configurar nada si el proyecto ya está en la ubicación correcta.

---

### Paso 3: Configurar Permisos de .env

```bash
# Proteger archivo .env (IMPORTANTE)
chmod 600 .env

# Verificar que .env no esté en git
git status  # No debe aparecer .env

# Si aparece, agregarlo a .gitignore
echo ".env" >> .gitignore
```

---

### Paso 4: Migrar Configuración Existente

#### 4.1. Rutas del Sistema

Si tenías rutas personalizadas en los scripts, agrégalas a `.env`:

```bash
# .env
KOHA_MIGRA_HOME=/mi/ruta/personalizada
KOHA_MIGRA_EXPORTS=/otra/ruta/exports
KOHA_MIGRA_LOGS=/var/log/koha-imports
```

#### 4.2. Parámetros de Koha

Si modificaste valores como `COMMIT_SIZE`, `CHUNK_SIZE`, etc.:

```bash
# .env
KOHA_COMMIT_SIZE=1500
KOHA_CHUNK_SIZE=3000
KOHA_MAX_RECORDS_PER_FILE=7000
```

#### 4.3. Timeouts

Si ajustaste timeouts:

```bash
# .env
KOHA_TIMEOUT_MARCXML=1200
KOHA_TIMEOUT_IMPORT=3000
```

---

### Paso 5: Probar la Configuración

```bash
# Ver la configuración actual
python3 config_manager.py
```

**Salida esperada:**

```
╔════════════════════════════════════════════════════════════════════╗
║          CONFIGURACIÓN DEL SISTEMA                                 ║
╚════════════════════════════════════════════════════════════════════╝

Rutas del Sistema:
  DIR_TRABAJO:    /home/usuario/migradatos
  DIR_EXPORTS:    /home/usuario/migradatos/exports
  DIR_LOGS:       /home/usuario/migradatos/logs
  ...

Configuración Koha:
  INSTANCIA_KOHA: koha-cnc
  LOC_DEFAULT:    SALA
  ...

Bibliotecas configuradas:
  POL        - Biblioteca Politécnica                   [ACTIVA]
  ARQ        - Arquitectura                             [ACTIVA]
  ...
```

---

### Paso 6: Probar Scripts

```bash
# Probar validador (no requiere configuración compleja)
python3 validador_csv.py --help

# Probar que importa correctamente
python3 -c "from config_manager import get_config; c = get_config(); print(f'✅ Config OK: {c.DIR_TRABAJO}')"

# Probar agente importador
python3 agente_importador_v3.py --version
```

---

## 🗄️ Migración de Bibliotecas Firebird

### Configuración Antigua (INSEGURA)

```python
# firebird_directo_koha.py (v1.x)
FIREBIRD_SERVERS = {
    'FACAGR': {
        'host': '192.168.1.10',
        'password': 'masterkey'  # ❌ En código fuente!
    }
}
```

### Configuración Nueva (SEGURA)

#### Opción 1: Variables de Entorno (.env) - RECOMENDADO

```bash
# .env
FIREBIRD_FACAGR_HOST=192.168.1.10
FIREBIRD_FACAGR_PORT=3050
FIREBIRD_FACAGR_DATABASE=/datos/biblio.fdb
FIREBIRD_FACAGR_USER=SYSDBA
FIREBIRD_FACAGR_PASSWORD=tu_password_real_aqui
FIREBIRD_FACAGR_CHARSET=UTF8
```

#### Opción 2: config/migracion_config.json + .env

```json
// config/migracion_config.json (solo metadatos)
{
  "bibliotecas": {
    "FACAGR": {
      "nombre": "Facultad de Ciencias Agrarias",
      "tipo_fuente": "firebird_remoto",
      "firebird": {
        "host": "192.168.1.10",
        "port": 3050,
        "database": "/datos/biblio.fdb",
        "user": "SYSDBA"
        // NO incluir password aquí
      },
      "codigo_koha": "FACAGR",
      "activa": true
    }
  }
}
```

```bash
# .env (credenciales)
FIREBIRD_FACAGR_PASSWORD=tu_password_segura
```

---

### Migrar Múltiples Bibliotecas Firebird

```bash
# .env
# Biblioteca 1
FIREBIRD_POL_HOST=localhost
FIREBIRD_POL_DATABASE=/var/lib/firebird/pol.fdb
FIREBIRD_POL_PASSWORD=password_pol

# Biblioteca 2
FIREBIRD_FACAGR_HOST=192.168.1.10
FIREBIRD_FACAGR_DATABASE=/datos/facagr.fdb
FIREBIRD_FACAGR_PASSWORD=password_facagr

# Biblioteca 3
FIREBIRD_ING_HOST=192.168.2.20
FIREBIRD_ING_DATABASE=/opt/firebird/ing.fdb
FIREBIRD_ING_PASSWORD=password_ing
```

---

## ❓ Preguntas Frecuentes

### ¿Tengo que cambiar mis scripts personalizados?

**No necesariamente.** Si tus scripts importan `agente_importador_v3.py` u otros, seguirán funcionando. La migración es backward-compatible.

### ¿Qué pasa si no creo el archivo .env?

El sistema usará:
1. Variables de entorno del sistema (si existen)
2. Configuración de `config/migracion_config.json`
3. Valores por defecto (directorio actual del proyecto)

Pero **sin .env no podrás configurar credenciales de forma segura**.

### ¿Puedo seguir usando rutas hardcodeadas?

Sí, técnicamente puedes modificar `config_manager.py` o `migracion_config.json`, pero **NO es recomendado** por razones de seguridad y portabilidad.

### ¿El archivo .env se commitea a Git?

**¡NO!** El archivo .env está automáticamente en `.gitignore`. Contiene credenciales sensibles y nunca debe versionarse.

Solo versionamos `.env.example` como template.

### ¿Cómo comparto configuración con otro servidor?

1. Copiar `config/migracion_config.json` (sin credenciales)
2. Crear nuevo `.env` en el servidor destino con sus credenciales
3. Listo

### ¿Los scripts viejos siguen funcionando?

Sí. Hemos mantenido backward compatibility. Los scripts detectan `Config` y siguen funcionando, pero ahora obtienen valores de `config_manager`.

---

## 🔧 Solución de Problemas

### Error: "No se pudo importar config_manager.py"

**Causa:** `config_manager.py` no está en el PATH de Python o en el mismo directorio.

**Solución:**

```bash
# Verificar que config_manager.py existe
ls -la config_manager.py

# Ejecutar desde el directorio correcto
cd /home/usuario/migradatosKOHA
python3 agente_importador_v3.py
```

---

### Error: "ModuleNotFoundError: No module named 'dotenv'"

**Causa:** No instalaste las dependencias.

**Solución:**

```bash
pip3 install -r requirements.txt
# o
pip3 install python-dotenv
```

---

### Las credenciales de Firebird no funcionan

**Verificar:**

```bash
# 1. ¿Está el .env en el directorio correcto?
ls -la .env

# 2. ¿Tiene los permisos correctos?
ls -l .env  # Debe ser -rw------- (600)

# 3. ¿Está bien formateado?
cat .env | grep FIREBIRD_

# 4. ¿Las variables se están leyendo?
python3 -c "from config_manager import get_config; c = get_config(); print(c.get_firebird_config('FACAGR'))"
```

---

### Error: "DIR_TRABAJO no existe"

**Causa:** La ruta en `KOHA_MIGRA_HOME` no existe.

**Solución:**

```bash
# Opción 1: Crear el directorio
mkdir -p /ruta/configurada

# Opción 2: Cambiar la ruta en .env
nano .env
# Editar KOHA_MIGRA_HOME a una ruta que exista

# Opción 3: Usar auto-detección (no configurar KOHA_MIGRA_HOME)
# El sistema usará el directorio donde está config_manager.py
```

---

### Los scripts no encuentran archivos CSV

**Causa:** Ruta `DIR_VIGILAR` incorrecta.

**Solución:**

```bash
# Ver configuración actual
python3 config_manager.py | grep DIR_VIGILAR

# Si es incorrecta, agregar a .env:
echo "KOHA_MIGRA_WATCH_DIR=/ruta/correcta/importar_aqui" >> .env
```

---

## 📚 Documentación Adicional

- **README_MASTER.md** - Documentación principal del sistema
- **.env.example** - Template completo de variables de entorno
- **requirements.txt** - Dependencias Python con notas de instalación
- **config/migracion_config.json** - Configuración de bibliotecas

---

## ✅ Checklist de Migración

Usa este checklist para verificar que la migración fue exitosa:

- [ ] ✅ Instaladas dependencias (`pip3 install -r requirements.txt`)
- [ ] ✅ Creado archivo `.env` desde `.env.example`
- [ ] ✅ Configuradas rutas en `.env` (o dejado auto-detección)
- [ ] ✅ Configuradas credenciales Firebird (si aplica)
- [ ] ✅ Permisos de `.env` establecidos (`chmod 600 .env`)
- [ ] ✅ Verificado que `.env` NO está en git (`git status`)
- [ ] ✅ Probado `python3 config_manager.py` muestra configuración correcta
- [ ] ✅ Probado al menos un script Python funciona correctamente
- [ ] ✅ Migrados todos los parámetros personalizados a `.env`
- [ ] ✅ Documentado cambios específicos de tu instalación

---

## 🆘 Soporte

Si tienes problemas con la migración:

1. **Revisar esta guía** completa
2. **Verificar logs** en `logs/`
3. **Ejecutar** `python3 config_manager.py` para diagnosticar
4. **Crear issue** en el repositorio con:
   - Error exacto
   - Salida de `python3 config_manager.py`
   - Sistema operativo y versión de Python

---

## 🎉 ¡Migración Completada!

Si llegaste hasta aquí y todos los checks están ✅, **¡felicitaciones!**

Tu sistema ahora es:
- ✅ Más seguro (credenciales protegidas)
- ✅ Más portable (funciona en cualquier servidor)
- ✅ Más mantenible (configuración centralizada)
- ✅ Más profesional (sigue estándares de la industria)

**Universidad Nacional de Asunción**
Sistema de Importación a Koha - v2.0
Actualizado: 2025-11-10
