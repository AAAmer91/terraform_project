# Provider block - specifies you're using AWS
provider "aws" {
  region = "us-west-2"  # Replace with your preferred AWS region
}

# Create a key pair to access the EC2 instance (replace with your preferred key name)
resource "aws_key_pair" "terraform_key" {
  key_name   = "terraform_key"
  public_key = var.ssh_public_key
}

variable "ssh_public_key" {
  type = string
}

# Create a security group to allow SSH, HTTP, and Airflow (8080)
resource "aws_security_group" "allow_ssh_http_airflow" {
  name        = "allow_ssh_http_airflow"
  
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

# Create a new EC2 instance only if no existing instance is found
resource "aws_instance" "my_ec2_instance" {
  count = length(data.aws_instance.existing_instance.id) == 0 ? 1 : 0

  ami           = "ami-05134c8ef96964280"  # Replace with a valid AMI ID for your region
  instance_type = "t2.micro"

  # Associate the key pair and security group
  key_name      = aws_key_pair.terraform_key.key_name
  security_groups = [aws_security_group.allow_ssh_http_airflow.name]

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

  tags = {
    Name = "MyTerraformEC2Instance"
  }
}

# Output the public IP of the EC2 instance (whether reused or newly created)
output "ec2_public_ip" {
  value = length(data.aws_instance.existing_instance.id) != 0 ? data.aws_instance.existing_instance.public_ip : aws_instance.my_ec2_instance[0].public_ip
}
