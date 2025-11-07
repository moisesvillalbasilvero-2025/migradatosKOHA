# 🚀 SISTEMA AUTO-IMPORTADOR - ESTADO FINAL

## ✅ Sistema Completado y Operativo

### 📦 Componentes Instalados

```
migradatos/
├── auto_importar.py              ⭐ Script principal del agente
├── test_sistema.sh               🔍 Verificador del sistema
│
├── importar_aqui/                📥 Carpeta para colocar CSVs nuevos
│   └── LEEME.txt                 📄 Instrucciones
│
├── procesados/                   ✅ Archivos procesados exitosamente
├── errores/                      ⚠️  Archivos con errores
├── exports/                      📝 MARCXML generados
├── logs/                         📊 Logs del sistema
│
└── Documentación:
    ├── INICIO_RAPIDO.txt         🎯 Empezar inmediatamente
    ├── COMO_USAR_AUTO_IMPORTAR.txt   📖 Guía completa
    ├── RESUMEN_AUTO_IMPORTADOR.txt   📚 Documentación técnica
    └── BIBLIOTECAS_PENDIENTES.txt    📋 Estado de bibliotecas
```

---

## 📊 Estado Actual

### ✅ Bibliotecas YA Importadas (13)

| Código | Biblioteca | Items |
|--------|------------|-------|
| AGRO | Ciencias Agrarias | 37,226 |
| ARQ | Arquitectura | 3,944 |
| ING | Ingeniería | 14,997 |
| MED | Ciencias Médicas | 4,767 |
| POL | Politécnica | 12,467 |
| VET | Veterinaria | 9,085 |
| ODO | Odontología | 1,212 |
| _...otros_ | _..._ | _..._ |

**Total: ~84,000 items cargados**

### ⏳ Bibliotecas Pendientes (29)

Principales:
- **BC** - Biblioteca Central UNA
- **ECO** - Ciencias Económicas
- **FORA** - Ingeniería Forestal
- **IICS** - Instituto de Investigaciones en Ciencias de la Salud
- **ISA** - Instituto Superior de Arte
- Y 24 filiales más...

Ver lista completa en: `BIBLIOTECAS_PENDIENTES.txt`

---

## 🎯 Cómo Usar (Modo Simple)

### Para Importar una NUEVA Biblioteca

**Cuando recibas un CSV de una biblioteca pendiente:**

```bash
# 1. Renombrar archivo con código de biblioteca
cp /tmp/datos_economia.csv /home/mvillalba/migradatos/importar_aqui/ECO.csv

# 2. Activar importador
cd /home/mvillalba/migradatos
./auto_importar.py

# El sistema detecta ECO.csv y lo procesa automáticamente
```

O directamente:
```bash
./auto_importar.py ECO.csv
```

---

## ✨ Qué Hace el Sistema Automáticamente

```
CSV colocado
    ↓
Detecta código (del nombre del archivo)
    ↓
Verifica que biblioteca existe en Koha
    ↓
Analiza formato CSV
    ↓
Corrige duplicados (si es necesario)
    ↓
Genera MARCXML optimizado
    ↓
Importa a Koha
    ↓
Reindexa catálogo
    ↓
Mueve archivo a procesados/ o errores/
    ↓
✅ LISTO
```

---

## 📋 Requisitos del Archivo CSV

### Naming Convention

El **nombre del archivo** debe contener el código de la biblioteca:

✅ **Correcto:**
- `ECO.csv` → Detecta biblioteca ECO
- `BC_2025.csv` → Detecta biblioteca BC
- `AGRC_chaco.csv` → Detecta biblioteca AGRC

❌ **Incorrecto:**
- `economia.csv` → No detecta código
- `datos.csv` → No detecta código

### Campos Obligatorios en el CSV

- `titulo` - Título del material
- `nroacceso` - Código de barras/acceso
- `codbiblio` - Código de biblioteca (o se detecta del nombre)

### Campos Recomendados

- `autor`
- `isbn_issn`
- `editorial`
- `anio` / `publicacion`
- `temas_descrip` / `materia`
- `ubicacion` (signatura)
- `tipomaterial`

---

## 🚀 Comandos Rápidos

```bash
# Verificar sistema
./test_sistema.sh

# Ver bibliotecas pendientes
cat BIBLIOTECAS_PENDIENTES.txt

# Procesar un archivo
./auto_importar.py CODIGO.csv

# Modo vigilancia (deja corriendo)
./auto_importar.py

# Ver archivos procesados
ls -lh procesados/

# Ver archivos con errores
ls -lh errores/

# Ver items por biblioteca en Koha
sudo koha-mysql koha-cnc -e "
SELECT homebranch, COUNT(*) as items
FROM items
GROUP BY homebranch
ORDER BY items DESC"
```

---

## 🔄 Flujo de Trabajo Recomendado

### Para el día a día:

