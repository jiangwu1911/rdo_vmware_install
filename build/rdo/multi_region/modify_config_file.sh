#!/bin/bash

# This script should be run on the new region server

REGION=RegionTwo
KEYSTONE_SERVER_IP=192.168.1.116

function modify_config_file() {
    openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://${KEYSTONE_SERVER_IP}:5000/
    openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host ${KEYSTONE_SERVER_IP}

    openstack-config --set /etc/cinder/api-paste.ini filter:authtoken auth_host ${KEYSTONE_SERVER_IP}
    openstack-config --set /etc/cinder/api-paste.ini filter:authtoken auth_uri http://${KEYSTONE_SERVER_IP}:5000/
    openstack-config --set /etc/cinder/api-paste.ini filter:authtoken service_host ${KEYSTONE_SERVER_IP}

    openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken identity_uri http://${KEYSTONE_SERVER_IP}:35357/
    openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken auth_uri http://${KEYSTONE_SERVER_IP}:5000/
    openstack-config --set /etc/glance/glance-api.conf keystone_authtoken identity_uri http://${KEYSTONE_SERVER_IP}:35357/
    openstack-config --set /etc/glance/glance-api.conf keystone_authtoken auth_uri http://${KEYSTONE_SERVER_IP}:5000/
}

modify_config_file
