# OpenShift Installation Scripts for CP4D and CP4I

Pre-requisites:

- A running OpenShift 4.14 cluster with both Block and File storage
- Capacity must be larger than <to be determined>
- Install `oc` cli from [here](https://mirror.openshift.com/pub/openshift-v4/clients/)
- Install `cpd-cli` from [here](https://github.com/IBM/cpd-cli/releases)
- Running latest `podman` or `docker`

Installation steps:

1. Installing CP4D and Watson Assistant 
    - modify `001_CP4Data/cpd.env` to reflect your environments
    - run `cpd-install.sh`

2. Installing CP4I with API Connect and App Connect Enterprise
    - modify `002_Cp4Int/cpi.env`
    - run `cpi-install.sh`

3. Installing Watsonx Orchastrate
    - modify `003_wxo/wxo.env`
    - run `exo-install.sh`