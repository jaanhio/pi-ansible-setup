# Doing a simple ping
```
ansible -i ./inventory k8pis --private-key ~/.ssh/id_rsa.pi -m ping -u pi
```
`--private-key` and `-u` can be omitted if these have been set in the `[<groupname>:vars]` in `inventory` file.
e.g
```
[allpis:vars]
ansible_ssh_user=pi
ansible_ssh_private_key=~/.ssh/id_rsa.pi
```
In this case, command can be executed like this `ansible -i ./inventory k8pis -a "ls -la"`


# Executing using a module
The `-m` flag tells ansible to use an existing module.
`ping` belongs to [ansible-builtin](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/index.html#plugins-in-ansible-builtin).
Many other modules can be found at [collections](https://docs.ansible.com/ansible/latest/collections/index.html#list-of-collections).

---
### To see server specs
```
ansible -i ./inventory zero --private-key ~/.ssh/id_rsa.pi -m setup -u pi
```
Useful when writing playbook and need to know the specs of a server.

---
### To install apt package
```
ansible -f 1 -b --become-user root --become-method sudo -i ./inventory k8pis --private-key ~/.ssh/id_rsa.pi -m apt -a "name=vim state=present" -u pi -vvvv
```
By default `--become-user=root` and `--become-method=sudo` so these 2 flags can be removed.

---
### To check if a service is up
```
ansible -i ./inventory k8pis -b -m service -a "name=ntpd state=started enabled=yes"
```
More info can be found [here](https://docs.ansible.com/ansible/latest/collections/ansible/builtin/service_module.html#ansible-collections-ansible-builtin-service-module). 

---
### To see notes about module
```
ansible-docs <module-name> (e.g ansible docs apt)
```

# Executing using the default comamnd module
If `-m` flag is not provided, it will default to `command` module. The `-a` flag in this case supplies args for the `command` module, which is basically any command (e.g `ls -la`).


# Running any other command
```
ansible -i ./inventory k8pis --private-key ~/.ssh/id_rsa.pi -a "ls -la" -u pi
```

# Parallelized nature of Ansible
By default, Ansible run commands in parallel using multiple forks.
To disable it, one can add the `-f 1` flag to specify only one fork.
```
ansible -f 1 -i ./inventory k8pis --private-key ~/.ssh/id_rsa.pi -a "ls -la" -u pi
```

# Execute command on multiple groups
By creating a group postfixed with `children` (e.g `multi:children`), ansible knows that this inventory will contain multiple other groups.
```
ansible -i ./inventory mult --private-key ~/.ssh/id_rsa.pi -a "ls -la" -u pi
```

# Excute command only on specific hosts
Ansible has a `--limit` that matches regex OR particular group/host.
```
ansible -i ./inventory k8pis -a "df -h" --limit ~"*.167"
ansible -i ./inventory k8pis -a "df -h" --limit=192.168.1.167
ansible -i ./inventory k8pis -a "df -h" --limit k8pis
```
Above command will only match `192.168.1.167` in the `k8pis` group.

# Using timeout and poll for managing long running processes (e.g installing packages)
```
ansible -i ./inventory k8pis -b -B 3600 -P 0 -a "apt install -y tcpdump"
```
The task above will be running async in the background and terminal will return something like 
```
192.168.1.169 | CHANGED => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python"
    },
    "ansible_job_id": "497212072166.8258",
    "changed": true,
    "finished": 0,
    "results_file": "/root/.ansible_async/497212072166.8258",
    "started": 1
}
```
We can then use the `ansible_job_id` to check status of this job.
```
ansible -i ./inventory k8pis -b -m async_status -a "jid=497212072166.8258" --limit "192.168.1.169"
```

# To check what ansible knows about the current state of inventory
```
ansible-inventory -i ./inventory --list
```

# Using playbook
Playbook is essentially a set of instructions to execute on any particular host.
```
ansible-playbook -i inventory playbook.yaml
```

# Encrypting secrets using ansible-vault
This is usually done so that files with secrets can be uploaded to version control platform (e.g github) without exposing the secret.
```
ansible-vault encrypt ./debug/fake-api-key.yaml
```
Now when trying to run the playbook that uses the encrypted file, you will get this error.
```
ERROR! Attempting to decrypt but no vault secrets found
```
To be able to decrypt the value and use it when running playbook,
```
ansible-playbook -i ./inventory ./debug/playbook.yaml --ask-vault-pass
```

# Decrypting the secrete
Normally this is done so that maintainer of code can make changes to the secret BUT NOT RECOMMENDED.
```
ansible-vault decrypt ./debug/fake-api-key.yaml
```

# Editing secrets without decrypting it first
```
ansible-vault edit ./debug/fake-api-key.yaml
```
Upon input of correct password, ansible will open an editor (vim) to allow editing the content of secret.

# Change password of encryption
```
ansible-vault rekey ./debug/fake-api-key.yaml
```

# Running only specific tasks on playbook
Each task on playbook can be tagged. This tag can then be referenced when executing the playbook command.
```
- name: Print mac address
  debug:
    msg: '{{ ansible_facts.default_ipv4.macaddress }} - {{ ansible_facts.memtotal_mb }}'
  tags:
    - printmac
```
```
ansible-playbook -i ./inventory ./debug/playbook.yaml --tags=api
```

# Importing tasks from other files
As playbook grows, it gets unmanageable and it makes sense to split them into different modules and import as needed.

A `task` yaml file will only contain the fields needed in the `tasks` section of playbook.
```
---
- name: Print mac address
  debug:
    msg: '{{ ansible_facts.default_ipv4.macaddress }}'
```
Then import tasks via:
```
tasks:
  - import_tasks: another-external-task.yaml
```

# Ansible roles
This is a more maintainable way of sharing tasks between playbooks.
https://www.ansible.com/theres-a-role-for-that

# Testing in Ansible
Similar to unit testing in software development, the list of types of testing is sorted from lowest effort, lowest coverage all the way to the highest coverage, highest effort required.

* yamllint
* ansible-playbook --syntax-check
* ansible-lint
* molecule test (integration)
* ansible-playbook --check (against prod)
* Having a parallel infra to test things on

### Yamllint
```
pip3 install yamllint
yamllint <direct-file-path or folder-path>
```

### Ansible-playbook
```
ansible-playbook --syntax-check <path-to-playbook>
```

### Ansible-lint
```
pip3 install ansible-lint
ansible-lint <path-to-playbook>
```

### Ansible molecule
```
pip3 install molecule
```
Create a new role with molecule:
```
molecule init role myrole
```
A new `myrole` folder will be created.

A role contains a specific set of files as mentioned [here](https://docs.ansible.com/ansible/2.9/user_guide/playbooks_reuse_roles.html).
On top of the usual set of folders, there's also another folder called `molecule` with 1 `default` folder. This is where [scenarios](https://molecule.readthedocs.io/en/latest/getting-started.html#molecule-scenarios) are stored.

To create different scenarios within the same `molecule role`,
```
molecule init scenario <scenario-name> --driver-name docker
```
Molecule itself also has many different commands,
```
molecule --help
```

To run molecule commands, make sure the `/molecule` folder is children of current working directory
```
├── ansible-example
│   ├── README.md
│   ├── defaults
│   │   └── main.yml
│   ├── files
│   ├── handlers
│   │   └── main.yml
│   ├── meta
│   │   └── main.yml
│   ├── molecule
│   │   ├── default
│   │   │   ├── converge.yml
│   │   │   ├── molecule.yml
│   │   │   └── verify.yml
│   │   └── foo
│   │       ├── converge.yml
│   │       ├── molecule.yml
│   │       └── verify.yml
│   ├── tasks
│   │   └── main.yml
│   ├── templates
│   ├── tests
│   │   ├── inventory
│   │   └── test.yml
│   └── vars
│       └── main.yml
```
```
cd ansible-example
molecule test
```
To test it but leave container running for debugger:
```
molecule converge
```
Set a 'breakpoint' using `fail:` in the tasks
