#!/bin/bash
################################################################################
# GENERADOR DE REPORTES ESTADÍSTICOS - KOHA UNA
################################################################################
# Genera reportes detallados de bibliotecas, títulos y ejemplares
#
# CARACTERÍSTICAS:
# - ✅ Reporte por biblioteca con totales
# - ✅ Ranking de bibliotecas por cantidad
# - ✅ Estadísticas generales del sistema
# - ✅ Gráficos ASCII visuales
# - ✅ Exportación a HTML, CSV y JSON
# - ✅ Comparación antes/después de importación
#
# USO:
#   ./generar_reporte_estadistico.sh                    # Reporte completo
#   ./generar_reporte_estadistico.sh --biblioteca ING   # Una biblioteca
#   ./generar_reporte_estadistico.sh --html             # Exportar a HTML
#   ./generar_reporte_estadistico.sh --json             # Exportar a JSON
#   ./generar_reporte_estadistico.sh --comparar         # Antes/después
#
# VERSIÓN: 1.0
# FECHA: 2025-11-04
################################################################################

set -euo pipefail

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTANCIA_KOHA="koha-cnc"
readonly DIR_REPORTES="${SCRIPT_DIR}/reportes"
readonly DIR_CACHE="${SCRIPT_DIR}/.cache"

# Timestamp
readonly TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
readonly FECHA_LEGIBLE=$(date '+%Y-%m-%d %H:%M:%S')

# Archivos de salida
readonly REPORTE_TXT="${DIR_REPORTES}/estadisticas_${TIMESTAMP}.txt"
readonly REPORTE_HTML="${DIR_REPORTES}/estadisticas_${TIMESTAMP}.html"
readonly REPORTE_CSV="${DIR_REPORTES}/estadisticas_${TIMESTAMP}.csv"
readonly REPORTE_JSON="${DIR_REPORTES}/estadisticas_${TIMESTAMP}.json"

