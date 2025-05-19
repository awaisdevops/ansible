# Ansible Integration with Jenkins Pipeline

This repository provides a guide to integrate Ansible into a Jenkins pipeline for automating infrastructure provisioning and server configurations. In this setup, instead of installing Ansible as a tool within Jenkins, we will install Ansible on a separate server and integrate it with the Jenkins pipeline.

### Technologies Used
- Ansible
- Jenkins
- DigitalOcean
- AWS
- Boto3
- Docker
- Java
- Maven
- Linux
- Git

### Project Description
- Create and configure a dedicated server for Jenkins
- Create and configure a dedicated server for Ansible Control Node
- Create 2 EC2 instances to be managed by Ansible
- Write Ansible Playbook, which configures 2 EC2 instances
- Add ssh key file credentials in Jenkins for Ansible Control Node server and Ansible Managed Node servers
- Configure Jenkins to execute the Ansible Playbook on remote Ansible Control Node server as part of the CI/CD pipeline
- So the Jenkinsfile configuration will do the following:
  - a. Connect to the remote Ansible Control Node server
  - b. Copy Ansible playbook and configuration files to the remote Ansible Control Node server
  - c. Copy the ssh keys for the Ansible Managed Node servers to the Ansible Control Node server 
  - d. Install Ansible, Python3 and Boto3 on the Ansible Control Node server
  - e. With everything installed and copied to the remote Ansible Control Node server, execute the
  playbook remotely on that Control Node that will configure the 2 EC2 Managed Nodes

## Steps for Integration:

### 1: Create a Dedicated Server for Jenkins
We're gonna reuse the same Jenkins server we already used in a couple of other demo projects (the one we created in module 8 on a DigitalOcean droplet).

