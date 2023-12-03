#!/bin/bash

# shellcheck source="scripts/errors"
source scripts/errors

AWS_CLI=$(which aws)
REGION="us-west-2"
MANIFEST_FILE="manifest.json"
INSTANCES_FILE="output/aws_instances.json"
SG_FILE="output/sg.json"
KEY_PAIRS_NAME="ec2_keys"

function create_keys()
{
    # Crear un par de llaves con el nombre ec2_keys
    $AWS_CLI ec2 create-key-pair --key-name $KEY_PAIRS_NAME
}

function create_security_group() {
    # Crear un grupo de seguridad
    # Las IPs qie se van a usar son 172.31.0.0/24 y 203.0.113.25/32.
    # Estas IPs están definidas en la VPC vpc-0d1705a7ae91bf680
    # Si hay algún cambio en las IPs, entonces hay que revisar las VPCs disponibles,
    # ya que si no coinciden, entonces habrá un error al ejecutar la instancia de la VM.
    local GROUP_ID
    GROUP_ID=$($AWS_CLI ec2 create-security-group \
        --group-name carlos_SG_uswest2 \
        --description "Allow access EC2 instance via SSH, HTTP and HTTPS" \
        --vpc-id vpc-0d1705a7ae91bf680 \
        --output text \
        --region "$REGION")

    # Abrir los puertos 22, 80 y 443
    $AWS_CLI ec2 authorize-security-group-ingress \
    --region "$REGION" \
    --group-id "$GROUP_ID" \
    --ip-permissions \
        IpProtocol=tcp,FromPort=80,ToPort=80,IpRanges='[{CidrIp=0.0.0.0/0,Description="HTTP from anywhere"}]' \
        IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges='[{CidrIp=0.0.0.0/0,Description="HTTPS from anywhere"}]' \
        IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=172.31.0.0/24,Description="SSH from private network"}]' \
        IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges='[{CidrIp=203.0.113.25/32,Description="SSH from public IP"}]' \
    > $SG_FILE
}

function start_ec2_instance()
{
    local AMI_ID
    local ARTIFACT_ID
    local INSTANCE_ID
    local SG_ID
    local PUBLIC_IP

    if [ -f "$MANIFEST_FILE" ]; then
        ARTIFACT_ID=$(cat $MANIFEST_FILE | jq -r '.builds[] | select(.builder_type == "amazon-ebs") | .artifact_id')

        if [ -z "$ARTIFACT_ID" ]; then
            echo "No se encontró el ArtifactID para una imagen EBS. ¿Ya construiste la imagen de AWS?"
            exit $VARIABLE_NOT_FOUND
        fi

        AMI_ID=$(echo "$ARTIFACT_ID" | cut -d ":" -f 2)
    else
        echo "No se encontró el archivo manifest.json. ¿Ya construiste la imagen de AWS?"
        exit $FILE_NOT_FOUND
    fi

    if [ ! -f $SG_FILE ]; then
        echo "No existe el archivo $SG_FILE, no se puede determinar el ID del grupo de seguridad"
        exit $FILE_NOT_FOUND
    fi

    SG_ID=$(cat $SG_FILE | jq -r .SecurityGroupRules[0].GroupId)

    $AWS_CLI ec2 run-instances \
        --image-id "$AMI_ID" \
        --instance-type t2.micro \
        --region $REGION \
        --security-group-ids "$SG_ID" \
        --key-name $KEY_PAIRS_NAME \
        --count 1 \
        > $INSTANCES_FILE

    INSTANCE_ID=$(jq -r '.Instances[0].InstanceId' $INSTANCES_FILE)

    while true; do
        state=$($AWS_CLI ec2 describe-instances --instance-ids "$INSTANCE_ID" --query 'Reservations[*].Instances[*].[State.Name]' --output text)
        if [ "$state" == "running" ]; then
            echo "La instancia está en estado $state."
            break
        fi
        echo "La instancia está en estado $state. Esperando..."
        sleep 5
    done

    PUBLIC_IP=$($AWS_CLI ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[*].Instances[*].PublicIpAddress' \
        --output text)

    echo "Haciendo una pausa de 5 segundos antes de hacer una prueba local ..."
    sleep 5

    local_test $PUBLIC_IP
}

function terminate_ec2_instance()
{
    if [ ! -f $INSTANCES_FILE ]; then
        echo "No existe el archivo $INSTANCES_FILE"
        exit $FILE_NOT_FOUND
    fi

    INSTANCE_ID=$(jq -r '.Instances[0].InstanceId' $INSTANCES_FILE)
    $AWS_CLI ec2 terminate-instances \
        --instance-ids \
        --region $REGION
}

if [ -z "$MAIN_SCRIPT" ] || [ "$MAIN_SCRIPT" != "ops" ]; then
    echo "ERROR: Este script no puede ser invocado directamente"
    exit $RUNTIME_ERROR
fi

if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    echo "No existe la variable de entorno AWS_ACCESS_KEY_ID."
    exit $VARIABLE_NOT_FOUND
fi

if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "No existe la variable de entorno AWS_SECRET_ACCESS_KEY."
    exit $VARIABLE_NOT_FOUND
fi