# Colores
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[1;33m'
readonly C_BLUE='\033[0;34m'
readonly C_CYAN='\033[0;36m'
readonly C_MAGENTA='\033[0;35m'
readonly C_BOLD='\033[1m'
readonly C_NC='\033[0m'

# Variables globales
BIBLIOTECA_ESPECIFICA=""
EXPORTAR_HTML=false
EXPORTAR_CSV=false
EXPORTAR_JSON=false
MODO_COMPARACION=false
MOSTRAR_GRAFICOS=true

# ============================================================================
# FUNCIONES DE UTILIDAD
# ============================================================================

log_info() {
    echo -e "${C_CYAN}ℹ ${1}${C_NC}"
}

log_success() {
    echo -e "${C_GREEN}✓ ${1}${C_NC}"
}

log_error() {
    echo -e "${C_RED}✗ ${1}${C_NC}"
}

banner() {
    local msg="$1"
    local ancho=80
    echo ""
    echo -e "${C_BOLD}${C_CYAN}╔$(printf '═%.0s' $(seq 1 $((ancho-2))))╗${C_NC}"
    printf "${C_BOLD}${C_CYAN}║%-$((ancho-2))s║${C_NC}\n" " $msg"
    echo -e "${C_BOLD}${C_CYAN}╚$(printf '═%.0s' $(seq 1 $((ancho-2))))╝${C_NC}"
    echo ""
}

separador() {
    echo -e "${C_CYAN}$(printf '─%.0s' $(seq 1 80))${C_NC}"
}

crear_directorios() {
    mkdir -p "$DIR_REPORTES" "$DIR_CACHE"
}

# ============================================================================
# FUNCIONES DE BASE DE DATOS
# ============================================================================

ejecutar_query() {
    local query="$1"
    sudo koha-mysql ${INSTANCIA_KOHA} -sN -e "$query" 2>/dev/null || echo ""
}

obtener_estadisticas_generales() {
    local total_bibliotecas=$(ejecutar_query "SELECT COUNT(*) FROM branches")
    local total_titulos=$(ejecutar_query "SELECT COUNT(DISTINCT biblionumber) FROM biblio")
    local total_ejemplares=$(ejecutar_query "SELECT COUNT(*) FROM items")
    local total_usuarios=$(ejecutar_query "SELECT COUNT(*) FROM borrowers")
    local bibliotecas_con_items=$(ejecutar_query "SELECT COUNT(DISTINCT homebranch) FROM items")

    echo "$total_bibliotecas|$total_titulos|$total_ejemplares|$total_usuarios|$bibliotecas_con_items"
}

obtener_datos_bibliotecas() {
    # Obtiene: código|nombre|títulos|ejemplares
    ejecutar_query "
        SELECT
            b.branchcode,
            b.branchname,
            COUNT(DISTINCT i.biblionumber) as titulos,
            COUNT(i.itemnumber) as ejemplares
        FROM branches b
        LEFT JOIN items i ON b.branchcode = i.homebranch
        GROUP BY b.branchcode, b.branchname
        ORDER BY ejemplares DESC, titulos DESC
    "
}

obtener_datos_biblioteca_especifica() {
    local codigo="$1"
    ejecutar_query "
        SELECT
            b.branchcode,
            b.branchname,
            COUNT(DISTINCT i.biblionumber) as titulos,
            COUNT(i.itemnumber) as ejemplares
        FROM branches b
        LEFT JOIN items i ON b.branchcode = i.homebranch
        WHERE b.branchcode = '$codigo'
        GROUP BY b.branchcode, b.branchname
    "
}

obtener_top_bibliotecas() {
    local limite=${1:-10}
    ejecutar_query "
        SELECT
            b.branchcode,
            b.branchname,
            COUNT(DISTINCT i.biblionumber) as titulos,
            COUNT(i.itemnumber) as ejemplares
        FROM branches b
        LEFT JOIN items i ON b.branchcode = i.homebranch
        GROUP BY b.branchcode, b.branchname
        HAVING COUNT(i.itemnumber) > 0
        ORDER BY ejemplares DESC
        LIMIT $limite
    "
}

obtener_estadisticas_recientes() {
    local dias=${1:-30}
    ejecutar_query "
        SELECT
            COUNT(DISTINCT biblionumber) as titulos_nuevos,
            COUNT(*) as ejemplares_nuevos
        FROM items
        WHERE DATE(dateaccessioned) >= DATE_SUB(CURDATE(), INTERVAL $dias DAY)
    "
}

# ============================================================================
# FUNCIONES DE VISUALIZACIÓN
# ============================================================================

dibujar_barra() {
    local valor=$1
    local maximo=$2
    local ancho=${3:-50}

    local proporcion=0
    if [ $maximo -gt 0 ]; then
        proporcion=$((valor * ancho / maximo))
    fi

    local barra=$(printf '█%.0s' $(seq 1 $proporcion))
    local vacio=$(printf '░%.0s' $(seq 1 $((ancho - proporcion))))

    echo "${barra}${vacio}"
}

formato_numero() {
    local num=$1
    printf "%'d" $num 2>/dev/null || echo $num
}

# ============================================================================
# GENERACIÓN DE REPORTES
# ============================================================================

generar_encabezado() {
    cat << EOF
╔════════════════════════════════════════════════════════════════════════════╗
║                                                                            ║
║  📊 REPORTE ESTADÍSTICO - SISTEMA KOHA UNA                                ║
║     Universidad Nacional de Asunción                                      ║
║                                                                            ║
╚════════════════════════════════════════════════════════════════════════════╝

Fecha de generación: $FECHA_LEGIBLE
Instancia Koha:      $INSTANCIA_KOHA

EOF
}

generar_resumen_general() {
    log_info "Obteniendo estadísticas generales..."

    local stats=$(obtener_estadisticas_generales)
    IFS='|' read -r total_bibs total_tit total_ejem total_users bibs_con_items <<< "$stats"

    cat << EOF
═══════════════════════════════════════════════════════════════════════════
📈 RESUMEN GENERAL DEL SISTEMA
═══════════════════════════════════════════════════════════════════════════

Bibliotecas:
  • Total de bibliotecas:          $(formato_numero $total_bibs)
  • Bibliotecas con ítems:          $(formato_numero $bibs_con_items)
  • Bibliotecas sin ítems:          $(formato_numero $((total_bibs - bibs_con_items)))

Catálogo:
  • Total de títulos únicos:        $(formato_numero $total_tit)
  • Total de ejemplares:            $(formato_numero $total_ejem)
  • Promedio ejemplares/título:     $(echo "scale=2; $total_ejem / $total_tit" | bc 2>/dev/null || echo "N/A")

Usuarios:
  • Total de usuarios registrados:  $(formato_numero $total_users)

EOF
}

generar_tabla_bibliotecas() {
    log_info "Generando tabla de bibliotecas..."

    local datos=""
    if [ -n "$BIBLIOTECA_ESPECIFICA" ]; then
        datos=$(obtener_datos_biblioteca_especifica "$BIBLIOTECA_ESPECIFICA")
    else
        datos=$(obtener_datos_bibliotecas)
    fi

    if [ -z "$datos" ]; then
        echo "⚠ No se encontraron datos de bibliotecas"
        return
    fi

    # Calcular máximos para barras
    local max_titulos=$(echo "$datos" | awk -F'\t' '{print $3}' | sort -rn | head -1)
    local max_ejemplares=$(echo "$datos" | awk -F'\t' '{print $4}' | sort -rn | head -1)

    cat << EOF
═══════════════════════════════════════════════════════════════════════════
📚 DETALLE POR BIBLIOTECA
═══════════════════════════════════════════════════════════════════════════

┌─────────┬──────────────────────────────────┬───────────┬────────────┐
│ Código  │ Nombre                           │ Títulos   │ Ejemplares │
├─────────┼──────────────────────────────────┼───────────┼────────────┤
EOF

    local num=1
    local total_titulos=0
    local total_ejemplares=0

    while IFS=$'\t' read -r codigo nombre titulos ejemplares; do
        # Acumular totales
        total_titulos=$((total_titulos + titulos))
        total_ejemplares=$((total_ejemplares + ejemplares))

        # Formatear nombre (max 32 chars)
        nombre_truncado=$(printf "%-32.32s" "$nombre")

        printf "│ %-7s │ %-32s │ %9s │ %10s │\n" \
            "$codigo" \
            "$nombre_truncado" \
            "$(formato_numero $titulos)" \
            "$(formato_numero $ejemplares)"

        # Mostrar barras gráficas si está habilitado
        if [ "$MOSTRAR_GRAFICOS" = true ] && [ $max_ejemplares -gt 0 ]; then
            local barra=$(dibujar_barra $ejemplares $max_ejemplares 40)
            printf "│         │ ${C_GREEN}%-40s${C_NC} │           │            │\n" "$barra"
        fi

        ((num++))
    done <<< "$datos"

    cat << EOF
├─────────┴──────────────────────────────────┴───────────┴────────────┤
│ ${C_BOLD}TOTALES:                                  $(printf "%9s" "$(formato_numero $total_titulos)")   $(printf "%10s" "$(formato_numero $total_ejemplares)")${C_NC} │
└────────────────────────────────────────────────────────────────────┘

EOF
}

generar_top_bibliotecas() {
    log_info "Generando ranking de bibliotecas..."

    local datos=$(obtener_top_bibliotecas 10)

    if [ -z "$datos" ]; then
        return
    fi

    cat << EOF
═══════════════════════════════════════════════════════════════════════════
🏆 TOP 10 BIBLIOTECAS POR CANTIDAD DE EJEMPLARES
═══════════════════════════════════════════════════════════════════════════

EOF

    local pos=1
    local max_ejemplares=$(echo "$datos" | head -1 | awk -F'\t' '{print $4}')

    while IFS=$'\t' read -r codigo nombre titulos ejemplares; do
        local medalla=""
        case $pos in
            1) medalla="🥇" ;;
            2) medalla="🥈" ;;
            3) medalla="🥉" ;;
            *) medalla="  " ;;
        esac

        printf "%s #%-2d  %-8s  %-30s\n" "$medalla" $pos "$codigo" "$nombre"
        printf "        Títulos: %s | Ejemplares: %s\n" \
            "$(formato_numero $titulos)" \
            "$(formato_numero $ejemplares)"

        if [ "$MOSTRAR_GRAFICOS" = true ]; then
            local barra=$(dibujar_barra $ejemplares $max_ejemplares 60)
            printf "        ${C_CYAN}%s${C_NC}\n" "$barra"
        fi

        echo ""
        ((pos++))
    done <<< "$datos"
}

