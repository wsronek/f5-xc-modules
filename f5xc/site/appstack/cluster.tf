resource "volterra_token" "token" {
  name      = var.f5xc_cluster_name
  namespace = var.f5xc_namespace
}

module "maurice" {
  source       = "../../../utils/maurice"
  f5xc_api_url = var.f5xc_api_url
}

resource "volterra_k8s_cluster" "cluster" {
  name                              = var.f5xc_cluster_name
  namespace                         = var.f5xc_namespace
  use_default_psp                   = true
  global_access_enable              = true
  no_cluster_wide_apps              = true
  no_insecure_registries            = true
  use_default_cluster_roles         = true
  cluster_scoped_access_permit      = true
  use_default_cluster_role_bindings = true

  local_access_config {
    local_domain = format("%s.local", var.f5xc_cluster_name)
    default_port = true
  }
}

resource "volterra_voltstack_site" "site" {
  name      = var.f5xc_cluster_name
  namespace = var.f5xc_namespace

  dynamic "master_node_configuration" {
    for_each = [for k, v in terraform_data.master : format("%s-m%s", volterra_k8s_cluster.cluster.name, k)]
    content {
      name = master_node_configuration.value
    }
  }

  k8s_cluster {
    namespace = var.f5xc_namespace
    name      = volterra_k8s_cluster.cluster.name
  }

  worker_nodes            = [for k, v in terraform_data.worker : format("%s-w%s", volterra_k8s_cluster.cluster.name, k)]
  disable_gpu             = true
  disable_vm              = var.kubevirt ? false : true
  no_bond_devices         = true
  logs_streaming_disabled = true
  default_network_config  = true
  default_storage_config  = true
  deny_all_usb            = false
  volterra_certified_hw   = var.f5xc_certified_hardware_profile
  os {
    operating_system_version = var.f5xc_operating_system_version
  }
}

resource "volterra_registration_approval" "master" {
  count        = var.master_nodes_count
  cluster_name = volterra_voltstack_site.site.name
  cluster_size = var.master_nodes_count
  hostname     = format("%s-m%d", volterra_voltstack_site.site.name, count.index)
  wait_time    = var.f5xc_registration_wait_time
  retry        = var.f5xc_registration_retry
}

module "site_wait_for_online" {
  depends_on     = [volterra_registration_approval.master]
  source         = "../../status/site"
  f5xc_api_token = var.f5xc_api_token
  f5xc_api_url   = var.f5xc_api_url
  f5xc_namespace = var.f5xc_namespace
  f5xc_site_name = var.f5xc_cluster_name
  f5xc_tenant    = var.f5xc_tenant
  is_sensitive   = var.is_sensitive
}

resource "volterra_registration_approval" "worker" {
  # depends_on   = [module.site_wait_for_online]
  count        = var.worker_nodes_count
  cluster_name = volterra_voltstack_site.site.name
  cluster_size = var.master_nodes_count
  hostname     = format("%s-w%d", volterra_voltstack_site.site.name, count.index)
  wait_time    = var.f5xc_registration_wait_time
  retry        = var.f5xc_registration_retry
}

module "kubeconfig" {
  source                = "../../../utils/kubeconfig"
  f5xc_api_token        = var.f5xc_api_token
  f5xc_api_url          = var.f5xc_api_url
  f5xc_k8s_cluster_name = var.f5xc_cluster_name
  f5xc_k8s_config_type  = var.f5xc_k8s_config_type
}