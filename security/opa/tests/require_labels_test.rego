package kubernetes.admission

test_deny_missing_required_labels {
    input := {
        "request": {
            "object": {
                "metadata": {"name": "test", "labels": {}},
                "kind": "Deployment",
                "spec": {
                    "template": {
                        "metadata": {"labels": {}}
                    }
                }
            }
        }
    }
    deny_missing_labels with input as input
}

test_allow_required_labels {
    input := {
        "request": {
            "object": {
                "metadata": {"name": "test", "labels": {"app.kubernetes.io/name": "test"}},
                "kind": "Deployment",
                "spec": {
                    "template": {
                        "metadata": {"labels": {"app.kubernetes.io/name": "test"}}
                    }
                }
            }
        }
    }
    not deny_missing_labels with input as input
}
