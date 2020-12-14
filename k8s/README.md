# Create a k8s cluster with pods that run pluto

## Container

We use the dockerfile of this repo

```
docker build --no-cache -t pluto:latest .

```

## Follow your host provider's guidance to install kubectl and other tools

## Docker save your image if you want to use in another machine

```
# If you need to build locally for any reason, use this:
docker save pluto:latest |gzip -c > pluto.tgz
scp pluto.tgz target_machine:/home/pgeorgakopoulos/
# On the target machine
gunzip -c pluto.tgz | docker load
```

### Upload to registry, from which k8s will take to make your pod

```
docker tag pluto registry.digitalocean.com/pluto-docker-images/pluto
docker push registry.digitalocean.com/pluto-docker-images/pluto
```

### Apply configurations

```
    for i in `ls *.yaml`; do
        kubectl apply -f $i;
    done
```

