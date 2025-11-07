# 🔍 REPORTE: INVESTIGACIÓN BORRADO DE ÍNDICES ZEBRA
## Fecha del Incidente: 15 de octubre de 2025 - 23:58:39

---

## 📋 RESUMEN EJECUTIVO

**CAUSA IDENTIFICADA:** El script `sincronizar_arquitectura.sh` ejecutó un rebuild completo de Zebra con el flag `-f` (full), que por diseño **borra todos los índices** antes de reconstruirlos.

**IMPACTO:** OPAC quedó sin búsquedas funcionales hasta que se completó la reindexación.

**RIESGO:** ALTO - Puede volver a ocurrir cada vez que se ejecute este script.

---

## 🔎 DETALLES DE LA INVESTIGACIÓN

### Línea de Tiempo del Incidente

```
23:53:14 - Inicio del script sincronizar_arquitectura.sh
23:53:14 - Comienza importación masiva de registros ARQ
23:58:39 - Finaliza importación (9,993 registros en 311.87 segundos)
23:58:39 - Ejecuta: koha-rebuild-zebra -f -v koha-cnc
23:58:39 - ÍNDICES BORRADOS (por el flag -f)
23:58:40 - Comienza reconstrucción de índices
~00:10:00 - Índices parcialmente reconstruidos
```

### Evidencia Recopilada

1. **Archivo de log**: `/home/mvillalba/migradatos/logs/sync_ARQ_20251015_235314.log`
   - Última línea: `[2025-10-15 23:58:39] ✓ Importado: ARQ_20251015_marcxml_01.xml`

2. **Timestamp del directorio**:
   ```bash
   drwxr-xr-x 2 koha-cnc-koha koha-cnc-koha 4096 oct 15 23:58 shadow
   ```

3. **Comando responsable** (línea 124-129 de sincronizar_arquitectura.sh):
   ```bash
   log "   Reconstruyendo índices Zebra..."
   sudo koha-rebuild-zebra -f -v "$INSTANCIA_KOHA" 2>&1 | tee -a "$LOGFILE"
   ```

### Scripts Que Borran Índices

Se identificaron **3 scripts** con comandos peligrosos:

#### 1. `sincronizar_arquitectura.sh` (CULPABLE)
```bash
Línea 127: sudo koha-rebuild-zebra -f -v "$INSTANCIA_KOHA"
```
- **Flag `-f`**: Full rebuild - BORRA todos los índices primero
- **Cuándo se ejecuta**: Después de importar registros
- **Tiempo de reindexación**: 10-15 minutos para ~70,000 registros

#### 2. `optimizar_opac_performance.sh`
```bash
Línea 104-105:
sudo rm -rf /var/lib/koha/${INSTANCIA}/biblios/register/*
sudo rm -rf /var/lib/koha/${INSTANCIA}/biblios/shadow/*
```
- **Acción**: Borra manualmente los archivos de índice
- **Requiere confirmación manual**: NO (peligroso)

#### 3. `reindexar_koha.sh`
```bash
Línea 101-102:
rm -rf "/var/lib/koha/${INSTANCIA}/biblios/register/"*
rm -rf "/var/lib/koha/${INSTANCIA}/biblios/shadow/"*
```
- **Acción**: Limpieza profunda de índices
- **Tiene modo interactivo**: SÍ (requiere escribir "SI")

---

## ⚠️ PROBLEMAS IDENTIFICADOS

### 1. Sin Validación de Horario
Los scripts pueden ejecutarse en cualquier momento, incluso en horario de producción.

### 2. Flag `-f` Demasiado Agresivo
El flag `-f` de `koha-rebuild-zebra` es innecesario para actualizaciones normales:
- `-f` (full): Borra TODO y reconstruye desde cero
- `-b` (bibliographic): Solo actualiza registros modificados (más rápido, seguro)

### 3. Sin Notificación
No hay alertas cuando los índices se borran, dejando el OPAC inoperable silenciosamente.

