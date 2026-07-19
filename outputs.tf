###############################################################################
# tf_mod_aws_global_accelerator — outputs
#
# Primary outputs id + arn + tags_all, plus the accelerator-specific computed
# attributes callers need to wire DNS, allow-lists, and endpoint groups.
###############################################################################

output "id" {
 description = "The ID (ARN) of the accelerator."
 value = aws_globalaccelerator_accelerator.this.id
}

output "arn" {
 description = "The ARN of the accelerator — the cross-resource reference type (IAM policies, monitoring, listeners)."
 value = aws_globalaccelerator_accelerator.this.arn
}

output "name" {
 description = "The name of the accelerator."
 value = aws_globalaccelerator_accelerator.this.name
}

output "enabled" {
 description = "Whether the accelerator is enabled."
 value = aws_globalaccelerator_accelerator.this.enabled
}

output "dns_name" {
 description = "The DNS name of the accelerator (e.g. a1234567890abcdef.awsglobalaccelerator.com). Point a Route 53 alias or CNAME here."
 value = aws_globalaccelerator_accelerator.this.dns_name
}

output "dual_stack_dns_name" {
 description = "The dual-stack DNS name resolving to the accelerator's IPv4 and IPv6 anycast addresses (set when ip_address_type is DUAL_STACK)."
 value = aws_globalaccelerator_accelerator.this.dual_stack_dns_name
}

output "hosted_zone_id" {
 description = "The Global Accelerator hosted zone id — used as zone_id for a Route 53 alias record targeting the accelerator."
 value = aws_globalaccelerator_accelerator.this.hosted_zone_id
}

output "static_ip_addresses" {
 description = "The flattened list of anycast static IP addresses assigned to the accelerator (two per IP set). Use for DNS A records and allow-listing."
 value = flatten(aws_globalaccelerator_accelerator.this.ip_sets[*].ip_addresses)
}

output "ip_sets" {
 description = "The full IP address sets associated with the accelerator (each with ip_addresses and ip_family)."
 value = aws_globalaccelerator_accelerator.this.ip_sets
}

output "listener_ids" {
 description = "Map of listener key => listener ARN/id."
 value = { for k, v in aws_globalaccelerator_listener.this: k => v.id }
}

output "listener_arns" {
 description = "Map of listener key => listener ARN."
 value = { for k, v in aws_globalaccelerator_listener.this: k => v.arn }
}

output "endpoint_group_ids" {
 description = "Map of endpoint-group key => endpoint-group ARN/id."
 value = { for k, v in aws_globalaccelerator_endpoint_group.this: k => v.id }
}

output "endpoint_group_arns" {
 description = "Map of endpoint-group key => endpoint-group ARN."
 value = { for k, v in aws_globalaccelerator_endpoint_group.this: k => v.arn }
}

output "tags_all" {
 description = "All tags on the accelerator, including those inherited from provider default_tags (resource tags win on key conflict)."
 value = aws_globalaccelerator_accelerator.this.tags_all
}
