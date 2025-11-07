# 🏛️ SINCRONIZACIÓN AUTOMATIZADA
## Facultad de Arquitectura, Diseño y Arte

---

## 📊 ANÁLISIS DE DATOS ARQ

### Archivo: ARQ.csv

**Estadísticas:**
- **Total de registros:** 9,710
- **Tamaño:** 8.5 MB
- **Encoding:** UTF-8
- **Delimitador:** `;` (punto y coma)
- **Código biblioteca:** `ARQ`

### Tipos de Material

| Tipo | Cantidad (estimado) |
|------|---------------------|
| REVISTA | ~40% |
| MONOGRAFIA | ~55% |
| Otros | ~5% |

### Características Especiales

1. **Muchas revistas internacionales:**
   - Francés (L'Architecture d'ajourd'Hui)
   - Inglés (Spaces, Kitchens & Bahts)
   - Alemán (AW - Architektur + Wohnwelt)
   - Español (Arquna, Mandu'a)

2. **Materias específicas:**
   - Arquitectura
   - Diseño
   - Urbanismo
   - Artes visuales
   - Moda

3. **Signaturas especiales:**
   - Sistema propio: `PP/Int/XXX/País`
   - Clasificación Dewey: `7XX` (artes), `711` (urbanismo), `728` (vivienda)

---

## 🚀 SISTEMA DE SINCRONIZACIÓN

### ¿Qué hace el script?

El archivo `sincronizar_arquitectura.sh` automatiza **TODO** el proceso:

```
┌──────────────────┐
│  ARQ.csv (9,710) │
│  registros       │
└────────┬─────────┘
         │
         ▼
┌────────────────────┐
│ 1. Genera MARCXML  │  ← opac_exportar.py
│    (streaming)     │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ 2. Valida XML      │  ← xmllint
│    (bien formado)  │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ 3. Importa a Koha  │  ← bulkmarcimport.pl
│    (lotes 1000)    │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ 4. Rebuild índices │  ← koha-rebuild-zebra
│    (búsqueda)      │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ 5. Verifica        │  ← SQL queries
│    (cuenta)        │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ ✅ SINCRONIZADO    │
│    en OPAC         │
└────────────────────┘
```

---

## ⚡ USO RÁPIDO

### Ejecución Manual (Primera Vez)

```bash
cd /home/mvillalba/migradatos

# Ejecutar sincronización
./sincronizar_arquitectura.sh

# Monitorear progreso (desde otra terminal)
tail -f logs/sync_ARQ_*.log
```

### Salida Esperada

```
╔═══════════════════════════════════════════════════════════╗
║  SINCRONIZACIÓN AUTOMATIZADA - Facultad de Arquitectura
╚═══════════════════════════════════════════════════════════╝

[2025-01-15 15:30:00] 📋 PASO 1/6: Verificaciones previas
[2025-01-15 15:30:01] ✓ Archivo CSV encontrado
[2025-01-15 15:30:01]    Total de registros: 9710

[2025-01-15 15:30:01] 🔄 PASO 2/6: Generando MARCXML
[2025-01-15 15:30:03] ✓ MARCXML generado: 2 archivo(s)
[2025-01-15 15:30:03]    - ARQ_20250115_marcxml_01.xml (4.2M)
[2025-01-15 15:30:03]    - ARQ_20250115_marcxml_02.xml (3.8M)

[2025-01-15 15:30:03] ✓ PASO 3/6: Validando MARCXML
[2025-01-15 15:30:05] ✓ Validación completada

[2025-01-15 15:30:05] 📥 PASO 4/6: Importando a Koha
[2025-01-15 15:35:20] ✓ Importación completada

[2025-01-15 15:35:20] 🔍 PASO 5/6: Reconstruyendo índices
[2025-01-15 15:40:15] ✓ Índices reconstruidos

[2025-01-15 15:40:15] ✓ PASO 6/6: Verificación
[2025-01-15 15:40:16]    Total de títulos en Koha: 9,710
[2025-01-15 15:40:16]    Total de ejemplares: 9,710

✅ SINCRONIZACIÓN COMPLETADA EXITOSAMENTE
```

**Tiempo estimado:** 10-15 minutos

---

## 🔄 AUTOMATIZACIÓN (CRON)

### Sincronización Diaria Automática

```bash
# Editar crontab
crontab -e

# Agregar línea para sincronizar cada día a las 2 AM
0 2 * * * /home/mvillalba/migradatos/sincronizar_arquitectura.sh >> /var/log/sync_arq.log 2>&1

# O cada 6 horas
0 */6 * * * /home/mvillalba/migradatos/sincronizar_arquitectura.sh >> /var/log/sync_arq.log 2>&1

# Guardar y salir (Ctrl+X, Y, Enter)
```

### Verificar Cron Configurado

```bash
# Ver tareas cron activas
crontab -l

# Ver logs de ejecuciones
ls -lth /home/mvillalba/migradatos/logs/sync_ARQ_*.log

# Ver última ejecución
tail -100 /home/mvillalba/migradatos/logs/sync_ARQ_*.log | less
```

---

## 📧 NOTIFICACIONES POR EMAIL (OPCIONAL)

### Configurar Email

Editar `sincronizar_arquitectura.sh` líneas 30-32:

```bash
EMAIL_NOTIF="tu_email@una.py"
ENVIAR_EMAIL=true
```

Instalar mailutils si no está:

```bash
sudo apt-get install mailutils
```

---

## ✅ VERIFICACIÓN POST-SINCRONIZACIÓN

### En el OPAC

```
1. Ir a: http://tu-koha.una.py/cgi-bin/koha/opac-search.pl
2. Buscar: "arquitectura"
3. Filtrar por biblioteca: "ARQ"
4. Verificar que aparecen registros
5. Abrir un registro y verificar datos completos
```

### En la Base de Datos

```bash
# Contar títulos de ARQ
sudo koha-mysql koha-cnc -e "
  SELECT COUNT(DISTINCT biblionumber)
  FROM items
  WHERE homebranch = 'ARQ'
"

# Ver distribución por tipo de material
sudo koha-mysql koha-cnc -e "
  SELECT itype, COUNT(*) as cantidad
  FROM items
  WHERE homebranch = 'ARQ'
  GROUP BY itype
"

# Ver algunos títulos
sudo koha-mysql koha-cnc -e "
  SELECT
    biblio.biblionumber,
    LEFT(biblio.title, 60) as titulo,
    items.barcode
  FROM biblio
  JOIN items ON biblio.biblionumber = items.biblionumber
  WHERE items.homebranch = 'ARQ'
  LIMIT 10
"
```

---

## 🔧 CONFIGURACIÓN AVANZADA

### Modificar Script

El script es completamente configurable. Editar líneas 24-35:

```bash
BIBLIOTECA="ARQ"
NOMBRE_BIBLIOTECA="Facultad de Arquitectura, Diseño y Arte"
CSV_INPUT="/home/mvillalba/migradatos/ARQ.csv"
LOC_DEFAULT="SALA"
```

### Parámetros de Importación

Cambiar línea ~180:

```bash
-commit 1000    # Commits cada 1000 registros
-split-by 5000  # Divide MARCXML cada 5000 registros
```

---

## 📊 DASHBOARD DE ESTADO

### Script de Monitoreo

```bash
#!/bin/bash
# Ver estado de sincronización

echo "═══════════════════════════════════════════════════"
echo "ESTADO DE SINCRONIZACIÓN - ARQUITECTURA"
echo "═══════════════════════════════════════════════════"
echo ""

# Última sincronización
ULTIMO_LOG=$(ls -t /home/mvillalba/migradatos/logs/sync_ARQ_*.log 2>/dev/null | head -1)

if [ -n "$ULTIMO_LOG" ]; then
    echo "Última sincronización:"
    echo "  Archivo: $(basename $ULTIMO_LOG)"
    echo "  Fecha: $(stat -c %y "$ULTIMO_LOG" | cut -d'.' -f1)"
    echo ""

    # Verificar si fue exitosa
    if grep -q "EXITOSA" "$ULTIMO_LOG"; then
        echo "  Estado: ✅ EXITOSA"
    else
        echo "  Estado: ❌ CON ERRORES"
    fi
    echo ""
fi

# Registros en Koha
TOTAL=$(sudo koha-mysql koha-cnc -N -e "
    SELECT COUNT(DISTINCT biblionumber)
    FROM items
    WHERE homebranch = 'ARQ'
" 2>/dev/null || echo "0")

echo "Registros en Koha:"
echo "  Total de títulos: $TOTAL"
echo ""

# Próxima sincronización programada
echo "Sincronización programada:"
crontab -l 2>/dev/null | grep sincronizar_arquitectura || echo "  No hay cron configurado"
echo ""
echo "═══════════════════════════════════════════════════"
```

Guardar como `estado_sincronizacion.sh` y ejecutar:

```bash
chmod +x estado_sincronizacion.sh
./estado_sincronizacion.sh
```

---

## 🆘 TROUBLESHOOTING

### Error: "No se encontró archivo CSV"

```bash
# Verificar ubicación
ls -lh /home/mvillalba/migradatos/ARQ.csv

# Si está en otro lugar, editar script línea 26
CSV_INPUT="/ruta/correcta/ARQ.csv"
```

### Error: "Falló importación a Koha"

```bash
# Verificar que biblioteca ARQ existe
sudo koha-mysql koha-cnc -e "SELECT * FROM branches WHERE branchcode='ARQ'"

# Si no existe, crear en Koha:
# Administration > Libraries > New library
# Code: ARQ
# Name: Facultad de Arquitectura, Diseño y Arte
```

### Error: "Índices no se reconstruyen"

```bash
# Verificar motor de búsqueda
sudo koha-shell koha-cnc -c "perl -e 'use C4::Context; print C4::Context->preference(\"SearchEngine\")'"

# Reconstruir manualmente
sudo koha-rebuild-zebra -f -v koha-cnc
```

---

## 📈 MÉTRICAS Y RENDIMIENTO

### Tiempos Estimados (9,710 registros)

| Paso | Tiempo |
|------|--------|
| Generar MARCXML | ~2 min |
| Validar XML | ~10 seg |
| Importar a Koha | ~5-8 min |
| Rebuild índices | ~2-3 min |
| **TOTAL** | **~10-15 min** |

### Recursos

- **CPU:** ~20-30% durante importación
- **RAM:** ~500 MB
- **Disco:** ~10 MB MARCXML + logs

---

## ✅ CHECKLIST DE PRIMERA SINCRONIZACIÓN

- [ ] Archivo ARQ.csv en `/home/mvillalba/migradatos/`
- [ ] Biblioteca ARQ creada en Koha
- [ ] Ubicaciones (SALA, REF, etc.) configuradas
- [ ] Tipos de ítem (BK, MG, etc.) configurados
- [ ] Script `sincronizar_arquitectura.sh` con permisos +x
- [ ] Ejecutar primera sincronización manual
- [ ] Verificar en OPAC que aparecen registros
- [ ] Configurar cron para automatización
- [ ] (Opcional) Configurar notificaciones email

---

**Sistema listo para sincronización automatizada de Arquitectura! 🚀**

**Próximo paso:**
```bash
./sincronizar_arquitectura.sh
```

