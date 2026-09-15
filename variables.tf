variable "hostname" {
  description = "Nom de la VM, calcule par le module racine."
  type        = string
}

variable "ip" {
  description = "IP fixe issue du plan d'adressage."
  type        = string
}

variable "image" {
  description = "Image systeme du catalogue IaaS."
  type        = string
}

variable "flavor" {
  description = "Gabarit du catalogue IaaS."
  type        = string
}

variable "cle_ssh" {
  description = "Nom de la paire de cles a injecter."
  type        = string
}

variable "network_id" {
  description = "ID du reseau IaaS."
  type        = string
}

variable "subnet_id" {
  description = "ID du subnet IaaS."
  type        = string
}

variable "etiquettes" {
  description = "Metadonnees posees sur la VM (env, grappe, role, version...)."
  type        = map(string)
}
