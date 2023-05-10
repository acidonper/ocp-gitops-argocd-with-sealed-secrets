#!/bin/bash
##
# Generate CA and certificates
##

mkdir -p tmp/old
cp tmp/* tmp/old
openssl genrsa -out tmp/ca-key.pem 2048
openssl req -x509 -sha256 -new -nodes -key tmp/ca-key.pem -days 3650 -out tmp/ca-tls.pem
openssl req -out tmp/tls.csr -newkey rsa:2048 -nodes -keyout tmp/tls.key -subj "/"
openssl x509 -req -days 365 -CA tmp/ca-tls.pem -CAkey tmp/ca-key.pem -CAcreateserial -in tmp/tls.csr -out tmp/tls.crt
oc delete secret cert-encryption -n sealedsecrets
oc create secret generic cert-encryption  -n sealedsecrets --from-file=tmp/tls.key --from-file=tmp/tls.crt --from-file=tmp/ca-tls.pem