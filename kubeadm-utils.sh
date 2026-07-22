ADMIN_NODE="controlplane1"

prepare-node() {
    local node_name="$1"
    local kubernetes_version="1.36"

    $(ssh-into $node_name) bash <<EOF

        set -euo pipefail

        echo "[prepare-node::$node_name] Disabling swap..."; (
            set -x
            sudo swapoff -a
            sudo sed -ri '/\sswap\s/s/^([^#])/# \1/' /etc/fstab
        )

        echo "[prepare-node::$node_name] Loading kernel modules..."; (
            set -x
            sudo touch /etc/modules-load.d/k8s.conf
            echo "overlay"      | sudo tee -a /etc/modules-load.d/k8s.conf
            echo "br_netfilter" | sudo tee -a /etc/modules-load.d/k8s.conf
            sudo modprobe overlay
            sudo modprobe br_netfilter
        )

        echo "[prepare-node::$node_name] Loading kernel parameters..."; (
            set -x
            sudo touch /etc/sysctl.d/k8s.conf
            echo "net.bridge.bridge-nf-call-iptables  = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
            echo "net.bridge.bridge-nf-call-ip6tables = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
            echo "net.ipv4.ip_forward                 = 1" | sudo tee -a /etc/sysctl.d/k8s.conf
            sudo sysctl --system
        )

        echo "[prepare-node::$node_name] Adding Docker APT repository and signing key..."; (
            set -x
            echo "deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list
            sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
            sudo chmod 0644 /etc/apt/keyrings/docker.asc
        )

        echo "[prepare-node::$node_name] Adding Kubernetes APT repository and signing key..."; (
            set -x
            echo "deb [signed-by=/etc/apt/keyrings/kubernetes.asc] https://pkgs.k8s.io/core:/stable:/v$kubernetes_version/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
            sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v$kubernetes_version/deb/Release.key -o /etc/apt/keyrings/kubernetes.asc
            sudo chmod 0644 /etc/apt/keyrings/kubernetes.asc
        )

        echo "[prepare-node::$node_name] Updating package index..."; (
            set -x
            sudo apt update
        )

        echo "[prepare-node::$node_name] Installing packages..."; (
            set -x
            sudo apt install -y containerd.io kubelet kubeadm kubectl
        )

        echo "[prepare-node::$node_name] Pinning Kubernetes package versions..."; (
            set -x
            sudo apt-mark hold kubelet kubeadm kubectl
        )

        echo "[prepare-node::$node_name] Configuring containerd..."; (
            set -x
            containerd config default | sed "s/SystemdCgroup = false/SystemdCgroup = true/" | sudo tee /etc/containerd/config.toml > /dev/null
        )

        echo "[prepare-node::$node_name] Restarting containerd..."; (
            set -x
            sudo systemctl restart containerd
        )

        echo "[prepare-node::$node_name] Enabling kubelet..."; (
            set -x
            sudo systemctl enable kubelet
        )
EOF
}

initialize-control-plane() {
    echo "[initialize-control-plane::$ADMIN_NODE] Initializing control-plane..."
    $(ssh-into $ADMIN_NODE) bash <<EOF

        set -euxo pipefail

        sudo kubeadm init \
            --node-name $ADMIN_NODE \
            --pod-network-cidr=10.244.0.0/16 \
            --apiserver-cert-extra-sans=$(public-ip $ADMIN_NODE) \
            --control-plane-endpoint=$(public-ip $ADMIN_NODE):6443
EOF
}

install-addons() {
    local kubectl="sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf"

    $(ssh-into $ADMIN_NODE) bash <<EOF

        set -euo pipefail

        echo "[install-addons::$ADMIN_NODE] Installing CNI Plugin..."; (
            set -x
            $kubectl apply -f https://github.com/flannel-io/flannel/releases/download/v0.28.5/kube-flannel.yml
        )

        echo "[install-addons::$ADMIN_NODE] Installing Metrics Server..."; (
            set -x
            $kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.9.0/components.yaml

            # kubelet's self-signed serving certificate has no IP SANs, so metrics-server
            # can't verify it; skip verification since this is a lab, not production.
            $kubectl -n kube-system patch deployment metrics-server --type=json \
                -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'
        )

        echo "[install-addons::$ADMIN_NODE] Installing Ingress Controller..."; (
            set -x
            $kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.15.1/deploy/static/provider/cloud/deploy.yaml
        )
EOF
}

