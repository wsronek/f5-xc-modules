resource "google_compute_network" "slo_vpc_network" {
  name                    = "${var.network_name}-slo-vpc-network"
  auto_create_subnetworks = var.auto_create_subnetworks
}

resource "google_compute_network" "sli_vpc_network" {
  count                   = var.f5xc_ce_gateway_type == var.f5xc_ce_gateway_type_ingress_egress ? 1 : 0
  name                    = "${var.network_name}-sli-vpc-network"
  auto_create_subnetworks = var.auto_create_subnetworks
}

resource "google_compute_subnetwork" "slo_subnet" {
  name          = "${var.network_name}-slo-subnetwork"
  ip_cidr_range = var.fabric_subnet_outside
  region        = var.gcp_region
  network       = google_compute_network.slo_vpc_network.id
}

resource "google_compute_subnetwork" "sli_subnet" {
  count         = var.f5xc_ce_gateway_type == var.f5xc_ce_gateway_type_ingress_egress ? 1 : 0
  name          = "${var.network_name}-sli-subnetwork"
  ip_cidr_range = var.fabric_subnet_inside
  region        = var.gcp_region
  network       = google_compute_network.sli_vpc_network[0].id
}

resource "google_compute_firewall" "slo_ingress" {
  name    = "${var.network_name}-slo-ingress"
  network = google_compute_network.slo_vpc_network.name

  dynamic "allow" {
    for_each = var.f5xc_slo_ingress_allow
    content {
      protocol = allow.value.protocol
      ports    = allow.value.ports
    }
  }
  target_tags   = var.f5xc_slo_ingress_target_tags
  source_ranges = var.f5xc_slo_ingress_source_ranges
}

resource "google_compute_firewall" "sli_ingress" {
  count   = var.f5xc_ce_gateway_type == var.f5xc_ce_gateway_type_ingress_egress ? 1 : 0
  name    = "${var.network_name}-sli-ingress"
  network = google_compute_network.sli_vpc_network[0].name
  allow {
    protocol = "all"
  }
  target_tags   = var.f5xc_sli_ingress_target_tags
  source_ranges = var.f5xc_sli_ingress_source_ranges
}

resource "google_compute_firewall" "slo_egress" {
  name    = "${var.network_name}-slo-egress"
  network = google_compute_network.slo_vpc_network.name
  allow {
    protocol = "all"
  }
  direction          = "EGRESS"
  target_tags        = var.f5xc_slo_egress_target_tags
  destination_ranges = var.f5xc_slo_egress_source_ranges
}

resource "google_compute_firewall" "sli_egress" {
  count   = var.f5xc_ce_gateway_type == var.f5xc_ce_gateway_type_ingress_egress ? 1 : 0
  name    = "${var.network_name}-sli-egress"
  network = google_compute_network.sli_vpc_network[0].name
  allow {
    protocol = "all"
  }
  direction          = "EGRESS"
  target_tags        = var.f5xc_sli_egress_target_tags
  destination_ranges = var.f5xc_sli_egress_source_ranges
}