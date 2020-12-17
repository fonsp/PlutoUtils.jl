# Create a k8s cluster *locally* with pods that run pluto

For information on how to build and run Pluto docker image, see the [README in the parent directory](../README.md).

## Installing minikube
To run kubernetes locally for development purposes, first install [minikube](https://github.com/kubernetes/minikube). Minikube binaries can be found under releases in the linked repository.

Start the minikube cluster using the following command:
```
minikube start
```

To point your shell to the docker environment inside the minikube process
```
minikube docker-env
```
Follow the instructions at the end and execute the command it prints out (this is different on different systems). In Windows PowerShell, the command outputted will be:
```
& minikube -p minikube docker-env | Invoke-Expression
```
Then build the necessary docker images for running Pluto. Instructions for building these images can be found in `/docker` of this repository.

At this point the configuration inside this directory can be applied to the kubernetes cluster. Some configuration values may need to be changed, such as the pluto image tag inside [pluto-deployment.yaml](pluto-deployment.yaml)

Configuration files can be applied to a kubernetes cluster with the following command:
```
kubectl apply -f <filename>
```
For example assuming your PWD is the same as this readme's parent:
```
kubectl apply -f pluto-deployment.yaml
```
