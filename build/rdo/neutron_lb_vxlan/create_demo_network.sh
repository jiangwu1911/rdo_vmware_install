#!/bin/sh

FLOATING_IP_START=192.168.206.51
FLOATING_IP_END=192.168.206.60
FLOATING_IP_CIDR=192.168.206.0/24
FLOATING_IP_GATEWAY=192.168.206.2

neutron net-create ext-net --router:external \
           --provider:physical_network external --provider:network_type flat --shared
neutron subnet-create ext-net --name ext-subnet --allocation-pool \
           start=$FLOATING_IP_START,end=$FLOATING_IP_END --disable-dhcp \
           --gateway $FLOATING_IP_GATEWAY $FLOATING_IP_CIDR

neutron net-create demo-net --provider:network_type vxlan
neutron subnet-create demo-net --name demo-subnet --gateway 10.0.1.1 10.0.1.0/24
neutron router-create demo-router
neutron router-interface-add demo-router demo-subnet
neutron router-gateway-set demo-router ext-net
