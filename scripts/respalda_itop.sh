#!/bin/bash
###############################################################################
# Script para respaldo de CMDB iTop
#
# Licencia: GNU  GPL Versión 2.0
###############################################################################

###############################################################################
# Variables - Solo modifica aquí
###############################################################################
DIRECTORIO_CMDB="/var/www/html"
DIRECTORIO_RESPALDOS="/var/www/respaldos"

###############################################################################
ARCHIVO_CONFIGURACION_CMDB="$DIRECTORIO_CMDB/conf/production/config-itop.php"
FECHA_RESPALDO=$(date '+%Y_%m_%d__%H_%M')
DIRECTORIO_RESPALDO="$DIRECTORIO_RESPALDOS/$FECHA_RESPALDO"
BASE_DATOS_HOST=$(grep 'db_host' $ARCHIVO_CONFIGURACION_CMDB | awk -F "' => '" '{ print $2 }' | sed "s/'*',/$1/g")
BASE_DATOS_NOMBRE=$(grep 'db_name' $ARCHIVO_CONFIGURACION_CMDB | awk -F "' => '" '{ print $2 }' | sed "s/'*',/$1/g")
BASE_DATOS_USUARIO=$(grep 'db_user' $ARCHIVO_CONFIGURACION_CMDB | awk -F "' => '" '{ print $2 }' | sed "s/'*',/$1/g")
BASE_DATOS_CONTRASENA=$(grep 'db_pwd' $ARCHIVO_CONFIGURACION_CMDB | awk -F "' => '" '{ print $2 }' | sed "s/'*',/$1/g")
BASE_DATOS_ARCHIVO_RESPALDO="$BASE_DATOS_NOMBRE-$FECHA_RESPALDO.sql"

###############################################################################
# Creación de directorio para archivos de respaldo
mkdir -p $DIRECTORIO_RESPALDO

###############################################################################
# Información del Sistema
echo -e "Versiones del Servidor\n" > $DIRECTORIO_RESPALDO/Versiones_Sistema.txt

source /etc/os-release
echo -e "$PRETTY_NAME" >> $DIRECTORIO_RESPALDO/Versiones_Sistema.txt
httpd -v >> $DIRECTORIO_RESPALDO/Versiones_Sistema.txt
php -v >> $DIRECTORIO_RESPALDO/Versiones_Sistema.txt
mysql -V >> $DIRECTORIO_RESPALDO/Versiones_Sistema.txt

###############################################################################
# Paquetes instalados
dnf list installed > $DIRECTORIO_RESPALDO/Paquetes_Instalados.txt

###############################################################################
# Respaldo de configuración de servicios
tar -zcf $DIRECTORIO_RESPALDO/configuraciones_servidor.tgz -C $DIRECTORIO_RESPALDO /etc/os-release /etc/hosts /etc/php.ini /etc/my.cnf /etc/httpd

###############################################################################
# Respaldo de archivos
tar -czf $DIRECTORIO_RESPALDO/cmdb-$FECHA_RESPALDO.tgz -C $DIRECTORIO_RESPALDO $DIRECTORIO_CMDB

###############################################################################
# Respaldo de base de datos
mysqldump -u $BASE_DATOS_USUARIO -p$BASE_DATOS_CONTRASENA -h $BASE_DATOS_HOST $BASE_DATOS_NOMBRE > $DIRECTORIO_RESPALDO/$BASE_DATOS_ARCHIVO_RESPALDO
tar -czf $DIRECTORIO_RESPALDO/$BASE_DATOS_ARCHIVO_RESPALDO.tgz -C $DIRECTORIO_RESPALDO $DIRECTORIO_RESPALDO/$BASE_DATOS_ARCHIVO_RESPALDO
rm -f $DIRECTORIO_RESPALDO/$BASE_DATOS_ARCHIVO_RESPALDO

###############################################################################
# Creación de archivo con hashes de contenido de respaldo
md5sum $DIRECTORIO_RESPALDO/* > $DIRECTORIO_RESPALDO/md5sum-$FECHA_RESPALDO.txt  

###############################################################################
# Cambiamos permisos
chown -R root:root $DIRECTORIO_RESPALDO -R
chmod -R 400 $DIRECTORIO_RESPALDO 

###############################################################################
