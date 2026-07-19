SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

KUBERNETES_VERSION := 1.36
SSH_OPTIONS := -i private_key -o UserKnownHostsFile=known_hosts

.PHONY: setup add-worker add-control-plane update-kubeconfig configure-ssh ssh-into remove-node terminate-instance destroy

setup:
	@if [ -f terraform.tfstate ] && jq -e '.resources | length > 0' terraform.tfstate >/dev/null; then
		echo; echo "❌ The cluster has already been set up." >&2
		exit 1
	fi

	jq -n '{
		instances: {
			controlplane1: { node_role: "control-plane" },
			worker1:       { node_role: "worker" }
		}
	}' > terraform.tfvars.json

	echo; echo "🏗️  Provisioning infrastructure..."
	terraform init && terraform apply

	prepare_controlplane1() {
		$(call wait_instance_ready,controlplane1)
		$(call discover_host_key,controlplane1)
		$(call configure_host,controlplane1)
	}

	prepare_worker1() {
		$(call wait_instance_ready,worker1)
		$(call discover_host_key,worker1)
		$(call configure_host,worker1)
	}

	prepare_controlplane1 & prepare_worker1 & wait

	$(call initialize_control_plane)
	$(call update_kubeconfig)
	$(call install_cni_plugin)
	$(call join_node,worker,worker1)

	echo; echo "Cluster set up ✅"

ssh-into:
	@$(call validate_name,$(NAME))
	@$(call ssh_into_host,$(NAME))

add-node:
	@$(call validate_name,$(NAME))
	@$(call validate_role,$(or $(ROLE),worker))
	@$(call provision_instance,$(or $(ROLE),worker),$(NAME))
	@$(call wait_instance_ready,$(NAME))
	@$(call discover_host_key,$(NAME))
	@$(call configure_host,$(NAME))
	@$(call join_node,$(or $(ROLE),worker),$(NAME))
	@echo; echo "Node $(NAME) added as $(ROLE) ✅"

remove-node:
	@$(call validate_name,$(NAME))
	@$(call remove_node,$(NAME))
	@$(call terminate_instance,$(NAME))
	@echo; echo "Node $(NAME) removed ✅"

terminate-instance:
	@$(call validate_name,$(NAME))
	@$(call terminate_instance,$(NAME))
	@echo; echo "Instance $(NAME) terminated ✅"

destroy:
	@echo; echo "💥 Destroying cluster..."
	@terraform destroy
	@rm -f known_hosts terraform.tfvars.*
	@echo; echo "Cluster destroyed ✅"

define validate_name
	name="$(1)"
	if [ -z "$$name" ]; then
		echo; echo "❌ Missing NAME." >&2
		echo "Usage: make $@ NAME=<name>" >&2
		exit 1
	fi
endef

define validate_role
	role="$(1)"
	if [[ "$$role" != "worker" && "$$role" != "control-plane" ]]; then
		echo "❌ Invalid role: $$role" >&2
		echo "Usage: make $@ [worker|control-plane]" >&2
		exit 1
	fi
endef

define provision_instance
	node_role="$(1)"
	instance_name="$(2)"

	echo; echo "🏗️  Provisioning instance $$instance_name..."

	if "$$(terraform output -json inventory | jq -e --arg name "$$instance_name" 'has($$name)')"; then
		echo; echo "❌ An instance named '$$instance_name' has already been provisioned." >&2
		exit 1
	fi

	cat terraform.tfvars.json > terraform.tfvars.backup.json
	jq --arg instance_name "$$instance_name" --arg node_role "$$node_role" '.instances[$$instance_name] = { "node_role": $$node_role }' terraform.tfvars.backup.json > terraform.tfvars.json
	rm terraform.tfvars.backup.json

	terraform apply
endef

define terminate_instance
	instance_name="$(1)"

	echo; echo "💀 Terminating instance $$instance_name..."

	if "$$(terraform output -json inventory | jq -e --arg name "$$instance_name" 'has($$name) | not')"; then
		echo; echo "❌ No instance named '$$instance_name' has been provisioned." >&2
		exit 1
	fi

	cat terraform.tfvars.json > terraform.tfvars.backup.json
	jq --arg instance_name "$$instance_name" 'del(.instances[$$instance_name])' terraform.tfvars.backup.json > terraform.tfvars.json
	rm terraform.tfvars.backup.json

	terraform apply
endef

define wait_instance_ready
	instance_name="$(1)"

	echo; echo "⏳ Waiting for instance $$instance_name to be ready..."

	instance_id="$$(terraform output -json inventory | jq -r --arg name "$$instance_name" '.[$$name].instance_id')"

	aws --no-cli-pager ec2 wait instance-running --instance-ids $$instance_id
	aws --no-cli-pager ec2 wait instance-status-ok --instance-ids $$instance_id
