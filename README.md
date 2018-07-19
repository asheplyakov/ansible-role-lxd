[![Build Status](https://travis-ci.org/Nani-o/ansible-role-lxd.svg?branch=master)](https://travis-ci.org/Nani-o/ansible-role-lxd)

lxd
===

This role aims to manage [LXD](https://linuxcontainers.org/lxd/), a daemon wrapping LXC with a REST API for managing vm like containers.

Using it you can **installs** and **configure** LXD. You can also **deploys** containers with a python post install to enable ansible.

This role use snap for installing LXD, **it will remove** any **package manager installation** of LXD in order for the LXD connection plugin to works. 

As of now there is 3 snap channels for installing LXD : 

snap channel | LXD version |
------------ | ----------- |
default      | 3.2         |
3.0          | 3.0.1       |
2.0          | 2.0.11      |

This role is tested against the stable branch of each of this channels.

Compatibility
-------------

This role should works on any platform where snap is available. Tests case will be added for other distros, for now :

  - Ubuntu 14.04 (not tested, can't run snap in trusty lxd containers)
  - Ubuntu 16.04
  - Ubuntu 18.04

Role Variables
--------------

Here the variables for using this role, there is some other variables that you can find in the [defaults/main.yml](./defaults/main.yml), but you should not need them.

###### lxd_snap_channel

This variable controls the channels used for installing LXD.

By default this variable is set to stable to installs the latest stable LXD release from the default channel.

```YAML
lxd_snap_channel: 2.0/edge
```

###### lxd_profiles

This is a list of LXD [profiles](https://lxd.readthedocs.io/en/latest/profiles/) that you want to setup. It uses the ansible [lxd_profile](https://docs.ansible.com/ansible/devel/modules/lxd_profile_module.html) module for installing them.

By default this var will contains a default profile that use the default storage and the lxdbr0 bridge.

```YAML
lxd_profiles:
  - name: "default"
    description: "Default lxd profile"
    config:
      environment.http_proxy: ""
      user.network_mode: ""
    devices:
      eth0:
        nictype: "bridged"
        parent: "lxdbr0"
        type: "nic"
      root:
        path: "/"
        pool: "default"
        type: "disk"
```

###### lxd_storages

As of now this var does not exists, since there is no module for managing LXD [storages](https://lxd.readthedocs.io/en/latest/storage/). I will implement it as soon as I can adapt one of the existing modules.

For now a default storage pool is created in **/var/snap/lxd/common/lxd/storage-pools/default** for version above 2.20 and for version before this we use **lxd init --auto**, so ... I don't really know what happens in this case since storage pools was not existing in this version, but it works !

###### lxd_networks

**This only works for LXD > 2.20**

This is a list of LXD [networks](https://lxd.readthedocs.io/en/latest/networks/) bridges managed by LXD you want to create. Since there is no module for this, I adapted the existing lxd_profile module that I named ... [lxd_network](./library/lxd_network.py). It is included in this role, waiting for the [PR](https://github.com/ansible/ansible/pull/31428) to gain some visibility (and me taking some time to work on it).

By default this variable contains a single default lxdbr0 bridge with ipv4 and nat support.

```YAML
lxd_networks:
  - name: lxdbr0
    description: "Default lxd network"
    config:
      ipv4.address: "192.168.56.1/24"
      ipv4.nat: "true"
      ipv6.address: "none"
```

###### lxd_bridge

**This only works for LXD < 2.20**

Before introducing networks objects in LXD, there was a service called lxd-bridge in charge of managing a single bridge using a configuration [file](./templates/lxd-bridge.j2). This variable allows to template the configuration file for enabling the lxd-bridge service.

By default it will create an lxdbr0 bridge with ipv4 and nat support.

```YAML
lxd_bridge:
  ipv4:
    address: "192.168.56.1/24"
    nat: "true"
  ipv6:
    address: "fd26:9b5f:cdb1:7756::1/64"
    nat: "true"
```

###### lxd_containers

This is a list of LXD [containers](https://lxd.readthedocs.io/en/latest/containers/) that will be deployed. It uses the ansible [lxd_container](https://docs.ansible.com/ansible/devel/modules/lxd_container_module.html) module for deploying them.

There is no default value for this var.

```YAML
lxd_containers:
  - name: container-full-options
    type: image                                # default
    mode: pull                                 # default
    server: https://images.linuxcontainers.org # default
    protocol: simplestreams                    # default
    alias: ubuntu/18.04/amd64
    profiles:                                  # default to ['default']
      - default
      - other_profile
    devices:                                   # default to {}
      eth1:
        nictype: "bridged"
        parent: "lxdbr0"
        type: "nic"

  - name: container-shorter-options
    alias: centos/7/amd64
```

Tags
----

Here the tags that you can use to control the execution of this role :

###### lxd

Execute the whole role.

###### lxd_install

It will remove any package installation of LXD, and install LXD alongside with snapd if it isn't already installed.

```
tasks:
  lxd : Remove lxd package install  TAGS: [lxd, lxd_install]
  lxd : Make sure snapd is installed        TAGS: [lxd, lxd_install]
  lxd : Install lxd via snap        TAGS: [lxd, lxd_install]
```

###### lxd_config

It will configure different aspects of LXD (profiles, networks and storages) with some differences according to the LXD version.

```
tasks:
  lxd : Get lxd version     TAGS: [lxd, lxd_config]
  lxd : Wait for socket file        TAGS: [lxd, lxd_config]
  lxd : Configuration for version 2.20 or above     TAGS: [lxd, lxd_config]
  lxd : Configuration for version before 2.20       TAGS: [lxd, lxd_config]
  lxd : Create LXD profiles TAGS: [lxd, lxd_config]
```

###### lxd_deploy

It will deploy LXD containers and check that python and some obvious packages are installed.

```
tasks:
  lxd : Create containers   TAGS: [lxd, lxd_deploy]
  lxd : Add containers to dynamic inventory TAGS: [lxd, lxd_deploy]
  lxd : Installing python if absent TAGS: [lxd, lxd_deploy]
```

Example Playbook
----------------

Here the simplest way to use this role installing latest stable and deploying a container :

```YAML
---
- hosts: localhost
  vars:
    lxd_containers:
      - name: c1
        alias: centos/7/amd64
  roles:
    - lxd
...
```

License
-------

MIT

Author Information
------------------

Sofiane MEDJKOUNE
