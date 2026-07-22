provision-infrastructure() {
    if [ -f terraform.tfstate ] && jq -e '.resources | length > 0' terraform.tfstate >/dev/null; then
        echo
        echo "[provision-infrastructure] ❌ Infrastructure has already been provisioned." >&2
        exit 1
    fi

    echo "[provision-infrastructure] Provisioning infrastructure..."

    echo "$1" > terraform.tfvars.json
    terraform init
    _terraform_apply_and_refresh_inventory

    local name
    for name in $(jq -r 'keys[]' inventory.json); do
        _wait_instance_ready "$name"
        _scan_host_key "$name"
    done
}

launch-instance() {
    local name="$1"
    local node_role="$2"

    echo "[launch-instance::$name] Launching instance..."

    local tfvars="$(jq --arg name "$name" --arg node_role "$node_role" '.instances[$name] = { node_role: $node_role }' terraform.tfvars.json)"
    echo "$tfvars" > terraform.tfvars.json
    _terraform_apply_and_refresh_inventory

    _wait_instance_ready "$name"
    _scan_host_key "$name"
}

terminate-instance() {
    local name="$1"

    echo "[terminate-instance::$name] Terminating instance..."

    local tfvars="$(jq --arg name "$name" 'del(.instances[$name])' terraform.tfvars.json)"
    echo "$tfvars" > terraform.tfvars.json
    _terraform_apply_and_refresh_inventory

    _remove_scanned_host_key "$name"
}

start-instance() {
    local name="$1"

    echo "[start-instance::$name] Starting instance..."

    aws --no-cli-pager ec2 start-instances --instance-ids "$(_instance_id "$name")" >/dev/null
    _wait_instance_ready "$name"

    _terraform_apply_and_refresh_inventory

    _scan_host_key "$name"
}

stop-instance() {
    local name="$1"

    echo "[stop-instance::$name] Stopping instance..."

    _remove_scanned_host_key "$name"

    aws --no-cli-pager ec2 stop-instances --instance-ids "$(_instance_id "$name")" >/dev/null
    _wait_instance_stopped "$name"

    _terraform_apply_and_refresh_inventory
}

destroy-infrastructure() {
    echo "[destroy-infrastructure] Destroying infrastructure..."

    terraform destroy -auto-approve
    rm -f inventory.json known_hosts.json known_hosts terraform.tfvars.json
}

public-ip() {
    local name="$1"
    jq -r --arg name "$name" '.[$name].public_ip' inventory.json
}

ssh-into() {
    local name="$1"
    echo "ssh -i private_key -o UserKnownHostsFile=known_hosts ubuntu@$(public-ip $name)"
}

_instance_id() {
    local name="$1"
    jq -r --arg name "$name" '.[$name].instance_id' inventory.json
}

_terraform_apply_and_refresh_inventory() {
    terraform apply -auto-approve
    terraform output -json inventory | jq > inventory.json
}

_wait_instance_ready() {
    local name="$1"

    echo "[wait-instance-ready::$name] Waiting for instance to be ready..."

    local instance_id="$(_instance_id "$name")"

    while true; do
        local state
        local instance_status
        local system_status
        read -r state instance_status system_status <<< "$(
            aws --no-cli-pager ec2 describe-instance-status \
                --instance-ids "$instance_id" \
                --include-all-instances \
                --query 'InstanceStatuses[0].[InstanceState.Name, InstanceStatus.Status, SystemStatus.Status]' \
                --output text
        )"

        if [ "$state" = "running" ] && [ "$instance_status" = "ok" ] && [ "$system_status" = "ok" ]; then
            break
        fi

        local status
        [ "$system_status" = "ok" ]   || status="$system_status"
        [ "$instance_status" = "ok" ] || status="$instance_status"
        [ "$state" = "running" ]      || status="$state"

        echo "[wait-instance-ready::$name] Instance is $status..."
        sleep 5
    done

    echo "[wait-instance-ready::$name] Instance is ready."
}

_wait_instance_stopped() {
    local name="$1"

    echo "[wait-instance-stopped::$name] Waiting for instance to be stopped..."

    local instance_id="$(_instance_id "$name")"

    while true; do
        local state="$(
            aws --no-cli-pager ec2 describe-instance-status \
                --instance-ids "$instance_id" \
                --include-all-instances \
                --query 'InstanceStatuses[0].InstanceState.Name' \
                --output text
        )"

        [ "$state" = "stopped" ] && break

        echo "[wait-instance-stopped::$name] Instance is $state..."
        sleep 5
    done

    echo "[wait-instance-stopped::$name] Instance stopped."
}

_scan_host_key() {
    local name="$1"

    echo "[scan-host-key::$name] Scanning host key..."

    local keyscan="$(ssh-keyscan "$(public-ip "$name")")"

    if [ ! -f known_hosts.json ]; then
        echo "{}" > known_hosts.json
    fi

    local known_hosts_json="$(jq --arg name "$name" --arg keyscan "$keyscan" '.[$name] = $keyscan' known_hosts.json)"
    echo "$known_hosts_json" > known_hosts.json
    _update_known_hosts_file
}

_remove_scanned_host_key() {
    local name="$1"

    local known_hosts_json="$(jq --arg name "$name" 'del(.[$name])' known_hosts.json)"
    echo "$known_hosts_json" > known_hosts.json
    _update_known_hosts_file
}

_update_known_hosts_file() {
    : > known_hosts
    chmod 644 known_hosts

    local name
    for name in $(jq -r 'keys[]' known_hosts.json); do
        jq -r --arg name "$name" '.[$name]' known_hosts.json >> known_hosts
    done
}
