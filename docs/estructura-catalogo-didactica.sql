/* ===============================================
   KOHA - ESTRUCTURA DE CATÁLOGO BIBLIOGRÁFICO
   ===============================================
   Guía didáctica completa de todas las tablas
   y campos necesarios para un catálogo óptimo
   =============================================== */

-- =============================================
-- TABLA 1: BIBLIO (Registro Bibliográfico Base)
-- =============================================
-- Almacena la información bibliográfica principal de cada registro
-- Un libro puede tener múltiples copias físicas (items)

CREATE TABLE IF NOT EXISTS biblio (
    -- IDENTIFICADORES --
    biblionumber INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del registro bibliográfico (autogenerado)',
    frameworkcode VARCHAR(4) DEFAULT '' COMMENT 'Código del framework MARC21 usado (ej: BKS para libros, dejar vacío para default)',

    -- INFORMACIÓN BÁSICA --
    title LONGTEXT COMMENT 'Título completo de la obra (OBLIGATORIO) - Ej: "Cien años de soledad"',
    author LONGTEXT COMMENT 'Autor principal (formato: Apellido, Nombre) - Ej: "García Márquez, Gabriel"',

    -- INFORMACIÓN COMPLEMENTARIA --
    subtitle LONGTEXT COMMENT 'Subtítulo de la obra - Ej: "Una crónica familiar"',
    medium LONGTEXT COMMENT 'Medio o formato - Ej: "texto impreso", "recurso electrónico"',
    part_number LONGTEXT COMMENT 'Número de parte si es obra en varios volúmenes - Ej: "Tomo 1"',
    part_name LONGTEXT COMMENT 'Nombre de la parte - Ej: "Primera parte"',
    unititle LONGTEXT COMMENT 'Título uniforme (para obras con múltiples traducciones)',

    -- SERIES Y PUBLICACIÓN --
    seriestitle LONGTEXT COMMENT 'Título de la serie a la que pertenece - Ej: "Biblioteca García Márquez"',
    serial TINYINT(1) DEFAULT 0 COMMENT 'Es publicación seriada (revista/periódico)? 1=Sí, 0=No',
    copyrightdate SMALLINT COMMENT 'Año de copyright - Ej: 1967',

    -- NOTAS Y RESUMEN --
    notes LONGTEXT COMMENT 'Notas generales sobre la obra - Ej: "Primera edición"',
    abstract LONGTEXT COMMENT 'Resumen o sinopsis del contenido de la obra',

    -- CONTROL --
    datecreated DATE NOT NULL COMMENT 'Fecha de creación del registro en Koha (YYYY-MM-DD)',
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última modificación (automático)'

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Tabla principal de registros bibliográficos';

-- =============================================
-- TABLA 2: BIBLIOITEMS (Detalles de Publicación)
-- =============================================
-- Almacena detalles específicos de la publicación y edición
-- Relacionada 1:1 con biblio

CREATE TABLE IF NOT EXISTS biblioitems (
    -- IDENTIFICADORES --
    biblioitemnumber INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del item bibliográfico (autogenerado)',
    biblionumber INT NOT NULL COMMENT 'ID del registro biblio asociado (OBLIGATORIO)',

    -- IDENTIFICADORES ESTÁNDAR --
    isbn LONGTEXT COMMENT 'ISBN (10 o 13 dígitos) - Ej: "978-84-376-0494-7"',
    issn LONGTEXT COMMENT 'ISSN (para publicaciones seriadas) - Ej: "1234-5678"',
    ean LONGTEXT COMMENT 'Código EAN/Código de barras europeo',
    lccn LONGTEXT COMMENT 'Library of Congress Control Number',

    -- INFORMACIÓN DE PUBLICACIÓN --
    publishercode TEXT COMMENT 'Nombre de la editorial - Ej: "Editorial Sudamericana"',
    publicationyear MEDIUMTEXT COMMENT 'Año de publicación - Ej: "1967"',
    place TEXT COMMENT 'Lugar de publicación - Ej: "Buenos Aires"',

    -- EDICIÓN --
    editionstatement MEDIUMTEXT COMMENT 'Declaración de edición - Ej: "Primera edición", "2da ed. revisada"',
    editionresponsibility MEDIUMTEXT COMMENT 'Responsabilidad de la edición - Ej: "Revisado por Juan Pérez"',

    -- CARACTERÍSTICAS FÍSICAS --
    pages TEXT COMMENT 'Número de páginas - Ej: "471 p.", "xxiv, 325 p."',
    size TEXT COMMENT 'Dimensiones físicas - Ej: "21 cm", "24 x 17 cm"',
    illus TEXT COMMENT 'Ilustraciones - Ej: "ilustraciones color", "mapas, gráficos"',

    -- VOLUMEN/SERIE --
    volume LONGTEXT COMMENT 'Número de volumen - Ej: "Vol. 3"',
    number LONGTEXT COMMENT 'Número dentro de serie - Ej: "No. 15"',
    volumedate DATE COMMENT 'Fecha del volumen (para seriadas)',
    volumedesc MEDIUMTEXT COMMENT 'Descripción del volumen',

    -- COLECCIÓN --
    collectiontitle LONGTEXT COMMENT 'Título de la colección - Ej: "Biblioteca Clásica"',
    collectionissn MEDIUMTEXT COMMENT 'ISSN de la colección',
    collectionvolume LONGTEXT COMMENT 'Volumen dentro de colección',

    -- CLASIFICACIÓN --
    itemtype VARCHAR(10) COMMENT 'Tipo de material - Ej: "BK"=Libro, "DVD"=DVD, "MAG"=Revista',
    cn_source VARCHAR(10) COMMENT 'Fuente de clasificación - Ej: "ddc" (Dewey), "lcc" (Library of Congress)',
    cn_class VARCHAR(30) COMMENT 'Número de clasificación principal - Ej: "863" (Dewey para literatura española)',
    cn_item VARCHAR(10) COMMENT 'Número de ítem en clasificación',
    cn_suffix VARCHAR(10) COMMENT 'Sufijo de clasificación',
    cn_sort VARCHAR(255) COMMENT 'Clasificación para ordenamiento (automático)',

    -- OTROS --
    url MEDIUMTEXT COMMENT 'URL del recurso electrónico (si aplica) - Ej: "http://ejemplo.com/libro.pdf"',
    agerestriction VARCHAR(255) COMMENT 'Restricción de edad - Ej: "PEGI 12", "Mayores de 18"',
    notes LONGTEXT COMMENT 'Notas bibliográficas adicionales',
    totalissues INT DEFAULT 0 COMMENT 'Total de préstamos históricos (automático)',

    -- CONTROL --
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última modificación',

    FOREIGN KEY (biblionumber) REFERENCES biblio(biblionumber) ON DELETE CASCADE

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Detalles de publicación y características físicas';

-- =============================================
-- TABLA 3: ITEMS (Copias Físicas/Ejemplares)
-- =============================================
-- Almacena cada copia física individual de una obra
-- Un biblio puede tener múltiples items (ejemplares)

CREATE TABLE IF NOT EXISTS items (
    -- IDENTIFICADORES --
    itemnumber INT AUTO_INCREMENT PRIMARY KEY COMMENT 'ID único del ejemplar físico (autogenerado)',
    biblionumber INT NOT NULL COMMENT 'ID del registro biblio (OBLIGATORIO)',
    biblioitemnumber INT NOT NULL COMMENT 'ID del biblioitem (OBLIGATORIO)',

    -- IDENTIFICACIÓN FÍSICA --
    barcode VARCHAR(20) UNIQUE COMMENT 'Código de barras único del ejemplar - Ej: "LIBRO001", "3900123456789"',

    -- UBICACIÓN --
    homebranch VARCHAR(10) COMMENT 'Biblioteca propietaria (código) - Ej: "ING", "ODO", "CENTRAL"',
    holdingbranch VARCHAR(10) COMMENT 'Biblioteca donde se encuentra actualmente (código)',
    location VARCHAR(80) COMMENT 'Ubicación específica - Ej: "Estantería General", "Sala de Referencia", "Depósito"',
    permanent_location VARCHAR(80) COMMENT 'Ubicación permanente del ítem',

    -- CLASIFICACIÓN --
    itemcallnumber VARCHAR(255) COMMENT 'Signatura topográfica - Ej: "863 GAR", "FIC GAR c.1"',
    cn_source VARCHAR(10) COMMENT 'Fuente de clasificación - Ej: "ddc", "lcc"',
    cn_sort VARCHAR(255) COMMENT 'Para ordenamiento (automático)',

    -- COLECCIÓN Y TIPO --
    itype VARCHAR(10) COMMENT 'Tipo de ítem - Ej: "BK" (Libro), "DVD", "CD", "REF" (Referencia)',
    ccode VARCHAR(80) COMMENT 'Código de colección - Ej: "FIC" (Ficción), "NF" (No ficción), "REF"',

    -- PRECIOS Y ADQUISICIÓN --
    price DECIMAL(8,2) COMMENT 'Precio de compra - Ej: 25.50',
    replacementprice DECIMAL(8,2) COMMENT 'Precio de reemplazo - Ej: 35.00',
    replacementpricedate DATE COMMENT 'Fecha del precio de reemplazo',
    dateaccessioned DATE COMMENT 'Fecha de ingreso al catálogo (YYYY-MM-DD)',
    booksellerid LONGTEXT COMMENT 'ID del proveedor',

    -- ESTADO DEL ÍTEM --
    notforloan TINYINT(1) DEFAULT 0 COMMENT '¿No prestable? 0=Prestable, 1=Solo consulta, 2=Reservado',
    damaged TINYINT(1) DEFAULT 0 COMMENT '¿Dañado? 0=No, 1=Sí',
    damaged_on DATETIME COMMENT 'Fecha/hora en que se marcó como dañado',
    itemlost TINYINT(1) DEFAULT 0 COMMENT '¿Perdido? 0=No, 1=Perdido, 2=Perdido y pagado',
    itemlost_on DATETIME COMMENT 'Fecha/hora en que se marcó como perdido',
    withdrawn TINYINT(1) DEFAULT 0 COMMENT '¿Retirado de circulación? 0=No, 1=Sí',
    withdrawn_on DATETIME COMMENT 'Fecha/hora de retiro',
    restricted TINYINT(1) COMMENT '¿Acceso restringido? NULL=No, 1=Sí',
    bookable TINYINT(1) COMMENT '¿Se puede reservar? 0=No, 1=Sí',

    -- ESTADÍSTICAS DE USO --
    issues SMALLINT DEFAULT 0 COMMENT 'Número de préstamos totales (automático)',
    renewals SMALLINT DEFAULT 0 COMMENT 'Número de renovaciones (automático)',
    reserves SMALLINT DEFAULT 0 COMMENT 'Número de reservas actuales (automático)',
    localuse SMALLINT DEFAULT 0 COMMENT 'Usos locales (consulta en sala)',

    -- PRÉSTAMO ACTUAL --
    onloan DATE COMMENT 'Fecha de devolución si está prestado (automático)',
    datelastborrowed DATE COMMENT 'Fecha del último préstamo (automático)',
    datelastseen DATETIME COMMENT 'Última vez visto/inventariado',

    -- NOTAS --
    itemnotes LONGTEXT COMMENT 'Notas públicas del ejemplar - Ej: "Incluye CD-ROM", "Tiene dedicatoria"',
    itemnotes_nonpublic LONGTEXT COMMENT 'Notas internas (no visibles en OPAC) - Ej: "Revisar encuadernación"',

    -- INFORMACIÓN FÍSICA ADICIONAL --
    materials MEDIUMTEXT COMMENT 'Materiales adicionales - Ej: "Incluye CD", "Con DVD"',
    uri MEDIUMTEXT COMMENT 'URI del recurso electrónico asociado',
    enumchron MEDIUMTEXT COMMENT 'Enumeración cronológica (para seriadas) - Ej: "v.15, no.3 (2023)"',
    copynumber VARCHAR(32) COMMENT 'Número de copia - Ej: "c.1", "c.2"',
    stocknumber VARCHAR(80) COMMENT 'Número de inventario/stock',

    -- OTROS --
    coded_location_qualifier VARCHAR(10) COMMENT 'Calificador de ubicación codificado',
    new_status VARCHAR(32) COMMENT 'Estado "nuevo" (para destacar novedades)',
    stack TINYINT(1) COMMENT 'Requiere solicitud de depósito? 0=No, 1=Sí',
    exclude_from_local_holds_priority TINYINT(1) COMMENT 'Excluir de prioridad de reservas locales',
    more_subfields_xml LONGTEXT COMMENT 'Subcampos MARC adicionales en XML',

    -- CONTROL --
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Última modificación',
    deleted_on DATETIME COMMENT 'Fecha de eliminación (si aplica)',

    FOREIGN KEY (biblionumber) REFERENCES biblio(biblionumber) ON DELETE CASCADE,
    FOREIGN KEY (biblioitemnumber) REFERENCES biblioitems(biblioitemnumber) ON DELETE CASCADE,

    INDEX idx_barcode (barcode),
    INDEX idx_homebranch (homebranch),
    INDEX idx_location (location),
    INDEX idx_itype (itype)

) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Ejemplares físicos individuales del catálogo';

/* ===============================================
   EJEMPLOS PRÁCTICOS DE INSERCIÓN
   =============================================== */

-- EJEMPLO 1: Libro de ficción con un solo ejemplar
-- Paso 1: Insertar registro bibliográfico
INSERT INTO biblio (
    title,
    author,
    copyrightdate,
    datecreated,
    abstract
) VALUES (
    'Cien años de soledad',                          -- Título
    'García Márquez, Gabriel',                       -- Autor (Apellido, Nombre)
    1967,                                             -- Año de copyright
    CURDATE(),                                        -- Fecha actual
    'Historia de la familia Buendía a lo largo de siete generaciones' -- Resumen
);

-- Paso 2: Obtener el biblionumber generado
SET @biblionumber = LAST_INSERT_ID();

-- Paso 3: Insertar detalles de publicación
INSERT INTO biblioitems (
    biblionumber,
    isbn,
    publishercode,
    publicationyear,
    pages,
    itemtype,
    cn_class
) VALUES (
    @biblionumber,                                    -- ID del biblio
    '978-84-376-0494-7',                             -- ISBN
    'Editorial Sudamericana',                         -- Editorial
    '1967',                                           -- Año publicación
    '471',                                            -- Páginas
    'BK',                                             -- Tipo: Libro
    '863'                                             -- Clasificación Dewey
);

-- Paso 4: Obtener el biblioitemnumber generado
SET @biblioitemnumber = LAST_INSERT_ID();

-- Paso 5: Insertar ejemplar físico
INSERT INTO items (
    biblionumber,
    biblioitemnumber,
    barcode,
    homebranch,
    holdingbranch,
    location,
    itemcallnumber,
    itype,
    ccode,
    price,
    replacementprice,
    dateaccessioned,
    notforloan
) VALUES (
    @biblionumber,                                    -- ID del biblio
    @biblioitemnumber,                                -- ID del biblioitem
    'LIBRO001',                                       -- Código de barras
    'ING',                                            -- Biblioteca: Ingeniería
    'ING',                                            -- Actualmente en: Ingeniería
    'Estantería General',                             -- Ubicación física
    '863 GAR',                                        -- Signatura
    'BK',                                             -- Tipo: Libro
    'FIC',                                            -- Colección: Ficción
    25.00,                                            -- Precio
    35.00,                                            -- Precio reemplazo
    CURDATE(),                                        -- Fecha ingreso
    0                                                 -- 0 = Prestable
);

-- EJEMPLO 2: Libro de texto con múltiples copias
INSERT INTO biblio (title, author, copyrightdate, datecreated)
VALUES ('Cálculo con geometría analítica', 'Larson, Ron', 2006, CURDATE());
SET @biblionumber = LAST_INSERT_ID();

INSERT INTO biblioitems (biblionumber, isbn, publishercode, publicationyear, pages, itemtype, cn_class)
VALUES (@biblionumber, '978-968-18-6186-8', 'McGraw-Hill', '2006', '1024', 'BK', '515');
SET @biblioitemnumber = LAST_INSERT_ID();

-- Copia 1
INSERT INTO items (biblionumber, biblioitemnumber, barcode, homebranch, location, itemcallnumber, itype, ccode, price, dateaccessioned, copynumber)
VALUES (@biblionumber, @biblioitemnumber, 'TEXTO001', 'ING', 'Matemáticas', '515 LAR', 'BK', 'TEXTB', 65.00, CURDATE(), 'c.1');

-- Copia 2
INSERT INTO items (biblionumber, biblioitemnumber, barcode, homebranch, location, itemcallnumber, itype, ccode, price, dateaccessioned, copynumber)
VALUES (@biblionumber, @biblioitemnumber, 'TEXTO002', 'ING', 'Matemáticas', '515 LAR', 'BK', 'TEXTB', 65.00, CURDATE(), 'c.2');

-- Copia 3
INSERT INTO items (biblionumber, biblioitemnumber, barcode, homebranch, location, itemcallnumber, itype, ccode, price, dateaccessioned, copynumber)
VALUES (@biblionumber, @biblioitemnumber, 'TEXTO003', 'ING', 'Matemáticas', '515 LAR', 'BK', 'TEXTB', 65.00, CURDATE(), 'c.3');

/* ===============================================
   CATÁLOGO DE VALORES COMUNES
   =============================================== */

/*
ITEMTYPE (Tipos de Material):
- BK    = Libro
- DVD   = DVD/Video
- CD    = CD/Audio
- MAG   = Revista
- NEWS  = Periódico
- MAP   = Mapa
- SCORE = Partitura
- REF   = Referencia

CCODE (Códigos de Colección):
- FIC   = Ficción
- NF    = No Ficción
- REF   = Referencia
- JUV   = Juvenil
- INF   = Infantil
- TEXTB = Libro de texto
- TESIS = Tesis
- CS    = Ciencias de la Computación

NOTFORLOAN (Estados de préstamo):
- 0 = Prestable (disponible para préstamo)
- 1 = No prestable (solo consulta en sala)
- 2 = En proceso técnico
- -1 = En orden (pedido)

CLASIFICACIÓN DEWEY (cn_class - primeros dígitos):
- 000-099 = Informática, información y obras generales
- 100-199 = Filosofía y psicología
- 200-299 = Religión
- 300-399 = Ciencias sociales
- 400-499 = Lenguas
- 500-599 = Ciencias naturales y matemáticas
- 600-699 = Tecnología
- 700-799 = Arte y recreación
- 800-899 = Literatura
- 900-999 = Historia y geografía

Ejemplos específicos:
- 005.133 = Lenguajes de programación
- 515     = Cálculo
- 571     = Biología
- 823     = Literatura inglesa
- 863     = Literatura española
*/

/* ===============================================
   CONSULTAS ÚTILES PARA VERIFICACIÓN
   =============================================== */

-- Ver todos los libros con sus ejemplares
SELECT
    b.biblionumber,
    b.title AS 'Título',
    b.author AS 'Autor',
    bi.isbn AS 'ISBN',
    bi.publishercode AS 'Editorial',
    i.barcode AS 'Código Barras',
    i.homebranch AS 'Biblioteca',
    i.location AS 'Ubicación',
    i.itemcallnumber AS 'Signatura',
    CASE WHEN i.onloan IS NOT NULL THEN 'Prestado' ELSE 'Disponible' END AS 'Estado'
FROM biblio b
LEFT JOIN biblioitems bi ON b.biblionumber = bi.biblionumber
LEFT JOIN items i ON b.biblionumber = i.biblionumber
ORDER BY b.title;

-- Contar ejemplares por biblioteca
SELECT
    homebranch AS 'Biblioteca',
    COUNT(*) AS 'Total Ejemplares'
FROM items
GROUP BY homebranch;

-- Libros más prestados
SELECT
    b.title AS 'Título',
    b.author AS 'Autor',
    SUM(i.issues) AS 'Total Préstamos'
FROM biblio b
JOIN items i ON b.biblionumber = i.biblionumber
GROUP BY b.biblionumber
ORDER BY SUM(i.issues) DESC
LIMIT 10;
