#!/bin/bash

# clean last certs
rm -f ca*
# generate rsa key
openssl genrsa -des3 -out ca.key 1024
# copy rsa key without password
openssl rsa -in ca.key -out ca_nopass.key
# generate cert request
openssl req -new -key ca.key -config ./openssl.cnf -out ca.csr
# self-sign cert with 365 days validation
openssl x509 -req -days 365 -in ca.csr -signkey ca.key -extfile ./openssl.cnf -extensions v3_ca -out ca.crt
