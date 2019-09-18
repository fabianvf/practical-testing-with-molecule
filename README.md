# Practical Ansible Testing with Molecule

[![Build Status](https://travis-ci.com/fabianvf/practical-testing-with-molecule.svg?branch=master)](https://travis-ci.com/fabianvf/practical-testing-with-molecule)

Contains all the code for the demos given in this presentation

`traditional/minecraft` is a role that installs a very basic Minecraft server on CentOS, either in a Vagrant environment or in a Docker environment

`kubernetes` is an operator that uses the `minecraft-kubernetes` role. It has two scenarios, one which runs the role against a Kubernetes-in-Docker cluster, and the other which installs the operator into the cluster.
