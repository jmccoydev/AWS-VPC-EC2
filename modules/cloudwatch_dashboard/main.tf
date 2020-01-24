################################################################################
# Data Providers
data "aws_region" "current_region" {}

################################################################################
# Resources
resource "aws_cloudwatch_dashboard" "usage_dashboard" {
  dashboard_name = "usage"

  dashboard_body = <<EOF
 {
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "view": "timeSeries",
                "stacked": false,
                "metrics": [
                    [ "AWS/EC2", "NetworkIn" ],
                    [ ".", "NetworkOut" ]
                ],
                "region": "${data.aws_region.current_region.name}",
                "title": "Network Usage"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/EC2", "CPUUtilization", { "label": "Average" } ],
                    [ "...", { "stat": "Maximum", "label": "Maximum" } ],
                    [ "...", { "stat": "Minimum", "label": "Minimum" } ]
                ],
                "view": "timeSeries",
                "stacked": false,
                "region": "${data.aws_region.current_region.name}",
                "title": "CPU Usage",
                "period": 300,
                "yAxis": {
                    "left": {
                        "max": 100,
                        "min": 0
                    }
                }
            }
        }
    ]
}
 EOF
}