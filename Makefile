SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

KUBERNETES_VERSION := 1.36
SSH_OPTIONS := -i private_key -o UserKnownHostsFile=known_hosts

.PHONY: setup-cluster add-worker add-control-plane update-kubeconfig configure-ssh ssh-into-host remove-node terminate-instance destroy-cluster

setup-cluster:
	@$(call check_if_can_setup_cluster)

	echo; echo "🏗️  Provisioning infrastructure..."
	$(call reset_tfvars)
	$(call add_instance_to_tfvars,control-plane,controlplane1)
	$(call add_instance_to_tfvars,worker,worker1)
	$(call terraform_apply)

	echo; echo "🔑 Configuring SSH..."
	$(call configure_private_key)
	$(call configure_known_hosts)

	echo; echo "🛠️  Preparing hosts..."
	$(call prepare_host,controlplane1)
	$(call prepare_host,worker1)

	echo; echo "🚀 Bootstrapping cluster..."
	$(call kubeadm_init,controlplane1)
	$(call kubeadm_join,worker,worker1)

	echo; echo "⚙️  Updating kubeconfig..."
	$(call update_kubeconfig)

	echo; echo "✅ Cluster set up."

add-control-plane:
	@$(call check_if_name_is_valid,$(NAME))
	$(call check_if_name_is_available,$(NAME))

	echo; echo "🏗️  Provisioning instance $(NAME)..."
	$(call add_instance_to_tfvars,control-plane,$(NAME))
	$(call terraform_apply)

	echo; echo "🔑 Updating SSH configuration..."
	$(call configure_known_hosts)

	echo; echo "🛠️  Preparing host $(NAME)..."
	$(call prepare_host,$(NAME))

	echo; echo "🚀 Joining control-plane node $(NAME)..."
	$(call kubeadm_join,control-plane,$(NAME))

	echo; echo "✅ Control-plane node $(NAME) added."

add-worker:
	@$(call check_if_name_is_valid,$(NAME))
	$(call check_if_name_is_available,$(NAME))

	echo; echo "🏗️  Provisioning instance $(NAME)..."
	$(call add_instance_to_tfvars,worker,$(NAME))
	$(call terraform_apply)

	echo; echo "🔑 Updating SSH configuration..."
	$(call configure_known_hosts)

	echo; echo "🛠️  Preparing host $(NAME)..."
	$(call prepare_host,$(NAME))

	echo; echo "🚀 Joining worker node $(NAME)..."
	$(call kubeadm_join,worker,$(NAME))

	echo; echo "✅ Worker node $(NAME) added."

update-kubeconfig:
	@echo; echo "⚙️  Updating kubeconfig..."
	$(call update_kubeconfig)
	echo; echo "✅ Kubeconfig updated."

configure-ssh:
	@echo; echo "🔑 Configuring SSH..."
	$(call configure_private_key)
	$(call configure_known_hosts)
	echo; echo "✅ SSH configured."

ssh-into-host:
	@$(call check_if_name_is_valid,$(NAME))
	echo; echo "📡 Connecting to host $(NAME)..."
	$(call ssh_into_host,$(NAME))

remove-node:
	@$(call check_if_name_is_valid,$(NAME))

	echo; echo "🔥 Deleting node $(NAME)..."
	$(call remove_etcd_member,$(NAME))
	$(call drain_and_delete_node,$(NAME))

	echo; echo "💀 Terminating instance $(NAME)..."
	$(call remove_instance_from_ftvars,$(NAME))
	$(call terraform_apply)

	echo; echo "🔑 Updating SSH configuration..."
	$(call configure_known_hosts)

	echo; echo "✅ Node $(NAME) removed."

terminate-instance:
	@$(call check_if_name_is_valid,$(NAME))

	echo; echo "💀 Terminating instance $(NAME)..."
	$(call remove_instance_from_ftvars,$(NAME))
	$(call terraform_apply)

	echo; echo "🔑 Updating SSH configuration..."
	$(call configure_known_hosts)

	echo; echo "✅ Instance $(NAME) terminated."

