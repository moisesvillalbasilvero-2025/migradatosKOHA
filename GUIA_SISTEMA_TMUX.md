# 📚 SISTEMA DE IMPORTACIÓN PERSISTENTE CON TMUX

## 🎯 Descripción General

Sistema optimizado de importación a Koha que utiliza **tmux** para garantizar la persistencia de las sesiones, asegurando que cada ejecución se complete incluso si se pierde la conexión remota.

## ✨ Características Principales

- ✅ **Persistencia Total**: Las sesiones sobreviven desconexiones SSH
- ✅ **Logs en Tiempo Real**: Seguimiento completo de cada importación
- ✅ **Recuperación Automática**: Reconexión instantánea a sesiones activas
- ✅ **Múltiples Sesiones**: Ejecuta varias importaciones simultáneas
- ✅ **Monitoreo Centralizado**: Dashboard en tiempo real
- ✅ **Control Completo**: Gestión total de todas las operaciones

---

## 📋 Componentes del Sistema

### 1. **importar_tmux.sh** - Importador Principal
Script principal que ejecuta importaciones en sesiones tmux persistentes.

**Funciones:**
- Inicia importaciones en sesiones tmux independientes
- Mantiene logs automáticos de cada proceso
- Permite reconexión sin perder el progreso
- Gestiona múltiples sesiones simultáneas

### 2. **monitor_tmux.sh** - Monitor en Tiempo Real
Dashboard interactivo que muestra el estado de todas las sesiones activas.

**Funciones:**
- Actualización automática cada N segundos
- Visualización de progreso en tiempo real
- Estadísticas de cada importación
- Controles interactivos

### 3. **gestionar_importaciones.sh** - Gestor Central
Interfaz unificada para administración completa del sistema.

**Funciones:**
- Menú interactivo completo
- Gestión de sesiones (iniciar, detener, conectar)
- Visualización de logs
- Reportes y estadísticas del sistema

---

## 🚀 Guía de Uso

### Opción A: Menú Interactivo (RECOMENDADO para principiantes)

```bash
./gestionar_importaciones.sh
```

Muestra un menú completo con todas las opciones disponibles:
1. Iniciar nueva importación
2. Ver sesiones activas
3. Conectar a sesión existente
4. Monitoreo en tiempo real
5. Ver logs de sesión
6. Detener sesión
7. Y mucho más...

---

### Opción B: Línea de Comandos (Para usuarios avanzados)

#### 📥 Importar un archivo específico

```bash
./importar_tmux.sh importar_aqui/BFIA.csv
```

**Resultado:**
```
═══════════════════════════════════════════════════════════════════════════════
  SISTEMA DE IMPORTACIÓN PERSISTENTE CON TMUX - KOHA UNA
═══════════════════════════════════════════════════════════════════════════════
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ℹ Iniciando importación en sesión tmux persistente
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Archivo:        BFIA.csv
Sesión tmux:    koha-import-BFIA-20251105_143022
Log:            /home/mvillalba/migradatos/logs/tmux/koha-import-BFIA-20251105_143022.log
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Sesión iniciada correctamente

ℹ Para ver el progreso en tiempo real, ejecuta:
  tmux attach-session -t koha-import-BFIA-20251105_143022

O monitorea el log:
  tail -f /home/mvillalba/migradatos/logs/tmux/koha-import-BFIA-20251105_143022.log

Para desconectarte sin detener: Ctrl+B luego D
```

---

#### 📥 Importar TODOS los archivos pendientes

```bash
./importar_tmux.sh --all
```

Crea una sesión tmux independiente para cada archivo CSV en `importar_aqui/`

---

#### 📊 Ver estado de todas las sesiones

```bash
./importar_tmux.sh --status
```

