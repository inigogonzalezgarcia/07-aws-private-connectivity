# What the lab costs

The lab is cheap per hour but **not free**, and the main costs are hourly. Run it, test it, destroy it the same day.

## Hourly charges

List prices for **US East (N. Virginia)** as published by AWS when this was written (October 2026). Other regions, including Ireland (the default here), are usually a little higher. Check the [PrivateLink](https://aws.amazon.com/privatelink/pricing/), [Elastic Load Balancing](https://aws.amazon.com/elasticloadbalancing/pricing/) and [EC2](https://aws.amazon.com/ec2/pricing/on-demand/) pricing pages, or the AWS Pricing Calculator, for your region before you apply.

| Item | How many in the lab | Unit price | Per hour |
|---|---|---|---|
| Interface endpoint ENIs (the orders endpoint in 2 AZs + 3 SSM endpoints in 2 AZs) | 8 | $0.01 per endpoint per AZ-hour | $0.080 |
| Network Load Balancer | 1 | $0.0225 per hour, plus $0.006 per NLCU-hour of use | ~$0.023 |
| t4g.nano test instances | 2 | about $0.0042 per hour | ~$0.008 |
| **Total** | | | **about $0.11 per hour** |

That is roughly **$2.70 per day**, or **about $80 a month** if you forget it.

## Small or usage-based charges

- **PrivateLink data processing:** $0.01 per GB through the endpoint. A few test requests cost nothing measurable.
- **Route 53 private hosted zone:** a monthly charge per zone. AWS does not charge for a zone deleted within 12 hours of creation.
- **CloudWatch Logs:** ingestion and storage of flow logs and DNS query logs. Tiny for a lab; retention is 30 and 14 days.
- **S3 gateway endpoint:** no charge.

## What is deliberately absent

No NAT gateway (it would be the most expensive item here), no internet gateway, no public IPv4 addresses (AWS charges for those by the hour too), no Transit Gateway.

## Turning it off

```bash
cd envs/lab
terraform destroy
```

Then check in the console (VPC → Endpoints, EC2 → Load Balancers) that nothing is left. To keep the network but stop most of the cost, set `create_test_instances = false` and remove the SSM endpoints, which are 6 of the 8 ENIs.
