#!/bin/bash
#==============================================================================
# Licencia GNU/GPL Versión 2 o superior
#
# Descripción:
# Script para la instalación de iTop en Rocky Linux 8 con instalación mínima.
#
#==============================================================================

#==============================================================================
# Variables - Modifica sólamente esta parte (lo demás si sabes lo que haces).
#==============================================================================
DOMINIO="cmdb.tu_dominio.mx"             # Dominio del Sitio
CORREO_ADMIN="contacto@tu_dominio.mx"    # Correo adminsitrador

IP_SEGMENTO_ADMINISTRACION="192.168.1" # Dos, tres o cuatro octetos de la IP
DIRECTORIO="itop"			                   # Nombre del directorio de instalación

USUARIO_CRON_ITOP="usuario_cron"         # Usuario para cron de iTop
USUARIO_CRON_ITOP_PASSWORD="password"    # Contraseña de usuario para cron iTop

MARIADB_ROOT_PASSWORD="password"         # Contraseña usuario "root" de MariaDB
BASE_DATOS_ITOP="itopdb"                 # Nombre de la Base de Datos para iTop
USUARIO_BASE_DATOS="usritopdb"           # Nombre usuario de Base de Datos
USUARIO_BASE_DATOS_PASSWORD="password"   # Contraseña de usuario de Base Datos


#==============================================================================
# Se suspende la validación de certificados en caso de mostrar error de ssl
#==============================================================================
#echo "sslverify=0" >> /etc/dnf/dnf.conf

#==============================================================================
# Sincronización de tiempo de equipo con la hora "oficial" de México
#==============================================================================
# Instalación de Chrony
dnf -y install chrony

# Configuración de Zona Horaria
timedatectl set-timezone America/Mexico_City

# Se sincronizará con un servidor de tiempo (NTP)
timedatectl set-ntp yes

# Configuración de servidor de tiempo a "cronos.cenam.mx"
sed -i "s/pool 2.pool.ntp.org iburst/server cronos.cenam.mx/g" /etc/chrony.conf

# Instala la herramienta ntpstat
dnf -y install ntpstat

# Muestra el estatus de sincronización del equipo con el servidor de tiempo.
ntpstat

# Sincroniza el servidor de tiempo al iniciar el equipo
systemctl enable --now chronyd

# Reinicia el servicio de cron
systemctl restart chronyd

# Muestra informacioń del tiempo actual de las fuentes o servidores de tiempo
chronyc sources


#==============================================================================
# Instalación de repositorio EPEL
#==============================================================================
# Limpia metadatos
dnf clean all

# Extra Packages for Enterprise Linux (EPEL)
dnf -y install epel-release

# Remi's RPM repository - https://rpms.remirepo.net/wizard/
dnf -y install https://rpms.remirepo.net/enterprise/remi-release-8.rpm

# Actualiza paquetes 
dnf -y update


#==============================================================================
# Instalación de paquetes
#==============================================================================
dnf -y install dnf-utils net-tools policycoreutils-python-utils wget vim bash-completion unzip graphviz git expect
dnf -y install httpd mod_ssl 

dnf module reset php
dnf -y module install php:remi-7.4
dnf -y update

dnf -y install php php-mysql php-xml php-cli php-soap php-ldap php-gd php-zip php-json php-intl php-mcrypt php-mbstring 


#==============================================================================
# Configuración de "PHP: Hypertext Preprocessor"
# https://www.itophub.io/wiki/page?id=3_0_0%3Ainstall%3Aphp_and_mysql_configuration
#==============================================================================
sed -i "s/post_max_size = 8M/post_max_size = 255M/g" /etc/php.ini
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 250M/g" /etc/php.ini
sed -i "s/max_input_time = 60/max_input_time = -1/g" /etc/php.ini
sed -i "s/memory_limit = 128M/memory_limit = 256M/g" /etc/php.ini
sed -i "s/;max_input_vars = 1000/max_input_vars = 5000/g" /etc/php.ini

