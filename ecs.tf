resource "aws_ecs_cluster" "tlb-analytics" {
  name = "we-are-too-lazy-to-manage-this"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "tlb-fargate" {
  cluster_name = aws_ecs_cluster.tlb-analytics.name
  capacity_providers = ["FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE_SPOT"
  }
}

resource "aws_ecs_task_definition" "superset-redis" {

    family = "redis"
    requires_compatibilities = ["FARGATE"]
    cpu = 256
    memory = 512
    network_mode = "awsvpc"
    container_definitions = jsonencode([
        {
            name = "redis"
            image = "redis:7-alpine"
        }
    ])
}

resource "aws_ecs_service" "tlb-redis" {
  name            = "redis"
  cluster         = aws_ecs_cluster.tlb-analytics.id
  task_definition = aws_ecs_task_definition.superset-redis.arn
  desired_count   = 1

  network_configuration {
    subnets = [ aws_subnet.tlb-default-priv-a.id ]
    assign_public_ip = true
  }

}