# 配置 Terraform 后端
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.82.2"
    }
  }
  backend "s3" {
    # 指定存储状态文件的 S3 存储桶名称
    bucket = "new12345new12345" #bucket name 全局唯一
    # 指定状态文件在存储桶中的路径和文件名
    key = "pipeline-terraform-statusfile/terraform.tfstate"
    # 指定 S3 存储桶所在的 AWS 区域
    region = "us-east-1"
  }
}

# 配置 AWS provider 和区域
provider "aws" {
  # 配置 AWS 区域
  # region = "us-east-1"  
  # 配置 AWS 访问密钥明码，用于身份验证
  # 注意：直接在代码中使用明码访问密钥是不安全的，建议使用环境变量或其他安全的方式传递这些敏感信息
}

# 创建 EC2 安全组
resource "aws_security_group" "ec2_security_group" {
  # 安全组名称
  name = "ec2 security group"
  # 安全组描述
  description = "allow access on ports 80 and 22"
  # 关联的 VPC ID
  vpc_id = aws_default_vpc.default_vpc.id
  # 入站规则：允许 HTTP 访问
  ingress {
    description = "http access"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # 入站规则：允许 SSH 访问
  ingress {
    description = "ssh access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # 出站规则：允许所有流量
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["0.0.0.0/0"]
  }
  # 安全组标签
  tags = {
    Name = "ec2 security group"
  }
}

# 创建默认 VPC 并为其命名
resource "aws_default_vpc" "default_vpc" {
  # VPC 标签
  tags = {
    Name = "default vpc"
  }
}

# 创建 EC2 实例
resource "aws_instance" "linux_instance" {
  # 使用的 AMI 镜像 ID，us-east-1区的 Amazon linux 2023
  ami = "ami-01816d07b1128cd2d"
  # 实例类型
  instance_type = "t2.micro"
  # 密钥对名称
  key_name = "LYC-APP2"
  # IAM 实例配置文件
  iam_instance_profile = "EC2CodeDeploy-new"
  # 实例标签
  tags = {
    Name = "LYC-APP2"
  }

  # User Data写入如下脚本: 在实例启动时执行的脚本
  user_data = <<-EOF
              #!/bin/bash

              # 更新系统
              yum update -y
              
              # 安装 Nginx
              yum install nginx -y
              
              # 启动 Nginx 
              systemctl start nginx
              
              # 设置 Nginx 为开机自启
              systemctl enable nginx

              # 安装codedeploy-agent
              sudo yum -y update
              sudo yum -y install ruby
              sudo yum -y install wget
              cd /home/ec2-user
              wget https://aws-codedeploy-us-east-1.s3.us-east-1.amazonaws.com/latest/install
              sudo chmod +x ./install
              sudo ./install auto
              systemctl status codedeploy-agent
              # 使用CodeDeploy服务需要在EC2中安装agent，具体代码解释，请参考
              # https://docs.aws.amazon.com/zh_cn/codedeploy/latest/userguide/codedeploy-agent-operations-install-linux.html

              EOF
}

# 输出 EC2 实例的公网 IPv4 地址
output "ec2_public_ipv4_url" {
  value = join("", ["http://", aws_instance.linux_instance.public_ip, ":80"])
}
