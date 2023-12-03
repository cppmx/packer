#!/bin/bash

# shellcheck source="scripts/errors"
source scripts/errors

RESOURCES_GROUP_NAME="tareas"
INSTANCES_FILE="output/azure_instances.json"
PORTS_FILE="output/azure_ports.json"
MANIFEST_FILE="manifest.json"
AZURE_CLI=$(which az)

function login_azure()
{
    if $AZURE_CLI account show &>/dev/null; then
        echo "Ya estás logueado a Azure"
    else
        echo "Por favor logueate primero a Azure"
        # Hacer loguin en la cuenta principal
        $AZURE_CLI login
    fi
}

function prepare_azure()
{
    # Crear un grupo de recursos llamado tareas
    $AZURE_CLI group create -n $RESOURCES_GROUP_NAME -l eastus 

    # Obtener el ID de la suscripción
    $AZURE_CLI account show --query "{ subscription_id: id }" | jq -r .subscription_id

    # Crear un servicio principal con el comando az ad sp create-for-rbac
    # La salida de este comando nos dará las credenciales que se usarán con packer
    # Ejemplo de la salida:
    # {
    #     "client_id": "f5b6a5cf-fbdf-4a9f-b3b8-3c2cd00225a4",
    #     "client_secret": "0e760437-bf34-4aad-9f8d-870be799c55d",
    #     "tenant_id": "72f988bf-86f1-41af-91ab-2d7cd011db47"
    # }
    $AZURE_CLI ad sp create-for-rbac \
        --role Contributor \
        --scopes "/subscriptions/$AZURE_SUBSCRIPTION_ID" \
        --query "{ client_id: appId, client_secret: password, tenant_id: tenant }"

    echo "Con estos valores crea las variables de ambiente AZURE_CLIENT_ID, AZURE_CLIENT_SECRET, y AZURE_TENANT_ID."
}

function start_vm_instance()
{
    local AZURE_IMAGE
    local PUBLIC_IP

    # Extraer el nombre de la imagen del archivo manifest.json
    AZURE_IMAGE=$(cat $MANIFEST_FILE | \
    jq -r '.builds[] | select(.builder_type == "azure-arm") | .artifact_id | split("/") | last')

    # Crear una instancia usando la nueva imagen
    $AZURE_CLI vm create \
        --resource-group "$RESOURCES_GROUP_NAME" \
        --name testVM \
        --image "$AZURE_IMAGE" \
        --admin-username azureuser \
        --generate-ssh-keys > $INSTANCES_FILE

    # Abrir el puerto 80
    $AZURE_CLI vm open-port \
        --resource-group "$RESOURCES_GROUP_NAME" \
        --name testVM --port 80 > $PORTS_FILE

    PUBLIC_IP=$(jq -r .publicIpAddress $INSTANCES_FILE)

    echo "Haciendo una pausa de 5 segundos antes de hacer una prueba local ..."
    sleep 5

    local_test $PUBLIC_IP
}

function login_azure_via_ssh()
{
    # Conectarse vía SSK a la VM
    $AZURE_CLI ssh vm \
        --resource-group "$RESOURCES_GROUP_NAME" \
        --vm-name testVM \
        --subscription "$AZURE_SUBSCRIPTION_ID"
}

function delete_azure_vm()
{
    $AZURE_CLI vm delete --name "testVM" --resource-group "$RESOURCES_GROUP_NAME" --yes --no-wait

    if [ $? -ne 0 ]; then
        echor "Hubo un error al intentar borrar la VM testVM."
        exit $RUNTIME_ERROR
    fi

    rm $INSTANCES_FILE
    rm $PORTS_FILE
}

if [ -z "$MAIN_SCRIPT" ] || [ "$MAIN_SCRIPT" != "ops" ]; then
    echo "ERROR: Este script no puede ser invocado directamente"
    exit $RUNTIME_ERROR
fi

if [ -z "$AZURE_CLI" ]; then
    echo "No se encontró el CLI de Azure, por favor instalalo primero y después vuelve a ejecutar este script"
    exit $VARIABLE_NOT_FOUND
fi

# Verificar si la variable de ambiente AZURE_SUBSCRIPTION_ID ya está definida
if [ -z "$AZURE_SUBSCRIPTION_ID" ]; then
    echo "La variable de ambiente AZURE_SUBSCRIPTION_ID no está definida."

    # Buscar en el archivo ~/.bashrc si la variable está definida
    if grep -q "export AZURE_SUBSCRIPTION_ID=" ~/.bashrc; then
        echo "La variable AZURE_SUBSCRIPTION_ID está definida en ~/.bashrc."

        # Actualizar el valor en ~/.bashrc
        sed -i 's/^export AZURE_SUBSCRIPTION_ID=.*/export AZURE_SUBSCRIPTION_ID=$(az account show --query "{ subscription_id: id }" | jq -r .subscription_id)/' ~/.bashrc

        echo "Se ha actualizado el valor de AZURE_SUBSCRIPTION_ID en ~/.bashrc."
    else
        # Si no está definida en ~/.bashrc, agregar la variable
        echo 'export AZURE_SUBSCRIPTION_ID=$(az account show --query "{ subscription_id: id }" | jq -r .subscription_id)' >> ~/.bashrc

        echo "Se ha agregado la variable AZURE_SUBSCRIPTION_ID en ~/.bashrc."
    fi

    echo "Recarga el archivo ~/.bashrc y vuelve a intentarlo"
fi

