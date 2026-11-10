package kubernetes.admission

import rego.v1

allowed_registries := {
    "ghcr.io/your-org",
    "docker.io/library",
    "registry.k8s.io",
    "gcr.io/google-containers",
}

deny_unapproved_registry contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    image := container.image
    not is_approved(image)
    msg := sprintf("Container %v uses image %v from an unapproved registry — not allowed", [container.name, image])
}

deny_latest_tag contains msg if {
    namespace := input.request.object.metadata.namespace
    contains(namespace, "production")
    container := input.request.object.spec.template.spec.containers[_]
    endswith(container.image, ":latest")
    msg := sprintf("Container %v uses 'latest' tag in production — not allowed", [container.name])
}

deny_missing_tag contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    not contains(container.image, ":")
    msg := sprintf("Container %v is missing image tag — not allowed", [container.name])
}

is_approved(image) if {
    registry := allowed_registries[_]
    startswith(image, registry)
}

deny_init_container_registry contains msg if {
    container := input.request.object.spec.template.spec.initContainers[_]
    image := container.image
    not is_approved(image)
    msg := sprintf("Init container %v uses image %v from an unapproved registry — not allowed", [container.name, image])
}
