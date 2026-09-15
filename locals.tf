# =============================================================================
# Tout part de grappes.yaml. Aucune IP, aucun hostname n'est ecrit a la main.
# Cette logique est la SEULE autorite sur l'adressage ; tools/grappes.mjs ne la
# reproduit que pour le lint de collisions (voir commentaire dans ce fichier).
# =============================================================================

locals {
  conf = yamldecode(file("${path.module}/${var.fichier_grappes}"))

  grappes_par_numero = { for g in local.conf.grappes : g.numero => g }

  grappe = lookup(
    local.grappes_par_numero,
    var.grappe_numero,
    null
  )

  # Octet de subnet (X)
  octet_subnet = local.conf.reseau.subnets[local.grappe.subnet]

  # Gabarit effectif : defaut global, surchargeable par grappe
  gabarits_grappe = merge(
    local.conf.defauts.gabarits,
    try(local.grappe.gabarits, {})
  )

  # ---------------------------------------------------------------------------
  # La grappe, role par role. Cle = id du role, pour un for_each stable :
  # renumeroter une grappe ne doit jamais detruire les VM des autres roles.
  # ---------------------------------------------------------------------------
  vms = {
    for r in local.conf.roles : r.id => {
      role        = r.id
      description = r.description
      hostname    = "${local.grappe.subnet}-g${local.grappe.numero}-${r.id}"

      # 10.29.X.YZ  ->  Y = numero de grappe, Z = suffixe de role
      ip = "${local.conf.reseau.prefixe}.${local.octet_subnet}.${local.grappe.numero * 10 + r.suffixe}"

      gabarit   = local.gabarits_grappe[r.id]
      flavor    = local.conf.gabarits[local.gabarits_grappe[r.id]].flavor
      vcpu      = local.conf.gabarits[local.gabarits_grappe[r.id]].vcpu
      ram_go    = local.conf.gabarits[local.gabarits_grappe[r.id]].ram_go
      disque_go = local.conf.gabarits[local.gabarits_grappe[r.id]].disque_go
      image     = try(local.grappe.image, local.conf.defauts.image)
    }
  }

  # ---------------------------------------------------------------------------
  # Etiquettes portees par chaque VM. C'est ce qui rend le parc lisible depuis
  # l'IaaS meme sans la doc, et ce qui fait apparaitre un changement de version
  # comme une derive legitime dans le plan.
  # ---------------------------------------------------------------------------
  etiquettes_communes = {
    env               = local.grappe.env
    grappe            = tostring(local.grappe.numero)
    subnet            = local.grappe.subnet
    version_composant = local.grappe.version_composant
    gere_par          = "opentofu"
  }
}

# Garde-fous : on echoue au plan, pas au milieu du apply.
check "grappe_declaree" {
  assert {
    condition     = local.grappe != null
    error_message = "La grappe ${var.grappe_numero} n'existe pas dans grappes.yaml."
  }
}

check "subnet_declare" {
  assert {
    condition     = contains(keys(var.subnet_ids), local.grappe.subnet)
    error_message = "Le subnet ${local.grappe.subnet} n'a pas d'ID IaaS dans la variable subnet_ids."
  }
}
