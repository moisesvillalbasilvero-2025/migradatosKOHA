# AGENTE EXPERTO EN ZEBRA - MANUAL DE USO

## Descripción

El Agente Experto en Zebra es un sistema inteligente de diagnóstico, optimización y auto-reparación para el motor de búsqueda Zebra de Koha. Detecta y soluciona automáticamente problemas comunes del OPAC.

## Características Principales

- ✅ **Diagnóstico automático** de 5 componentes críticos
- 🔧 **Auto-reparación** inteligente de problemas detectados
- 📊 **Cálculo de porcentaje indexado** (DB vs Zebra)
- 📈 **Monitoreo continuo** opcional
- 📄 **Reportes JSON** detallados
- 🎨 **Interfaz con colores** para facilitar lectura

## Instalación

El agente ya está instalado en:
```
/home/mvillalba/migradatos/zebra_expert_agent.py
```

No requiere dependencias adicionales (usa solo bibliotecas estándar de Python).

## Uso Básico

### 1. Diagnóstico Completo con Auto-reparación (Modo por Defecto)

```bash
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py
```

Este modo:
- Ejecuta diagnóstico completo
- Si detecta problemas, intenta repararlos automáticamente
- Calcula porcentaje de indexación
- Genera reporte

### 2. Solo Diagnóstico (Sin Auto-reparación)

```bash
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --no-fix
```

Útil para:
- Ver el estado del sistema sin hacer cambios
- Verificar si hay problemas antes de decidir acciones
- Monitoreo regular

### 3. Monitoreo Continuo

```bash
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --monitor
```

Ejecuta diagnóstico cada 5 minutos en bucle infinito.
Para detener: `Ctrl+C`

### 4. Especificar Instancia de Koha

```bash
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --instance mi-koha
```

Por defecto usa `koha-cnc`.

## Componentes que Diagnostica

### 1. Proceso Zebra
- ✓ Verifica que zebrasrv esté corriendo
- ✓ Cuenta procesos activos
- ⚠️ Si no está corriendo, lo inicia automáticamente

### 2. Índices Zebra
- ✓ Verifica que existan los directorios de índices
- ✓ Verifica que estén poblados (tamaño > 100KB)
- ⚠️ Si están vacíos, lanza reindexación completa

### 3. Registros en Base de Datos
- ✓ Cuenta registros bibliográficos en MySQL
- ✓ Verifica que haya contenido para indexar

### 4. Memoria del Sistema
- ✓ Verifica memoria disponible (mínimo 500MB)
- ⚠️ Si es baja, limpia cache del sistema

### 5. Espacio en Disco
- ✓ Verifica uso de disco (alerta si > 90%)
- ✓ Muestra espacio disponible

### 6. Porcentaje de Indexación (NUEVO)
- 📊 Compara registros en DB vs registros indexados
- ✓ Calcula porcentaje exacto
- 🎯 Objetivo: 95% o más

## Interpretación de Resultados

### Estado: ✓ SISTEMA OK
- Todos los diagnósticos pasaron
- Porcentaje de indexación ≥ 95%
- OPAC funcionando correctamente

### Estado: ⚠️ REQUIERE ATENCIÓN
Posibles causas:
1. **Porcentaje indexado bajo** (< 95%)
   - Solución: Esperar a que termine reindexado actual
   - O ejecutar: `sudo koha-rebuild-zebra -f -a -b -v koha-cnc`

2. **Zebra no responde**
   - Solución: Reiniciar servicios
   - `sudo koha-restart-zebra koha-cnc`

3. **Memoria baja**
   - Solución: El agente limpia cache automáticamente
   - O manualmente: `sync && echo 3 > /proc/sys/vm/drop_caches`

4. **Índices corruptos**
   - Solución: Reindexar completamente
   - Ver sección "Solución de Problemas"

## Ejemplos de Salida

### Ejemplo 1: Sistema Funcionando Correctamente

```
============================================================
🚀 AGENTE EXPERTO ZEBRA - DIAGNÓSTICO COMPLETO
============================================================

🔍 Diagnosticando proceso Zebra...
✓ Zebra está corriendo (4 procesos)
🔍 Diagnosticando índices de Zebra...
✓ Índices poblados (947M)
🔍 Diagnosticando registros en base de datos...
✓ Registros en base de datos: 73249

------------------------------------------------------------
📊 RESUMEN DE DIAGNÓSTICO
------------------------------------------------------------
✓ OK - Proceso Zebra
✓ OK - Índices Zebra
✓ OK - Registros Koha
✓ OK - Memoria Sistema
✓ OK - Espacio Disco

📊 Calculando porcentaje de indexación...
  📚 Registros en base de datos: 73,249
  🔍 Registros en índice Zebra: 73,249
  ✓ Porcentaje indexado: 100.00%

🏁 AGENTE EXPERTO ZEBRA - FINALIZADO
📊 Estado final: ✓ SISTEMA OK
```

### Ejemplo 2: Problema Detectado y Reparado

```
⚠️  PROBLEMAS DETECTADOS:
  1. Índices están vacíos

============================================================
🔧 INICIANDO AUTO-REPARACIÓN
============================================================

🔧 Iniciando reindexación completa de Zebra...
⏳ Esto puede tomar varios minutos...
✓ Reindexación completada

✅ REPARACIONES APLICADAS
  1. Índices reconstruidos completamente
```

## Reportes Generados

Cada ejecución genera un reporte JSON en:
```
/home/mvillalba/migradatos/logs/zebra_report_YYYYMMDD_HHMMSS.json
```

