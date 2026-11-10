package kubernetes.admission

import rego.v1

required_labels := {
    "app.kubernetes.io/name": "application name",
    "app.kubernetes.io/part-of": "parent application name",
    "app.kubernetes.io/managed-by": "tool used to manage the resource",
}

deny_missing_labels contains msg if {
    resource := input.request.object
    label_key := required_labels[_]
    not resource.metadata.labels[label_key]
    msg := sprintf("Resource %v is missing required label %v — not allowed", [resource.metadata.name, label_key])
}

warn_missing_team_label contains msg if {
    resource := input.request.object
    not resource.metadata.labels["team"]
    msg := sprintf("Resource %v is missing 'team' label — consider adding it", [resource.metadata.name])
}

warn_missing_environment_label contains msg if {
    resource := input.request.object
    not resource.metadata.labels["environment"]
    msg := sprintf("Resource %v is missing 'environment' label — consider adding it", [resource.metadata.name])
}

deny_missing_deployment_labels contains msg if {
    resource := input.request.object
    resource.kind == "Deployment"
    pod_labels := resource.spec.template.metadata.labels
    label_key := required_labels[_]
    not pod_labels[label_key]
    msg := sprintf("Deployment %v is missing required pod label %v — not allowed", [resource.metadata.name, label_key])
}
