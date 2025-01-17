#!/bin/bash

set -euo pipefail

github_token=${GITHUB_TOKEN:-}
repository=${REPOSITORY:-}
runner=${RUNNER_NAME:-$(uuidgen)}
version=${RUNNER_VERSION:-"2.299.1"}
type=${RUNNER_RUN_TYPE:-"service"}
work_dir=${RUNNER_WORK_DIR:-"_work"}
deploy_dir=${RUNNER_DEPLOY_DIR:-"$HOME/actions-runner"}
group=${RUNNER_GROUP:-"default"}
labels=${RUNNER_LABELS:-"macOS"}
cpu=${CPU_TYPE:-"x64"}
ephemeral=${EPHEMERAL:-"false"}

while [[ "$#" -gt 0 ]]
do
case $1 in
    -t|--github_token)
    github_token=$2
    ;;
    -r|--repository)
    repository=$2
    ;;
    -n|--runner_name)
    agent=$2
    ;;
    -v|--runner_version)
    version=$2
    ;;
    -tp|--runner_run_type)
    type=$2
    ;;
    -w|--runner_work_dir)
    work_dir=$2
    ;;
    -d|--runner_deploy_dir)
    deploy_dir=$2
    ;;
    -g|--runner_group)
    group=$2
    ;;
    -l|--runner_labels)
    labels=$2
    ;;
    -c|--cpu)
    cpu=$2
    ;;
    -e|--ephemeral)
    ephemeral=$2
    ;;
esac
shift
done

mkdir -p $deploy_dir

curl -o $deploy_dir/actions-runner.tar.gz -L https://github.com/actions/runner/releases/download/v$version/actions-runner-osx-$cpu-$version.tar.gz
cd $deploy_dir && tar xzf $deploy_dir/actions-runner.tar.gz

config_command="$deploy_dir/config.sh --url $repository --token $github_token --name $agent --work $work_dir --runnergroup $group --labels $labels"

if [[ $ephemeral == "true" ]]; then
    config_command="$config_command --ephemeral"
elif [[ $ephemeral == "false" ]]; then
    :
else
    echo "Invalid input for the ephemeral tag."
    exit 1
fi

eval $config_command

if [[ "$type" == "service" ]]; then
    echo "Installing service"
    $deploy_dir/svc.sh install

    if pgrep -qx Finder; then
        echo "Starting service"
        $deploy_dir/svc.sh start
    else
        echo "Cannot start service. No UI session found. Make sure the user is logged in. To enable automatic login, see https://support.apple.com/en-us/HT201476."
        exit -1
    fi
elif [[ "$type" == "command" ]]; then
    echo "Running agent"
    nohup $deploy_dir/run.sh &>/dev/null &
fi
