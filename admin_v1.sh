#!/bin/bash
# Gestión de usuarios, grupos y procesos con verificación de root
# Compatible con Alma Linux

# 1. VERIFICACIÓN DE PRIVILEGIOS ROOT
if [ "$(id -u)" -ne 0 ]; then
    echo "Acceso denegado. Este script requiere privilegios de root."
    exit 1
fi

# Función auxiliar para pausa interactiva
pausar() {
    read -p "++ Presione [Enter] para continuar..."
}

# ============ MENÚ DE USUARIOS ============
menu_usuarios() {
    while true; do
        clear
        echo "===============================++"
        echo "    GESTIÓN DE USUARIOS"
        echo "===============================++"
        echo "a) Alta de usuario"
        echo "b) Baja de usuario"
        echo "c) Consulta de usuario"
        echo "d) Modificación de usuario"
        echo "e) Agregar usuario a grupo"
        echo "f) Volver al menú principal"
        echo "===============================++"
        read -rp "Seleccione una opción: " op

        case "$op" in
            a|A)
                read -rp "Ingrese nombre del nuevo usuario: " user
                if id "$user" &>/dev/null; then
                    echo "El usuario '$user' ya existe."
                else
                    useradd -m "$user" && echo "// Usuario '$user' creado correctamente." || echo "** Error al crear usuario."
                fi
                pausar
                ;;
            b|B)
                read -rp "Ingrese nombre del usuario a eliminar: " user
                if id "$user" &>/dev/null; then
                    read -rp "¿Eliminar también el directorio home? [s/N]: " conf
                    if [[ "$conf" =~ ^[sS]$ ]]; then
                        userdel -r "$user" && echo "// Usuario '$user' y su home eliminados." || echo "** Error al eliminar usuario."
                    else
                        userdel "$user" && echo "// Usuario '$user' eliminado (home conservado)." || echo "** Error al eliminar usuario."
                    fi
                else
                    echo "El usuario '$user' no existe."
                fi
                pausar
                ;;
            c|C)
                read -rp "Ingrese nombre del usuario a consultar: " user
                if id "$user" &>/dev/null; then
                    echo "// El usuario '$user' existe. Detalles:"
                    id "$user"
                else
                    echo "** El usuario '$user' NO existe en el sistema."
                fi
                pausar
                ;;
            d|D)
                read -rp "Ingrese usuario a modificar: " user
                if ! id "$user" &>/dev/null; then
                    echo "El usuario '$user' no existe."
                    pausar
                    continue
                fi
                clear
                echo "===============================++"
                echo "  MODIFICAR USUARIO: $user"
                echo "===============================++"
                echo "1) Fecha de caducidad de cuenta"
                echo "2) Cambiar directorio home"
                echo "3) Bloquear/Desbloquear cuenta"
                echo "4) Cambiar descripción/comentario (GECOS)"
                read -rp "Seleccione opción: " mod

                case "$mod" in
                    1)
                        read -rp "Nueva fecha de caducidad (AAAA-MM-DD): " fecha
                        usermod -e "$fecha" "$user" && echo "// Fecha de caducidad actualizada." || echo "** Formato inválido o error."
                        ;;
                    2)
                        read -rp "Nuevo directorio home (ruta absoluta): " dir
                        usermod -d "$dir" -m "$user" && echo "// Home actualizado y contenido migrado." || echo "** Error al cambiar home."
                        ;;
                    3)
                        read -rp "Bloquear (b) o Desbloquear (d) cuenta: " acc
                        case "$acc" in
                            b|B) usermod -L "$user" && echo "-- Cuenta bloqueada." ;;
                            d|D) usermod -U "$user" && echo "++ Cuenta desbloqueada." ;;
                            *) echo "Opción no válida." ;;
                        esac
                        ;;
                    4)
                        read -rp "Nueva descripción: " desc
                        usermod -c "$desc" "$user" && echo "// Descripción actualizada." || echo "** Error."
                        ;;
                    *) echo "Opción no válida." ;;
                esac
                pausar
                ;;
            e|E)
                read -rp "Ingrese nombre del usuario: " user
                if ! id "$user" &>/dev/null; then
                    echo "El usuario '$user' no existe."
                    pausar
                    continue
                fi
                read -rp "Ingrese nombre del grupo: " grp
                if ! getent group "$grp" &>/dev/null; then
                    echo "El grupo '$grp' no existe."
                    pausar
                    continue
                fi
                usermod -a -G "$grp" "$user" && echo "// Usuario '$user' agregado al grupo '$grp'." || echo "** Error al agregar usuario."
                pausar
                ;;
            f|F) return ;;
            *) echo "Opción no válida."
        pausar;;
        esac
    done
}

