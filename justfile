default:
  @just --list

key host:
  cd ansible; \
  yq .wireguard_private_key "./inventory/host_vars/{{host}}.yml" \
  | ansible-vault decrypt

pubkey host:
  just prikey {{host}} | wg pubkey

genkey:
  cd ansible; \
  wg genkey \
  | ansible-vault encrypt_string --stdin-name 'wireguard_private_key'
