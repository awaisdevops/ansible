# Kubernetes Deployment with Ansible on AWS EKS

This repository contains an Ansible playbook for deploying an application to an AWS EKS (Elastic Kubernetes Service) cluster, along with the Terraform configurations to set up the required AWS infrastructure (VPC and EKS Cluster).

The following resources are provided:

- **Terraform Configurations**: For setting up the AWS VPC and EKS Cluster.
- **Ansible Playbook**: For deploying an NGINX application to the EKS cluster.
- **Kubernetes Configurations**: For deploying the application in a Kubernetes namespace.

## Prerequisites

Before running the playbook and infrastructure setup, ensure you have the following prerequisites:

- **Ansible**: Installed on your local machine:

  ```bash
  sudo apt update
  sudo apt upgrade -y
  sudo apt install -y software-properties-common
  sudo add-apt-repository ppa:ansible/ansible
  sudo apt update
  sudo apt install ansible -y
  ansible --version
  ```

- **AWS CLI**: Installed and configured with the necessary permissions to interact with your AWS EKS cluster.

  ```bash
  sudo apt update
  sudo apt install -y unzip
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
  aws --version
  ```

- **Terraform**: Installed for provisioning the infrastructure.

  ```bash
  sudo apt update
  sudo apt install -y wget gnupg software-properties-common
  wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg
  sudo apt update
  sudo apt install terraform
  terraform --version
  ```

- **Kubernetes CLI (kubectl)**: Installed to verify the deployment after running the playbook.

  ```bash
  sudo apt update
  sudo apt install -y apt-transport-https ca-certificates curl
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor > /usr/share/keyrings/kubernetes-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee 
  /etc/apt/sources.list.d/kubernetes.list
  sudo apt update
  sudo apt install -y kubectl
  kubectl version --client
  ```

- **Ansible Kubernetes Collection**: Make sure you have the Ansible Kubernetes collection installed.

  ```bash
  ansible-galaxy collection install kubernetes.core
  ```

## Terraform Infrastructure Provisioning

### 1. **Terraform Configuration Files**

The following Terraform files are provided to provision the infrastructure on AWS.

#### `eks-cluster.tf`

This Terraform file provisions the AWS EKS cluster and configures the Kubernetes provider for the cluster:

```hcl
provider "kubernetes" {
  load_config_file = "false"
  host = data.aws_eks_cluster.myapp-cluster.endpoint
  token = data.aws_eks_cluster_auth.myapp-cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.myapp-cluster.certificate_authority.0.data)
}

data "aws_eks_cluster" "myapp-cluster" {
  name = module.eks.cluster_id 
}

data "aws_eks_cluster_auth" "myapp-cluster" {
  name = module.eks.cluster_id
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.33.1"
  cluster_name = "myapp-eks-cluster"
  cluster_version = null
  vpc_id = module.myapp-vpc.vpc_id
  subnet_ids  = module.myapp-vpc.private_subnets
  tags = {
    environment = "development"
    application = "myapp"
  }
  self_managed_node_groups = [
    {
      instance_type = "t2.small"
      name = "worker-group-1"
      asg_desired_capacity = 2
    },
    {
      instance_type = "t2.medium"
      name = "worker-group-2"
      asg_desired_capacity = 1
    },
  ]
}
```

#### `vpc.tf`

This Terraform file sets up the VPC and subnets for the AWS EKS cluster:

```hcl
provider "aws" {
  region = "us-west-1"
}

variable vpc_cidr_block{}
variable private_subnet_cidr_blocks {}
variable public_subnet_cidr_blocks {}

data "aws_availability_zones" "azs" {}

module "myapp-vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.18.1"
  name = "myapp-vpc"
  cidr = var.vpc_cidr_block
  private_subnets = var.private_subnet_cidr_blocks 
  public_subnets = var.public_subnet_cidr_blocks
  azs = data.aws_availability_zones.azs.names
  enable_nat_gateway = true
  single_nat_gateway = true
  enable_dns_hostnames = true
  tags = {
    "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
  }
  public_subnet_tags = {
    "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
    "kubernetes.io/role/elb" = 1
  }
  private_subnet_tags = {
    "kubernetes.io/cluster/myapp-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb" = 1
  }
}
```

#### `terraform.tfvars`

The `terraform.tfvars` file defines the CIDR blocks for your VPC and subnets:

```hcl
vpc_cidr_block = "10.0.0.0/16"
private_subnet_cidr_blocks = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidr_blocks = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
```

### 2. **Provision AWS Infrastructure with Terraform**

Run the following commands to provision the AWS infrastructure:

```bash
terraform init
terraform apply
```

This will provision the following resources:

- A custom VPC with public and private subnets.
- An AWS EKS cluster with the necessary IAM roles and security groups.
- Self-managed node groups for the EKS cluster.

Once the Terraform infrastructure is created, the EKS cluster will be ready for deployment.

---

## Ansible Playbook for Deploying Application

### 1. **Ansible Configuration Files**

The following Ansible playbook is used to deploy an NGINX application to the AWS EKS cluster.

#### `deploy-to-k8s.yaml`

This playbook will create a namespace in the Kubernetes cluster and deploy the NGINX application defined in the `nginx-config.yaml` file.

```yaml
- name: Deploy app in new namespace
  hosts: localhost
  tasks:
    - name: Create k8s namespace
      k8s:
        name: may-app
        api_version: v1
        kind: Namespace
        state: present
        kubeconfig: ./kubeconfig_myapp_eks_cluster  # Authenticate to your AWS-eks cluster

    - name: Deploy nginx app
      k8s:
        source: ./nginx-config.yaml  # Deploying to k8s from config file
        state: present
        kubeconfig: ./kubeconfig_myapp_eks_cluster  # Authenticate to your AWS-eks cluster
        namespace: may-app  # Will use our created ns, will override ns in config file
```

#### `nginx-config.yaml`

This file defines the Kubernetes deployment and service for the NGINX application:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: nginx
  type: LoadBalancer
```

#### `kubeconfig_myapp_eks_cluster`

This file is used to authenticate to the AWS EKS cluster using the `aws eks get-token` command to fetch the authentication token:

```yaml
apiVersion: v1
kind: Config
clusters:
- name: myapp-cluster
  cluster:
    server: https://<cluster-endpoint>  # EKS cluster API server URL
    certificate-authority-data: <base64-encoded-certificate>  # Base64 encoded cluster certificate
contexts:
- name: myapp-cluster-context
  context:
    cluster: myapp-cluster
    user: myapp-cluster-user
    namespace: default
current-context: myapp-cluster-context
users:
- name: myapp-cluster-user
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws
      args:
        - "eks"
        - "get-token"
        - "--region"
        - "<region>"
        - "--cluster-name"
        - "<cluster-name>"
```

### 2. **Run the Ansible Playbook**

Execute the following Ansible command to deploy the NGINX application to your EKS cluster:

```bash
ansible-playbook deploy-to-k8s.yaml
```

This will:

- Create a new Kubernetes namespace (`may-app`).
- Deploy the NGINX application defined in the `nginx-config.yaml` file.
- Expose the NGINX application via a LoadBalancer service.

### 3. **Verify the Deployment**

After running the playbook, verify the NGINX deployment in your AWS EKS cluster:

```bash
kubectl get deployments -n may-app
kubectl get services -n may-app
```

You should see the NGINX deployment and the LoadBalancer service created.

---

## License

This project is licensed under the MIT License.
