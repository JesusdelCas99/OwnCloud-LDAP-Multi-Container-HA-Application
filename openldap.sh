#!/bin/bash

# Check if Docker Compose is installed
if ! command -v docker-compose &> /dev/null; then
    echo "Docker Compose is not installed. Please install Docker Compose before running this script."
    exit 1
fi

# Start Docker Compose services in detached mode
sudo docker-compose up -d

# Wait until all services are up and running
while [[ $(sudo docker-compose ps --services | wc -l) -ne $(sudo docker-compose ps --services --filter "status=running" | wc -l) ]]; do
    sleep 1
done

# Directory containing LDIF files
HOST_LDIF_DIR="./data/ldif"

# Directory in the container where LDIF files will be copied
CONTAINER_LDIF_DIR="/tmp"

# Copy LDIF files from host to container
sudo docker cp "$HOST_LDIF_DIR" openldap:"$CONTAINER_LDIF_DIR"

# LDAP administrator credentials
LDAP_ADMIN_DN="cn=admin,dc=miejemploowncloudldap,dc=com"
LDAP_ADMIN_PW="admin"

# Iterate over LDIF files
for ldif_file in "$HOST_LDIF_DIR"/*.ldif; do
    echo "Processing LDIF file: $ldif_file"

    # Execute ldapadd command and capture output
    output=$(sudo docker exec openldap sh -c "ldapadd -x -D '$LDAP_ADMIN_DN' -w '$LDAP_ADMIN_PW' -c -f '$CONTAINER_LDIF_DIR/ldif/$(basename "$ldif_file")'" 2>&1)
    exit_code=$?

    # Check if the exit code is 68 (Already exists)
    if [ $exit_code -eq 68 ]; then
        echo "The entry already exists in the LDAP directory"
    elif [ $exit_code -eq 0 ]; then
        echo "The entry was added successfully"
    else
        echo "An error occurred while executing ldapadd. Exit code: $exit_code"
        echo "Command output: $output"
    fi
done

