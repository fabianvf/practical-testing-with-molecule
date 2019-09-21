#!/usr/bin/bash

pushd kubernetes
(molecule converge && molecule verify)&
(molecule converge -s operator && molecule verify -s operator)&
popd

pushd traditional/minecraft
sed -i -e 's/server.jar/spigot.jar/' templates/minecraft.service.j2
git add templates/minecraft.service.j2
git commit -m "Breaking the role for my demo"
git push origin master

(molecule converge && molecule verify)&
(molecule converge -s vagrant && molecule verify -s vagrant)&
