package kubernetes.admission

test_deny_missing_cpu_limit {
    input := {
        "request": {
            "object": {
                "spec": {
                    "template": {
                        "spec": {
                            "containers": [
                                {"name": "test", "resources": {"limits": {"memory": "512Mi"}}}
                            ]
                        }
                    }
                }
            }
        }
    }
    deny_missing_cpu_limit with input as input
}

test_allow_cpu_limit {
    input := {
        "request": {
            "object": {
                "spec": {
                    "template": {
                        "spec": {
                            "containers": [
                                {"name": "test", "resources": {"limits": {"cpu": "500m", "memory": "512Mi"}}}
                            ]
                        }
                    }
                }
            }
        }
    }
    not deny_missing_cpu_limit with input as input
}

test_deny_production_requires_guaranteed_qos {
    input := {
        "request": {
            "object": {
                "metadata": {"namespace": "blueprint-production"},
                "spec": {
                    "template": {
                        "spec": {
                            "containers": [
                                {"name": "test", "resources": {"requests": {"cpu": "100m"}, "limits": {"cpu": "200m"}}}
                            ]
                        }
                    }
                }
            }
        }
    }
    deny_non_guaranteed_qos with input as input
}
