resource "aws_wafregional_regex_match_set" "test" {
  name = "example"

  regex_match_tuple {
    field_to_match {
      data = "TEST"
      type = "HEADER"
    }

    regex_pattern_set_id = "${aws_wafregional_regex_pattern_set.test.id}"
    text_transformation  = "NONE"
  }
}

resource "aws_wafregional_regex_pattern_set" "test" {
  name                  = "example"
  regex_pattern_strings = ["test123"]
}

resource "aws_wafregional_rule" "test" {
  name        = "testWAFRule"
  metric_name = "testWAFRule"

  predicate {
    data_id = "${aws_wafregional_regex_match_set.test.id}"
    negated = false
    type    = "RegexMatch"
  }
}

resource "aws_wafregional_web_acl" "test" {
  name        = "testACL"
  metric_name = "testACL"

  default_action {
    type = "BLOCK"
  }

  rule {
    action {
      type = "ALLOW"
    }

    priority = 1
    rule_id  = "${aws_wafregional_rule.test.id}"
  }
}

resource "aws_wafregional_web_acl_association" "test" {
  resource_arn = "${aws_alb.alb.arn}"
  web_acl_id   = "${aws_wafregional_web_acl.test.id}"
}
