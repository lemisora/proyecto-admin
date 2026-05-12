#!/usr/bin/env bash
# =============================================================================
# install_nagios.sh — Nagios Core 4.5.12 en AlmaLinux 10
# Basado en: "Install Nagios Core on Rocky Linux 10 / AlmaLinux 10"
# Requiere: AlmaLinux 10, acceso root o sudo, SELinux enforcing
# =============================================================================

set -euo pipefail

# ─── Colores ─────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()    { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

# ─── Configuración ────────────────────────────────────────────────────────────
NAGIOS_VER="4.5.12"
NAGIOS_URL="https://github.com/NagiosEnterprises/nagioscore/releases/download/nagios-${NAGIOS_VER}/nagios-${NAGIOS_VER}.tar.gz"
NAGIOS_USER="nagios"
NAGIOS_GROUP="nagios"
NAGCMD_GROUP="nagcmd"
NAGIOS_ADMIN="nagiosadmin"
INSTALL_DIR="/usr/local/nagios"
WORK_DIR="/tmp/nagios_build"

# ─── Verificaciones previas ───────────────────────────────────────────────────
check_root() {
    [[ $EUID -eq 0 ]] || error "Este script debe ejecutarse como root (o con sudo)."
}

check_os() {
    if ! grep -qi "almalinux" /etc/redhat-release 2>/dev/null; then
        warn "Este script está diseñado para AlmaLinux 10. Continuar bajo tu responsabilidad."
        read -rp "¿Continuar de todas formas? [s/N]: " ans
        [[ "${ans,,}" == "s" ]] || exit 1
    fi
    info "SO detectado: $(cat /etc/redhat-release)"
}

check_selinux() {
    local status
    status=$(getenforce 2>/dev/null || echo "Disabled")
    info "SELinux: ${status}"
    [[ "${status}" == "Enforcing" ]] || warn "SELinux no está en modo Enforcing. Se recomienda mantenerlo activo."
}

# ─── Dependencias de compilación ──────────────────────────────────────────────
install_dependencies() {
    info "Instalando dependencias de compilación..."
    dnf install -y \
        gcc glibc glibc-common make gettext automake autoconf wget \
        openssl-devel net-snmp net-snmp-utils perl-Net-SNMP unzip \
        httpd php php-cli php-gd gd gd-devel perl perl-devel
    info "Dependencias instaladas correctamente."
}

# ─── Usuario y grupo ──────────────────────────────────────────────────────────
create_user_and_group() {
    info "Creando usuario '${NAGIOS_USER}' y grupo '${NAGCMD_GROUP}'..."

    if ! id "${NAGIOS_USER}" &>/dev/null; then
        useradd -m "${NAGIOS_USER}"
        info "Usuario '${NAGIOS_USER}' creado."
    else
        warn "Usuario '${NAGIOS_USER}' ya existe, se omite."
    fi

    if ! getent group "${NAGCMD_GROUP}" &>/dev/null; then
        groupadd "${NAGCMD_GROUP}"
        info "Grupo '${NAGCMD_GROUP}' creado."
    else
        warn "Grupo '${NAGCMD_GROUP}' ya existe, se omite."
    fi

    usermod -aG "${NAGCMD_GROUP}" "${NAGIOS_USER}"
    usermod -aG "${NAGCMD_GROUP}" apache
    info "Usuarios añadidos al grupo '${NAGCMD_GROUP}'."
}

# ─── Descarga y compilación de Nagios Core ───────────────────────────────────
download_and_compile_nagios() {
    info "Preparando directorio de trabajo: ${WORK_DIR}"
    mkdir -p "${WORK_DIR}"
    cd "${WORK_DIR}"

    info "Descargando Nagios Core ${NAGIOS_VER}..."
    wget -q --show-progress -O "nagios-${NAGIOS_VER}.tar.gz" "${NAGIOS_URL}" \
        || error "No se pudo descargar Nagios desde ${NAGIOS_URL}"

    info "Extrayendo fuentes..."
    tar -xzf "nagios-${NAGIOS_VER}.tar.gz"
    cd "nagios-${NAGIOS_VER}"

    info "Configurando el build (--with-command-group=${NAGCMD_GROUP})..."
    ./configure --with-command-group="${NAGCMD_GROUP}" \
        || error "Falló ./configure — revisa las dependencias faltantes."

    info "Compilando Nagios Core (esto puede tardar unos minutos)..."
    make all

    info "Instalando binarios y archivos de configuración..."
    make install
    make install-init
    make install-commandmode
    make install-config
    make install-webconf

    info "Nagios Core ${NAGIOS_VER} instalado en ${INSTALL_DIR}."
}

# ─── Autenticación web ────────────────────────────────────────────────────────
setup_web_auth() {
    info "Configurando autenticación HTTP para el usuario '${NAGIOS_ADMIN}'..."
    echo ""
    echo -e "${YELLOW}Introduce una contraseña segura para el usuario '${NAGIOS_ADMIN}' de la interfaz web:${NC}"
    htpasswd -c "${INSTALL_DIR}/etc/htpasswd.users" "${NAGIOS_ADMIN}" \
        || error "No se pudo crear el archivo htpasswd."
    info "Credenciales web creadas correctamente."
}

