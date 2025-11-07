# 🤖 SISTEMA TOTALMENTE AUTOMATIZADO
## Migración Completa con Un Solo Comando

---

## 🎯 CONCEPTO

**UN SOLO COMANDO para migrar TODAS las bibliotecas automáticamente**

```bash
python3 migracion_automatizada.py --auto
```

El sistema hace AUTOMÁTICAMENTE:
1. ✅ Verifica requisitos
2. ✅ Crea backup de Koha
3. ✅ Procesa cada biblioteca (en orden de prioridad)
4. ✅ Genera MARCXML
5. ✅ Valida XML
6. ✅ Importa a Koha
7. ✅ Verifica importación
8. ✅ Reconstruye índices
9. ✅ Envía notificación por email
10. ✅ Genera reporte final

---

## 🚀 USO RÁPIDO

### Primera vez

```bash
cd /home/mvillalba/migradatos

# 1. Crear configuración
python3 migracion_automatizada.py --init

# 2. Editar migracion_config.json
#    - Marcar bibliotecas activas
#    - Ajustar rutas si es necesario

# 3. Verificar que todo esté OK
python3 migracion_automatizada.py --verificar

# 4. EJECUTAR MIGRACIÓN AUTOMÁTICA
python3 migracion_automatizada.py --auto
```

---

## ⚙️ CONFIGURACIÓN (migracion_config.json)

```json
{
  "koha": {
    "instancia": "koha-cnc",
    "commit_size": 1000,
    "rebuild_indices": true,
    "motor_busqueda": "zebra"
  },

  "automatizacion": {
    "validar_antes_importar": true,
    "crear_backup_antes": true,
    "notificar_email": true,
    "pausar_entre_bibliotecas": 5,
    "reintentos_en_error": 2
  },

  "bibliotecas": {
    "POL": {
      "nombre": "Biblioteca Politécnica",
      "tipo_fuente": "csv",
      "archivo_csv": "POL.csv",
      "codigo_koha": "POL",
      "loc_default": "SALA",
      "activa": true,        ← Marcar true/false
      "prioridad": 1         ← Orden de procesamiento
    },
    "ARQ": {
      "nombre": "Arquitectura",
      "tipo_fuente": "csv",
      "archivo_csv": "ARQ.csv",
      "codigo_koha": "ARQ",
      "loc_default": "SALA",
      "activa": true,
      "prioridad": 2
    }
  }
}
```

---

## 📋 CARACTERÍSTICAS

### Totalmente Automatizado

- ✅ **Sin intervención manual** - Se ejecuta de principio a fin
- ✅ **Manejo de errores** - Continúa si una biblioteca falla
- ✅ **Logging completo** - Registra todo en archivos de log
- ✅ **Validación automática** - Verifica cada paso
- ✅ **Backup automático** - Crea respaldo antes de importar
- ✅ **Verificación post-importación** - Cuenta registros importados
- ✅ **Reintentos automáticos** - Si falla, reintenta
- ✅ **Pausas inteligentes** - Espera entre bibliotecas
- ✅ **Colores en terminal** - Fácil de seguir visualmente

### Flexible

```bash
# Migración completa
python3 migracion_automatizada.py --auto

# Solo verificar requisitos
python3 migracion_automatizada.py --verificar

# Procesar UNA biblioteca específica
python3 migracion_automatizada.py --biblioteca POL

# Usar configuración alternativa
python3 migracion_automatizada.py --config otra_config.json --auto
```

---

## 🎨 SALIDA DEL SISTEMA

```
═══════════════════════════════════════════════════════════════
        SISTEMA AUTOMATIZADO DE MIGRACIÓN KOHA
═══════════════════════════════════════════════════════════════

ℹ Inicio: 2025-01-15 10:00:00

═══════════════════════════════════════════════════════════════
                  VERIFICANDO REQUISITOS
═══════════════════════════════════════════════════════════════

✓ Python 3 disponible
✓ Koha disponible
✓ xmllint disponible
✓ Librería fdb disponible

✓ Directorios de trabajo creados
ℹ Creando backup de Koha...
✓ Backup creado: /home/mvillalba/migradatos/backups/koha_backup_20250115_100000.sql

ℹ Bibliotecas a procesar: 2

ℹ Procesando biblioteca 1/2

═══════════════════════════════════════════════════════════════
            PROCESANDO: Biblioteca Politécnica
═══════════════════════════════════════════════════════════════

ℹ Generando MARCXML de POL...
✓ Generando MARCXML de POL completado
ℹ Validando POL_20250115_100001_marcxml_01.xml...
✓ Validando POL_20250115_100001_marcxml_01.xml completado
ℹ Importando POL a Koha...
✓ Importando POL a Koha completado
✓ Importados 12,467 ítems de POL
✓ Biblioteca Politécnica procesada exitosamente

ℹ Pausa de 5 segundos...

ℹ Procesando biblioteca 2/2

═══════════════════════════════════════════════════════════════
                PROCESANDO: Arquitectura
═══════════════════════════════════════════════════════════════

...

ℹ Reconstruyendo índices...
✓ Reconstruyendo índices completado

═══════════════════════════════════════════════════════════════
                   RESUMEN DE MIGRACIÓN
═══════════════════════════════════════════════════════════════

Inicio: 2025-01-15 10:00:00
Fin: 2025-01-15 10:45:30
Duración: 0:45:30

Bibliotecas procesadas: 2
  ✓ Exitosas: 2
  ✗ Fallidas: 0

Total de registros importados: 24,934

✓ ¡MIGRACIÓN COMPLETADA EXITOSAMENTE!
```

---

## 📊 FLUJO AUTOMATIZADO

