# 🚀 Sistema de Importación a Koha con TMUX

Sistema completo de importación de datos desde Firebird a Koha OPAC con persistencia total usando tmux y automatización 24/7.

## 📋 Descripción

Este sistema permite migrar datos bibliográficos desde bases de datos Firebird a Koha OPAC de forma segura, eficiente y completamente automatizada.

**Características principales:**
- ✅ **Persistencia total con tmux** - Las sesiones no se pierden al desconectar SSH
- ✅ **Vigilante permanente** - Automatización 24/7 con detección instantánea
- ✅ **Monitor en tiempo real** - Dashboard interactivo
- ✅ **Tres modos de operación** - Manual, automático y gestor interactivo

---

## 🚀 Inicio Rápido

### Automatización Total (Recomendado)
```bash
./vigilante_permanente.sh start
cp /origen/*.csv importar_aqui/
# ¡Se importan automáticamente!
```

### Importación Manual con Persistencia
```bash
./importar_tmux.sh importar_aqui/ARCHIVO.csv
```

### Menú Interactivo
```bash
./gestionar_importaciones.sh
```

---

## 📦 Componentes

- `importar_tmux.sh` - Importador principal con tmux
- `vigilante_permanente.sh` - Vigilante automático 24/7 ⭐
- `monitor_tmux.sh` - Dashboard en tiempo real
- `gestionar_importaciones.sh` - Gestor completo (15 opciones)
- Ver **GUIA_SISTEMA_TMUX.md** para documentación completa

---

## 📖 Documentación

- `GUIA_SISTEMA_TMUX.md` - Guía completa del sistema
- `GUIA_VIGILANTE_PERMANENTE.md` - Guía del vigilante
- `RESUMEN_FINAL_TMUX.txt` - Resumen ejecutivo

---

**Universidad Nacional de Asunción** | Versión 2.0 | 2025-11-05
