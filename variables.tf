variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "master_os" {
  description = "OS type for the Ansible master (ubuntu or amazon-linux)"
  type        = string
  default     = "ubuntu"
}

variable "master_instance_type" {
  description = "Instance type for Ansible master"
  type        = string
  default     = "t2.micro"
}

variable "ubuntu_slave_count" {
  description = "Number of Ubuntu slave nodes"
  type        = number
}

variable "amazon_slave_count" {
  description = "Number of Amazon Linux slave nodes"
  type        = number
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "ami_map" {
  description = "Mapping of OS to AMI"
  type        = map(string)
  default = {
    "ubuntu"       = "ami-084568db4383264d4"
    "amazon-linux" = "ami-00a929b66ed6e0de6"
  }
}

variable "slave_instance_type" {
  description = "Instance type for all slaves"
  type        = string
  default     = "t2.micro"
}