
Multiarch Setup
===============

Ensure binfmt support
---------------------
  
```
sudo apt install binfmt-support
sudo update-binfmts --enable
```

```
modprobe binfmt_misc
```

Create buildx builder with multiarch support
--------------------------------------------

```
# Create buildx container
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
#docker buildx create --name multiarch --driver docker-container --use

# Create registry
docker run -d -p 5000:5000 --restart=always --name registry registry:2

# Create new multiarch + network builder
docker buildx create --name multiarch-network --use --driver-opt network=host

# Setup builder
docker buildx inspect --bootstrapa
```

Building
--------------

```
# Do build(s)
cd debian
./make.sh

# Cache builds to repo
cd ../tools
./cache.sh

# Post repo updates
cd ../repo
git add freight apt
git commit -m "Added x.x.x builds"
git push
```

Pruning old images
------------------

```
docker image prune -a --filter "until=24h"
```