# ============ MENÚ DE GRUPOS ============
menu_grupos() {
    while true; do
        clear
        echo "===============================++"
        echo "    GESTIÓN DE GRUPOS"
        echo "===============================++"
        echo "a) Alta de grupo"
        echo "b) Baja de grupo"
        echo "c) Consulta de grupo"
        echo "d) Modificación de grupo"
        echo "e) Volver al menú principal"
        echo "===============================++"
        read -rp "Seleccione una opción: " op

        case "$op" in
            a|A)
                read -rp "Nombre del nuevo grupo: " grp
                if getent group "$grp" &>/dev/null; then
                    echo "El grupo '$grp' ya existe."
                else
                    groupadd "$grp" && echo "// Grupo '$grp' creado." || echo "** Error al crear grupo."
                fi
                pausar
                ;;
            b|B)
                read -rp "Nombre del grupo a eliminar: " grp
                if getent group "$grp" &>/dev/null; then
                    groupdel "$grp" && echo "// Grupo '$grp' eliminado." || echo "** Error (¿el grupo es primario de algún usuario?)."
                else
                    echo "El grupo '$grp' no existe."
                fi
                pausar
                ;;
            c|C)
                read -rp "Nombre del grupo a consultar: " grp
                if getent group "$grp" &>/dev/null; then
                    echo "// El grupo '$grp' existe. Información:"
                    getent group "$grp"
                else
                    echo "** El grupo '$grp' NO existe."
                fi
                pausar
                ;;
            d|D)
                read -rp "Grupo a modificar: " grp
                if ! getent group "$grp" &>/dev/null; then
                    echo "El grupo '$grp' no existe."
                    pausar
                    continue
                fi
                clear
                echo "===============================++"
                echo "  MODIFICAR GRUPO: $grp"
                echo "===============================++"
                echo "1) Cambiar nombre del grupo"
                echo "2) Cambiar GID"
                read -rp "Seleccione opción: " mod

                case "$mod" in
                    1)
                        read -rp "Nuevo nombre del grupo: " newgrp
                        groupmod -n "$newgrp" "$grp" && echo "// Grupo renombrado a '$newgrp'." || echo "** Error."
                        ;;
                    2)
                        read -rp "Nuevo GID (numérico): " gid
                        groupmod -g "$gid" "$grp" && echo "// GID actualizado." || echo "** GID en uso o inválido."
                        ;;
                    *) echo "Opción no válida." ;;
                esac
                pausar
                ;;
            e|E) return ;;
            *) echo "Opción no válida."
        pausar;;
        esac
    done
}

# ============ MENÚ DE PROCESOS ============
menu_procesos() {
    while true; do
        clear
        echo "===============================++"
        echo "    GESTIÓN DE PROCESOS"
        echo "===============================++"
        echo "a) Procesos por usuario"
        echo "b) Procesos del sistema (todas)"
        echo "c) Top (procesos con mayor consumo)"
        echo "d) Información del PC (uname)"
        echo "e) Volver al menú principal"
        echo "===============================++"
        read -rp "Seleccione una opción: " op

        case "$op" in
            a|A)
                read -rp "Ingrese nombre del usuario: " user
                if ! id "$user" &>/dev/null; then
                    echo "El usuario '$user' no existe."
                    pausar
                    continue
                fi
                clear
                echo "================================================================"
                echo "PROCESOS DEL USUARIO: $user"
                echo "================================================================"
                ps -u "$user" -o pid,ppid,stat,%cpu,%mem,etime,args --sort=-%cpu
                echo "================================================================"
                pausar
                ;;
            b|B)
                clear
                echo "================================================================"
                echo "PROCESOS DEL SISTEMA (TODOS)"
                echo "================================================================"
                ps aux --sort=-%cpu | head -30
                echo "================================================================"
                echo "Mostrando los 30 primeros procesos (ordenados por CPU)"
                pausar
                ;;
            c|C)
                clear
                echo "================================================================"
                echo "TOP - PROCESOS CON MAYOR CONSUMO DE RECURSOS"
                echo "================================================================"
                echo ""
                top -bn1 | head -20
                echo ""
                echo "================================================================"
                pausar
                ;;
            d|D)
                clear
                echo "================================================================"
                echo "INFORMACIÓN DEL SISTEMA (PC)"
                echo "================================================================"
                echo ""
                echo "Información general del sistema:"
                uname -a
                echo ""
                echo "Kernel:"
                uname -r
                echo ""
                echo "Arquitectura:"
                uname -m
                echo ""
                echo "Nombre del host:"
                uname -n
                echo ""
                echo "================================================================"
                pausar
                ;;
            e|E) return ;;
            *) echo "Opción no válida."
        pausar;;
        esac
    done
}

