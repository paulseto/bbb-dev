# bbb-dev

The purpose of this project is to deploy a server for testing scripts used to build AMIs for BigBlueButton. BigBlueButton supports many unix-based platforms and the example shown focuses on AmazonLinux2 deployed on Amazon Web Services.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Python](https://www.python.org/downloads/)
- [Ansible](https://www.ansible.com/)
- [make](https://www.gnu.org/software/make/)
- [yq](https://github.com/mikefarah/yq/)
- [Lego](https://github.com/go-acme/lego/)
- [jq](https://stedolan.github.io/jq/)

## Setup Instructions
These are setup instructions for AmazonLinux2 and includes extra packages used to build and deploy Scalelite Enterprise. `packer`, `lego`, `jq`, `docker`, and `ansible community.docker` not required.

```
sudo yum update -y
sudo yum install -y jq docker yum-utils

# Install terraform and packer
sudo yum install -y yum-utils shadow-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform packer
terraform -install-autocomplete

# Install Python3.8; Python3.7 is installed by default on AmazonLinux2
sudo amazon-linux-extras enable python3.8
sudo yum install python3.8
sudo rm /usr/bin/python3
sudo ln -s /usr/bin/python3.8 /usr/bin/python3

# Install Ansible through pip to ensure compatibility with python
pip install ansible
ansible-galaxy collection install community.docker

# Install yq
cd /tmp
wget https://github.com/mikefarah/yq/releases/download/v4.33.2/yq_linux_amd64.tar.gz
tar xvf yq_linux_amd64.tar.gz
sudo mv yq_linux_amd64 /usr/local/bin/yq

#Install Lego
cd /tmp
wget https://github.com/go-acme/lego/releases/download/v4.10.2/lego_v4.10.2_linux_amd64.tar.gz
tar xf lego_v4.6.0_linux_amd64.tar.gz
sudo mv lego /usr/local/bin/
```

## Example

1. Grab project files

```
git clone https://github.com/paulseto/bbb-dev.git
cd bbb-dev
```

2. Initialize the project and create a workspace
```
terraform init
terraform workspace new amzn2
```

3. Create configuration file.

The name of your configuration will include your terraform workspace.  The `amzn2` workspace was created above so your configuration file name will be `vars.amzn2.yml`. Create the configuration file containing the following:

```
---
hostname: dev26

ssh:
  user: ec2-user

instance:
  ami_filter: amzn2-ami-kernel-*-hvm-*-x86_64-gp2
  ami_owner_id: "137112412989"

ssl:
  crt: ~/ssl/certificates/_.mountcorona.com.crt
  key: ~/ssl/certificates/_.mountcorona.com.key
```
The configuration file overrides default settings defined in `variables.tf`.  This project resides on the same workstation as the deployment worksation for Scalelite Enterprise so default configuration copies the script used configure the ami. See `script_setup` and `script_config`

4. Provision the server

`make apply`

The following files are created

- `connect_amzn2` - ssh into the server
- `upload_amzn2` - scp files to the server
- `.inv.amzn2.yml` - ansible inventory file

5. Run the ami build script

SSH into the server

```
./connect_amzn2
```

Execute the AMI script. This simulates packer building the AMI

```
./setup.sh
```

Complete the configuration. This simultes running ansible to complete the customization.
```
sudo ./configure.sh
```

You should have a working BBB server.
