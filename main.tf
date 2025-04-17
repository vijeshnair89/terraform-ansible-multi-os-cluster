## Security group
resource "aws_security_group" "ssh_sg" {
  name        = "allow_ssh"
  description = "Allow SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create ansible master
resource "aws_instance" "ansible_master" {
  ami           = var.ami_map[var.master_os]
  instance_type = var.master_instance_type
  key_name      = var.key_name
  vpc_security_group_ids      = [aws_security_group.ssh_sg.id]
  associate_public_ip_address = true
  tags = { Name = "Ansible-Master" }

# Login to master and generate keys and install ansible
  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y || sudo apt update -y",
      "sudo yum install -y openssh-server || sudo apt install -y openssh-server",
      "sudo yum install -y ansible || sudo apt install -y ansible",
      "ssh-keygen -t rsa -f ~/.ssh/id_rsa -q -N ''",
      "cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys"
    ]

    connection {
      type        = "ssh"
      user        = var.master_os == "ubuntu" ? "ubuntu" : "ec2-user"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }

# Get the public key from master to the local machine 
  provisioner "local-exec" {
    command = "ssh -o StrictHostKeyChecking=no -i ${var.key_name}.pem ${var.master_os == "ubuntu" ? "ubuntu" : "ec2-user"}@${self.public_ip} 'cat ~/.ssh/id_rsa.pub' > master_id_rsa.pub"
  }
}

# Create Ubuntu machines as slaves
resource "aws_instance" "ubuntu_slaves" {
  count         = var.ubuntu_slave_count
  ami           = var.ami_map["ubuntu"]
  instance_type = "t2.micro"
  key_name      = var.key_name
  vpc_security_group_ids      = [aws_security_group.ssh_sg.id]
  associate_public_ip_address = true

  tags = { Name = "Ubuntu-Slave-${count.index + 1}" }

  provisioner "file" {
    source      = "master_id_rsa.pub"
    destination = "/tmp/master_id_rsa.pub"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }

# Copy the keys from /tmp folder and add under .ssh/authorized keys file
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh",
      "cat /tmp/master_id_rsa.pub >> ~/.ssh/authorized_keys",
      "chmod 600 ~/.ssh/authorized_keys"
    ]

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }

  depends_on = [aws_instance.ansible_master]
}

# Create amazon linux machines as slaves
resource "aws_instance" "amazon_slaves" {
  count         = var.amazon_slave_count
  ami           = var.ami_map["amazon-linux"]
  instance_type = "t2.micro"
  key_name      = var.key_name
  vpc_security_group_ids      = [aws_security_group.ssh_sg.id]
  associate_public_ip_address = true

  tags = { Name = "Amazon-Slave-${count.index + 1}" }

  provisioner "file" {
    source      = "master_id_rsa.pub"
    destination = "/tmp/master_id_rsa.pub"

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }

# Copy the keys from /tmp folder and add under .ssh/authorized keys file
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ssh",
      "cat /tmp/master_id_rsa.pub >> ~/.ssh/authorized_keys",
      "chmod 600 ~/.ssh/authorized_keys"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("${var.key_name}.pem")
      host        = self.public_ip
    }
  }

  depends_on = [aws_instance.ansible_master]
}


# Dynamic inventory file creation - inventory.ini on ansible-master
resource "null_resource" "generate_inventory_on_master" {
  depends_on = [
    aws_instance.ansible_master,
    aws_instance.amazon_slaves,
    aws_instance.ubuntu_slaves
  ]
  
  provisioner "local-exec" {
    command = "rm -rf master_id_rsa.pub"
  }

  provisioner "remote-exec" {
    inline = concat(
      [
        "echo '[master]' > inventory.ini",
        "hostname -I | awk '{print $1\" ansible_user=${var.master_os == "ubuntu" ? "ubuntu" : "ec2-user"} ansible_ssh_common_args=\\\"-o StrictHostKeyChecking=no\\\"\"}' >> inventory.ini",
        "echo '' >> inventory.ini",
        "echo '[ubuntu_slaves]' >> inventory.ini",
      ],
      [
        for ip in aws_instance.ubuntu_slaves[*].private_ip:
         "echo '${ip} ansible_user=ubuntu ansible_ssh_common_args=\"-o StrictHostKeyChecking=no\"' >> inventory.ini"
      ],
      [
        "echo '' >> inventory.ini",
        "echo '[amazon_slaves]' >> inventory.ini",
      ],
      [
        for ip in aws_instance.amazon_slaves[*].private_ip:
         "echo '${ip} ansible_user=ec2-user ansible_ssh_common_args=\"-o StrictHostKeyChecking=no\"' >> inventory.ini"
      ],
      [
        "echo 'inventory.ini created on master:'",
        "cat inventory.ini"
      ]
    )

    connection {
      type        = "ssh"
      user        = var.master_os == "ubuntu" ? "ubuntu" : "ec2-user"
      host        = aws_instance.ansible_master.public_ip
      private_key = file("${var.key_name}.pem")  
    }
  }
}
