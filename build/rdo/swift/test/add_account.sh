#!/bin/sh

keystone tenant-create --name jwu

keystone user-create --name=jwu --pass=abc123 --tenant-id=jwu --email jiangwu1911@hotmail.com --enabled true
