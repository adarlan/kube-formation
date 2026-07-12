terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.53"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "4.3.0"
    }
  }
}
