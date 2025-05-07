# Introduction

This repo contains commonly used bash scripts and code snippets.

For example if you want to use snippets related to docker, include this in your script:

```bash
export FOLDER_bash=$(pwd)
source ${FOLDER_bash}/docker.sh
```

and you can execute, for example:

```bash
docker_restart --cpu 4 --memory 8
```

 to restart docker to use 4 CPU cores and 8 GB of RAM.