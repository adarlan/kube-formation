SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: setup setup-phase-provision-infrastructure setup-phase-prepare-nodes setup-phase-initialize-control-plane setup-phase-update-kubeconfig setup-phase-install-addons setup-phase-join-worker \
	add-control-plane add-control-plane-phase-launch-instance add-control-plane-phase-prepare-node add-control-plane-phase-join-node \
	add-worker add-worker-phase-launch-instance add-worker-phase-prepare-node add-worker-phase-join-node \
	remove-node remove-node-phase-leave-node remove-node-phase-terminate-instance \
	kubeconfig ssh-into start-instance stop-instance terminate-instance destroy

setup: setup-phase-provision-infrastructure setup-phase-prepare-nodes setup-phase-initialize-control-plane setup-phase-update-kubeconfig setup-phase-install-addons setup-phase-join-worker
setup-phase-provision-infrastructure:
	@$(call utils)
	provision-infrastructure '{
		"instances": {
			"controlplane1": {"node_role": "control-plane"},
			"worker1": {"node_role": "worker"}
		}
	}'
setup-phase-prepare-nodes:
	@$(call utils)
	prepare-node controlplane1 & prepare-node worker1 & wait
setup-phase-initialize-control-plane:
	@$(call utils)
	initialize-control-plane
setup-phase-update-kubeconfig:
	@$(call utils)
	update-kubeconfig
setup-phase-install-addons:
	@$(call utils)
	install-addons
setup-phase-join-worker:
	@$(call utils)
	join-node worker1 worker

add-control-plane: add-control-plane-phase-launch-instance add-control-plane-phase-prepare-node add-control-plane-phase-join-node
add-control-plane-phase-launch-instance:
	@$(call utils)
	@$(call validate_name,$(NAME))
	launch-instance "$(NAME)" control-plane
add-control-plane-phase-prepare-node:
	@$(call utils)
	@$(call validate_name,$(NAME))
	prepare-node "$(NAME)"
add-control-plane-phase-join-node:
	@$(call utils)
	@$(call validate_name,$(NAME))
	join-node "$(NAME)" control-plane

add-worker: add-worker-phase-launch-instance add-worker-phase-prepare-node add-worker-phase-join-node
add-worker-phase-launch-instance:
	@$(call utils)
	@$(call validate_name,$(NAME))
	launch-instance "$(NAME)" worker
add-worker-phase-prepare-node:
	@$(call utils)
	@$(call validate_name,$(NAME))
	prepare-node "$(NAME)"
add-worker-phase-join-node:
	@$(call utils)
	@$(call validate_name,$(NAME))
	join-node "$(NAME)" worker

remove-node: remove-node-phase-leave-node remove-node-phase-terminate-instance
remove-node-phase-leave-node:
	@$(call utils)
	@$(call validate_name,$(NAME))
	leave-node "$(NAME)" "$(or $(FORCE),false)"
remove-node-phase-terminate-instance:
	@$(call utils)
	@$(call validate_name,$(NAME))
	terminate-instance "$(NAME)"

kubeconfig: setup-phase-update-kubeconfig

ssh-into:
	@$(call utils)
	@$(call validate_name,$(NAME))
	$$(ssh-into "$(NAME)")

start-instance:
	@$(call utils)
	@$(call validate_name,$(NAME))
	start-instance "$(NAME)"

stop-instance:
	@$(call utils)
	@$(call validate_name,$(NAME))
	stop-instance "$(NAME)"

terminate-instance: remove-node-phase-terminate-instance

destroy:
	@$(call utils)
	destroy-infrastructure

define utils
	source infra-utils.sh
	source kubeadm-utils.sh
endef

define validate_name
	if [ -z "$(1)" ]; then
		echo
		echo "❌ Missing NAME." >&2
		exit 1
	fi
endef