### 4. Sin Respaldo
No se respaldan los índices antes de borrarlos.

---

## ✅ SOLUCIONES IMPLEMENTADAS

### Solución Inmediata
✓ Agente Experto en Zebra creado (`zebra_expert_agent.py`)
- Detecta índices vacíos
- Calcula porcentaje indexado
- Auto-repara problemas
- Monitoreo continuo disponible

### Uso del Agente
```bash
# Diagnóstico rápido
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --no-fix

# Auto-reparación
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py

# Monitoreo continuo
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --monitor
```

---

## 🛡️ MEDIDAS PREVENTIVAS RECOMENDADAS

### CRÍTICO - Implementar YA

#### 1. Modificar `sincronizar_arquitectura.sh`

**CAMBIO REQUERIDO:**
```bash
# ❌ PELIGROSO (actual):
sudo koha-rebuild-zebra -f -v "$INSTANCIA_KOHA"

# ✅ SEGURO (recomendado):
sudo koha-rebuild-zebra -b -v "$INSTANCIA_KOHA"
```

**Razón**: El flag `-b` solo reindexar registros modificados, NO borra todo.

**Comando para aplicar:**
```bash
sudo sed -i 's/koha-rebuild-zebra -f -v/koha-rebuild-zebra -b -v/g' /home/mvillalba/migradatos/sincronizar_arquitectura.sh
```

#### 2. Agregar Validación de Horario

Agregar al inicio de cada script de mantenimiento:

```bash
# Evitar ejecución en horario laboral (8am - 6pm)
HORA=$(date +%H)
if [ $HORA -ge 8 ] && [ $HORA -lt 18 ]; then
    echo "⚠️  ADVERTENCIA: No se recomienda ejecutar durante horario laboral"
    echo "   Horario permitido: 18:00 - 08:00"
    read -p "¿Desea continuar de todas formas? (s/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Ss]$ ]]; then
        echo "Cancelado por el usuario"
        exit 1
    fi
fi
```

#### 3. Implementar Modo de Respaldo de Índices

Antes de borrar índices, crear respaldo:

```bash
backup_indices() {
    local BACKUP_DIR="/var/backups/zebra/$(date +%Y%m%d_%H%M%S)"
    echo "Respaldando índices en: $BACKUP_DIR"
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp -r /var/lib/koha/koha-cnc/biblios "$BACKUP_DIR/"
    echo "✓ Respaldo completado"
}
```

#### 4. Agregar Notificaciones

Enviar alerta cuando se borren índices:

```bash
notificar_borrado() {
    echo "⚠️  ALERTA: Índices Zebra borrados - $(date)" | \
        tee -a /var/log/zebra_critical.log

    # Opcional: enviar email
    # echo "Índices borrados en $(hostname)" | \
    #     mail -s "ALERTA Zebra" admin@dominio.com
}
```

### IMPORTANTE - Implementar Esta Semana

#### 5. Monitoreo Automático con Agente

Agregar a cron para monitoreo cada hora:

```bash
sudo crontab -e
```

Agregar línea:
```
0 * * * * /usr/bin/python3 /home/mvillalba/migradatos/zebra_expert_agent.py --no-fix >> /var/log/zebra_monitor.log 2>&1
```

#### 6. Política de Mantenimiento

Crear política documentada:

**Horarios Permitidos:**
- Mantenimiento normal: 22:00 - 06:00
- Emergencias: Cualquier hora (con aprobación)

**Procedimiento Antes de Rebuild:**
1. Notificar a usuarios (si es horario laboral)
2. Respaldar índices actuales
3. Ejecutar con flag `-b` (no `-f`) salvo extrema necesidad
4. Monitorear con agente hasta completar reindexación

---

## 📊 ANÁLISIS DE IMPACTO

### Tiempo de Inactividad