join-node() {
    local node_name="$1"
    local role="$2"

    echo "[join-node::$node_name] Creating bootstrap token and obtain the join command..."
    local kubeadm_join_command="$($(ssh-into $ADMIN_NODE) "sudo kubeadm token create --print-join-command")"

    echo "[join-node::$node_name] Specifying the node name in the join command..."
    kubeadm_join_command="$kubeadm_join_command --node-name $node_name"

    if [ "$role" = "control-plane" ]; then

        echo "[join-node::$node_name] Adding flag to the join command indicating that this is a control-plane node..."
        kubeadm_join_command="$kubeadm_join_command --control-plane"

        echo "[join-node::$node_name] Uploading control-plane certificates to the cluster and obtain the certificate key..."
        local certificate_key="$($(ssh-into $ADMIN_NODE) "sudo kubeadm init phase upload-certs --upload-certs" | tail -n1)"

        echo "[join-node::$node_name] Adding certificate key to the join command..."
        kubeadm_join_command="$kubeadm_join_command --certificate-key $certificate_key"
    fi

    echo "[join-node::$node_name] Initializing the new node and joining it to the cluster..."
    $(ssh-into $node_name) "set -x; sudo $kubeadm_join_command"
}

leave-node() {
    local node_name="$1"
    local force="$2"

    local kubectl="sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf"

    echo "[leave-node::$node_name] Obtaining node details..."
    local node_details="$($(ssh-into $ADMIN_NODE) "$kubectl get node \"$node_name\" -o json")"

    echo "[leave-node::$node_name] Checking if node is a control-plane..."
    local is_control_plane="$(echo "$node_details" | jq '.metadata.labels | has("node-role.kubernetes.io/control-plane")')"

    echo "[leave-node::$node_name] Is control-plane: $is_control_plane"

    if $is_control_plane; then

        local etcdctl="$kubectl --namespace kube-system \
            exec etcd-$ADMIN_NODE -- \
                etcdctl \
                    --write-out=json \
                    --endpoints=https://127.0.0.1:2379 \
                    --cacert=/etc/kubernetes/pki/etcd/ca.crt \
                    --cert=/etc/kubernetes/pki/etcd/server.crt \
                    --key=/etc/kubernetes/pki/etcd/server.key"

        echo "[leave-node::$node_name] Obtaining etcd member ID..."
        local etcd_member_id="$($(ssh-into $ADMIN_NODE) "$etcdctl member list | jq -r --arg name \"$node_name\" '.members[] | select(.name == \$name) | .ID'")"

        if [ -n "$etcd_member_id" ]; then
            echo "[leave-node::$node_name] etcd member ID: $etcd_member_id"

            etcd_member_id_hex="$(printf '%x\n' $etcd_member_id)"

            echo "[leave-node::$node_name] Removing etcd membership..."
            if ! $(ssh-into $ADMIN_NODE) "set -x; $etcdctl member remove $etcd_member_id_hex" && ! $force; then
                exit 1
            fi
        else
            echo "[leave-node::$node_name] Not an etcd member."
        fi
    fi

    kubectl_drain_command="$kubectl drain \"$node_name\" --ignore-daemonsets"

    if $force; then
        kubectl_drain_command="$kubectl_drain_command --force --delete-emptydir-data --disable-eviction --timeout=60s"
    fi

    echo "[leave-node::$node_name] Draining node..."
    if ! $(ssh-into $ADMIN_NODE) "set -x; $kubectl_drain_command" && ! $force; then
        exit 1
    fi

    echo "[leave-node::$node_name] Deleting node..."
    $(ssh-into $ADMIN_NODE) "set -x; $kubectl delete node \"$node_name\""
}

update-kubeconfig() {
    echo "[update-kubeconfig] Pulling admin kubeconfig..."
    local admin_conf="$($(ssh-into $ADMIN_NODE) "sudo cat /etc/kubernetes/admin.conf" | yq -o=json)"

    echo "[update-kubeconfig] Extracting CA certificate and setting kubectl cluster..."
    echo "$admin_conf" | jq -r '.clusters[0].cluster["certificate-authority-data"]' | base64 --decode > ca.crt
    kubectl config set-cluster kubeadm-lab --server "https://$(public-ip $ADMIN_NODE):6443" --certificate-authority ca.crt --embed-certs=true
    rm ca.crt

    echo "[update-kubeconfig] Extracting client certificate and key, and setting kubectl user..."
    echo "$admin_conf" | jq -r '.users[0].user["client-certificate-data"]' | base64 --decode > admin.crt
    echo "$admin_conf" | jq -r '.users[0].user["client-key-data"]' | base64 --decode > admin.key
    kubectl config set-credentials kubeadm-lab:admin --client-key admin.key --client-certificate admin.crt --embed-certs=true
    rm admin.crt admin.key

    echo "[update-kubeconfig] Setting kubectl context..."
    kubectl config set-context kubeadm-lab:admin --cluster=kubeadm-lab --user=kubeadm-lab:admin
    kubectl config use-context kubeadm-lab:admin
}
