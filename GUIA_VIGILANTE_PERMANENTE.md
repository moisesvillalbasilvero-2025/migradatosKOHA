# 🔄 VIGILANTE PERMANENTE - Importador Automático Continuo

## 🎯 ¿Qué es el Vigilante Permanente?

El **Vigilante Permanente** es un servicio daemon que se ejecuta continuamente en tmux, monitoreando el directorio `importar_aqui/` y procesando **automáticamente** cualquier archivo CSV nuevo que aparezca.

**Es como tener un asistente trabajando 24/7 que importa archivos en cuanto los detecta.**

---

## ✨ Características

- ✅ **Monitoreo Continuo 24/7**: Nunca duerme, siempre vigilante
- ✅ **Detección Instantánea**: Usa `inotify` para detectar archivos al instante
- ✅ **Procesamiento Automático**: Sin intervención manual necesaria
- ✅ **Persistencia Total**: Se ejecuta en tmux, sobrevive desconexiones SSH
- ✅ **Control de Carga**: Limita importaciones simultáneas para no saturar el sistema
- ✅ **Reintentos Automáticos**: Reintenta archivos que fallan temporalmente
- ✅ **Logs Detallados**: Registro completo de toda actividad
- ✅ **Cola Inteligente**: Procesa archivos en orden con tiempos de espera
- ✅ **Notificaciones**: Información en tiempo real de cada operación

---

## 🚀 Inicio Rápido

### Iniciar el Vigilante

```bash
./vigilante_permanente.sh start
```

**Resultado:**
```
═══════════════════════════════════════════════════════════════════════════════
  VIGILANTE PERMANENTE - IMPORTADOR AUTOMÁTICO CONTINUO
═══════════════════════════════════════════════════════════════════════════════
ℹ Iniciando vigilante permanente en sesión tmux...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Vigilante iniciado exitosamente

Sesión tmux:  koha-vigilante-permanente
Log:          /home/mvillalba/migradatos/logs/vigilante/vigilante.log

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ℹ El vigilante procesará automáticamente cualquier archivo CSV
ℹ que se copie en: importar_aqui/

ℹ Comandos útiles:
  ./vigilante_permanente.sh status   - Ver estado
  ./vigilante_permanente.sh attach   - Conectar a la sesión
  ./vigilante_permanente.sh logs     - Ver logs en tiempo real
  ./vigilante_permanente.sh stop     - Detener vigilante
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Ver Estado

```bash
./vigilante_permanente.sh status
```

### Ver Logs en Tiempo Real

```bash
./vigilante_permanente.sh logs
```

### Conectar a la Sesión (Ver en Vivo)

```bash
./vigilante_permanente.sh attach
```

**Para desconectar:** `Ctrl+B` luego `D`

### Detener el Vigilante

```bash
./vigilante_permanente.sh stop
```

---

## 📋 Comandos Disponibles

| Comando | Descripción |
|---------|-------------|
| `start` | Inicia el vigilante permanente en tmux |
| `stop` | Detiene el vigilante |
| `status` | Muestra estado actual y estadísticas |
| `restart` | Reinicia el vigilante |
| `logs` | Ver logs en tiempo real (tail -f) |
| `attach` | Conectar a la sesión tmux del vigilante |

---

## 🔧 Funcionamiento Interno

### 1. Detección de Archivos

El vigilante usa dos métodos:

**A) Detección Instantánea (con inotify-tools):**
```bash
# Detecta archivos al instante usando eventos del sistema
inotifywait -m -e close_write,moved_to importar_aqui/
```

**B) Escaneo Periódico (sin inotify-tools):**
```bash
# Escanea el directorio cada 30 segundos
while true; do
    # Buscar archivos nuevos
    sleep 30
