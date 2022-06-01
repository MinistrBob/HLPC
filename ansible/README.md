- Стендов может быть множество. Все сведения каждого стенда находятся в одном файле инвентаря это список групп, хостов и переменных.
Исключение составляют секретные переменные, которые нужно выделить в отдельный файл.



# Ansible Collection - ministrbob.hlpc

At the moment, the collection is designed to install Postgresql version starting from 12 and higher on the Astra Linux Special Edition 1.7 OS that corresponds to Debian 10 (Buster) or Ubuntu 18.04 (Bionic).  
In the future, you can easily modify this collection for other OS versions.  

Authentication method is "scram-sha-256" this is requirement pgpool2.  

# Clone git repo
cd ~
mkdir HLPC
cd HLPC/
git clone git@github.com:MinistrBob/HLPC.git

# Run playbook hlpc.yml
cd ~/HLPC/ansible/ministrbob/hlpc
-- Prepare inventory file (with postgresql parameters)
nano ia1
-- Prepare vars file
cp example-main_vars.yml main_vars.yml
cp example-secret_vars.yml secret_vars.yml
nano main_vars.yml
nano secret_vars.yml
-- Edit all templates of config files in subfolders "templates"
nano ./roles/postgresql/templates/...
nano ./roles/pgpool/templates/...

```
ansible-playbook -i inventory/standXX.yaml hlpc.yaml
```