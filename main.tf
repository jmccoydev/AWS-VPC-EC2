provider "aws" {
  region = "us-east-2"
  }

module "satellite_vpc" {
  source          = "./modules/satellite_vpc"
}

module "ec2" {
  source = "./modules/ec2"
}

