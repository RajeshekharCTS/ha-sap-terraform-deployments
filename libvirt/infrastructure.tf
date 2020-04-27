provider "libvirt" {
  uri = var.qemu_uri
}

locals {
  internal_network_name = var.network_name
  internal_network_id   = var.network_name != "" ? "" : libvirt_network.isolated_network.0.id
  base_image_name       = var.base_source_image != "" ? libvirt_volume.base_image.0.name : var.base_image_name != "" ? var.base_image_name : ""
  iprange               = var.iprange
}

resource "libvirt_volume" "base_image" {
  count  = var.base_source_image != "" ? 1 : 0
  name   = "${terraform.workspace}-baseimage"
  source = var.base_source_image
  pool   = var.storage_pool
}

# Internal network
resource "libvirt_network" "isolated_network" {
  count     = var.network_name == "" ? 1 : 0
  name      = "${terraform.workspace}-isolated"
  bridge    = var.isolated_network_bridge
  mode      = "none"
  addresses = [var.iprange]
  dhcp {
    enabled = "false"
  }
  dns {
    enabled = true
  }
  autostart = true
}

# Create shared disks for sbd
module "sbd_disk" {
  source            = "./modules/shared_disk"
  shared_disk_count = var.shared_storage_type == "shared-disk" ? 1 : 0
  name              = "sbd"
  pool              = var.storage_pool
  shared_disk_size  = 104857600
}

module "drbd_sbd_disk" {
  source            = "./modules/shared_disk"
  shared_disk_count = var.drbd_enabled == true && var.drbd_shared_storage_type == "shared-disk" ? 1 : 0
  name              = "drbd-sbd"
  pool              = var.storage_pool
  shared_disk_size  = 104857600
}

# Netweaver uses the shared disk for more things than only sbd
# Some SAP data is stored there to enable HA stack
module "netweaver_shared_disk" {
  source            = "./modules/shared_disk"
  shared_disk_count = var.netweaver_enabled == true ? 1 : 0
  name              = "netweaver-shared"
  pool              = var.storage_pool
  shared_disk_size  = 68719476736
}
