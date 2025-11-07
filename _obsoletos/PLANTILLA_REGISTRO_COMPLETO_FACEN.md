# 📖 PLANTILLA DE REGISTRO BIBLIOGRÁFICO COMPLETO
## Formato FACEN para OPAC de Koha

Este documento muestra un registro bibliográfico COMPLETO con TODOS los campos que se mostrarán en el OPAC, siguiendo el formato de:
**https://catalogobibliografico.facen.una.py**

---

## 🎯 EJEMPLO DE REGISTRO COMPLETO

### Vista Normal del OPAC

```
═══════════════════════════════════════════════════════════════════
                    EL SUELO Y SU FORMACIÓN
                  Fundamentos de edafología
═══════════════════════════════════════════════════════════════════

📖 INFORMACIÓN BIBLIOGRÁFICA

Título:         El suelo y su formación : fundamentos de edafología /
                José García López.

Autor:          García López, José, 1960-

Coautores:      Pérez, María Elena (colaboradora)
                Rodríguez, Carlos (editor)

Editorial:      Asunción : Editorial UNA, 2023.

Edición:        2ª ed. rev. y aum.

Descripción:    350 p. : il., gráfs., tablas ; 24 cm.

Serie:          Colección Ciencias Agrarias ; vol. 15

ISBN:           978-99967-1-234-5

Clasificación:  631.4 G216s (Dewey)
                S592.1 G37 (LC)

───────────────────────────────────────────────────────────────────

📋 RESUMEN

Este libro presenta los fundamentos sobre la formación y características
de los suelos, con énfasis en suelos tropicales y subtropicales de la
región. Incluye análisis de propiedades físicas, químicas y biológicas,
así como métodos de evaluación de fertilidad.

───────────────────────────────────────────────────────────────────

🏷️ MATERIAS

• Suelos
• Edafología
• Ciencias agrarias
• Agricultura tropical
• Paraguay

───────────────────────────────────────────────────────────────────

📝 NOTAS

• Incluye referencias bibliográficas (p. 340-348) e índice
• Bibliografía: p. 340-348
• Texto en español con resúmenes en inglés

───────────────────────────────────────────────────────────────────

📍 EJEMPLARES DISPONIBLES

┌────────────────────────────────────────────────────────────────┐
│ Biblioteca │ Ubicación  │ Signatura    │ Código Barras │ Estado │
├────────────┼────────────┼──────────────┼───────────────┼────────┤
│ FACAGR     │ Sala       │ 631.4 G216s  │ AGR-001234    │ ✓ Disp │
│ FACEN      │ Referencia │ 631.4 G216s  │ CEN-005678    │ ✗ Ref  │
│ FACMED     │ Depósito   │ 631.4 G216s  │ MED-002341    │ ✓ Disp │
│ POL        │ Sala       │ 631.4 G216s  │ POL-000987    │ ⏳ Pres│
└────────────────────────────────────────────────────────────────┘

Estado:
  ✓ Disponible para préstamo
  ✗ Solo consulta en sala (Referencia)
  ⏳ Prestado - Devolución: 2025-01-20

═══════════════════════════════════════════════════════════════════
```

---

## 📊 MAPEO COMPLETO DE CAMPOS MARC21

### Todos los campos necesarios para mostrar información completa en OPAC:

