provider "aws" {
  profile = "default"
}

data "aws_ssm_parameter" "ami_id" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

# It'll use the public Terrraform module (https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["ap-southeast-2a"]
  public_subnets = ["10.0.1.0/24"]
}


resource "aws_security_group" "my-sg" {
  vpc_id = module.vpc.vpc_id
  name   = join("_", ["sg", module.vpc.vpc_id])
  # it'll setup the ingress rules dynamically
  dynamic "ingress" {
    # loop the var files for each rule
    for_each = var.rules
    content {
      from_port   = ingress.value["port"]
      to_port     = ingress.value["port"]
      protocol    = ingress.value["proto"]
      cidr_blocks = ingress.value["cidr_blocks"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Terraform-Dynamic-SG"
  }
}

resource "aws_instance" "my-instance" {
  ami                         = data.aws_ssm_parameter.ami_id.value
  subnet_id                   = module.vpc.public_subnets[0]
  instance_type               = "t3.micro"
  security_groups             = [aws_security_group.my-sg.id]
  associate_public_ip_address = true
  # it'll check if the script.sh exists, if it's True the file will be executed. If it's False, pass the user_data parameter as null
  user_data = fileexists("script.sh") ? file("script.sh") : null
}