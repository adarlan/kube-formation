SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: setup ssh-keys apply start stop known-hosts inventory configure-nodes init-cluster kubeconfig destroy ssh-into

# Bring up the full cluster end to end.
setup: ssh-keys apply start known-hosts inventory configure-nodes init-cluster kubeconfig

ssh-keys:
	mkdir -p ssh
	chmod 700 ssh
	if [ ! -f ssh/id_ed25519 ] || [ ! -f ssh/id_ed25519.pub ]; then
		ssh-keygen -t ed25519 -f ssh/id_ed25519 -N "" -q
	fi
	chmod 600 ssh/id_ed25519
	chmod 644 ssh/id_ed25519.pub

apply:
	cd infrastructure
	terraform init
	terraform apply

destroy:
	cd infrastructure
	terraform init
	terraform destroy

start:
	nodes="$$(terraform -chdir=infrastructure output -json nodes)"
	for id in $$(echo "$$nodes" | jq -r '.[] | .instance_id'); do
		aws ec2 start-instances --instance-ids $$id
	done

stop:
	nodes="$$(terraform -chdir=infrastructure output -json nodes)"
	for id in $$(echo "$$nodes" | jq -r '.[] | .instance_id'); do
		aws ec2 stop-instances --instance-ids $$id
	done

known-hosts:
	echo -e "Configuring SSH known hosts..."
	nodes="$$(terraform -chdir=infrastructure output -json nodes)"
	mkdir -p ssh
	: > ssh/known_hosts
	for ip in $$(echo "$$nodes" | jq -r '.[] | .public_ip'); do
		echo "- $$ip"
		ssh-keyscan $$ip >> ssh/known_hosts
	done
	chmod 644 ssh/known_hosts

inventory:
	echo -e "\nReading Terraform outputs..."
	control_plane_nodes="$$(terraform -chdir=infrastructure output -json control_plane_nodes)"
	worker_nodes="$$(terraform -chdir=infrastructure output -json worker_nodes)"

	echo -e "\nConfiguring Ansible inventory..."
	{
		echo "[bootstrap_control_plane]"
		echo "$$control_plane_nodes" | jq -r 'to_entries | first | "\(.key) ansible_host=\(.value.public_ip)"'
		echo ""
		echo "[control_plane]"
		echo "$$control_plane_nodes" | jq -r 'to_entries[] | "\(.key) ansible_host=\(.value.public_ip)"'
		echo ""
		echo "[workers]"
		echo "$$worker_nodes" | jq -r 'to_entries[] | "\(.key) ansible_host=\(.value.public_ip)"'
		echo ""
		echo "[k8s:children]"
		echo "control_plane"
		echo "workers"
		echo ""
		echo "[k8s:vars]"
		echo "ansible_user=ubuntu"
		echo "ansible_python_interpreter=/usr/bin/python3"
	} > playbooks/ansible.inventory.ini

	cd playbooks
	echo -e "\nTesting connection..."
	ansible k8s -m ping

configure-nodes:
	cd playbooks
	ansible-playbook ConfigureNodes.yml

init-cluster:
	cd playbooks
	ansible-playbook InitializeCluster.yml

kubeconfig:
	controlplane1_ip="$$(terraform -chdir=infrastructure output -json control_plane_nodes | jq -r '.controlplane1.public_ip')"

	admin_conf="$$(
		ssh \
			-i ./ssh/id_ed25519 \
			-o UserKnownHostsFile=./ssh/known_hosts \
			ubuntu@"$$controlplane1_ip" \
			"sudo cat /etc/kubernetes/admin.conf" \
			| yq -o=json
	)"

	mkdir -p kubeconfig

	echo "$$admin_conf" | jq -r '.clusters[0].cluster["certificate-authority-data"]' | base64 --decode > kubeconfig/ca.crt
	echo "$$admin_conf" | jq -r '.users[0].user["client-certificate-data"]' | base64 --decode > kubeconfig/client.crt
	echo "$$admin_conf" | jq -r '.users[0].user["client-key-data"]' | base64 --decode > kubeconfig/client.key

	kubectl config set-cluster kube-formation --server "https://$$controlplane1_ip:6443" --certificate-authority kubeconfig/ca.crt --embed-certs=true
	kubectl config set-credentials kube-formation --client-key kubeconfig/client.key --client-certificate kubeconfig/client.crt --embed-certs=true
	kubectl config set-context kube-formation --cluster=kube-formation --user=kube-formation
	kubectl config use-context kube-formation

# Usage: make ssh-into NODE=controlplane1
ssh-into:
	node="$(NODE)"
	if [ -z "$$node" ]; then
		echo "Usage: make ssh-into NODE=<node-name>" >&2
		exit 1
	fi
	node_ip="$$(terraform -chdir=infrastructure output -json nodes | jq -r --arg node "$$node" '.[$$node].public_ip')"
	ssh -i ./ssh/id_ed25519 -o UserKnownHostsFile=./ssh/known_hosts ubuntu@"$$node_ip"
