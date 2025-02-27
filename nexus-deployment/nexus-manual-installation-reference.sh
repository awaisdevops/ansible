-->> apt update
-->> apt install openjdk-8-jdk
-->> java -version
#install java 8 as its a dependency for nexus

-->> adduser nexus
#create user nexus.

-->> cd /opt/
-->> wget https://download.sonatype.com/nexus/3/nexus-3.68.0-04-java8-unix.tar.gz
-->> tar -zxvf nexus-3.68.0-04-java8-unix.tar.gz
#The Nexus package directory will be '/opt/nexus-3.68.0-04' that contains runtime and application of nexus.
-->> chown -R nexus:nexus sonatype-work/
-->> chown -R nexus:nexus nexus-3.68.0-04/
#change the ownership of both directories to the user and group 'nexus'

-->> vim /opt/nexus-3.68.0-04/bin/nexus.rc
#change the user to nexus user to run application using user nexus

-->> /opt/nexus-3.68.0-04/bin/nexus start
#starting nexus
