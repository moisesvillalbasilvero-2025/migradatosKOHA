# 🌐 GUÍA COMPLETA: API REST DEL DASHBOARD KOHA

**Universidad Nacional de Asunción**
**Entendiendo REST de forma práctica**

---

## 📚 Índice

1. [¿Qué es REST?](#qué-es-rest)
2. [Conceptos Fundamentales](#conceptos-fundamentales)
3. [La API de Tu Dashboard](#la-api-de-tu-dashboard)
4. [Ejemplos Prácticos](#ejemplos-prácticos)
5. [Casos de Uso Reales](#casos-de-uso-reales)
6. [Integración con Otros Sistemas](#integración-con-otros-sistemas)

---

## 🤔 ¿Qué es REST?

### Definición Simple

**REST** = **Forma estandarizada de comunicación entre programas** a través de internet.

### Analogía del Restaurante

| Concepto REST | Analogía Restaurante |
|---------------|---------------------|
| **API** | El menú completo |
| **Endpoint** | Un plato específico del menú |
| **Método HTTP (GET, POST)** | La acción (pedir, modificar) |
| **Request** (petición) | Tu orden al mesero |
| **Response** (respuesta) | El plato que te traen |
| **JSON** | El idioma en que está el menú |

### ¿Por Qué es Útil?

```
SIN REST:
  Programa A → [código específico complicado] → Programa B
  ❌ Solo estos dos programas pueden comunicarse
  ❌ Difícil de mantener
  ❌ Cada programa necesita código diferente

CON REST:
  Programa A → [HTTP/JSON estándar] → API REST → Base de Datos
  Programa B → [HTTP/JSON estándar] → API REST → Base de Datos
  Programa C → [HTTP/JSON estándar] → API REST → Base de Datos

  ✅ Cualquier programa puede conectarse
  ✅ Un solo código (la API)
  ✅ Lenguaje estándar (HTTP/JSON)
```

---

## 🎯 Conceptos Fundamentales

### 1. HTTP (HyperText Transfer Protocol)

Es el protocolo que usan los navegadores web. Tu API usa lo mismo.

**Componentes de una petición HTTP:**

```
GET /api/stats HTTP/1.1
│   │           │
│   │           └─ Versión del protocolo
│   └─ Endpoint (¿qué quiero?)
└─ Método (¿qué acción?)

Host: localhost:5000
```

### 2. Métodos HTTP (Verbos)

| Método | Acción | Ejemplo Mundo Real | Ejemplo API |
|--------|--------|-------------------|-------------|
| **GET** | Obtener/Leer | Leer un libro | `GET /api/stats` |
| **POST** | Crear nuevo | Escribir libro nuevo | `POST /api/biblioteca` |
| **PUT** | Actualizar todo | Reescribir libro completo | `PUT /api/biblioteca/123` |
| **PATCH** | Actualizar parcial | Corregir una página | `PATCH /api/biblioteca/123` |
| **DELETE** | Eliminar | Quemar libro | `DELETE /api/biblioteca/123` |

**En tu dashboard solo usamos GET** porque solo consultamos información (no modificamos nada).

### 3. Endpoints

Son las **URLs específicas** que hacen algo:

```
http://localhost:5000/api/stats
                      └─ Este es el endpoint

Piensa en cada endpoint como un "botón" que hace algo específico
```

### 4. JSON (JavaScript Object Notation)

Formato de datos que usan las APIs REST para intercambiar información:

```json
{
  "nombre": "Juan",
  "edad": 25,
  "ciudad": "Asunción",
  "activo": true,
  "hobbies": ["fútbol", "lectura"],
  "direccion": {
    "calle": "Av. España",
    "numero": 123
  }
}
```

**Reglas JSON:**
- Llaves `{}` = objeto/diccionario
- Corchetes `[]` = lista/array
- Comillas dobles `""` para texto
- Sin comillas para números
- `true`/`false` para booleanos
- Comas `,` para separar elementos

---

## 🔧 La API de Tu Dashboard

Tu dashboard expone **4 endpoints**:

### 📊 Endpoint 1: `/api/stats`

**Propósito:** Obtener estadísticas de bibliotecas

**Método:** GET

**URL completa:** `http://localhost:5000/api/stats`

**Respuesta:**

```json
{
  "bibliotecas": [
    {
      "codigo": "AGRO",
      "nombre": "Biblioteca de la Facultad de Ciencias Agrarias",
      "titulos": 37226,
      "ejemplares": 37226
    },
    {
      "codigo": "BCT",
      "nombre": "Biblioteca Central - Tesis",
      "titulos": 19298,
      "ejemplares": 19298
    }
  ],
  "totales": {
    "biblios": 191542,
    "items": 157208,
    "bibliotecas": 42
  }
}
```

**Usar desde terminal:**

```bash
curl http://localhost:5000/api/stats
```

**Usar desde navegador:**
Simplemente abre: http://localhost:5000/api/stats

**Usar desde Python:**

```python
import requests

response = requests.get('http://localhost:5000/api/stats')
data = response.json()

print(f"Total items: {data['totales']['items']}")
```

---

### 📝 Endpoint 2: `/api/logs`

**Propósito:** Obtener lista de logs recientes

**Método:** GET

**URL:** `http://localhost:5000/api/logs`

**Respuesta:**

```json
{
  "logs": [
    {
      "archivo": "maestro_20251031_143022.log",
      "fecha": "2025-10-31 14:30:22",
      "tamano": 15234,
      "ruta": "/home/mvillalba/migradatos/logs/maestro_20251031_143022.log"
    }
  ]
}
```

---

### 📥 Endpoint 3: `/api/importaciones`

**Propósito:** Obtener historial de importaciones

**Método:** GET

**URL:** `http://localhost:5000/api/importaciones`

**Respuesta:**

```json
{
  "importaciones": [
    {
      "codigo": "MED",
      "fecha": "2025-10-31 14:25:10",
      "archivo": "reporte_MED_20251031.txt"
    }
  ]
}
```

---

### 💻 Endpoint 4: `/api/estado`

**Propósito:** Obtener estado del sistema

**Método:** GET

**URL:** `http://localhost:5000/api/estado`

**Respuesta:**

```json
{
  "espacio_libre": "153G",
  "procesos_activos": 0,
  "hora_servidor": "2025-10-31 14:30:45",
  "koha_activo": true
}
```

---

## 💡 Ejemplos Prácticos

### Ejemplo 1: Consulta Simple con `curl`

```bash
# Obtener estadísticas
curl http://localhost:5000/api/stats

# Formatear JSON (más legible)
curl http://localhost:5000/api/stats | python3 -m json.tool

# Guardar en archivo
curl http://localhost:5000/api/stats > stats.json
```

### Ejemplo 2: Extraer Datos Específicos

**Con Python:**

```python
import requests

# Obtener datos
response = requests.get('http://localhost:5000/api/stats')
data = response.json()

# Extraer solo totales
totales = data['totales']
print(f"Biblios: {totales['biblios']:,}")
print(f"Items: {totales['items']:,}")

# Extraer top 5 bibliotecas
top5 = data['bibliotecas'][:5]
for i, bib in enumerate(top5, 1):
    print(f"{i}. {bib['codigo']:8} {bib['ejemplares']:>7,} items")
```

**Salida:**

```
Biblios: 191,542
Items: 157,208
1. AGRO      37,226 items
2. BCT       19,298 items
3. BC        15,997 items
4. ING       14,997 items
5. POL       12,467 items
```

### Ejemplo 3: Usando `jq` (Herramienta para JSON)

```bash
# Instalar jq (si no está)
sudo apt install jq

# Solo totales
curl -s http://localhost:5000/api/stats | jq '.totales'

# Solo códigos de bibliotecas
curl -s http://localhost:5000/api/stats | jq '.bibliotecas[].codigo'

# Top 3 bibliotecas
curl -s http://localhost:5000/api/stats | jq '.bibliotecas[:3]'

# Bibliotecas con más de 10,000 items
curl -s http://localhost:5000/api/stats | \
  jq '.bibliotecas[] | select(.ejemplares > 10000)'
```

### Ejemplo 4: Monitoreo Continuo

**Script Bash:**

```bash
#!/bin/bash
# monitor_api.sh

while true; do
    clear
    echo "MONITOREO EN TIEMPO REAL"
    echo "═══════════════════════════════════"

    # Obtener estado
    estado=$(curl -s http://localhost:5000/api/estado)

    # Extraer valores
    hora=$(echo "$estado" | jq -r '.hora_servidor')
    espacio=$(echo "$estado" | jq -r '.espacio_libre')

    echo "Hora:          $hora"
    echo "Espacio libre: $espacio"

    # Obtener totales
    totales=$(curl -s http://localhost:5000/api/stats | jq '.totales')
    items=$(echo "$totales" | jq '.items')

    echo "Total items:   $items"
    echo ""
    echo "Actualizando en 5s... (Ctrl+C para salir)"

    sleep 5
done
```

---

## 🎯 Casos de Uso Reales

### Caso 1: Dashboard Personalizado

Crear tu propio dashboard en Excel/Google Sheets que se actualice automáticamente:

**Python con openpyxl:**

```python
import requests
from openpyxl import Workbook

# Obtener datos
response = requests.get('http://localhost:5000/api/stats')
data = response.json()

# Crear Excel
wb = Workbook()
ws = wb.active
ws.title = "Estadísticas Koha"

# Encabezados
ws['A1'] = "Código"
ws['B1'] = "Biblioteca"
ws['C1'] = "Títulos"
ws['D1'] = "Ejemplares"

# Datos
for i, bib in enumerate(data['bibliotecas'], 2):
    ws[f'A{i}'] = bib['codigo']
    ws[f'B{i}'] = bib['nombre']
    ws[f'C{i}'] = bib['titulos']
    ws[f'D{i}'] = bib['ejemplares']

wb.save('estadisticas_koha.xlsx')
print("✓ Excel generado: estadisticas_koha.xlsx")
```

### Caso 2: Alertas Automáticas

Script que envía alerta si el espacio libre es bajo:

```python
import requests
import smtplib
from email.message import EmailMessage

def verificar_espacio():
    response = requests.get('http://localhost:5000/api/estado')
    data = response.json()

    espacio = data['espacio_libre']
    # Extraer número (ej: "153G" -> 153)
    numero = int(espacio.replace('G', ''))

    if numero < 20:  # Menos de 20 GB
        enviar_alerta(f"⚠ Espacio bajo: {espacio}")

def enviar_alerta(mensaje):
    # Configurar según tu servidor de email
    print(f"ALERTA: {mensaje}")
    # Aquí iría el código para enviar email

# Ejecutar cada hora
import time
while True:
    verificar_espacio()
    time.sleep(3600)  # 1 hora
```

### Caso 3: Integración con Sistema Externo

Sincronizar estadísticas con otro sistema:

```python
import requests
import json

class SincronizadorKoha:
    def __init__(self, api_base="http://localhost:5000"):
        self.api_base = api_base

    def obtener_estadisticas(self):
        """Obtiene estadísticas del dashboard"""
        response = requests.get(f"{self.api_base}/api/stats")
        return response.json()

    def sincronizar_con_sistema_externo(self):
        """Envía datos a sistema externo"""
        stats = self.obtener_estadisticas()

        # Enviar a sistema externo (ejemplo)
        sistema_externo_url = "http://sistema-central.una.py/api/koha"

        payload = {
            'fuente': 'Koha UNA',
            'timestamp': self.obtener_estado()['hora_servidor'],
            'datos': stats
        }

        # POST a sistema externo
        response = requests.post(sistema_externo_url, json=payload)

        if response.status_code == 200:
            print("✓ Sincronización exitosa")
        else:
            print(f"✗ Error: {response.status_code}")

    def obtener_estado(self):
        response = requests.get(f"{self.api_base}/api/estado")
        return response.json()

# Uso
sync = SincronizadorKoha()
sync.sincronizar_con_sistema_externo()
```

### Caso 4: Reporte Diario Automatizado

Script que genera reporte diario y lo envía por email:

```python
import requests
from datetime import datetime

def generar_reporte_diario():
    # Obtener datos
    stats = requests.get('http://localhost:5000/api/stats').json()
    estado = requests.get('http://localhost:5000/api/estado').json()
    importaciones = requests.get('http://localhost:5000/api/importaciones').json()

    # Crear reporte
    reporte = f"""
    REPORTE DIARIO - SISTEMA KOHA UNA
    {'='*50}
    Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

    TOTALES DEL SISTEMA:
    - Biblios:      {stats['totales']['biblios']:>10,}
    - Items:        {stats['totales']['items']:>10,}
    - Bibliotecas:  {stats['totales']['bibliotecas']:>10}

    TOP 5 BIBLIOTECAS:
    """

    for i, bib in enumerate(stats['bibliotecas'][:5], 1):
        reporte += f"\n    {i}. {bib['codigo']:8} {bib['ejemplares']:>7,} items"

    reporte += f"""

    ESTADO DEL SISTEMA:
    - Espacio libre: {estado['espacio_libre']}
    - Hora servidor: {estado['hora_servidor']}

    IMPORTACIONES RECIENTES:
    """

    if importaciones['importaciones']:
        for imp in importaciones['importaciones'][:5]:
            reporte += f"\n    - {imp['codigo']:6} {imp['fecha']}"
    else:
        reporte += "\n    (No hay importaciones recientes)"

    reporte += f"\n\n{'='*50}\n"

    # Guardar
    filename = f"reporte_{datetime.now().strftime('%Y%m%d')}.txt"
    with open(filename, 'w') as f:
        f.write(reporte)

    print(f"✓ Reporte generado: {filename}")
    print(reporte)

    return filename

# Ejecutar
generar_reporte_diario()
```

---

## 🔗 Integración con Otros Sistemas

### JavaScript (Node.js)

```javascript
const axios = require('axios');

async function obtenerEstadisticas() {
    try {
        const response = await axios.get('http://localhost:5000/api/stats');
        const data = response.data;

        console.log(`Total Items: ${data.totales.items.toLocaleString()}`);

        // Top 3
        data.bibliotecas.slice(0, 3).forEach((bib, i) => {
            console.log(`${i+1}. ${bib.codigo} - ${bib.ejemplares.toLocaleString()} items`);
        });
    } catch (error) {
        console.error('Error:', error.message);
    }
}

obtenerEstadisticas();
```

### PHP

```php
<?php
// Obtener estadísticas
$url = 'http://localhost:5000/api/stats';
$response = file_get_contents($url);
$data = json_decode($response, true);

// Mostrar totales
echo "Total Items: " . number_format($data['totales']['items']) . "\n";

// Top 3 bibliotecas
foreach (array_slice($data['bibliotecas'], 0, 3) as $i => $bib) {
    $num = $i + 1;
    echo "$num. {$bib['codigo']} - " . number_format($bib['ejemplares']) . " items\n";
}
?>
```

### Excel VBA

```vba
Sub ObtenerEstadisticasKoha()
    Dim http As Object
    Set http = CreateObject("MSXML2.XMLHTTP")

    ' Hacer petición
    http.Open "GET", "http://localhost:5000/api/stats", False
    http.Send

    ' Procesar respuesta
    Dim json As String
    json = http.responseText

    ' Parsear JSON (requiere biblioteca JSON)
    Dim data As Object
    Set data = JsonConverter.ParseJson(json)

    ' Escribir en Excel
    Range("A1").Value = "Total Items:"
    Range("B1").Value = data("totales")("items")
End Sub
```

---

## 🛠️ Herramientas Útiles

### 1. curl (Terminal)

```bash
# GET simple
curl http://localhost:5000/api/stats

# Con headers
curl -H "Content-Type: application/json" http://localhost:5000/api/stats

# Guardar en archivo
curl http://localhost:5000/api/stats -o stats.json

# Solo ver headers
curl -I http://localhost:5000/api/stats

# Modo verbose (debug)
curl -v http://localhost:5000/api/stats
```

### 2. jq (Procesador JSON)

```bash
# Instalar
sudo apt install jq

# Formatear JSON
curl -s http://localhost:5000/api/stats | jq '.'

# Extraer campo específico
curl -s http://localhost:5000/api/stats | jq '.totales.items'

# Filtrar array
curl -s http://localhost:5000/api/stats | jq '.bibliotecas[] | select(.ejemplares > 10000)'

# Mapear campos
curl -s http://localhost:5000/api/stats | jq '.bibliotecas[] | {codigo, items: .ejemplares}'
```

### 3. Postman (GUI)

Aplicación gráfica para probar APIs:
- Descargar: https://www.postman.com/downloads/
- Crear nueva request
- Método: GET
- URL: http://localhost:5000/api/stats
- Send

### 4. Python requests

```python
import requests

# GET básico
r = requests.get('http://localhost:5000/api/stats')

# Ver status
print(r.status_code)  # 200 = OK

# Ver headers
print(r.headers)

# Ver JSON
data = r.json()

# Con timeout
r = requests.get('http://localhost:5000/api/stats', timeout=5)

# Con manejo de errores
try:
    r = requests.get('http://localhost:5000/api/stats')
    r.raise_for_status()  # Lanza excepción si status != 200
    data = r.json()
except requests.exceptions.RequestException as e:
    print(f"Error: {e}")
```

---

## 📚 Recursos Adicionales

### Scripts de Ejemplo

He creado un script con **8 ejemplos prácticos**:

```bash
./ejemplos_api.sh
```

Incluye:
1. Obtener estadísticas
2. Extraer solo totales
3. Top 5 bibliotecas
4. Estado del sistema
5. Logs recientes
6. Importaciones
7. Uso desde Python
8. Monitoreo continuo

### Documentación Oficial

- **REST API Tutorial**: https://restfulapi.net/
- **HTTP Methods**: https://developer.mozilla.org/es/docs/Web/HTTP/Methods
- **JSON**: https://www.json.org/json-es.html
- **Python requests**: https://requests.readthedocs.io/

---

## 🎓 Glosario

| Término | Definición |
|---------|-----------|
| **API** | Application Programming Interface - Interfaz para que programas se comuniquen |
| **REST** | Representational State Transfer - Estilo arquitectónico para APIs |
| **Endpoint** | URL específica que realiza una acción |
| **HTTP** | HyperText Transfer Protocol - Protocolo de comunicación web |
| **JSON** | JavaScript Object Notation - Formato de datos |
| **GET** | Método HTTP para obtener datos |
| **Status Code** | Código numérico de respuesta (200=OK, 404=No encontrado, 500=Error) |
| **Request** | Petición del cliente al servidor |
| **Response** | Respuesta del servidor al cliente |

---

## ✅ Checklist de Aprendizaje

- [ ] Entiendo qué es REST
- [ ] Sé qué es un endpoint
- [ ] Conozco los métodos HTTP básicos
- [ ] Entiendo el formato JSON
- [ ] Puedo usar curl desde terminal
- [ ] He probado los 4 endpoints del dashboard
- [ ] Sé extraer datos con jq o Python
- [ ] He ejecutado ./ejemplos_api.sh
- [ ] Puedo crear un script que use la API

---

## 🎯 Próximos Pasos

1. **Practicar**: Ejecutar `./ejemplos_api.sh`
2. **Experimentar**: Crear tu propio script que use la API
3. **Integrar**: Conectar la API con algún sistema que uses
4. **Automatizar**: Crear reportes automáticos

---

**¡Ahora entiendes REST! 🎉**

Universidad Nacional de Asunción
Sistema Koha OPAC - 2025
