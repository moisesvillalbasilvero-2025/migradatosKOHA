# 📖 TUTORIAL PASO A PASO - IMPORTAR CSV AUTOMÁTICAMENTE
## Universidad Nacional de Asunción - Sistema Koha

---

## 🎯 OBJETIVO

Recibiste un archivo CSV de una biblioteca y quieres importarlo automáticamente a Koha.

---

## ✅ REQUISITOS PREVIOS

Antes de empezar, necesitas saber:

1. **Código de la biblioteca** (3-5 letras mayúsculas)
   - Ejemplos: FACEN, MED, DER, ODONT, VET

2. **Tener el archivo CSV**
   - Puede estar en cualquier ubicación
   - Ejemplo: `/tmp/datos.csv` o en tu escritorio

---

## 📝 PASO 1: CREAR LA BIBLIOTECA EN KOHA (Solo primera vez)

**⚠️ IMPORTANTE:** La biblioteca debe existir en Koha ANTES de importar.

### Cómo crear la biblioteca:

1. Abre tu navegador web

2. Ir a Staff Interface:
   ```
   http://tu-servidor:8080/cgi-bin/koha/mainpage.pl
   ```

3. Iniciar sesión (usuario administrador)

4. Ir a: **Administración** (menú izquierdo)

5. Buscar: **Bibliotecas y grupos**

6. Clic en: **Nueva biblioteca**

7. Llenar el formulario:
   ```
   Código de biblioteca: FACEN         (MAYÚSCULAS, sin espacios)
   Nombre: Facultad de Ciencias Exactas y Naturales
   ```

8. Clic en: **Guardar**

✅ **Listo.** La biblioteca ya existe en Koha.

---

## 📝 PASO 2: CONECTARSE AL SERVIDOR

Abre tu terminal y conéctate al servidor donde está Koha:

```bash
ssh usuario@servidor
```

Ejemplo:
```bash
ssh mvillalba@192.168.1.100
```

---

## 📝 PASO 3: IR AL DIRECTORIO DE TRABAJO

```bash
cd /home/mvillalba/migradatos
```

---

## 📝 PASO 4: VERIFICAR QUE EL SCRIPT EXISTE

```bash
ls -lh importar_nueva_biblioteca.sh
```

Deberías ver algo como:
```
-rwxr-xr-x 1 root root 8.3K oct 21 09:45 importar_nueva_biblioteca.sh
```

✅ Si lo ves, continúa al siguiente paso.

❌ Si NO lo ves, contacta al administrador.

---

## 📝 PASO 5: EJECUTAR LA IMPORTACIÓN AUTOMÁTICA

Aquí está la **MAGIA**. Un solo comando hace TODO:

```bash
./importar_nueva_biblioteca.sh CODIGO /ruta/completa/al/archivo.csv
```

### Ejemplos reales:

**Ejemplo 1: Archivo en /tmp**
```bash
./importar_nueva_biblioteca.sh FACEN /tmp/datos_facen.csv
```

**Ejemplo 2: Archivo en tu home**
```bash
./importar_nueva_biblioteca.sh MED /home/mvillalba/medicina.csv
```

**Ejemplo 3: Archivo ya en el directorio actual**
```bash
./importar_nueva_biblioteca.sh DER ./derecho_20251021.csv
```

---

## 📝 PASO 6: SEGUIR LAS INSTRUCCIONES EN PANTALLA

El script te mostrará:

```
╔════════════════════════════════════════════════════════════════════╗
║       IMPORTACIÓN AUTOMÁTICA DE NUEVA BIBLIOTECA                   ║
╚════════════════════════════════════════════════════════════════════╝

PASO 1: Verificar archivo CSV
✓ Archivo encontrado
  Total de registros: 5,234

PASO 2: Copiar CSV al directorio de trabajo
✓ Archivo copiado

PASO 3: Analizar estructura del CSV
...

PASO 4: Verificar que biblioteca existe en Koha
✓ Biblioteca encontrada: Facultad de Ciencias Exactas

PASO 5: Verificar registros existentes
  Items existentes: 0
```