#==============================================================================
# Descarga de iTop
#==============================================================================
wget -O iTop-3.0.1-9191.zip "https://sourceforge.net/projects/itop/files/itop/3.0.1/iTop-3.0.1-9191.zip/download"
unzip iTop-3.0.1-9191.zip
mv web/* /var/www/html/
mkdir /var/www/html/{conf,env-production,env-production-build}


#==============================================================================
# Descarga Extensión - Monedas Adicionales para Contratos
#==============================================================================
git clone https://github.com/HCDCU/CMDB-MonedasContratos.git /var/www/html/extensions/monedas-contratos

#==============================================================================
# Elimina diccionarios de otros lenguajes - Excepto Español Castellano e Inglés
# Basado en el script de "Jeffrey Bostoen"
#==============================================================================
listaDiccionarios=("cs" "da" "de" "fr" "hu" "it" "ja" "nl" "pt_br" "ru" "sk" "tr" "zh" "zh_cn")

for i in "${listaDiccionarios[@]}"
do
   find /var/www/html/ -type f -name "$i.dict.*" -delete
   find /var/www/html/ -type f -name "$i.dictionary.*" -delete
done


#==============================================================================
# Cron de iTop
#==============================================================================
mkdir /etc/$DIRECTORIO
mv /var/www/html/webservices/cron.distrib /etc/$DIRECTORIO/
sed -i "s/auth_user=admin/auth_user=${USUARIO_CRON_ITOP}/g" /etc/$DIRECTORIO/cron.distrib
sed -i "s/auth_pwd=admin/auth_pwd=${USUARIO_CRON_ITOP_PASSWORD}/g" /etc/$DIRECTORIO/cron.distrib
echo "* * * * * /usr/bin/php /var/www/html/webservices/cron.php --param_file=/etc/$DIRECTORIO/cron.distrib >>/var/log/${DIRECTORIO}-cron.log 2>&1" | crontab


#==============================================================================
# Configuración de Virtualhost
#==============================================================================
cat << EOF > /etc/httpd/conf.d/00-$DIRECTORIO.conf
<VirtualHost *:80>
 ServerName ${DOMINIO}:80
 ServerAdmin $CORREO_ADMIN
 DocumentRoot "/var/www/html"
 DirectoryIndex index.php index.html
 CustomLog '|/usr/sbin/rotatelogs "/var/log/httpd/access_${DIRECTORIO}_log" 604800 -360' "%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-Agent}i\""
 ErrorLog '|/usr/sbin/rotatelogs "/var/log/httpd/error_${DIRECTORIO}_log" 604800 -360'
 ExpiresActive On
 ExpiresByType image/jpg "access plus 1 month"
 ExpiresByType image/png "access plus 1 month"
 ExpiresByType image/gif "access plus 1 month"
 ExpiresByType image/jpeg "access plus 1 month"
 ExpiresByType text/css "access plus 1 month"
 ExpiresByType image/x-icon "access plus 1 month"
 ExpiresByType application/pdf "access plus 1 month"
 ExpiresByType audio/x-wav "access plus 1 month"
 ExpiresByType audio/mpeg "access plus 1 month"
 ExpiresByType video/mpeg "access plus 1 month"
 ExpiresByType video/mp4 "access plus 1 month"
 ExpiresByType video/quicktime "access plus 1 month"
 ExpiresByType video/x-ms-wmv "access plus 1 month"
 ExpiresByType application/x-shockwave-flash "access 1 month"
 ExpiresByType text/javascript "access plus 2 month"
 ExpiresByType application/x-javascript "access plus 1 month"
 ExpiresByType application/javascript "access plus 1 month"
 <Directory "/var/www/html">
 AllowOverride all
 Options All -Includes -ExecCGI -Indexes +MultiViews
 Require all granted
 </Directory>
 #<Directory "/var/www/html/setup">
 #AllowOverride all
 #Options All -Includes -ExecCGI -Indexes +MultiViews
 #Require ip $IP_SEGMENTO_ADMINISTRACION
 #ErrorDocument 403 http://${DOMINIO}/
 #</Directory>
 LogLevel warn
 TimeOut 300
 ProxyTimeout 300
</VirtualHost>
EOF

#==============================================================================
# Configuración de archivo /etc/hosts
#==============================================================================
echo -ne "127.0.0.1\t$DOMINIO" >> /etc/hosts


#==============================================================================
# Seguridad por contexto - SELinux
#==============================================================================
setsebool -P httpd_can_network_connect_db on
setsebool -P httpd_can_connect_ldap on

chcon -u system_u /etc/$DIRECTORIO/cron.distrib
chcon -t etc_t /etc/$DIRECTORIO/cron.distrib
chcon -u system_u /etc/httpd/conf.d/00-$DIRECTORIO.conf
chcon -t httpd_config_t /etc/httpd/conf.d/00-$DIRECTORIO.conf
chcon -R -u system_u /var/www/html/*
chcon -R -t httpd_sys_content_t /var/www/html

semanage fcontext -a -t etc_t "/etc/$DIRECTORIO/cron.distrib"
semanage fcontext -a -t httpd_config_t "/etc/httpd/conf.d/00-${DIRECTORIO}.conf"
semanage fcontext -a -t httpd_sys_content_t "/var/www/html(/.*)?"
semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/conf"
semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/data"
semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/env-production"
semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/env-production-build"
semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/log"
semanage fcontext -a -t httpd_sys_rw_content_t "/var/www/html/extensions"

restorecon -R -v "/var/www/html"
restorecon -v "/etc/httpd/conf.d/00-${DIRECTORIO}.conf"
restorecon -v "/var/www/html/conf"
restorecon -v "/var/www/html/data"
restorecon -v "/var/www/html/env-production"
restorecon -v "/var/www/html/env-production-build"
restorecon -v "/var/www/html/log"
restorecon -v "/var/www/html/extensions"


#==============================================================================
# Propietario y permisos de archivos
#==============================================================================
chown -R apache:apache /var/www/html
find /var/www/html -type d -exec chmod 755 {} \;
find /var/www/html -type f -exec chmod 644 {} \;


#==============================================================================
# Permitir tráfico HTTP y HTTPS (puertos 80 y 443)
#==============================================================================
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --reload


#==============================================================================
# Servidor HTTP - Apache.
#==============================================================================
# Activar el servicio de base de datos MariaDB al iniciar el equipo
systemctl enable httpd.service

# Iniciar el servicio de base de datos MariaDB
systemctl start httpd.service


#==============================================================================
# Servidor de base de datos - MariaDB.
#==============================================================================
# Instalación de servidor de base de datos MariaDB
dnf -y install mariadb mariadb-server

# Configuracón del máximo tamaño de paquetes permitido
sed -i "s/\[client-server\]/\[client-server\]\nmax_allowed_packet=300M/g" /etc/my.cnf

# Activar el servicio de base de datos MariaDB al iniciar el equipo
systemctl enable mariadb.service

# Iniciar el servicio de base de datos MariaDB
systemctl start mariadb.service

# Configuración de MariaDB mediante "mysql_secure_installation"
INSTALACION_SEGURA_MARIADB=$(expect -c "
   set timeout 10
   spawn mysql_secure_installation
   expect \"Enter current password for root (enter for none): \"
   send \"\r\"
   expect \"Set root password? \[Y/n\] \"
   send \"Y\r\"
   expect \"New password:\"
   send \"$MARIADB_ROOT_PASSWORD\r\"
   expect \"Re-enter new password:\"
   send \"$MARIADB_ROOT_PASSWORD\r\"
   expect \"Remove anonymous users? \[Y/n\] \"
   send \"Y\r\"
   expect \"Disallow root login remotely? \[Y/n\] \"
   send \"Y\r\"
   expect \"Remove test database and access to it? \[Y/n\] \"
   send \"Y\r\"
   expect \"Reload privilege tables now? \[Y/n\] \"
   send \"Y\r\"
   expect EOF
")
echo "$INSTALACION_SEGURA_MARIADB"

# Creación de base de datos para iTop
mysql -u root -p$MARIADB_ROOT_PASSWORD -e "CREATE DATABASE $BASE_DATOS_ITOP DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci"

# Creación de usuario y permisos para iTop
mysql -u root -p$MARIADB_ROOT_PASSWORD -e "GRANT ALL ON $BASE_DATOS_ITOP.* TO '${USUARIO_BASE_DATOS}'@'localhost' identified by '${USUARIO_BASE_DATOS_PASSWORD}'"

#==============================================================================
#  Desinstalar expect y remover paquetes que ya no sean necesarios.
#==============================================================================
dnf -y remove expect
dnf -y autoremove


#==============================================================================
# Se reactiva la validación de certificados para la descarga de paquetes.
#==============================================================================
#sed -i "s/sslverify=0/sslverify=1/g" /etc/dnf/dnf.conf