| Campo MARC | Descripción | Ejemplo | Dónde se ve en OPAC |
|------------|-------------|---------|---------------------|
| **CAMPOS DE CONTROL** |
| 001 | Número de control | `000558` | No visible (interno) |
| 003 | Identificador | `PyUNA` | No visible (interno) |
| 005 | Fecha modificación | `20240115120000.0` | No visible (interno) |
| 008 | Elementos fijos | `240115s2023    py ...` | No visible (interno) |
| **IDENTIFICADORES** |
| 020$a | ISBN | `978-99967-1-234-5` | ✓ ISBN |
| 022$a | ISSN | `1234-5678` | ✓ ISSN (revistas) |
| **CLASIFICACIÓN** |
| 050$a | Clasificación LC | `S592.1` | ✓ Clasificación |
| 082$a | Clasificación Dewey | `631.4` | ✓ Clasificación |
| **AUTORES** |
| 100$a | Autor principal | `García López, José` | ✓ **Autor** (destacado) |
| 100$d | Fechas del autor | `1960-` | ✓ Autor |
| 110$a | Autor corporativo | `Universidad Nacional de Asunción` | ✓ Autor |
| 700$a | Autor secundario | `Pérez, María Elena` | ✓ Coautores |
| 700$e | Relación | `colaboradora` | ✓ Coautores |
| **TÍTULO** |
| 245$a | Título principal | `El suelo y su formación` | ✓ **TÍTULO** (grande) |
| 245$b | Subtítulo | `fundamentos de edafología` | ✓ **Subtítulo** |
| 245$c | Responsabilidad | `José García López` | ✓ Mención responsabilidad |
| 246$a | Título variante | `Soil formation` | ✓ Otros títulos |
| **EDICIÓN** |
| 250$a | Mención de edición | `2ª ed. rev. y aum.` | ✓ **Edición** |
| **PUBLICACIÓN** |
| 260$a | Lugar publicación | `Asunción :` | ✓ **Editorial** |
| 260$b | Editorial | `Editorial UNA,` | ✓ **Editorial** |
| 260$c | Año | `2023.` | ✓ **Editorial** / Año |
| 264$a | Lugar (RDA) | `Asunción :` | ✓ Editorial (alternativo) |
| 264$b | Editorial (RDA) | `Editorial UNA,` | ✓ Editorial (alternativo) |
| 264$c | Fecha (RDA) | `2023.` | ✓ Editorial (alternativo) |
| **DESCRIPCIÓN FÍSICA** |
| 300$a | Extensión | `350 p. :` | ✓ **Descripción física** |
| 300$b | Otros detalles | `il., gráfs., tablas ;` | ✓ Descripción física |
| 300$c | Dimensiones | `24 cm.` | ✓ Descripción física |
| 300$e | Material acomp. | `+ 1 CD-ROM` | ✓ Descripción física |
| **SERIE** |
| 490$a | Serie | `Colección Ciencias Agrarias` | ✓ **Serie** |
| 490$v | Volumen | `vol. 15` | ✓ Serie |
| **NOTAS** |
| 500$a | Nota general | `Texto en español` | ✓ **Notas** |
| 504$a | Bibliografía | `Incluye referencias bibliográficas` | ✓ **Notas** |
| 505$a | Contenido | `Cap. 1. Introducción -- Cap. 2...` | ✓ Tabla de contenidos |
| 520$a | Resumen | `Este libro presenta...` | ✓ **RESUMEN** (destacado) |
| **MATERIAS** |
| 650$a | Materia-Tópico | `Suelos` | ✓ **MATERIAS** (lista) |
| 650$x | Subdivisión | `Análisis` | ✓ Materias |
| 650$z | Subdivisión geográfica | `Paraguay` | ✓ Materias |
| 651$a | Materia geográfica | `Paraguay` | ✓ Materias |
| **ENLACES** |
| 856$u | URL | `http://biblioteca.una.py/...` | ✓ **Acceso en línea** |
| 856$z | Texto del enlace | `Acceso al texto completo` | ✓ Enlace |
| **CONTROL KOHA** |
| 942$c | Tipo bibliográfico | `BK` | ✓ Tipo de documento |
| **EJEMPLARES (952)** |
| 952$a | Biblioteca propietaria | `FACAGR` | ✓ **Ejemplares** (tabla) |
| 952$b | Biblioteca física | `FACAGR` | ✓ Ejemplares |
| 952$c | Ubicación | `SALA` | ✓ **Ubicación** |
| 952$o | Signatura | `631.4 G216s` | ✓ **Signatura** |
| 952$p | Código de barras | `AGR-001234` | ✓ **Código barras** |
| 952$y | Tipo ítem | `BK` | ✓ Tipo |
| 952$7 | Estado préstamo | `0` = Disponible | ✓ **Estado** |
| 952$d | Fecha adquisición | `2023-03-15` | No visible |
| 952$g | Precio | `150000` | No visible (staff) |
| 952$h | Volumen | `Tomo 1` | ✓ Vol/Ejemplar |

