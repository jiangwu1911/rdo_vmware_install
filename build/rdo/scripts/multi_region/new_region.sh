#!/bin/bash

REGION=region02
REGION_SERVER_IP=192.168.206.152
KEYSTONE_SERVER_IP=192.168.206.151

function regist_new_region() {
    export OS_USERNAME=admin
    export OS_TENANT_NAME=admin
    export OS_PASSWORD=admin
    export OS_AUTH_URL=http://192.168.206.151:5000/v2.0/
    export OS_REGION_NAME=RegionOne
    export PS1='[\u@\h \W(keystone_admin)]\$ '

    keystone_service_id=`keystone service-get keystone 2>/dev/null| awk '/ id / { print $4 }'` 
    glance_service_id=`keystone service-get glance 2>/dev/null| awk '/ id / { print $4 }'` 
    cinder_service_id=`keystone service-get cinder 2>/dev/null| awk '/ id / { print $4 }'` 
    cinderv2_service_id=`keystone service-get cinderv2 2>/dev/null| awk '/ id / { print $4 }'` 
    nova_service_id=`keystone service-get nova 2>/dev/null| awk '/ id / { print $4 }'` 
    nova_ec2_service_id=`keystone service-get nova_ec2 2>/dev/null| awk '/ id / { print $4 }'` 
    novav3_service_id=`keystone service-get novav3 2>/dev/null| awk '/ id / { print $4 }'` 
    heat_service_id=`keystone service-get heat 2>/dev/null| awk '/ id / { print $4 }'` 

    keystone endpoint-create --region $REGION --service_id $keystone_service_id \
            --publicurl "http://${KEYSTONE_SERVER_IP}:5000/v2.0" \
            --adminurl "http://${KEYSTONE_SERVER_IP}:35357/v2.0" \
            --internalurl "http://${KEYSTONE_SERVER_IP}:5000/v2.0"

    keystone endpoint-create --region $REGION --service_id $glance_service_id \
            --publicurl "http://${REGION_SERVER_IP}:9292" \
            --adminurl "http://${REGION_SERVER_IP}:9292" \
            --internalurl "http://${REGION_SERVER_IP}:9292"

    keystone endpoint-create --region $REGION --service_id $nova_service_id \
            --publicurl "http://${REGION_SERVER_IP}:8774/v2/%(tenant_id)s" \
            --adminurl "http://${REGION_SERVER_IP}:8774/v2/%(tenant_id)s" \
            --internalurl "http://${REGION_SERVER_IP}:8774/v2/%(tenant_id)s"

    keystone endpoint-create --region $REGION --service_id $nova_ec2_service_id \
            --publicurl "http://${REGION_SERVER_IP}:8773/services/Cloud" \
            --adminurl "http://${REGION_SERVER_IP}:8773/services/Cloud" \
            --internalurl "http://${REGION_SERVER_IP}:8773/services/Cloud"

    keystone endpoint-create --region $REGION --service_id $cinder_service_id \
            --publicurl "http://${REGION_SERVER_IP}:8776/v1/%(tenant_id)s" \
            --adminurl "http://${REGION_SERVER_IP}:8776/v1/%(tenant_id)s" \
            --internalurl "http://${REGION_SERVER_IP}:8776/v1/%(tenant_id)s"

    keystone endpoint-create --region $REGION --service_id $novav3_service_id \
            --publicurl "http://${REGION_SERVER_IP}:8774/v3" \
            --adminurl "http://${REGION_SERVER_IP}:8774/v3" \
            --internalurl "http://${REGION_SERVER_IP}:8774/v3"

    keystone endpoint-create --region $REGION --service_id $cinderv2_service_id \
            --publicurl "http://${REGION_SERVER_IP}:8776/v2/%(tenant_id)s" \
            --adminurl "http://${REGION_SERVER_IP}:8776/v2/%(tenant_id)s" \
            --internalurl "http://${REGION_SERVER_IP}:8776/v2/%(tenant_id)s"

    keystone endpoint-create --region $REGION --service_id $heat_service_id \
            --publicurl "http://${REGION_SERVER_IP}:8004/v1/%(tenant_id)s" \
            --adminurl "http://${REGION_SERVER_IP}:8004/v1/%(tenant_id)s" \
            --internalurl "http://${REGION_SERVER_IP}:8004/v1/%(tenant_id)s"
}


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

regist_new_region
modify_config_file
systemctl disable httpd
