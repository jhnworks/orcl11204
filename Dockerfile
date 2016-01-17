#FROM this is the OS image whic is used as a base image. If it not avialable locally, it will be pulled from the central docker repo.
#oracle:6.6 means Oracle Linux Version 6.6. This serves as the base image on which all other this are built.
FROM    oraclelinux:6.6
#MAINTAINER; the maintainer of the new image, obviously
MAINTAINER JHNWORKS@GMAIL.COM
#RUN; the groups and user for hte oracle db (oinstall, dba, oracle) are created. this looks like a redudant step, as this is supposed
#to be done by the oracle-dbms-server-preinstall rpm. However, this does not work. By manually creating them this way, the asignment is alright
RUN groupadd -g 54321 oinstall
RUN groupadd -g 54322 dba
RUN groupadd -g 54323 oper
RUN groupadd -g 54327 asmdba
RUN groupadd -g 54328 asoper
RUN groupadd -g 54329 asadmin

RUN useradd -m -g oinstall -G oinstall,oper,asmadmin,dba -u 54321 oracle
#RUN; yum -y installs all the necessary packages.
RUN yum -y oracle-rdbms-server-11gR2-preinstall perl wget unzip
#RUNL /u01 is the directory in which the database sofware is installed
RUN mkdir /u01
#RUN; chown user:group is used to cange the user and group permissions of /u01
RUN chown oracle:oinstall /u01
#USER; this changes teh current user for the exection to 'oracle'
USER    oracle
#WORKDIRL this sets the work directory
WORKDIR /home/oracle
#ENV; this sets a few env. variables needed by the getMOSPatch.sh script
ENV mosUser=john.gnanamani@oracle.com mosPass=ASG9dcTG DownList=1,2
#RUN; this downloads a modified version of the getMOSPatch.sh script. The only monidcation made is the make the downloads pre-selected
#by settings the DownList environment variable
RUN wget https://raw.githubusercontent.com/jhnworks/orcl11204/master/getMOSPatch.sh
# RUN; downlaod the response file for this installation
RUN wget https://raw.githubusercontent.com/jhnworks/orcl11204/master/responsefile_oracle11204.rsp
#RUN; this echoes the language for the patches to download
RUN echo "226P;Linux x86-64" > /home/oracle/.getMOSPatch.sh.cfg
#RUNl sh /home/oracle/getMOSPatch.sh patch 13390677 runs getMOSPatch.sh and downloads file 1 &2 of patch 13390677, which is the full blown installation of
# oracle DB 11.2.0.4
RUN sh /home/oracle/getMOSPatch.sh patch=13390677
#RUN;Cleanup the zip files after they have been extracted
RUN unzip p13390677_112040_Linux-x86-64_1of7.zip
RUN unzip p13390677_112040_Linux-x86-64_2of7.zip
#RUN; cleanup to save space after they ahve been extracted
RUN rm -f p13390677_112040_Linux-x86-64_1of7.zip p13390677_112040_Linux-x86-64_2of7.zip
#RUN; runs the installer with templatle and few extra switches
RUN /home/oracle/database/runInstaller -silent -force -waitforcompletion -responsefile /home/oracle/responsefile_oracle11204.rsp -ignoresysprereqs -ignoreprereq
#RUN /home/oracle/database/runInstaller -silent -force -waitforcompletion -responsefile /home/oracle/responsefile_oracle12102.rsp -ignoresysprereqs -ignoreprereq
#USER;here we switch to root, because after instllation theere are two scruipts which needs to be run as root
USER root
#RUN; execute the mandatory scripts desired by Oracle
RUN /u01/app/oraInventory/orainstRoot.sh
RUN /u01/app/oracle/product/11.2.0.4/dbhome_1/root.sh -silent
#RUN; cleans up the getMOSPatch.sh script, the tempalte and database directory, which contains the db installation media
RUN rm -rf /home/oracle/responsefile_oracle12102.rsp /home/oracle/getMOSPatch.sh /home/oracle/database
#USER; change back to the oracle user
USER oracle
WORKDIR /home/oracle
#RUN;create a dir on which we hook the persistant sorage of the db
RUN mkdir -p /u01/app/oracle/data
#RUN; download manage-oracle.sh, themain script that set up the listener and the db
RUN wget https://raw.githubusercontent.com/jhnworks/orcl11204/master/manage-oracle.sh
#RUN; set the mode of the manage-oracle.sh SCRIPT to 700 (rwx for oracle user)
RUN chmod 700 /home/oracle/manage-oracle.sh
#RUN; download the database instllation template
RUN wget https://raw.githubusercontent.com/jhnworks/orcl11204/master/db_install.dbt
#EXPOSE; make port 1521 available externally
EXPOSE 1521
#CMD; make ~/manage-oracle.sh the main command (pid 1 in the container)
CMD /home/oracle/manage-oracle.sh
