# 📚 ÍNDICE DE DOCUMENTACIÓN
## Sistema de Migración Bibliográfica a Koha

**Ubicación:** `/home/mvillalba/migradatos/`
**Fecha:** 2025-10-15
**Estado:** ✅ **Operacional** - Primera migración exitosa (ARQ: 3,609 títulos)

---

## 🚀 INICIO RÁPIDO

### 🆕 RESUMEN EJECUTIVO COMPLETO
**Lea primero:** `RESUMEN_SISTEMA_MIGRACION.md` ⭐⭐⭐
- Estado actual del sistema
- Resultados de ARQ (primera migración exitosa)
- Próximos pasos recomendados
- Métricas y estadísticas completas

### Para migrar POL inmediatamente:
1. Leer: `GUIA_RAPIDA.md`
2. Ejecutar: Comandos en `COMANDOS_RAPIDOS.txt`
3. Verificar: Siguiendo checklist en `README.md`

---

## 📖 DOCUMENTACIÓN

### 1. Guías de Usuario

| Archivo | Descripción | Para Quién | Prioridad |
|---------|-------------|------------|-----------|
| `00_INICIO_AQUI.md` | **Punto de entrada principal** | Todos | ⭐⭐⭐ |
| `RESUMEN_SISTEMA_MIGRACION.md` | 🆕 **Estado completo del sistema** | Coordinador/Gerencia | ⭐⭐⭐ |
| `README.md` | **Resumen ejecutivo** | Coordinador del proyecto | ⭐⭐⭐ |
| `GUIA_RAPIDA.md` | **Migración POL paso a paso** | Técnico ejecutor | ⭐⭐⭐ |
| `GUIA_DIDACTICA_COMPLETA.md` | **Tutorial para desarrolladores** | Desarrolladores | ⭐⭐⭐ |
| `COMANDOS_RAPIDOS.txt` | Comandos listos para copiar/pegar | Técnico ejecutor | ⭐⭐⭐ |
| `ANALISIS_Y_PLAN.md` | Análisis detallado y plan de acción | Coordinador | ⭐⭐ |
| `TABLA_MAPEO_UNIDADES_ACADEMICAS.md` | **Documento para facultades** | Responsables de bibliotecas | ⭐⭐⭐ |
| `PLANTILLA_REGISTRO_COMPLETO_FACEN.md` | Formato completo OPAC estilo FACEN | Catalogadores | ⭐⭐ |
| `SINCRONIZACION_ARQUITECTURA.md` | 🆕 **Documentación ARQ** | Administrador ARQ | ⭐⭐ |
| `SISTEMA_TOTALMENTE_AUTOMATIZADO.md` | Sistema Python automatizado | Administrador de sistema | ⭐⭐ |
| `SISTEMA_DESCENTRALIZADO.md` | Opción sin acceso remoto | Bibliotecas independientes | ⭐⭐ |
| `ANALISIS_REGISTRO_FACEN_558.md` | Análisis del registro modelo | Catalogadores | ⭐ |

### 2. Referencias Técnicas (en `/tmp/`)

| Archivo | Descripción |
|---------|-------------|
| `GUIA_CAMPOS_MARC_KOHA.md` | Guía completa de campos MARC21 |
| `README_MIGRACION_KOHA.md` | Manual técnico completo |

---

## 💻 SCRIPTS

### Scripts Principales

| Archivo | Descripción | Cuándo Usar |
|---------|-------------|-------------|
| `opac_exportar.py` | **CSV → MARCXML** | ✅ Para POL y cualquier CSV |
| `firebird_exporter.py` | **Firebird → CSV** | Exportar desde servidores remotos |
| `firebird_structure_analyzer.py` | **Analizar BD Firebird** | Entender estructura de BD |

### Scripts Avanzados (en `/tmp/`)

| Archivo | Descripción |
|---------|-------------|
| `firebird_to_koha_marc.py` | Conexión directa Firebird → MARCXML (avanzado) |
| `koha_sync.py` | Sistema de sincronización automática programada |

---

## 📊 DATOS

| Archivo | Descripción | Estado |
|---------|-------------|--------|
| `POL.csv` | 12,467 registros de biblioteca POL | ✅ Listo para migrar |

---

## 📋 FLUJO DE TRABAJO RECOMENDADO

### Fase 1: Migración POL (AHORA)

```
1. Leer: GUIA_RAPIDA.md
   ↓
2. Configurar Koha (biblioteca POL, ubicaciones, tipos)
   ↓
3. Ejecutar: python3 opac_exportar.py (generar MARCXML)
   ↓
4. Validar MARCXML
   ↓
5. Importar lote prueba (5000 registros)
   ↓
6. Verificar en OPAC
   ↓
7. Importar completo
   ↓
8. Rebuild índices
   ↓
✓ POL Migrado
```

### Fase 2: Otras Bibliotecas (PRÓXIMAMENTE)

