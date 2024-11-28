#!/bin/bash
# 
# Source: https://github.com/mrts/docker-postgresql-multiple-databases
# Author: Mart Sõmermaa (https://github.com/mrts)
# contributor: Jens Peter Secher (https://github.com/jpsecher)
# contributor: Emanuele Scarsella (https://github.com/emanuele-scarsella)
# License: MIT
#

set -e
set -u

# Create a user and a database, if they don't already exist
# Arguments:
#   $1 - Database name
function create_user_and_database() {
	local database=$1
	local user=$(get_user_for_database $database)
	local password=$(get_password_for_database $database)
	if user_exists $user; then
		echo "User '$user' already exists, skipping"
	else
		echo "Creating user '$user' ${password:+(with password)}"
		create_user $user $password
	fi
	if database_exists $database; then
		echo "Database '$database' already exists, skipping"
	else
		echo "Creating database '$database' and granting all privileges to user '$user'"
		create_database $database $user
	fi
}

# Create a PostgreSQL user
# Arguments:
#   $1 - User name
#   $2 - User password (optional)
function create_user() {
	local user=$1
	local password=$2
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
		CREATE USER "$user" ${password:+WITH PASSWORD '$password'};
	EOSQL
}

# Create a PostgreSQL database and assign ownership
# Arguments:
#   $1 - Database name
#   $2 - User name
function create_database() {
	local database=$1
	local user=$2
	psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
		CREATE DATABASE "$database" WITH OWNER "$user";
		GRANT ALL PRIVILEGES ON DATABASE "$database" TO "$user";
	EOSQL
}

# Check if a PostgreSQL user exists
# Arguments:
#   $1 - User name
# Returns:
#   0 if user exists, 1 otherwise
function user_exists() {
	local user=$1
	local result
	result=$(psql -t -v ON_ERROR_STOP=1 \
		--username "$POSTGRES_USER" \
		--dbname "$POSTGRES_DB" \
		-c "SELECT 1 FROM pg_roles WHERE rolname = '$user';")
	if [[ "$result" =~ 1 ]]; then
		return 0
	fi
	return 1
}

# Check if a PostgreSQL database exists
# Arguments:
#   $1 - Database name
# Returns:
#   0 if database exists, 1 otherwise
function database_exists() {
	local database="$1"
	if psql -lqt --username "$POSTGRES_USER" | cut -d \| -f 1 | grep -qw "$database"; then
		return 0
	else
		return 1
	fi
}

# Retrieve the user for a given database
# Arguments:
#   $1 - Database name
# Returns:
#   User name derived from environment variables or defaults to database name
function get_user_for_database() {
    local database=$1
    local user_var="POSTGRES_USER_${database^^}"
    echo "${!user_var:-$database}"
}

# Retrieve the password for a given database
# Arguments:
#   $1 - Database name
# Returns:
#   Password derived from environment variables or empty if not set
function get_password_for_database() {
    local database=$1
    local password_var="POSTGRES_PASSWORD_${database^^}"
    echo "${!password_var:-}"
}

# Main script logic: Create multiple databases if specified in the environment variable
if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
	echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
	for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
		create_user_and_database $db
	done
	echo "Multiple databases created"
fi
