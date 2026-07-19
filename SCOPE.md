# tf-mod-aws-global-accelerator — SCOPE

Composite module for AWS Global Accelerator. It owns the accelerator (with its two
anycast static IPs), the listeners, and the endpoint groups that route to regional
endpoints (ALB/NLB/EIP/EC2) — so a single module call produces a global,
fault-tolerant traffic-entry point aligned with the Casey's baseline.

- **Module type:** Composite
- **Primary resource (keystone):** `aws_globalaccelerator_accelerator.this`

## In-scope resources

The module manages the following (allow-list):

- `aws_globalaccelerator_accelerator` — keystone (provides 2 static anycast IPs)
- `aws_globalaccelerator_listener` — port/protocol listeners (`for_each` over `map(object(...))`)
- `aws_globalaccelerator_endpoint_group` — per-region endpoint groups + health checks (`for_each`)

## Out-of-scope resources (consumed by reference)

Referenced by `id`/`arn`, never created here:

- ALB/NLB endpoints — `arn` (from `tf-mod-aws-lb`)
- Elastic IP endpoints — allocation `id` (from `tf-mod-aws-elastic-ip`)
- EC2 instance endpoints — instance `id` (from `tf-mod-aws-ec2-instance`)
- S3 access-log bucket for flow logs — bucket name (from `tf-mod-aws-s3-bucket`)

## Consumes

| Input | Type | Source module |
|---|---|---|
| `endpoint_groups[*].endpoints[*].endpoint_id` | `string` (ALB/NLB ARN, EIP alloc id, instance id) | `tf-mod-aws-lb` / `tf-mod-aws-elastic-ip` / `tf-mod-aws-ec2-instance` |
| `flow_logs_s3_bucket` | `string` (bucket name) | `tf-mod-aws-s3-bucket` |

## Required IAM permissions

Least-privilege actions the Terraform identity needs:

| Action | Required for |
|---|---|
| `globalaccelerator:CreateAccelerator`, `globalaccelerator:DeleteAccelerator`, `globalaccelerator:DescribeAccelerator`, `globalaccelerator:UpdateAccelerator`, `globalaccelerator:UpdateAcceleratorAttributes` | Accelerator lifecycle + flow-log attrs |
| `globalaccelerator:CreateListener`, `globalaccelerator:DeleteListener`, `globalaccelerator:DescribeListener`, `globalaccelerator:UpdateListener` | Listener lifecycle |
| `globalaccelerator:CreateEndpointGroup`, `globalaccelerator:DeleteEndpointGroup`, `globalaccelerator:DescribeEndpointGroup`, `globalaccelerator:UpdateEndpointGroup` | Endpoint-group lifecycle |
| `globalaccelerator:TagResource`, `globalaccelerator:UntagResource`, `globalaccelerator:ListTagsForResource` | Tagging |
| `elasticloadbalancing:DescribeLoadBalancers`, `ec2:DescribeAddresses`, `ec2:DescribeInstances` | Resolving endpoint targets |
| `s3:PutBucketPolicy` (on the flow-log bucket) | Enabling flow logs to S3 (when configured) |

## AWS Prerequisites

- **Global / us-west-2 control plane.** Global Accelerator is a global service whose
  API is hosted in **us-west-2**; resources are created via a provider in that region.
  The accelerator itself is global (anycast). Do NOT add a `region` variable — use a
  provider alias if the caller's default region is not us-west-2.
- **No service-linked role** is required for Global Accelerator.
- **Endpoints must pre-exist:** ALB/NLB (`tf-mod-aws-lb`), EIP (`tf-mod-aws-elastic-ip`),
  or EC2 instances must exist and be referenced by ARN / id.
- **Client IP preservation** for ALB/EC2 endpoints requires the endpoint's security
  group to allow real client CIDRs (or the Global Accelerator managed prefix list
  `com.amazonaws.global.globalaccelerator`) — NOT the accelerator IPs. Preservation
  bypasses any allow-list keyed on the accelerator addresses. NLB endpoints preserve
  client IP inherently.
