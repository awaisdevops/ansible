# AWS Infrastructure Setup with Terraform and Ansible

This project provisions AWS infrastructure using **Terraform** and automatically configures an EC2 instance using **Ansible**. The infrastructure includes a Virtual Private Cloud (VPC), a subnet, security groups, an EC2 instance, and a route table with an internet gateway for internet access. The EC2 instance is provisioned with a Docker environment using Ansible.

## Project Overview

- **AWS VPC**: Creates a VPC with a specified CIDR block.
- **Subnet**: Creates a subnet within the VPC, with the specified availability zone.
- **Security Group**: Configures a security group to control traffic for SSH and HTTP/HTTPS access.
- **EC2 Instance**: Deploys an EC2 instance using the latest Amazon Linux AMI.
- **Ansible Integration**: After EC2 instance creation, an Ansible playbook (`deploy-docker.yaml`) is executed to configure the server (e.g., installing Docker and Docker Compose).

## Prerequisites

- **Terraform**: Install [Terraform](https://www.terraform.io/downloads) to run the infrastructure provisioning.
- **AWS Account**: An AWS account with access credentials to deploy resources.
- **Ansible**: Install [Ansible](https://www.ansible.com/) to manage server configuration.
- **SSH Key**: Ensure you have an SSH key for connecting to the EC2 instance.

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/your-username/your-repository.git
cd your-repository
```

### 2. Configure Variables

In the `terraform.tfvars` file, provide the required values:

```hcl
vpc_cidr_block       = "10.0.0.0/16"
subnet_cidr_block    = "10.0.1.0/24"
avail_zone           = "us-west-1a"
env_prefix           = "myapp"
my_ip                = "your-public-ip"
instance_type        = "t2.micro"
public_key_location  = "~/.ssh/id_rsa.pub"
ssh_key_private      = "~/.ssh/id_rsa"
```

### 3. Terraform Configuration

The following is the Terraform configuration that provisions the required resources:

#### `provider.tf`

```hcl
provider "aws" {
  region = "us-west-1"  # Specify the AWS region for the resources
}
```

#### `variables.tf`

```hcl
variable vpc_cidr_block {}
variable subnet_cidr_block {}
variable avail_zone {}
variable env_prefix {}
variable my_ip {}
variable instance_type {}
variable public_key_location {}
```

#### `main.tf`

```hcl
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

# Internet Gateway creation
resource "aws_internet_gateway" "myapp-igw" {
  vpc_id = aws_vpc.myapp-vpc.id  # Reference to the VPC created above
  tags = {
    Name = "${var.env_prefix}-igw"  # Name tag for the internet gateway
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

# Associating the route table with the subnet
resource "aws_route_table_association" "a-rtb-subnet" {
  subnet_id      = aws_subnet.myapp-subnet-1.id  # Reference to the subnet
  route_table_id = aws_route_table.myapp-route-table.id  # Reference to the route table
}

# Security Group configuration
resource "aws_security_group" "myapp-sg" {
  name = "myapp-sg"  # Name of the security group
  vpc_id = aws_vpc.myapp-vpc.id  # Reference to the VPC

  ingress {
    from_port   = 22  # Allow SSH on port 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]  # Restrict to your IP address
  }

  ingress {
    from_port   = 8080  # Allow HTTP (port 8080)
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere
  }

  ingress {
    from_port   = 443  # Allow HTTPS (port 443)
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere
  }

  ingress {
    from_port   = 80  # Allow HTTP (port 80)
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere
  }

  egress {
    from_port   = 0  # Allow all outbound traffic
    to_port     = 0
    protocol    = "-1"  # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]  # Allow to any destination
  }

  tags = {
    Name = "${var.env_prefix}-sg"  # Name tag for the security group
  }
}

# EC2 Instance creation
resource "aws_instance" "myapp-server" {
  ami                    = data.aws_ami.latest_amazon_linux_image.id  # Use the AMI from the data source
  instance_type          = var.instance_type  # Instance type
  subnet_id              = aws_subnet.myapp-subnet-1.id  # Reference to the subnet
  vpc_security_group_ids = [aws_security_group.myapp-sg.id]  # Attach the security group
  availability_zone      = var.avail_zone  # Availability zone
  associate_public_ip_address = true  # Associate a public IP address with the instance
  key_name               = aws_key_pair.ssh-key.key_name  # Use the SSH key for access

  tags = {
    Name = "${var.env_prefix}-server"  # Name tag for the instance
  }
}

# Data source to fetch the latest Amazon Linux AMI
data "aws_ami" "latest_amazon_linux_image" {
  most_recent = true  # Get the latest AMI
  owners      = ["137112412989"]  # Amazon's official account ID
  filter {
    name   = "name"
    values = ["amzn2-ami-kernel-5.10-hvm-*-x86_64-gp2"]  # Filter by AMI name
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]  # Ensure the AMI supports hardware virtual machines
  }
}

# Output the AMI ID
output "aws_ami_id" {
  value = data.aws_ami.latest_amazon_linux_image.id
}

# Key Pair creation for SSH access
resource "aws_key_pair" "ssh-key" {
  key_name   = "server_key"  # Name of the SSH key
  public_key = "${file(var.public_key_location)}"  # Load the public key from the specified file
}

# Provisioning with Ansible
resource "null_resource" "configure_server" {
  triggers = {
    trigger = aws_instance.myapp-server.public_ip  # Trigger on the public IP of the instance
  }

  provisioner "local-exec" {
    working_dir = "../ansible"  # Directory of the Ansible playbooks
    command = "ansible-playbook --inventory ${aws_instance.myapp-server.public_ip}, --private-key ${var.ssh_key_private} --user ec2-user deploy-docker.yaml"  # Run the Ansible playbook
  }
}
```

### 4. Initialize Terraform

Run the following command to initialize Terraform and download necessary providers.

```bash
terraform init
```

### 5. Apply the Configuration

Run the Terraform apply command to create the infrastructure:

```bash
terraform apply
```

Terraform will prompt for confirmation. Type `yes` to proceed.

### 6. Ansible Playbook (`deploy-docker.yaml`)

The Ansible playbook `deploy-docker.yaml` is used to configure the EC2 instance after it has been provisioned by Terraform. This playbook installs Python3, Docker, Docker Compose, and configures the server to run Docker containers.

Here is the content for `deploy-docker.yaml`:

```yaml
---
# Playbook to wait for SSH connection to be available on the target hosts


- name: Wait for SSH Connection
  hosts: all 
  gather_facts: false  # Skip gathering facts initially as we don't have Python3 installed yet

  tasks:
    - name: Ensure SSH port is open
      wait_for:  # Hold configuration until EC2 is up
        port: 22  # Check for port 22 (SSH)
        delay: 10  # Wait for 10 seconds before starting to check
        timeout: 100  # Timeout after 100 seconds if the port is not open
        search_regex: OpenSSH  # Ensure OpenSSH is running
        host: '{{ (ansible_ssh_host|default(ansible_host))|default(inventory_hostname) }}'

      vars:
        ansible_connection: local  # Use local connection type
        ansible_python_interpreter: /usr/bin/python  # Specify Python interpreter path

- name: Install Python3 and Docker 
  hosts: all
  become: yes
  gather_facts: false
  tasks:
    - name: Install Python3 and Docker
      vars:
        ansible_python_interpreter: /usr/bin/python
      yum:
        name:
          - python3
          - docker
        update_cache: yes
        state: present

    - name: Install Docker Compose
      get_url:
        url: "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-{{lookup('pipe', 'uname -m')}}"
        dest: /usr/local/bin/docker-compose
        mode: +x
    
    - name: Start Docker daemon
      systemd:
        name: docker
        state: started

    - name: Add ec2-user to Docker group
      user:
        name: ec2-user
        groups: docker
        append: yes

    - name: Reconnect to server session
      meta: reset_connection

    - name: Install Docker Python module
      pip:
        name:
          - docker
          - docker-compose

- name: Start Docker container
  hosts: docker_server
  vars_prompt:
    - name: docker_password
      prompt: Enter your Docker registry password
  tasks:
    - name: Copy docker-compose file to remote node
      copy:
        src: /opt/devops/ansible/docker-compose.yaml
        dest: /home/ec2-user/docker-compose.yaml

    - name: Docker login
      docker_login:
        registry_url: https://index.docker.io/v1
        username: awaisakram11199
        password: "{{docker_password}}"

    - name: Start container from Docker Compose
      docker_compose:
        project_src: /home/ec2-user
        state: present
```

---