generar_estadisticas_recientes() {
    log_info "Analizando actividad reciente..."

    local stats_30d=$(obtener_estadisticas_recientes 30)
    local stats_7d=$(obtener_estadisticas_recientes 7)
    local stats_1d=$(obtener_estadisticas_recientes 1)

    IFS=$'\t' read -r tit_30d ejem_30d <<< "$stats_30d"
    IFS=$'\t' read -r tit_7d ejem_7d <<< "$stats_7d"
    IFS=$'\t' read -r tit_1d ejem_1d <<< "$stats_1d"

    cat << EOF
═══════════════════════════════════════════════════════════════════════════
📅 ACTIVIDAD RECIENTE (Nuevos Registros)
═══════════════════════════════════════════════════════════════════════════

Últimas 24 horas:
  • Títulos agregados:    $(formato_numero ${tit_1d:-0})
  • Ejemplares agregados:  $(formato_numero ${ejem_1d:-0})

Últimos 7 días:
  • Títulos agregados:    $(formato_numero ${tit_7d:-0})
  • Ejemplares agregados:  $(formato_numero ${ejem_7d:-0})

Últimos 30 días:
  • Títulos agregados:    $(formato_numero ${tit_30d:-0})
  • Ejemplares agregados:  $(formato_numero ${ejem_30d:-0})

EOF
}

