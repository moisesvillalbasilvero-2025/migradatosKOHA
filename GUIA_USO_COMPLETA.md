# 📚 Guía de Uso Completa - Sistema de Importación a Koha

## Universidad Nacional de Asunción

**Versión:** 3.1.0
**Fecha:** 2025-11-07
**Nivel:** Principiante a Avanzado

---

## 📋 Tabla de Contenidos

1. [Introducción](#introducción)
2. [Requisitos Previos](#requisitos-previos)
3. [Preparación de Archivos CSV](#preparación-de-archivos-csv)
4. [Modo Básico - Primeros Pasos](#modo-básico---primeros-pasos)
5. [Modo Avanzado - Opciones y Configuración](#modo-avanzado---opciones-y-configuración)
6. [Solución de Problemas](#solución-de-problemas)
7. [Preguntas Frecuentes (FAQ)](#preguntas-frecuentes-faq)
8. [Casos de Uso Reales](#casos-de-uso-reales)
9. [Mejores Prácticas](#mejores-prácticas)

---

## 🎯 Introducción

Este sistema automatiza la importación de registros bibliográficos desde archivos CSV al catálogo Koha OPAC de la Universidad Nacional de Asunción.

### ¿Qué hace este sistema?

✅ **Valida** tus archivos CSV antes de importar
✅ **Convierte** datos CSV a formato MARCXML
✅ **Importa** automáticamente a Koha
✅ **Reindexa** el catálogo para búsquedas
✅ **Genera reportes** detallados de cada importación
✅ **Se recupera** automáticamente de errores

### ¿Para quién es esta guía?

- 👤 **Bibliotecarios** que necesitan importar catálogos
- 👩‍💻 **Personal técnico** que gestiona el sistema
- 👨‍🎓 **Estudiantes** en prácticas de bibliotecología
- 👨‍🏫 **Capacitadores** del sistema Koha

---

## 🔧 Requisitos Previos

### Acceso al Servidor

Necesitas:
- 🖥️ **Acceso SSH** al servidor Koha
- 👤 **Usuario** con permisos sudo
- 🔑 **Contraseña** o clave SSH

```bash
# Conectarse al servidor
ssh tu_usuario@servidor-koha.edu.py
```

### Software Instalado

El servidor debe tener:
- ✅ Koha instalado y funcionando
- ✅ Python 3.6 o superior
- ✅ MySQL/MariaDB
- ✅ Git (opcional)

### Verificar que todo esté listo

```bash
# Ejecutar el verificador del sistema
cd /ruta/al/sistema
./verificar_sistema.sh
```

Si vez ✅ en la mayoría de items, estás listo para comenzar.

---

## 📝 Preparación de Archivos CSV

### Paso 1: Nombrar el Archivo Correctamente

**MUY IMPORTANTE:** El nombre del archivo debe contener el código de la biblioteca.

#### ✅ Nombres CORRECTOS:
```
MED.csv                    → Biblioteca MED
FACEN_2025.csv            → Biblioteca FACEN
VET_octubre.csv           → Biblioteca VET
DERECHO_backup.csv        → Biblioteca DERECHO
```

#### ❌ Nombres INCORRECTOS:
```
datos.csv                  → Sin código de biblioteca
export.csv                 → Sin código de biblioteca
catalogo.csv               → Sin código de biblioteca
```

### Paso 2: Estructura del CSV

Tu archivo CSV debe tener estas columnas:

#### Columnas OBLIGATORIAS:
- **titulo** - Título del libro/recurso
- **nroacceso** - Código de barras/acceso único

#### Columnas RECOMENDADAS:
- **autor** - Autor(es)
- **editorial** - Editorial
- **publicacion** - Año de publicación
- **isbn** - ISBN del libro
- **notas** - Notas adicionales

### Paso 3: Formato del Archivo

```csv
titulo;autor;editorial;publicacion;isbn;nroacceso
Cien años de soledad;Gabriel García Márquez;Sudamericana;1967;978-0-307-47472-8;MED-001234
Don Quijote de la Mancha;Miguel de Cervantes;Francisco de Robles;1605;978-8-420-41380-0;MED-001235
La sombra del viento;Carlos Ruiz Zafón;Planeta;2001;978-8-408-04379-5;MED-001236
```

#### 📌 Puntos Importantes:

1. **Delimitador:** Usar `;` (punto y coma) o `,` (coma)
2. **Primera línea:** Debe tener los nombres de columnas
3. **Encoding:** UTF-8 (sin BOM)
4. **Sin líneas vacías** al final
5. **nroacceso único** para cada registro

### Paso 4: Validar el CSV (RECOMENDADO)

Antes de importar, valida tu archivo:

```bash
# Validar un archivo
./validador_csv.py MED.csv

# Validar en modo estricto
./validador_csv.py --strict MED.csv

# Validar todo un directorio
./validador_csv.py --dir importar_aqui/
```

**Resultado esperado:**
```
✓✓✓ ARCHIVO VÁLIDO PARA IMPORTACIÓN ✓✓✓
```

---

## 🚀 Modo Básico - Primeros Pasos

### Método 1: Importación Simple (Recomendado para principiantes)

Este es el método más simple y seguro.

#### Paso 1: Copiar el archivo CSV

```bash
# Copiar tu CSV a la carpeta de importación
cp /ruta/a/tu/archivo/MED.csv importar_aqui/
```

#### Paso 2: Ejecutar el importador

```bash
# Importar el archivo
./importar_optimizado.sh importar_aqui/MED.csv
```

#### Paso 3: Seguir el proceso en pantalla

Verás algo como esto:

```
╔════════════════════════════════════════════════════════════════════╗
║          IMPORTADOR AUTOMÁTICO OPTIMIZADO - KOHA UNA V3.0          ║
╚════════════════════════════════════════════════════════════════════╝

ℹ Verificando dependencias del sistema...
✓ Python3 detectado: v3.11.14
✓ Agente Python v3 disponible
✓ koha-shell disponible
✓ Conexión a MySQL Koha OK
✓ Todas las dependencias están disponibles

1. DETECCIÓN DE BIBLIOTECA
────────────────────────────────────────────────────────────────────
✓ Código detectado: MED

2. VERIFICACIÓN EN KOHA
────────────────────────────────────────────────────────────────────
✓ Biblioteca: Biblioteca de Medicina

3. VALIDACIÓN DEL ARCHIVO
────────────────────────────────────────────────────────────────────
✓ Validación exitosa: MED.csv

4. IMPORTACIÓN A KOHA
────────────────────────────────────────────────────────────────────
→ Ejecutando agente de importación...

Importando: [████████████████████] 1250/1250 (100.0%)

✓ Importación completada: MED
📊 Items antes:   5,234
📊 Items después: 6,484
✓ Items nuevos:  1,250

╔════════════════════════════════════════════════════════════════════╗
║          ✓✓✓ IMPORTACIÓN COMPLETADA EXITOSAMENTE ✓✓✓              ║
╚════════════════════════════════════════════════════════════════════╝

⏱ Tiempo total: 15m 42s
```

#### Paso 4: Verificar en Koha

1. Abrir el navegador
2. Ir a: `http://tu-servidor:8080/`
3. Buscar por biblioteca "MED"
4. Verificar que aparecen los nuevos registros

---

### Método 2: Modo Dry-Run (Simulación)

**¿Cuándo usar esto?** Cuando quieres verificar que todo está correcto SIN modificar la base de datos.

```bash
# Simular importación
./agente_importador_v3.py MED.csv --dry-run
```

**Lo que hace:**
- ✅ Valida el archivo CSV
- ✅ Genera los archivos MARCXML
- ✅ Verifica que los datos son correctos
- ❌ NO importa a la base de datos
- ❌ NO modifica Koha

**Resultado:**
```
╔════════════════════════════════════════════════════════════════════╗
║          ✓✓✓ SIMULACIÓN COMPLETADA EXITOSAMENTE ✓✓✓               ║
╚════════════════════════════════════════════════════════════════════╝

🔍 Validación completada - Los datos son correctos
💡 Para importar realmente, ejecuta sin --dry-run
```

---

## 🎓 Modo Avanzado - Opciones y Configuración

### Importar Múltiples Archivos

#### Opción 1: Uno por uno
```bash
./importar_optimizado.sh MED.csv
./importar_optimizado.sh FACEN.csv
./importar_optimizado.sh VET.csv
```

#### Opción 2: Modo Batch (todos a la vez)
```bash
# Copiar todos los archivos
cp *.csv importar_aqui/

# Importar todos
./importar_optimizado.sh --batch importar_aqui/
```

Te preguntará confirmación:
```
Archivos encontrados: 3
  1. MED.csv
  2. FACEN.csv
  3. VET.csv

¿Procesar estos archivos? (SI/no):
```

### Modo Vigilancia 24/7 (Automatización)

Este modo vigila continuamente la carpeta `importar_aqui/` e importa automáticamente cualquier CSV nuevo.

```bash
# Iniciar vigilancia
./vigilante_permanente.sh start

# Ver estado
./vigilante_permanente.sh status

# Ver logs en vivo
./vigilante_permanente.sh logs

# Detener vigilancia
./vigilante_permanente.sh stop
```

**Uso típico:**
1. Iniciar vigilancia al principio del día
2. Ir copiando archivos CSV a `importar_aqui/`
3. El sistema los procesa automáticamente
4. Detener vigilancia al final del día

### Reanudar Importación Interrumpida

Si una importación se interrumpe (corte de luz, error, etc.), puedes reanudarla:

```bash
# Reanudar desde donde quedó
./agente_importador_v3.py MED.csv --resume
```

El sistema:
- 📂 Carga el estado guardado
- ⏭️ Omite registros ya importados
- ▶️ Continúa desde donde quedó

### Solo Validar (Sin Importar)

```bash
# Solo validar, no importar
./importar_optimizado.sh --validate-only MED.csv

# Validar todo un directorio
./importar_optimizado.sh --validate-only --batch importar_aqui/
```

### Modo Silencioso

Para scripts o cron:

```bash
# Sin salida en pantalla
./agente_importador_v3.py MED.csv --quiet

# Los errores se guardan en logs/
```

---

## 🔍 Solución de Problemas

### Problema 1: "No se detectó código de biblioteca"

**Causa:** El nombre del archivo no contiene el código.

**Solución:**
```bash
# ❌ Incorrecto
mv datos.csv importar_aqui/

# ✅ Correcto
mv datos.csv MED.csv
mv MED.csv importar_aqui/
```

---

### Problema 2: "La biblioteca 'XXX' NO existe en Koha"

**Causa:** El código no está registrado en Koha.

**Solución:**
1. Ir a Koha Staff Interface
2. Administración → Bibliotecas y grupos
3. Nueva biblioteca
4. Código: `MED`, Nombre: `Biblioteca de Medicina`
5. Guardar
6. Reintentar importación

---

### Problema 3: "Validación fallida: Faltan columnas obligatorias"

**Causa:** El CSV no tiene `titulo` o `nroacceso`.

**Solución:**
```bash
# Ver qué columnas tiene tu CSV
head -1 MED.csv

# Debe tener al menos:
titulo;nroacceso
```

Si faltan, edita el CSV y agrega las columnas.

---

### Problema 4: "Error de encoding"

**Causa:** El CSV tiene encoding incorrecto.

**Solución:**
```bash
# Convertir a UTF-8
iconv -f ISO-8859-1 -t UTF-8 MED.csv > MED_utf8.csv
mv MED_utf8.csv MED.csv
```

---

### Problema 5: Importación muy lenta

**Causas posibles:**
- Archivo muy grande
- Servidor con poca memoria
- Muchos duplicados

**Soluciones:**

1. **Dividir el archivo:**
```bash
# Dividir CSV grande en archivos de 1000 líneas
split -l 1000 MED_grande.csv MED_parte_
```

2. **Aumentar timeout:**
Editar `agente_importador_v3.py`:
```python
TIMEOUT_IMPORT = 3600  # 1 hora (default: 1800)
```

3. **Verificar recursos:**
```bash
# Ver uso de CPU/memoria
htop

# Ver espacio en disco
df -h
```

---

### Problema 6: "Timeout en importación"

**Causa:** El archivo es demasiado grande o el servidor está lento.

**Solución:**
```bash
# Dividir en archivos más pequeños
# Opción 1: Manual
head -501 MED.csv > MED_parte1.csv  # Header + 500 líneas
tail -n +502 MED.csv > resto.csv
head -501 resto.csv > MED_parte2.csv

# Opción 2: Automático con split
split -l 500 --additional-suffix=.csv MED.csv MED_parte_
```

---

## ❓ Preguntas Frecuentes (FAQ)

### ¿Puedo importar el mismo archivo dos veces?

**Sí**, pero creará duplicados. El sistema no detecta duplicados automáticamente (próxima versión).

**Recomendación:** Usa nombres únicos en `nroacceso` para cada item.

---

### ¿Qué pasa si me equivoco y quiero deshacer?

Actualmente no hay un botón de "deshacer". Debes:
1. Identificar los registros importados por fecha/hora
2. Eliminarlos manualmente desde Koha Staff Interface
3. O restaurar un backup de la base de datos

**Próxima versión:** Sistema de rollback automático.

---

### ¿Cuántos registros puedo importar a la vez?

**Técnicamente:** Ilimitado
**Recomendación práctica:**
- **Hasta 5,000 registros:** Importación directa
- **5,000 - 20,000:** Dividir en 2-4 archivos
- **Más de 20,000:** Dividir en archivos de 5,000

---

### ¿Puedo importar mientras usuarios buscan en el catálogo?

**Sí**, pero:
- ✅ Los usuarios pueden buscar normalmente
- ⚠️ Nuevos registros aparecen después de reindexar
- ⚠️ Puede haber lentitud si el servidor tiene poca RAM

**Mejor horario:** Fuera de horas pico (noche, fin de semana)

---

### ¿Qué archivos puedo borrar después de importar?

```bash
# ✅ PUEDES borrar (después de verificar en Koha):
rm -rf exports/MED_*_marcxml*.xml
rm -rf procesados/MED.csv

# ⚠️ CONSERVAR (para auditoría):
# logs/maestro_*.log
# reportes/reporte_MED_*.txt

# ❌ NUNCA borrar (sistema):
# importar_optimizado.sh
# agente_importador_v3.py
# validador_csv.py
```

---

### ¿Cómo sé si la importación fue exitosa?

Verifica 3 cosas:

1. **Mensaje final:**
```
╔════════════════════════════════════════════════════════════════════╗
║          ✓✓✓ IMPORTACIÓN COMPLETADA EXITOSAMENTE ✓✓✓              ║
╚════════════════════════════════════════════════════════════════════╝
```

2. **Reporte en reportes/:**
```bash
cat reportes/reporte_MED_*.txt
```

3. **Búsqueda en Koha:**
- Ir al OPAC
- Buscar por biblioteca
- Verificar registros

---

## 📚 Casos de Uso Reales

### Caso 1: Importar Catálogo Nuevo de una Biblioteca

**Escenario:** La Biblioteca de Medicina tiene 2,500 libros en Excel.

**Pasos:**
1. Exportar Excel a CSV (con `;` como delimitador)
2. Nombrar archivo: `MED.csv`
3. Validar estructura:
```bash
./validador_csv.py MED.csv
```
4. Simular importación (dry-run):
```bash
./agente_importador_v3.py MED.csv --dry-run
```
5. Si todo OK, importar realmente:
```bash
./importar_optimizado.sh MED.csv
```
6. Verificar en Koha
7. Guardar reporte para auditoría

**Tiempo estimado:** 15-20 minutos para 2,500 registros

---

### Caso 2: Actualizar Catálogo Existente (Agregar Items Nuevos)

**Escenario:** La Biblioteca FACEN recibió 300 libros nuevos.

**Pasos:**
1. Crear CSV solo con los nuevos libros
2. **IMPORTANTE:** Usar códigos `nroacceso` únicos
```csv
titulo;autor;nroacceso
Nuevo Libro 1;Autor 1;FACEN-NEW-001
Nuevo Libro 2;Autor 2;FACEN-NEW-002
...
```
3. Importar:
```bash
./importar_optimizado.sh FACEN_nuevos.csv
```

---

### Caso 3: Migración Masiva (Múltiples Bibliotecas)

**Escenario:** Importar catálogos de 5 bibliotecas (total: 15,000 registros).

**Estrategia:**
1. Preparar archivos:
```
MED.csv (3000 registros)
FACEN.csv (4000 registros)
VET.csv (2500 registros)
DERECHO.csv (3500 registros)
INGENIERIA.csv (2000 registros)
```

2. Validar todos:
```bash
./validador_csv.py --dir .
```

3. Importar en modo batch:
```bash
./importar_optimizado.sh --batch .
```

4. O usar vigilancia automática:
```bash
# Terminal 1
./vigilante_permanente.sh start

# Terminal 2
cp MED.csv importar_aqui/
# Esperar a que termine
cp FACEN.csv importar_aqui/
# Repetir...
```

**Tiempo estimado:** 1-2 horas total

---

### Caso 4: Importación Programada (Cron)

**Escenario:** Importar automáticamente cada noche archivos que llegan por FTP.

**Configuración:**
```bash
# Editar crontab
crontab -e

# Agregar:
0 2 * * * cd /ruta/sistema && ./importar_optimizado.sh --batch /ruta/ftp/nuevos/ >> /var/log/importacion.log 2>&1
```

Esto ejecuta importación todos los días a las 2 AM.

---

## ✨ Mejores Prácticas

### ✅ Antes de Importar

1. **Siempre hacer backup de la base de datos**
```bash
sudo koha-dump koha-cnc
```

2. **Validar el CSV primero**
```bash
./validador_csv.py archivo.csv
```

3. **Probar con dry-run**
```bash
./agente_importador_v3.py archivo.csv --dry-run
```

4. **Importar un archivo pequeño de prueba** (10-20 registros)

5. **Verificar en Koha** que se ve correcto

6. **Entonces importar el archivo completo**

---

### ✅ Durante la Importación

1. **No cerrar la terminal** mientras importa
2. **No apagar el servidor**
3. **Monitorear logs** en otra terminal:
```bash
tail -f logs/maestro_*.log
```
4. **Anotar la hora de inicio** para auditoría

---

### ✅ Después de Importar

1. **Verificar mensaje de éxito**
2. **Revisar reporte generado** en `reportes/`
3. **Buscar en Koha** algunos registros aleatorios
4. **Mover CSV a `procesados/`** (el sistema lo hace automáticamente)
5. **Guardar logs** para auditoría
6. **Documentar la importación** (fecha, biblioteca, cantidad)

---

### ✅ Mantenimiento Regular

#### Diario:
- Revisar `logs/` por errores
- Limpiar archivos temporales antiguos

#### Semanal:
- Revisar espacio en disco
```bash
df -h
```
- Limpiar XMLs antiguos en `exports/`
```bash
find exports/ -name "*.xml" -mtime +7 -delete
```

#### Mensual:
- Revisar reportes de todas las importaciones
- Generar estadística de uso
- Optimizar base de datos Koha

---

## 📞 Soporte y Contacto

### Documentación Adicional

- 📄 `README.md` - Vista general del sistema
- 📄 `GUIA_COMPLETA_OPTIMIZADA.md` - Guía técnica detallada
- 📄 `MEJORAS_REFACTORIZACION.md` - Cambios técnicos recientes

### Ayuda en el Sistema

```bash
# Ayuda del importador
./importar_optimizado.sh --help

# Ayuda del agente Python
./agente_importador_v3.py --help

# Ayuda del validador
./validador_csv.py --help
```

### Reportar Problemas

Si encuentras un problema:

1. **Recopilar información:**
   - Archivo CSV problemático
   - Logs relevantes
   - Mensaje de error exacto
   - Pasos para reproducir

2. **Revisar esta guía** primero

3. **Contactar a soporte técnico:**
   - Email: soporte-bibliotecas@una.edu.py
   - Incluir toda la información recopilada

---

## 🎓 Resumen de Comandos Más Usados

```bash
# VALIDACIÓN
./validador_csv.py archivo.csv                    # Validar un archivo
./validador_csv.py --strict archivo.csv           # Validación estricta
./validador_csv.py --dir importar_aqui/           # Validar directorio

# SIMULACIÓN (DRY-RUN)
./agente_importador_v3.py archivo.csv --dry-run   # Simular sin modificar BD

# IMPORTACIÓN BÁSICA
./importar_optimizado.sh archivo.csv              # Importar un archivo
./importar_optimizado.sh                          # Importar importar_aqui/

# IMPORTACIÓN BATCH
./importar_optimizado.sh --batch directorio/      # Importar varios archivos

# VIGILANCIA AUTOMÁTICA
./vigilante_permanente.sh start                   # Iniciar vigilancia
./vigilante_permanente.sh status                  # Ver estado
./vigilante_permanente.sh logs                    # Ver logs
./vigilante_permanente.sh stop                    # Detener

# RECUPERACIÓN
./agente_importador_v3.py archivo.csv --resume    # Reanudar interrumpida

# VERIFICACIÓN DEL SISTEMA
./verificar_sistema.sh                            # Verificar dependencias
```

---

## 🏆 Checklist de Importación Exitosa

Antes de considerar completa una importación, verifica:

- [ ] ✅ Mensaje de éxito en pantalla
- [ ] ✅ Reporte generado en `reportes/`
- [ ] ✅ Archivo movido a `procesados/`
- [ ] ✅ Registros visibles en Koha OPAC
- [ ] ✅ Búsquedas funcionan correctamente
- [ ] ✅ Cantidad de items coincide con esperado
- [ ] ✅ Logs guardados para auditoría
- [ ] ✅ Sin errores en `logs/`
- [ ] ✅ Backup de BD realizado (antes de importar)
- [ ] ✅ Importación documentada (fecha, hora, cantidad)

---

**¡Felicitaciones! Ahora eres un experto en el Sistema de Importación a Koha de la UNA.**

Para dudas o sugerencias, contacta al equipo técnico de bibliotecas.

---

*Universidad Nacional de Asunción - Sistema de Bibliotecas*
*Última actualización: 2025-11-07*