destroy-cluster:
	@echo; echo "💥 Destroying cluster..."
	$(call terraform_destroy)
	rm -f private_key known_hosts terraform/terraform.tfvars.json primary_control_plane_public_ip
	echo; echo "✅ Cluster destroyed."

define check_if_can_setup_cluster
	if [ -f terraform/terraform.tfstate ] \
	&& jq -e '.resources | length > 0' terraform/terraform.tfstate >/dev/null; then
		echo; echo "❌ The cluster has already been set up." >&2
		exit 1
	fi
endef

define check_if_name_is_valid
	name="$(1)"
	if [ -z "$$name" ]; then
		echo; echo "❌ Missing NAME." >&2
		exit 1
	fi
endef

define check_if_name_is_available
	name="$(1)"
	if terraform -chdir=terraform state list | grep -E "^aws_instance\.this\[\"$$name\"\]\$$" >/dev/null; then
		echo; echo "❌ '$$name' already exists." >&2
		exit 1
	fi
endef

define reset_tfvars
	echo; echo "Reseting tfvars..."
	jq -n '{ instances: {} }' > terraform/terraform.tfvars.json
endef

define add_instance_to_tfvars
	node_role="$(1)"
	name="$(2)"
	echo; echo "Adding $$name instance to tfvars..."
	tmp=$$(mktemp)
	jq --arg name "$$name" --arg node_role "$$node_role" \
		'.instances[$$name] = { "node_role": $$node_role }' \
		terraform/terraform.tfvars.json > "$$tmp" && mv "$$tmp" terraform/terraform.tfvars.json || exit1
endef

define remove_instance_from_ftvars
	name="$(1)"
	echo; echo "Removing $$name instance from tfvars..."
	tmp=$$(mktemp)
	jq --arg name "$$name" \
		'del(.instances[$$name])' \
		terraform/terraform.tfvars.json > "$$tmp" && mv "$$tmp" terraform/terraform.tfvars.json || exit 1
endef

define terraform_apply
	echo; echo "Terraform init..."
	terraform -chdir=terraform init

	echo; echo "Terraform apply..."
	terraform -chdir=terraform apply -auto-approve
endef

define configure_private_key
	echo; echo "Configuring private_key..."
	terraform -chdir=terraform output -raw private_key > private_key
	chmod 600 private_key
endef

define configure_known_hosts

	instance_ids="$$(terraform -chdir=terraform output -json instance_ids | jq -r 'values[]')"
	public_ips="$$(terraform -chdir=terraform output -json public_ips | jq -r 'values[]')"

	echo; echo "Waiting for instances to be ready..."
	aws --no-cli-pager ec2 wait instance-running --instance-ids $$instance_ids
	aws --no-cli-pager ec2 wait instance-status-ok --instance-ids $$instance_ids

	echo; echo "Configuring known_hosts..."
	: > known_hosts
	for public_ip in $$public_ips; do
		echo "$$public_ip"
		ssh-keyscan $$public_ip >> known_hosts
	done
	chmod 644 known_hosts
endef

define ssh_into_host
	node_name="$(1)"
	public_ip="$$(terraform -chdir=terraform output -json public_ips | jq -r --arg key "$$node_name" '.[$$key]')"
	ssh $(SSH_OPTIONS) ubuntu@$$public_ip
endef

define terraform_destroy
	echo; echo "Terraform init..."
	terraform -chdir=terraform init

	echo; echo "Terraform destroy..."
	terraform -chdir=terraform destroy -auto-approve
endef

