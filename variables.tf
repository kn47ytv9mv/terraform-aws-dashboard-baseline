variable "name" {
  default     = null
  description = "Name of the dashboard, which is how it is identified in the CloudWatch console and in a dashboard URL. Only alphanumerics, dashes, and underscores are accepted. If null, a generated UUID is used and exposed as the dashboard_name output."
}

variable "region" {
  default     = null
  description = "Region whose metrics every graph reads. If null, the region the aws provider is configured for is used, which is the right answer whenever the graphed resources live alongside the dashboard. Set it only to graph another region's metrics, since CloudWatch resolves a graph's metrics in the region named inside the widget rather than the region the dashboard itself was created in."
}

variable "rds_instances" {
  default     = {}
  description = "RDS instances to graph, keyed by a name used to label each series. identifier is the instance's own identifier, from terraform-aws-db-instance's identifier output."
  type = map(object({
    identifier = string
  }))
}

variable "rds_clusters" {
  default     = {}
  description = "Aurora clusters to graph, keyed by a name used to label each series. cluster_identifier comes from terraform-aws-rds-cluster's cluster_identifier output."
  type = map(object({
    cluster_identifier = string
  }))
}

variable "load_balancers" {
  default     = {}
  description = "Load balancers to graph, keyed by a name used to label each series. arn_suffix comes from the load balancer module's arn_suffix output — the plain ARN does not work as a CloudWatch dimension, and a graph built on it renders empty rather than failing. type is 'application' or 'network', which selects the metric namespace and the widgets that apply."
  type = map(object({
    arn_suffix = string
    type       = optional(string, "application")
  }))

  validation {
    condition     = alltrue([for l in var.load_balancers : contains(["application", "network"], l.type)])
    error_message = "A load balancer's type must be either 'application' or 'network'."
  }
}

variable "autoscaling_groups" {
  default     = {}
  description = "Autoscaling groups to graph, keyed by a name used to label each series. name comes from terraform-aws-autoscaling-group's name output."
  type = map(object({
    name = string
  }))
}

variable "lambda_functions" {
  default     = {}
  description = "Lambda functions to graph, keyed by a name used to label each series. function_name comes from terraform-aws-lambda-function's function_name output."
  type = map(object({
    function_name = string
  }))
}

variable "dynamodb_tables" {
  default     = {}
  description = "DynamoDB tables to graph, keyed by a name used to label each series. table_name comes from terraform-aws-dynamodb-table's name output."
  type = map(object({
    table_name = string
  }))
}

variable "elasticache_replication_groups" {
  default     = {}
  description = "ElastiCache replication groups to graph, keyed by a name used to label each series. replication_group_id comes from terraform-aws-elasticache-replication-group's id output."
  type = map(object({
    replication_group_id = string
  }))
}

variable "ecs_services" {
  default     = {}
  description = "ECS services to graph, keyed by a name used to label each series. Both the cluster and service names are needed, since ECS service metrics are dimensioned on the pair."
  type = map(object({
    cluster_name = string
    service_name = string
  }))
}

variable "enable_rds_instances" {
  default     = true
  description = "Draw the RDS instance section: CPU utilization, free storage, and connections."
}

variable "enable_rds_clusters" {
  default     = true
  description = "Draw the Aurora cluster section: CPU utilization and connections."
}

variable "enable_load_balancers" {
  default     = true
  description = "Draw the load balancer section, covering both the application and network entries of load_balancers."
}

variable "enable_autoscaling_groups" {
  default     = true
  description = "Draw the autoscaling group section: average CPU across the group and the count of in-service instances."
}

variable "enable_lambda_functions" {
  default     = true
  description = "Draw the Lambda section: invocations, errors, throttles, and duration."
}

variable "enable_dynamodb_tables" {
  default     = true
  description = "Draw the DynamoDB section: consumed read and write capacity, and throttled requests."
}

variable "enable_elasticache_replication_groups" {
  default     = true
  description = "Draw the ElastiCache section: CPU utilization, memory usage, and evictions."
}

variable "enable_ecs_services" {
  default     = true
  description = "Draw the ECS section: CPU and memory utilization."
}

variable "alarm_arns" {
  default     = []
  description = "ARNs of alarms whose current state is rendered as a status row across the top of the dashboard. Pass values(module.monitoring.alarm_arns) from terraform-aws-monitoring-baseline to show every alarm it created. Left empty, no status row is drawn and the graphs begin at the top of the grid."
}

variable "widget_width" {
  default     = 12
  description = "Grid columns each graph occupies. The CloudWatch grid is 24 columns wide and a widget that overruns the last column wraps to the next row, so a width that divides 24 evenly is what keeps rows aligned. 12 places two graphs per row."

  validation {
    condition     = contains([4, 6, 8, 12, 24], var.widget_width)
    error_message = "widget_width must divide the 24-column CloudWatch grid evenly: one of 4, 6, 8, 12, or 24."
  }
}

variable "widget_height" {
  default     = 6
  description = "Grid rows each graph occupies. Six is the height the CloudWatch console itself gives a newly added graph, which is tall enough for the y-axis labels to stay legible."
}

variable "alarm_widget_height" {
  default     = 4
  description = "Grid rows the alarm status row occupies. It always spans the full 24 columns, since it renders a list of alarm states rather than a graph."
}

variable "period" {
  default     = 300
  description = "Seconds each datapoint covers, for every graph this module draws. A shorter period gives more detail at the cost of a longer query, and CloudWatch only retains sub-minute resolution for three hours."
}
