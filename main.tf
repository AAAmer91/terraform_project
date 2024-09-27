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

# Create a security group to allow SSH and HTTP
resource "aws_security_group" "allow_ssh_http" {
  name        = "allow_ssh_http"
  
  ingress {
    from_port   = 22  # Allow SSH
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Allow from anywhere
  }

  ingress {
    from_port   = 80  # Allow HTTP
    to_port     = 80
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

# Create an EC2 instance
resource "aws_instance" "my_ec2_instance" {
  ami           = "ami-05134c8ef96964280"  # Replace with a valid AMI ID for your region
  instance_type = "t2.micro"

  # Associate the key pair and security group
  key_name      = aws_key_pair.terraform_key.key_name
  security_groups = [aws_security_group.allow_ssh_http.name]

  # Tags for better management
  tags = {
    Name = "MyTerraformEC2Instance"
  }
}

# Output the public IP of the EC2 instance
output "ec2_public_ip" {
  value = aws_instance.my_ec2_instance.public_ip
}