define prepare_host
	node_name="$(1)"

	public_ip="$$(terraform -chdir=terraform output -json public_ips | jq -r --arg key "$$node_name" '.[$$key]')"

	ssh $(SSH_OPTIONS) ubuntu@$$public_ip bash <<EOF

		set -euo pipefail

		echo; echo "$$node_name: Disable swap..."
		sudo swapoff -a
		sudo sed -ri '/\sswap\s/s/^([^#])/# \1/' /etc/fstab

		echo; echo "$$node_name: Load kernel modules..."
		cat <<EOT | sudo tee /etc/modules-load.d/k8s.conf
			overlay
			br_netfilter
		EOT
		sudo modprobe overlay
		sudo modprobe br_netfilter

		echo; echo "$$node_name: Load kernel parameters..."
		cat <<EOT | sudo tee /etc/sysctl.d/k8s.conf
			net.bridge.bridge-nf-call-iptables  = 1
			net.bridge.bridge-nf-call-ip6tables = 1
			net.ipv4.ip_forward                 = 1
		EOT
		sudo sysctl --system

		echo; echo "$$node_name: Add Docker APT repository and signing key..."
		cat <<EOT | sudo tee /etc/apt/sources.list.d/docker.list
			deb [signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \$$(lsb_release -cs) stable
		EOT
		sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
		sudo chmod 0644 /etc/apt/keyrings/docker.asc

		echo; echo "$$node_name: Add Kubernetes APT repository and signing key..."
		cat <<EOT | sudo tee /etc/apt/sources.list.d/kubernetes.list
			deb [signed-by=/etc/apt/keyrings/kubernetes.asc] https://pkgs.k8s.io/core:/stable:/v$(KUBERNETES_VERSION)/deb/ /
		EOT
		sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v$(KUBERNETES_VERSION)/deb/Release.key -o /etc/apt/keyrings/kubernetes.asc
		sudo chmod 0644 /etc/apt/keyrings/kubernetes.asc

		echo; echo "$$node_name: Update APT package index..."
		sudo apt update

		echo; echo "$$node_name: Install, enable and start containerd..."
		sudo apt install -y containerd.io

		echo; echo "$$node_name: Configure and restart containerd..."
		containerd config default | sed "s/SystemdCgroup = false/SystemdCgroup = true/" | sudo tee /etc/containerd/config.toml > /dev/null
		sudo systemctl restart containerd

		echo; echo "$$node_name: Install Kubernetes packages and pin versions..."
		sudo apt install -y kubelet kubeadm kubectl
		sudo apt-mark hold kubelet kubeadm kubectl

		echo; echo "$$node_name: Enable and start kubelet..."
		sudo systemctl enable --now kubelet
	EOF
endef

define kubeadm_init
	node_name="$(1)"

	public_ip="$$(terraform -chdir=terraform output -json public_ips | jq -r --arg key "$$node_name" '.[$$key]')"
	echo "$$public_ip" > primary_control_plane_public_ip

	ssh $(SSH_OPTIONS) ubuntu@$$public_ip bash <<EOF

		set -euo pipefail

		echo; echo "Initializing control-plane..."
		sudo kubeadm init \
			--node-name $$node_name \
			--pod-network-cidr=10.244.0.0/16 \
			--apiserver-cert-extra-sans=$$public_ip \
			--control-plane-endpoint=$$public_ip:6443

		echo; echo "Installing CNI plugin..."
		sudo kubectl apply \
			--kubeconfig=/etc/kubernetes/admin.conf \
			--filename https://github.com/flannel-io/flannel/releases/download/v0.28.5/kube-flannel.yml
	EOF
endef

define kubeadm_join
	node_role="$(1)"
	node_name="$(2)"

	echo; echo "Creating kubeadm token..."
	kubeadm_join_command="$$(
		ssh $(SSH_OPTIONS) ubuntu@$$(cat primary_control_plane_public_ip) \
			sudo kubeadm token create --print-join-command
	)"

	if [ "$$node_role" = "control-plane" ]; then

		echo; echo "Uploading kubeadm certificate..."
		kubeadm_certificate_key="$$(
			ssh $(SSH_OPTIONS) ubuntu@$$(cat primary_control_plane_public_ip) \
				sudo kubeadm init phase upload-certs --upload-certs | tail -n1
		)"

		kubeadm_join_args="--node-name $$node_name --control-plane --certificate-key $$kubeadm_certificate_key"
	else
		kubeadm_join_args="--node-name $$node_name"
	fi

	public_ip="$$(terraform -chdir=terraform output -json public_ips | jq -r --arg key "$$node_name" '.[$$key]')"

	echo; echo "Running kubeadm join command..."
	ssh $(SSH_OPTIONS) ubuntu@$$public_ip bash <<EOF

		set -euo pipefail

		sudo $$kubeadm_join_command $$kubeadm_join_args
	EOF
