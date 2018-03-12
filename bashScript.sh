#!/bin/bash

#Borrar rclone
#sudo rm /usr/bin/rclone
#sudo rm /usr/local/share/man/man1/rclone.1



#Bloque 1 - Verificación y configurar rclone
ins_7z=$(type 7z 2>/dev/null)
ins_rclone=$(type rclone 2>/dev/null)
flag_7z=false
flag_rclone=false
omitir=false
mantener7z=false
nombreGDRecibido=false
user_input="N"
fecha=$(date '+%Y%m%d')
defaultBackup=BACKUP_${fecha}
NEWLINE=$'\n'
TABULATION=$'\t'
DOUBLETAB=$'\t'$'\t'
TIME_OUT=2000

while getopts 'hoing:' flag; do
	case "${flag}" in
		h)
			clear
			echo "${NEWLINE}${TABULATION}-- Script para hacer copia de datos a Google Drive --${NEWLINE}"
			echo "Uso de flags: ${NEWLINE}"
			echo "-h${DOUBLETAB}Muestra esta ayuda${NEWLINE}"
			echo "-o${DOUBLETAB}Se omite pedir al usuario los nombres de archivos"
			echo "${DOUBLETAB}y carpetas comprimidos y la carpeta en Google Drive${NEWLINE}"
			echo "-i${DOUBLETAB}Todos los pasos (excepto navegación de carpetas) se"
			echo "${DOUBLETAB}hacen automáticamente con los valores por defecto${NEWLINE}"
			echo "-n${DOUBLETAB}Mantiene los archivos comprimidos creados${NEWLINE}"
			echo "-g name${DOUBLETAB}Se guardarán todos los datos elegidos en la"
			echo "${DOUBLETAB}carpeta 'name' en Google Drive${NEWLINE}"
			exit
			;;
		o)
			omitir=true
			;;
		i)
			TIME_OUT=0.1
			;;
		n)
			mantener7z=true
			;;
		g)          
            if [[ ( "$OPTARG" == "-h" ) || ( "$OPTARG" == "-o" ) || ( "$OPTARG" == "-i" ) || ( "$OPTARG" == "-n" ) || ( "$OPTARG" == "-g" ) ]]; then
                echo "Nombre incorrecto para carpeta en Google Drive"
                exit
            fi
			defaultBackup="$OPTARG"
            nombreGDRecibido=true
			;;
        *)            
            exit
            ;;
            
	esac
done

function verificar_7z {
    if [ "$ins_7z" == "" ]; then
        echo "Es necesario el paquete 'p7zip' antes de ejecutar el script."
		exit
    else
        flag_7z=true
    fi
}


function verificar_rclone {
    if [ "$ins_rclone" == "" ]; then
        echo "Es necesario el paquete 'rclone' antes de ejecutar el script."
        echo "Si no existe en los repositorios ejecutar la instrucción:"
        echo "${TABULATION}curl https://rclone.org/install.sh | sudo bash"
		exit
    else
        flag_rclone=true
    fi
}

verificar_7z
verificar_rclone

if [[ ( "$flag_7z" == "false" ) || ( "$flag_rclone" == "false" ) ]]; then
    exit
fi

read -t "$TIME_OUT" -p "¿Omitir configuración de rclone (S/N)? " user_input

if [[ ( "$user_input" != "S" ) && ( "$user_input" != "s" ) && ( "$user_input" != "" ) ]]; then
	clear
	echo "  -- CONFIGURAR RCLONE --  "
	echo "En caso de dudas, consultar https://rclone.org/drive/ o README_config${NEWLINE}"
	rclone config
fi

#Bloque 2 - Seleccionar carpeta de datos
salirWhile=false
carpetaActual=$HOME
numAux=0

cd $HOME