1. **Recibir CSV** de una biblioteca nueva
2. **Renombrar** con código correcto (ej: `ECO.csv`)
3. **Colocar** en `importar_aqui/`
4. **Ejecutar** `./auto_importar.py`
5. **Verificar** en OPAC
6. **Archivar** CSV procesado

### Para procesamiento masivo:

```bash
# Dejar sistema en modo vigilancia
nohup ./auto_importar.py > auto_importar.log 2>&1 &

# Colocar múltiples CSVs en importar_aqui/
cp BC.csv ECO.csv FORA.csv importar_aqui/

# Se procesan automáticamente en segundo plano
```

---

## 🛡️ Manejo de Errores

El sistema es **robusto** y maneja errores automáticamente:

| Error | Qué hace el sistema |
|-------|---------------------|
| No detecta código de biblioteca | Mueve a `errores/_SIN_CODIGO` |
| Biblioteca no existe en Koha | Mueve a `errores/_NO_EXISTE` |
| Formato CSV inválido | Mueve a `errores/_FORMATO_INVALIDO` |
| Error generando MARCXML | Mueve a `errores/_ERROR_MARCXML` |
| Error en importación | Mueve a `errores/_ERROR_IMPORT` |

**No pierdes datos**, siempre se guardan en alguna carpeta.

---

## 📖 Documentación Disponible

| Archivo | Propósito |
|---------|-----------|
| `INICIO_RAPIDO.txt` | Empezar a usar YA |
| `COMO_USAR_AUTO_IMPORTAR.txt` | Guía completa de uso |
| `RESUMEN_AUTO_IMPORTADOR.txt` | Documentación técnica |
| `BIBLIOTECAS_PENDIENTES.txt` | Bibliotecas por importar |
| `importar_aqui/LEEME.txt` | Instrucciones en carpeta |

---

## 🎯 Próximos Pasos

1. **Identificar** qué bibliotecas tienen datos disponibles de las 29 pendientes
2. **Obtener** los archivos CSV
3. **Renombrar** con código correcto
4. **Importar** usando el sistema automático
5. **Verificar** en OPAC

---

## ✅ Checklist de Verificación

Antes de importar un CSV nuevo:

- [ ] El archivo está renombrado con código de biblioteca (`ECO.csv`, `BC.csv`, etc.)
- [ ] La biblioteca existe en Koha (verificar con `./test_sistema.sh`)
- [ ] El CSV tiene campos: `titulo`, `nroacceso`
- [ ] Tienes backup del CSV original
- [ ] El sistema está funcionando (`./test_sistema.sh`)

---

## 🔍 Verificación Post-Importación

Después de cada importación:

```bash
# 1. Verificar en MySQL
sudo koha-mysql koha-cnc -e "
SELECT COUNT(*) as items
FROM items
WHERE homebranch = 'ECO'"

# 2. Verificar en OPAC
# http://tu-servidor:8080/cgi-bin/koha/opac-search.pl?branch=ECO

# 3. Revisar archivo movido
ls -lh procesados/ECO_OK_*
```

---

## 💡 Consejos

- ✅ **Usa nombres claros**: `ECO.csv`, `BC.csv`, `FORA.csv`
- ✅ **Procesa de uno en uno** al principio para familiarizarte
- ✅ **Revisa logs** en `logs/` si algo falla
- ✅ **Mantén backups** de CSVs originales
- ✅ **Verifica en OPAC** después de cada importación
- ✅ **Limpia periódicamente** carpetas `procesados/` y `exports/`

---

## 🎉 Ventajas del Sistema

| Característica | Beneficio |
|----------------|-----------|
| **Automático** | No requiere intervención manual |
| **Inteligente** | Auto-detección y auto-corrección |
| **Robusto** | Manejo completo de errores |
| **Simple** | Solo colocar CSV y ejecutar |
| **Rápido** | Procesa miles de registros |
| **Seguro** | No pierde datos, todo trazable |
| **Flexible** | Modo individual o batch |

---

## 📞 Soporte

Para problemas:
1. Revisar logs en `logs/importacion_*.log`
2. Verificar archivos en `errores/`
3. Ejecutar `./test_sistema.sh` para diagnóstico
4. Consultar documentación correspondiente

---

## 📊 Estadísticas del Sistema

- **Bibliotecas configuradas en Koha**: 42
- **Bibliotecas con datos cargados**: 13
- **Items totales importados**: ~84,000
- **Bibliotecas pendientes**: 29
- **Sistema**: Operativo y listo

---

**Universidad Nacional de Asunción**
*Sistema de Migración Bibliográfica Automatizada*
Versión 3.0 - Octubre 2025

**Estado**: ✅ **SISTEMA OPERATIVO Y LISTO PARA USAR**

---

## 🚀 Empezar Ahora

```bash
cd /home/mvillalba/migradatos
cat INICIO_RAPIDO.txt
./test_sistema.sh
```

¡El sistema está listo para importar las 29 bibliotecas pendientes! 🎉
