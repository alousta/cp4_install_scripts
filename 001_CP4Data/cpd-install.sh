#!/bin/bash
source ./cpd.env
#cp install-config.yaml cpd-cli-workspace/olm-utils-workspace/work/install-config.yaml

# https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=cluster-manually-creating-projects-namespaces-shared-components

#${OC_LOGIN} --token=${OCP_TOKEN}
#run line 2, 9 and 16 everytime token change
${OC_LOGIN} 
oc new-project ${PROJECT_CERT_MANAGER}
oc new-project ${PROJECT_LICENSE_SERVICE}
oc new-project ${PROJECT_SCHEDULING_SERVICE}

# https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=cluster-installing-shared-components

${CPDM_OC_LOGIN}
cpd-cli manage apply-cluster-components \
--release=${VERSION} \
--license_acceptance=true \
--cert_manager_ns=${PROJECT_CERT_MANAGER} \
--licensing_ns=${PROJECT_LICENSE_SERVICE}
cpd-cli manage apply-scheduler \
--release=${VERSION} \
--license_acceptance=true \
--scheduler_ns=${PROJECT_SCHEDULING_SERVICE}
cp install-config.yaml cpd-cli-workspace/olm-utils-workspace/work/install-config.yaml
# https://access.redhat.com/documentation/id-id/red_hat_openshift_data_foundation/4.9/html/deploying_openshift_data_foundation_using_bare_metal_infrastructure/deploy-standalone-multicloud-object-gateway

OC_VERSION=$(oc version | grep "Server Version" | awk '{print $3}' | awk -F '.' '{ print $1"."$2 }')
oc create ns openshift-storage
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: openshift-storage-operatorgroup
  namespace: openshift-storage
spec:
  targetNamespaces:
    - openshift-storage
  upgradeStrategy: Default
EOF
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: odf-operator
  namespace: openshift-storage
spec:
  channel: stable-${OC_VERSION}
  installPlanApproval: Automatic
  name: odf-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
ODF_CSV=$(oc get subs/odf-operator -n openshift-storage -o=jsonpath='{.status.installedCSV}')
oc wait csv/${ODF_CSV} -n openshift-storage --timeout=3600s --for=jsonpath='{.status.phase}'=Succeeded
cat << EOF | oc apply -f -
apiVersion: odf.openshift.io/v1alpha1
kind: StorageSystem
metadata:
  name: ocs-storagecluster-storagesystem
  namespace: openshift-storage
spec:
  kind: storagecluster.ocs.openshift.io/v1
  name: ocs-storagecluster
  namespace: openshift-storage
EOF
cat << EOF | oc apply -f -
apiVersion: ocs.openshift.io/v1
kind: StorageCluster
metadata:
  name: ocs-storagecluster
  namespace: openshift-storage
spec:
  arbiter: {}
  encryption:
    kms: {}
  externalStorage: {}
  managedResources:
    cephObjectStoreUsers: {}
    cephCluster: {}
    cephBlockPools: {}
    cephNonResilientPools: {}
    cephObjectStores: {}
    cephFilesystems: {}
    cephRBDMirror: {}
    cephToolbox: {}
    cephDashboard: {}
    cephConfig: {}
  mirroring: {}
  multiCloudGateway:
    dbStorageClassName: ${STG_CLASS_BLOCK}
    reconcileStrategy: standalone
EOF
oc wait pod/noobaa-db-pg-0 --timeout=3600s -n openshift-storage --for=jsonpath='{.status.phase}'=Running

# https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=software-installing-red-hat-openshift-serverless-knative-eventing

cpd-cli manage authorize-instance-topology \
--release=${VERSION} \
--cpd_operator_ns=ibm-knative-events \
--cpd_instance_ns=knative-eventing
cpd-cli manage setup-instance-topology \
--release=${VERSION} \
--cpd_operator_ns=ibm-knative-events \
--cpd_instance_ns=knative-eventing \
--license_acceptance=true

# https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=software-installing-app-connect

