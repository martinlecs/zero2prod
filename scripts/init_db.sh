#!/usr/bin/env bash
if [[ -n "${DEBUG}" ]]
then
    set -x
fi
set -eo pipefail

RETRIES=5

if [[ -z "${SKIP_SQLX}" ]]
then
    if ! [ -x "$(command -v sqlx)" ]; then
        echo >&2 "Error: sqlx is not installed."
        echo >&2 "Use:"
        echo >&2 "
        cargo install --version='~0.7' sqlx-cli \
        --no-default-features --features rustls,postgres"
        echo >&2 "to install it."
        exit 1
    fi
fi

DB_USER="${POSTGRES_USER:=postgres}"
DB_PASSWORD="${POSTGRES_PASSWORD:=password}"
DB_NAME="${POSTGRES_DB:=newsletter}"
DB_PORT="${POSTGRES_PORT:=5432}"
DB_HOST="${POSTGRES_HOST:=localhost}"

if [[ -z "${SKIP_DOCKER}" ]]
then
    docker run \
        -e POSTGRES_USER=${DB_USER} \
        -e POSTGRES_PASSWORD=${DB_PASSWORD} \
        -e POSTGRES_DB=${DB_NAME} \
        -p "${DB_PORT}":5432 \
        -d postgres \
        postgres -N 1000
fi

until </dev/tcp/${DB_HOST}/${DB_PORT} || [ $RETRIES -eq 0 ]; do
>&2 echo "Postgres is still unavailable - sleeping"
RETRIES=$((RETRIES-=1))
sleep 1
done
>&2 echo "Postgres is up and running on port ${DB_PORT}!"

DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
export DATABASE_URL

if [[ -n "${RUNNING_CI}" ]]
then
    # set this env var in GHA so that subsequent sqlx-related actions can connect to the DB
    echo "DATABASE_URL=postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}" >> "$GITHUB_ENV"
fi

if [[ -z "${SKIP_SQLX}" ]]
then
    sqlx database create
    sqlx migrate run
    >&2 echo "Postgres has been migrated, ready to go!"
fi