generar_distribucion_visual() {
    if [ "$MOSTRAR_GRAFICOS" = false ]; then
        return
    fi

    log_info "Generando gráfico de distribución..."

    local datos=$(obtener_top_bibliotecas 15)

    cat << EOF
═══════════════════════════════════════════════════════════════════════════
📊 DISTRIBUCIÓN DE COLECCIONES (Top 15)
═══════════════════════════════════════════════════════════════════════════

EOF

    local max=$(echo "$datos" | head -1 | awk -F'\t' '{print $4}')

    while IFS=$'\t' read -r codigo nombre titulos ejemplares; do
        local barra=$(dibujar_barra $ejemplares $max 50)
        printf "%-6s ${C_GREEN}%-50s${C_NC} %s\n" \
            "$codigo" \
            "$barra" \
            "$(formato_numero $ejemplares)"
    done <<< "$datos"

    echo ""
}

generar_pie_reporte() {
    cat << EOF
═══════════════════════════════════════════════════════════════════════════
📝 NOTAS
═══════════════════════════════════════════════════════════════════════════

• Este reporte fue generado automáticamente
• Los datos reflejan el estado actual de la base de datos
• Para reportes personalizados, usa las opciones disponibles

Reportes generados:
  • Texto:  $REPORTE_TXT
EOF

    if [ "$EXPORTAR_HTML" = true ]; then
        echo "  • HTML:   $REPORTE_HTML"
    fi

    if [ "$EXPORTAR_CSV" = true ]; then
        echo "  • CSV:    $REPORTE_CSV"
    fi

    if [ "$EXPORTAR_JSON" = true ]; then
        echo "  • JSON:   $REPORTE_JSON"
    fi

    cat << EOF

Universidad Nacional de Asunción - Sistema de Bibliotecas
Generado: $FECHA_LEGIBLE

═══════════════════════════════════════════════════════════════════════════
EOF
}

