###############################################################################
# tf_mod_aws_global_accelerator — variables
#
# Composite module for AWS Global Accelerator: the accelerator (keystone, with
# its two anycast static IPs), its listeners, and its endpoint groups.
#
# Order: name (identity) -> required/optional accelerator config -> child
# collections (listeners, endpoint_groups) -> tags -> timeouts.
###############################################################################

variable "name" {
 description = <<-EOT
 The name of the Global Accelerator. Must contain only alphanumeric
 characters or hyphens, up to 64 characters.
 EOT
 type = string

 validation {
 condition = can(regex("^[a-zA-Z0-9-]{1,64}$", var.name))
 error_message = "name must be 1-64 characters and contain only alphanumeric characters or hyphens."
 }
}

variable "ip_address_type" {
 description = <<-EOT
 The IP address type for the accelerator. One of "IPV4" or "DUAL_STACK".
 FORCE-NEW — changing this re-creates the accelerator and its anycast IPs.
 Defaults to "IPV4".
 EOT
 type = string
 default = "IPV4"

 validation {
 condition = contains(["IPV4", "DUAL_STACK"], var.ip_address_type)
 error_message = "ip_address_type must be one of: IPV4, DUAL_STACK."
 }
}

variable "ip_addresses" {
 description = <<-EOT
 Optional BYOIP IPv4 addresses (1 or 2) to assign to the accelerator. When
 null, Global Accelerator assigns the two anycast static IPs automatically.
 FORCE-NEW — changing the supplied IP set re-creates the anycast IPs.
 EOT
 type = list(string)
 default = null

 validation {
 condition = var.ip_addresses == null ? true: (length(var.ip_addresses) >= 1 && length(var.ip_addresses) <= 2)
 error_message = "ip_addresses must be null or a list of 1 or 2 IPv4 addresses."
 }
}

variable "enabled" {
 description = <<-EOT
 Whether the accelerator is enabled. Defaults to true. Terraform must disable
 an accelerator before it can be deleted; the provider handles that transition
 on destroy.
 EOT
 type = bool
 default = true
}

variable "flow_logs_s3_bucket" {
 description = <<-EOT
 Name of the S3 bucket to receive Global Accelerator flow logs. When set, flow
 logs are ENABLED (auditability baseline); when null, flow logs are off.
 The bucket must already exist with a policy granting Global Accelerator write
 access. Wire from tf_mod_aws_s3_bucket.
 EOT
 type = string
 default = null
}

variable "flow_logs_s3_prefix" {
 description = <<-EOT
 Prefix (key path) for flow-log objects in flow_logs_s3_bucket. Only used when
 flow_logs_s3_bucket is set. Defaults to "flow-logs/".
 EOT
 type = string
 default = "flow-logs/"
}

variable "listeners" {
 description = <<-EOT
 Map of listeners keyed by a stable caller string. Each entry is one
 aws_globalaccelerator_listener. Endpoint groups reference a listener by this
 key (see endpoint_groups[*].listener_key).

 protocol - "TCP" or "UDP" (default "TCP")
 client_affinity - "NONE" (stateless five-tuple hash) or "SOURCE_IP"
 (two-tuple, source-IP stickiness). Default "NONE".
 port_ranges - one or more client-facing port ranges:
 from_port - first port, inclusive
 to_port - last port, inclusive
 EOT
 type = map(object({
 protocol = optional(string, "TCP")
 client_affinity = optional(string, "NONE")
 port_ranges = list(object({
 from_port = number
 to_port = number
 }))
 }))
 default = {}

 validation {
 condition = alltrue([for k, v in var.listeners: contains(["TCP", "UDP"], v.protocol)])
 error_message = "Each listener protocol must be one of: TCP, UDP."
 }

 validation {
 condition = alltrue([for k, v in var.listeners: contains(["NONE", "SOURCE_IP"], v.client_affinity)])
 error_message = "Each listener client_affinity must be one of: NONE, SOURCE_IP."
 }

 validation {
 condition = alltrue([for k, v in var.listeners: length(v.port_ranges) > 0])
 error_message = "Each listener must define at least one port range."
 }
}

