#!/bin/bash
##
# Generate SealedSecret objects in order to analyse Sealed Secret Controller performance
##

FILE='tmp/all-objects.yaml'

mkdir tmp
rm $FILE

for i in {1..5000}
do
  echo $i
  echo "---" >> $FILE
  oc create secret generic mysecret-$i --dry-run=client --from-literal=foo$i=bar$i -o yaml | \
    kubeseal \
      --controller-name=sealed-secrets \
      --controller-namespace=sealedsecrets \
      --format yaml >> $FILE
done

oc apply -f $FILE