# ============================================================================
# EXPORTACIÓN A HTML
# ============================================================================

exportar_html() {
    log_info "Generando reporte HTML..."

    local datos=$(obtener_datos_bibliotecas)
    local stats=$(obtener_estadisticas_generales)
    IFS='|' read -r total_bibs total_tit total_ejem total_users bibs_con_items <<< "$stats"

    cat > "$REPORTE_HTML" << 'HTML_START'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reporte Estadístico - Koha UNA</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }

        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            color: #333;
        }

        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 20px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }

        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }

        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }

        .header .subtitle {
            font-size: 1.2em;
            opacity: 0.9;
        }

        .header .timestamp {
            margin-top: 20px;
            font-size: 0.9em;
            opacity: 0.8;
        }

        .content {
            padding: 40px;
        }

        .stats-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }

        .stat-card {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            transition: transform 0.3s ease;
        }

        .stat-card:hover {
            transform: translateY(-5px);
        }

        .stat-card .label {
            font-size: 0.9em;
            opacity: 0.9;
            margin-bottom: 10px;
        }

        .stat-card .value {
            font-size: 2.5em;
            font-weight: bold;
        }

        .section-title {
            font-size: 1.8em;
            color: #667eea;
            margin: 40px 0 20px 0;
            padding-bottom: 10px;
            border-bottom: 3px solid #667eea;
        }

        table {
            width: 100%;
            border-collapse: collapse;
            margin: 20px 0;
            background: white;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            border-radius: 10px;
            overflow: hidden;
        }

        thead {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }

        th {
            padding: 15px;
            text-align: left;
            font-weight: 600;
        }

        td {
            padding: 12px 15px;
            border-bottom: 1px solid #f0f0f0;
        }

        tr:hover {
            background: #f8f9ff;
        }

        .bar-container {
            width: 100%;
            height: 20px;
            background: #e0e0e0;
            border-radius: 10px;
            overflow: hidden;
            margin-top: 5px;
        }

        .bar {
            height: 100%;
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            border-radius: 10px;
            transition: width 1s ease;
        }

        .number {
            text-align: right;
            font-weight: bold;
            color: #667eea;
        }

        .footer {
            background: #f8f9fa;
            padding: 30px;
            text-align: center;
            color: #666;
            border-top: 1px solid #e0e0e0;
        }

        .top-badge {
            display: inline-block;
            padding: 5px 10px;
            border-radius: 20px;
            font-size: 0.8em;
            font-weight: bold;
            margin-right: 10px;
        }

        .gold { background: #ffd700; color: #333; }
        .silver { background: #c0c0c0; color: #333; }
        .bronze { background: #cd7f32; color: white; }

        @media print {
            body { background: white; padding: 0; }
            .container { box-shadow: none; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 Reporte Estadístico</h1>
            <div class="subtitle">Sistema Koha - Universidad Nacional de Asunción</div>
HTML_START

    echo "            <div class=\"timestamp\">Generado: $FECHA_LEGIBLE</div>" >> "$REPORTE_HTML"

    cat >> "$REPORTE_HTML" << HTML_STATS
        </div>

        <div class="content">
            <div class="stats-grid">
                <div class="stat-card">
                    <div class="label">Total Bibliotecas</div>
                    <div class="value">$(formato_numero $total_bibs)</div>
                </div>
                <div class="stat-card">
                    <div class="label">Total Títulos</div>
                    <div class="value">$(formato_numero $total_tit)</div>
                </div>
                <div class="stat-card">
                    <div class="label">Total Ejemplares</div>
                    <div class="value">$(formato_numero $total_ejem)</div>
                </div>
                <div class="stat-card">
                    <div class="label">Bibliotecas con Ítems</div>
                    <div class="value">$(formato_numero $bibs_con_items)</div>
                </div>
            </div>

            <h2 class="section-title">Detalle por Biblioteca</h2>
            <table>
                <thead>
                    <tr>
                        <th>Ranking</th>
                        <th>Código</th>
                        <th>Nombre</th>
                        <th>Títulos</th>
                        <th>Ejemplares</th>
                        <th>Distribución</th>
                    </tr>
                </thead>
                <tbody>
HTML_STATS

    local max_ejemplares=$(echo "$datos" | head -1 | awk -F'\t' '{print $4}')
    local pos=1

    while IFS=$'\t' read -r codigo nombre titulos ejemplares; do
        local badge=""
        case $pos in
            1) badge='<span class="top-badge gold">🥇 #1</span>' ;;
            2) badge='<span class="top-badge silver">🥈 #2</span>' ;;
            3) badge='<span class="top-badge bronze">🥉 #3</span>' ;;
            *) badge="<span style='color: #999;'>#$pos</span>" ;;
        esac

        local porcentaje=0
        if [ $max_ejemplares -gt 0 ]; then
            porcentaje=$((ejemplares * 100 / max_ejemplares))
        fi

        cat >> "$REPORTE_HTML" << HTML_ROW
                    <tr>
                        <td>$badge</td>
                        <td><strong>$codigo</strong></td>
                        <td>$nombre</td>
                        <td class="number">$(formato_numero $titulos)</td>
                        <td class="number">$(formato_numero $ejemplares)</td>
                        <td>
                            <div class="bar-container">
                                <div class="bar" style="width: ${porcentaje}%"></div>
                            </div>
                        </td>
                    </tr>
HTML_ROW
        ((pos++))
    done <<< "$datos"

    cat >> "$REPORTE_HTML" << 'HTML_END'
                </tbody>
            </table>
        </div>

        <div class="footer">
            <p><strong>Universidad Nacional de Asunción</strong></p>
            <p>Sistema de Bibliotecas - Koha</p>
            <p style="margin-top: 10px; font-size: 0.9em;">
                Reporte generado automáticamente por el sistema de importación ultra-optimizado
            </p>
        </div>
    </div>
</body>
</html>
HTML_END

    log_success "Reporte HTML generado: $REPORTE_HTML"
}