- **Flow logs (optional):** an S3 bucket with a policy granting Global Accelerator
  write access.
- **Quotas:** default 10 accelerators per account; 10 listeners per accelerator;
  10 endpoint groups per listener (raisable via Service Quotas).

## Emits

| Output | Description | Consumed by |
|---|---|---|
| `id` | Accelerator id (its ARN) | listener/endpoint-group wiring |
| `arn` | Accelerator ARN (`arn:aws:globalaccelerator::<acct>:accelerator/<uuid>`, no region segment) — cross-resource reference type | IAM policies, monitoring |
| `name` | Accelerator name | tagging, monitoring |
| `enabled` | Whether the accelerator is enabled | operational verification |
| `static_ip_addresses` | The two anycast static IPs | DNS A records, allow-listing |
| `dns_name` | Accelerator DNS name (`a…awsglobalaccelerator.com`) | Route 53 alias / CNAME |
| `dual_stack_dns_name` | IPv6/dual-stack DNS name | dual-stack DNS records |
| `hosted_zone_id` | Global Accelerator hosted zone id | Route 53 alias records |
| `ip_sets` | Full IP sets (`ip_addresses` + `ip_family`) | inspection / dual-stack wiring |
| `listener_ids` / `listener_arns` | Maps of listener key → id / ARN | endpoint-group references, inspection |
| `endpoint_group_ids` / `endpoint_group_arns` | Maps of endpoint-group key → id / ARN | monitoring, inspection |
| `tags_all` | All tags incl. provider `default_tags` | governance/audit |

## Provider gotchas

- **`ip_address_type` and supplied BYOIP `ip_addresses` are effectively FORCE-NEW** at
  the accelerator level; changing the IP set re-creates anycast IPs.
- **Listener `protocol` / `client_affinity` updates** can briefly disrupt connections.
- **Endpoint-group `endpoint_group_region` is FORCE-NEW** — moving a group between
  regions requires replacement.
- **`tags` vs `tags_all`.** `var.tags` flows to each resource's `tags`; `tags_all` is the
  computed merge of resource tags over provider `default_tags` (resource tags win).
- **`arn` is the cross-resource reference type** — `arn:aws:globalaccelerator::<acct>:accelerator/<uuid>`
  (global, no region segment); the accelerator `id` IS this ARN. Listener ARN:
  `…/accelerator/<uuid>/listener/<id>`; endpoint-group ARN: `…/listener/<id>/endpoint-group/<id>`.
- **Provider region:** because the API lives in us-west-2, document the
  `providers = { aws = aws.us_west_2 }` alias pattern; this is NOT a `region` variable.
- **Destroy ordering:** endpoint groups → listeners → accelerator; the accelerator must
  be disabled before deletion (Terraform handles the enabled→delete transition).

## Secure-by-default decisions

| Posture | Default | Opt-out |
|---|---|---|
| Accelerator enabled | `enabled = true` | `enabled = false` |
| Flow logs | enabled when an S3 bucket is supplied (auditability) | omit `flow_logs_s3_bucket` |
| Health checks | endpoint groups default to health checking with sane thresholds | tune per group |
| Client affinity | `NONE` (stateless) unless app requires source-IP stickiness | `SOURCE_IP` |
| TLS termination | terminated at the regional endpoint (ALB/NLB with ACM cert) | n/a — GA forwards L4 |

## Design decisions

- One composite owns the accelerator plus its listeners and endpoint groups so a global
  entry point is provisioned from a single call.
- Listeners and endpoint groups are `for_each` over `map(object(...))` keyed by a stable
  caller string — no `count` — so adding/removing one never re-indexes others.
- Regional endpoints (ALB/NLB/EIP) are referenced by ARN/id from sibling modules, keeping
  the blast radius to the Global Accelerator objects.
- TLS is terminated at the regional load balancer (Global Accelerator operates at L4),
  so certificate management stays in `tf-mod-aws-lb` / `tf-mod-aws-acm`.
