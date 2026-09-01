# =============================================================================
# Network: one VPC, public subnets (ALB + NAT) and private subnets (ECS / RDS /
# Redis) across two AZs. NAT lets the private tasks reach the SES API and pull
# images; nothing in private subnets is publicly reachable.
# =============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # /16 VPC carved into /20 subnets.
  public_subnet_cidrs  = [cidrsubnet(var.vpc_cidr, 4, 0), cidrsubnet(var.vpc_cidr, 4, 1)]
  private_subnet_cidrs = [cidrsubnet(var.vpc_cidr, 4, 8), cidrsubnet(var.vpc_cidr, 4, 9)]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project_name}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project_name}-igw" }
}

# ---- Subnets ----------------------------------------------------------------
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project_name}-public-${local.azs[count.index]}", Tier = "public" }
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.project_name}-private-${local.azs[count.index]}", Tier = "private" }
}

# ---- NAT (intentionally omitted) --------------------------------------------
# This AWS account is at its Elastic IP cap (~20, all associated to other
# projects), so a NAT gateway can't allocate an EIP. Instead the Fargate tasks
# run in PUBLIC subnets with a public IP for egress (inbound stays locked to the
# ALB via security group; see ecs.tf). RDS/Redis remain in private subnets and
# need only local VPC routing. Bonus: saves the ~$32/mo NAT gateway cost.
# (var.nat_per_az is retained but unused; re-introduce NAT here if you later
# raise the EIP quota and want private egress.)

# ---- Route tables -----------------------------------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project_name}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count  = 2
  vpc_id = aws_vpc.main.id
  # Local VPC routing only — RDS/Redis need no internet egress.
  tags = { Name = "${var.project_name}-private-rt-${count.index}" }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
