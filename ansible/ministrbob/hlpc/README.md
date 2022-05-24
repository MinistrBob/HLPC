# Ansible Collection - ministrbob.hlpc

Documentation for the collection.

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