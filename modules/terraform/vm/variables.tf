# Tags
variable "environment_tag" {
  description = "The environment where the resource resides (e.g., Production, Staging, Development)"
  default     = "Development"
}
variable "asset_tag" {
  description = "The overarching asset this resource supports (e.g., application name, hardware, device)"
  default     = "asset_name"
}
variable "createdby_tag" {
  description = "If manual - the person who created a resource. If automated- the automation tool used to create resource"
  default     = "INF Terraform"
}
variable "operationalOwner_tag" {
  description = " Department that utilizes or requested the resource (e.g., Operations)"
  default     = "OperationalOwner"
}
variable "maintainedBy_tag" {
  description = "Department responsible for resource maintenance and accountability (e.g., Maintenance)"
  default     = "MaintainedBy"
}
variable "requestedBy_tag" {
  description = "The user who requested the resource"
  default     = "RequestedBy"
}

variable "data_center" {
  description = "Data Center/site"
  default     = "ftdc4"
}

variable "env_short" {
  description = "Short environment name"
  default     = "d"
}
variable "vm_os_disk_size" {
  description = "OS Disk Size"
  default     = "127"

  validation {
    condition     = tonumber(var.vm_os_disk_size) >= 127
    error_message = "OS disk size must be at least 127 GiB."
  }
}

variable "vm_size" {
  description = "Size of the VM"
  default     = "Standard_b2ms"

  validation {
    condition     = var.env_short != "p" || !can(regex("^Standard_[Bb]", var.vm_size))
    error_message = "B-series (burstable) VM SKUs are not allowed in production environments (env_short = 'p')."
  }
}

variable "use_case" {
  description = "Use Case"
}

variable "resource_group" {
  description = "Resource Group"
}

variable "vm_image_id" {
  description = "VM Image ID - Optional - if provided, this will be used instead of the source_image_reference block"
  type        = string
  default     = null
}

variable "vm_source_image" {
  description = "Source image for the VM"
  type        = string
  default     = "Windows Server 2022"

  validation {
    condition = (
      (var.os == "windows" && contains(["Windows Server 2025", "Windows Server 2022"], var.vm_source_image)) ||
      (var.os == "linux" && contains(["Ubuntu 24.04", "Ubuntu 26.04"], var.vm_source_image))
    )
    error_message = "For Windows OS, vm_source_image must be either 'Windows Server 2025' or 'Windows Server 2022'. For Linux OS, vm_source_image must be either 'Ubuntu 24.04' or 'Ubuntu 26.04'."
  }
}

variable "os" {
  description = "Operating System"
}

#######################
### Local Variables ###
#######################
locals {
  source_image_map = {
    "Windows Server 2025" = {
      publisher = "microsoftwindowsserver"
      offer     = "windowsserver"
      sku       = "2025-datacenter-azure-edition"
      version   = "latest"
    }
    "Windows Server 2022" = {
      publisher = "microsoftwindowsserver"
      offer     = "windowsserver"
      sku       = "2022-datacenter-azure-edition-hotpatch"
      version   = "latest"
    }
    "Ubuntu 24.04" = {
      publisher = "Canonical"
      offer     = "ubuntu-24_04-lts"
      sku       = "server"
      version   = "latest"
    }
    "Ubuntu 26.04" = {
      publisher = "Canonical"
      offer     = "ubuntu-26_04-lts"
      sku       = "server"
      version   = "latest"
    }
  }

  source_image_reference = local.source_image_map[var.vm_source_image]
}