done
```

**Recomendación:** Instala `inotify-tools` para detección instantánea:
```bash
sudo apt install inotify-tools
```

### 2. Procesamiento de Archivos

Cuando se detecta un archivo nuevo:

1. **Verificación**: Comprueba que el archivo esté completo
2. **Control de Carga**: Verifica importaciones activas
3. **Espera si Necesario**: Espera si hay demasiadas importaciones simultáneas
4. **Creación de Sesión**: Crea una sesión tmux con `importar_tmux.sh`
5. **Monitoreo**: Sigue el progreso y actualiza estadísticas
6. **Reintentos**: Si falla, reintenta automáticamente
7. **Finalización**: Mueve el archivo a `procesados/` o `errores/`

### 3. Control de Carga

**Configuración por defecto:**
- **Máximo de importaciones simultáneas**: 3
- **Tiempo de espera entre archivos**: 10 segundos
- **Máximo de reintentos por archivo**: 2
- **Tiempo entre reintentos**: 5 minutos

### 4. Estado Persistente

El vigilante guarda su estado en `.vigilante.state`:
```json
{
    "estado": "ACTIVO",
    "pid": 12345,
    "inicio": "2025-11-05 15:30:00",
    "archivos_procesados": 15,
    "archivos_error": 1,
    "ultimo_archivo": "BFIA.csv",
    "ultima_actividad": "2025-11-05 18:45:22"
}
```

---

## 💡 Casos de Uso

### Caso 1: Importación Automática Continua

**Escenario:** Quieres que cualquier archivo que copies se importe automáticamente.

```bash
# 1. Inicia el vigilante una vez
./vigilante_permanente.sh start

# 2. Desde ahora, simplemente copia archivos
cp /origen/BIBLIOTECA1.csv importar_aqui/
# ¡Se importa automáticamente!

cp /origen/BIBLIOTECA2.csv importar_aqui/
# ¡También se importa!

# 3. El vigilante sigue trabajando aunque te desconectes
exit

# 4. Días después, sigue funcionando
ssh usuario@servidor
./vigilante_permanente.sh status
# Muestra todas las importaciones realizadas
```

### Caso 2: Importación Masiva Nocturna Programada

**Escenario:** Quieres copiar muchos archivos de noche y que se importen automáticamente.

```bash
# 1. Inicia el vigilante
./vigilante_permanente.sh start