# ============ MENÚ DE INFORMACIÓN ============
menu_informacion() {
    while true; do
        clear
        echo "===============================++"
        echo "  INFORMACIÓN DE USUARIOS/GRUPOS"
        echo "===============================++"
        echo "a) Listar todos los usuarios"
        echo "b) Listar todos los grupos"
        echo "c) Volver al menú principal"
        echo "===============================++"
        read -rp "Seleccione una opción: " op

        case "$op" in
            a|A)
                clear
                echo "================================================================"
                echo "LISTA DE USUARIOS LOCALES (CREADOS EN EL EQUIPO)"
                echo "================================================================"
                echo ""
                echo "UID:GID | Usuario | Home | Shell"
                echo "────────────────────────────────────────────────────────────────"
                # Muestra usuarios normales (UID >= 1000); evita cuentas del sistema.
                awk -F: '$3 >= 1000 && $1 != "nobody" {print $3 ":" $4 ":" $1 ":" $6 ":" $7}' /etc/passwd | column -t -s:
                echo "────────────────────────────────────────────────────────────────"
                echo "Mostrando usuarios locales creados (UID >= 1000)"
                pausar
                ;;
            b|B)
                clear
                echo "================================================================"
                echo "LISTA DE GRUPOS LOCALES (CREADOS EN EL EQUIPO)"
                echo "================================================================"
                echo ""
                echo "GID | Nombre | Miembros"
                echo "────────────────────────────────────────────────────────────────"
                # Muestra grupos normales (GID >= 1000); evita grupos del sistema.
                awk -F: '$3 >= 1000 {print $3 ":" $1 ":" $4}' /etc/group | column -t -s:
                echo "────────────────────────────────────────────────────────────────"
                echo "Mostrando grupos locales creados (GID >= 1000)"
                pausar
                ;;
            c|C) return ;;
            *) echo "Opción no válida."
        pausar;;
        esac
    done
}

# ============ MENÚ DE AUTOMATIZACIÓN ============
menu_automatizacion() {
    while true; do
        clear
        echo "===============================++"
        echo "   AUTOMATIZACIÓN DE TAREAS"
        echo "===============================++"
        echo "1. Cron"
        echo "2. At"
        echo "3. Volver al menú principal"
        echo "===============================++"
        read -rp "Seleccione una opción [1-3]: " op

        case "$op" in
            1)
                read -rp "Ingrese el comando/tarea a programar (ej. /usr/bin/uptime): " tarea
                read -rp "Ingrese fecha y hora (YYYY-MM-DD HH:MM): " datetime

                # Convierte fecha/hora a campos de cron: MIN HOUR DAY MONTH
                horario=$(date -d "$datetime" '+%M %H %d %m' 2>/dev/null)
                if [ $? -ne 0 ] || [ -z "$horario" ]; then
                    echo "** Formato de fecha/hora inválido."
                    pausar
                    continue
                fi

                # Nota: cron ejecuta con /bin/sh. Usar comandos con rutas absolutas reduce problemas.
                cron_line="$horario * $tarea"
                (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
                echo "// Tarea programada en cron para: $datetime"
                echo "// Línea cron: $cron_line"
                pausar
                ;;
                2)
                    if ! command -v at &>/dev/null; then
                        echo "** 'at' no está instalado. Intentando instalar..."
                        dnf -y install at >/dev/null 2>&1 || {
                            echo "** Falló la instalación de 'at'. Verifica repos y conectividad."
                            pausar
                            continue
                        }
                    fi
                
                    systemctl enable --now atd >/dev/null 2>&1 || true
                
                    read -rp "Ingrese el comando/tarea a ejecutar (ej. /usr/bin/uptime): " tarea
                    read -rp "Ingrese fecha y hora (YYYY-MM-DD HH:MM): " datetime
                
                    # Convertir al formato que at entiende: HH:MM MM/DD/YYYY
                    at_time=$(date -d "$datetime" '+%H:%M %m/%d/%Y' 2>/dev/null)
                    if [ -z "$at_time" ]; then
                        echo "** Formato de fecha/hora inválido. Usa YYYY-MM-DD HH:MM"
                        pausar
                        continue
                    fi
                
                    output=$(echo "$tarea" | at "$at_time" 2>&1)
                    if [ $? -ne 0 ]; then
                        echo "** Error al programar con at: $output"
                    else
                        echo "// Tarea programada para: $datetime"
                        echo "// Confirmación: $output"
                    fi
                    pausar
                    ;;
            3) return ;;
            *) echo "Opción no válida."
               pausar
               ;;
        esac
    done
}

