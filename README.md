# AWS Private Connectivity (PrivateLink lab)

Terraform for publishing an internal service from one VPC to another **without any route between them and without the internet**: an internal Network Load Balancer behind a **VPC endpoint service**, an **interface endpoint** on the consumer side, a **private DNS name** in Route 53, and **security controls** that are written down and tested.

![CI](https://github.com/inigogonzalezgarcia/07-aws-private-connectivity/actions/workflows/ci.yml/badge.svg)

> This is a hands-on lab built while learning cloud networking in depth, not a copy of any production setup. Everything is generic and uses reserved names (`internal.example`).

## What you get

```
consumer VPC (no IGW, no NAT)                          provider VPC (no IGW, no NAT)
  client --DNS--> orders.internal.example
  client --8080--> interface endpoint ==PrivateLink==> endpoint service --> internal NLB --> service
                   (SG: client subnets)                (acceptance required,              (SG: provider VPC)
                                                        allowed principals)
```

| Module | Purpose |
|---|---|
| [`modules/network`](modules/network) | Private-only VPC across AZs, flow logs, locked default security group |
| [`modules/endpoint-service`](modules/endpoint-service) | Internal NLB published as a VPC endpoint service |
| [`modules/endpoint-consumer`](modules/endpoint-consumer) | Interface endpoint with a narrow security group |
| [`modules/private-dns`](modules/private-dns) | Private hosted zone, alias records, Resolver query logs |
| [`modules/service-endpoints`](modules/service-endpoints) | SSM endpoints (Session Manager without internet) and S3 gateway endpoint |
| [`envs/lab`](envs/lab) | Everything wired together, with optional test instances |

The full picture, with a diagram and a comparison with VPC peering and Transit Gateway, is in [ARCHITECTURE.md](ARCHITECTURE.md).

## Guard-rails

| Control | Enforced by |
|---|---|
| No internet gateway, NAT gateway or public IP anywhere | Not in the code; tests assert no instance gets a public IP |
| The service is offered to named principals only, never `"*"` | Variable validation (tested) |
| Each endpoint connection must be accepted by the provider | `acceptance_required = true` |
| Endpoint reachable only from the consumer's client subnets; `0.0.0.0/0` rejected | Security group + variable validation |
| Service reachable only from inside the provider VPC (the NLB) | Security group (tested) |
| Instances: IMDSv2 only, encrypted volumes, no SSH key, managed through Session Manager | Resource arguments (tested) |
| Every connection and DNS query is logged | VPC Flow Logs, Route 53 Resolver query logs |
| Default security group has no rules | `aws_default_security_group` |

## Check it without an AWS account

```bash
cd envs/lab
terraform init -backend=false
terraform validate
terraform test          # mocked AWS provider: no credentials, no cost
```

The tests check that the pieces are wired together (endpoint to service, alias to endpoint, accepter), that the instances are locked down, and that bad inputs (`"*"` as principal, invalid names) are rejected. CI runs these on every push, together with `terraform fmt` and [tfsec](https://github.com/aquasecurity/tfsec). Two tfsec findings are accepted on purpose; the reasons are in [docs/decisions.md](docs/decisions.md#10-accepted-scanner-findings).

## Deploy it (sandbox account)

```bash
cd envs/lab
cp terraform.tfvars.example terraform.tfvars
terraform init && terraform apply
terraform output test_commands     # Session Manager command and curl to orders.internal.example
terraform destroy                  # same day: the lab costs about $0.11/hour
```

Step-by-step test, troubleshooting table and clean-up: [docs/runbook.md](docs/runbook.md). Cost breakdown: [docs/costs.md](docs/costs.md).

## What has been verified, and what has not

- **Verified:** `fmt`, `validate`, the mocked tests (5 runs, all passing) and a tfsec scan with no open findings, using OpenTofu 1.10 and the AWS provider 5.70. CI runs the same checks with Terraform.
- **Not yet verified:** `apply` in a real AWS account. The design follows the AWS documentation for PrivateLink, NLB and Route 53, but until it has been applied and the `curl` in the runbook succeeds, treat it as untested against AWS.

## Roadmap

- Apply in a sandbox account and add the real `curl` output and flow-log samples to the runbook.
- Cross-account example: provider and consumer in different accounts, acceptance done by the provider.
- TLS on the NLB listener with an ACM private certificate.
- The same consumer side expressed as Crossplane resources, to compare with Terraform.
- Run the DNS and TCP probes from [project 08](https://github.com/inigogonzalezgarcia/08-edge-health-slo-monitor) against `orders.internal.example`.

## Customisation and contact

Want this adapted to your environment (cross-account PrivateLink, your naming and tagging standards, a landing-zone module, a review of an existing setup)? Get in touch:

- Email: [inigogonzalezgarcia@yahoo.es](mailto:inigogonzalezgarcia@yahoo.es)
- LinkedIn: [linkedin.com/in/igonzalez93](https://www.linkedin.com/in/igonzalez93)

## License

MIT