variable "endpoint_groups" {
 description = <<-EOT
 Map of endpoint groups keyed by a stable caller string. Each entry is one
 aws_globalaccelerator_endpoint_group routing a listener's traffic to regional
 endpoints (ALB/NLB/EIP/EC2).

 listener_key - key into var.listeners this group belongs to (REQUIRED)
 endpoint_group_region - AWS Region of the endpoints. FORCE-NEW.
 Null uses the provider's region.
 health_check_interval_seconds - 10 or 30 (default 30)
 health_check_path - HTTP/HTTPS health-check path (e.g. "/health")
 health_check_port - health-check port; null uses the listener port
 health_check_protocol - "TCP", "HTTP", or "HTTPS" (default "TCP")
 threshold_count - consecutive checks to flip health state (default 3)
 traffic_dial_percentage - percent of traffic sent to this Region (default 100)
 endpoints - regional targets:
 endpoint_id - ALB/NLB ARN, EIP allocation id, or EC2 instance id
 weight - routing weight 0-255 (default 100)
 client_ip_preservation_enabled - preserve client source IP (ALB/EC2). Default false.
 attachment_arn - optional cross-account attachment ARN
 port_overrides - map a listener port to a different endpoint port:
 listener_port - port traffic arrives on at the accelerator
 endpoint_port - port to forward to on the endpoint
 EOT
 type = map(object({
 listener_key = string
 endpoint_group_region = optional(string)
 health_check_interval_seconds = optional(number, 30)
 health_check_path = optional(string)
 health_check_port = optional(number)
 health_check_protocol = optional(string, "TCP")
 threshold_count = optional(number, 3)
 traffic_dial_percentage = optional(number, 100)
 endpoints = optional(list(object({
 endpoint_id = string
 weight = optional(number, 100)
 client_ip_preservation_enabled = optional(bool, false)
 attachment_arn = optional(string)
 })), [])
 port_overrides = optional(list(object({
 listener_port = number
 endpoint_port = number
 })), [])
 }))
 default = {}

 validation {
 condition = alltrue([for k, v in var.endpoint_groups: contains(["TCP", "HTTP", "HTTPS"], v.health_check_protocol)])
 error_message = "Each endpoint group health_check_protocol must be one of: TCP, HTTP, HTTPS."
 }

 validation {
 condition = alltrue([for k, v in var.endpoint_groups: contains([10, 30], v.health_check_interval_seconds)])
 error_message = "Each endpoint group health_check_interval_seconds must be 10 or 30."
 }

 validation {
 condition = alltrue([for k, v in var.endpoint_groups: v.traffic_dial_percentage >= 0 && v.traffic_dial_percentage <= 100])
 error_message = "Each endpoint group traffic_dial_percentage must be between 0 and 100."
 }

 validation {
 condition = alltrue([for k, v in var.endpoint_groups: alltrue([for e in v.endpoints: e.weight >= 0 && e.weight <= 255])])
 error_message = "Each endpoint weight must be between 0 and 255."
 }

 validation {
 condition = alltrue([for k, v in var.endpoint_groups: contains(keys(var.listeners), v.listener_key)])
 error_message = "Each endpoint group listener_key must reference a key defined in var.listeners."
 }
}

variable "tags" {
 description = <<-EOT
 A map of tags to assign to the accelerator (the only taggable Global
 Accelerator resource — listeners and endpoint groups are not taggable).
 These merge with provider-level default_tags; resource tags win on key
 conflict. The computed tags_all output reflects the merged set.
 EOT
 type = map(string)
 default = {}
}

variable "timeouts" {
 description = <<-EOT
 Optional Terraform operation timeouts for the accelerator. The accelerator
 resource supports create and update only (no delete timeout).
 EOT
 type = object({
 create = optional(string)
 update = optional(string)
 })
 default = {}
}
