package kubernetes.admission

test_deny_unapproved_registry {
    input := {
        "request": {
            "object": {
                "spec": {
                    "template": {
                        "spec": {
                            "containers": [
                                {"name": "test", "image": "unapproved.io/image:latest"}
                            ]
                        }
                    }
                }
            }
        }
    }
    deny_unapproved_registry with input as input
}

test_allow_approved_registry {
    input := {
        "request": {
            "object": {
                "spec": {
                    "template": {
                        "spec": {
                            "containers": [
                                {"name": "test", "image": "ghcr.io/your-org/app:v1.0.0"}
                            ]
                        }
                    }
                }
            }
        }
    }
    not deny_unapproved_registry with input as input
}

test_deny_latest_tag_in_production {
    input := {
        "request": {
            "object": {
                "metadata": {"namespace": "blueprint-production"},
                "spec": {
                    "template": {
                        "spec": {
                            "containers": [
                                {"name": "test", "image": "ghcr.io/your-org/app:latest"}
                            ]
                        }
                    }
                }
            }
        }
    }
    deny_latest_tag with input as input
}
