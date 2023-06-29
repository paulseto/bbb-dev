locals {
  vars = yamldecode(file("vars.${terraform.workspace}.yml"))

  aws         = lookup(local.vars, "aws", {})
  aws_region  = lookup(local.aws, "region", "ca-central-1")
  aws_profile = lookup(local.aws, "profile", "default")

  domain   = lookup(local.vars, "domain", "mountcorona.com")
  hostname = lookup(local.vars, "hostname", terraform.workspace)
  fqdn     = format("%s.%s", local.hostname, local.domain)

  ssh          = lookup(local.vars, "ssh", {})
  ssh_user     = lookup(local.ssh, "user", "ubuntu")
  ssh_key_name = lookup(local.ssh, "key_name", "mountcorona")
  ssh_key_file = lookup(local.ssh, "key_file", "~/.ssh/mountcorona.pem")
  ssh_keys     = lookup(local.ssh, "keys", [])

  ssl     = lookup(local.vars, "ssl", {})
  ssl_crt = lookup(local.ssl, "crt", "")
  ssl_key = lookup(local.ssl, "key", "")

  instance              = lookup(local.vars, "instance", {})
  instance_type         = lookup(local.instance, "type", "c5.xlarge")
  instance_volume_type  = lookup(local.instance, "volume_type", "gp3")
  instance_volume_size  = lookup(local.instance, "volume_size", 30)
  instance_ami_id       = lookup(local.instance, "ami_id", "")
  instance_ami_filter   = lookup(local.instance, "ami_filter", "ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*")
  instance_ami_owner_id = lookup(local.instance, "ami_owner_id", "099720109477")
  instance_iam_role     = lookup(local.instance, "iam_role", "AdministratorAccess")

  script        = lookup(local.vars, "scripts", {})
  script_setup  = lookup(local.script, "setup", "bbb-centos7.sh")
  script_config = lookup(local.script, "config", "bbb-configure-centos7.sh")
}
