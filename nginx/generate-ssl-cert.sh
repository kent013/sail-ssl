#!/bin/bash

ME=$(basename $0)

OPENSSL_CONF=/docker-entrypoint.d/99-openssl.cnf
CA_DIR=/etc/nginx/certs/
CA_KEY=/etc/nginx/certs/ca.key
CA_CERT=/etc/nginx/certs/ca.pem
SERVER_KEY=/etc/nginx/certs/server.key
SERVER_CSR=/etc/nginx/certs/server.csr
SERVER_CERT=/etc/nginx/certs/server.pem

if [ -f $CA_KEY ] && [ -f $CA_CERT ] && [ -f $SERVER_KEY ] && [ -f $SERVER_CERT ]; then
    echo "$ME: CA/Server certificate already exists, do nothing."
else
    # setup / cleanup CA
    if [ ! -e $CA_DIR ]; then
        mkdir $CA_DIR
    else
        rm $CA_DIR/index.txt
        rm $CA_DIR/newcerts/*
    fi
    touch $CA_DIR/index.txt

    openssl req -config $OPENSSL_CONF -x509 -newkey rsa:2048 -keyout $CA_KEY \
        -out $CA_CERT -sha256 -days 3650 -nodes -subj '/CN=localhost' -extensions v3_ca 

    # create server csr with subjectAltName
CONFIG="
[ req ]
distinguished_name = req_dn
req_extensions = req_ext
[ req_dn ]
[ req_ext ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = localhost
IP.1 = 127.0.0.1
"
    openssl req -new -newkey rsa:2048 -keyout $SERVER_KEY \
        -out $SERVER_CSR -sha256 -nodes -subj '/CN=localhost' -config <(echo "$CONFIG") 

    # sign server csr
    openssl ca -config $OPENSSL_CONF -in $SERVER_CSR -cert $CA_CERT -keyfile $CA_KEY \
    -out $SERVER_CERT -days 3650 -notext -rand_serial -policy policy_anything -batch
    echo "$ME: Server certificate has been generated."
fi


