# Design decisions

## 1. Private-only networks

**Decision.** Neither VPC has an internet gateway or a NAT gateway. Instances have no public IP and no SSH key; the client is reached through Session Manager over VPC endpoints.

**Why.** The point of the lab is to show that a service can be consumed with no path to or from the internet at all. It also removes the largest hourly cost (NAT) and the most common misconfiguration (a public subnet that should not exist).

**Consequence.** Instances cannot install packages from the internet. The demo service uses only Python from the base image.

## 2. One service, one direction

**Decision.** PrivateLink instead of VPC peering or a Transit Gateway.

**Why.** Consumers only need one port of one service. PrivateLink exposes exactly that, connections can only start from the consumer side, and the provider decides who may connect. Peering or a Transit Gateway would connect whole networks and need route and firewall rules on both sides to narrow them down again.

## 3. Acceptance required, explicit principals

**Decision.** The endpoint service requires acceptance and lists allowed principals. `"*"` is rejected by variable validation (both in the module and in the lab).

**Why.** "Who can connect to this service?" should have an answer you can read in code and in review. In the lab the provider accepts its own consumer with `aws_vpc_endpoint_connection_accepter`; across accounts, accepting is the provider team's decision.

## 4. Our own DNS name instead of the endpoint's private DNS

**Decision.** `private_dns_enabled = false` on the interface endpoint, and a Route 53 private hosted zone with an alias record (`orders.internal.example`).

**Why.** Endpoint-service private DNS needs a public domain the provider has verified, which a lab does not have. A private zone also gives the consumer a stable name: if the provider rebuilds the service and the endpoint changes, only the alias moves. `.example` is reserved (RFC 2606), so the name can never collide with a real domain.

## 5. Security groups as narrow as the clients

**Decision.** The endpoint admits the service port from the consumer's private subnets only, and has no egress rules. The service instance admits the port from the provider VPC only, which is where the NLB's traffic and health checks come from. The test client may only open connections to addresses inside its own VPC.

**Why.** Every rule names a reason. A reviewer can check each one against the diagram.

## 6. Two AZs minimum, cross-zone on

**Decision.** Subnets, endpoint ENIs and NLB nodes in at least two AZs, and cross-zone load balancing on.

**Why.** An interface endpoint in one AZ is a single point of failure. Cross-zone balancing lets a consumer in one AZ reach healthy targets in any AZ.

**Trade-off.** Cross-zone traffic can incur inter-AZ data transfer charges; negligible in a lab, worth measuring in production.

## 7. Logs that answer the first incident questions

**Decision.** VPC Flow Logs for both VPCs and Route 53 Resolver query logs for the consumer.

**Why.** The first two questions in any "can't reach the service" incident are "does the name resolve?" and "is the connection rejected?". Both have a log here before the incident happens.

## 8. Tests without credentials

**Decision.** `terraform test` with a mocked AWS provider, run in CI on every push, plus `terraform validate`, `terraform fmt` and tfsec.

**Why.** Anyone can run the checks without an AWS account, and guard-rails (no public IPs, IMDSv2, encrypted volumes, narrow security groups, no wildcard principals) are asserted rather than just written down.

**Limit.** Mocked tests check the configuration's logic, not AWS's behaviour. Only `terraform apply` in a real account proves the path works; see the [runbook](runbook.md).

## 9. Accepted scanner findings

| Finding (tfsec) | Decision |
|---|---|
| CloudWatch log groups not encrypted with a customer-managed key | Log data is encrypted at rest by CloudWatch by default. Both modules accept `kms_key_id` for a customer-managed key (the key policy must allow the CloudWatch Logs service). |
| Wildcard in the flow-log IAM policy | The resource is `<this log group ARN>:*`, i.e. the streams inside one log group, which is what `CreateLogStream` and `PutLogEvents` act on. |

Each is suppressed inline with a comment next to the resource.
