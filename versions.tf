terraform {
  required_version = ">= 1.8.0"

  required_providers {
    # ADAPTER : remplacer par le provider de votre IaaS
    # (proxmox, vsphere, libvirt, nutanix...). Seul modules/vm/main.tf change.
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 3.0"
    }
  }

  # Backend HTTP = state manage par GitLab. Configure entierement en CI via
  # -backend-config (voir ci/tofu.yml), un state nomme par grappe.
  backend "http" {}
}
