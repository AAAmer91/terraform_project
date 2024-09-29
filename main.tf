# Provider block - specifies you're using AWS
provider "aws" {
  region = "us-west-2"  # Replace with your preferred AWS region
}

# Use an existing key pair if it exists
data "aws_key_pair" "existing_key" {
  key_name = "terraform_key"  # Replace with the key name you want to check for
}

# If the key pair exists, use it, otherwise create a new one
resource "aws_key_pair" "terraform_key" {
  count      = length(data.aws_key_pair.existing_key.id) == 0 ? 1 : 0
  key_name   = "terraform_key"  # Replace with your preferred key name
  public_key = var.ssh_public_key
}

variable "ssh_public_key" {
  type = string
}

# Use an existing security group if it exists
data "aws_security_group" "existing_sg" {
  filter {
    name   = "group-name"
    values = ["allow_ssh_http_airflow"]
  }
}

# If the security group exists, use it, otherwise create a new one
resource "aws_security_group" "allow_ssh_http_airflow" {
  count = length(data.aws_security_group.existing_sg.id) == 0 ? 1 : 0
  name  = "allow_ssh_http_airflow"

  ingress {
    from_port   = 22  # Allow SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere
  }

  ingress {
    from_port   = 80  # Allow HTTP (Airflow Web UI will be bound to port 80)
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080  # Allow Airflow on port 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define local variables to choose either the existing or the new security group
locals {
  key_name            = length(data.aws_key_pair.existing_key.id) > 0 ? data.aws_key_pair.existing_key.key_name : aws_key_pair.terraform_key.key_name
  security_group_id   = length(data.aws_security_group.existing_sg.id) > 0 ? data.aws_security_group.existing_sg.id : aws_security_group.allow_ssh_http_airflow[0].id
}

# Create an EC2 instance
resource "aws_instance" "my_ec2_instance" {
  ami           = "ami-05134c8ef96964280"  # Replace with a valid AMI ID for your region
  instance_type = "t2.micro"

  # Use the local variable for key_name
  key_name = local.key_name

  # Use the local variable for security group ID
  vpc_security_group_ids = [local.security_group_id]

  # Tags for better management
  tags = {
    Name = "MyTerraformEC2Instance"
  }

  # User data script to install Apache Airflow
  user_data = <<-EOF
    #!/bin/bash
    # Update the instance and install dependencies
    sudo apt update -y
    sudo apt upgrade -y
    sudo apt install -y python3-pip

    # Install Apache Airflow
    pip3 install apache-airflow

    # Initialize the Airflow database
    airflow db init

    # Start Airflow Webserver and Scheduler
    nohup airflow webserver --port 8080 &  # Starts webserver on port 8080
    nohup airflow scheduler &  # Starts the scheduler
  EOF
}

# Output the public IP of the EC2 instance
output "ec2_public_ip" {
  value = aws_instance.my_ec2_instance.public_ip
}