endef

define discover_host_key
	host_name="$(1)"

	echo; echo "📡 Discovering $$host_name host key..."

	host_public_ip="$$(terraform output -json inventory | jq -r --arg name "$$host_name" '.[$$name].public_ip')"

	if [ ! -f known_hosts ]; then
		touch known_hosts
		chmod 644 known_hosts
	fi

	ssh-keyscan $$host_public_ip >> known_hosts
endef

define ssh_into_host
	host_name="$(1)"

	echo; echo "📡 SSH-ing into $$host_name..."

	host_public_ip="$$(terraform output -json inventory | jq -r --arg name "$$host_name" '.[$$name].public_ip')"

	ssh $(SSH_OPTIONS) ubuntu@$$host_public_ip
endef

define configure_host
	host_name="$(1)"

	echo; echo "🛠️  Configuring host $$host_name..."

	host_public_ip="$$(terraform output -json inventory | jq -r --arg name "$$host_name" '.[$$name].public_ip')"

	ssh $(SSH_OPTIONS) ubuntu@$$host_public_ip bash <<EOF

		set -euxo pipefail

		# Disable swap
		sudo swapoff -a
		sudo sed -ri '/\sswap\s/s/^([^#])/# \1/' /etc/fstab

		# Load kernel modules
		cat <<EOT | sudo tee /etc/modules-load.d/k8s.conf
			overlay
			br_netfilter
		EOT
		sudo modprobe overlay
		sudo modprobe br_netfilter

		# Load kernel parameters
		cat <<EOT | sudo tee /etc/sysctl.d/k8s.conf
			net.bridge.bridge-nf-call-iptables  = 1
			net.bridge.bridge-nf-call-ip6tables = 1
			net.ipv4.ip_forward                 = 1
		EOT
		sudo sysctl --system

		# Add Docker APT repository and signing key
		cat <<EOT | sudo tee /etc/apt/sources.list.d/docker.list
			deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \$$(lsb_release -cs) stable
		EOT
		sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
		sudo chmod 0644 /etc/apt/keyrings/docker.asc

		# Add Kubernetes APT repository and signing key
		cat <<EOT | sudo tee /etc/apt/sources.list.d/kubernetes.list
			deb [signed-by=/etc/apt/keyrings/kubernetes.asc] https://pkgs.k8s.io/core:/stable:/v$(KUBERNETES_VERSION)/deb/ /
		EOT
		sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v$(KUBERNETES_VERSION)/deb/Release.key -o /etc/apt/keyrings/kubernetes.asc
		sudo chmod 0644 /etc/apt/keyrings/kubernetes.asc

		# Update APT package index
		sudo apt update

		# Install containerd
		sudo apt install -y containerd.io

		# Configure containerd
		containerd config default | sed "s/SystemdCgroup = false/SystemdCgroup = true/" | sudo tee /etc/containerd/config.toml > /dev/null

		# Restart containerd
		sudo systemctl restart containerd

		# Install Kubernetes packages
		sudo apt install -y kubelet kubeadm kubectl

		# Pin Kubernetes package versions
		sudo apt-mark hold kubelet kubeadm kubectl

		# Enable and start kubelet
		sudo systemctl enable --now kubelet
	EOF
endef

define initialize_control_plane

	echo; echo "☸️  Initializing control-plane..."

	admin_node_name="controlplane1"
	admin_node_public_ip="$$(terraform output -json inventory | jq -r --arg name "$$admin_node_name" '.[$$name].public_ip')"

	ssh $(SSH_OPTIONS) ubuntu@$$admin_node_public_ip bash <<EOF

		set -euxo pipefail

		sudo kubeadm init \
			--node-name $$admin_node_name \
			--pod-network-cidr=10.244.0.0/16 \
			--apiserver-cert-extra-sans=$$admin_node_public_ip \
			--control-plane-endpoint=$$admin_node_public_ip:6443
	EOF
endef

define update_kubeconfig

	echo; echo "☸️  Updating kubeconfig..."

	admin_node_name="controlplane1"
	admin_node_public_ip="$$(terraform output -json inventory | jq -r --arg name "$$admin_node_name" '.[$$name].public_ip')"

	admin_conf="$$(
		ssh $(SSH_OPTIONS) ubuntu@$$admin_node_public_ip \
			"sudo cat /etc/kubernetes/admin.conf" \
		| yq -o=json
	)"

	echo "$$admin_conf" | jq -r '.clusters[0].cluster["certificate-authority-data"]' | base64 --decode > ca.crt
	kubectl config set-cluster kubeadm-lab --server "https://$$admin_node_public_ip:6443" --certificate-authority ca.crt --embed-certs=true
	rm ca.crt

	echo "$$admin_conf" | jq -r '.users[0].user["client-certificate-data"]' | base64 --decode > admin.crt
	echo "$$admin_conf" | jq -r '.users[0].user["client-key-data"]' | base64 --decode > admin.key
	kubectl config set-credentials kubeadm-lab:admin --client-key admin.key --client-certificate admin.crt --embed-certs=true
	rm admin.crt admin.key

	kubectl config set-context kubeadm-lab:admin --cluster=kubeadm-lab --user=kubeadm-lab:admin
	kubectl config use-context kubeadm-lab:admin
