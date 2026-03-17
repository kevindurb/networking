pubkey host:
  cd ansible; \
  yq .wireguard_private_key "./inventory/host_vars/{{host}}.yml" \
  | ansible-vault decrypt \
  | wg pubkey

genkey:
  cd ansible; \
  wg genkey \
  | ansible-vault encrypt_string --stdin-name 'wireguard_private_key'