```
1. Enviar: TABLA_MAPEO_UNIDADES_ACADEMICAS.md a cada facultad
   ↓
2. Recibir: Datos de conexión Firebird
   ↓
3. Ejecutar: python3 firebird_structure_analyzer.py
   ↓
4. Adaptar queries en firebird_exporter.py
   ↓
5. Exportar: python3 firebird_exporter.py --biblioteca FACXX
   ↓
6. Convertir: python3 opac_exportar.py -i FACXX.csv
   ↓
7. Importar a Koha
   ↓
✓ FACXX Migrada
```

---

## 🎯 TAREAS PENDIENTES

### Inmediatas (Esta Semana)

- [ ] Configurar biblioteca POL en Koha
- [ ] Migrar POL (12,467 registros)
- [ ] Verificar visualización en OPAC
- [ ] Documentar resultados

### Corto Plazo (Próximas 2 Semanas)

- [ ] Enviar `TABLA_MAPEO_UNIDADES_ACADEMICAS.md` a todas las facultades
- [ ] Obtener datos de conexión Firebird de cada biblioteca
- [ ] Analizar estructura de cada BD
- [ ] Crear planilla de seguimiento por biblioteca

### Mediano Plazo (Próximo Mes)

- [ ] Migrar 5 bibliotecas más
- [ ] Implementar sistema de sincronización
- [ ] Capacitar a catalogadores
- [ ] Crear manual de usuario final

---

## 📞 CONTACTOS Y SOPORTE

### Responsables por Biblioteca

| Biblioteca | Responsable | Email | Teléfono |
|------------|-------------|-------|----------|
| POL | | | |
| FACAGR | | | |
| FACEN | | | |
| FACMED | | | |
| ... | | | |

### Soporte Técnico

- Email: soporte.biblioteca@una.py
- Sistema: Koha + Firebird
- Documentación: `/home/mvillalba/migradatos/`

---

## 🔧 REQUISITOS TÉCNICOS

### Software Necesario

- [x] Python 3.8+
- [x] Koha 23.x instalado (koha-cnc)
- [ ] Driver Firebird Python (fdb) - `pip3 install fdb`
- [x] xmllint (para validación)

### Accesos Necesarios

- [x] Acceso sudo en servidor Koha
- [x] Acceso a koha-shell
- [ ] Datos de conexión a servidores Firebird
- [ ] Usuarios y passwords de BD Firebird

---

## 📈 MÉTRICAS

### POL (Listo)

- Registros: 12,467
- Archivo: POL.csv (11 MB)
- Estado: ✅ Listo para migrar

### Total Estimado

- Bibliotecas: ~10-15
- Registros totales: ~100,000-200,000 (estimado)
- Tiempo por biblioteca: 1-2 horas
- Tiempo total estimado: 2-4 semanas

---

## ✅ CHECKLIST GENERAL

### Sistema

- [x] Scripts creados
- [x] Documentación completa
- [x] Datos POL disponibles
- [ ] Koha configurado
- [ ] Prueba exitosa POL
- [ ] Accesos a Firebird remotos
- [ ] Mapeos confirmados con facultades

### Por Biblioteca

**POL:**
- [x] Datos disponibles (CSV)
- [ ] Biblioteca creada en Koha
- [ ] MARCXML generado
- [ ] Importación exitosa
- [ ] Verificación OPAC

**Otras (FACAGR, FACEN, etc.):**
- [ ] Contacto establecido
- [ ] Datos de conexión recibidos
- [ ] Estructura analizada
- [ ] Mapeo confirmado
- [ ] Exportación exitosa
- [ ] Importación exitosa

---

## 📚 GLOSARIO

| Término | Descripción |
|---------|-------------|
| **MARC21** | Formato estándar de catalogación bibliográfica |
| **MARCXML** | MARC en formato XML |
| **Firebird** | Sistema de base de datos usado actualmente |
| **Koha** | Sistema integrado de gestión bibliotecaria (ILS) |
| **OPAC** | Online Public Access Catalog (catálogo público) |
| **homebranch** | Biblioteca propietaria del ítem (952$a) |
| **holdingbranch** | Biblioteca donde está físicamente (952$b) |
| **itemtype** | Tipo de material (BK, MG, TES, etc.) |
| **LOC** | Ubicación física (SALA, REF, DEP, etc.) |

---

## 🔗 ENLACES ÚTILES

- **Koha Manual:** https://koha-community.org/manual/
- **MARC21:** https://www.loc.gov/marc/bibliographic/
- **Catálogo FACEN (referencia):** https://catalogobibliografico.facen.una.py

---

## 📜 HISTORIAL DE VERSIONES

| Versión | Fecha | Cambios |
|---------|-------|---------|
| 1.0 | 2025-01-15 | Sistema completo creado |

---

**🎯 Próximo Paso:** Ejecutar migración de POL siguiendo `GUIA_RAPIDA.md`

**Estado General:** ✅ Sistema Completo - Listo para Producción
