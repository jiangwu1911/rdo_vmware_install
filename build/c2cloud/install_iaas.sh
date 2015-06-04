#!/bin/bash

OLD_MYSQL_ROOT_PASSWORD=""
NEW_MYSQL_ROOT_PASSWORD="password"
DATABASE_NAME="c2cloud"
DATABASE_USER="c2cloud"
DATABASE_PASSWORD="123456"
SOURCE_DIR=`dirname $0`

KEYSTONE_URL="http://10.2.2.213:5000/v2.0"
VNC_URL="http://10.2.2.213:6080"
VCENTER_IP="10.2.2.212"
VCENTER_USERNAME="root"
VCENTER_PASSWORD="vmware"

dt=`date '+%Y%m%d-%H%M%S'`
logfile="install_$dt.log"


# 配置mysql root口令, 创建sinopem库, 创建sinopem用户
function config_mysql() {
    echo -ne "\n配置MySQL数据库......      "

    mysql_secure_installation >> $logfile 2>&1 <<EOF
$OLD_MYSQL_ROOT_PASSWORD
Y
$NEW_MYSQL_ROOT_PASSWORD
$NEW_MYSQL_ROOT_PASSWORD
Y
Y
Y
EOF

    mysql -u root -p$NEW_MYSQL_ROOT_PASSWORD >> $logfile 2>&1 <<EOF
CREATE DATABASE $DATABASE_NAME;  
GRANT ALL ON $DATABASE_USER.* TO '$DATABASE_NAME'@'%' IDENTIFIED BY '$DATABASE_PASSWORD';  
commit;  
EOF

    cp $SOURCE_DIR/my.cnf /etc/my.cnf
    systemctl restart mysql
    mysql -u $DATABASE_NAME -p$DATABASE_PASSWORD -D$DATABASE_NAME -e quit >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "错误，请检查提供的数据库密码是否正确。"
        exit -1
    else 
        echo -e "成功。"
    fi
}


# 安装应用程序
function install_package() {
    echo -ne "\n安装IaaS云管平台......      "

    cp c2-cloud-resource-console-2.1.0-SNAPSHOT.war /usr/share/tomcat/webapps
    systemctl enable tomcat > /dev/null 2>&1
    systemctl start tomcat > /dev/null 2>&1

    conffile="/usr/share/tomcat/webapps/c2-cloud-resource-console-2.1.0-SNAPSHOT/WEB-INF/classes/c2-config.properties"
    while [ ! -e $conffile ]; do
        sleep 1    # 等待tomcat解压
    done
    sleep 3
    ln -s /usr/share/tomcat/webapps/c2-cloud-resource-console-2.1.0-SNAPSHOT /usr/share/tomcat/webapps/c2cloud

    mkdir /usr/share/tomcat/webapps/c2cloud/WEB-INF/c2cloudres_files
    chown -R tomcat:tomcat /usr/share/tomcat/webapps/c2cloud/WEB-INF/c2cloudres_files

    sed -i "s#^c2.file.rootFolder=.*#c2.file.rootFolder=/usr/share/tomcat/webapps/c2cloud/WEB-INF/c2cloudres_files#" $conffile
    sed -i "s#^c2.cloud.res.openstack.identity.endpoint=.*#c2.cloud.res.openstack.identity.endpoint=$KEYSTONE_URL#" $conffile
    sed -i "s#^c2.cloud.res.openstack.identity.vnc=.*#c2.cloud.res.openstack.identity.vnc=$VNC_URL#" $conffile
    sed -i "s/^c2.cloud.res.vmware.vim25.vCenterAddress=.*/c2.cloud.res.vmware.vim25.vCenterAddress=$VCENTER_IP/" $conffile
    sed -i "s/^c2.cloud.res.vmware.vim25.vCenterUserName=.*/c2.cloud.res.vmware.vim25.vCenterUserName=$VCENTER_USERNAME/" $conffile
    sed -i "s/^c2.cloud.res.vmware.vim25.vCenterPassword=.*/c2.cloud.res.vmware.vim25.vCenterPassword=$VCENTER_PASSWORD/" $conffile

    conffile="/usr/share/tomcat/webapps/c2cloud/WEB-INF/c2/conf/datasource.xml"
    sed -i "s#<url>.*#<url>jdbc:mysql://127.0.0.1:3306/c2cloud?useUnicode=true\&amp;characterEncoding=UTF-8\&amp;zeroDateTimeBehavior=convertToNull</url>#" $conffile
    sed -i "s#<username>.*#<username>$DATABASE_USER</username>#" $conffile
    sed -i "s#<password>.*#<password>$DATABASE_PASSWORD</password>#" $conffile
    
    sqlfile="/usr/share/tomcat/webapps/c2cloud/WEB-INF/classes/initdb/c2cloud-res-initdb.sql"
    sed -i "/^CREATE DATABASE/d" $sqlfile
    mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -D$DATABASE_NAME < $sqlfile >> $logfile 2>&1

    echo -e "成功。"
}


# 主程序
config_mysql
install_package
systemctl restart tomcat

sleep 5
localip=`ifconfig | grep -v 127.0.0.1 | grep inet | grep -v inet6 | awk '{print $2}' | sed 's/addr://'`
echo -e "\n安装完成，请在浏览器中打开http://$localip:8080/c2cloud, 访问IaaS云管平台。\n"
