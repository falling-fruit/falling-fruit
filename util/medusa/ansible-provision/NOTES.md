Notes for setting up a new dev environment for falling fruit

Using DigitalOcean to manage dev environments
------------------------------------------------
1. create an account and place some credit
2. add your ssh-key to the digitalocean account
3. use the do.py script to manage new boxes with ssh-key


Generate ssh-key if don't have one
----------------------------------
you might need to run your ssh-agent first (eval `ssh-agent -s`)

```bash
$ ssh-keygen -t rsa -C "your_email@example.com"
$ ssh-add ~/.ssh/id_rsa
```

Install Ansible and galaxy roles
---------------
```bash
$ sudo apt-add-repository ppa:rquillo/ansible
$ sudo apt-get update
$ sudo apt-get install ansible
$ sudo ansible-galaxy install Ansibles.postgresql
$ sudo ansible-galaxy install Ansibles.generic-users
```

edit your '/etc/ansible/hosts' file to contain your new machine


Falling Fruit Config update
---------------------------
1. update files/https.pem.example ->files/https.pem (or decrypt files https.pem.asc if it exists with gpg -d https.pem.asc)
2. update secret_vars.yml.example -> secret_vars.yml (or decrypt secret_vars.yml.asc if it exists with gpg -d secret_vars.yml.asc)

setup table
-----------

FIXME: this is out of date

```bash
$ bundle exec rake db:setup
```







NOTES
=====

1. make master
2. make slave
3. configure master to replicate to slave
4. configure slave to read from master
