# Introduction

This repo contains commonly used bash scripts and code snippets.

For example if you want to use snippets related to docker, include this in your script:

```bash
export FOLDER_bash=$(pwd)
source ${FOLDER_bash}/docker.sh
```

and you can execute, for example:

```bash
docker_delete_all
```

to delete all docker resources.