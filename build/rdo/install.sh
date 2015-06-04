#!/bin/bash

# OpenStack version: kilo

HYPERVISOR=vmware

VCENTER_HOST=192.168.206.140
VCENTER_USER=root
VCENTER_PASSWORD=vmware
GLANCE_DATACENTER=dc01
VCENTER_CLUSTER=cluster01
GLANCE_DATASTORE=share01
GLANCE_IMAGE_PATH=/openstack_glance

#OPENSTACK_NIC=ens224
FIXED_IP_RANGE="10.0.0.0/16"
FLOAT_IP_RANGE="192.168.206.224/28"
ADMIN_PASSWORD="admin"
DNS_SERVER="8.8.8.8"

USE_VLAN="yes"
VLAN_START=101
VLAN_NUM=10
VMWARE_VLAN_INTERFACE=vmnic0

COMPUTE_HOSTS="192.168.206.146"
KEYSTONE_REGION="region01"
SERVICE_PASSWORD="0477c6168f474238"


dt=`date '+%Y%m%d-%H%M%S'`
logfile="install_$dt.log"
answerfile="mystack.txt"

function add_hostname() {
    localip=`ifconfig | grep -v 127.0.0.1 | grep inet | grep -v inet6 | awk '{print $2}' | sed 's/addr://'`
    hostname=`hostname`
    sed -i "/.* $hostname/d" /etc/hosts
    hostname_without_domain=`echo $hostname | awk -F'.' '{print $1}'`
    echo "$localip $hostname $hostname_without_domain" >> /etc/hosts
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

    if [ -n "$OPENSTACK_NIC" ]; then
        nic=$OPENSTACK_NIC
    else
        nic=`ifconfig | grep flags | grep -v lo: | awk -F: '{print $1}'`
    fi

    modify_answerfile CONFIG_NEUTRON_INSTALL n
    modify_answerfile CONFIG_SWIFT_INSTALL n
    modify_answerfile CONFIG_NAGIOS_INSTALL n
    modify_answerfile CONFIG_CEILOMETER_INSTALL n
    modify_answerfile CONFIG_HEAT_INSTALL y

    modify_answerfile CONFIG_NOVA_KS_PW $SERVICE_PASSWORD
    modify_answerfile CONFIG_NEUTRON_KS_PW $SERVICE_PASSWORD
    modify_answerfile CONFIG_HEAT_KS_PW $SERVICE_PASSWORD
    modify_answerfile CONFIG_GLANCE_KS_PW $SERVICE_PASSWORD
    modify_answerfile CONFIG_CINDER_KS_PW $SERVICE_PASSWORD
    
    modify_answerfile CONFIG_KEYSTONE_REGION $KEYSTONE_REGION

    if [ -n $COMPUTE_HOSTS ]; then
        modify_answerfile CONFIG_COMPUTE_HOSTS $COMPUTE_HOSTS
        modify_answerfile CONFIG_NETWORK_HOSTS $COMPUTE_HOSTS
    fi

    if [ "$HYPERVISOR" = "vmware" ]; then
        modify_answerfile CONFIG_VMWARE_BACKEND y
        modify_answerfile CONFIG_VCENTER_HOST $VCENTER_HOST
        modify_answerfile CONFIG_VCENTER_USER $VCENTER_USER
        modify_answerfile CONFIG_VCENTER_PASSWORD $VCENTER_PASSWORD
        modify_answerfile CONFIG_VCENTER_CLUSTER_NAME $VCENTER_CLUSTER
        modify_answerfile CONFIG_CINDER_BACKEND vmdk
    fi

    modify_answerfile CONFIG_NOVA_COMPUTE_PRIVIF $nic
    modify_answerfile CONFIG_NOVA_NETWORK_PRIVIF $nic
    modify_answerfile CONFIG_NOVA_NETWORK_PUBIF $nic
    modify_answerfile CONFIG_NOVA_NETWORK_FIXEDRANGE $FIXED_IP_RANGE
    modify_answerfile CONFIG_NOVA_NETWORK_FLOATRANGE $FLOAT_IP_RANGE

    modify_answerfile CONFIG_KEYSTONE_ADMIN_PW $ADMIN_PASSWORD
    modify_answerfile CONFIG_PROVISION_DEMO n

    if [ "$USE_VLAN" = "yes" ]; then
        modify_answerfile CONFIG_NOVA_NETWORK_MANAGER nova.network.manager.VlanManager
        modify_answerfile CONFIG_NOVA_NETWORK_VLAN_START $VLAN_START
        modify_answerfile CONFIG_NOVA_NETWORK_NUMBER $VLAN_NUM
    fi

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

    if [ "$HYPERVISOR" = "vmware" ]; then
        if [ "$USE_VLAN" = "yes" ]; then
            openstack-config --set /etc/nova/nova.conf vmware vlan_interface $VMWARE_VLAN_INTERFACE
        fi
    fi

    if [ "$HYPERVISOR" = "kvm" ]; then
        openstack-config --set /etc/nova/nova.conf libvirt virt_type kvm
    fi

    systemctl restart openstack-nova-compute
    systemctl restart openstack-nova-scheduler
    systemctl restart openstack-nova-conductor
    pkill -9 dnsmasq
    systemctl restart openstack-nova-network

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
    if [ "$HYPERVISOR" = "vmware" ]; then
        openstack-config --set /etc/glance/glance-api.conf glance_store default_store vsphere
        openstack-config --set /etc/glance/glance-api.conf glance_store vmware_server_host $VCENTER_HOST
        openstack-config --set /etc/glance/glance-api.conf glance_store vmware_server_username $VCENTER_USER
        openstack-config --set /etc/glance/glance-api.conf glance_store vmware_server_password $VCENTER_PASSWORD
        openstack-config --set /etc/glance/glance-api.conf glance_store vmware_datacenter_path $GLANCE_DATACENTER
        openstack-config --set /etc/glance/glance-api.conf glance_store vmware_datastore_name $GLANCE_DATASTORE
        openstack-config --set /etc/glance/glance-api.conf glance_store vmware_store_image_dir $GLANCE_IMAGE_PATH
        openstack-config --set /etc/glance/glance-api.conf glance_store stores glance.store.vmware_datastore.Store
    fi
    systemctl restart openstack-glance-api
    systemctl restart openstack-glance-registry

    # ceilometer
    #if [ "$HYPERVISOR" = "vmware" ]; then
    #    openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT hypervisor_inspector vsphere
    #    openstack-config --set /etc/ceilometer/ceilometer.conf vmware host_ip $VCENTER_HOST
    #    openstack-config --set /etc/ceilometer/ceilometer.conf vmware host_username $VCENTER_USER
    #    openstack-config --set /etc/ceilometer/ceilometer.conf vmware host_password $VCENTER_PASSWORD
    #    systemctl restart openstack-ceilometer-central
    #    systemctl restart openstack-ceilometer-collector
    #    systemctl restart openstack-ceilometer-compute
    #fi

    # VMs can connect to internet
    iptables -t nat -I POSTROUTING -s $FIXED_IP_RANGE ! -d $FIXED_IP_RANGE -j MASQUERADE
    service iptables save
}

function apply_patches() {
    yum install -y patch
    patch -p1 /usr/lib/python2.7/site-packages/nova/network/linux_net.py < ~/rdo/patches/linux_net_br100_promisc.patch
    pkill -9 dnsmasq
    systemctl restart openstack-nova-network

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
