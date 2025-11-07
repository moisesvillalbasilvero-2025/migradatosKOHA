# 📚 SISTEMA DE IMPORTACIÓN A KOHA - ÍNDICE MAESTRO

**Universidad Nacional de Asunción**
**Documentación Completa - Todos los Métodos**

---

## 🎯 **Inicio Rápido - ¿Por Dónde Empezar?**

### **¿Primera vez aquí?**
👉 Lee primero: `COMPARACION_TODOS_LOS_METODOS.md`

### **¿Ya sabes qué método usar?**

| Método | Ir a |
|--------|------|
| **CSV Manual** | `README_SISTEMA_V3.md` |
| **Plan A: Firebird Directo** | `README_FIREBIRD_DIRECTO.md` |
| **Plan B: SSH + Firebird** | `README_PLAN_B_SSH.md` |

---

## 📖 **Documentación por Método**

### **Método CSV Manual (Original/Respaldo)**

Exportación manual de CSV, importación a Koha.

| Documento | Descripción | ¿Cuándo leer? |
|-----------|-------------|---------------|
| **README_SISTEMA_V3.md** | Índice del sistema V3 | Primero |
| **GUIA_COMPLETA_OPTIMIZADA.md** | Guía técnica completa | Implementación |
| **INICIO_RAPIDO_V3.txt** | Referencia rápida | Uso diario |

**Scripts principales**:
- `importar_optimizado.sh` - Importa CSV a Koha
- `agente_importador_v3.py` - Motor de importación
- `validador_csv.py` - Valida CSV antes de importar

**Comando básico**:
```bash
cp archivo.csv importar_aqui/
./importar_optimizado.sh
```

---

### **Plan A: Conexión Directa a Firebird**

Conexión TCP/IP directa a Firebird remoto (puerto 3050).

| Documento | Descripción | ¿Cuándo leer? |
|-----------|-------------|---------------|
| **README_FIREBIRD_DIRECTO.md** | Inicio rápido (5 pasos) | **Lee primero** |
| **GUIA_FIREBIRD_REMOTO.md** | Guía completa paso a paso | Implementación |
| **FIREBIRD_25_GDB.md** | Específico FB 2.5.7 (.gdb) | Si usas 2.5.7 |

**Scripts principales**:
- `firebird_directo_koha.py` - Sistema completo sincronización
- `test_firebird_remoto.py` - Prueba conexión interactiva

**Comandos básicos**:
```bash
# Instalar driver
pip3 install --break-system-packages fdb

# Probar conexión
./test_firebird_remoto.py

# Importar
./firebird_directo_koha.py --biblioteca CODIGO --incremental
```

**¿Cuándo usar?**
- ✅ Red local (LAN)
- ✅ Puerto 3050 accesible
- ✅ Actualizaciones frecuentes

---

### **Plan B: SSH + Firebird**

Conexión segura vía túnel SSH o importación remota.

| Documento | Descripción | ¿Cuándo leer? |
|-----------|-------------|---------------|
| **README_PLAN_B_SSH.md** | Guía completa Plan B | **Lee primero** |
| **COMPARACION_TODOS_LOS_METODOS.md** | Comparación detallada | Decidir método |

**2 sub-métodos**:

#### **B1: Túnel SSH a Firebird**
Crea túnel SSH, usa mismo script que Plan A.

**Scripts**:
- `tunel_firebird.sh` - Crear túnel
- `cerrar_tunel.sh` - Cerrar túnel
- `firebird_directo_koha.py` - Importación

**Comandos**:
```bash
# 1. Crear túnel
./tunel_firebird.sh CODIGO

# 2. Importar
./firebird_directo_koha.py --biblioteca CODIGO --incremental

# 3. Cerrar túnel
./cerrar_tunel.sh 3050
```

**¿Cuándo usar?**
- ✅ Internet público
- ✅ Máxima seguridad
- ✅ Solo puerto SSH abierto

#### **B2: Importación Remota SSH**
Ejecuta exportación en servidor remoto, descarga CSV.

**Scripts**:
- `importar_remoto_ssh.sh` - Todo en uno

**Comandos**:
```bash
./importar_remoto_ssh.sh CODIGO
```

**¿Cuándo usar?**
- ✅ Firebird NO acepta conexiones remotas
- ✅ Firewall muy restrictivo

---

## 🗂️ **Estructura de Archivos**