**Resultado:**
```
═══════════════════════════════════════════════════════════════════════════════
  SISTEMA DE IMPORTACIÓN PERSISTENTE CON TMUX - KOHA UNA
═══════════════════════════════════════════════════════════════════════════════
✓ Sesiones activas: 2
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Sesión: koha-import-BFIA-20251105_143022
Archivo:     BFIA.csv
PID:         12345
Inicio:      2025-11-05 14:30:22
Duración:    0h 15m 32s
Log:         /home/mvillalba/migradatos/logs/tmux/koha-import-BFIA-20251105_143022.log
Tamaño log:  2.3MiB

Últimas 3 líneas:
  │ [2025-11-05 14:45:54] [INFO] Importando archivo 3 de 5...
  │ [2025-11-05 14:45:55] [INFO] Procesando registros bibliográficos...
  │ [2025-11-05 14:45:56] [SUCCESS] ✓ Importados 500 registros

Comandos:
  Conectar:    tmux attach-session -t koha-import-BFIA-20251105_143022
  Ver log:     tail -f /home/mvillalba/migradatos/logs/tmux/koha-import-BFIA-20251105_143022.log
  Detener:     ./importar_tmux.sh --kill koha-import-BFIA-20251105_143022
```

---

#### 🔌 Conectar a una sesión en ejecución

```bash
./importar_tmux.sh --attach koha-import-BFIA-20251105_143022
```

**O simplemente:**
```bash
tmux attach-session -t koha-import-BFIA-20251105_143022
```

**Para desconectar SIN detener la sesión:**
- Presiona `Ctrl + B`, luego presiona `D`

---

#### 🛑 Detener una sesión específica

```bash
./importar_tmux.sh --kill koha-import-BFIA-20251105_143022
```

---

#### 📺 Monitor en tiempo real (Dashboard)

```bash
./monitor_tmux.sh
```

**Dashboard interactivo que se actualiza automáticamente:**
```
═══════════════════════════════════════════════════════════════════════════════
  MONITOR DE IMPORTACIONES KOHA - SESIONES TMUX ACTIVAS
═══════════════════════════════════════════════════════════════════════════════

Actualizado: 2025-11-05 14:50:32    Sesiones activas: 2    Intervalo: 5s
Controles: [q] Salir | [r] Refrescar | [l] Ver logs | [c] Limpiar
───────────────────────────────────────────────────────────────────────────────

● BFIA-20251105_143022
├─ Archivo:     BFIA.csv
├─ PID:         12345
├─ Inicio:      2025-11-05 14:30:22
├─ Duración:    0h 20m 10s
├─ Status:      RUNNING
├─ Log size:    3.1MiB
├─ Progreso:    [████████████████░░░░] 3/5 (60.0%)
└─ Última:      Importados 1500 registros de 2500
   tmux attach-session -t koha-import-BFIA-20251105_143022
───────────────────────────────────────────────────────────────────────────────

Esperando 5 segundos antes de actualizar...
```

**Controles del monitor:**
- `q` = Salir
- `r` = Refrescar inmediatamente
- `l` = Ver lista de logs
- `c` = Limpiar sesiones finalizadas

---

#### 🧹 Limpiar sesiones finalizadas

```bash
./importar_tmux.sh --cleanup
```

---

## 🎓 Casos de Uso Comunes

### Caso 1: Importación Remota con Desconexión Programada

**Escenario:** Necesitas importar un archivo grande pero debes cerrar tu laptop.

```bash
# 1. Inicia la importación
./importar_tmux.sh importar_aqui/BIBLIOTECA_GRANDE.csv

# 2. Desconéctate de SSH (cierra tu laptop, apaga tu PC, etc.)
# La sesión tmux SIGUE EJECUTÁNDOSE en el servidor

# 3. Reconéctate más tarde desde cualquier lugar
ssh usuario@servidor
cd /home/mvillalba/migradatos

# 4. Revisa el estado
./importar_tmux.sh --status

# 5. Conéctate a la sesión si aún está activa
tmux attach-session -t koha-import-BIBLIOTECA_GRANDE-20251105_143022

# O revisa el log si ya finalizó
tail -100 logs/tmux/koha-import-BIBLIOTECA_GRANDE-20251105_143022.log
```

---

### Caso 2: Importación Masiva de Múltiples Bibliotecas

**Escenario:** Tienes 10 archivos CSV para importar.

```bash
# 1. Copia todos los CSV a importar_aqui/
cp /origen/*.csv importar_aqui/

# 2. Inicia importación de TODOS
./importar_tmux.sh --all

# 3. Monitorea todas las sesiones en tiempo real
./monitor_tmux.sh

# 4. O usa el gestor interactivo
./gestionar_importaciones.sh
```

