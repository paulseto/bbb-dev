terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.59.0"
    }
  }
}

provider "aws" {
  region  = local.aws_region
  profile = local.aws_profile

  default_tags {
    tags = {
      Workspace   = terraform.workspace
      Provisioner = "Terraform"
    }
  }
}

data "aws_ami" "this" {
  most_recent = true

  filter {
    name   = "owner-id"
    values = [local.instance_ami_owner_id]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = local.instance_ami_id == "" ? "name" : "image-id"
    values = [local.instance_ami_id == "" ? local.instance_ami_filter : local.instance_ami_id]
  }
}

data "aws_iam_role" "this" {
  name = local.instance_iam_role
}

resource "aws_eip" "this" {
  vpc = true

  tags = {
    Name     = local.fqdn
    Hostname = local.fqdn
  }
}

data "aws_vpc" "this" {
  default = true
}

data "aws_subnets" "this" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
}

resource "aws_security_group" "this" {
  name   = "bbb-dev-${terraform.workspace}"
  vpc_id = data.aws_vpc.this.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    #    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    #    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    #    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    #    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port   = 5060
    to_port     = 5060
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    #    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 16384
    to_port          = 32768
    protocol         = "udp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

}

resource "aws_instance" "this" {
  ami                         = data.aws_ami.this.image_id
  associate_public_ip_address = true
  key_name                    = local.ssh_key_name
  instance_type               = local.instance_type
  iam_instance_profile        = data.aws_iam_role.this.id
  #  ipv6_address_count          = 1

  root_block_device {
    volume_type = local.instance_volume_type
    volume_size = local.instance_volume_size
  }

  subnet_id              = data.aws_subnets.this.ids[0]
  vpc_security_group_ids = [resource.aws_security_group.this.id]

  tags = {
    Hostname = local.fqdn
    Name     = local.fqdn
  }

  connection {
    type        = "ssh"
    user        = local.ssh_user
    host        = self.public_ip
    private_key = file(local.ssh_key_file)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo hostnamectl set-hostname ${local.fqdn}",
      "mkdir -p /home/${local.ssh_user}/.ssh",
      "echo set number > /home/${local.ssh_user}/.vimrc",
      "echo set paste >> /home/${local.ssh_user}/.vimrc",
    ]
  }

  # Copies setup script
  provisioner "file" {
    source      = local.script_setup
    destination = "/home/${local.ssh_user}/setup.sh"
  }

  # Copies configure script
  provisioner "file" {
    source      = local.script_config
    destination = "/home/${local.ssh_user}/configure.sh"
  }

  # Copies crt
  provisioner "file" {
    source      = local.ssl_crt
    destination = "/home/${local.ssh_user}/bbb.crt"
  }

  # Copies ssl key
  provisioner "file" {
    source      = local.ssl_key
    destination = "/home/${local.ssh_user}/bbb.key"
  }

  # Copies ansible completion setup 
  provisioner "file" {
    source      = "./post_setup.sh"
    destination = "/home/${local.ssh_user}/post_setup.sh"
  }

  # Copies deployment workstation setup
  provisioner "file" {
    source      = "./deploy.sh"
    destination = "/home/${local.ssh_user}/deployment_setup.sh"
  }

  # Copies ssh identity file
  provisioner "file" {
    source      = "~/.ssh/mountcorona.pem"
    destination = "/home/${local.ssh_user}/.ssh/mountcorona.pem"
  }
  

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${local.ssh_user}/setup.sh",
      "chmod +x /home/${local.ssh_user}/configure.sh",
      "sudo mv /home/${local.ssh_user}/configure.sh /root/configure.sh",
      "chmod +x /home/${local.ssh_user}/post_setup.sh",
      "chmod +x /home/${local.ssh_user}/deployment_setup.sh",
      "sudo mkdir -p /etc/nginx/ssl",
      "sudo mv ~/bbb.* /etc/nginx/ssl"
    ]
  }

}

resource "aws_eip_association" "this" {
  instance_id   = resource.aws_instance.this.id
  allocation_id = resource.aws_eip.this.id
}

data "aws_route53_zone" "this" {
  name = local.domain
}

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.fqdn
  type    = "A"
  ttl     = "300"
  records = [resource.aws_eip.this.public_ip]
}

resource "local_file" "ssh" {
  filename        = format("connect_%s", terraform.workspace)
  file_permission = "0744"
  content         = <<-EOT
    #!/bin/bash
    
    OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=120 -o ServerAliveCountMax=2"
    
    ssh -i ${local.ssh_key_file} $OPTIONS ${local.ssh_user}@${local.fqdn}
EOT
}

resource "local_file" "upload" {
  filename        = format("upload_%s", terraform.workspace)
  file_permission = "0744"
  content         = <<-EOT
    #!/bin/bash
    
    OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=120 -o ServerAliveCountMax=2"
    
    scp -i ${local.ssh_key_file} $OPTIONS $1 ${local.ssh_user}@${local.fqdn}:$2
EOT
}

resource "local_file" "ansible" {
  filename = format(".inv.%s.yml", terraform.workspace)
  file_permission = "0744"
  content = yamlencode({
    "all": {
      "hosts": {
        "${local.fqdn}": {
          "ansible_user": "${local.ssh_user}",
          "ansible_ssh_private_key_file": "${local.ssh_key_file}",
          "ssh_config": "StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ServerAliveInterval=120 -o ServerAliveCountMax=2"
        }
      }
    }
  })
}


output "instance_created_based_on_image" {
  value = {
    id          = data.aws_ami.this.image_id
    name        = data.aws_ami.this.name
    name_filter = local.instance_ami_filter
    description = data.aws_ami.this.description
    created     = data.aws_ami.this.creation_date
    deprecated  = data.aws_ami.this.deprecation_time
  }
}
output "connect_using" {
  value = "./connect_${terraform.workspace}"
}
/*
output "ami" {
  value = data.aws_ami.this
}*/
