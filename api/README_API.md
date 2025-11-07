# 🚀 API REST - Sistema de Importación Koha

Sistema profesional de importación automática de datos bibliográficos a Koha OPAC mediante API REST.

---

## 📋 Tabla de Contenidos

1. [Características](#características)
2. [Arquitectura](#arquitectura)
3. [Instalación](#instalación)
4. [Inicio Rápido](#inicio-rápido)
5. [Endpoints API](#endpoints-api)
6. [Autenticación](#autenticación)
7. [Ejemplos de Uso](#ejemplos-de-uso)
8. [Cliente Python](#cliente-python)
9. [Modos de Importación](#modos-de-importación)
10. [Monitoreo de Trabajos](#monitoreo-de-trabajos)
11. [Webhooks](#webhooks)
12. [Seguridad](#seguridad)
13. [Despliegue en Producción](#despliegue-en-producción)
14. [Troubleshooting](#troubleshooting)

---

## ✨ Características

- ✅ **API REST completa** con OpenAPI/Swagger
- ✅ **Importación directa a Koha OPAC** sin intervención manual
- ✅ **Procesamiento asíncrono** de trabajos en background
- ✅ **3 modos de operación**: normal, dry-run, validate-only
- ✅ **Sistema de colas** para múltiples trabajos simultáneos
- ✅ **Persistencia de estado** para recovery automático
- ✅ **Webhooks** para notificaciones al completar
- ✅ **Validación avanzada** con ISBN/ISSN checksum
- ✅ **Detección de duplicados** con fuzzy matching
- ✅ **Cliente Python incluido** con ejemplos
- ✅ **Documentación interactiva** auto-generada
- ✅ **Sin modificación del sistema CLI** existente

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                    CLIENTES (Usuarios)                      │
├─────────────┬───────────────┬───────────────┬──────────────┤
│   curl/wget │  Cliente Web  │ Cliente Python│  Otro HTTP   │
└──────┬──────┴───────┬───────┴───────┬───────┴──────┬───────┘
       │              │               │              │
       └──────────────┴───────────────┴──────────────┘
                          │
                    [API Gateway]
                          │
       ┌──────────────────┴──────────────────┐
       │   FastAPI REST Server (Port 8000)   │
       ├─────────────────────────────────────┤
       │  • Endpoints de importación         │
       │  • Validación de archivos           │
       │  • Gestión de trabajos              │
       │  • Autenticación API Key            │
       └──────────────────┬──────────────────┘
                          │
       ┌──────────────────┴──────────────────┐
       │     Background Job Processor        │
       ├─────────────────────────────────────┤
       │  • Cola asíncrona de trabajos       │
       │  • Persistencia de estado (JSON)    │
       │  • Recovery automático              │
       │  • Webhooks al completar            │
       └──────────────────┬──────────────────┘
                          │
       ┌──────────────────┴──────────────────┐
       │      Core Processing Layer          │
       ├─────────────────────────────────────┤
       │  • ProcesadorCSV (existente)        │
       │  • ValidadorAvanzado                │
       │  • Generador MARCXML                │
       └──────────────────┬──────────────────┘
                          │
       ┌──────────────────┴──────────────────┐
       │         Koha OPAC Database          │
       ├─────────────────────────────────────┤
       │  • MySQL/MariaDB                    │
       │  • Tablas biblio, items, etc.       │
       └─────────────────────────────────────┘
```

**Flujo de Datos:**

1. **Cliente** envía CSV vía HTTP POST
2. **API** valida autenticación y archivo
3. **Job Manager** crea trabajo y lo encola
4. **Background Processor** ejecuta importación
5. **Core Layer** procesa CSV → MARCXML → Koha
6. **Koha Database** recibe los registros
7. **Webhook** (opcional) notifica completación

---

## 📦 Instalación

### Requisitos

- **Python 3.8+**
- **Acceso a Koha OPAC** (MySQL/MariaDB)
- **Sistema CLI funcional** (ya instalado)

### Paso 1: Instalar Dependencias

```bash
cd /home/user/migradatosKOHA/api
pip3 install -r requirements.txt
```

### Paso 2: Configurar Variables de Entorno (Opcional)

```bash
# Crear archivo .env
cat > .env <<EOF
API_KEY=tu-api-key-super-secreta-2025
HOST=0.0.0.0
PORT=8000
EOF
```

### Paso 3: Verificar Instalación

```bash
python3 -c "import fastapi, uvicorn; print('✓ Dependencias OK')"
```

---

## 🚀 Inicio Rápido

### Opción 1: Script Automático (Recomendado)

```bash
cd /home/user/migradatosKOHA/api
./iniciar_servidor.sh
```

### Opción 2: Manual con Uvicorn

```bash
cd /home/user/migradatosKOHA/api
python3 -m uvicorn servidor_api:app --host 127.0.0.1 --port 8000 --reload
```

### Verificar que Funciona

```bash
# Health check
curl http://localhost:8000/api/v1/health

# Ver documentación interactiva
xdg-open http://localhost:8000/docs  # O visita en navegador
```

---

## 📡 Endpoints API

### Base URL

```
http://localhost:8000/api/v1
```

### Endpoints Disponibles

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/health` | Health check del servidor |
| `POST` | `/import` | **Importar CSV directamente a Koha** |
| `POST` | `/validate` | Validar archivo CSV sin importar |
| `GET` | `/jobs` | Listar todos los trabajos |
| `GET` | `/jobs/{job_id}` | Obtener estado de un trabajo |
| `DELETE` | `/jobs/{job_id}` | Cancelar un trabajo pendiente |

### Documentación Interactiva

- **Swagger UI**: `http://localhost:8000/docs`
- **ReDoc**: `http://localhost:8000/redoc`
- **OpenAPI JSON**: `http://localhost:8000/openapi.json`

---

## 🔐 Autenticación

Todas las peticiones (excepto `/health`) requieren una **API Key** en el header:

```http
X-API-Key: una-koha-api-key-segura-2025
```

**Configurar tu propia API Key:**

Editar `api/servidor_api.py`:

```python
class APIConfig:
    API_KEYS = {
        "tu-api-key-super-secreta",
        "otra-api-key-para-otro-usuario"
    }
```

**Ejemplo con curl:**

```bash
curl -X POST "http://localhost:8000/api/v1/import" \
     -H "X-API-Key: una-koha-api-key-segura-2025" \
     -F "file=@MED.csv"
```

---

## 💡 Ejemplos de Uso

### 1. Importación Directa a Koha (Caso Principal)

```bash
# Importar archivo CSV directamente a Koha OPAC
curl -X POST "http://localhost:8000/api/v1/import" \
     -H "X-API-Key: una-koha-api-key-segura-2025" \
     -F "file=@MED.csv" \
     -F "mode=normal"

# Respuesta:
{
  "job_id": "20251107-103045-a1b2c3",
  "status": "pending",
  "filename": "MED.csv",
  "message": "Trabajo creado exitosamente",
  "created_at": "2025-11-07T10:30:45"
}
```

### 2. Validar Archivo Sin Importar

```bash
# Solo validar estructura y calidad
curl -X POST "http://localhost:8000/api/v1/validate" \
     -H "X-API-Key: una-koha-api-key-segura-2025" \
     -F "file=@MED.csv"

# Respuesta:
{
  "valid": true,
  "codigo_biblioteca": "MED",
  "record_count": 1500,
  "quality_score": 95.5,
  "errors": [],
  "warnings": ["ISBN faltante en 3 registros"]
}
```

### 3. Dry-Run (Simulación)

```bash
# Simular importación sin modificar base de datos
curl -X POST "http://localhost:8000/api/v1/import" \
     -H "X-API-Key: una-koha-api-key-segura-2025" \
     -F "file=@MED.csv" \
     -F "mode=dry_run"
```

### 4. Ver Estado de Trabajo

```bash
# Obtener estado actual de un trabajo
curl -X GET "http://localhost:8000/api/v1/jobs/20251107-103045-a1b2c3" \
     -H "X-API-Key: una-koha-api-key-segura-2025"

# Respuesta:
{
  "job_id": "20251107-103045-a1b2c3",
  "status": "processing",
  "progress": 65.5,
  "message": "Procesando lote 98 de 150",
  "result": null
}
```

### 5. Listar Todos los Trabajos

```bash
# Ver histórico de importaciones
curl -X GET "http://localhost:8000/api/v1/jobs?limit=10&status=completed" \
     -H "X-API-Key: una-koha-api-key-segura-2025"
```

### 6. Cancelar Trabajo

```bash
# Cancelar un trabajo pendiente
curl -X DELETE "http://localhost:8000/api/v1/jobs/20251107-103045-a1b2c3" \
     -H "X-API-Key: una-koha-api-key-segura-2025"
```

### 7. Importación con Webhook

```bash
# Recibir notificación al completar
curl -X POST "http://localhost:8000/api/v1/import" \
     -H "X-API-Key: una-koha-api-key-segura-2025" \
     -F "file=@MED.csv" \
     -F "webhook_url=https://tu-servidor.com/webhook"

# El servidor enviará POST al webhook al completar:
# {
#   "job_id": "...",
#   "status": "completed",
#   "result": {
#     "items_nuevos": 1500,
#     "tiempo_total": 125.5
#   }
# }
```

---

## 🐍 Cliente Python

Incluimos un cliente Python completo y fácil de usar.

### Instalación

```bash
# Copiar cliente a tu proyecto
cp /home/user/migradatosKOHA/api/cliente_api.py .

# O importar directamente
import sys
sys.path.append('/home/user/migradatosKOHA/api')
from cliente_api import KohaAPIClient
```

### Uso Básico

```python
from cliente_api import KohaAPIClient, ImportMode

# 1. Crear cliente
client = KohaAPIClient(
    base_url="http://localhost:8000",
    api_key="una-koha-api-key-segura-2025"
)

# 2. Verificar servidor
health = client.health_check()
print(f"Servidor: {health['status']}")

# 3. Importar archivo
job_id = client.import_file("MED.csv")
print(f"Trabajo creado: {job_id}")

# 4. Esperar a que complete (con progreso en consola)
resultado = client.wait_for_completion(job_id)

# 5. Ver resultados
print(f"✓ Completado!")
print(f"  Items nuevos: {resultado['result']['items_nuevos']}")
print(f"  Tiempo: {resultado['result']['tiempo_total']:.1f}s")
```

### Ejemplo Completo con Manejo de Errores

```python
from cliente_api import KohaAPIClient, ImportMode
import sys

def importar_con_validacion(archivo: str):
    """Importa un archivo validando primero."""

    client = KohaAPIClient(
        base_url="http://localhost:8000",
        api_key="una-koha-api-key-segura-2025"
    )

    try:
        # 1. Validar primero
        print(f"📋 Validando {archivo}...")
        validacion = client.validate_file(archivo)

        if not validacion['valid']:
            print(f"✗ Archivo inválido:")
            for error in validacion['errors']:
                print(f"  - {error}")
            return False

        print(f"✓ Archivo válido (calidad: {validacion['quality_score']}/100)")

        # 2. Importar
        print(f"\n📤 Importando a Koha...")
        job_id = client.import_file(archivo, mode=ImportMode.NORMAL)

        # 3. Esperar
        resultado = client.wait_for_completion(job_id, show_progress=True)

        # 4. Mostrar resultados
        print(f"\n✓ Importación completada!")
        print(f"  Items nuevos: {resultado['result']['items_nuevos']:,}")
        print(f"  Items actualizados: {resultado['result']['items_actualizados']:,}")
        print(f"  Tiempo total: {resultado['result']['tiempo_total']:.1f}s")

        return True

    except FileNotFoundError:
        print(f"✗ Error: Archivo no encontrado: {archivo}")
        return False
    except RuntimeError as e:
        print(f"✗ Error en importación: {e}")
        return False
    except Exception as e:
        print(f"✗ Error inesperado: {e}")
        return False

# Usar
if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Uso: python3 script.py <archivo.csv>")
        sys.exit(1)

    archivo = sys.argv[1]
    exito = importar_con_validacion(archivo)
    sys.exit(0 if exito else 1)
```

### Ejemplos del Cliente

```bash
# Ver ejemplos incluidos
python3 api/cliente_api.py ejemplo1  # Importación básica
python3 api/cliente_api.py ejemplo2  # Dry-run
python3 api/cliente_api.py ejemplo3  # Validación
python3 api/cliente_api.py ejemplo4  # Listar trabajos

# Usar CLI del cliente
python3 api/cliente_api.py import MED.csv
python3 api/cliente_api.py validate MED.csv
python3 api/cliente_api.py list
python3 api/cliente_api.py status <job_id>
```

---

## 🎯 Modos de Importación

### 1. Normal (Producción)

```python
client.import_file("MED.csv", mode=ImportMode.NORMAL)
```

- **Importa directamente a Koha**
- Modifica la base de datos
- Crea registros bibliográficos e items
- Reindexación automática

**Cuándo usar:** Importación real en producción

### 2. Dry-Run (Simulación)

```python
client.import_file("MED.csv", mode=ImportMode.DRY_RUN)
```

- **Simula** todo el proceso
- NO modifica base de datos
- Valida y genera MARCXML
- Útil para probar

**Cuándo usar:** Pruebas antes de importar

### 3. Validate Only (Solo Validación)

```python
resultado = client.validate_file("MED.csv")
```

- Solo valida estructura
- Calcula puntaje de calidad
- No procesa registros
- Muy rápido

**Cuándo usar:** Verificar archivos antes de enviar

---

## 📊 Monitoreo de Trabajos

### Estados de Trabajo

Un trabajo pasa por estos estados:

```
pending → validating → processing → completed
                                  ↘ failed
                                  ↘ cancelled
```

| Estado | Descripción |
|--------|-------------|
| `pending` | Trabajo creado, esperando procesamiento |
| `validating` | Validando estructura del archivo |
| `processing` | Importando registros a Koha |
| `completed` | Completado exitosamente |
| `failed` | Falló con error |
| `cancelled` | Cancelado por usuario |

### Tracking de Progreso

```python
import time

job_id = client.import_file("MED.csv")

while True:
    status = client.get_job_status(job_id)

    print(f"Estado: {status['status']}")
    print(f"Progreso: {status['progress']:.1f}%")
    print(f"Mensaje: {status['message']}")

    if status['status'] in ['completed', 'failed', 'cancelled']:
        break

    time.sleep(2)
```

### Listar Trabajos por Estado

```python
# Solo completados
completed = client.list_jobs(status=JobStatus.COMPLETED)

# Solo en proceso
processing = client.list_jobs(status=JobStatus.PROCESSING)

# Últimos 50
recent = client.list_jobs(limit=50)
```

---

## 🔔 Webhooks

Recibe notificaciones automáticas cuando un trabajo completa.

### Configurar Webhook

```python
job_id = client.import_file(
    "MED.csv",
    webhook_url="https://tu-servidor.com/api/webhook"
)
```

### Payload Enviado

```json
{
  "job_id": "20251107-103045-a1b2c3",
  "status": "completed",
  "filename": "MED.csv",
  "result": {
    "items_nuevos": 1500,
    "items_actualizados": 0,
    "tiempo_total": 125.5,
    "biblioteca": "MED"
  },
  "completed_at": "2025-11-07T10:32:50"
}
```

### Servidor Webhook Ejemplo (Flask)

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/api/webhook', methods=['POST'])
def webhook():
    data = request.json

    print(f"✓ Trabajo {data['job_id']} completado!")
    print(f"  Items: {data['result']['items_nuevos']}")
    print(f"  Tiempo: {data['result']['tiempo_total']}s")

    # Procesar según necesites
    # - Enviar email
    # - Actualizar dashboard
    # - Notificar Slack/Discord
    # etc.

    return jsonify({'status': 'received'}), 200

if __name__ == '__main__':
    app.run(port=5000)
```

---

## 🔒 Seguridad

### Best Practices

1. **API Keys Secretas**
   ```python
   # NO hagas esto:
   API_KEY = "123456"

   # Haz esto:
   import os
   API_KEY = os.environ.get('KOHA_API_KEY')
   ```

2. **HTTPS en Producción**
   ```bash
   # Usar proxy reverso (nginx/apache)
   # con certificados SSL/TLS
   ```

3. **Rate Limiting**
   ```python
   # Agregar limitación de requests
   from slowapi import Limiter

   limiter = Limiter(key_func=get_remote_address)
   app.state.limiter = limiter

   @app.post("/api/v1/import")
   @limiter.limit("10/minute")
   async def import_file(...):
       ...
   ```

4. **Validación de Archivos**
   ```python
   # Ya implementado en el servidor:
   # - Validación de extensión (.csv)
   # - Límite de tamaño
   # - Sanitización de nombres
   ```

5. **Logs de Auditoría**
   ```python
   # Registrar todas las operaciones
   logger.info(f"Import by {api_key[:8]}... : {filename}")
   ```

### Configuración Firewall

```bash
# Solo permitir desde IPs conocidas
sudo ufw allow from 192.168.1.0/24 to any port 8000

# O solo localhost (más seguro)
sudo ufw deny 8000
# Acceder vía SSH tunnel
```

---

## 🚀 Despliegue en Producción

### Opción 1: Systemd Service

```bash
# Crear servicio systemd
sudo nano /etc/systemd/system/koha-api.service
```

```ini
[Unit]
Description=Koha Import API Server
After=network.target

[Service]
Type=simple
User=koha
WorkingDirectory=/home/user/migradatosKOHA/api
ExecStart=/usr/bin/python3 -m uvicorn servidor_api:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

Environment=API_KEY=tu-api-key-super-secreta

[Install]
WantedBy=multi-user.target
```

```bash
# Activar servicio
sudo systemctl daemon-reload
sudo systemctl enable koha-api
sudo systemctl start koha-api
sudo systemctl status koha-api
```

### Opción 2: Docker

```dockerfile
# Dockerfile
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "servidor_api:app", "--host", "0.0.0.0", "--port", "8000"]
```

```bash
# Build y run
docker build -t koha-api .
docker run -d -p 8000:8000 \
  -v /ruta/uploads:/app/uploads \
  -e API_KEY=tu-api-key \
  koha-api
```

### Opción 3: Nginx Reverse Proxy

```nginx
# /etc/nginx/sites-available/koha-api
server {
    listen 80;
    server_name api.koha.tudominio.com;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;

        # Para uploads grandes
        client_max_body_size 100M;
    }
}
```

```bash
# Activar
sudo ln -s /etc/nginx/sites-available/koha-api /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## 🔧 Troubleshooting

### Problema 1: Servidor no inicia

**Síntoma:**
```
Error: uvicorn: command not found
```

**Solución:**
```bash
pip3 install -r api/requirements.txt
# O específicamente:
pip3 install uvicorn fastapi
```

### Problema 2: Error 401 Unauthorized

**Síntoma:**
```json
{"detail": "API key inválida"}
```

**Solución:**
```bash
# Verificar API key
curl -H "X-API-Key: una-koha-api-key-segura-2025" \
     http://localhost:8000/api/v1/health
```

### Problema 3: Archivo muy grande

**Síntoma:**
```
413 Request Entity Too Large
```

**Solución:**
```python
# Editar servidor_api.py
class APIConfig:
    MAX_FILE_SIZE = 100 * 1024 * 1024  # 100 MB
```

### Problema 4: Job se queda en "pending"

**Síntoma:**
Job nunca pasa a "processing"

**Solución:**
```bash
# Verificar logs del servidor
tail -f api/logs/api.log

# Reiniciar servidor
sudo systemctl restart koha-api
```

### Problema 5: Importación falla

**Síntoma:**
```json
{"status": "failed", "error": "..."}
```

**Solución:**
```bash
# Ver detalles del error
curl -X GET "http://localhost:8000/api/v1/jobs/{job_id}" \
     -H "X-API-Key: ..."

# Verificar logs
cat api/logs/import_{job_id}.log
```

### Logs Útiles

```bash
# Logs del servidor API
tail -f api/logs/api.log

# Logs de un trabajo específico
tail -f api/logs/import_20251107-103045-a1b2c3.log

# Logs de uvicorn
journalctl -u koha-api -f  # Si usas systemd
```

---

## 📚 Referencias Adicionales

- **Documentación FastAPI**: https://fastapi.tiangolo.com/
- **Koha Manual**: https://koha-community.org/manual/
- **OpenAPI Spec**: https://swagger.io/specification/
- **MARC21**: https://www.loc.gov/marc/bibliographic/

---

## 👥 Soporte

Para problemas o preguntas:

1. Ver documentación: `GUIA_USO_COMPLETA.md`
2. Revisar ejemplos: `python3 api/cliente_api.py`
3. Ver logs del servidor
4. Contactar al equipo de desarrollo

---

## 📄 Licencia

Universidad Nacional de Asunción - 2025

---

**¡API Lista para Importación Directa a Koha OPAC! 🎉**

```bash
# Inicio rápido:
cd /home/user/migradatosKOHA/api
./iniciar_servidor.sh

# Importar:
curl -X POST "http://localhost:8000/api/v1/import" \
     -H "X-API-Key: una-koha-api-key-segura-2025" \
     -F "file=@MED.csv"
```
