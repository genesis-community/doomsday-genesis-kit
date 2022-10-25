doomsday Genesis Kit
=================

Quick Start
-----------

To use it, you don't even need to clone this repository! Just run
the following (using Genesis v2):

```
# create a doomsday-deployments repo using the latest version of the doomsday kit
genesis init --kit doomsday

# create a doomsday-deployments repo using v1.0.0 of the doomsday kit
genesis init --kit doomsday/1.0.0

# create a my-doomsday-configs repo using the latest version of the doomsday kit
genesis init --kit doomsday -d my-doomsday-configs
```

Once created, refer to the deployment repository README for information on
provisioning and deploying new environments.

Features
-------

`ocfp` - Open Cloud Foundry Platform - using the reference architecture.

Params
------

See the Doomsday boshrelease repo for params options.

Cloud Config
------------

If using `ocfp` Cloud Config is taken care of.

