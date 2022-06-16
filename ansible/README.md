# Ansible Collection - ministrbob.hlpc
Эта коллекция предназначена для развёртывания кластера postgresql. Конфигурация Master - несколько Standby и автоматическое переключение одного из stanby серверов в master обеспечивают высокудю доступность HA. Такое переключение управляется с помощью pgpool2. Так же pgpool2 с помощью своих возможностей: пуллинг сессий, кэш запросов, кэш результатов запросов и т.п. обеспечивает высокую нагруженность HighLoad кластера.

ATTENTION: In the current implementation, the collection is designed to install Postgresql version starting from 12 and higher on the Astra Linux Special Edition 1.7 OS that corresponds to Debian 10 (Buster) or Ubuntu 18.04 (Bionic). For other OS or Postgresql versions, the collection needs to be modified.  

Authentication method for Postgresql is "scram-sha-256" this is requirement pgpool2.  

# Общие примечания
- Pgpool устанавливается из репозитория Postgresql.  

# Install collection
Нужно описать метод через ansible-galaxy install

## (Option 2) Clone git repo
cd ~
mkdir HLPC
cd HLPC/
git clone git@github.com:MinistrBob/HLPC.git

# Run playbook hlpc.yml for deploy cluster

- нужно настраивать c:\MyGit\HLPC\ansible\roles\postgresql\templates\ в соответствии с stand_name

cd ~/HLPC/ansible
-- Prepare inventory file (with postgresql parameters)
nano inventory/stand01.yml
-- Prepare vars file
cp example-secret_vars.yml secret_vars.yml
nano secret_vars.yml
-- Rename files. Instead of substitution {{ stand_name }}, insert the name of your stand from the invet file. And edit all templates of config files in subfolders "templates" the way you want
cp roles/postgresql/templates/pg_hba.conf.j2 roles/postgresql/templates/{{ stand_name }}.pg_hba.conf.j2
nano ./roles/postgresql/templates/...
nano ./roles/pgpool/templates/...

```
ansible-playbook -i inventory/standXX.yaml hlpc.yaml
```