# 2. Programa un cron o copia manualmente de noche
# (El vigilante los procesará automáticamente)
rsync -av /backup/*.csv importar_aqui/

# 3. Al día siguiente, revisa
./vigilante_permanente.sh status
```

### Caso 3: Monitoreo desde Múltiples Ubicaciones

**Escenario:** Quieres monitorear el vigilante desde diferentes dispositivos.

```bash
# Terminal 1 (en la oficina)
./vigilante_permanente.sh start

# Terminal 2 (desde casa, horas después)
ssh usuario@servidor
./vigilante_permanente.sh logs
# Ves todo lo que ha procesado

# Terminal 3 (desde el móvil con app SSH)
./vigilante_permanente.sh status
# Estadísticas actualizadas
```

### Caso 4: Sistema Automatizado con FTP/SFTP

**Escenario:** Otros sistemas suben archivos vía FTP al servidor.

```bash
# 1. Configura FTP/SFTP para subir archivos a importar_aqui/

# 2. Inicia el vigilante
./vigilante_permanente.sh start

# 3. Otros sistemas suben archivos
# El vigilante los detecta y procesa automáticamente

# 4. Monitorea desde el gestor
./gestionar_importaciones.sh
# Opción 15: Ver estado del vigilante
```

---

## 📊 Ejemplo de Sesión en Vivo

Cuando conectas a la sesión del vigilante (`./vigilante_permanente.sh attach`), ves algo así:

```
═══════════════════════════════════════════════════════════════════════════════
  VIGILANTE PERMANENTE INICIADO
═══════════════════════════════════════════════════════════════════════════════
Fecha/Hora:      2025-11-05 15:30:00
PID:             12345
Directorio:      /home/mvillalba/migradatos/importar_aqui
Max simultáneas: 3
═══════════════════════════════════════════════════════════════════════════════

[15:30:00] ✓ inotify-tools detectado - Modo de monitoreo instantáneo

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  VIGILANTE EN ESPERA - Monitoreando nuevos archivos...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[15:30:05] 🔔 Modo instantáneo activado (inotify)

[15:32:15] 🔔 ¡Nuevo archivo detectado!

[15:32:15] ╔═══════════════════════════════════════════════════════════════════════════════╗
[15:32:15] ║  NUEVO ARCHIVO DETECTADO                                                      ║
[15:32:15] ╚═══════════════════════════════════════════════════════════════════════════════╝
[15:32:15] Archivo:  BFIA.csv
[15:32:15] Intento:  1 de 3
[15:32:15] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[15:32:15] Importaciones activas: 0/3
[15:32:15] 🚀 Iniciando importación en sesión tmux...
[15:32:18] ✓ Sesión tmux creada exitosamente

[15:32:18] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[15:32:18] 👁  Vigilancia activa - Esperando nuevos archivos...
[15:32:18] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[15:35:30] 🔔 ¡Nuevo archivo detectado!
[...]
```

---

## ⚙️ Configuración Avanzada

Puedes modificar el comportamiento editando las variables en el script:

```bash
# Abrir el script
nano vigilante_permanente.sh

# Variables configurables (líneas 39-46):
readonly INTERVALO_ESCANEO=30                  # Segundos entre escaneos (modo periódico)
readonly MAX_IMPORTACIONES_SIMULTANEAS=3       # Máximo de importaciones paralelas
readonly TIEMPO_ESPERA_ENTRE_ARCHIVOS=10       # Segundos entre archivos
readonly REINTENTOS_ERROR=2                    # Número de reintentos
readonly TIEMPO_REINTENTO=300                  # Segundos entre reintentos (5 min)
```

**Ejemplos de ajustes:**

**Para servidor con mucha RAM:**
```bash
readonly MAX_IMPORTACIONES_SIMULTANEAS=5       # Más importaciones simultáneas
readonly TIEMPO_ESPERA_ENTRE_ARCHIVOS=5        # Menos espera entre archivos
```

**Para servidor con poca RAM:**
```bash
readonly MAX_IMPORTACIONES_SIMULTANEAS=1       # Solo una a la vez
readonly TIEMPO_ESPERA_ENTRE_ARCHIVOS=30       # Más tiempo entre archivos
```

---

## 🔍 Monitoreo y Logs

### Ver Logs en Tiempo Real
```bash
./vigilante_permanente.sh logs
```

### Ver Estado Detallado
```bash
./vigilante_permanente.sh status
```

**Salida del status:**
```
═══════════════════════════════════════════════════════════════════════════════
  VIGILANTE PERMANENTE - IMPORTADOR AUTOMÁTICO CONTINUO
═══════════════════════════════════════════════════════════════════════════════
✓ Vigilante ACTIVO
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Sesión tmux:  koha-vigilante-permanente
PID:          12345
Estado:
  estado                = ACTIVO
  pid                   = 12345
  inicio                = 2025-11-05 15:30:00
  archivos_procesados   = 15
  archivos_error        = 1
  ultimo_archivo        = BFIA.csv
  ultima_actividad      = 2025-11-05 18:45:22

Importaciones activas:
  2 sesión(es) de importación en curso

Archivos pendientes:
  3 archivo(s) en cola

Últimas 5 líneas del log:
  │ [18:45:22] ✓ Sesión tmux creada exitosamente
  │ [18:45:22] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  │ [18:45:22] 👁  Vigilancia activa - Esperando nuevos archivos...
  │ [18:45:22] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Archivo de Log

Ubicación: `/home/mvillalba/migradatos/logs/vigilante/vigilante.log`

```bash
# Ver últimas 50 líneas
tail -50 logs/vigilante/vigilante.log

# Buscar errores
grep "ERROR\|✗" logs/vigilante/vigilante.log

# Buscar importaciones exitosas
grep "✓ Sesión tmux creada" logs/vigilante/vigilante.log
```

---

## 🛠️ Integración con Gestor

El vigilante está integrado en el **Gestor de Importaciones**:

```bash
./gestionar_importaciones.sh
```

**Opciones del menú:**
- **13)** Iniciar vigilante permanente
- **14)** Detener vigilante permanente
- **15)** Ver estado del vigilante

---

## 🚦 Inicio Automático al Arranque del Sistema

Para que el vigilante se inicie automáticamente cuando arranca el servidor:

### Opción 1: Systemd Service (Recomendado)

```bash
# Crear archivo de servicio
sudo nano /etc/systemd/system/koha-vigilante.service
```

Contenido:
```ini
[Unit]
Description=Koha Vigilante Permanente - Importador Automático
After=network.target

[Service]
Type=forking
User=mvillalba
WorkingDirectory=/home/mvillalba/migradatos
ExecStart=/home/mvillalba/migradatos/vigilante_permanente.sh start
ExecStop=/home/mvillalba/migradatos/vigilante_permanente.sh stop
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# Habilitar e iniciar
sudo systemctl daemon-reload
sudo systemctl enable koha-vigilante.service
sudo systemctl start koha-vigilante.service

# Ver estado
sudo systemctl status koha-vigilante.service
```

### Opción 2: Crontab @reboot

```bash
crontab -e
```

Agregar:
```bash
@reboot sleep 30 && cd /home/mvillalba/migradatos && ./vigilante_permanente.sh start
```

---

## ❓ Preguntas Frecuentes

### ¿El vigilante se ejecuta aunque cierre mi sesión SSH?
**R:** Sí, el vigilante se ejecuta en una sesión tmux que persiste incluso si cierras tu terminal o pierdes conexión.

### ¿Puedo tener el vigilante Y ejecutar importaciones manuales?
**R:** Sí, puedes usar `./importar_tmux.sh` manualmente mientras el vigilante está activo. Ambos coexisten sin problemas.

### ¿Qué pasa si copio muchos archivos a la vez?
**R:** El vigilante los procesará en orden, respetando el límite de importaciones simultáneas (por defecto 3).

### ¿Cómo sé si el vigilante sigue funcionando?
**R:** Usa `./vigilante_permanente.sh status` en cualquier momento.

### ¿Los logs ocupan mucho espacio?
**R:** Los logs se guardan en un solo archivo que puedes rotar periódicamente. Para limpiarlo:
```bash
# Limpiar log antiguo manteniendo últimas 1000 líneas
tail -1000 logs/vigilante/vigilante.log > logs/vigilante/vigilante.log.tmp
mv logs/vigilante/vigilante.log.tmp logs/vigilante/vigilante.log
```

### ¿Puedo pausar el vigilante temporalmente?
**R:** Sí, simplemente detenlo:
```bash
./vigilante_permanente.sh stop
```

Y luego reinícialo cuando quieras:
```bash
./vigilante_permanente.sh start
```

### ¿Qué pasa si el servidor se reinicia?
**R:** El vigilante se detiene. Necesitas configurar inicio automático (ver sección arriba) o iniciarlo manualmente después del reinicio.

---

## 🎉 ¡Listo para Usar!

El vigilante permanente convierte tu sistema en un **importador totalmente automático**.

**Flujo de trabajo ideal:**

1. Inicia el vigilante una vez:
   ```bash
   ./vigilante_permanente.sh start
   ```

2. Desde ahora, solo copia archivos a `importar_aqui/`:
   ```bash
   cp /origen/*.csv importar_aqui/
   ```

3. ¡El vigilante se encarga del resto automáticamente!

4. Monitorea cuando quieras:
   ```bash
   ./vigilante_permanente.sh status
   ```

**¡No necesitas hacer nada más!** 🚀
