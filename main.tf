###############################################################################
# tf_mod_aws_global_accelerator — main
#
# Keystone: aws_globalaccelerator_accelerator.this (2 anycast static IPs)
# Child resources: aws_globalaccelerator_listener.this (for_each map)
# aws_globalaccelerator_endpoint_group.this (for_each map)
#
# Only the accelerator is taggable; listeners and endpoint groups expose no tags
# argument. Endpoint groups wire back to their listener via each.value.listener_key.
###############################################################################

# --- Keystone: the accelerator ----------------------------------------------
resource "aws_globalaccelerator_accelerator" "this" {
 name = var.name
 ip_address_type = var.ip_address_type
 ip_addresses = var.ip_addresses
 enabled = var.enabled

 # Secure-by-default: flow logs are enabled whenever a destination bucket is
 # supplied (auditability). Omit flow_logs_s3_bucket to leave them off.
 dynamic "attributes" {
 for_each = var.flow_logs_s3_bucket != null ? [1]: []
 content {
 flow_logs_enabled = true
 flow_logs_s3_bucket = var.flow_logs_s3_bucket
 flow_logs_s3_prefix = var.flow_logs_s3_prefix
 }
 }

 tags = var.tags

 dynamic "timeouts" {
 for_each = length(var.timeouts) > 0 ? [var.timeouts]: []
 content {
 create = try(timeouts.value.create, null)
 update = try(timeouts.value.update, null)
 }
 }
}

# --- Listeners ----------------------------------------------------------------
resource "aws_globalaccelerator_listener" "this" {
 for_each = var.listeners

 accelerator_arn = aws_globalaccelerator_accelerator.this.arn
 protocol = each.value.protocol
 client_affinity = each.value.client_affinity

 dynamic "port_range" {
 for_each = each.value.port_ranges
 content {
 from_port = port_range.value.from_port
 to_port = port_range.value.to_port
 }
 }
}

# --- Endpoint groups ----------------------------------------------------------
resource "aws_globalaccelerator_endpoint_group" "this" {
 for_each = var.endpoint_groups

 listener_arn = aws_globalaccelerator_listener.this[each.value.listener_key].arn
 endpoint_group_region = each.value.endpoint_group_region

 health_check_interval_seconds = each.value.health_check_interval_seconds
 health_check_path = each.value.health_check_path
 health_check_port = each.value.health_check_port
 health_check_protocol = each.value.health_check_protocol
 threshold_count = each.value.threshold_count
 traffic_dial_percentage = each.value.traffic_dial_percentage

 dynamic "endpoint_configuration" {
 for_each = each.value.endpoints
 content {
 endpoint_id = endpoint_configuration.value.endpoint_id
 weight = endpoint_configuration.value.weight
 client_ip_preservation_enabled = endpoint_configuration.value.client_ip_preservation_enabled
 attachment_arn = try(endpoint_configuration.value.attachment_arn, null)
 }
 }

 dynamic "port_override" {
 for_each = each.value.port_overrides
 content {
 listener_port = port_override.value.listener_port
 endpoint_port = port_override.value.endpoint_port
 }
 }
}
