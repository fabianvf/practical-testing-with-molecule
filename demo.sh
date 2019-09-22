# Recorded with the doitlive recorder
#doitlive shell: /usr/bin/zsh
#doitlive prompt: default

# So I've created a (bad) role for deploying a basic vanilla minecraft server.
# Please nobody actually try to use this, there are much better roles out there already
# (and a few that I found already had molecule tests!)
#
# All right, so I won't actually be running a full molecule test here, because
# a) I don't want to risk a network fault breaking everything
# b) I don't want to have you all spend the next 30 minutes watching openjdk and minecraft download
#
# Instead, I want to show off how cool the iterative development flow is - it's (hopefully) letting me present
# this demo which installs hundreds of megabytes of dependencies on conference internet with almost no fear.
cd traditional/minecraft

tree

# So, heading to the minecraft role, we can see it looks a lot like what I showed in the slides (but not
# exactly because I've updated this demo a lot since making the slides). I've got two scenarios,
# default and vagrant. let's take a look at the molecule.ymls really quickly.
#
vim -O molecule/*/molecule.yml

# You can see we've got the dependency and lint sections which are identical, and then in the driver section
# for the default scenario I'm using docker, and for the vagrant scenario I'm predictably using vagrant.
#
# Going on to the platform sections, I'm creating two hosts with each platform, one is minecraft-server,
# which is going to be running the minecraft server, and the other is minecraft-client, which is going
# to be used during verification (but isn't really related to the minecraft role, it has its own set of tasks).
#
# You can see in the docker scenario I'm forwarding port 25565 in the container to 25565 on my laptop.
# I'm also using the centos7 image from geerlingguy (he has a bunch of them).
#
# They're really useful
# because they all have systemd running in them, which functionally means that I can run pretty much
# any command in the container that I'd run in say a VM or on bare metal. There's some other stuff going
# on with the cgroups that allow everything to work properly, but I can't really explain them so ask Jeff.
#
# For the vagrant scenario I'm just using centos:7 boxes, because I work at red hat and it's what I reach for
# instinctively.
#
# On to the provisioner section, they look pretty similar, except that I'm setting the motd to reflect the
# driver, and you can see in the vagrant scenario I'm just running the same playbooks as the default scenario.
#
# And then finally the verifier section, I'm just using Ansible and ansible-lint.
#
# So like I said before, I've already run converge which has stood up the instances, which means that the
# create and prepare steps have already been run. We can take a quick look to see what the vagrant scenario
# did for its preparation.
vim molecule/vagrant/prepare.yml

#
# On both the client and server, we're making sure that Python is installed, and then I'm installing a few
# dependencies on the client, which is only used for verification. Also I guess I should provide some proof that
# these virtual machines are running, so let me just show that real quick so you know I'm not a liar.
#
virsh list

# I'll just run converge really quickly on the vagrant nodes again (it shouldn't actually do anything since I've
# run it already and the idempotence test is passing).
#
molecule converge -s vagrant

#
# And yep, just as expected nothing changed. So let's run verify really quickly, and make sure everything
# is working ok...
# We'll do a shorter wait period since it should already be up
WAIT_SECONDS=30 molecule verify -s vagrant

# and it's broken! Good thing I ran verify and didn't just push this up
#
# <go to github repo and show build is failing>
# oh, whoops
#
# well let's see if we can figure out what's wrong, for whatever reason the minecraft server doesn't seem to be
# coming up.
#
# First let's check the verify.yml, see what it's up to. In our molecule.yml for the vagrant scenario
# we told it to just run the verify from the default scenario:
#
vim molecule/default/verify.yml

#
# So on the minecraft-client box, we're just running mcstatus (a little Python utility that speaks minecraft) to
# query the server, and we timed out on that very first task, which means that we were not able to contact
# the server.
#
# This is the perfect example to show off another one of molecule's super useful commands, `login`, which
# let's you open a shell in one of your targeted hosts. So let's pop on to the server really quickly and
# see if we can figure out what's wrong.
#
# Actually, before that why don't we take a quick look at the role
# to see where we might be able to start our investigation.
#
vim tasks/main.yml

#
# So we install dependencies, we create users and directories, blah blah blah, download minecraft,
# set up a few utilities as well, and then we create a minecraft systemd unit file and start the service!
#
# So that's a good place to start, let's hop into that host and see if the service is actually running
molecule login -s vagrant --host minecraft-server
# <type sudo systemctl status minecraft>
#
# Oh that's not good, it looks like the service did not successfully start. Ah, actually I can see the problem
# here, it's trying to run spigot.jar (which is what my earlier attempt at running a minecraft server used).
#
# Spigot is a lower weight, higher performance server implementation but I decided not to go with it for
# this demo because it makes more sense to just show regular minecraft so that I don't have to explain
# what spigot is and why I'm building it. If we look at the directory configured in the role, /opt/minecraft/server,
#
# < ls /opt/minecraft/server >
#
# we can see that there is no spigot.jar, but there is a server.jar
#
# So let's exit this host and look for where that spigot.jar is coming from
grep -r spigot

# Ok, so let's go to templates/minecraft.service.j2 and fix that up
vim templates/minecraft.service.j2

# So now we should be all good, let's run converge real quick so our changes are populated to the host
molecule converge -s vagrant

# We can see that the unit file was updated, and that the service has been started again,
# so let's run verify and see how that goes.
#
molecule verify -s vagrant

# All right awesome, looks like we fixed the issue, so let's go ahead and commit that and push it off, we can
# check to make sure the travis build is working again in a few minutes.
#
git status

git add templates/minecraft.service.j2

git commit -m "Fixing bugs during a talk"

git push origin master

# So we've verified it with the mcstatus utility, but let's just make sure for fun. first things first,
# let's find the IP of that vagrant machine.
molecule login -s vagrant --host minecraft-server

#
# Oh that was easy, it's right there! All right, let's just copy that and switch over to the minecraft launcher really quickly
#
# < copy IP, open minecraft launcher, add server, paste IP in >
#
# wow there it is, and check out that motd! It's the same one we set earlier.
#
# Yep that's minecraft.
#
# Let's do the same thing with the docker scenario really quickly, since that one should be broken too (they
# use the same role after all)
# So a quick converge, a quick verify...
molecule converge

molecule verify

# We don't need the -s on these commands because it's the default scenario
#
# Sweet, so I don't know if you remember from earlier, but we actually went ahead and forwarded the server
# port of the docker container, so it should be accessible on localhost
# vim molecule/default/molecule.yml
#
# <back to launcher, just punch in localhost>
#
# So here we are in a completely different server, with its own motd!
#
# Let's check that travis build too
#
# < hope travis build is done >

# 
# All right, I do have one other demo scenario to show you. This one is more related to what I do with
# molecule on a day-to-day basis. Let's back up a few directories and head to the kubernetes demo...
# 
cd ../..

cd kubernetes

tree

# All right, so we're running out of time here so I can't really give you any explanation of what Kubernetes
# or Operators are, or do an in-depth walkthrough of this role, but feel free to approach me any time this
# conference if you want to learn more. Basically, Operators sit in your Kubernetes cluster and react to
# changes in the cluster state, so when you create an Operator with Ansible, you've basically got reactive
# playbooks running in your cluster just waiting to fix things or create them when requested.
# I've got two scenarios here, one for running the role straight into kubernetes, and one that will
# make the operator image available to Kubernetes and then run a bunch of tests against it, where
# I've actually split those tests out into their own task files which makes it look more like your
# typical test directory set up
# I'm just going to run these real quick to prove to you that they work and hopefully pique your interest
molecule converge
molecule verify

molecule converge -s operator
molecule verify -s operator

# Don't forget to check travis

# This isn't really a talk about Kubernetes, and it would be easy to do a full breakout session on
# `What is Kubernetes`, so unfortunately I'm going to have to gloss over it a lot for this demo. Basically,
# it's a container orchestration system, you send YAML documents describing resources to the API, and it handles
# creating containers, setting up networking, etc, to make the cluster state match the state requested by
# the resource you sent. Wow that was high level, I'm really sorry to anyone who finds this hard to follow.
# 
# 
# We can see that this directory looks pretty different from the role-based molecule directory from before.
# 
# This is actually the directory structure for an Ansible based operator. What's an operator you might ask?
# 
# An operator is basically a very specific controller for Kubernetes, it watches a specific kind of resource
# (you can even define your own), and does something when those resources are created or modified. Writing
# an operator with Ansible means that you can have ansible playbooks that are reactive to changes in your cluster
# state, so as soon as something changes or breaks the playbook is triggered and responds.
# 
# so I have a role here, called minecraft-kubernetes. It installs minecraft on a kubernetes cluster, we can
# take a quick look.
vim roles/minecraft-kubernetes/tasks/main.yml

# 
# There's a few things for initial setup, then we start creating those yaml files I
# talked about using the k8s module, which just takes the yaml you provide and sends it to the cluster.
# 
# We can take a quick look at a few of these resources too..
vim roles/minecraft-kubernetes/templates/deployment.yaml.j2

# here's the deployment, which defines how I want Kubernetes to deploy my minecraft
# container. There's some metadata that all resources have,
# like name and namespace, then down here we're defining the actual container, we want some volumes
# mounted in there, we want some environment variables set, a few ports (sometimes). Again I'd love
# to dive more into this, feel free to ask me about it after this talk or just if you see me around.
# 
# Anyway, let's check out the molecule scenarios, because that's what this talk is actually about.
# 
# So I have two scenarios, default, and operator.
# 
vim molecule/default/molecule.yml

# Looking at the molecule.yml, you can see
# it's actually using the docker driver, which may strike you as odd, because Kubernetes runs containers,
# but it's actually this really cool project that spins up a whole Kubernetes cluster inside a docker
# container, which means there is almost no local configuration required to get a full cluster
# up and running, all we need to do is run this bsycorp/kind container and it all comes up. I've got
# a port forwarded, just to make it easy to connect with my local cli, and there's also a few more
# variables set than there were for previous scenarios. This one specifically sets the
# `ANSIBLE_ROLES_PATH`, which is generally required when you don't have your molecule directory
# sitting inside the role.
vim molecule/default/playbook.yml

# The default scenario is pretty similar to what we've
# seen before, it just runs the role and then runs some verification tasks.
# 
# Let's just run that one real quick before checking out the operator scenario.
# 
molecule converge

# So you can see I already stood this one up as well, but starting from scratch on a decent
# connection it would still only take 30 seconds to a minute generally. So it deployed,
# let's see what the verify tasks look like
# 
vim molecule/default/verify.yml

# So first it waits for the deployment to report ready (resources in Kubernetes can have a status,
# which tells you stuff about the state of the cluster). Once that's done it does some lookups for
# ports and such on the deployment, and attempts to discover the IP of the kubernetes cluster.
# 
# This task should be familiar, it's the same one we were using in the original demo, where it just
# queries the minecraft server status until it returns
# 
# And then finally you can see that there are some assertions, a critical part of any test suite.
# 
# So let's see if that verify passes
# 
molecule verify

# Sweet that's awesome! Again let me just prove that to you by heading to the minecraft launcher
# You can see that the port is not the default, even though minecraft thinks it's running on the
# default, because I let Kubernetes pick which port it actually wanted to open and it's just
# forwarding all the traffic on that port into port 25565 on the container.
# 
# < copy IP from where address is output >
# 
# yep still minecraft
# 
vim molecule/operator/molecule.yml

# The molecule.yml looks pretty much identical to the default scenario, because we're still
# just standing up a Kubernetes-in-docker container. Let's check out the prepare and converge playbooks though
# 
vim molecule/operator/prepare.yml

# So you can we import the default scenario's prepare.yml, which is just waiting for kubernetes to become
# available and setting up the kubeconfig. It's then creating a CustomResourceDefinition, which is the
# way that you define custom resources (my operator will watch resources of the type described here),
# and then some role-based access control, which just ensures my operator is allowed to do what it needs to
# do to deploy minecraft.
vim molecule/operator/playbook.yml

# In the playbook.yml things start to get a little spicy. Kubernetes needs to have the docker container
# for the operator locally or be able to pull it, and since I don't want to have to push to a registry
# every time I test something locally, I'm actually going to build the operator inside the
# container running the cluster (it doesn't have the docker python modules installed so I'm just using
# command, don't tell on me). Then all we do is create the operator deployment.
# 
molecule converge -s operator
# 
# Now we should have an operator running in the cluster!
# 
# 
vim molecule/operator/verify.yml

# 
# Now on to the verify. This one looks a little different, and that's because it's using a pattern I made
# up while writing this demo that I kind of like (the Ansible verifier is super new so experimentation is
# necessary to develop best practices). you can see that the verify.yml doesn't actually have any verification
# tasks in it, instead it's just importing task files, and it's all in a block/rescue that prints out
# debug information on error (this is super useful for CI). Let's take a look at what those task files look like.
# 

vim molecule/operator/tasks/test_working_defaults.yml
# 
# So this first set of tasks is just for testing that a minimal minecraft resource produces a working container
# 
# I'm using the k8s module to create a Minecraft instance that just has one argument in its spec (these arguments
# will be snake_cased and passed to the minecraft-kubernetes role). I'm using a new in 2.8 feature that allows
# us to wait for certain conditions, in this case I'm waiting for a successful run to be reported.
# 
# Then we check that an address is set in the status (a benefit of using operators is that you can add that
# sort of information to the resource), and then we import the test_reachable tasks file.
# 

# 
# We're then just running some tasks to make sure the server is reachable and reporting a status, and that the
# status isn't malformed in some way.
vim molecule/operator/tasks/test_reachable.yml

vim molecule/operator/tasks/test_eula_required.yml
# 
# This one just basically makes sure that the minecraft EULA must be explicitly agreed to in order for the
# server to start, so instead we import the test_not_reachable.yml tasks. 

vim molecule/operator/tasks/test_not_reachable.yml
# This one just sits and pings
# for a bit, making sure that the server isn't coming up.

# Now let's run our verify
molecule verify -s operator

# Sweet so everything works, but let's just make sure one last time. I'll just set this environment variable
# so that my cli knows about my kubernetes-in-docker cluster.
# 
export KUBECONFIG=/home/fabian/.cache/molecule/kubernetes/operator/.kubeconfig

kubectl get minecrafts

# So you can see we are now able to list
# minecrafts, which means Kubernetes knows about that resource,
# 
kubectl describe minecraft test-working-defaults
# 
# and if we describe our working minecraft
# we can see the address there. Let's just copy that into our minecraft launcher again.
# 
# And there you have it, 4 minecrafts deployed in different ways, all using molecule, and all of them except for the vagrant scenario work perfectly in a CI environment like travis.