# ${OC_LOGIN}
# tar -xf ibm-appconnect-${AC_CASE_VERSION}.tgz
# oc patch \
# --filename=ibm-appconnect/inventory/ibmAppconnect/files/op-olm/catalog_source.yaml \
# --type=merge \
# -o yaml \
# --patch="{\"metadata\":{\"namespace\":\"${PROJECT_IBM_APP_CONNECT}\"}}" \
# --dry-run=client \
# | oc apply -n ${PROJECT_IBM_APP_CONNECT} -f -
# cat <<EOF | oc apply -f -
#   apiVersion: operators.coreos.com/v1
#   kind: OperatorGroup
#   metadata:
#     name: appconnect-og
#     namespace: ${PROJECT_IBM_APP_CONNECT}
#   spec:
#     targetNamespaces:
#     - ${PROJECT_IBM_APP_CONNECT}
#     upgradeStrategy: Default
# EOF
# cat <<EOF | oc apply -f -
#   apiVersion: operators.coreos.com/v1alpha1
#   kind: Subscription
#   metadata:
#     name: ibm-appconnect-operator
#     namespace: ${PROJECT_IBM_APP_CONNECT}
#   spec:
#     channel: ${AC_CHANNEL_VERSION}
#     config:
#       env:
#       - name: ACECC_ENABLE_PUBLIC_API
#         value: "true"
#     installPlanApproval: Automatic
#     name: ibm-appconnect
#     source: appconnect-operator-catalogsource
#     sourceNamespace: ${PROJECT_IBM_APP_CONNECT}
# EOF
# oc wait csv \
# --namespace="${APROJECT_IBM_APP_CONNECT}" \
# --lables=operators.coreos.com/ibm-appconnect.${PROJECT_IBM_APP_CONNECT}='' \
# --for='jsonpath={.status.phase}'=Succeeded

# https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=data-manually-creating-projects-namespaces

oc new-project ${PROJECT_CPD_INST_OPERATORS}
oc new-project ${PROJECT_CPD_INST_OPERANDS}

# https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=data-applying-required-permissions-projects-namespaces

cpd-cli manage authorize-instance-topology \
--cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
--cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
--additional_ns=${PROJECT_CPD_INSTANCE_TETHERED}

# https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=data-authorizing-instance-administrator

oc adm policy add-role-to-user admin ${INSTANCE_ADMIN} \
--namespace=${PROJECT_CPD_INST_OPERATORS} \
--rolebinding-name="cpd-instance-admin-rbac"
oc adm policy add-role-to-user admin ${INSTANCE_ADMIN} \
--namespace=${PROJECT_CPD_INST_OPERANDS} \
--rolebinding-name="cpd-instance-admin-rbac"
oc apply -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: cpd-instance-admin-apply-olm
  namespace: ${PROJECT_CPD_INST_OPERATORS}
rules:
- apiGroups:
  - operators.coreos.com
  resources:
  - operatorgroups
  verbs:
  - create
  - get
  - list
  - patch
  - update
- apiGroups:
  - operators.coreos.com
  resources:
  - catalogsources
  verbs:
  - create
  - get
  - list
EOF
oc adm policy add-role-to-user cpd-instance-admin-apply-olm ${INSTANCE_ADMIN} \
--namespace=${PROJECT_CPD_INST_OPERATORS} \
--role-namespace=${PROJECT_CPD_INST_OPERATORS} \
--rolebinding-name="cpd-instance-admin-apply-olm-rbac"

# https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=piicpd-creating-secrets-services-that-use-multicloud-object-gateway

export NOOBAA_ACCOUNT_CREDENTIALS_SECRET=noobaa-admin
export NOOBAA_ACCOUNT_CERTIFICATE_SECRET=noobaa-s3-serving-cert
cpd-cli manage setup-mcg \
--components=watson_assistant \
--cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
--noobaa_account_secret=${NOOBAA_ACCOUNT_CREDENTIALS_SECRET} \
--noobaa_cert_secret=${NOOBAA_ACCOUNT_CERTIFICATE_SECRET}


# https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=data-installing-cloud-pak-foundational-services

cpd-cli manage setup-instance-topology \
--release=${VERSION} \
--cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
--cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
--license_acceptance=true \
--additional_ns=${PROJECT_CPD_INSTANCE_TETHERED} \
--block_storage_class=${STG_CLASS_BLOCK}

# https://www.ibm.com/docs/en/cloud-paks/cp-data/4.8.x?topic=data-installing-cloud-pak

cpd-cli manage get-license \
--release=${VERSION} \
--license-type=EE
cpd-cli manage apply-olm \
--release=${VERSION} \
--cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
--components=${COMPONENTS}
cpd-cli manage apply-cr \
--release=${VERSION} \
--cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
--components=${COMPONENTS} \
--block_storage_class=${STG_CLASS_BLOCK} \
--file_storage_class=${STG_CLASS_FILE} \
--license_acceptance=true \
--param-file=/tmp/work/install-options.yaml
cpd-cli manage get-cr-status \
--cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS}
cpd-cli manage get-cpd-instance-details \
--cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
--get_admin_initial_credentials=true


