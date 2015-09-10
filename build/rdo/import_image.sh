#!/bin/sh

if [ "$1" = "vmware" ]; then
    glance image-create \
        --name cirros \
        --disk-format vmdk \
        --visibility public \
        --container-format bare \
        --property vmware_adaptertype="ide" \
        --property vmware_disktype="sparse" \
        --property hypervisor_type="vmware" \
        < images/cirros-0.3.3-x86_64-ide.vmdk
else
    glance image-create \
        --name cirros \
        --disk-format qcow2 \
        --visibility public \
        --container-format bare \
        < images/cirros-0.3.2-x86_64-disk.img
fi