| Etapa | Duración | Estado OPAC |
|-------|----------|-------------|
| Borrado de índices | Instantáneo | ❌ Sin búsquedas |
| Reindexación (0-50%) | 5-7 minutos | ⚠️ Resultados parciales |
| Reindexación (50-100%) | 5-7 minutos | ⚠️ Resultados incompletos |
| **TOTAL** | **~12 minutos** | **Servicio degradado** |

### Registros Afectados
- Total en BD: 73,249 registros
- Tiempo de reindexación completa: ~12 minutos
- Velocidad: ~6,100 registros/minuto

### Frecuencia del Problema
- **Última ocurrencia**: 15 oct 2025, 23:58
- **Patrón**: Cada vez que se ejecuta sincronizar_arquitectura.sh
- **Riesgo de recurrencia**: ALTO (hasta aplicar fix)

---

## 🔧 COMANDOS ÚTILES PARA VERIFICACIÓN

### Ver estado actual de índices
```bash
# Verificar tamaño de índices
du -sh /var/lib/koha/koha-cnc/biblios/

# Ver últimos archivos modificados
sudo find /var/lib/koha/koha-cnc/biblios/ -type f -exec stat -c '%y %n' {} \; | sort | tail -10

# Verificar porcentaje indexado
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --no-fix | grep "Porcentaje"
```

### Ver historial de reindexaciones
```bash
# Logs de sincronización
ls -lh /home/mvillalba/migradatos/logs/sync_*.log

# Ver última ejecución
tail -50 $(ls -t /home/mvillalba/migradatos/logs/sync_*.log | head -1)
```

### Verificar procesos activos
```bash
# Ver si hay reindexación en curso
ps aux | grep rebuild_zebra | grep -v grep

# Ver actividad de Zebra
sudo tail -f /var/log/koha/koha-cnc/zebra-output.log
```

---

## 📝 RECOMENDACIONES FINALES

### Prioridad CRÍTICA ⚡
1. **CAMBIAR flag `-f` por `-b` en sincronizar_arquitectura.sh**
   ```bash
   sudo sed -i 's/koha-rebuild-zebra -f -v/koha-rebuild-zebra -b -v/g' /home/mvillalba/migradatos/sincronizar_arquitectura.sh
   ```

2. **Verificar el cambio**
   ```bash
   grep "koha-rebuild-zebra" /home/mvillalba/migradatos/sincronizar_arquitectura.sh
   ```

### Prioridad ALTA 🔴
3. Agregar validación de horario a todos los scripts de mantenimiento
4. Implementar monitoreo automático con el agente Zebra
5. Crear respaldos automáticos de índices antes de mantenimiento

### Prioridad MEDIA 🟡
6. Documentar procedimientos de mantenimiento
7. Capacitar al equipo sobre el uso del agente experto
8. Establecer política de horarios de mantenimiento

### Prioridad BAJA 🟢
9. Implementar sistema de notificaciones por email
10. Crear dashboard de monitoreo en tiempo real

---

## 📞 CONTACTOS DE EMERGENCIA

**Si el OPAC queda sin búsquedas:**

1. Verificar estado:
   ```bash
   sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --no-fix
   ```

2. Auto-reparar:
   ```bash
   sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py
   ```

3. Reindexar manualmente (solo si agente falla):
   ```bash
   sudo koha-rebuild-zebra -b -v koha-cnc
   ```

---

## 📅 PRÓXIMOS PASOS

- [ ] Aplicar fix CRÍTICO del flag `-f` → `-b`
- [ ] Probar cambio en ambiente de prueba
- [ ] Implementar monitoreo automático
- [ ] Documentar procedimientos
- [ ] Capacitar equipo
- [ ] Revisar otros scripts con comandos peligrosos
- [ ] Establecer política de mantenimiento
- [ ] Crear plan de respaldo automatizado

---

**Reporte generado:** 16 de octubre de 2025
**Investigado por:** Agente de Análisis del Sistema
**Estado:** ✅ Causa identificada - ⚠️ Fix pendiente de aplicar
