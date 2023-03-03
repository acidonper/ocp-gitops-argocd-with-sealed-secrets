# ocp-gitops-argocd-with-sealed-secrets

This repository collects information about implementing a secret management strategy based on Bitnami Sealed Secrets.

Bitnami Sealed Secrets encrypts your Secret into a SealedSecret, which is safe to store - even inside a public repository. The SealedSecret can be decrypted only by the controller running in the target cluster and nobody else (not even the original author) is able to obtain the original Secret from the SealedSecret.

## Prerequisites

- Helm
- kubeseal CLI +0.19.5 - [Official Doc](https://github.com/bitnami-labs/sealed-secrets#linux)
- Openshift +4.12
- Oc CLI +4.12 - [Official Doc](https://docs.openshift.com/container-platform/4.12/cli_reference/openshift_cli/getting-started-cli.html)

## Setting Up

This section includes a set of procedures to set up a Bitnami Sealed Secrets controller and create a first protected secret.

### Sealed Secret

Bitnami Sealed Secrets team has developed a Helm Chart for installing the solution automatically. This automatism is customizable with multiple variables depending on the client requirements.

It is important to bear in mind that The kubeseal utility uses asymmetric crypto to encrypt secrets that only the controller can decrypt. Please visit the following [link](https://github.com/bitnami-labs/sealed-secrets/blob/main/docs/developer/crypto.md) for more information about security protocols and cryptographic tools used.

In the following process, a Sealed Secrets controller will be installed using a custom certificate that was generated in the respective namespace previously. This installation model is designed for multi-cluster environments where it is required to use the same certificate in multiple Kubernetes clusters in order to facilitate operations and maintainability.

- Create the respective namespace
 
```$bash
oc new-project sealedsecrets
```

- Assign permissions to the default service account in order to be able to deploy the respective controller pod
 
```$bash
oc adm policy add-scc-to-user anyuid -z sealed-secrets-controller -n sealedsecrets
```

- Generate the respective certificates and create a secret
 
```$bash
sh scripts/generate-cert.sh
```

- Deploy Sealed Secrets using the respective Helm Chart and the secret generated by the previous script execution
 
```$bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets -n sealedsecrets --set-string secretName=cert-encryption sealed-secrets/sealed-secrets
```

### Create SealedSecret

Once the Sealed Secrets controller is installed and configured, it is time to start playing with Sealed Secrets. The following procedures include the main operations that it is possible to perform using Sealed Secrets.

- Create a *Sealed Secret* object from a *Secret* file

```$bash
kubeseal -f examples/secret.yaml -n app --name mysecret \
 --controller-namespace=sealedsecrets \
 --controller-name=sealed-secrets \
 --format yaml  | oc apply -n app -f -
```

- Create a *SealedSecret* object from a command

```$bash
oc create secret generic mysecret2 --dry-run=client --from-literal=foo=bar -o yaml | \
    kubeseal \
      --controller-name=sealed-secrets \
      --controller-namespace=sealedsecrets \
      --format yaml | oc apply -n app -f -
```

- Check the respective *SealedSecret* and *Secret* objects

```$bash
oc get sealedsecrets 
...
mysecret     12s
mysecret2    20s

oc get secret -n app
...
mysecret                    Opaque                                1      17s
mysecret2                   Opaque                                1      25s
```

## Operations

There are multiple operations and situations that it could be possible to assume during the Sealed Secrets solutions lifecycle. The following sections include some use cases or hypothetical situations with the respective procedures to face them.

### Obtain Controller Certificate

It is possible to obtain the Sealed Secrets controller's certificate exeuting the following command:

```$bash
kubeseal --controller-name=sealed-secrets --controller-namespace=sealedsecrets --fetch-cert
```
### Decrypt a SealedSecret Manually

In order to obtain the information from a specific *SealedSecret* object, it is possible decrypt a *SealedSecret* object included in a file using the kubeseal CLI and the respective certificate.

```$bash
cat examples/sealedsecret.yaml | kubeseal -o yaml --recovery-private-key tls-old.key --recovery-unseal
```

> **NOTE**
> 
> This procedure could be interesting if Sealed Secrets controller's certificate has been rotated and it is required to recover the original *Secret* objects using the previous certificate

### Rotate SealedSecret Certificate

During the life of the solution, it is possible to have certificate rotation due to certificate expiration date or security reasons rotation. The following procedure includes a mechanism to rotate the certificate:

- Generate the respective certificates and recreate the secret
 
```$bash
sh scripts/generate-cert.sh
```

- Restart the Sealed Secrets controller

```$bash
oc scale --replicas=0 deployment.apps/sealed-secrets -n sealedsecrets
oc scale --replicas=1 deployment.apps/sealed-secrets -n sealedsecrets
```

> **NOTE**
> 
> The original *SealedSecret* and *Secret* objects do not disappear but it is required to modify *SealedSecret* objects in order to encrypt the information with the new certificate

### Identify Error Decrypting SealedSecret Objects

After rotate certificates, it is possible to find errors if the *SealedSecret* objects are not modified. Execute the following procedure to detect these errors: 

```$bash
POD=$(oc get pods --no-headers -o custom-columns=":metadata.name" -n sealedsecrets )
oc logs $POD -n sealedsecrets
...
E0303 10:33:27.741011       1 controller.go:230] no key could decrypt secret (foo)
2023/03/03 10:33:27 Event(v1.ObjectReference{Kind:"SealedSecret", Namespace:"app", Name:"mysecret22", UID:"abf50e85-49d0-4288-857d-dce7dce9e6b5", APIVersion:"bitnami.com/v1alpha1", ResourceVersion:"1352784", FieldPath:""}): type: 'Warning' reason: 'ErrUnsealFailed' Failed to unseal: no key could decrypt secret (foo)
```

### Modifiying Created Secrets

It is possible to modify the *Secret* objects that have been created by Sealed Secret controller but you have to take into consideration that Sealed Secrets controller does not monitor the final *Secret* objects and any changes in the final object will be reemplaced when the original *SealedSecret* object is modified.

For this reason, it is required to execute the following procedure to update a specific *SealedSecret* object:

```$bash
oc extract secret/cert-encryption --to=.

oc get sealedsecret mysecret -o yaml -n app |  kubeseal -o yaml --recovery-private-key tls.key --recovery-unseal >> new-secret.yaml

vi new-secret.yaml (*Add some new literals)

kubeseal -f new-secret.yaml -n app --name mysecret \
 --controller-namespace=sealedsecrets \
 --controller-name=sealed-secrets \
 --format yaml  | oc apply -n app -f -
```

## Performance

In terms of performance, Sealed Secrets controller is an unique piece that has a single replica. It is important to bear in mind that having multiple replicas could bring consistency issues.

It is possible to create 1000 *SealedSecret* objects, one by one, during 5 minutes consuming 9 milicores and 80MB RAM by the Sealed Secrets controller.

> **NOTE**
> 
> The load tests have been performed in a laboratory environment with 1 Sealed Secrets controller replicas

## Author

Asier Cidon @RedHat