### ⚠️ PREGUNTA IMPORTANTE:

Si ya existen registros, el script preguntará:

```
⚠ ADVERTENCIA: Ya existen 173 items de esta biblioteca en Koha
  La importación agregará NUEVOS registros

¿Desea continuar de todas formas? (escriba SI):
```

**Opciones:**
- Escribir `SI` y presionar Enter → Continúa la importación
- Escribir cualquier otra cosa → Cancela

---

## 📝 PASO 7: ESPERAR (Automático)

El script hace TODO automáticamente:

```
PASO 6: Generar MARCXML desde CSV
✓ MARCXML generado

PASO 7: Validar archivos MARCXML
✓ Válido

PASO 8: Importar a Koha
Importando...
..................................................
100..................................................
200..................................................
...
5000..................................................
✓ Importado exitosamente

PASO 9: Reconstruir índices de búsqueda
✓ Índices reconstruidos

PASO 10: Verificar importación
✓ Verificación exitosa
```

**Tiempo estimado:**
- 1,000 registros: ~5 minutos
- 5,000 registros: ~20 minutos
- 10,000 registros: ~40 minutos

⚠️ **NO cerrar la terminal mientras importa**

---

## 📝 PASO 8: VER EL RESUMEN

Al finalizar verás:

```
═══════════════════════════════════════════════════════════════════
RESUMEN FINAL:
  • Biblioteca: FACEN - Facultad de Ciencias Exactas
  • Registros importados: 5,234
  • Total items en biblioteca: 5,234
  • Estado: ✓✓✓ COMPLETADO EXITOSAMENTE ✓✓✓
═══════════════════════════════════════════════════════════════════

VERIFICACIÓN EN OPAC:
URL directa: http://servidor:8080/cgi-bin/koha/opac-search.pl?branch=FACEN
```

---

## 📝 PASO 9: VERIFICAR EN EL OPAC

1. Abre tu navegador

2. Ir a la URL que te mostró el script:
   ```
   http://servidor:8080/cgi-bin/koha/opac-search.pl?branch=FACEN
   ```

3. O manualmente:
   - Ir a: http://servidor:8080
   - Clic en: **Búsqueda avanzada**
   - En "Biblioteca" seleccionar: **FACEN**
   - Hacer búsqueda

4. Deberías ver todos los registros importados

✅ **¡Listo! Importación completada.**

---

## 📊 PASO 10 (Opcional): VER ESTADÍSTICAS

Para ver cuántos items tiene cada biblioteca:

```bash
sudo koha-mysql koha-cnc -e "
SELECT homebranch, COUNT(*) as total_items
FROM items
GROUP BY homebranch
ORDER BY total_items DESC"
```

Resultado:
```
homebranch    total_items
ING           15086
POL           12467
VET           9086
FACEN         5234
ARQ           8579
```

---

## 🎓 EJEMPLO COMPLETO DE INICIO A FIN

### Escenario:
Recibiste por email: `ODONT_20251021.csv` (Facultad de Odontología)

### Paso a paso:

```bash
# 1. Conectar al servidor
ssh mvillalba@servidor

# 2. Ir al directorio
cd /home/mvillalba/migradatos

# 3. El archivo está en /tmp/ODONT_20251021.csv

# 4. Verificar que ODONT existe en Koha
sudo koha-mysql koha-cnc -e "SELECT * FROM branches WHERE branchcode = 'ODONT'"

# Si NO existe → Ir a Staff Interface y crear biblioteca ODONT

# 5. Ejecutar importación
./importar_nueva_biblioteca.sh ODONT /tmp/ODONT_20251021.csv

# 6. Responder SI cuando pregunte

# 7. Esperar... (20-30 minutos para 8000 registros)

# 8. Ver resultado en OPAC
# http://servidor:8080/cgi-bin/koha/opac-search.pl?branch=ODONT

# ✓ ¡Listo!
```

---

## 🆘 PROBLEMAS COMUNES Y SOLUCIONES

### Problema 1: "biblioteca NO existe en Koha"

**Causa:** No creaste la biblioteca en Koha primero

