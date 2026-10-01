/**
 * Optional instances to prove the path end to end:
 *   client (consumer VPC, Session Manager) --> orders.<zone> --> interface endpoint
 *     --> PrivateLink --> internal NLB --> service instance (provider VPC)
 * Neither instance has a public IP, SSH key or internet route.
 */

data "aws_ssm_parameter" "al2023_arm64" {
  count = var.create_test_instances ? 1 : 0
  name  = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# --- Service instance (provider VPC) -----------------------------------------------------

resource "aws_security_group" "service" {
  count       = var.create_test_instances ? 1 : 0
  name        = "${var.name}-orders-service"
  description = "Service port from the NLB (inside the provider VPC) only"
  vpc_id      = module.provider_vpc.vpc_id
  tags        = { Name = "${var.name}-orders-service" }
}

resource "aws_vpc_security_group_ingress_rule" "service_from_nlb" {
  count             = var.create_test_instances ? 1 : 0
  security_group_id = aws_security_group.service[0].id
  description       = "Service port from the provider VPC (NLB nodes and health checks)"
  ip_protocol       = "tcp"
  from_port         = var.service_port
  to_port           = var.service_port
  cidr_ipv4         = module.provider_vpc.cidr_block
}

resource "aws_instance" "service" {
  count                       = var.create_test_instances ? 1 : 0
  ami                         = data.aws_ssm_parameter.al2023_arm64[0].value
  instance_type               = var.instance_type
  subnet_id                   = module.provider_vpc.private_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.service[0].id]
  associate_public_ip_address = false

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    encrypted = true
  }

  # A tiny HTTP service: answers with its name and AZ so you can see which target replied.
  user_data = <<-EOF
    #!/bin/bash
    cat > /usr/local/bin/orders-api.py <<'PY'
    import json, urllib.request
    from http.server import BaseHTTPRequestHandler, HTTPServer
    def az():
        token = urllib.request.urlopen(urllib.request.Request(
            "http://169.254.169.254/latest/api/token", method="PUT",
            headers={"X-aws-ec2-metadata-token-ttl-seconds": "60"}), timeout=2).read().decode()
        return urllib.request.urlopen(urllib.request.Request(
            "http://169.254.169.254/latest/meta-data/placement/availability-zone",
            headers={"X-aws-ec2-metadata-token": token}), timeout=2).read().decode()
    ZONE = az()
    class H(BaseHTTPRequestHandler):
        def do_GET(self):
            body = json.dumps({"service": "orders-api", "az": ZONE, "path": self.path}).encode()
            self.send_response(200); self.send_header("Content-Type", "application/json")
            self.end_headers(); self.wfile.write(body)
    HTTPServer(("0.0.0.0", ${var.service_port}), H).serve_forever()
    PY
    cat > /etc/systemd/system/orders-api.service <<'UNIT'
    [Unit]
    Description=Demo orders API
    After=network-online.target
    [Service]
    ExecStart=/usr/bin/python3 /usr/local/bin/orders-api.py
    Restart=always
    DynamicUser=yes
    [Install]
    WantedBy=multi-user.target
    UNIT
    systemctl daemon-reload
    systemctl enable --now orders-api
  EOF

  tags = { Name = "${var.name}-orders-service" }
}

# --- Client instance (consumer VPC, reachable only through Session Manager) ---------------

data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "client" {
  count              = var.create_test_instances ? 1 : 0
  name               = "${var.name}-client"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "client_ssm" {
  count      = var.create_test_instances ? 1 : 0
  role       = aws_iam_role.client[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "client" {
  count = var.create_test_instances ? 1 : 0
  name  = "${var.name}-client"
  role  = aws_iam_role.client[0].name
}

resource "aws_security_group" "client" {
  count       = var.create_test_instances ? 1 : 0
  name        = "${var.name}-client"
  description = "Test client: no inbound, outbound only to endpoints inside the VPC"
  vpc_id      = module.consumer_vpc.vpc_id
  tags        = { Name = "${var.name}-client" }
}

resource "aws_vpc_security_group_egress_rule" "client_https" {
  count             = var.create_test_instances ? 1 : 0
  security_group_id = aws_security_group.client[0].id
  description       = "HTTPS to AWS service endpoints (Session Manager)"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = module.consumer_vpc.cidr_block
}

resource "aws_vpc_security_group_egress_rule" "client_service" {
  count             = var.create_test_instances ? 1 : 0
  security_group_id = aws_security_group.client[0].id
  description       = "Service port to the PrivateLink endpoint"
  ip_protocol       = "tcp"
  from_port         = var.service_port
  to_port           = var.service_port
  cidr_ipv4         = module.consumer_vpc.cidr_block
}

resource "aws_instance" "client" {
  count                       = var.create_test_instances ? 1 : 0
  ami                         = data.aws_ssm_parameter.al2023_arm64[0].value
  instance_type               = var.instance_type
  subnet_id                   = module.consumer_vpc.private_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.client[0].id]
  iam_instance_profile        = aws_iam_instance_profile.client[0].name
  associate_public_ip_address = false

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = { Name = "${var.name}-client" }

  # Session Manager needs the endpoints before the agent starts.
  depends_on = [module.consumer_aws_endpoints]
}
