default:
  @just --list

# Path to the ansible-vault password file (override with the
# ANSIBLE_VAULT_PASSWORD_FILE environment variable). It lives outside the repo.
vault_pass := env_var_or_default("ANSIBLE_VAULT_PASSWORD_FILE", home_directory() / ".vault_pass")

# Install the Ansible collections required by the playbooks.
galaxy-install:
  ansible-galaxy collection install -r ansible/requirements.yml

# Dry run: show what would change without touching the router.
check:
  cd ansible && ansible-playbook router.yml --check --diff

# Apply the router playbook.
run:
  cd ansible && ansible-playbook router.yml

# Dry run for the access points (needs the vault password for the SSID/PSK).
aps-check:
  cd ansible && ANSIBLE_VAULT_PASSWORD_FILE="{{ vault_pass }}" ansible-playbook aps.yml --check --diff

# Apply the access point playbook.
aps-run:
  cd ansible && ANSIBLE_VAULT_PASSWORD_FILE="{{ vault_pass }}" ansible-playbook aps.yml
