Bootstrap command:

```bash
ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook playbooks/bootstrap.yaml \
  -i inventory/prod -l eroc \
  -e ansible_user=temp \
  -k -K
```