- Login to your [DigitalOcean account](https://cloud.digitalocean.com/login) and create a new Droplet (Frankfurt, Ubuntu 22.04, Shared CPU Basic, Regular Disk Type SSD, 2GB / 2CPU / 60GB SSD) and give it the hostname 'ansible-control-node'.

### 2. Install Python Modules on Ansible Server
First, install the required Python modules (`boto3` and `botocore`) for interacting with AWS.

```bash
apt update
pip3 install boto3 botocore
python3 -c "import boto3; print(boto3.__version__)"
python3 -c "import botocore; print(botocore.__version__)"
```

### 3. Configure AWS Credentials on Ansible Server
Create the `.aws` directory in the home directory of the user executing Ansible on the server. Place your AWS credentials (`aws_access_key_id` and `aws_secret_access_key`) in the `credentials` file. This is essential for fetching AWS EC2 instance details using the dynamic inventory plugin `aws_ec2`.

```bash
~/.aws/credentials
```

### 4. Copy Configuration Files from Jenkins to Ansible Server
Our Jenkins pipeline will copy necessary files such as the target nodes' PEM file and Ansible configuration files to the Ansible server. 

The following files need to be included in your Git repository:
1. `ansible-playbook.yaml`
2. `inventory_aws_ec2.yaml`
3. `ansible.cfg`
4. Target node PEM/private key file

These files will be copied to the Ansible server by Jenkins during pipeline execution.

### 5. Jenkins Server Configuration

#### a. Install SSH Agent Plugin
The SSH Agent Plugin will allow Jenkins to copy files from the Jenkins server to the Ansible server using SCP and SSH.

1. Log in to Jenkins → **Manage Jenkins** → **Manage Plugins**
2. Search for **SSH Plugin** and install it.

#### b. Configure SSH Credentials for Ansible Server
1. Log in to Jenkins → **Manage Jenkins** → **Manage Credentials**
2. Add SSH credentials for the Ansible server with the necessary private key.

#### c. Convert SSH Key to Classic OpenSSH Format (if needed)
Ensure the SSH key used with Jenkins is in the classic OpenSSH format. Use the following command to convert it:

```bash
ssh-keygen -p -m PEM -f /path/to/your/private-key -P "" -N ""
```

#### d. Configure SSH Credentials for Target Nodes
1. Log in to Jenkins → **Manage Jenkins** → **Manage Credentials**
2. Add SSH credentials for the target nodes (e.g., EC2 instances) using their private key.

#### e. Install Credentials Binding Plugin
Install the **Credentials Binding Plugin** for securely handling credentials in Jenkins pipelines.

#### f. Configure GitHub/GitLab/Bitbucket Credentials (if required)
Configure Git credentials for connecting to repositories stored on GitHub, GitLab, or Bitbucket. You can add SSH keys or personal access tokens based on the repository host.

### 6. Create Jenkins Pipeline
Create a **Multibranch Pipeline** in Jenkins:

1. Log in to Jenkins → **New Item** → **Multibranch Pipeline**
2. Configure the pipeline with your repository information.
3. Configure additional settings like discovering branches and pull requests.
4. Save the pipeline.

### 7. Execute Ansible Playbook from Jenkins
Install the **SSH Pipeline Steps Plugin** to enable executing commands (including Ansible playbooks) remotely on the Ansible server.

1. Log in to Jenkins → **Manage Jenkins** → **Manage Plugins**
2. Search for **SSH Pipeline Steps Plugin** and install it.

## Jenkins Pipeline Script

Here’s the Jenkinsfile used to integrate Ansible with the Jenkins pipeline:

```groovy
pipeline {
    agent any

    environment {
        ANSIBLE_SERVER = "ansible_server_ip_address"
    }

    stages {
        stage("copy files to ansible server") {
            steps {
                script {
                    // Copying necessary files to the Ansible server
                    echo "copying all necessary files to Ansible control node"
                    sshagent(['ansible-server-key']) {
                        sh "scp -o StrictHostKeyChecking=no ansible/* root@${ANSIBLE_SERVER}:/root"

                        // Copying the target node's PEM file to Ansible server
                        withCredentials([sshUserPrivateKey(credentialsId: 'ec2-server-key', keyFileVariable: 'keyfile', usernameVariable: 'user')]) {
                            sh 'scp $keyfile root@$ANSIBLE_SERVER:/root/ssh-key.pem'
                        }
                    }
                }
            }
        }
        
        stage("execute ansible playbook") {
            steps {
                script {
                    echo "Calling Ansible playbook to configure EC2 instances"
                    def remote = [:]
                    remote.name = "ansible-server"
                    remote.host = ANSIBLE_SERVER
                    remote.allowAnyHosts = true

                    withCredentials([sshUserPrivateKey(credentialsId: 'ansible-server-key', keyFileVariable: 'keyfile', usernameVariable: 'user')]) {
                        remote.user = user
                        remote.identityFile = keyfile
                        sshCommand remote: remote, command: "ansible-playbook my-playbook.yaml"
                    }
                }
            }
        }
    }
}
```

## Ansible Configuration Files

### `ansible.cfg`

```ini
[defaults]
host_key_checking = False
inventory = inventory_aws_ec2.yaml
interpreter_python = /usr/bin/python3
enable_plugins = aws_ec2
remote_user = ec2-user
private_key_file = ~/ssh-key.pem
```

### `inventory_aws_ec2.yaml` (Dynamic Inventory for AWS EC2)

```yaml
plugin: aws_ec2
regions:
  - eu-west-3
keyed_groups:
  - key: tags
    prefix: tag
  - key: instance_type
    prefix: instance_type
```

### `my-playbook.yaml` (Ansible Playbook)

```yaml
---
- name: Install Python3 and Docker 
  hosts:  all
  become: yes #switching to root user
  gather_facts: false #it a module that runs initially. as it uses pyhthon3 that is not installed yes. we're skipping it
  tasks:
    - name: Install Python3 and Docker
      vars: #configuring Python2 as interpreter for yum
        ansible_python_interpreter: /usr/bin/python
      yum:
        name:
          - python3
          - docker
        update_cache: yes # yum update
        state: present # install latest packages
    
    - name: Install docker-compose
      get_url:
        curl: https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-{{lookup('pipe', 'uname -m')}}
        # accessing output of 'uname -m' shell command using lookup function that are ansible specific extensions to the jinja2 templating language  
        dest: /usr/local/bin/docker-compose #donwloading file in bin dir
        mode: +x # assigning execute permission
    
    # systemctl start doccker
    - name: Start docker daemon
      systemd: 
        name: docker
        state: started 

     # usermod -aG docker ec2-user
    - name: Add ec2-user to Group Docker
      user:
        name: ec2-user
        groups: docker
        append: yes
    - name: Reconnect to server session
      meta: reset_connection

    # pip install docker-py. docker python is a dependency b/w ansible and python on remote
    - name: Install docker python module
      pip:
        name: 
          - docker #docker python module dor docker
          - docker-compse #docker python module dor docker-compose

- name: Start docker container
  hosts:  docker_server
  vars_prompt: #interactive input: prompts
    - name: docker_password
      prompt: Enter message for docker your docker regostry #msg to display to user
  tasks:
    - name: copy docker-compose to remote node
      copy:
        src: /your/path/to/docker-compose.yaml
        dest: /home/ec2-user/docker-compose.yaml

    # logging to our private docker repository  
    - name: docker login
      docker_login:
        registry_url: https://index.docker.io/v1 #url for dockerhub.\
        username: <dockerHub_repo_name>
        password: "{{docker_password}}" #providing password as variable

    # docker compose -f /home/ec2-user/docker-compose.yaml up
    - name: Start container from compose
      docker_compose:
        project_src: /home/ec2-user
        state: present # "docker compose up", absent for "docker compose down"
```

---

### Conclusion

This setup enables the integration of Ansible with Jenkins to automate infrastructure provisioning and server configuration via a Jenkins pipeline. With this configuration, Jenkins will manage the process of copying files to the Ansible server and executing the Ansible playbook remotely. 

Make sure that all necessary credentials are set up and that your Ansible server is correctly configured for communication with AWS and your target servers.
