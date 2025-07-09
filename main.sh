#!/usr/bin/env bash

incus list --format csv | grep -q "^mythai," && incus rm --force mythai
incus list --format csv | grep -q "^u," && incus rm --force u

incus list --format csv | grep -q "^airflow-test," && incus rm --force airflow-test
incus launch 002-jolly-penguin airflow-test

incus exec airflow-test -- bash -c 'cd /opt/ringgem && until git fetch; do sleep 0.5s; done && git reset --hard @{upstream}'
incus exec airflow-test -- task --dir=/opt/ringgem install-uv-on-linux

cat >install.sh <<'EOF'
#!/usr/bin/env bash
AIRFLOW_VERSION="$(uv tool run --from 'apache-airflow[celery]' --python python3 -- python -c 'import airflow; print(airflow.__version__)')"
echo AIRFLOW_VERSION=$AIRFLOW_VERSION
PYTHON_VERSION=3.12

type -a deactivate >/dev/null 2>&1 && deactivate
rm -rf .venv
rm -rf airflow/

export PATH="$HOME/.local/bin:$PATH"
uv venv

# shellcheck disable=SC1091
source .venv/bin/activate

CONSTRAINT_URL="https://raw.githubusercontent.com/apache/airflow/constraints-${AIRFLOW_VERSION}/constraints-${PYTHON_VERSION}.txt"
uv pip install "apache-airflow[celery]==${AIRFLOW_VERSION}" --constraint "${CONSTRAINT_URL}"
uv pip install apache-airflow-providers-fab
uv pip install pandas

airflow version

cat >airflow.cfg <<EOF2
[core]
auth_manager = airflow.providers.fab.auth_manager.fab_auth_manager.FabAuthManager
EOF2

airflow config get-value core auth_manager
airflow db migrate
airflow providers list | grep fab

echo "Check /root/airflow/simple_auth_manager_passwords.json.generated for auto-generated passwords"
#airflow api-server --port 8080
EOF

incus file push install.sh airflow-test/root/install.sh
incus exec airflow-test -- bash --login -e /root/install.sh
incus exec airflow-test -- rm -rf /root/.venv /root/airflow.cfg /root/airflow/
incus stop airflow-test

incus image list --format csv | grep -q '^my-airflow-test-image,' && incus image rm my-airflow-test-image
incus publish airflow-test --alias my-airflow-test-image

# now repeatedly test using my-airflow-test-image that has cached files
incus list --format csv | grep -q "^airflow-test," && incus rm --force airflow-test
incus launch my-airflow-test-image airflow-test

incus file push install.sh airflow-test/root/install.sh
incus exec airflow-test -- bash --login -e /root/install.sh

incus exec airflow-test -- bash -e -c 'source .venv/bin/activate && airflow api-server --port 8080'
