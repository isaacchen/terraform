Steps:

1. Create a key pair locally with 'ssh-keygen -f ichen-tf' in your .ssh directory
2. Create .aws/credentials with [test_account] section that contains aws_access_key_id and aws_secret_access_key
3. terraform init
4. terraform appy

Known issues:
1. no vault
2. no userdata template to allow version change
3. no https with dns/cn/cert
4. local db
5. no DR