```
migradatos/
│
├── README_MASTER.md                  ← ESTE ARCHIVO (índice)
├── COMPARACION_TODOS_LOS_METODOS.md  ← Comparación completa
│
├── ─────────────────────────────────
│   CSV MANUAL (V3)
├── ─────────────────────────────────
├── README_SISTEMA_V3.md              ← Índice V3
├── GUIA_COMPLETA_OPTIMIZADA.md       ← Guía técnica CSV
├── INICIO_RAPIDO_V3.txt              ← Referencia rápida
├── importar_optimizado.sh            ← Script principal CSV
├── agente_importador_v3.py           ← Motor importación
├── validador_csv.py                  ← Validador CSV
├── dashboard.py                      ← Dashboard web + API
├── verificar_sistema.sh              ← Verificación sistema
│
├── ─────────────────────────────────
│   PLAN A - FIREBIRD DIRECTO
├── ─────────────────────────────────
├── README_FIREBIRD_DIRECTO.md        ← Inicio rápido Plan A
├── GUIA_FIREBIRD_REMOTO.md           ← Guía completa Plan A
├── FIREBIRD_25_GDB.md                ← Específico FB 2.5.7
├── firebird_directo_koha.py          ← Sistema sincronización
├── test_firebird_remoto.py           ← Prueba conexión
│
├── ─────────────────────────────────
│   PLAN B - SSH + FIREBIRD
├── ─────────────────────────────────
├── README_PLAN_B_SSH.md              ← Guía completa Plan B
├── tunel_firebird.sh                 ← B1: Crear túnel SSH
├── cerrar_tunel.sh                   ← B1: Cerrar túnel
├── importar_remoto_ssh.sh            ← B2: Importación remota
│
├── ─────────────────────────────────
│   APIS Y UTILIDADES
├── ─────────────────────────────────
├── GUIA_API_REST.md                  ← Guía API REST
├── ejemplos_api.sh                   ← Ejemplos API
│
├── ─────────────────────────────────
│   DIRECTORIOS
├── ─────────────────────────────────
├── importar_aqui/                    ← CSV para importar
├── exports/                          ← Archivos exportados
├── logs/                             ← Logs de importación
├── _obsoletos/                       ← Scripts antiguos
└── temp_remoto_*/                    ← Temporales SSH
```

---

## 🎯 **Flujo de Decisión - ¿Qué Método Usar?**

```
┌─────────────────────────────────────┐
│ ¿Qué tipo de conexión tienes?       │
└──────────────┬──────────────────────┘
               │
        ┌──────┴──────┐
        │             │
    [LAN/Local]   [Internet]
        │             │
        ▼             ▼
  ┌──────────┐  ┌──────────┐
  │ PLAN A   │  │ ¿Puerto  │
  │ Directo  │  │ 3050     │
  │          │  │ abierto? │
  └──────────┘  └────┬─────┘
                     │
              ┌──────┴──────┐
              │             │
           [Sí]          [No]
              │             │
              ▼             ▼
        ┌──────────┐  ┌──────────┐
        │ PLAN B1  │  │ PLAN B2  │
        │ Túnel SSH│  │ SSH      │
        │          │  │ Remoto   │
        └──────────┘  └──────────┘

        ┌──────────────────────┐
        │ Respaldo SIEMPRE:    │
        │ CSV Manual           │
        └──────────────────────┘
```

---

## 📊 **Comparación Rápida**

| Aspecto | CSV Manual | Plan A | Plan B1 | Plan B2 |
|---------|------------|--------|---------|---------|
| **Setup** | ⭐ Simple | ⭐⭐ Fácil | ⭐⭐⭐ Medio | ⭐⭐⭐ Medio |
| **Uso** | ⭐⭐ Manual | ⭐ Auto | ⭐⭐ Auto | ⭐ Auto |
| **Velocidad** | ⭐⭐ Media | ⭐⭐⭐ Alta | ⭐⭐⭐ Alta | ⭐⭐ Media |
| **Seguridad** | N/A | ⭐⭐ Media | ⭐⭐⭐ Alta | ⭐⭐⭐ Alta |
| **Automático** | ❌ No | ✅ Sí | ✅ Sí | ✅ Sí |
| **Incremental** | ❌ No | ✅ Sí | ✅ Sí | ⚠️ Parcial |

Ver detalles completos en: `COMPARACION_TODOS_LOS_METODOS.md`

---

## 🚀 **Guía de Implementación Paso a Paso**

### **Fase 1: Preparación (Día 1)**

