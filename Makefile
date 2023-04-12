.SHELL:=/bin/bash
WORKSPACE:=$(shell terraform workspace show)
CONFIG_FILE:="vars.$(WORKSPACE).yml"

AUTO:=$(shell [ $(shell env | grep -c -i auto) > 0 ] && echo -auto-approve)

SSH_USER:=$(shell yq -r .ssh.user vars.amzn.yml)
FQDN:=$(shell yq -r .hostname vars.amzn.yml).$(shell yq -r .domain vars.amzn.yml)

ansible:
	ansible-playbook -i .inv.$(WORKSPACE).yml playbook.yml

apply:
	terraform apply $(AUTO)

destroy: 
	terraform destroy $(AUTO)

reset:
	terraform destroy $(AUTO)
	terraform apply -auto-approve
	
