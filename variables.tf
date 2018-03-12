variable "aws_region" {
  default = "us-east-1"
}

variable "shared_credentials_file" {
  default = "~/.aws/credentials"
}

variable "aws_profile" {
  description = "admin credential for the test account"
  default = "test_account"
}

variable "aws_keypair_name" {
  description = "name the key after yourself for testing"
  default = "ichen-tf"
}

variable "public_key_path" {
  description = "public key path"
  default = "~/.ssh/ichen-tf.pub"
}

variable "teststr" {
  description = "string to indicate object is related to your test"
  default = "ictest"
}

variable "app" {
  default = "sonarqube"
}

variable "vpc_name_tag" {
  default = "CC4"
}

variable "az1" {
  default = "us-east-1d"
}

variable "az2" {
  default = "us-east-1e"
}

variable "ip_block" {
  default = "172.25"
}

variable "office1" {
  default = "38.140.26.74/32"
}

variable "office2" {
  default = "209.210.189.44/32"
}

variable "home1" {
  default = "98.237.252.96/32"
}

# amazon ami
variable "aws_amis" {
  default = {
    us-east-1 = "ami-97785bed"
    us-west-1 = ""
    us-west-2 = ""
  }
}


