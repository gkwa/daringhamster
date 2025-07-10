#!/usr/bin/env bash

incus list --format csv | grep -q "^mythai," && incus rm --force mythai
incus list --format csv | grep -q "^u," && incus rm --force u

incus list --format csv | grep -q "^airflow-test," && incus rm --force airflow-test
incus launch 002-jolly-penguin airflow-test

incus exec airflow-test -- bash -c 'cd /opt/ringgem && until git fetch; do sleep 0.5s; done && git reset --hard @{upstream}'
incus exec airflow-test -- task --dir=/opt/ringgem install-uv-on-linux

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
