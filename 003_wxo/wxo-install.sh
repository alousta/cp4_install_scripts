#!/bin/bash

${CPDM_OC_LOGIN}
cpd-cli manage setup-appconnect \
--appconnect_ns=${PROJECT_IBM_APP_CONNECT} \
--cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
--release=${VERSION} \
--components=watsonx_orchestrate \
--file_storage_class=${STG_CLASS_FILE}

cpd-cli manage setup-wxo-assistant \
--cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
--create_assistants=true \
--user=${CPD_USERNAME} \
--auth_type=password

cpd-cli manage apply-olm \
--release=${VERSION} \
--cpd_operator_ns=${PROJECT_CPD_INST_OPERATORS} \
--components=watsonx_orchestrate

cpd-cli manage apply-cr \
--components=watsonx_orchestrate \
--release=${VERSION} \
--cpd_instance_ns=${PROJECT_CPD_INST_OPERANDS} \
--block_storage_class=${STG_CLASS_BLOCK} \
--file_storage_class=${STG_CLASS_FILE} \
--license_acceptance=true

