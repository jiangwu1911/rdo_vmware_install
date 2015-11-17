#!/bin/bash

# OpenStack version: kilo

ADMIN_PASSWORD="admin"

dt=`date '+%Y%m%d-%H%M%S'`
logfile="install_$dt.log"
answerfile="mystack.txt"

function add_hostname() {
    localip=`ifconfig | grep -v 127.0.0.1 | grep inet | grep -v inet6 | awk '{print $2}' | sed 's/addr://'`
    hostname=`hostname`
    sed -i "/.* $hostname/d" /etc/hosts
    echo "$localip $hostname" >> /etc/hosts
}

function pre_install() {
    yum install -y net-tools | tee -a $logfile 
    add_hostname
}

function modify_answerfile() {
    sed -i "s#^$1=.*#$1=$2#" $answerfile
}

function install_openstack() {
    yum install -y openstack-packstack | tee -a $logfile 
 
    # Make sure installer not connect to internet
    sed -i "s#\$repos_ensure.*#\$repos_ensure = false#" /usr/share/openstack-puppet/modules/rabbitmq/manifests/params.pp
    
    pushd ~/rdo >/dev/null
    if [ ! -e $answerfile ]; then
        packstack  --gen-answer-file=$answerfile
        cp -n $answerfile ${answerfile}.bak
    fi

    modify_answerfile CONFIG_NEUTRON_INSTALL n
    modify_answerfile CONFIG_GLANCE_INSTALL n
    modify_answerfile CONFIG_CINDER_INSTALL n
    modify_answerfile CONFIG_NOVA_INSTALL n
    modify_answerfile CONFIG_SWIFT_INSTALL y
    modify_answerfile CONFIG_NAGIOS_INSTALL n
    modify_answerfile CONFIG_CEILOMETER_INSTALL n
    modify_answerfile CONFIG_HEAT_INSTALL n
    modify_answerfile CONFIG_PROVISION_DEMO n
    modify_answerfile CONFIG_KEYSTONE_ADMIN_PW $ADMIN_PASSWORD

    packstack --answer-file=$answerfile

    echo ". ~/keystonerc_admin" > ~/.bash_profile
    . ~/.bash_profile
    popd >/dev/null
}

pre_install
install_openstack
