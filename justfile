default:
  @just --list

# Install the Ansible collections required by the playbook.
galaxy-install:
  ansible-galaxy collection install -r ansible/requirements.yml

# Dry run: show what would change without touching the router.
check:
  cd ansible && ansible-playbook router.yml --check --diff

# Apply the playbook.
run:
  cd ansible && ansible-playbook router.yml
