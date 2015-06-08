#!/bin/bash

# OpenStack version: kilo

HYPERVISOR=kvm

ADMIN_PASSWORD="admin"
DNS_SERVER="192.168.206.2"

COMPUTE_HOSTS="192.168.206.139"
FLOATING_RANGE="192.168.206.224/28"
INTERFACE=eno16777736

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

    modify_answerfile CONFIG_NEUTRON_INSTALL y
    modify_answerfile CONFIG_SWIFT_INSTALL n
    modify_answerfile CONFIG_NAGIOS_INSTALL n
    modify_answerfile CONFIG_CEILOMETER_INSTALL n
    modify_answerfile CONFIG_HEAT_INSTALL y
    modify_answerfile CONFIG_PROVISION_DEMO n
    modify_answerfile CONFIG_KEYSTONE_ADMIN_PW $ADMIN_PASSWORD

    modify_answerfile CONFIG_NEUTRON_ML2_MECHANISM_DRIVERS linuxbridge,l2population
    modify_answerfile CONFIG_NEUTRON_L2_AGENT linuxbridge
    modify_answerfile CONFIG_NEUTRON_L3_EXT_BRIDGE ""
    modify_answerfile CONFIG_NEUTRON_LB_INTERFACE_MAPPINGS external:$INTERFACE

    packstack --answer-file=$answerfile

    echo ". ~/keystonerc_admin" > ~/.bash_profile
    . ~/.bash_profile
    popd >/dev/null
}

# Modify openstack configurations
function post_install() {
    # nova
    filters=`openstack-config --get /etc/nova/nova.conf DEFAULT scheduler_default_filters`
    openstack-config --set /etc/nova/nova.conf DEFAULT scheduler_default_filters "AggregateMultiTenancyIsolation,$filters"
    openstack-config --set /etc/nova/nova.conf DEFAULT allow_resize_to_same_host true 
    openstack-config --set /etc/nova/nova.conf DEFAULT dns_server $DNS_SERVER

    if [ "$HYPERVISOR" = "kvm" ]; then
        openstack-config --set /etc/nova/nova.conf libvirt virt_type kvm
    fi

    systemctl restart openstack-nova-compute
    systemctl restart openstack-nova-scheduler
    systemctl restart openstack-nova-conductor

    openstack-config --set /etc/nova/nova.conf DEFAULT notification_driver messaging
    openstack-config --set /etc/nova/nova.conf DEFAULT notify_on_state_change vm_and_task_state
    openstack-config --set /etc/nova/nova.conf DEFAULT control_exchange nova
    systemctl restart openstack-nova-api

    # cinder
    openstack-config --set /etc/cinder/cinder.conf DEFAULT notification_driver messaging
    openstack-config --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder
    systemctl restart openstack-cinder-api

    # glance
    openstack-config --set /etc/glance/glance-api.conf DEFAULT notification_driver messaging
    openstack-config --set /etc/glance/glance-api.conf DEFAULT control_exchange glance
    systemctl restart openstack-glance-api
    systemctl restart openstack-glance-registry

    # neutron
    openstack-config --set /etc/neutron/plugin.ini ml2 type_drivers "flat,vxlan"
    systemctl restart neutron-linuxbridge-agent
    systemctl restart neutron-server
}

function apply_patches() {
    yum install -y patch

    patch -p1 /usr/lib/python2.7/site-packages/nova/scheduler/filters/aggregate_multitenancy_isolation.py < ~/rdo/patches/scheduler_filter_aggregate.patch
    systemctl restart openstack-nova-scheduler
}

function import_image() {
    pushd ~/rdo >/dev/null
    if [ "$HYPERVISOR" = "vmware" ]; then
        ./import_image.sh vmware    
    else 
        ./import_image.sh kvm
    fi
    popd >/dev/null
}

pre_install
install_openstack
post_install
apply_patches
import_image
