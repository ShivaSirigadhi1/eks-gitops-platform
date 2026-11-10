package kubernetes.admission

test_deny_privileged_container {
    input := {
        "request": {
            "object": {
                "spec": {
                    "template": {
                        "spec": {
                            "containers": [
                                {"name": "test", "securityContext": {"privileged": true}}
                            ]
                        }
                    }
                }
            }
        }
    }
    deny_privileged with input as input
}

test_allow_non_privileged_container {
    input := {
        "request": {
            "object": {
                "spec": {
                    "template": {
                        "spec": {
                            "containers": [
                                {"name": "test", "securityContext": {"privileged": false}}
                            ]
                        }
                    }
                }
            }
        }
    }
    not deny_privileged with input as input
}

test_deny_root_user {
    input := {
        "request": {
            "object": {
                "spec": {
                    "template": {
                        "spec": {
                            "containers": [
                                {"name": "test", "securityContext": {}}
                            ]
                        }
                    }
                }
            }
        }
    }
    deny_root_user with input as input
}

test_allow_non_root_user {
    input := {
        "request": {
            "object": {
                "spec": {
                    "template": {
                        "spec": {
                            "containers": [
                                {"name": "test", "securityContext": {"runAsNonRoot": true}}
                            ]
                        }
                    }
                }
            }
        }
    }
    not deny_root_user with input as input
}