# ─── Plugins de Nagios ────────────────────────────────────────────────────────
install_plugins() {
    info "Obteniendo la última versión de Nagios Plugins desde GitHub..."
    local PLUG_VER
    PLUG_VER=$(curl -sL "https://api.github.com/repos/nagios-plugins/nagios-plugins/releases/latest" \
        | grep '"tag_name"' | sed -E 's/.*"release-([^"]+)".*/\1/')

    if [[ -z "${PLUG_VER}" ]]; then
        warn "No se pudo determinar la versión de los plugins automáticamente. Usando 2.4.12 como fallback."
        PLUG_VER="2.4.12"
    fi
    info "Versión de plugins: ${PLUG_VER}"

    cd "${WORK_DIR}"
    wget -q --show-progress -O "nagios-plugins-${PLUG_VER}.tar.gz" \
        "https://nagios-plugins.org/download/nagios-plugins-${PLUG_VER}.tar.gz" \
        || error "No se pudo descargar los plugins de Nagios."

    tar -xzf "nagios-plugins-${PLUG_VER}.tar.gz"
    cd "nagios-plugins-${PLUG_VER}"

    info "Compilando e instalando plugins..."
    ./configure --with-nagios-user="${NAGIOS_USER}" --with-nagios-group="${NAGIOS_GROUP}"
    make
    make install

    info "Plugins instalados en ${INSTALL_DIR}/libexec/"
    info "Verificando plugins instalados:"
    ls "${INSTALL_DIR}/libexec/" | head -20
}

# ─── Firewall ─────────────────────────────────────────────────────────────────
configure_firewall() {
    info "Abriendo el puerto HTTP en firewalld..."
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-service=http
        firewall-cmd --reload
        info "Servicios activos en el firewall:"
        firewall-cmd --list-services
    else
        warn "firewalld no está activo. Omitiendo configuración del firewall."
    fi
}

# ─── Verificación de configuración ───────────────────────────────────────────
verify_config() {
    info "Verificando la configuración de Nagios..."
    "${INSTALL_DIR}/bin/nagios" -v "${INSTALL_DIR}/etc/nagios.cfg" \
        || error "La configuración de Nagios contiene errores. Revisa la salida anterior."
    info "Configuración verificada sin errores."
}

# ─── Inicio de servicios ──────────────────────────────────────────────────────
start_services() {
    info "Habilitando e iniciando Apache (httpd)..."
    systemctl enable --now httpd

    info "Habilitando e iniciando Nagios..."
    systemctl enable --now nagios

    info "Estado de Nagios:"
    systemctl status nagios --no-pager
}

# ─── SELinux: verificación post-instalación ──────────────────────────────────
check_selinux_denials() {
    info "Verificando denials de SELinux recientes..."
    local denials
    denials=$(ausearch -m avc -ts recent 2>/dev/null || echo "<no matches>")
    if echo "${denials}" | grep -q "nagios"; then
        warn "Se detectaron posibles denials de SELinux relacionados con Nagios:"
        echo "${denials}"
        warn "Usa 'ausearch -m avc -ts recent', 'semanage fcontext' y 'restorecon' para corregirlos."
        warn "NUNCA deshabilites SELinux como solución."
    else
        info "Sin denials de SELinux relacionados con Nagios. Todo en orden."
    fi
}

# ─── Resumen final ────────────────────────────────────────────────────────────
print_summary() {
    local SERVER_IP
    SERVER_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  Nagios Core ${NAGIOS_VER} instalado exitosamente en AlmaLinux 10${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Interfaz web:  ${YELLOW}http://${SERVER_IP}/nagios${NC}"
    echo -e "  Usuario:       ${YELLOW}${NAGIOS_ADMIN}${NC}"
    echo -e "  Contraseña:    la que ingresaste durante la instalación"
    echo ""
    echo -e "  Archivos de configuración: ${INSTALL_DIR}/etc/"
    echo -e "  Plugins:                   ${INSTALL_DIR}/libexec/"
    echo -e "  Logs:                      ${INSTALL_DIR}/var/"
    echo ""
    echo -e "${YELLOW}Próximos pasos recomendados:${NC}"
    echo "  1. Habilitar HTTPS (reverse proxy + Let's Encrypt o mod_ssl)"
    echo "  2. Configurar notificaciones en ${INSTALL_DIR}/etc/objects/contacts.cfg"
    echo "  3. Ajustar retención de datos en ${INSTALL_DIR}/etc/nagios.cfg"
    echo "  4. Hacer backup periódico de ${INSTALL_DIR}/etc/"
    echo "  5. Instalar NRPE en servidores remotos para monitorearlos"
    echo ""
}

# ─── Limpieza ─────────────────────────────────────────────────────────────────
cleanup() {
    info "Limpiando archivos temporales en ${WORK_DIR}..."
    rm -rf "${WORK_DIR}"
}

# ─── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   Instalador de Nagios Core ${NAGIOS_VER} — AlmaLinux 10    ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""

    check_root
    check_os
    check_selinux
    install_dependencies
    create_user_and_group
    download_and_compile_nagios
    setup_web_auth
    install_plugins
    configure_firewall
    verify_config
    start_services
    check_selinux_denials
    cleanup
    print_summary
}

main "$@"