Contiene:
- Timestamp de ejecución
- Estado de todos los componentes
- Problemas detectados
- Reparaciones aplicadas
- Estadísticas de indexación

## Logs

Los logs se guardan en:
```
/home/mvillalba/migradatos/logs/zebra_agent_YYYYMMDD.log
```

## Solución de Problemas Comunes

### Problema: "Porcentaje indexado: 0%"

**Causa:** Los índices no están respondiendo a consultas

**Soluciones:**
1. Verificar que Zebra esté corriendo:
   ```bash
   ps aux | grep zebrasrv
   ```

2. Reiniciar Zebra:
   ```bash
   sudo koha-restart-zebra koha-cnc
   ```

3. Reindexar completamente:
   ```bash
   sudo koha-rebuild-zebra -f -a -b -v koha-cnc
   ```

4. Verificar configuración:
   ```bash
   cat /etc/koha/sites/koha-cnc/koha-conf.xml | grep -A 5 zebra
   ```

### Problema: "Memoria baja"

**Solución automática:** El agente limpia cache

**Solución manual:**
```bash
free -m  # Ver memoria
sudo sync && sudo echo 3 > /proc/sys/vm/drop_caches  # Limpiar cache
```

### Problema: "Zebra no está corriendo"

**Solución automática:** El agente lo inicia

**Solución manual:**
```bash
sudo koha-start-zebra koha-cnc
```

### Problema: "Error en reindexación"

**Diagnóstico:**
```bash
sudo tail -100 /var/log/koha/koha-cnc/zebra-error.log
```

**Soluciones:**
1. Limpiar índices y reindexar:
   ```bash
   sudo koha-stop-zebra koha-cnc
   sudo rm -rf /var/lib/koha/koha-cnc/biblios/*
   sudo koha-start-zebra koha-cnc
   sudo koha-rebuild-zebra -f -a -b -v koha-cnc
   ```

2. Verificar permisos:
   ```bash
   sudo chown -R koha-cnc-koha:koha-cnc-koha /var/lib/koha/koha-cnc
   ```

## Integración con Cron (Monitoreo Automático)

Para ejecutar el agente automáticamente cada hora:

```bash
sudo crontab -e
```

Agregar:
```
# Agente Zebra - diagnóstico cada hora
0 * * * * /usr/bin/python3 /home/mvillalba/migradatos/zebra_expert_agent.py >> /var/log/zebra_agent_cron.log 2>&1
```

## Comandos Útiles Adicionales

### Ver estado actual rápido
```bash
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --no-fix | grep -E "(✓|✗|⚠|📊)"
```

### Ver solo porcentaje indexado
```bash
sudo python3 /home/mvillalba/migradatos/zebra_expert_agent.py --no-fix 2>&1 | grep -A 3 "Calculando porcentaje"
```

### Ver último reporte
```bash
cat $(ls -t /home/mvillalba/migradatos/logs/zebra_report_*.json | head -1) | python3 -m json.tool
```

### Verificar log diario
```bash
tail -f /home/mvillalba/migradatos/logs/zebra_agent_$(date +%Y%m%d).log
```

## Mejores Prácticas

1. **Ejecutar diagnóstico antes de cambios importantes**
   ```bash
   sudo python3 zebra_expert_agent.py --no-fix
   ```

2. **Monitorear después de importaciones masivas**
   ```bash
   sudo python3 zebra_expert_agent.py
   ```

3. **Revisar reportes semanalmente**
   ```bash
   ls -lh /home/mvillalba/migradatos/logs/zebra_report_*.json
   ```

4. **Mantener logs limpios** (más de 30 días)
   ```bash
   find /home/mvillalba/migradatos/logs -name "zebra_*" -mtime +30 -delete
   ```

## Preguntas Frecuentes

### ¿Cuánto tiempo toma la reindexación?
- Para ~73,000 registros: 5-10 minutos
- Depende de CPU, disco y complejidad de registros

### ¿Puedo ejecutar el agente mientras Zebra está indexando?
- Sí, con `--no-fix` es seguro
- Sin `--no-fix` puede interferir con el proceso

### ¿Qué significa "Porcentaje indexado: 0%" si índices están poblados?
- Los índices existen pero Zebra no los está sirviendo
- Posibles causas: configuración incorrecta, proceso colgado, índices corruptos

### ¿Cómo verifico el OPAC manualmente?
```bash
# Buscar en OPAC
curl "https://koha.cnc.una.py/cgi-bin/koha/opac-search.pl?q=test" | grep -c "result"

# Consultar Zebra directamente
echo "find @attr 1=4 test" | yaz-client localhost:9998/biblios
```

## Soporte

Para problemas no resueltos por el agente:

1. Revisar logs de Koha:
   ```bash
   sudo tail -100 /var/log/koha/koha-cnc/zebra-error.log
   sudo tail -100 /var/log/koha/koha-cnc/zebra-output.log
   sudo tail -100 /var/log/koha/koha-cnc/plack-error.log
   ```

2. Verificar servicios:
   ```bash
   sudo systemctl status koha-common
   ```

3. Consultar documentación oficial:
   - https://koha-community.org
   - https://wiki.koha-community.org/wiki/Zebra

## Changelog

### v1.0 (2025-10-16)
- ✅ Diagnóstico completo de 5 componentes
- ✅ Auto-reparación inteligente
- ✅ Cálculo de porcentaje indexado
- ✅ Reportes JSON
- ✅ Modo monitoreo continuo
- ✅ Logs con colores

---

**Desarrollado para:** Centro Nacional de Computación - Universidad Nacional de Asunción
**Mantenido por:** Sistema Automatizado de Migración Koha
