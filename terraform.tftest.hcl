mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }
}

run "invalid_load_balancer_type_is_rejected" {
  command = plan

  variables {
    load_balancers = {
      web = { arn_suffix = "app/web/1111", type = "gateway" }
    }
  }

  expect_failures = [var.load_balancers]
}

run "widget_width_that_does_not_divide_the_grid_is_rejected" {
  command = plan

  variables {
    widget_width = 10
  }

  expect_failures = [var.widget_width]
}

run "nothing_to_graph_still_produces_a_valid_body" {
  command = plan

  assert {
    condition     = can(jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body))
    error_message = "A dashboard with no resources supplied must still render valid JSON rather than fail evaluation."
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets) == 0
    error_message = "Supplying no resources should draw no widgets at all."
  }

  assert {
    condition     = output.widget_count == 0
    error_message = "An empty dashboard should report a widget count of zero."
  }
}

run "one_rds_instance_gets_its_three_graphs" {
  command = plan

  variables {
    rds_instances = {
      app = { identifier = "app-db" }
    }
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets) == 3
    error_message = "An RDS instance should get its CPU, free storage, and connections graphs."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.metrics[0][2] == "DBInstanceIdentifier"
    error_message = "An RDS graph must name the DBInstanceIdentifier dimension, or the widget renders empty."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.metrics[0][3] == "app-db"
    error_message = "An RDS graph must carry the instance identifier as its dimension value."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[1].properties.metrics[0][1] == "FreeStorageSpace"
    error_message = "The second RDS graph should be free storage."
  }
}

run "load_balancer_graphs_carry_the_arn_suffix_dimension" {
  command = plan

  variables {
    load_balancers = {
      web = { arn_suffix = "app/web/1111" }
    }
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets) == 4
    error_message = "An application load balancer should get its request, 5XX, response time, and unhealthy host graphs."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.metrics[0][2] == "LoadBalancer"
    error_message = "A load balancer graph is dimensioned on LoadBalancer."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.metrics[0][3] == "app/web/1111"
    error_message = "The LoadBalancer dimension value must be the ARN suffix; the full ARN matches no metric and renders a blank graph."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[2].properties.stat == "p99"
    error_message = "Target response time should be graphed at p99, since an average hides the slow requests worth seeing."
  }
}

run "a_network_load_balancer_gets_its_own_namespace" {
  command = plan

  variables {
    load_balancers = {
      web = { arn_suffix = "app/web/1111", type = "application" }
      tcp = { arn_suffix = "net/tcp/2222", type = "network" }
    }
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets) == 6
    error_message = "An application load balancer should get four graphs and a network one its own two."
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.metrics) == 1
    error_message = "A network load balancer has no HTTP metrics and must not appear as a series on an application graph."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[4].properties.metrics[0][0] == "AWS/NetworkELB"
    error_message = "A network load balancer's metrics live in the AWS/NetworkELB namespace."
  }
}

run "disabling_a_section_removes_its_graphs" {
  command = plan

  variables {
    rds_instances = {
      app = { identifier = "app-db" }
    }
    lambda_functions = {
      processor = { function_name = "processor" }
    }
    enable_rds_instances = false
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets) == 4
    error_message = "Disabling the RDS section should leave only the four Lambda graphs."
  }

  assert {
    condition     = length([for w in jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets : w if startswith(w.properties.title, "RDS")]) == 0
    error_message = "No RDS graph should survive disabling the RDS section."
  }
}

run "graphs_flow_left_to_right_and_wrap_at_the_grid_width" {
  command = plan

  variables {
    load_balancers = {
      web = { arn_suffix = "app/web/1111" }
    }
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[1].x == 12
    error_message = "The second graph should sit beside the first at the default width of 12."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[2].x == 0
    error_message = "The third graph should wrap back to the left edge."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[2].y == 6
    error_message = "A wrapped graph should start a new row one widget height down."
  }
}

run "a_narrower_widget_fits_more_graphs_per_row" {
  command = plan

  variables {
    widget_width = 8

    load_balancers = {
      web = { arn_suffix = "app/web/1111" }
    }
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[2].x == 16
    error_message = "At a width of 8 the third graph should still be on the first row."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[3].y == 6
    error_message = "At a width of 8 the fourth graph should wrap to the second row."
  }
}

run "alarm_arns_draw_a_status_row_above_the_graphs" {
  command = plan

  variables {
    rds_instances = {
      app = { identifier = "app-db" }
    }
    alarm_arns = ["arn:aws:cloudwatch:us-east-1:123456789012:alarm:app-rds-cpu-high"]
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets) == 4
    error_message = "The status row should be drawn in addition to the three RDS graphs."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].type == "alarm"
    error_message = "The alarm status row should be the first widget on the dashboard."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].width == 24
    error_message = "The alarm status row should span the full grid width."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.alarms[0] == "arn:aws:cloudwatch:us-east-1:123456789012:alarm:app-rds-cpu-high"
    error_message = "The alarm widget renders the alarm ARNs it was given."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[1].y == 4
    error_message = "The graphs should start below the status row rather than underneath it."
  }
}

