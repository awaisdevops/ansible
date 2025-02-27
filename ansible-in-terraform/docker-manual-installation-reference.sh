-->> yum update 
-->> yum install docker -y
-->> yum install python3 -y
-->> systemctl start docker 
-->> usermod -aG docker ec2-user
#
-->> yum install python3
#updating yum repo cache and installing docker and python3

-->> curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
-->> chmod +x /usr/local/bin/docker-compose
# install docker-compose 

