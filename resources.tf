locals {
  region = coalesce(var.region, data.aws_region.resource.region)

  widgets_per_row = floor(24 / var.widget_width)

  application_load_balancers = { for k, v in var.load_balancers : k => v if v.type == "application" }
  network_load_balancers     = { for k, v in var.load_balancers : k => v if v.type == "network" }

  rds_instance_widgets = [
    for m in [
      { title = "RDS CPU utilization", metric_name = "CPUUtilization", stat = "Average" },
      { title = "RDS free storage", metric_name = "FreeStorageSpace", stat = "Average" },
      { title = "RDS connections", metric_name = "DatabaseConnections", stat = "Average" },
      ] : {
      title = m.title
      stat  = m.stat
      series = [
        for k, v in var.rds_instances : {
          namespace   = "AWS/RDS"
          metric_name = m.metric_name
          dimensions  = ["DBInstanceIdentifier", v.identifier]
          label       = k
        }
      ]
    } if var.enable_rds_instances && length(var.rds_instances) > 0
  ]

  rds_cluster_widgets = [
    for m in [
      { title = "Aurora CPU utilization", metric_name = "CPUUtilization", stat = "Average" },
      { title = "Aurora connections", metric_name = "DatabaseConnections", stat = "Average" },
      ] : {
      title = m.title
      stat  = m.stat
      series = [
        for k, v in var.rds_clusters : {
          namespace   = "AWS/RDS"
          metric_name = m.metric_name
          dimensions  = ["DBClusterIdentifier", v.cluster_identifier]
          label       = k
        }
      ]
    } if var.enable_rds_clusters && length(var.rds_clusters) > 0
  ]

  application_load_balancer_widgets = [
    for m in [
      { title = "Load balancer requests", metric_name = "RequestCount", stat = "Sum" },
      { title = "Load balancer target 5XX responses", metric_name = "HTTPCode_Target_5XX_Count", stat = "Sum" },
      { title = "Load balancer p99 target response time", metric_name = "TargetResponseTime", stat = "p99" },
      { title = "Load balancer unhealthy hosts", metric_name = "UnHealthyHostCount", stat = "Maximum" },
      ] : {
      title = m.title
      stat  = m.stat
      series = [
        for k, v in local.application_load_balancers : {
          namespace   = "AWS/ApplicationELB"
          metric_name = m.metric_name
          dimensions  = ["LoadBalancer", v.arn_suffix]
          label       = k
        }
      ]
    } if var.enable_load_balancers && length(local.application_load_balancers) > 0
  ]

  network_load_balancer_widgets = [
    for m in [
      { title = "Network load balancer active flows", metric_name = "ActiveFlowCount", stat = "Average" },
      { title = "Network load balancer unhealthy hosts", metric_name = "UnHealthyHostCount", stat = "Maximum" },
      ] : {
      title = m.title
      stat  = m.stat
      series = [
        for k, v in local.network_load_balancers : {
          namespace   = "AWS/NetworkELB"
          metric_name = m.metric_name
          dimensions  = ["LoadBalancer", v.arn_suffix]
          label       = k
        }
      ]
    } if var.enable_load_balancers && length(local.network_load_balancers) > 0
  ]

  autoscaling_group_widgets = [
    for m in [
      { title = "Autoscaling group average CPU", namespace = "AWS/EC2", metric_name = "CPUUtilization", stat = "Average" },
      { title = "Autoscaling group in-service instances", namespace = "AWS/AutoScaling", metric_name = "GroupInServiceInstances", stat = "Average" },
      ] : {
      title = m.title
      stat  = m.stat
      series = [
        for k, v in var.autoscaling_groups : {
          namespace   = m.namespace
          metric_name = m.metric_name
          dimensions  = ["AutoScalingGroupName", v.name]
          label       = k
        }
      ]
    } if var.enable_autoscaling_groups && length(var.autoscaling_groups) > 0
  ]

  lambda_function_widgets = [
    for m in [
      { title = "Lambda invocations", metric_name = "Invocations", stat = "Sum" },
      { title = "Lambda errors", metric_name = "Errors", stat = "Sum" },
      { title = "Lambda throttles", metric_name = "Throttles", stat = "Sum" },
      { title = "Lambda duration", metric_name = "Duration", stat = "Average" },
      ] : {
      title = m.title
      stat  = m.stat
      series = [
        for k, v in var.lambda_functions : {
          namespace   = "AWS/Lambda"
          metric_name = m.metric_name
          dimensions  = ["FunctionName", v.function_name]
          label       = k
        }
      ]
    } if var.enable_lambda_functions && length(var.lambda_functions) > 0
  ]

  dynamodb_table_widgets = [
    for m in [
      { title = "DynamoDB consumed read capacity", metric_name = "ConsumedReadCapacityUnits", stat = "Sum" },
      { title = "DynamoDB consumed write capacity", metric_name = "ConsumedWriteCapacityUnits", stat = "Sum" },
      { title = "DynamoDB throttled requests", metric_name = "ThrottledRequests", stat = "Sum" },
      ] : {
      title = m.title
      stat  = m.stat
      series = [
        for k, v in var.dynamodb_tables : {
          namespace   = "AWS/DynamoDB"
          metric_name = m.metric_name
          dimensions  = ["TableName", v.table_name]
          label       = k
        }
      ]
    } if var.enable_dynamodb_tables && length(var.dynamodb_tables) > 0
  ]

  elasticache_widgets = [
    for m in [
      { title = "Cache CPU utilization", metric_name = "CPUUtilization", stat = "Average" },
      { title = "Cache memory usage", metric_name = "DatabaseMemoryUsagePercentage", stat = "Average" },
      { title = "Cache evictions", metric_name = "Evictions", stat = "Sum" },
      ] : {
      title = m.title
      stat  = m.stat
      series = [
        for k, v in var.elasticache_replication_groups : {
          namespace   = "AWS/ElastiCache"
          metric_name = m.metric_name
          dimensions  = ["ReplicationGroupId", v.replication_group_id]
          label       = k
        }
      ]
    } if var.enable_elasticache_replication_groups && length(var.elasticache_replication_groups) > 0
  ]

  ecs_service_widgets = [
    for m in [
      { title = "ECS CPU utilization", metric_name = "CPUUtilization", stat = "Average" },
      { title = "ECS memory utilization", metric_name = "MemoryUtilization", stat = "Average" },
      ] : {
      title = m.title
      stat  = m.stat
      series = [
        for k, v in var.ecs_services : {
          namespace   = "AWS/ECS"
          metric_name = m.metric_name
          dimensions  = ["ClusterName", v.cluster_name, "ServiceName", v.service_name]
          label       = k
        }
      ]
    } if var.enable_ecs_services && length(var.ecs_services) > 0
  ]

  widget_specs = concat(
    local.rds_instance_widgets,
    local.rds_cluster_widgets,
    local.application_load_balancer_widgets,
    local.network_load_balancer_widgets,
    local.autoscaling_group_widgets,
    local.lambda_function_widgets,
    local.dynamodb_table_widgets,
    local.elasticache_widgets,
    local.ecs_service_widgets,
  )

  alarm_widgets = length(var.alarm_arns) > 0 ? [
    {
      type   = "alarm"
      x      = 0
      y      = 0
      width  = 24
      height = var.alarm_widget_height
      properties = {
        title  = "Alarm status"
        alarms = var.alarm_arns
      }
    }
  ] : []

  graph_offset = length(var.alarm_arns) > 0 ? var.alarm_widget_height : 0

  metric_widgets = [
    for i, w in local.widget_specs : {
      type   = "metric"
      x      = (i % local.widgets_per_row) * var.widget_width
      y      = local.graph_offset + floor(i / local.widgets_per_row) * var.widget_height
      width  = var.widget_width
      height = var.widget_height
      properties = {
        title   = w.title
        region  = local.region
        view    = "timeSeries"
        stacked = false
        period  = var.period
        stat    = w.stat
        metrics = [
          for s in w.series : concat([s.namespace, s.metric_name], s.dimensions, [{ label = s.label }])
        ]
      }
    }
  ]

  dashboard_body = jsonencode({
    widgets = concat(local.alarm_widgets, local.metric_widgets)
  })
}

resource "random_uuid" "resource" {}

data "aws_region" "resource" {}

resource "aws_cloudwatch_dashboard" "resource" {
  dashboard_name = coalesce(var.name, random_uuid.resource.id)
  dashboard_body = local.dashboard_body
}

output "id" {
  description = "Identifier of the dashboard, which CloudWatch sets to the dashboard's name."
  value       = aws_cloudwatch_dashboard.resource.id
}

output "arn" {
  description = "ARN of the dashboard, for an IAM policy that grants access to this one dashboard."
  value       = aws_cloudwatch_dashboard.resource.dashboard_arn
}

output "dashboard_name" {
  description = "Full name of the dashboard, including the generated UUID when name was left null."
  value       = aws_cloudwatch_dashboard.resource.dashboard_name
}

output "dashboard_body" {
  description = "The rendered dashboard JSON, so a caller can inspect or assert on the widgets that were produced without reading them back from CloudWatch."
  value       = aws_cloudwatch_dashboard.resource.dashboard_body
}

output "widget_count" {
  description = "Total number of widgets drawn, including the alarm status row, useful for confirming a configuration change actually added or removed what was intended."
  value       = length(local.alarm_widgets) + length(local.metric_widgets)
}
