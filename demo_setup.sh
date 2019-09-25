#!/usr/bin/bash

pushd traditional/minecraft
# molecule destroy --all
sed -i -e 's/server.jar/spigot.jar/' templates/minecraft.service.j2
git add templates/minecraft.service.j2
git commit -m "Breaking the role for my demo"
git push origin master

molecule converge && WAIT_SECONDS=5 molecule verify
molecule converge -s vagrant && WAIT_SECONDS=5 molecule verify -s vagrant
popd

pushd kubernetes
# molecule destroy --all
molecule converge && molecule verify
molecule converge -s operator && molecule verify -s operator
popd


export KUBECONFIG=~/.cache/molecule/kubernetes/operator/.kubeconfig
doitlive play demo.sh