---

### Caso 3: Monitoreo Desde Otro Terminal

**Escenario:** Quieres monitorear una importación desde otra terminal/dispositivo.

```bash
# Terminal 1: Inicia la importación
./importar_tmux.sh importar_aqui/ARCHIVO.csv

# Terminal 2 (en otro lugar): Monitorea en tiempo real
ssh usuario@servidor
./monitor_tmux.sh

# O sigue el log directamente
tail -f logs/tmux/koha-import-ARCHIVO-20251105_143022.log

# O conéctate a la sesión
tmux attach-session -t koha-import-ARCHIVO-20251105_143022
```

---

### Caso 4: Recuperación Tras Error de Red

**Escenario:** Se cortó tu conexión SSH durante una importación.

```bash
# No te preocupes, la importación SIGUE EJECUTÁNDOSE

# 1. Reconéctate al servidor
ssh usuario@servidor
cd /home/mvillalba/migradatos

# 2. Verifica las sesiones activas
./importar_tmux.sh --status

# 3. Reconéctate a tu sesión
./importar_tmux.sh --attach koha-import-ARCHIVO-20251105_143022

# ¡Listo! Sigues donde lo dejaste
```

---

## 📁 Estructura de Directorios

```
/home/mvillalba/migradatos/
├── importar_aqui/              # Archivos CSV pendientes de importación
├── procesados/                 # Archivos CSV ya importados exitosamente
├── errores/                    # Archivos CSV que tuvieron errores
├── exports/                    # Archivos MARCXML generados
├── logs/
│   ├── tmux/                   # Logs de sesiones tmux
│   └── *.log                   # Logs generales
├── .sessions/                  # Información de estado de sesiones (interno)
├── .cache/                     # Cache de recuperación (interno)
│
├── importar_tmux.sh            # 🔧 Script principal de importación
├── monitor_tmux.sh             # 📺 Monitor en tiempo real
├── gestionar_importaciones.sh  # 🎛️ Gestor interactivo completo
└── importador_automatico_completo.sh  # Motor de importación (llamado internamente)
```

---

## 🔑 Comandos Esenciales de tmux

### Comando: Listar todas las sesiones tmux
```bash
tmux list-sessions
# o
tmux ls
```

### Comando: Conectar a sesión
```bash
tmux attach-session -t NOMBRE_SESION
# o forma corta
tmux a -t NOMBRE_SESION
```

### Comando: Desconectar de sesión (SIN detenerla)
- **Dentro de tmux:** Presiona `Ctrl + B`, luego `D`

### Comando: Detener sesión
```bash
tmux kill-session -t NOMBRE_SESION
```

### Comando: Detener TODAS las sesiones
```bash
tmux kill-server
```

---

## 🛡️ Ventajas del Sistema con tmux

| Característica | Sin tmux | Con tmux |
|----------------|----------|----------|
| **Persistencia** | ❌ Se pierde al desconectar SSH | ✅ Sigue ejecutándose |
| **Recuperación** | ❌ Debes reiniciar todo | ✅ Reconectas donde quedaste |
| **Monitoreo remoto** | ❌ Solo desde terminal activo | ✅ Desde cualquier conexión |
| **Múltiples importaciones** | ⚠️ Complejo de gestionar | ✅ Sesiones independientes |
| **Logs en tiempo real** | ⚠️ Solo en terminal actual | ✅ Acceso permanente |
| **Trabajo en background** | ⚠️ Requiere nohup/screen | ✅ Nativo con tmux |

---

## 📊 Monitoreo de Estado

### Ver archivos pendientes
```bash
ls -lh importar_aqui/
```

### Ver archivos procesados
```bash
ls -lh procesados/
```

### Ver logs más recientes
```bash
ls -lht logs/tmux/*.log | head -10
```

### Seguir un log en tiempo real
```bash
tail -f logs/tmux/koha-import-ARCHIVO-20251105_143022.log
```

### Ver últimas 100 líneas de un log
```bash
tail -100 logs/tmux/koha-import-ARCHIVO-20251105_143022.log
```

