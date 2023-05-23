# DEMO

## Setting Up


- Create the respective namespace
 
```$bash
oc new-project app
```

- Create a *Sealed Secret* object from a *Secret* file

```$bash
kubeseal -f examples/secret-argo.yaml --name gitops-sealedsecret \
 --controller-namespace=sealedsecrets \
 --controller-name=sealed-secrets \
 --format yaml > examples/argocd/sealedsecret.yaml
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
```

- Check Sealedsecrets created

```$bash
oc get sealedsecret -n app
NAME            AGE
mysecret-argocd        11m

oc get secret -n app
NAME            AGE
mysecret-argocd                   Opaque                                1      11m
```

- Access Argo CD console

```$bash
# Retrieve Password
oc get secret argocd-cluster -o jsonpath='{.data.admin\.password}' -n argocd | base64 -d

# Retrieve URL
oc get route argocd-server -n argocd
```

## Author

Asier Cidon @RedHat