# ============ MENÚ DE RESPALDOS ============
menu_respaldo() {
    while true; do
        clear
        echo "===============================++"
        echo "     RESPALDO DE LA INFORMACIÓN"
        echo "===============================++"
        echo "1. Tar - gzip"
        echo "2. Tar - bzip2"
        echo "3. Volver al menú principal"
        echo "===============================++"
        read -rp "Seleccione una opción [1-3]: " op

        case "$op" in
            1)
                read -rp "Ingrese la carpeta a respaldar (ruta): " src
                if [ ! -d "$src" ]; then
                    echo "** La carpeta no existe."
                    pausar
                    continue
                fi
                read -rp "Ingrese la ruta destino donde se guardará el respaldo: " dest
                mkdir -p "$dest" >/dev/null 2>&1 || {
                    echo "** No se pudo crear/acceder al destino."
                    pausar
                    continue
                }

                base=$(basename "$src")
                parent=$(dirname "$src")
                out="$dest/backup_${base}_$(date +%Y%m%d_%H%M%S).tar.gz"
                tar -czf "$out" -C "$parent" "$base" || {
                    echo "** Error creando el respaldo."
                    pausar
                    continue
                }
                echo "// Respaldo creado: $out"
                pausar
                ;;
            2)
                read -rp "Ingrese la carpeta a respaldar (ruta): " src
                if [ ! -d "$src" ]; then
                    echo "** La carpeta no existe."
                    pausar
                    continue
                fi
                read -rp "Ingrese la ruta destino donde se guardará el respaldo: " dest
                mkdir -p "$dest" >/dev/null 2>&1 || {
                    echo "** No se pudo crear/acceder al destino."
                    pausar
                    continue
                }

                base=$(basename "$src")
                parent=$(dirname "$src")
                out="$dest/backup_${base}_$(date +%Y%m%d_%H%M%S).tar.bz2"
                tar -cjf "$out" -C "$parent" "$base" || {
                    echo "** Error creando el respaldo."
                    pausar
                    continue
                }
                echo "// Respaldo creado: $out"
                pausar
                ;;
            3) return ;;
            *) echo "Opción no válida."
               pausar
               ;;
        esac
    done
}

# ============ MENÚ DE SEGURIDAD ============
menu_seguridad() {
    while true; do
        clear
        echo "===============================++"
        echo "          SEGURIDAD"
        echo "===============================++"
        echo "1. MONITOREO"
        echo "2. Volver al menú principal"
        echo "===============================++"
        read -rp "Seleccione una opción [1-2]: " op

        case "$op" in
            1) menu_monitoreo ;;
            2) return ;;
            *) echo "Opción no válida."
               pausar
               ;;
        esac
    done
}

menu_monitoreo() {
    while true; do
        clear
        echo "===============================++"
        echo "          MONITOREO"
        echo "===============================++"
        echo "a) Nagios"
        echo "b) Wireshark"
        echo "c) Nmap o iftop"
        echo "d) Volver"
        echo "===============================++"
        read -rp "Seleccione una opción: " op

        case "$op" in
            a|A) monitoreo_nagios ;;
            b|B) monitoreo_wireshark ;;
            c|C) monitoreo_nmap_iftop ;;
            d|D) return ;;
            *) echo "Opción no válida."
               pausar
               ;;
        esac
    done
}

monitoreo_nagios() {
    # Intenta arrancar Nagios y mostrar la UI en el navegador (si existe entorno gráfico).
    if ! systemctl list-unit-files | grep -q 'nagios.service'; then
        echo "** Nagios no detectado como servicio."
        read -rp "¿Deseas intentar instalarlo automáticamente? [s/N]: " resp
        if [[ "$resp" =~ ^[sS]$ ]]; then
            dnf -y install nagios nagios-plugins-all >/dev/null 2>&1 || {
                echo "** Falló la instalación de Nagios. Revisa repositorio."
                pausar
                return
            }
        else
            pausar
            return
        fi
    fi

    systemctl enable --now nagios >/dev/null 2>&1 || true
    systemctl restart nagios >/dev/null 2>&1 || true

    url="http://localhost/nagios"
    echo "// Inicia el monitoreo en la URL: $url"
    if command -v xdg-open &>/dev/null; then
	if [ -n "$SUDO_USER" ]; then
	    local uid
	    uid=$(id -u "$SUDO_USER")
	    sudo -u "$SUDO_USER" \
		    DISPLAY=:0 \
		    DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/${uid}/bus" \
		    xdg-open "$url" > /dev/null 2>&1 || true
	else 
	    echo "** No se detectó SUDO_USER; abre manualmente la dirección con Ctrl + Click en el enlace: $url"
	fi
    fi

    echo "// Mostrando logs en tiempo real (Ctrl+C para regresar)..."
    journalctl -u nagios -f --no-pager
}