```bash
# 1. Clonar/actualizar sistema
cd /home/mvillalba/migradatos
git pull  # Si usas git

# 2. Verificar sistema
./verificar_sistema.sh

# 3. Leer documentación
less COMPARACION_TODOS_LOS_METODOS.md
```

### **Fase 2: Setup Básico (Día 2-3)**

**Opción 1: Empezar con CSV Manual**
```bash
# Leer guía
less README_SISTEMA_V3.md

# Configurar
mkdir -p importar_aqui exports logs

# Probar con CSV de ejemplo
cp ejemplo.csv importar_aqui/
./importar_optimizado.sh
```

**Opción 2: Directo a Plan A/B**
```bash
# Leer guía según tu red
less README_FIREBIRD_DIRECTO.md    # LAN
less README_PLAN_B_SSH.md          # Internet

# Instalar dependencias
pip3 install --break-system-packages fdb

# Probar conexión
./test_firebird_remoto.py
```

### **Fase 3: Producción (Semana 2)**

```bash
# 1. Primera importación real
./firebird_directo_koha.py --biblioteca CODIGO

# 2. Configurar automático (cron)
crontab -e
# Agregar línea según método

# 3. Monitorear logs
tail -f logs/sync_*.log
```

### **Fase 4: Optimización (Semana 3-4)**

```bash
# 1. Activar modo incremental
./firebird_directo_koha.py --biblioteca CODIGO --incremental

# 2. Dashboard para monitoreo
./dashboard.py
# Abrir: http://localhost:8080

# 3. Agregar más bibliotecas
nano firebird_directo_koha.py  # Agregar servidores
```

---

## 🧪 **Testing y Validación**

### **Probar CSV Manual**
```bash
# 1. Validar CSV
./validador_csv.py archivo.csv

# 2. Importar en test
./importar_optimizado.sh archivo.csv

# 3. Verificar en Koha
# Buscar registros importados
```

### **Probar Plan A**
```bash
# 1. Probar conexión
./test_firebird_remoto.py

# 2. Test de configuración
./firebird_directo_koha.py --test

# 3. Importar muestra (primeros 10 registros)
# Editar firebird_directo_koha.py:
#   query = "SELECT FIRST 10 ..."
./firebird_directo_koha.py --biblioteca CODIGO
```

### **Probar Plan B1 (Túnel)**
```bash
# 1. Crear túnel
./tunel_firebird.sh CODIGO

# 2. Verificar túnel activo
lsof -i :3050

# 3. Probar conexión
./test_firebird_remoto.py
# Host: localhost, Puerto: 3050

# 4. Cerrar
./cerrar_tunel.sh 3050
```

### **Probar Plan B2 (Remoto)**
```bash
# 1. Verificar SSH
ssh usuario@servidor exit

# 2. Verificar fdb en remoto
ssh usuario@servidor "python3 -c 'import fdb; print(fdb.__version__)'"

# 3. Importación remota
./importar_remoto_ssh.sh CODIGO
```

---

## 📈 **Monitoreo y Mantenimiento**

### **Dashboard Web**
```bash
# Iniciar dashboard
./dashboard.py

# Abrir navegador
http://localhost:8080

# API REST disponible:
#   /api/stats          - Estadísticas
#   /api/logs           - Logs recientes
#   /api/importaciones  - Historial
```

### **Logs**
```bash
# Ver logs en tiempo real
tail -f logs/sync_*.log

# Buscar errores
grep -i error logs/*.log

# Últimas importaciones
ls -lht logs/ | head
```

### **Estado del Sistema**
```bash
# Verificación completa
./verificar_sistema.sh

# Estado Firebird (Plan A)
./firebird_directo_koha.py --status

# Túneles activos (Plan B1)
./cerrar_tunel.sh  # Sin args lista todos
```

---

## 🆘 **Troubleshooting Rápido**

### **"No puedo conectar a Firebird"**
```bash
# Diagnóstico:
ping <IP>                    # ¿Red OK?
telnet <IP> 3050            # ¿Puerto abierto?
./test_firebird_remoto.py   # ¿Credenciales OK?

# Solución:
# Si solo SSH funciona → Usar Plan B
# Si nada funciona → Usar CSV Manual
```

### **"Importación falla"**
```bash
# Ver último log
tail -100 logs/sync_*.log | less

# Validar CSV (si usas CSV)
./validador_csv.py archivo.csv

# Probar con muestra pequeña
# Editar query para "SELECT FIRST 10..."
```

