# Ansible Docker Setup and Container Management

This project provides an **Ansible playbook** that deplys the application using docker-compose and automates the installation of **Python3**, **Docker**, and **Docker Compose**, as well as the management of Docker containers. This playbook is designed to work with a **docker_server** host, making it ideal for automating the setup of Docker environments across multiple servers.

## Overview

This project aims to:
1. Install **Python3**, **Docker**, and **Docker Compose** on a target server.
2. Start the **Docker** daemon and configure the server to allow the user to run Docker commands.
3. Authenticate and manage Docker containers using **docker-compose**.
4. Provide an interactive way to login to Docker Hub and manage private repositories.
5. Check if Docker is running properly after setup.

## Playbook Details

The playbook is divided into multiple parts:

### 1. **Install Python3 and Docker**
   - Installs Python3 and Docker on the target server using **yum**.
   - Downloads and installs **docker-compose**.
   - Starts the **Docker** daemon.
   - Adds the `ec2-user` to the `docker` group to allow the user to run Docker commands without `sudo`.
   - Installs the **docker-py** Python module, which is required for Ansible to interact with Docker.

### 2. **Start Docker Container**
   - Prompts the user for a **Docker registry password**.
   - Copies the `docker-compose.yml` file to the remote server.
   - Logs into the Docker registry using the credentials provided.
   - Starts the container using `docker-compose` from the copied `docker-compose.yml` file.

### 3. **Authenticate Docker Process**
   - Verifies that the Docker daemon is running on the remote server by checking the process status.

## Prerequisites

To use this playbook, ensure the following:
- You have **Ansible** installed on your local machine.
- You have a **Docker server** or target host configured.
- The target server should be running a **Linux-based OS** (e.g., Ubuntu, CentOS) and have access to the **internet** to download Docker and Docker Compose.

## Setup Instructions

1. **Clone the repository**:

   ```bash
   git clone https://github.com/awaisdevops/ansible.git
   cd ansible-docker-setup
   ```

2. **Modify Inventory File**:
   - Edit the `inventory.ini` file to include the `docker_server` host, which is the machine you want to configure.
   - Example:

     ```ini
     [docker_server]
     your-server-ip-or-hostname ansible_user=root ansible_ssh_private_key_file=<path_to_your_setver_private_key>
     ```

3. **Run the Playbook**:
   - Run the following Ansible command to execute the playbook:

     ```bash
     ansible-playbook -i inventory.ini playbook.yml
     ```

   This will install Docker, Docker Compose, and start the container using the provided `docker-compose.yml` file.

4. **Interactive Docker Login**:
   - During the execution of the playbook, you will be prompted for your **Docker registry password**. Enter your Docker Hub password (or the password for your private registry).

## Playbook Breakdown

### Install Python3 and Docker
```yaml
- name: Install Python3 and Docker
  hosts: docker_server
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

    - name: Install docker-compose
      get_url:
        url: https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-{{ lookup('pipe', 'uname -m') }}
        dest: /usr/local/bin/docker-compose
        mode: +x

    - name: Start docker daemon
      systemd:
        name: docker
        state: started

    - name: Add ec2-user to Group Docker
      user:
        name: ec2-user
        groups: docker
        append: yes

    - name: Reconnect to server session
      meta: reset_connection

    - name: Install docker python module
      pip:
        name:
          - docker
          - docker-compose
```

### Start Docker Container
```yaml
- name: Start docker container
  hosts: docker_server
  vars_prompt:
    - name: docker_password
      prompt: Enter your docker registry password
  tasks:
    - name: Copy docker-compose to remote node
      copy:
        src: docker-compose_file_location
        dest: docker-compose_paste_location_on_remote

    - name: Docker login
      docker_login:
        registry_url: https://index.docker.io/v1
        username: <your-user-name>
        password: "{{ docker_password }}"

    - name: Start container from compose
      docker_compose:
        project_src: /home/ec2-user
        state: present
```

### Authenticate Docker Process
```yaml
- name: Authenticate if docker is running
  hosts: docker_server
  tasks:
    - name: Checking docker process
      shell: ps aux | grep -i docker
      register: app_status
    - debug:
        msg: "{{ app_status.stdout_lines }}"
```

## License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to fork this repository, create a branch for your changes, and submit a pull request. If you find any issues or have suggestions, feel free to open an issue on GitHub.

## Acknowledgments

Thanks to the **Ansible** community for making automation simpler, and to **Docker** for providing an excellent platform for containerization.

---

Feel free to explore and modify the playbooks to suit your specific needs. If you have any questions or need assistance, don't hesitate to reach out!
```

### Key Sections of This README:
1. **Project Introduction**: Overview of what the repository contains and what it aims to do.
2. **Project Details**: Breaks down the key tasks the playbook performs.
3. **Prerequisites**: List of requirements for running the playbook.
4. **Setup Instructions**: Step-by-step guide to setting up and running the playbook.
5. **Playbook Breakdown**: Detailed example of the tasks defined in the Ansible playbook.
6. **License and Contributions**: Information about contributing to the project and the license under which it is shared.
