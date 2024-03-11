resource "local_file" "kubectl_manifest_worker" {
  count   = var.worker_nodes_count
  content = templatefile("${path.module}/templates/rhel9-worker-node-template-static-ip.yaml", {
    latitude                   = var.f5xc_cluster_latitude
    longitude                  = var.f5xc_cluster_longitude
    network                    = count.index % 3 == 0 ? "ves-system/sb-infra-lab-v5-eno5np0-251-vfio" : count.index % 3 == 1 ? "ves-system/sb-infra-lab-v5-eno6np1-251-vfio" : "ves-system/sb-infra-lab-v5-ens1f0np0-251-vfio"
    host_name                  = format("w%d", count.index)
    ip_address                 = "${var.worker_node_ip_address_prefix}${count.index + 10}/${var.worker_node_ip_address_suffix}"
    ip_gateway                 = var.ip_gateway
    cluster_name               = var.f5xc_cluster_name
    maurice_endpoint           = module.maurice.endpoints.maurice
    f5xc_rhel9_container       = var.f5xc_rhel9_container
    site_registration_token    = var.site_registration_token != "" ? var.site_registration_token : volterra_token.site.id
    maurice_private_endpoint   = module.maurice.endpoints.maurice_mtls
    certified_hardware_profile = var.f5xc_certified_hardware_profile
  })
  filename = "manifest/${var.f5xc_cluster_name}_w${count.index}.yaml"
}

resource "terraform_data" "worker" {
  count      = var.worker_nodes_count
  depends_on = [local_file.kubectl_manifest_worker]
  input      = {
    name            = "${var.f5xc_cluster_name}-w${count.index}"
    manifest        = "manifest/${var.f5xc_cluster_name}_w${count.index}.yaml"
    kubeconfig_file = module.kubeconfig.filename
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${self.input.manifest} --kubeconfig ${self.input.kubeconfig_file} && kubectl wait --for=condition=ready pod -l vm.kubevirt.io/name=${self.input.name} --kubeconfig ${self.input.kubeconfig_file}"
  }
  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = "kubectl delete -f ${self.input.manifest} --kubeconfig ${self.input.kubeconfig_file}"
  }
}