endef

define install_cni_plugin

	echo; echo "☸️  Installing CNI plugin..."

	admin_node_name="controlplane1"
	admin_node_public_ip="$$(terraform output -json inventory | jq -r --arg name "$$admin_node_name" '.[$$name].public_ip')"

	ssh $(SSH_OPTIONS) ubuntu@$$admin_node_public_ip bash <<EOF

		set -euxo pipefail

		sudo kubectl apply \
			--kubeconfig=/etc/kubernetes/admin.conf \
			--filename https://github.com/flannel-io/flannel/releases/download/v0.28.5/kube-flannel.yml
	EOF
endef

define join_node
	join_node_role="$(1)"
	join_node_name="$(2)"

	echo; echo "☸️  Joining $$join_node_role node $$join_node_name..."

	admin_node_name="controlplane1"
	admin_node_public_ip="$$(terraform output -json inventory | jq -r --arg name "$$admin_node_name" '.[$$name].public_ip')"

	if [ "$$join_node_role" = "control-plane" ]; then
		kubeadm_join_command="$$(
			ssh $(SSH_OPTIONS) ubuntu@$$admin_node_public_ip bash <<EOF
				join_command="\$$(sudo kubeadm token create --print-join-command)"
				certificate_key="\$$(sudo kubeadm init phase upload-certs --upload-certs | tail -n1)"
				echo "\$$join_command --node-name $$join_node_name --control-plane --certificate-key \$$certificate_key"
			EOF
		)"
	else
		kubeadm_join_command="$$(
			ssh $(SSH_OPTIONS) ubuntu@$$admin_node_public_ip bash <<EOF
				join_command="\$$(sudo kubeadm token create --print-join-command)"
				echo "\$$join_command --node-name $$join_node_name"
			EOF
		)"
	fi

	join_node_public_ip="$$(terraform output -json inventory | jq -r --arg name "$$join_node_name" '.[$$name].public_ip')"

	ssh $(SSH_OPTIONS) ubuntu@$$join_node_public_ip bash <<EOF
		set -euxo pipefail
		sudo $$kubeadm_join_command
	EOF
endef

define remove_node
	remove_node_name="$(1)"

	echo; echo "🔥 Removing node $$remove_node_name from cluster..."

	remove_node_role="$$(terraform output -json inventory | jq -r --arg name "$$remove_node_name" '.[$$name].node_role')"

	admin_node_name="controlplane1"
	admin_node_public_ip="$$(terraform output -json inventory | jq -r --arg name "$$admin_node_name" '.[$$name].public_ip')"

	ssh $(SSH_OPTIONS) ubuntu@$$admin_node_public_ip bash <<EOF

		set -euo pipefail

		if [ "$$remove_node_role" = "control-plane" ]; then

			etcd_pod_name="etcd-$$admin_node_name"

			# Check if node is an etcd member
			etcd_member_id="\$$(
				sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf --namespace kube-system \
					exec \$$etcd_pod_name -- \
						etcdctl \
							--write-out=json \
							--endpoints=https://127.0.0.1:2379 \
							--cacert=/etc/kubernetes/pki/etcd/ca.crt \
							--cert=/etc/kubernetes/pki/etcd/server.crt \
							--key=/etc/kubernetes/pki/etcd/server.key \
							member list \
							| jq -r '.members[] | select(.name == "$$remove_node_name") | .ID'
			)"

			if [ -n "\$$etcd_member_id" ]; then

				etcd_member_id_hex="\$$(printf '%x\n' "\$$etcd_member_id")"

				# Remove etcd member
				sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf --namespace kube-system \
					exec \$$etcd_pod_name -- \
						etcdctl \
							--endpoints=https://127.0.0.1:2379 \
							--cacert=/etc/kubernetes/pki/etcd/ca.crt \
							--cert=/etc/kubernetes/pki/etcd/server.crt \
							--key=/etc/kubernetes/pki/etcd/server.key \
							member remove \$$etcd_member_id_hex
			fi
		fi

		# Drain node
		sudo kubectl \
			--kubeconfig=/etc/kubernetes/admin.conf \
			drain "$$remove_node_name" --ignore-daemonsets

		# Delete node
		sudo kubectl \
			--kubeconfig=/etc/kubernetes/admin.conf \
			delete node "$$remove_node_name"
	EOF
endef
