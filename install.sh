#!/usr/bin/env bash
AIRFLOW_VERSION="$(uv tool run --from 'apache-airflow[celery]' --python python3 -- python -c 'import airflow; print(airflow.__version__)')"
echo AIRFLOW_VERSION=$AIRFLOW_VERSION
PYTHON_VERSION=3.12

type -a deactivate >/dev/null 2>&1 && deactivate
rm -rf .venv
rm -rf airflow/

export PATH="$HOME/.local/bin:$PATH"
uv venv --python python${PYTHON_VERSION}

# shellcheck disable=SC1091
source .venv/bin/activate

CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
uv pip install "apache-airflow[celery]==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"
uv pip install apache-airflow-providers-fab
uv pip install pandas
uv pip install graphviz

airflow version

cat >airflow.cfg <<EOF
[core]
auth_manager = airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager
EOF

airflow config get-value core auth_manager
airflow db migrate
airflow providers list | grep fab

echo "Check /root/airflow/simple_auth_manager_passwords.json.generated for auto-generated passwords"
#airflow api-server --port 8080