run "no_alarm_arns_draws_no_status_row" {
  command = plan

  variables {
    rds_instances = {
      app = { identifier = "app-db" }
    }
  }

  assert {
    condition     = length([for w in jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets : w if w.type == "alarm"]) == 0
    error_message = "An empty alarm_arns should draw no status row."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].y == 0
    error_message = "Without a status row the first graph should sit at the top of the grid."
  }
}

run "ecs_graphs_carry_both_dimensions" {
  command = plan

  variables {
    ecs_services = {
      api = { cluster_name = "prod", service_name = "api" }
    }
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.metrics[0][3] == "prod"
    error_message = "An ECS graph is dimensioned on the cluster and service pair, and needs the cluster name."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.metrics[0][5] == "api"
    error_message = "An ECS graph needs its ServiceName dimension as well."
  }
}

run "autoscaling_graphs_span_two_namespaces" {
  command = plan

  variables {
    autoscaling_groups = {
      web = { name = "web" }
    }
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.metrics[0][0] == "AWS/EC2"
    error_message = "An autoscaling group's CPU is published by EC2, not by the autoscaling service."
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[1].properties.metrics[0][0] == "AWS/AutoScaling"
    error_message = "In-service instance counts are published by the autoscaling service, not by EC2."
  }
}

run "every_graph_names_the_provider_region" {
  command = plan

  variables {
    rds_instances = {
      app = { identifier = "app-db" }
    }
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.region == "us-east-1"
    error_message = "A graph with no region resolves no metrics, so the provider's region is the default."
  }
}

run "the_region_variable_overrides_the_provider_region" {
  command = plan

  variables {
    region = "eu-west-1"

    rds_instances = {
      app = { identifier = "app-db" }
    }
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.region == "eu-west-1"
    error_message = "An explicit region should let a dashboard graph another region's metrics."
  }
}

run "period_reaches_every_graph" {
  command = plan

  variables {
    period = 60

    rds_instances = {
      app = { identifier = "app-db" }
    }
  }

  assert {
    condition     = jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets[0].properties.period == 60
    error_message = "A tuned period should reach the graphs."
  }
}

run "a_generated_name_is_used_when_name_is_null" {
  command = apply

  assert {
    condition     = aws_cloudwatch_dashboard.resource.dashboard_name == random_uuid.resource.id
    error_message = "Leaving name null should fall back to the generated UUID."
  }
}

run "an_explicit_name_is_used_verbatim" {
  command = plan

  variables {
    name = "production-baseline"
  }

  assert {
    condition     = aws_cloudwatch_dashboard.resource.dashboard_name == "production-baseline"
    error_message = "An explicit name should be used as the dashboard name unchanged."
  }
}

run "every_section_together_draws_every_graph" {
  command = plan

  variables {
    rds_instances = {
      app = { identifier = "app-db" }
    }
    rds_clusters = {
      orders = { cluster_identifier = "orders-aurora" }
    }
    load_balancers = {
      web = { arn_suffix = "app/web/1111", type = "application" }
      tcp = { arn_suffix = "net/tcp/2222", type = "network" }
    }
    autoscaling_groups = {
      web = { name = "web" }
    }
    lambda_functions = {
      processor = { function_name = "processor" }
    }
    dynamodb_tables = {
      sessions = { table_name = "sessions" }
    }
    elasticache_replication_groups = {
      cache = { replication_group_id = "cache" }
    }
    ecs_services = {
      api = { cluster_name = "prod", service_name = "api" }
    }
  }

  assert {
    condition     = output.widget_count == 25
    error_message = "Every section enabled should draw three RDS, two Aurora, four application and two network load balancer, two autoscaling, four Lambda, three DynamoDB, three cache, and two ECS graphs."
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.resource.dashboard_body).widgets) == output.widget_count
    error_message = "The reported widget count should match the widgets actually rendered into the body."
  }
}

run "readme_paired_example" {
  command = plan

  variables {
    name   = "production"
    region = null

    alarm_arns = ["arn:aws:cloudwatch:us-east-1:123456789012:alarm:production-app-rds-cpu-high"]

    rds_instances = {
      app = { identifier = "app-db" }
    }

    load_balancers = {
      web = { arn_suffix = "app/web/1111" }
    }

    autoscaling_groups = {
      web = { name = "web" }
    }
  }

  assert {
    condition     = output.widget_count == 10
    error_message = "The paired example should draw a status row, three RDS graphs, four load balancer graphs, and two autoscaling graphs."
  }
}

run "readme_github_source_example" {
  command = plan

  variables {
    name         = "serverless"
    widget_width = 8

    lambda_functions = {
      processor = { function_name = "processor" }
    }

    dynamodb_tables = {
      sessions = { table_name = "sessions" }
    }

    enable_dynamodb_tables = false
  }

  assert {
    condition     = output.widget_count == 4
    error_message = "Disabling the DynamoDB section should leave only the four Lambda graphs."
  }
}