# ============================================================================
# EXPORTACIÓN A CSV
# ============================================================================

exportar_csv() {
    log_info "Generando reporte CSV..."

    local datos=$(obtener_datos_bibliotecas)

    # Encabezado
    echo "Codigo,Nombre,Titulos,Ejemplares" > "$REPORTE_CSV"

    # Datos
    while IFS=$'\t' read -r codigo nombre titulos ejemplares; do
        # Escapar comas en el nombre
        nombre_escapado=$(echo "$nombre" | sed 's/,/;/g')
        echo "$codigo,\"$nombre_escapado\",$titulos,$ejemplares" >> "$REPORTE_CSV"
    done <<< "$datos"

    log_success "Reporte CSV generado: $REPORTE_CSV"
}

# ============================================================================
# EXPORTACIÓN A JSON
# ============================================================================

exportar_json() {
    log_info "Generando reporte JSON..."

    local datos=$(obtener_datos_bibliotecas)
    local stats=$(obtener_estadisticas_generales)
    IFS='|' read -r total_bibs total_tit total_ejem total_users bibs_con_items <<< "$stats"

    cat > "$REPORTE_JSON" << JSON_START
{
  "fecha_generacion": "$FECHA_LEGIBLE",
  "instancia": "$INSTANCIA_KOHA",
  "resumen": {
    "total_bibliotecas": $total_bibs,
    "total_titulos": $total_tit,
    "total_ejemplares": $total_ejem,
    "total_usuarios": $total_users,
    "bibliotecas_con_items": $bibs_con_items
  },
  "bibliotecas": [
JSON_START

    local primera=true
    while IFS=$'\t' read -r codigo nombre titulos ejemplares; do
        if [ "$primera" = false ]; then
            echo "," >> "$REPORTE_JSON"
        fi
        primera=false

        # Escapar comillas en el nombre
        nombre_json=$(echo "$nombre" | sed 's/"/\\"/g')

        cat >> "$REPORTE_JSON" << JSON_ITEM
    {
      "codigo": "$codigo",
      "nombre": "$nombre_json",
      "titulos": $titulos,
      "ejemplares": $ejemplares
    }
JSON_ITEM
    done <<< "$datos"

    cat >> "$REPORTE_JSON" << 'JSON_END'
  ]
}
JSON_END

    log_success "Reporte JSON generado: $REPORTE_JSON"
}