endef

define update_kubeconfig

	primary_control_plane_public_ip="$$(cat primary_control_plane_public_ip)"

	echo; echo "Pulling admin.conf..."
	admin_conf="$$(
		ssh $(SSH_OPTIONS) ubuntu@$$primary_control_plane_public_ip \
			"sudo cat /etc/kubernetes/admin.conf" \
		| yq -o=json
	)"

	tmpdir=$$(mktemp -d)

	echo; echo "Extracting cluster CA certificate..."
	echo "$$admin_conf" | jq -r '.clusters[0].cluster["certificate-authority-data"]' | base64 --decode > $$tmpdir/ca.crt

	echo; echo "Extracting client certificate and key..."
	echo "$$admin_conf" | jq -r '.users[0].user["client-certificate-data"]' | base64 --decode > $$tmpdir/admin.crt
	echo "$$admin_conf" | jq -r '.users[0].user["client-key-data"]' | base64 --decode > $$tmpdir/admin.key

	echo; echo "Configuring kubectl..."
	kubectl config set-cluster kubeadm-lab --server "https://$$primary_control_plane_public_ip:6443" --certificate-authority $$tmpdir/ca.crt --embed-certs=true
	kubectl config set-credentials kubeadm-lab:admin --client-key $$tmpdir/admin.key --client-certificate $$tmpdir/admin.crt --embed-certs=true
	kubectl config set-context kubeadm-lab:admin --cluster=kubeadm-lab --user=kubeadm-lab:admin
	kubectl config use-context kubeadm-lab:admin

	rm -rf $$tmpdir
endef

define remove_etcd_member
	node_name="$(1)"

	ssh $(SSH_OPTIONS) ubuntu@$$(cat primary_control_plane_public_ip) bash <<EOF

		set -euo pipefail

		primary_etcd_pod_name="etcd-\$$(cat /etc/hostname)"

		etcd_member_id="\$$(
			sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf --namespace kube-system \
				exec \$$primary_etcd_pod_name -- \
					etcdctl \
						--write-out=json \
						--endpoints=https://127.0.0.1:2379 \
						--cacert=/etc/kubernetes/pki/etcd/ca.crt \
						--cert=/etc/kubernetes/pki/etcd/server.crt \
						--key=/etc/kubernetes/pki/etcd/server.key \
						member list \
						| jq -r '.members[] | select(.name == "$$node_name") | .ID'
		)"

		if [ -n "\$$etcd_member_id" ]; then

			etcd_member_id_hex="\$$(printf '%x\n' "\$$etcd_member_id")"

			echo; echo "Removing etcd member $$node_name..."
			sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf --namespace kube-system \
				exec \$$primary_etcd_pod_name -- \
					etcdctl \
						--endpoints=https://127.0.0.1:2379 \
						--cacert=/etc/kubernetes/pki/etcd/ca.crt \
						--cert=/etc/kubernetes/pki/etcd/server.crt \
						--key=/etc/kubernetes/pki/etcd/server.key \
						member remove \$$etcd_member_id_hex
		fi
	EOF
endef

define drain_and_delete_node
	node_name="$(1)"

	ssh $(SSH_OPTIONS) ubuntu@$$(cat primary_control_plane_public_ip) bash <<EOF

		set -euo pipefail

# 		TODO get nodes first, then check if exists
		if sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf get node "$$node_name" >/dev/null 2>&1; then

			echo; echo "Draining node $$node_name..."
			sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf drain "$$node_name" --ignore-daemonsets --force

			echo; echo "Deleting node $$node_name..."
			sudo kubectl --kubeconfig=/etc/kubernetes/admin.conf delete node "$$node_name"
		fi
	EOF
endef
