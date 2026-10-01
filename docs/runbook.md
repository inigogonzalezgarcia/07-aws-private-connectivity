# Runbook: deploy, test, troubleshoot, destroy

## Before you start

- An AWS account where you may create VPCs, endpoints, a load balancer, EC2 instances, IAM roles and Route 53 zones. Use a sandbox account, not production.
- Terraform 1.7+ (or OpenTofu 1.8+), the AWS CLI, and the [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the CLI.
- Read [costs.md](costs.md): the lab costs about $0.11 per hour while it exists.

## Deploy

```bash
cd envs/lab
cp terraform.tfvars.example terraform.tfvars   # adjust region, CIDRs, name
terraform init
terraform plan -out tfplan                     # read it: no internet gateway, no NAT gateway, no public IP
terraform apply tfplan
terraform output test_commands
```

## Test the path

```bash
aws ssm start-session --target <client instance id> --region <region>
# inside the session:
getent hosts orders.internal.example          # private IPs of the endpoint ENIs, one per AZ
curl -s http://orders.internal.example:8080/health
# {"service": "orders-api", "az": "eu-west-1a", "path": "/health"}
curl -s --max-time 5 https://aws.amazon.com    # should fail: there is no route to the internet
```

The Session Manager agent can take a few minutes after the first boot to register. The service instance needs a minute or two before the NLB marks it healthy.

## Troubleshooting

| Symptom | Check |
|---|---|
| `getent hosts` returns nothing | Is the private zone associated with the consumer VPC? Resolver query logs (`/route53resolver/internal-example`) show the query and the answer. |
| The name resolves, `curl` hangs | Endpoint security group allows the client's subnet on 8080? Flow logs of the consumer VPC show `REJECT` for the client's IP. |
| `curl` is refused or times out after the endpoint | Endpoint connection state is `Available` (not `PendingAcceptance`)? NLB target healthy? Service security group allows the provider VPC CIDR? |
| `start-session` fails | SSM endpoints exist with private DNS on, client SG allows 443 to the VPC, the instance profile has `AmazonSSMManagedInstanceCore`. |

## Destroy

```bash
terraform destroy
```

Then check the console for leftovers in VPC → Endpoints and EC2 → Load Balancers in the lab region. Delete local `terraform.tfstate*` files when you are done; they contain resource IDs from your account.
