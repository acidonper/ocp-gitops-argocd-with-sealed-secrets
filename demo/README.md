# DEMO - Openshift GitOps - Argo CD with SealedSecrets

This demo includes the basics about setting up an Argo CD environment and using Bitnami SealedSecrets.

## Prerequisites

- Openshift 4.12+
- Red Hat GitOps Operator
- Argo CD intance (*installed by default*)
- Bitnami Sealed Secrets v0.20.5+
- kubeseal CLI +0.19.5 - [Official Doc](https://github.com/bitnami-labs/sealed-secrets#linux)
- Oc CLI +4.12 - [Official Doc](https://docs.openshift.com/container-platform/4.12/cli_reference/openshift_cli/getting-started-cli.html)

## Setting Up

- Create a *Sealed Secret* object from a *Secret* file 

```$bash
cat examples/secret-argo.yaml 

oc extract --to=- -f examples/secret-argo.yaml 

kubeseal -f examples/secret-argo.yaml --name gitops-sealedsecret -n app-sealedsecrets \
 --controller-namespace=sealedsecrets \
 --controller-name=sealed-secrets \
 --format yaml > examples/argocd/sealedsecret.yaml

 cat examples/argocd/sealedsecret.yaml
```

- Add Changes to Git

```$bash
git add .
git commit -m "argocd sealed secrets"
git push
```

- Create ArgoCD application

```$bash
oc apply -f argocd/application.yaml -n openshift-gitops

cat argocd/application.yaml
```

- Access Argo CD console

```$bash
# Retrieve Password
oc get secret openshift-gitops-cluster -o jsonpath='{.data.admin\.password}' -n openshift-gitops | base64 -d

# Retrieve URL
oc get route  openshift-gitops-server -n  openshift-gitops
```

- Check Sealedsecrets created

```$bash
oc get sealedsecret -n app-sealedsecrets

oc get secret -n app-sealedsecrets

oc extract secret/gitops-sealedsecret --to=- -n app-sealedsecrets
```

- Check Sealed Secret microservice logs


```$bash
POD=$(oc get pods --no-headers -o custom-columns=":metadata.name" -n sealedsecrets )
oc logs $POD -n sealedsecrets
```


## Author

Asier Cidon @RedHat