---

## 📝 MARCXML COMPLETO - PLANTILLA

```xml
<?xml version="1.0" encoding="UTF-8"?>
<collection xmlns="http://www.loc.gov/MARC21/slim">
  <record>

    <!-- Leader -->
    <leader>00000nam a2200000 i 4500</leader>

    <!-- Campos de control -->
    <controlfield tag="001">000558</controlfield>
    <controlfield tag="003">PyUNA</controlfield>
    <controlfield tag="005">20240115120000.0</controlfield>
    <controlfield tag="008">240115s2023    py a     b    001 0 spa d</controlfield>

    <!-- ISBN -->
    <datafield tag="020" ind1=" " ind2=" ">
      <subfield code="a">978-99967-1-234-5</subfield>
    </datafield>

    <!-- Agencia catalogadora -->
    <datafield tag="040" ind1=" " ind2=" ">
      <subfield code="a">FACAGR</subfield>
      <subfield code="b">spa</subfield>
      <subfield code="c">FACAGR</subfield>
    </datafield>

    <!-- Clasificación LC -->
    <datafield tag="050" ind1=" " ind2="4">
      <subfield code="a">S592.1</subfield>
      <subfield code="b">G37</subfield>
    </datafield>

    <!-- Clasificación Dewey -->
    <datafield tag="082" ind1="0" ind2="4">
      <subfield code="a">631.4</subfield>
      <subfield code="2">23</subfield>
    </datafield>

    <!-- Autor principal -->
    <datafield tag="100" ind1="1" ind2=" ">
      <subfield code="a">García López, José,</subfield>
      <subfield code="d">1960-</subfield>
    </datafield>

    <!-- Título -->
    <datafield tag="245" ind1="1" ind2="4">
      <subfield code="a">El suelo y su formación :</subfield>
      <subfield code="b">fundamentos de edafología /</subfield>
      <subfield code="c">José García López.</subfield>
    </datafield>

    <!-- Título variante -->
    <datafield tag="246" ind1="3" ind2="1">
      <subfield code="a">Fundamentos de edafología</subfield>
    </datafield>

    <!-- Edición -->
    <datafield tag="250" ind1=" " ind2=" ">
      <subfield code="a">2ª ed. rev. y aum.</subfield>
    </datafield>

    <!-- Publicación (RDA) -->
    <datafield tag="264" ind1=" " ind2="1">
      <subfield code="a">Asunción :</subfield>
      <subfield code="b">Editorial UNA,</subfield>
      <subfield code="c">2023.</subfield>
    </datafield>

    <!-- Descripción física -->
    <datafield tag="300" ind1=" " ind2=" ">
      <subfield code="a">350 p. :</subfield>
      <subfield code="b">il., gráfs., tablas ;</subfield>
      <subfield code="c">24 cm.</subfield>
    </datafield>

    <!-- Serie -->
    <datafield tag="490" ind1="1" ind2=" ">
      <subfield code="a">Colección Ciencias Agrarias ;</subfield>
      <subfield code="v">vol. 15</subfield>
    </datafield>

    <!-- Nota general -->
    <datafield tag="500" ind1=" " ind2=" ">
      <subfield code="a">Texto en español con resúmenes en inglés.</subfield>
    </datafield>

    <!-- Bibliografía -->
    <datafield tag="504" ind1=" " ind2=" ">
      <subfield code="a">Incluye referencias bibliográficas (p. 340-348) e índice.</subfield>
    </datafield>

    <!-- Contenido -->
    <datafield tag="505" ind1="0" ind2=" ">
      <subfield code="a">Cap. 1. Introducción a la edafología -- Cap. 2. Formación del suelo -- Cap. 3. Propiedades físicas -- Cap. 4. Propiedades químicas -- Cap. 5. Fertilidad -- Cap. 6. Evaluación de suelos.</subfield>
    </datafield>

    <!-- Resumen -->
    <datafield tag="520" ind1=" " ind2=" ">
      <subfield code="a">Este libro presenta los fundamentos sobre la formación y características de los suelos, con énfasis en suelos tropicales y subtropicales de la región. Incluye análisis de propiedades físicas, químicas y biológicas, así como métodos de evaluación de fertilidad.</subfield>
    </datafield>

    <!-- Materias -->
    <datafield tag="650" ind1=" " ind2="4">
      <subfield code="a">Suelos.</subfield>
    </datafield>

    <datafield tag="650" ind1=" " ind2="4">
      <subfield code="a">Edafología.</subfield>
    </datafield>

    <datafield tag="650" ind1=" " ind2="4">
      <subfield code="a">Ciencias agrarias.</subfield>
    </datafield>

    <datafield tag="650" ind1=" " ind2="4">
      <subfield code="a">Agricultura tropical.</subfield>
    </datafield>

    <datafield tag="651" ind1=" " ind2="4">
      <subfield code="a">Paraguay.</subfield>
    </datafield>

    <!-- Coautores -->
    <datafield tag="700" ind1="1" ind2=" ">
      <subfield code="a">Pérez, María Elena,</subfield>
      <subfield code="e">colaboradora.</subfield>
    </datafield>

    <datafield tag="700" ind1="1" ind2=" ">
      <subfield code="a">Rodríguez, Carlos,</subfield>
      <subfield code="e">editor.</subfield>
    </datafield>

    <!-- Entrada de serie -->
    <datafield tag="830" ind1=" " ind2="0">
      <subfield code="a">Colección Ciencias Agrarias ;</subfield>
      <subfield code="v">v. 15.</subfield>
    </datafield>

    <!-- Acceso electrónico (opcional) -->
    <datafield tag="856" ind1="4" ind2="0">
      <subfield code="u">http://biblioteca.una.py/documentos/suelo_formacion.pdf</subfield>
      <subfield code="z">Acceso al texto completo</subfield>
    </datafield>

    <!-- Tipo bibliográfico Koha -->
    <datafield tag="942" ind1=" " ind2=" ">
      <subfield code="c">BK</subfield>
    </datafield>

    <!-- ========================================================= -->
    <!-- EJEMPLARES - Campo 952                                    -->
    <!-- ========================================================= -->

    <!-- Ejemplar 1: FACAGR - Sala -->
    <datafield tag="952" ind1=" " ind2=" ">
      <subfield code="a">FACAGR</subfield>          <!-- homebranch -->
      <subfield code="b">FACAGR</subfield>          <!-- holdingbranch -->
      <subfield code="c">SALA</subfield>            <!-- location -->
      <subfield code="o">631.4 G216s</subfield>     <!-- signatura -->
      <subfield code="p">AGR-001234</subfield>      <!-- barcode -->
      <subfield code="y">BK</subfield>              <!-- itemtype -->
      <subfield code="2">ddc</subfield>             <!-- clasificación -->
      <subfield code="7">0</subfield>               <!-- disponible -->
      <subfield code="d">2023-03-15</subfield>      <!-- fecha adq -->
      <subfield code="g">150000</subfield>          <!-- precio -->
      <subfield code="e">Compra</subfield>          <!-- fuente -->
    </datafield>

    <!-- Ejemplar 2: FACEN - Referencia -->
    <datafield tag="952" ind1=" " ind2=" ">
      <subfield code="a">FACEN</subfield>
      <subfield code="b">FACEN</subfield>
      <subfield code="c">REF</subfield>
      <subfield code="o">631.4 G216s</subfield>
      <subfield code="p">CEN-005678</subfield>
      <subfield code="y">BK</subfield>
      <subfield code="2">ddc</subfield>
      <subfield code="7">1</subfield>               <!-- no se presta -->
      <subfield code="d">2023-04-20</subfield>
      <subfield code="g">150000</subfield>
      <subfield code="e">Donación</subfield>
    </datafield>

    <!-- Ejemplar 3: FACMED - Depósito -->
    <datafield tag="952" ind1=" " ind2=" ">
      <subfield code="a">FACMED</subfield>
      <subfield code="b">FACMED</subfield>
      <subfield code="c">DEP</subfield>
      <subfield code="o">631.4 G216s</subfield>
      <subfield code="p">MED-002341</subfield>
      <subfield code="y">BK</subfield>
      <subfield code="2">ddc</subfield>
      <subfield code="7">0</subfield>
      <subfield code="d">2023-05-10</subfield>
      <subfield code="g">150000</subfield>
      <subfield code="e">Compra</subfield>
    </datafield>

    <!-- Ejemplar 4: POL - Sala (Prestado) -->
    <datafield tag="952" ind1=" " ind2=" ">
      <subfield code="a">POL</subfield>
      <subfield code="b">POL</subfield>
      <subfield code="c">SALA</subfield>
      <subfield code="o">631.4 G216s</subfield>
      <subfield code="p">POL-000987</subfield>
      <subfield code="y">BK</subfield>
      <subfield code="2">ddc</subfield>
      <subfield code="7">0</subfield>
      <subfield code="d">2023-02-01</subfield>
      <subfield code="g">150000</subfield>
      <subfield code="e">Compra</subfield>
    </datafield>

  </record>
</collection>
```

