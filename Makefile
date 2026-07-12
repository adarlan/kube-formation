SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: setup tfvars apply start stop ssh-key known-hosts inventory ansible-ping init-cluster kubeconfig destroy ssh-into

setup: tfvars apply ssh-key known-hosts inventory ansible-ping init-cluster kubeconfig

tfvars:
	control_plane_node_count="$(CP)"
	if [ -z "$$control_plane_node_count" ] && [ -f terraform/terraform.tfvars.json ]; then
		control_plane_node_count="$$(jq -r '.control_plane_node_count // empty' terraform/terraform.tfvars.json)"
	fi
	control_plane_node_count="$${control_plane_node_count:-1}"

	worker_node_count="$(W)"
	if [ -z "$$worker_node_count" ] && [ -f terraform/terraform.tfvars.json ]; then
		worker_node_count="$$(jq -r '.worker_node_count // empty' terraform/terraform.tfvars.json)"
	fi
	worker_node_count="$${worker_node_count:-1}"

	jq -n \
		--arg control_plane_node_count "$$control_plane_node_count" \
		--arg worker_node_count "$$worker_node_count" \
		'{
			control_plane_node_count: $$control_plane_node_count,
			worker_node_count: $$worker_node_count
		}' > terraform/terraform.tfvars.json

apply:
	terraform -chdir=terraform init
	terraform -chdir=terraform apply

destroy:
	terraform -chdir=terraform init
	terraform -chdir=terraform destroy

start:
	nodes="$$(terraform -chdir=terraform output -json nodes)"
	for id in $$(echo "$$nodes" | jq -r '.[] | .instance_id'); do
		aws ec2 start-instances --instance-ids $$id
	done

stop:
	nodes="$$(terraform -chdir=terraform output -json nodes)"
	for id in $$(echo "$$nodes" | jq -r '.[] | .instance_id'); do
		aws ec2 stop-instances --instance-ids $$id
	done

ssh-key:
	terraform -chdir=terraform output -raw private_key > ansible/private_key
	chmod 600 ansible/private_key

known-hosts:
	nodes="$$(terraform -chdir=terraform output -json nodes)"
	: > ansible/known_hosts
	for ip in $$(echo "$$nodes" | jq -r '.[] | .public_ip'); do
		echo "- $$ip"
		ssh-keyscan $$ip >> ansible/known_hosts
	done
	chmod 644 ansible/known_hosts

inventory:
	nodes="$$(terraform -chdir=terraform output -json nodes)"
	control_plane_nodes="$$(echo "$$nodes" | jq 'with_entries(select(.value.role == "control-plane"))')"
	worker_nodes="$$(echo "$$nodes" | jq 'with_entries(select(.value.role == "worker"))')"

	{
		echo "[primary_control_plane_node]"
		echo "$$control_plane_nodes" | jq -r 'to_entries | first | "\(.key) ansible_host=\(.value.public_ip)"'
		echo ""
		echo "[control_plane_nodes]"
		echo "$$control_plane_nodes" | jq -r 'to_entries[] | "\(.key) ansible_host=\(.value.public_ip)"'
		echo ""
		echo "[worker_nodes]"
		echo "$$worker_nodes" | jq -r 'to_entries[] | "\(.key) ansible_host=\(.value.public_ip)"'
		echo ""
		echo "[cluster_nodes:children]"
		echo "control_plane_nodes"
		echo "worker_nodes"
		echo ""
		echo "[cluster_nodes:vars]"
		echo "ansible_user=ubuntu"
		echo "ansible_python_interpreter=/usr/bin/python3"
	} > ansible/inventory.ini

ansible-ping:
	cd ansible
	ansible cluster_nodes -m ping

init-cluster:
	cd ansible
	ansible-playbook initialize_cluster.yaml

kubeconfig:
	nodes="$$(terraform -chdir=terraform output -json nodes)"
	controlplane1_ip="$$(echo "$$nodes" | jq -r '.controlplane1.public_ip')"

	admin_conf="$$(ssh -i ansible/private_key -o UserKnownHostsFile=ansible/known_hosts ubuntu@"$$controlplane1_ip" "sudo cat /etc/kubernetes/admin.conf" | yq -o=json)"

	echo "$$admin_conf" | jq -r '.clusters[0].cluster["certificate-authority-data"]' | base64 --decode > ca.crt
	echo "$$admin_conf" | jq -r '.users[0].user["client-certificate-data"]' | base64 --decode > admin.crt
	echo "$$admin_conf" | jq -r '.users[0].user["client-key-data"]' | base64 --decode > admin.key

	kubectl config set-cluster kube-formation --server "https://$$controlplane1_ip:6443" --certificate-authority ca.crt --embed-certs=true
	kubectl config set-credentials kube-formation:admin --client-key admin.key --client-certificate admin.crt --embed-certs=true
	kubectl config set-context kube-formation:admin --cluster=kube-formation --user=kube-formation:admin
	kubectl config use-context kube-formation:admin

	rm -f ca.crt admin.crt admin.key

ssh-into:
	node="$(NODE)"
	if [ -z "$$node" ]; then
		echo "Usage: make ssh-into NODE=<node-name>" >&2
		exit 1
	fi
	nodes="$$(terraform -chdir=terraform output -json nodes)"
	node_ip="$$(echo "$$nodes" | jq -r --arg node "$$node" '.[$$node].public_ip')"
	ssh -i ansible/private_key -o UserKnownHostsFile=ansible/known_hosts ubuntu@"$$node_ip"
