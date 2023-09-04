resource "random_string" "server" {
  length  = 3
  lower   = true
  special = false
  numeric = false
  upper   = false

  keepers = {
    # We re-create the apart of the name changes.
    name = var.name
  }
}

resource "random_string" "identity_file" {
  length  = 20
  lower   = true
  special = false
  numeric = true
  upper   = false
}

resource "hcloud_server" "server" {
  name               = local.name
  image              = var.microos_snapshot_id
  server_type        = var.server_type
  location           = var.location
  ssh_keys           = var.ssh_keys
  firewall_ids       = var.firewall_ids
  placement_group_id = var.placement_group_id
  backups            = var.backups
  user_data          = data.cloudinit_config.config.rendered

  labels = var.labels

  # Prevent destroying the whole cluster if the user changes
  # any of the attributes that force to recreate the servers.
  lifecycle {
    ignore_changes = [
      location,
      ssh_keys,
      user_data,
      image,
    ]
  }

  connection {
    user           = "root"
    private_key    = var.ssh_private_key
    agent_identity = local.ssh_agent_identity
    host           = self.ipv4_address
    port           = var.ssh_port
  }

  # Prepare ssh identity file
  provisioner "local-exec" {
    command = <<-EOT
      install -b -m 600 /dev/null /tmp/${random_string.identity_file.id}
      echo "${local.ssh_client_identity}" > /tmp/${random_string.identity_file.id}
    EOT
  }

  # Wait for MicroOS to reboot and be ready.
  provisioner "local-exec" {
    command = <<-EOT
      until ssh ${local.ssh_args} -i /tmp/${random_string.identity_file.id} -o ConnectTimeout=2 -p ${var.ssh_port} root@${self.ipv4_address} true 2> /dev/null
      do
        echo "Waiting for MicroOS to become available..."
        sleep 3
      done
    EOT
  }

  # Cleanup ssh identity file
  provisioner "local-exec" {
    command = <<-EOT
      rm /tmp/${random_string.identity_file.id}
    EOT
  }


  provisioner "remote-exec" {
    inline = var.automatically_upgrade_os ? [
      <<-EOT
      echo "Automatic OS updates are enabled"
      EOT
      ] : [
      <<-EOT
      echo "Automatic OS updates are disabled"
      systemctl --now disable transactional-update.timer
      EOT
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait"
    ]
  }

}

resource "null_resource" "registries" {
  triggers = {
    registries = var.k3s_registries
  }

  connection {
    user           = "root"
    private_key    = var.ssh_private_key
    agent_identity = local.ssh_agent_identity
    host           = hcloud_server.server.ipv4_address
    port           = var.ssh_port
  }

  provisioner "file" {
    content     = var.k3s_registries
    destination = "/tmp/registries.yaml"
  }

  provisioner "remote-exec" {
    inline = [var.k3s_registries_update_script]
  }

  depends_on = [hcloud_server.server]
}

resource "hcloud_rdns" "server" {
  count = var.base_domain != "" ? 1 : 0

  server_id  = hcloud_server.server.id
  ip_address = hcloud_server.server.ipv4_address
  dns_ptr    = format("%s.%s", local.name, var.base_domain)
}

resource "hcloud_server_network" "server" {
  ip        = var.private_ipv4
  server_id = hcloud_server.server.id
  subnet_id = var.ipv4_subnet_id
}

data "cloudinit_config" "config" {
  gzip          = true
  base64_encode = true

  # Main cloud-config configuration file.
  part {
    filename     = "init.cfg"
    content_type = "text/cloud-config"
    content = templatefile(
      "${path.module}/templates/cloudinit.yaml.tpl",
      {
        hostname                     = local.name
        sshAuthorizedKeys            = concat([var.ssh_public_key], var.ssh_additional_public_keys)
        cloudinit_write_files_common = var.cloudinit_write_files_common
        cloudinit_runcmd_common      = var.cloudinit_runcmd_common
      }
    )
  }
}