### **"Muy lento"**
```bash
# Usar modo incremental
./firebird_directo_koha.py --biblioteca X --incremental

# Dividir en lotes (CSV)
split -l 1000 archivo.csv lote_

# Sincronizar de noche (cron)
crontab -e
0 2 * * * ...
```

---

## 📚 **Documentación Adicional**

### **APIs y Integración**
- `GUIA_API_REST.md` - API REST del dashboard
- `ejemplos_api.sh` - Ejemplos prácticos API

### **Versiones Antiguas**
- `_obsoletos/` - Scripts V1 y V2 (referencia)

### **Documentación Externa**
- [Koha Manual](https://koha-community.org/manual/)
- [Firebird Documentation](https://firebirdsql.org/en/documentation/)
- [MARC21 Reference](https://www.loc.gov/marc/)

---

## 🎓 **Capacitación**

### **Para Operadores (Uso Diario)**
**Leer**:
1. Este archivo (README_MASTER.md)
2. INICIO_RAPIDO_V3.txt (si CSV)
3. README_FIREBIRD_DIRECTO.md pasos 4-5 (si Plan A/B)

**Aprender**:
- Ejecutar importación manual
- Ver logs
- Verificar resultados en Koha

### **Para Administradores (Setup)**
**Leer**:
1. COMPARACION_TODOS_LOS_METODOS.md
2. Documentación específica del método elegido
3. GUIA_COMPLETA_OPTIMIZADA.md (técnico)

**Aprender**:
- Configurar servidores
- Troubleshooting
- Monitoreo y alertas

### **Para Desarrolladores**
**Leer**:
- Código fuente comentado
- GUIA_API_REST.md
- Documentación técnica completa

**Aprender**:
- Arquitectura del sistema
- Extensión de funcionalidades
- Integración con otros sistemas

---

## ✅ **Checklist Post-Implementación**

- [ ] Método principal funcionando
- [ ] CSV Manual documentado como respaldo
- [ ] Cron configurado (si automático)
- [ ] Logs monitoreados
- [ ] Dashboard accesible (opcional)
- [ ] Equipo capacitado
- [ ] Documentación actualizada con detalles locales
- [ ] Procedimientos de emergencia definidos
- [ ] Contactos IT documentados
- [ ] Backup de Koha configurado

---

## 🏆 **Mejores Prácticas**

1. **Siempre mantén CSV Manual como respaldo**
   - Documéntalo aunque no lo uses
   - Pruébalo trimestralmente

2. **Empieza simple, crece gradualmente**
   - Primera biblioteca con método elegido
   - Monitorea una semana
   - Expande a más bibliotecas

3. **Monitorea activamente**
   - Revisa logs semanalmente
   - Dashboard siempre visible
   - Alertas configuradas

4. **Documenta tu configuración específica**
   - Crea archivo LOCAL_CONFIG.md
   - Incluye IPs, usuarios (no passwords)
   - Procedimientos específicos

5. **Capacita múltiples personas**
   - No dependas de una sola persona
   - Documentación accesible
   - Procedimientos claros

---

## 📞 **Soporte**

### **Documentación**
- Este sistema: Ver archivos README_*.md
- Koha: https://koha-community.org/
- Firebird: https://firebirdsql.org/

### **Logs y Debugging**
```bash
# Todos los logs en:
ls -lh logs/

# Activar debug (editar scripts)
# En Python: logging.DEBUG
# En Bash: set -x
```

### **Comunidad**
- Koha Community: https://koha-community.org/support/
- Firebird Community: https://firebirdsql.org/en/support/

---

## 🎯 **Resumen Ejecutivo**

**Sistema completo de importación a Koha con 3 métodos**:

1. **CSV Manual**: Respaldo garantizado, siempre funciona
2. **Plan A (Directo)**: Óptimo para LAN, máximo rendimiento
3. **Plan B (SSH)**: Óptimo para Internet, máxima seguridad

**Características**:
- ✅ 100% automatizable
- ✅ Sincronización incremental
- ✅ Múltiples servidores Firebird
- ✅ Logs de auditoría completos
- ✅ Dashboard web + API REST
- ✅ Recuperación automática de errores
- ✅ Documentación completa

**Inversión**:
- Tiempo setup: 1-2 semanas
- Costo: $0 (software libre)
- Ahorro: 4-8 horas/semana de trabajo manual

**¡Sistema listo para producción! 🚀**

---

**Universidad Nacional de Asunción - 2025**

**Desarrollado para el Sistema de Bibliotecas**

**Versión**: 3.0 + Plan A + Plan B
**Última actualización**: 2025-01-31
