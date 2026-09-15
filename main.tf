# =============================================================================
# SEUL FICHIER SPECIFIQUE AU PROVIDER. Pour passer a Proxmox / vSphere / libvirt,
# c'est le seul endroit a reecrire : le contrat d'entree (variables.tf) et de
# sortie (outputs.tf) ne bouge pas, donc ni l'adressage ni la doc ne bougent.
# =============================================================================

terraform {
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }
}

# IP fixe : le plan d'adressage est deterministe, on ne laisse pas le DHCP decider.
resource "openstack_networking_port_v2" "this" {
  name           = var.hostname
  network_id     = var.network_id
  admin_state_up = true

  fixed_ip {
    subnet_id  = var.subnet_id
    ip_address = var.ip
  }
}

resource "openstack_compute_instance_v2" "this" {
  name        = var.hostname
  image_name  = var.image
  flavor_name = var.flavor
  key_pair    = var.cle_ssh

  # Les etiquettes sont lisibles depuis l'IaaS : le parc reste comprehensible
  # meme si la doc tombe.
  metadata = var.etiquettes

  network {
    port = openstack_networking_port_v2.this.id
  }

  lifecycle {
    # Une VM ne se recree pas sur un changement d'image sans decision explicite.
    ignore_changes = [image_name]
  }
}