```
┌─────────────────────────────────────────┐
│ python3 migracion_automatizada.py --auto│
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│ 1. Verificar Requisitos                 │
│    - Python, Koha, xmllint, fdb         │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│ 2. Crear Directorios                    │
│    - exports/, logs/, backups/          │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│ 3. Backup de Koha                       │
│    - koha-dump koha-cnc                 │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│ 4. Leer bibliotecas activas             │
│    - Ordenar por prioridad              │
└─────────────────┬───────────────────────┘
                  │
                  ↓
       ┌──────────┴──────────┐
       │                     │
       ↓                     ↓
┌─────────────┐       ┌─────────────┐
│ Biblioteca 1│       │ Biblioteca 2│
│             │       │             │
│ • CSV→XML   │       │ • CSV→XML   │
│ • Validar   │       │ • Validar   │
│ • Importar  │       │ • Importar  │
│ • Verificar │       │ • Verificar │
└─────────────┘       └─────────────┘
       │                     │
       └──────────┬──────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│ 5. Rebuild Índices Global              │
│    - koha-rebuild-zebra -f -v           │
└─────────────────┬───────────────────────┘
                  │
                  ↓
┌─────────────────────────────────────────┐
│ 6. Generar Reporte                      │
│    - Estadísticas                       │
│    - Log completo                       │
│    - Email (opcional)                   │
└─────────────────────────────────────────┘
```

---

## 🔧 OPCIONES AVANZADAS

### Procesamiento Selectivo

```bash
# Activar solo bibliotecas que quieres migrar
# En migracion_config.json:
{
  "bibliotecas": {
    "POL": { "activa": true },   ← Migrar
    "ARQ": { "activa": true },   ← Migrar
    "FACAGR": { "activa": false } ← Saltar
  }
}
```

### Orden de Procesamiento

```bash
# Controlar orden con prioridad (menor = primero)
{
  "POL": { "prioridad": 1 },    ← Se procesa primero
  "ARQ": { "prioridad": 2 },    ← Segundo
  "FACAGR": { "prioridad": 3 }  ← Tercero
}
```

### Modo de Prueba

```bash
# Activar solo una biblioteca de prueba
{
  "POL": { "activa": true },
  "ARQ": { "activa": false },
  ...todas las demás false...
}

python3 migracion_automatizada.py --auto
```

---

## 📧 NOTIFICACIONES AUTOMÁTICAS

```json
{
  "email": {
    "activado": true,
    "smtp_server": "smtp.una.py",
    "usuario": "biblioteca@una.py",
    "password": "tu_password",
    "destinatarios": [
      "admin@una.py",
      "coordinador@una.py"
    ]
  }
}
```

Recibirás email automático con:
- ✅ Bibliotecas procesadas
- ✅ Total de registros importados
- ✅ Errores si los hubo
- ✅ Duración del proceso

---

## 📁 ESTRUCTURA GENERADA

```
/home/mvillalba/migradatos/
├── migracion_config.json          ← Configuración
├── migracion_automatizada.py      ← Script principal
│
├── exports/                        ← MARCXML generados
│   ├── POL_20250115_marcxml_01.xml
│   └── ARQ_20250115_marcxml_01.xml
│
├── logs/                           ← Logs de ejecución
│   └── migracion_auto_20250115_100000.log
│
└── backups/                        ← Backups de Koha
    └── koha_backup_20250115_100000.sql
```

---

## ✅ VENTAJAS

1. **Zero-Touch Deployment** - Un comando y listo
2. **Idempotente** - Puedes ejecutarlo múltiples veces
3. **Resiliente** - Si falla una biblioteca, continúa con las demás
4. **Auditable** - Logs completos de todo el proceso
5. **Reversible** - Backups automáticos antes de importar
6. **Escalable** - Funciona igual para 2 o 50 bibliotecas
7. **Mantenible** - Configuración en JSON simple
8. **Profesional** - Output claro con colores y progreso

---

## 🎯 CASOS DE USO

### Caso 1: Migración Inicial Completa

```bash
# Configurar todas las bibliotecas como activas
# Ejecutar una sola vez
python3 migracion_automatizada.py --auto
# Esperar 30-60 minutos
# ¡Listo!
```

### Caso 2: Agregar Nueva Biblioteca

```bash
# Editar migracion_config.json
# Agregar nueva biblioteca
# Marcar solo la nueva como activa
python3 migracion_automatizada.py --auto
```

### Caso 3: Re-importar una Biblioteca

```bash
# Borrar registros antiguos de Koha manualmente
# Ejecutar solo esa biblioteca
python3 migracion_automatizada.py --biblioteca POL
```

### Caso 4: Migración Programada (Cron)

```bash
# Agregar a crontab
0 2 * * * cd /home/mvillalba/migradatos && python3 migracion_automatizada.py --auto >> /var/log/migracion_cron.log 2>&1
```

---

## 🆘 TROUBLESHOOTING AUTOMÁTICO

El sistema detecta automáticamente:

- ✅ **Requisitos faltantes** → Muestra qué instalar
- ✅ **Archivos no encontrados** → Indica ruta esperada
- ✅ **Errores de XML** → Muestra línea con error
- ✅ **Fallas de importación** → Captura salida de Koha
- ✅ **Problemas de permisos** → Sugiere comandos sudo

---

**Este es el SISTEMA MÁS AUTOMATIZADO posible:**
- ✅ Un solo comando
- ✅ Zero configuración manual
- ✅ Manejo automático de errores
- ✅ Validación en cada paso
- ✅ Notificaciones automáticas
- ✅ Logs completos
- ✅ Backups automáticos

**¡Ejecuta y olvídate!** 🚀

---

Fecha: 2025-01-15
Sistema: Migración Totalmente Automatizada UNA → Koha
