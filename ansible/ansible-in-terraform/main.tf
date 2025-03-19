# Provider configuration for AWS
provider "aws" {
	region = "us-west-1"  # Specify the AWS region for the resources
}

# Variable declarations
variable vpc_cidr_block {}  # CIDR block for the VPC
variable subnet_cidr_block {}  # CIDR block for the subnet
variable avail_zone {}  # Availability zone for the subnet
variable env_prefix {}  # Prefix to be used for resource names
variable my_ip {}  # Your public IP address for security group ingress
variable instance_type {}  # Instance type for EC2 instance
variable public_key_location {}  # Path to the public SSH key for EC2 instance

# VPC resource creation
resource "aws_vpc" "myapp-vpc" {
    cidr_block = var.subnet_cidr_block  # CIDR block for the VPC
    tags = {
        Name = "${var.env_prefix}-vpc"  # Name tag for the VPC
    }
}

# Subnet resource creation
resource "aws_subnet" "myapp-subnet-1" {
    vpc_id = aws_vpc.myapp-vpc.id  # Reference to the VPC created above
    cidr_block = var.subnet_cidr_block  # CIDR block for the subnet
    availability_zone = var.avail_zone  # Availability zone for the subnet
    tags = {
        Name = "${var.env_prefix}-subnet-1"  # Name tag for the subnet
    }
}

# Route table resource creation
resource "aws_route_table" "myapp-route-table" {
    vpc_id = aws_vpc.myapp-vpc.id  # Reference to the VPC created above
    route {
        cidr_block = "0.0.0.0/0"  # Default route for all traffic
        gateway_id = aws_internet_gateway.myapp-igw.id  # Reference to the internet gateway
    }
    tags = {
        Name = "${var.env_prefix}-rtb"  # Name tag for the route table
    }
}

# Internet Gateway creation for outbound internet access
resource "aws_internet_gateway" "myapp-igw" {
    vpc_id = aws_vpc.myapp-vpc.id  # Reference to the VPC created above
    tags = {
        Name = "${var.env_prefix}-igw"  # Name tag for the internet gateway
    }
}

# Associating the route table with the subnet
resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id      = aws_subnet.myapp-subnet-1.id  # Reference to the subnet
  route_table_id = aws_route_table.myapp-route-table.id  # Reference to the route table
}

# Security Group configuration for controlling traffic to the instance
resource "aws_security_group" "myapp-sg" {
    name = "myapp-sg"  # Name of the security group
    vpc_id = aws_vpc.myapp-vpc.id  # Reference to the VPC

    ingress {
        from_port = 22  # Allow SSH on port 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.my_ip]  # Restrict to your IP address
    }

    ingress {
        from_port = 8080  # Allow HTTP (port 8080)
        to_port = 8080
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere
    }

    ingress {
        from_port = 443  # Allow HTTPS (port 443)
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere
    }

    ingress {
        from_port = 80  # Allow HTTP (port 80)
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere
    }

    egress {
        from_port = 0  # Allow all outbound traffic
        to_port = 0
        protocol = "-1"  # -1 means all protocols
        cidr_blocks = ["0.0.0.0/0"]  # Allow to any destination
        prefix_list_ids = []
    }

    tags = {
        Name = "${var.env_prefix}-sg"  # Name tag for the security group
    }
} 

# Data source to fetch the latest Amazon Linux AMI
data "aws_ami" "latest_amazon_linux_image" {
    most_recent = true  # Get the latest AMI
    owners = ["137112412989"]  # Amazon's official account ID
    filter {
        name = "name"
        values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]  # Filter by AMI name
    }

    filter {
        name = "virtualization-type"
        values = ["hvm"]  # Ensure the AMI supports hardware virtual machines
    }
}

# Output the AMI ID to use in other parts of the Terraform configuration
output "aws_ami_id" {
  value = data.aws_ami.latest_amazon_linux_image.id
}

# Key Pair creation for SSH access
resource "aws_key_pair" "ssh-key" {
    key_name = "server_key"  # Name of the SSH key
    public_key = "${file(var.public_key_location)}"  # Load the public key from the specified file
}

# EC2 instance creation using the latest AMI and other configurations
resource "aws_instance" "myapp-server" {
    ami = data.aws_ami.latest_amazon_linux_image.id  # Use the AMI from the data source
    instance_type = var.instance_type  # Instance type
    subnet_id = aws_subnet.myapp-subnet-1.id  # Reference to the subnet
    vpc_security_group_ids = [aws_security_group.myapp-sg.id]  # Attach the security group
    availability_zone = var.avail_zone  # Availability zone
    associate_public_ip_address = true  # Associate a public IP address with the instance
    key_name = aws_key_pair.ssh-key.key_name  # Use the SSH key for access

    tags = {
        Name = "${var.env_prefix}-server"  # Name tag for the instance
    }
}

# Local-exec provisioner to run Ansible playbook for server provisioning
#provisioner "local-exec" {
#    working_dir = "../ansible"  # Directory of the Ansible playbooks
#    command = "ansible-playbook --inventory ${self.public_ip}, --private-key ${var.ssh_key_private} --user ec2-user deploy-docker.yaml"  # Run the Ansible playbook
#}

# Null resource to trigger another provisioner after the instance is created
resource "null_resource" "configure_server" {
  triggers = {
    trigger = aws_instance.myapp-server.public_ip  # Trigger on the public IP of the instance
  }

  provisioner "local-exec" {
    working_dir = "../ansible"  # Directory of the Ansible playbooks
    command = "ansible-playbook --inventory ${aws_instance.myapp-server.public_ip}, --private-key ${var.ssh_key_private} --user ec2-user deploy-docker.yaml"  # Run the Ansible playbook
  }
}
