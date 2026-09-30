# terraform-aws-dashboard-baseline

Terraform module for a curated CloudWatch dashboard across the resources
this family builds — the visual counterpart to
[`terraform-aws-monitoring-baseline`](https://github.com/kn47ytv9mv/terraform-aws-monitoring-baseline),
which covers the same resources with alarms.

## Cost

CloudWatch bills per dashboard-month. The first three dashboards in an
account are free, so a single baseline dashboard per environment usually
costs nothing at all; past that third dashboard each one bills whether
or not anyone opens it. The number of widgets on a dashboard does not
change what it costs, so disabling a section via its `enable_*` variable
is a legibility decision rather than a cost one. See AWS's
[CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/) page for
current rates.

## Design

This module takes the same resource maps
[`terraform-aws-monitoring-baseline`](https://github.com/kn47ytv9mv/terraform-aws-monitoring-baseline)
takes, under the same names and with the same object shapes. A caller
has already described their infrastructure once to get alarms; passing
the identical maps here turns that description into graphs, and the two
modules stay in step because neither of them invents its own vocabulary.

Every graph is built on a metric AWS already publishes, so nothing here
requires enabling a paid metric stream first. Resources are supplied as
maps keyed by a short name, and that key becomes the series label on the
graph, so `rds_instances = { app = { identifier = "app-db" } }` draws a
line labelled `app`.

Widgets are grouped by metric rather than by resource: one graph per
metric, with a line for every resource of that kind. Ten RDS instances
produce three graphs of ten lines each rather than thirty graphs, which
is both the comparison an operator actually wants and a dashboard whose
length does not grow with the fleet.

This module implements its own `aws_cloudwatch_dashboard` resource rather
than calling
[`terraform-aws-cloudwatch-dashboard`](https://github.com/kn47ytv9mv/terraform-aws-cloudwatch-dashboard)
internally — this family keeps single-purpose modules standalone; only a
parent composition config wires leaf modules together. Reach for that
module directly for a dashboard outside this curated set.

### What it graphs

| Resource | Graphs |
|---|---|
| `rds_instances` | CPU utilization, free storage, connections |
| `rds_clusters` | CPU utilization, connections |
| `load_balancers` (application) | Requests, target 5XX, p99 target response time, unhealthy hosts |
| `load_balancers` (network) | Active flows, unhealthy hosts |
| `autoscaling_groups` | Average CPU, in-service instances |
| `lambda_functions` | Invocations, errors, throttles, duration |
| `dynamodb_tables` | Consumed read capacity, consumed write capacity, throttled requests |
| `elasticache_replication_groups` | CPU utilization, memory usage, evictions |
| `ecs_services` | CPU utilization, memory utilization |

### The alarm status row

`alarm_arns` accepts a list of alarm ARNs and renders their current
state as a row across the top of the dashboard, above the graphs. This
is what makes the two modules a pair: `monitoring-baseline` outputs
`alarm_arns` as a map, and `values()` over it hands every alarm it
created straight to this module. Left empty, no row is drawn and the
graphs begin at the top of the grid.

An alarm widget identifies each alarm by its full ARN and therefore
takes no region of its own, which is why an alarm in another region can
appear on this dashboard without any further configuration.

### Choices worth knowing about

- **Load balancers take `arn_suffix`, not `arn`.** CloudWatch's
  `LoadBalancer` dimension is the suffix (`app/web/1111`); the full ARN
  matches no metric. A graph built on the wrong value renders blank and
  reports no error at all, which is harder to notice than an alarm stuck
  in `INSUFFICIENT_DATA`. The load balancer modules expose an
  `arn_suffix` output for this.
- **A graph names its own region, and an alarm does not.** A metric
  widget with no `region` in its properties resolves nothing, so this
  module fills it from `region` when set and otherwise from the region
  the `aws` provider is configured for — the right answer whenever the
  graphed resources live alongside the dashboard. Set `region`
  explicitly only to graph another region's metrics, since CloudWatch
  resolves each widget against the region named inside it rather than
  the region the dashboard was created in.
- **An ECS service is dimensioned on the cluster and service pair**, so
  `ecs_services` needs both names. An autoscaling group is graphed
  across two namespaces: its CPU is published by EC2 as
  `AWS/EC2 CPUUtilization`, while its instance count is published by the
  autoscaling service as `AWS/AutoScaling GroupInServiceInstances`.
- **Target response time is graphed at p99, not average.** An average
  over five minutes hides exactly the slow requests worth looking at.
- **A network load balancer gets its own two graphs.** It publishes no
  request count, no HTTP status codes, and no target response time, so
  those three graphs cover the application entries only and active flow
  count stands in as the network equivalent of request volume.
- **`widget_width` must divide the 24-column grid evenly.** CloudWatch
  lays widgets out on a 24-column grid and wraps anything that overruns
  the last column, so a width of 10 leaves a ragged third column. The
  variable is validated against 4, 6, 8, 12, and 24.
- **There is no `tags` variable.** `aws_cloudwatch_dashboard` has no
  tags attribute in the AWS provider's schema, which is the one place
  this module's inputs depart from `monitoring-baseline`'s. Tagging a
  dashboard is not possible through Terraform at all, rather than merely
  unsupported here.

## Usage

Paired with `terraform-aws-monitoring-baseline`, so the same description
of the infrastructure produces both the alarms and the graphs, and the
dashboard leads with the state of those alarms:

```hcl
module "monitoring" {
  source = "kn47ytv9mv/monitoring-baseline/aws"

  name_prefix   = "production"
  alarm_actions = [module.alerts.arn]

  rds_instances = {
    app = { identifier = module.database.identifier }
  }

  load_balancers = {
    web = { arn_suffix = module.alb.arn_suffix }
  }

  autoscaling_groups = {
    web = { name = module.group.name }
  }
}

module "dashboard" {
  source = "kn47ytv9mv/dashboard-baseline/aws"

  name       = "production"
  alarm_arns = values(module.monitoring.alarm_arns)

  rds_instances = {
    app = { identifier = module.database.identifier }
  }

  load_balancers = {
    web = { arn_suffix = module.alb.arn_suffix }
  }

  autoscaling_groups = {
    web = { name = module.group.name }
  }
}
```

Or directly from this repository. The resource maps are usually the same
ones handed to `monitoring-baseline`, so an `enable_*` flag rather than
an edited map is how a section is dropped from the dashboard while its
alarms stay in place:

```hcl
module "dashboard" {
  source = "github.com/kn47ytv9mv/terraform-aws-dashboard-baseline"

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
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.3 |
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Providers

| Name | Version |
|---|---|
| aws | ~> 6.61 |
| random | ~> 3.9 |

## Inputs

| Name | Description | Default | Required |
|---|---|---|---|
| name | Name of the dashboard. Only alphanumerics, dashes, and underscores are accepted. If null, a generated UUID is used. | `null` | no |
| region | Region whose metrics every graph reads. If null, the region the `aws` provider is configured for is used. | `null` | no |
| rds_instances | RDS instances to graph, keyed by a name used to label each series. | `{}` | no |
| rds_clusters | Aurora clusters to graph, keyed by a name used to label each series. | `{}` | no |
| load_balancers | Load balancers to graph. `arn_suffix`, not the full ARN. `type` is `'application'` or `'network'`. | `{}` | no |
| autoscaling_groups | Autoscaling groups to graph, keyed by a name used to label each series. | `{}` | no |
| lambda_functions | Lambda functions to graph, keyed by a name used to label each series. | `{}` | no |
| dynamodb_tables | DynamoDB tables to graph, keyed by a name used to label each series. | `{}` | no |
| elasticache_replication_groups | ElastiCache replication groups to graph. | `{}` | no |
| ecs_services | ECS services to graph. Both cluster and service names are required. | `{}` | no |
| enable_rds_instances | Draw the RDS instance section. | `true` | no |
| enable_rds_clusters | Draw the Aurora cluster section. | `true` | no |
| enable_load_balancers | Draw the load balancer section, application and network entries alike. | `true` | no |
| enable_autoscaling_groups | Draw the autoscaling group section. | `true` | no |
| enable_lambda_functions | Draw the Lambda section. | `true` | no |
| enable_dynamodb_tables | Draw the DynamoDB section. | `true` | no |
| enable_elasticache_replication_groups | Draw the ElastiCache section. | `true` | no |
| enable_ecs_services | Draw the ECS section. | `true` | no |
| alarm_arns | ARNs of alarms whose state is rendered as a status row above the graphs. | `[]` | no |
| widget_width | Grid columns each graph occupies. Must divide the 24-column grid evenly. | `12` | no |
| widget_height | Grid rows each graph occupies. | `6` | no |
| alarm_widget_height | Grid rows the alarm status row occupies. It always spans all 24 columns. | `4` | no |
| period | Seconds each datapoint covers, for every graph. | `300` | no |

## Outputs

| Name | Description |
|---|---|
| id | Identifier of the dashboard, which CloudWatch sets to its name. |
| arn | ARN of the dashboard. |
| dashboard_name | Full name of the dashboard, including the generated UUID when `name` was left null. |
| dashboard_body | The rendered dashboard JSON, for inspecting the widgets that were produced. |
| widget_count | Total number of widgets drawn, including the alarm status row. |

## License

MIT — see [LICENSE.md](LICENSE.md).
