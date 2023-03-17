terraform {
    backend "s3" {
    bucket = "hello-world-sample-bucket"
    key    = "my_states/terraform.tfstate"
    region = "ap-northeast-1"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.59.0"
    }
  }
}

provider "aws" {
    region = "ap-northeast-1"
}

resource "aws_vpc" "my_vpc" { 
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "hello_world" 
  }
}

resource "aws_internet_gateway" "my_gateway" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "my_gateway"
  }
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-northeast-1a"
  #Enable auto-assign public IPv4 address
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-northeast-1c"
  #Enable auto-assign public IPv4 address
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_2"
  }
}



resource "aws_route_table" "public_route" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_gateway.id
  }
}

#associating public route table with public subnet

resource "aws_route_table_association" "public_route_table_association_1" {
  subnet_id = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route.id
}

resource "aws_route_table_association" "public_route_table_association_2" {
  subnet_id = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_route.id
}



resource "aws_security_group" "ecs_sg" {
  name_prefix = "ecs-sg"
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port = 3000
    to_port = 3000
    protocol = "tcp"
    security_groups = [ aws_security_group.ecs_lb_sg.id]
  }

  egress {
    from_port = 0 
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags =  {
    Name = "h_w_sg"
  }
}




resource "aws_ecs_cluster" "ecs_cluster" {
  name = "hello-world-cluster"
  # capacity_providers = ["FARGATE"]
}


resource "aws_ecs_task_definition" "hello_world_task_definition" {
  family                   = "helloworld-td"  
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu       = 256
  memory    = 512
  container_definitions    = jsonencode([{
    name  = "hello-world"
    image = "ajmaldocker07/hello-world"

    portMappings = [{
      containerPort = 3000
    }]
  }])

}


resource "aws_ecs_service" "mongo" {
  name            = "hello-world-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.hello_world_task_definition.arn
  launch_type     = "FARGATE"
  desired_count   = 2


  load_balancer {
    target_group_arn = aws_lb_target_group.ecs_lb_tg.arn 
    container_name   = "hello-world"
    container_port   = 3000 
  }


  network_configuration {
    subnets          = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
    assign_public_ip = true # Providing our containers with public IPs
    security_groups = [aws_security_group.ecs_sg.id]
  }
}





resource "aws_security_group" "ecs_lb_sg" {
  name_prefix = "elb_sg"
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    from_port   = 80
    to_port     = 80
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



resource "aws_alb" "ecs_load_balancer" {
  name               = "ecs-hw-lb" # Naming our load balancer
  load_balancer_type = "application"
  subnets = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
  # Referencing the security group
  security_groups = [aws_security_group.ecs_lb_sg.id]
}





resource "aws_lb_target_group" "ecs_lb_tg" {
   name = "ecs-target-group"
   port = 80
   protocol = "HTTP"
   target_type = "ip"
   vpc_id = aws_vpc.my_vpc.id
   health_check {
     matcher = "200,301,302" 
     path = "/"
   }
}


resource "aws_lb_listener" "ecs_lb_listner" {
  load_balancer_arn = aws_alb.ecs_load_balancer.arn
  port = "80"
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.ecs_lb_tg.arn
  }
}