---

## ❓ Preguntas Frecuentes

### ¿Qué pasa si cierro mi terminal SSH?
**R:** Nada. La sesión tmux sigue ejecutándose en el servidor. Puedes reconectarte en cualquier momento.

### ¿Puedo ejecutar varias importaciones al mismo tiempo?
**R:** Sí. Cada importación se ejecuta en su propia sesión tmux independiente.

### ¿Cómo sé si una importación terminó?
**R:** Usa `./importar_tmux.sh --status` o `./monitor_tmux.sh` para ver el estado de todas las sesiones.

### ¿Los logs se guardan automáticamente?
**R:** Sí. Cada sesión genera su propio log en `logs/tmux/` que se mantiene incluso después de finalizar.

### ¿Puedo conectarme a una sesión desde otra computadora?
**R:** Sí. Solo necesitas acceso SSH al servidor y conocer el nombre de la sesión.

### ¿Cómo detengo una importación que está tardando mucho?
**R:** Usa `./importar_tmux.sh --kill NOMBRE_SESION` o desde el gestor interactivo.

---

## 🔧 Solución de Problemas

### Problema: "tmux: command not found"
**Solución:**
```bash
sudo apt update
sudo apt install tmux
```

### Problema: No veo mis sesiones con `tmux ls`
**Causa:** Las sesiones pueden haber terminado o están bajo otro usuario.

**Solución:**
```bash
# Verificar si hay sesiones de importación
./importar_tmux.sh --status

# Ver todas las sesiones tmux (incluyendo de otros usuarios si tienes permisos)
sudo tmux ls
```

### Problema: No puedo conectarme a una sesión
**Causa:** La sesión ya finalizó.

**Solución:**
```bash
# Ver logs de la sesión finalizada
ls -lh logs/tmux/

# Ver contenido del log
cat logs/tmux/NOMBRE_SESION.log
```

### Problema: Importación muy lenta
**Solución:**
```bash
# Conéctate a la sesión para ver qué está pasando
tmux attach-session -t NOMBRE_SESION

# O revisa el log
tail -f logs/tmux/NOMBRE_SESION.log
```

---

## 📝 Ejemplos Prácticos Completos

### Ejemplo 1: Flujo Completo de Importación

```bash
# PASO 1: Preparar archivo
cp /origen/BFIA.csv importar_aqui/

# PASO 2: Iniciar importación
./importar_tmux.sh importar_aqui/BFIA.csv

# PASO 3: Ver progreso (opción A - monitoreo continuo)
./monitor_tmux.sh

# PASO 3: Ver progreso (opción B - conectarse a sesión)
tmux attach-session -t koha-import-BFIA-20251105_143022
# Desconectar: Ctrl+B luego D

# PASO 4: Verificar finalización
./importar_tmux.sh --status

# PASO 5: Ver log final
tail -100 logs/tmux/koha-import-BFIA-20251105_143022.log

# PASO 6: Verificar en Koha
./gestionar_importaciones.sh resumen
```

### Ejemplo 2: Importación Masiva Nocturna

```bash
# Programar para que se ejecute de noche
# (Nota: las sesiones tmux seguirán ejecutándose incluso si cierras sesión)

# PASO 1: Preparar todos los archivos
cp /origen/*.csv importar_aqui/

# PASO 2: Iniciar importación de todos
./importar_tmux.sh --all

# PASO 3: Desconectar (las importaciones continúan)
exit

# PASO 4: Al día siguiente, verificar
ssh usuario@servidor
cd /home/mvillalba/migradatos
./gestionar_importaciones.sh resumen
```

---

## 📞 Soporte

Para más información sobre el sistema:
- Ejecuta `./importar_tmux.sh --help`
- Ejecuta `./monitor_tmux.sh --help`
- Ejecuta `./gestionar_importaciones.sh` (menú interactivo)

---

## 🎉 ¡Listo para Usar!

El sistema está completamente configurado y listo para usar. Recomendamos empezar con el gestor interactivo:

```bash
./gestionar_importaciones.sh
```

¡Buena suerte con tus importaciones! 🚀
