# Ansible Collection - ministrbob.hlpc

At the moment, the collection is designed to install Postgresql version starting from 12 and higher on the Astra Linux Special Edition 1.7 OS that corresponds to Debian 10 (Buster) or Ubuntu 18.04 (Bionic).  
In the future, you can easily modify this collection for other OS versions.  

# Clone git repo
cd ~
mkdir HLPC
cd HLPC/
git clone git@github.com:MinistrBob/HLPC.git

# Run playbook hlpc.yml
-- Prepare vars file
cd ~/HLPC/ansible/ministrbob/hlpc
cp example-main_vars.yml main_vars.yml
cp example-secret_vars.yml secret_vars.yml
nano main_vars.yml
nano secret_vars.yml
-- 
