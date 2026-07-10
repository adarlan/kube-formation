SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: setup ssh-keys tfvars apply start stop known-hosts inventory ansible-ping init-cluster kubeconfig destroy ssh-into

setup: ssh-keys tfvars apply known-hosts inventory ansible-ping init-cluster kubeconfig

ssh-keys:
	if [ ! -f id_ed25519 ] || [ ! -f id_ed25519.pub ]; then
		ssh-keygen -t ed25519 -f id_ed25519 -N "" -q
	fi
	chmod 600 id_ed25519
	chmod 644 id_ed25519.pub

tfvars:
	{
		echo "ssh_authorized_key = \"$$(cat id_ed25519.pub)\""
	} > terraform/terraform.tfvars

apply:
	terraform -chdir=terraform init
	terraform -chdir=terraform apply
	terraform -chdir=terraform output -json nodes | jq > nodes.json

destroy:
	terraform -chdir=terraform init
	terraform -chdir=terraform destroy

start:
	for id in $$(cat nodes.json | jq -r '.[] | .instance_id'); do
		aws ec2 start-instances --instance-ids $$id
	done

stop:
	for id in $$(cat nodes.json | jq -r '.[] | .instance_id'); do
		aws ec2 stop-instances --instance-ids $$id
	done

known-hosts:
	: > known_hosts
	for ip in $$(cat nodes.json | jq -r '.[] | .public_ip'); do
		echo "- $$ip"
		ssh-keyscan $$ip >> known_hosts
	done
	chmod 644 known_hosts

inventory:
	control_plane_nodes="$$(cat nodes.json | jq 'with_entries(select(.value.role == "control-plane"))')"
	worker_nodes="$$(cat nodes.json | jq 'with_entries(select(.value.role == "worker"))')"

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
	} > ansible/ansible-inventory.ini

ansible-ping:
	cd ansible
	ansible k8s -m ping

init-cluster:
	cd ansible
	ansible-playbook initialize_cluster.yaml

kubeconfig:
	controlplane1_ip="$$(cat nodes.json | jq -r '.controlplane1.public_ip')"

	admin_conf="$$(
		ssh \
			-i id_ed25519 \
			-o UserKnownHostsFile=known_hosts \
			ubuntu@"$$controlplane1_ip" \
			"sudo cat /etc/kubernetes/admin.conf" \
			| yq -o=json
	)"

	echo "$$admin_conf" | jq -r '.clusters[0].cluster["certificate-authority-data"]' | base64 --decode > ca.crt
	echo "$$admin_conf" | jq -r '.users[0].user["client-certificate-data"]' | base64 --decode > client.crt
	echo "$$admin_conf" | jq -r '.users[0].user["client-key-data"]' | base64 --decode > client.key

	kubectl config set-cluster kube-formation --server "https://$$controlplane1_ip:6443" --certificate-authority ca.crt --embed-certs=true
	kubectl config set-credentials kube-formation --client-key client.key --client-certificate client.crt --embed-certs=true
	kubectl config set-context kube-formation --cluster=kube-formation --user=kube-formation
	kubectl config use-context kube-formation

	rm -f ca.crt client.crt client.key

ssh-into:
	node="$(NODE)"
	if [ -z "$$node" ]; then
		echo "Usage: make ssh-into NODE=<node-name>" >&2
		exit 1
	fi
	node_ip="$$(cat nodes.json | jq -r --arg node "$$node" '.[$$node].public_ip')"
	ssh -i id_ed25519 -o UserKnownHostsFile=known_hosts ubuntu@"$$node_ip"

ssh-cmd:
	node="$(NODE)"
	cmd="$(CMD)"
	if [ -z "$$node" ] || [ -z "$$cmd" ]; then
		echo "Usage: make ssh-into NODE=<node-name> CMD=<command>" >&2
		exit 1
	fi
	node_ip="$$(cat nodes.json | jq -r --arg node "$$node" '.[$$node].public_ip')"
	ssh -i id_ed25519 -o UserKnownHostsFile=known_hosts ubuntu@"$$node_ip" "$$cmd"
