# 📂 Ejemplos de Configuración de Mapeo

Esta carpeta contiene ejemplos de configuración para diferentes tipos de bibliotecas y casos de uso.

---

## 📋 Archivos Disponibles

### 1. `config_simple.json` ⭐ **RECOMENDADO PARA EMPEZAR**
**Para quién:** Cualquier biblioteca, principiantes
**Contiene:** Configuración básica y genérica
**Uso:**
```bash
python3 scripts/opac_exportar.py \
  -i mi_biblioteca.csv \
  --codbiblio MiBIB \
  --map-config config/ejemplos/config_simple.json
```

**Qué incluye:**
- ✅ Mapeo de tipos de material básicos (Libro, Revista, DVD, etc.)
- ✅ Ejemplo paso a paso de uso
- ✅ Plantilla CSV lista para copiar
- ✅ Preguntas frecuentes resueltas
- ✅ Guía de ampliación gradual

---

### 2. `medicina_loc_map.json`
**Para quién:** Biblioteca de Medicina (MED)
**Contiene:** Mapeo de ubicaciones físicas especializadas
**Uso:**
```bash
python3 scripts/opac_exportar.py \
  -i MED.csv \
  --codbiblio MED \
  --loc-map config/ejemplos/medicina_loc_map.json
```

**Ubicaciones incluidas:**
- `GENERAL`, `REFERENCIA`, `TESIS`
- `HEMEROTECA` (revistas médicas)
- `ATLAS` (atlas médicos)
- `PEDIATRIA`, `CIRUGIA`, `ANATOMIA`, `FARMACOLOGIA` (secciones especializadas)
- Y más...

**Ejemplo CSV:**
```csv
titulo,autor,ubicacion_fisica,signatura
"Gray's Anatomy","Gray, Henry","ANATOMIA","611 GRA"
"Farmacología Básica","Katzung","FARMACOLOGIA","615 KAT"
```

---

### 3. `agronomia_loc_map.json`
**Para quién:** Facultad de Ciencias Agrarias (AGRO)
**Contiene:** Ubicaciones específicas de agronomía
**Uso:**
```bash
python3 scripts/opac_exportar.py \
  -i AGRO.csv \
  --codbiblio AGRO \
  --loc-map config/ejemplos/agronomia_loc_map.json
```

**Ubicaciones incluidas:**
- `LABORATORIO` (Lab. Suelos, Botánica)
- `INVESTIGACION` (Proyectos de investigación)
- `HERBARIO` (Colecciones botánicas)
- `CAMPO` (Estación experimental)
- `PRODUCCION` (Producción Animal/Vegetal)
- Y más...

**Ejemplo CSV:**
```csv
titulo,ubicacion_fisica,signatura
"Cultivos Tropicales","PRODUCCION","630 CUL"
"Manual de Suelos","LABORATORIO","631.4 MAN"
"Flora del Paraguay","HERBARIO","581.9 FLO"
```

---

### 4. `ingenieria_tipos.json`
**Para quién:** Facultad Politécnica (POL)
**Contiene:** Tipos de material técnico/ingenieril
**Uso:**
```bash
python3 scripts/opac_exportar.py \
  -i POL.csv \
  --codbiblio POL \
  --map-config config/ejemplos/ingenieria_tipos.json
```

**Tipos de material incluidos:**
- `Libro Técnico` → BK
- `Norma` (ASTM, ISO) → NORM
- `Plano` / `Dibujo Técnico` → MP
- `Software` / `CD-ROM` → SW
- `Video Tutorial` → VM
- `Manual de Equipo` → EQ
- `Catálogo` / `Datasheet` → CAT
- Y más...

**Ejemplo CSV:**
```csv
titulo,tipo,año
"Resistencia de Materiales","Libro Técnico","2023"
"Norma ASTM D638","Norma","2022"
"Tutorial AutoCAD 2024","Video Tutorial","2024"
"Manual Osciloscopio Tektronix","Manual de Equipo","2023"
```

---

## 🚀 Inicio Rápido

### Opción 1: Usar configuración genérica (más fácil)

```bash
# 1. Copia la plantilla CSV de config_simple.json
# 2. Llena tus datos
# 3. Ejecuta:

python3 scripts/opac_exportar.py \
  -i tus_datos.csv \
  --codbiblio TU_CODIGO \
  --map-config config/ejemplos/config_simple.json
```

### Opción 2: Usar configuración específica

```bash
# Para Medicina:
python3 scripts/opac_exportar.py \
  -i MED.csv \
  --codbiblio MED \
  --loc-map config/ejemplos/medicina_loc_map.json

# Para Agronomía:
python3 scripts/opac_exportar.py \
  -i AGRO.csv \
  --codbiblio AGRO \
  --loc-map config/ejemplos/agronomia_loc_map.json

# Para Ingeniería:
python3 scripts/opac_exportar.py \
  -i POL.csv \
  --codbiblio POL \
  --map-config config/ejemplos/ingenieria_tipos.json
```

