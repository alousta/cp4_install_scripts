#!/bin/bash
source cpi.env

${OC_LOGIN}

oc new-project ${NS}
oc project ${NS}

# https://www.ibm.com/docs/en/cloud-paks/cp-integration/2023.4?topic=images-adding-catalog-sources-cluster

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: ibm-operator-catalog
  namespace: openshift-marketplace
  annotations:
    olm.catalogImageTemplate: "icr.io/cpopen/ibm-operator-catalog:v{kube_major_version}.{kube_minor_version}"
spec:
  displayName: IBM Operator Catalog
  publisher: IBM
  sourceType: grpc
  image: icr.io/cpopen/ibm-operator-catalog:latest
  updateStrategy:
    registryPoll:
      interval: 45m
EOF
oc wait CatalogSource/ibm-operator-catalog -n openshift-marketplace --timeout=600s --for=jsonpath='{.status.connectionState.lastObservedState}'=READY


# https://www.ibm.com/docs/en/cloud-paks/cp-integration/2023.4?topic=operators-installing-by-using-cli

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: ibm-integration-operatorgroup
  namespace: ${NS}
  labels:
    backup.integration.ibm.com/component: operatorgroup        
spec:
  targetNamespaces:
  - ${NS}
EOF

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${PN_OPERATOR_PACKAGE_NAME}
  namespace: ${NS}
spec:
  channel: ${PN_OPERATOR_CHANNEL}
  name: ${PN_OPERATOR_PACKAGE_NAME}
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${ZEN_OPERATOR_PACKAGE_NAME}
  namespace: ${NS}
spec:
  name: ${ZEN_OPERATOR_PACKAGE_NAME}
  channel: ${ZEN_OPERATOR_CHANNEL}
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${APIC_OPERATOR_PACKAGE_NAME}
  namespace: ${NS}
spec:
  channel: ${APIC_OPERATOR_CHANNEL}
  name: ${APIC_OPERATOR_PACKAGE_NAME}
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF

cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: ${ACE_OPERATOR_PACKAGE_NAME}
  namespace: ${NS}
spec:
  channel: ${ACE_OPERATOR_CHANNEL}
  name: ${ACE_OPERATOR_PACKAGE_NAME}
  source: ibm-operator-catalog
  sourceNamespace: openshift-marketplace
EOF
oc wait commonservice/common-service -n ${NS} --timeout=600s --for=jsonpath='{.status.phase}'=Succeeded
oc wait clusterserviceversion/${PN_OPERATOR_PACKAGE_NAME}.v${PN_OPERATOR_VERSION} -n ${NS} --timeout=600s --for=jsonpath='{.status.phase}'=Succeeded
oc wait clusterserviceversion/${APIC_OPERATOR_PACKAGE_NAME}.v${APIC_OPERATOR_VERSION} -n ${NS} --timeout=600s --for=jsonpath='{.status.phase}'=Succeeded
oc wait clusterserviceversion/${ACE_OPERATOR_PACKAGE_NAME}.v${ACE_OPERATOR_VERSION} -n ${NS} --timeout=600s --for=jsonpath='{.status.phase}'=Succeeded

# https://www.ibm.com/docs/en/cloud-paks/cp-integration/2023.4?topic=ui-deploying-platform-by-using-cli

cat <<EOF | oc apply -f -
apiVersion: integration.ibm.com/v1beta1
kind: PlatformNavigator
metadata:
  name: integration
  namespace: ${NS}
  labels:
    backup.integration.ibm.com/component: platformnavigator        
spec:
  license:
    accept: true
    license: L-VTPK-22YZPK
  replicas: 1
  version: 2023.4.1
EOF

oc wait platformnavigator/integration -n ${NS} --timeout=3600s  --for=jsonpath='{.status.metadata.coreNamespace}'=${NS}

# Deploy APIC
# https://www.ibm.com/docs/en/cloud-paks/cp-integration/2023.4?topic=amd-deploying-all-api-management-subsystems-linux-x86-64-cli

cat <<EOF | oc apply -f -
kind: APIConnectCluster
apiVersion: apiconnect.ibm.com/v1beta1
metadata:
  name: api-management
  namespace: ${NS}
  annotations: 
    apiconnect-operator/backups-not-configured: "true"
spec:
  license:
    accept: true
    license: L-MMBZ-295QZQ
    metric: VIRTUAL_PROCESSOR_CORE
    use: production
  profile: n1xc7.m48
  version: 10.0.7.0
  storageClassName: ${STG_CLASS}
EOF

oc wait apiconnectcluster/api-management -n ${NS} --timeout=1800s --for=jsonpath='{.status.phase}'=Ready