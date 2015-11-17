#!/bin/sh

curl -d '{"auth":{"passwordCredentials":{"username": "jwu", "password": "abc123"},"tenantName":"jwu"}}' -H "Content-type: application/json" http://localhost:5000/v2.0/tokens
