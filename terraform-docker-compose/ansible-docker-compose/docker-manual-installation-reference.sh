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

-->> pip install docker-py
#docker python is a dependency b/w ansible and python on remote

-->> cp docker-compose_file_location docker-compose_paste_location_on_remote
#copy docker-compose.yaml file from local to remote

-->> docker login
#login to your docker repo where docker image resides

-->> docker compose -f docker-compose_paste_location_on_remote  up
#run the application 

-->> ps aux | grep -i docker
#checking docker process


