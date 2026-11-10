package kubernetes.admission

import rego.v1

deny_unsigned_image contains msg if {
    namespace := input.request.object.metadata.namespace
    contains(namespace, "production")
    container := input.request.object.spec.template.spec.containers[_]
    not input.request.object.metadata.annotations["cosign.sigstore.dev/signature"]
    msg := sprintf("Container %v in production must have Cosign signature — not allowed", [container.name])
}
