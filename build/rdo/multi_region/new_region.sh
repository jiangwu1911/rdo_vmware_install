#!/bin/bash

REGION=RegionTwo
REGION_SERVER_IP=192.168.1.118

glance_service_id=`keystone service-get glance 2>/dev/null| awk '/ id / { print $4 }'` 
cinder_service_id=`keystone service-get cinder 2>/dev/null| awk '/ id / { print $4 }'` 
cinderv2_service_id=`keystone service-get cinderv2 2>/dev/null| awk '/ id / { print $4 }'` 
nova_service_id=`keystone service-get nova 2>/dev/null| awk '/ id / { print $4 }'` 
nova_ec2_service_id=`keystone service-get nova_ec2 2>/dev/null| awk '/ id / { print $4 }'` 
novav3_service_id=`keystone service-get novav3 2>/dev/null| awk '/ id / { print $4 }'` 

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
