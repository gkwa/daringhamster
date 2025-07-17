#!/usr/bin/env bash
set -e

PYTHON_VERSION=3.12
AIRFLOW_VERSION="$(uv tool run --from 'apache-airflow[celery]' --python python3 -- python -c 'import airflow; print(airflow.__version__)')"
echo "AIRFLOW_VERSION=$AIRFLOW_VERSION"

# Clean up
type -a deactivate >/dev/null 2>&1 && deactivate
rm -rf .venv
rm -rf airflow/

# Create environment and install dependencies from pyproject.toml
export PATH="$HOME/.local/bin:$PATH"
CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
uv sync --constraint "${CONSTRAINT_URL}"

# Activate the environment
source .venv/bin/activate

# Configure Airflow
cat >airflow.cfg <<EOF
[core]
auth_manager = airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager
EOF

# Initialize
airflow version
airflow config get-value core auth_manager
airflow db migrate
airflow providers list | grep fab

echo "Setup complete! Check /root/airflow/simple_auth_manager_passwords.json.generated for auto-generated passwords"
echo "To start: airflow api-server --port 8080"