---

## 🎨 Personalización

### Crear tu propia configuración

1. **Copia un ejemplo** que se parezca a tu caso:
   ```bash
   cp config/ejemplos/config_simple.json config/mi_biblioteca.json
   ```

2. **Edita** con tu editor favorito:
   ```bash
   nano config/mi_biblioteca.json
   ```

3. **Modifica** los valores según tus necesidades:
   ```json
   {
     "default": {
       "branch_map": {
         "MI_BIBLIOTECA": "MIB"
       },
       "itemtype_map": {
         "Libro Antiguo": "RARE",
         "Manuscrito": "MS"
       }
     }
   }
   ```

4. **Prueba** con archivo pequeño:
   ```bash
   python3 scripts/opac_exportar.py \
     -i test.csv \
     --map-config config/mi_biblioteca.json \
     --dry-run  # ← Simula sin importar
   ```

---

## 📚 Combinando Configuraciones

Puedes usar mapeo de ubicaciones Y tipos juntos:

```bash
python3 scripts/opac_exportar.py \
  -i MED.csv \
  --codbiblio MED \
  --map-config config/ejemplos/ingenieria_tipos.json \
  --loc-map config/ejemplos/medicina_loc_map.json
```

Esto te da:
- ✅ Tipos de material de `ingenieria_tipos.json`
- ✅ Ubicaciones de `medicina_loc_map.json`

---

## 💡 Casos de Uso Frecuentes

### Caso 1: Biblioteca Pequeña con Solo Libros

**Archivo:** Usa `config_simple.json`

**CSV mínimo:**
```csv
titulo,autor,editorial,año
"Don Quijote","Cervantes","Planeta","1605"
```

**Comando:**
```bash
python3 scripts/opac_exportar.py -i libros.csv --codbiblio BIB
```

**Resultado:** Registro básico pero funcional ✅

---

### Caso 2: Biblioteca con Múltiples Salas

**Archivo:** Crea tu propio `mi_ubicaciones.json` basado en `medicina_loc_map.json`

**CSV:**
```csv
titulo,ubicacion_fisica,signatura
"Libro 1","SALA_NORTE","100 LIB"
"Libro 2","SALA_SUR","200 LIB"
```

**Configuración:**
```json
{
  "SALA_NORTE": "NORTE",
  "SALA_SUR": "SUR"
}
```

---

### Caso 3: Materiales Especiales (Normas, Planos, etc.)

**Archivo:** Usa `ingenieria_tipos.json` como base

**CSV:**
```csv
titulo,tipo
"Norma ISO 9001","Norma"
"Plano Edificio A","Plano"
```

**Resultado:** Tipos correctos asignados ✅

---

## ❓ Preguntas Frecuentes

### ¿Qué archivo debo usar?

| Tu caso | Archivo recomendado |
|---------|---------------------|
| Biblioteca general, cualquier tema | `config_simple.json` |
| Biblioteca médica | `medicina_loc_map.json` |
| Biblioteca de agronomía | `agronomia_loc_map.json` |
| Biblioteca técnica/ingeniería | `ingenieria_tipos.json` |
| Algo específico | Crea el tuyo basándote en un ejemplo |

### ¿Puedo modificar los ejemplos?

¡Sí! Los ejemplos son plantillas. Cópialos y modifícalos libremente.

### ¿Cómo sé qué códigos de ubicación existen en mi Koha?

```bash
# En el servidor Koha:
sudo koha-mysql INSTANCIA -e "SELECT authorised_value, lib FROM authorised_values WHERE category='LOC';"
```

O ve a: **Koha Administration > Authorized Values > LOC**

### ¿Qué pasa si mi CSV tiene nombres de columnas raros?

No hay problema. Edita `config/mapeo_campos.json` y agrega tus variantes:

```json
"titulo": {
  "variantes_csv": ["titulo", "título", "title", "TU_NOMBRE_RARO"]
}
```

---

## 🆘 Ayuda

**Más documentación:**
- `config/GUIA_MAPEO.md` - Guía completa del sistema de mapeo
- `config/mapeo_campos.json` - Configuración maestra con todos los campos
- `GUIA_USO_COMPLETA.md` - Guía general del sistema

**¿Problemas?**
1. Prueba primero en modo `--dry-run`
2. Verifica con archivo CSV pequeño (2-3 líneas)
3. Revisa los logs generados
4. Consulta GUIA_MAPEO.md para casos específicos

---

## 📝 Crear Nuevo Ejemplo

Si creaste una configuración útil para tu biblioteca y quieres compartirla:

```bash
# 1. Copia tu configuración aquí
cp config/mi_config.json config/ejemplos/nombre_descriptivo.json

# 2. Agrega documentación inline
# 3. Agrega ejemplo de CSV
# 4. Documenta en este README
```

---

**¡Sistema de Mapeo Flexible y Didáctico Listo! 🎉**

Ahora puedes adaptar la importación a cualquier estructura de datos.
