# Using default VPC for simplicity, instead of creating a production-grade VPC setup with subnets, NAT, etc.

resource "aws_default_vpc" "this" {}