**Solución:**
1. Ir a Staff Interface
2. Administración → Bibliotecas → Nueva biblioteca
3. Crear biblioteca con el código correcto
4. Volver a ejecutar el script

---

### Problema 2: "archivo no encontrado"

**Causa:** La ruta del archivo es incorrecta

**Solución:**
```bash
# Buscar el archivo
find /home -name "*.csv" 2>/dev/null

# O si sabes dónde está
ls -lh /tmp/*.csv
ls -lh /home/mvillalba/*.csv

# Luego usar la ruta completa correcta
./importar_nueva_biblioteca.sh CODIGO /ruta/correcta/archivo.csv
```

---

### Problema 3: "permisos denegados"

**Causa:** No tienes permisos sudo

**Solución:**
```bash
# Agregar sudo antes del comando
sudo ./importar_nueva_biblioteca.sh CODIGO /ruta/archivo.csv
```

---

### Problema 4: No aparecen registros en OPAC

**Causa:** Índices no actualizados

**Solución:**
```bash
sudo koha-rebuild-zebra -f -v koha-cnc
```

Esperar 2-3 minutos y recargar la página (Ctrl+F5)

---

### Problema 5: "Script no hace nada"

**Causa:** Tal vez no es ejecutable

**Solución:**
```bash
chmod +x importar_nueva_biblioteca.sh
./importar_nueva_biblioteca.sh CODIGO /ruta/archivo.csv
```

---

## 📋 CHECKLIST RÁPIDO

Antes de importar, verificar:

- [ ] Tengo el archivo CSV
- [ ] Sé el código de la biblioteca (3-5 letras)
- [ ] La biblioteca existe en Koha (creada en Staff)
- [ ] Estoy conectado al servidor
- [ ] Estoy en el directorio /home/mvillalba/migradatos

Para importar:

```bash
./importar_nueva_biblioteca.sh CODIGO /ruta/archivo.csv
```

---

## 📁 ARCHIVOS GENERADOS

Después de la importación encontrarás:

```
/home/mvillalba/migradatos/
├── CODIGO_20251021.csv              ← CSV copiado
├── exports/
│   ├── CODIGO_20251021_marcxml_01.xml  ← XML generado
│   └── CODIGO_20251021_marcxml_02.xml
└── logs/
    └── importacion_CODIGO_20251021.log ← Reporte detallado
```

Ver el reporte:
```bash
cat logs/importacion_CODIGO_20251021.log
```

---

## 🎯 RESUMEN DE UN VISTAZO

```
1. Crear biblioteca en Koha (Staff Interface) - Solo primera vez
2. Conectar al servidor: ssh usuario@servidor
3. Ir al directorio: cd /home/mvillalba/migradatos
4. Ejecutar: ./importar_nueva_biblioteca.sh CODIGO /ruta/archivo.csv
5. Responder SI cuando pregunte
6. Esperar (automático)
7. Verificar en OPAC
8. ✓ ¡Listo!
```

---

## 📞 AYUDA ADICIONAL

**Comandos útiles:**

```bash
# Ver guía rápida
cat IMPORTAR_FACIL.md

# Ver todos los comandos en 1 página
cat CHEATSHEET.txt

# Ver logs recientes
ls -lht logs/ | head

# Ver bibliotecas con items
sudo koha-mysql koha-cnc -e "SELECT homebranch, COUNT(*) FROM items GROUP BY homebranch"
```

---

## ✅ CONCLUSIÓN

**Para importar un CSV solo necesitas:**

```bash
./importar_nueva_biblioteca.sh CODIGO /ruta/archivo.csv
```

**El script hace TODO automáticamente:**
- ✅ Verifica
- ✅ Analiza
- ✅ Genera XML
- ✅ Valida
- ✅ Importa
- ✅ Reindexar
- ✅ Verifica
- ✅ Genera reporte

**Tú solo esperas y verificas el resultado.**

---

**Fecha:** 2025-10-21
**Versión:** 1.0
**Sistema:** UNA → Koha - Proceso Totalmente Automatizado