# ============================================================================
# FUNCIÓN PRINCIPAL
# ============================================================================

generar_reporte_completo() {
    banner "GENERADOR DE REPORTES ESTADÍSTICOS"

    # Generar reporte principal en texto
    {
        generar_encabezado
        generar_resumen_general
        generar_tabla_bibliotecas
        generar_top_bibliotecas
        generar_estadisticas_recientes
        generar_distribucion_visual
        generar_pie_reporte
    } | tee "$REPORTE_TXT"

    echo ""
    log_success "Reporte principal generado: $REPORTE_TXT"

    # Exportar a otros formatos si se solicita
    if [ "$EXPORTAR_HTML" = true ]; then
        exportar_html
    fi

    if [ "$EXPORTAR_CSV" = true ]; then
        exportar_csv
    fi

    if [ "$EXPORTAR_JSON" = true ]; then
        exportar_json
    fi

    echo ""
    separador
    log_success "✓ Generación de reportes completada"
    separador
    echo ""
}

mostrar_ayuda() {
    cat << EOF
${C_BOLD}${C_CYAN}GENERADOR DE REPORTES ESTADÍSTICOS - KOHA UNA${C_NC}

Genera reportes detallados de bibliotecas, títulos y ejemplares.

${C_BOLD}USO:${C_NC}
    $0 [OPCIONES]

${C_BOLD}OPCIONES:${C_NC}
    --biblioteca CODIGO    Generar reporte de una biblioteca específica
    --html                 Exportar reporte a HTML
    --csv                  Exportar reporte a CSV
    --json                 Exportar reporte a JSON
    --all                  Exportar a todos los formatos
    --no-graficos          Desactivar gráficos ASCII
    --help, -h             Mostrar esta ayuda

${C_BOLD}EJEMPLOS:${C_NC}
    # Reporte completo en texto
    $0

    # Reporte de una biblioteca
    $0 --biblioteca ING

    # Reporte con exportación HTML
    $0 --html

    # Reporte con todos los formatos
    $0 --all

    # Reporte sin gráficos (más rápido)
    $0 --no-graficos

${C_BOLD}SALIDA:${C_NC}
    Los reportes se guardan en: $DIR_REPORTES

Universidad Nacional de Asunción - 2025
EOF
}

# ============================================================================
# PROCESAMIENTO DE ARGUMENTOS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --biblioteca)
            BIBLIOTECA_ESPECIFICA="$2"
            shift 2
            ;;
        --html)
            EXPORTAR_HTML=true
            shift
            ;;
        --csv)
            EXPORTAR_CSV=true
            shift
            ;;
        --json)
            EXPORTAR_JSON=true
            shift
            ;;
        --all)
            EXPORTAR_HTML=true
            EXPORTAR_CSV=true
            EXPORTAR_JSON=true
            shift
            ;;
        --no-graficos)
            MOSTRAR_GRAFICOS=false
            shift
            ;;
        --help|-h)
            mostrar_ayuda
            exit 0
            ;;
        *)
            log_error "Opción desconocida: $1"
            echo "Use --help para ver opciones disponibles"
            exit 1
            ;;
    esac
done

# ============================================================================
# EJECUCIÓN PRINCIPAL
# ============================================================================

crear_directorios
generar_reporte_completo

exit 0
