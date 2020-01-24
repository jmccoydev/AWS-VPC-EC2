data "aws_availability_zones" "available" {
  provider = "aws"
  state    = "available"
}

# Create the Satellite VPC
resource "aws_vpc" "satellite" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "satellite"
  }
}

locals {
  # Generate the CIDRs for each subnet
  cidr_subnet_1 = "${cidrsubnet("10.0.0.0/16", 1, 0)}"
  cidr_subnet_2 = "${cidrsubnet("10.0.0.0/16", 1, 1)}"

  # Add all subnets to lists
  subnets = "${list(local.cidr_subnet_1, local.cidr_subnet_2)}"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.satellite.id}"

  tags = {
    Name = "satellite"
  }
}

resource "aws_subnet" "satellite" {
  provider                = "aws"
  count                   = "${length(local.subnets)}"
  vpc_id                  = "${aws_vpc.satellite.id}"
  cidr_block              = "${element(local.subnets, count.index)}"
  availability_zone       = "${element(data.aws_availability_zones.available.names, count.index % 2)}"
  map_public_ip_on_launch = false
  tags = {
    Name = "satellite-${count.index}"
  }
}

# Since we can't delete the VPC's default route table, configure it with no
# routes (i.e. null route)
resource "aws_default_route_table" "default" {
  provider               = "aws"
  default_route_table_id = "${aws_vpc.satellite.default_route_table_id}"
  tags = {
    Name = "default"
  }
}

# Create a route table with default routing through the TransitGW
resource "aws_route_table" "satellite" {
  provider = "aws"
  vpc_id   = "${aws_vpc.satellite.id}"
  route {
    cidr_block         = "0.0.0.0/0"
    gateway_id         = "${aws_internet_gateway.gw.id}"
  }
  tags = {
    Name = "satellite"
  }
}

# Associate the new route table with the subnets.
resource "aws_route_table_association" "satellite" {
  provider       = "aws"
  count          = "${length(local.subnets)}"
  route_table_id = "${aws_route_table.satellite.id}"
  subnet_id      = "${element(aws_subnet.satellite.*.id, count.index)}"
}

# Set default security group with no ingres/egress rules
resource "aws_default_security_group" "default" {
  provider = "aws"
  vpc_id   = "${aws_vpc.satellite.id}"
  tags = {
    Name = "default"
  }
}

# Create a basic security group allowing SSH and ICMP.
resource "aws_security_group" "basic" {
  provider    = "aws"
  name        = "basic"
  description = "Allow SSH and ICMP inbound; all outbound"
  vpc_id      = "${aws_vpc.satellite.id}"
  ingress {
    description = "Open communication within this security group"
    from_port   = 0
    to_port     = 0
    protocol    = -1
    self        = true
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # Wide open egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "basic"
  }
}

##################################################
# ENDPOINTS
##################################################

resource "aws_route53_resolver_endpoint" "outbound_forward" {
  name               = "outbound_forward"
  direction          = "OUTBOUND"
  security_group_ids = ["${aws_security_group.basic.id}"]

  dynamic "ip_address" {
    for_each = "${aws_subnet.satellite}"
    content {
      subnet_id = ip_address.value.id
      ip        = "${cidrhost(ip_address.value.cidr_block, 5)}"
    }
  }
}

resource "aws_route53_resolver_endpoint" "inbound_forward" {
  name               = "inbound_forward"
  direction          = "INBOUND"
  security_group_ids = ["${aws_security_group.basic.id}"]

  dynamic "ip_address" {
    for_each = "${aws_subnet.satellite}"
    content {
      subnet_id = ip_address.value.id
      ip        = "${cidrhost(ip_address.value.cidr_block, 6)}"
    }
  }
}

##################################################
# FORWARDING RULES
##################################################

resource "aws_route53_resolver_rule" "fwd" {
  domain_name          = "cas.org"
  name                 = "CAS"
  rule_type            = "FORWARD"
  resolver_endpoint_id = "${aws_route53_resolver_endpoint.outbound_forward.id}"

  target_ip {
    ip = "134.243.50.56"
  }

  target_ip {
    ip = "134.243.50.57"
  }

  target_ip {
    ip = "134.243.50.19"
  }
}

##################################################
# FORWARDING RULES ASSOCIATIONS
##################################################

resource "aws_route53_resolver_rule_association" "vpcforward" {
  resolver_rule_id = "${aws_route53_resolver_rule.fwd.id}"
  vpc_id           = "${aws_vpc.satellite.id}"
}
