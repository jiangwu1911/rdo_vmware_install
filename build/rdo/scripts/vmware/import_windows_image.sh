#!/bin/sh

image_name=$1

nova image-delete $image_name

glance image-create \
        --name=$image_name \
        --disk-format=vmdk \
        --container-format=bare  \
        --is-public=True  \
        --property vmware_disktype="sparse" \
        --property vmware_adaptertype="ide" \
        --property hypervisor_type="vmware" \
        --property vmware_ostype="windows7Server64Guest" \
      < $image_name-disk1.vmdk