while [ "$salirWhile" == "false" ]; do
	clear
	
	echo "  -- SELECCIONAR CARPETA DE ORIGEN --  "
	echo "Carpeta actual: ${carpetaActual}"
	numArchivos=$(find 2>/dev/null * -maxdepth 0 -type f | wc -l)
	numCarpetas=$(find 2>/dev/null * -maxdepth 0 -type d | wc -l)
	echo "Nº de archivos: ${numArchivos}"
	echo "Nº de carpetas: ${numCarpetas}"
	read -p "¿Navegar a subcarpeta (S) o mantenerse en ésta (N)? " user_input

	if [[ ( "$user_input" == "S" ) || ( "$user_input" == "s" ) || ( "$user_input" == "" ) ]]; then
		if [ "$HOME" != "$carpetaActual" ]; then
			echo "(${numAux}) Volver un nivel atrás${NEWLINE}"
		fi
		
		for i in * ; do
    		if [ -d "$i" ]; then
		    	arrayCarpetas[$numAux]="$i"
				numAux=$((numAux+1))
			fi
		done

		contador=1
		while [ "$contador" -le "$numAux" ]; do
			echo "(${contador}) ${arrayCarpetas[$contador-1]}"
			contador=$((contador+1))
		done		
		numAux=0

		read -p "Introduce número de carpeta: " user_input

		if [[ ( "$user_input" -lt 0 ) || ( "$user_input" -ge "$contador" ) || ( "$user_input" -eq 0 && "$HOME" == "$carpetaActual" ) ]]; then
			read -t "$TIME_OUT" -p "Error: Opción invalida"
		elif [ "$user_input" -eq 0 ]; then
			IFS='/' read -r -a arrayAux <<< "$carpetaActual"
			carpetaActual=""
			contador=1
			limite=$((${#arrayAux[@]}-1))

			while [ "$contador" -lt "$limite" ]; do
				carpetaActual=${carpetaActual}/${arrayAux[$contador]}
				contador=$((contador+1))
			done
			
			cd ..
		else
			numCarpeta="$((user_input-1))"
			carpetaActual=${carpetaActual}/${arrayCarpetas[$numCarpeta]}
			cd "$carpetaActual"
		fi
	else
		salirWhile=true
	fi
done


#Bloque 3 - Seleccionar datos a copiar
if [ "$nombreGDRecibido" == "false" ]; then
    read -t "$TIME_OUT" -p "${NEWLINE}Nombre de la carpeta en Google Drive (por defecto ${defaultBackup}): " nombre_backup
    if [ "$nombre_backup" == "" ]; then
	    nombre_backup="$defaultBackup"
    fi
else
    nombre_backup="$defaultBackup"
fi

tamanyAcumulado=0
tamanyTotalB=0
tamanyDisco=$(df -B1 . | tail -1 | tr -s ' ' | cut -d' ' -f4)

for i in * ; do
    if [ -f "$i" ]; then
		tamanyTotalB=$((tamanyTotal+$(du -sb "$i" | cut -f1)))
	fi
done

contador=0
espacios=""
numDigitos=$((${#tamanyDisco}-${#tamanyTotalB}))
while [ "$contador" -lt "$numDigitos" ]; do
	espacios="$espacios"" "
	contador=$((contador+1))
done

contador=0
espaciosAcum=""
numDigitos=$((${#tamanyDisco}-${#tamanyAcumulado}))
while [ "$contador" -lt "$numDigitos" ]; do
	espaciosAcum="$espaciosAcum"" "
	contador=$((contador+1))
done

clear
echo "  -- SELECCIONAR COPIA DE ARCHIVOS --  "
echo "Tamaño restante en disco:${TABULATION}${tamanyDisco} bytes"
echo "Tamaño total de archivos:${TABULATION}${espacios}${tamanyTotalB} bytes"
echo "Tamaño acumulado para copiar:${TABULATION}${espaciosAcum}${tamanyAcumulado} bytes"
read -t "$TIME_OUT" -p "¿Comprimir todos los archivos (S/N)? " user_input

defaultName=ARCHIVOS_${fecha}
if [[ ( "$user_input" == "S" ) || ( "$user_input" == "s" ) || ( "$user_input" == "" ) ]]; then
	tamanyAcumulado=$((tamanyAcumulado+tamanyTotalB))
	read -t "$TIME_OUT" -p "Nombre del archivo comprimido (por defecto ${defaultName}.7z): " nombre_archivo	
	
	if [ "$nombre_archivo" == "" ]; then
		nombre_archivo="$defaultName"
	fi		
fi

echo "${NEWLINE}  -- SELECCIONAR COPIA DE DIRECTORIOS --  "
numAux=0
for i in * ; do
    if [ -d "$i" ]; then
		tamanyCarpeta=$(du -sb "$i" | cut -f1)
		
		contador=0
		espacios=""
		numDigitos=$((${#tamanyDisco}-${#tamanyCarpeta}))
		while [ "$contador" -lt "$numDigitos" ]; do
			espacios="$espacios"" "
			contador=$((contador+1))
		done

		contador=0
		espaciosAcum=""
		numDigitos=$((${#tamanyDisco}-${#tamanyAcumulado}))
		while [ "$contador" -lt "$numDigitos" ]; do
			espaciosAcum="$espaciosAcum"" "
			contador=$((contador+1))
		done

		echo "Tamaño restante en disco:${TABULATION}${tamanyDisco} bytes"
		echo "Tamaño total de carpeta:${TABULATION}${espacios}${tamanyCarpeta} bytes"
		echo "Tamaño acumulado a copiar:${TABULATION}${espaciosAcum}${tamanyAcumulado} bytes"
    	read -t "$TIME_OUT" -p "¿Comprimir ${i} (S/N)? " user_input

		if [[ ( "$user_input" == "S" ) || ( "$user_input" == "s" ) || ( "$user_input" == "" ) ]]; then
			defaultName=${i}_${fecha}			
			read -t "$TIME_OUT" -p "Nombre del archivo comprimido (por defecto ${defaultName}.7z): " nombre_carpeta
	
			if [ "$nombre_carpeta" == "" ]; then
				nombre_carpeta="$defaultName"
			fi	

			copiaCarpetas[$numAux]="$i"
			nombreComprimido[$numAux]="$nombre_carpeta"
			numAux=$((numAux+1))
			tamanyAcumulado=$((tamanyAcumulado+tamanyCarpeta))
		fi
		echo "$NEWLINE"
fi
done


#Bloque 4 - Copiar datos en Google Drive
clear
if [ "$numArchivos" -gt 0 ]; then
	echo "Subiendo archivos..."
	find * -maxdepth 0 -type f -exec 7z a "$nombre_archivo" {} +
	rclone copy "$nombre_archivo".7z remote:"$nombre_backup" -v
	if [ "$mantener7z" == "false" ]; then
		rm -f "$nombre_archivo".7z
	fi
fi

contador=0
totalCarpetas=${#copiaCarpetas[@]}
while [ "$contador" -lt "$totalCarpetas" ]; do
	nCarpetaOrg=${copiaCarpetas[$contador]}
	nCarpetaAux=${nombreComprimido[$contador]}
	echo "Subiendo carpeta ${copiaCarpetas[$contador]}..."
	find "$nCarpetaOrg" -maxdepth 0 -type d -exec 7z a "$nCarpetaAux".7z {} +
	rclone copy "$nCarpetaAux".7z remote:"$nombre_backup" -v
	if [ "$mantener7z" == "false" ]; then
		rm -f "$nCarpetaAux".7z
	fi
	contador=$((contador+1))
done

echo "Finalizando programa..."

