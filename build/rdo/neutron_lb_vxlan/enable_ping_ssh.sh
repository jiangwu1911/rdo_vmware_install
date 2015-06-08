#!/bin/bash

neutron security-group-rule-create --protocol icmp \
    --direction ingress default

neutron security-group-rule-create --protocol icmp \
    --direction egress default

neutron security-group-rule-create --protocol tcp --port-range-min 22 \
    --port-range-max 22 --direction ingress default
