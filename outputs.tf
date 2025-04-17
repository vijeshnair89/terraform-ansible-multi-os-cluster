
output "master_ip" {
  value = aws_instance.ansible_master.public_ip
}

output "ubuntu_slave_ips" {
  value = [
    for ip in aws_instance.ubuntu_slaves[*].public_ip :
    "Ubuntu Slave IP: ${ip}"
  ]
}

output "amazon_slave_ips" {
  value = [
    for ip in aws_instance.amazon_slaves[*].public_ip :
    "Amazon Linux Slave IP: ${ip}"
  ]
}


