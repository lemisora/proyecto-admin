#!/usr/bin/env bash
print_menu(){
	echo "Elige una de las siguientes opciones: "
	echo "E"
}


if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Acceso denegado."
    echo "Este script debe ejecutarse con privilegios de root."
    exit 1
fi

while true; do
    echo -e "\n=========================================="
    echo "      MENÚ DE ADMINISTRACIÓN DE SISTEMA"
    echo "=========================================="
    echo "1) Gestión de Usuarios"
    echo "2) Gestión de Grupos"
    echo "3) Mostrar procesos de un usuario"
    echo "4) Salir"
    read -p "Seleccione una opción: " opcion_principal

    case $opcion_principal in
        1)
            echo -e "\n--- SUBMENÚ: USUARIOS ---"
            echo "a) Alta de usuarios"
            echo "b) Baja de usuarios"
            echo "c) Consulta de usuarios (ver si existe)"
            echo "d) Modificaciones (caducidad, carpetas, estado)"
            read -p "Selección: " sub_u
            
            case $sub_u in
                a) 
                    read -p "Nombre del nuevo usuario: " nom
                    useradd "$nom" && echo "Usuario $nom creado exitosamente."
                    ;;
                b) 
                    read -p "Usuario a eliminar: " nom
                    userdel -r "$nom" && echo "Usuario $nom eliminado (incluyendo home)."
                    ;;
                c) 
                    read -p "Usuario a consultar: " nom
                    id "$nom" &>/dev/null && echo "El usuario $nom EXISTE." || echo "El usuario $nom NO existe."
                    ;;
                d) 
                    read -p "Usuario a modificar: " nom
                    echo "1. Cambiar fecha de caducidad (AAAA-MM-DD)"
                    echo "2. Bloquear cuenta"
                    echo "3. Desbloquear cuenta"
                    read -p "Opción: " mod_u
                    case $mod_u in
                        1) read -p "Fecha: " fec; usermod -e "$fec" "$nom" ;;
                        2) usermod -L "$nom" && echo "Cuenta bloqueada." ;;
                        3) usermod -U "$nom" && echo "Cuenta desbloqueada." ;;
                    esac
                    ;;
            esac
            ;;
            
        2)
            echo -e "\n--- SUBMENÚ: GRUPOS ---"
            echo "a) Alta de grupos"
            echo "b) Baja de grupos"
            echo "c) Consulta de grupos"
            echo "d) Modificaciones de grupo"
            read -p "Selección: " sub_g
            
            case $sub_g in
                a) read -p "Nombre del grupo: " grp; groupadd "$grp" ;;
                b) read -p "Grupo a eliminar: " grp; groupdel "$grp" ;;
                c) read -p "Grupo a consultar: " grp; getent group "$grp" ;;
                d) read -p "Grupo a renombrar: " grp; read -p "Nuevo nombre: " ngr; groupmod -n "$ngr" "$grp" ;;
            esac
            ;;
            
        3)
            read -p "Ingrese el nombre del usuario para ver sus procesos: " user_proc
            echo "Procesos actuales para $user_proc:"
            ps -u "$user_proc" || echo "No se encontraron procesos o el usuario no existe."
            ;;
            
        4)
            echo "Saliendo del programa..."
            break
            ;;
            
        *)
            echo "Opción no válida."
            ;;
    esac
done