monitoreo_wireshark() {
    if ! command -v wireshark &>/dev/null; then
        echo "** 'wireshark' (GUI) no está instalado."
        echo "  Intentaré instalar 'wireshark'. Si no hay entorno gráfico, usaré 'tshark'."
        dnf -y install wireshark >/dev/null 2>&1 || true
    fi

    if ! command -v ip &>/dev/null; then
        echo "** No se encontró el comando 'ip'."
        pausar
        return
    fi

    echo "Interfaces disponibles:"
    ip -o link show | awk -F': ' '{print $2}' | awk -F'@' '{print $1}' | sed '/^lo$/d' || true
    read -rp "Ingrese la interfaz a capturar (ej. eth0): " iface

    # Si la GUI no funciona, fallback a tshark.
    if command -v wireshark &>/dev/null; then
        echo "// Abriendo Wireshark (Ctrl+C para regresar si lo ejecuta en terminal)."
        wireshark -i "$iface"
    elif command -v tshark &>/dev/null; then
        echo "// Wireshark GUI no disponible; iniciando captura con tshark (Ctrl+C para regresar)."
        tshark -i "$iface" -n
    else
        echo "** No se encontró 'wireshark' ni 'tshark'."
        pausar
        return
    fi
}

monitoreo_nmap_iftop() {
    clear
    echo "===============================++"
    echo "Nmap o iftop (elige una opción)"
    echo "===============================++"
    echo "1) Nmap "
    echo "2) iftop "
    read -rp "Seleccione [1-2]: " op

    case "$op" in
        1)
            read -rp "Ingrese el objetivo (IP/host o rango, ej. 192.168.1.0/24): " target
            read -rp "Intervalo en segundos (ej. 10): " interval
            interval=${interval:-10}
            if ! [[ "$interval" =~ ^[0-9]+$ ]]; then
                echo "** Intervalo inválido."
                pausar
                return
            fi

            if ! command -v nmap &>/dev/null; then
                echo "** 'nmap' no está instalado. Intentando instalar..."
                dnf -y install nmap >/dev/null 2>&1 || {
                    echo "** Falló la instalación de nmap."
                    pausar
                    return
                }
            fi

            echo "// Iniciando monitoreo (escaneo ICMP/ARP) repetido. Ctrl+C para regresar."
            while true; do
                clear
                echo "Fecha/hora: $(date)"
                nmap -sn "$target"
                echo
                echo "Actualizando en $interval segundos..."
                sleep "$interval"
            done
            ;;
        2)
            if ! command -v iftop &>/dev/null; then
                echo "** 'iftop' no está instalado. Intentando instalar..."
                dnf -y install iftop >/dev/null 2>&1 || {
                    echo "** Falló la instalación de iftop."
                    pausar
                    return
                }
            fi

            echo "Interfaces disponibles:"
            ip -o link show | awk -F': ' '{print $2}' | awk -F'@' '{print $1}' | sed '/^lo$/d' || true
            read -rp "Ingrese la interfaz (ej. eth0): " iface

            echo "// Ejecutando iftop en tiempo real (Ctrl+C para regresar)..."
            iftop -i "$iface"
            ;;
        *) echo "Opción no válida."
           pausar
           ;;
    esac
}

# ============ MENÚ PRINCIPAL ============
while true; do
    clear
    echo " -- GESTIÓN DE USUARIOS --  "
    echo "1. Gestión de Usuarios"
    echo "2. Gestión de Grupos"
    echo "3. Gestión de Procesos"
    echo "4. Listar Usuarios y Grupos"
    echo "5. Automatización de tareas"
    echo "6. Respaldo de la información"
    echo "7. Seguridad/Monitoreo"
    echo "8. Salir"
    echo "======================================="
    read -rp "Seleccione una opción [1-8]: " opcion

    case "$opcion" in
        1) menu_usuarios ;;
        2) menu_grupos ;;
        3) menu_procesos ;;
        4) menu_informacion ;;
        5) menu_automatizacion ;;
        6) menu_respaldo ;;
        7) menu_seguridad ;;
        8) echo "<< Saliendo del script. Hasta luego. >>"; exit 0 ;;
        *) echo "Opción no válida. Intente de nuevo."
    pausar;;
    esac
done
 
