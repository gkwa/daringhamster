#!/usr/bin/env bash
set -e

PYTHON_VERSION=3.12

AIRFLOW_VERSION="$(uv tool run --python=${PYTHON_VERSION} --from apache-airflow -- python -c 'import airflow; print(airflow.__version__)')"
echo AIRFLOW_VERSION=$AIRFLOW_VERSION

# Clean up
type -a deactivate >/dev/null 2>&1 && deactivate
rm -rf .venv
rm -rf airflow/

uv venv --python=${PYTHON_VERSION}

# Activate the environment
# shellcheck disable=SC1091
source .venv/bin/activate

# Configure Airflow
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
uv pip install "apache-airflow[celery]==${AIRFLOW_VERSION}" graphviz pandas --constraint "${CONSTRAINT_URL}"

cat >airflow.cfg <<EOF
[core]
auth_manager = airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager
EOF

# Initialize
airflow version
airflow config get-value core auth_manager
airflow db migrate
airflow providers list

echo "Setup complete! Check /root/airflow/simple_auth_manager_passwords.json.generated for auto-generated passwords"
echo "To start: airflow api-server --port 8080"