---

## ✅ CHECKLIST DE CAMPOS PARA OPAC COMPLETO

### Obligatorios (Mínimo para que se vea bien)

- [ ] **245$a** - Título principal
- [ ] **100$a** o **110$a** - Autor
- [ ] **264$a/b/c** o **260$a/b/c** - Editorial, lugar, año
- [ ] **952$a** - Biblioteca propietaria
- [ ] **952$b** - Biblioteca física
- [ ] **952$p** - Código de barras
- [ ] **952$y** - Tipo de ítem
- [ ] **952$o** - Signatura

### Muy Recomendados (Para mostrar bien)

- [ ] **245$b** - Subtítulo
- [ ] **250$a** - Edición
- [ ] **300$a/b/c** - Descripción física
- [ ] **520$a** - Resumen
- [ ] **650$a** - Materias (al menos 2-3)
- [ ] **020$a** - ISBN
- [ ] **082$a** - Clasificación Dewey
- [ ] **952$c** - Ubicación física

### Opcionales (Mejoran la información)

- [ ] **490$a/v** - Serie
- [ ] **504$a** - Bibliografía
- [ ] **505$a** - Tabla de contenidos
- [ ] **700$a** - Coautores
- [ ] **856$u** - Enlace electrónico
- [ ] **050$a** - Clasificación LC
- [ ] **246$a** - Títulos variantes

---

## 🎨 CONFIGURACIÓN DEL OPAC (Koha)

Para que se vea como FACEN, configurar:

### 1. System Preferences > OPAC

```
OPACXSLTDetailsDisplay: default
OpacShowItemsFromOtherBranches: Yes
OPACShowCheckoutName: Show
OpacItemLocation: location
```

### 2. OPAC CSS (OPACUserCSS)

```css
/* Mejorar visualización como FACEN */
#catalogue_detail_biblio {
    max-width: 1200px;
    margin: 0 auto;
}

.results_summary {
    padding: 12px 0;
    border-bottom: 1px solid #eee;
}

.label {
    font-weight: bold;
    color: #0066cc;
    margin-right: 10px;
}

#holdings {
    margin-top: 30px;
}

#holdings th {
    background-color: #f0f0f0;
    padding: 12px;
    border: 1px solid #ddd;
}

#holdings td {
    padding: 10px;
    border: 1px solid #ddd;
}
```

---

**Fecha:** 2025-01-15
**Referencia:** https://catalogobibliografico.facen.una.py
**Sistema:** Koha MARC21
