provider "aws" {
  region = "us-east-2"
  }

module "project_satellite_vpc" {
  source          = "../../modules/satellite_vpc"
}

#module "project_cloudwatch_dashboard" {
#  source = "../../modules/cloudwatch_dashboard"
#}

module "project_ec2" {
  source = "../../modules/ec2"
}

