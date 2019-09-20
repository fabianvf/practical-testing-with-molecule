#!/usr/bin/bash

pushd kubernetes
(molecule converge && molecule verify)&
(molecule converge -s operator && molecule verify -s operator)&
popd

pushd traditional/minecraft
(molecule converge && molecule verify)&
(molecule converge -s vagrant && molecule verify -s vagrant)&
popd

((flatpak run com.mojang.Minecraft)&)&
