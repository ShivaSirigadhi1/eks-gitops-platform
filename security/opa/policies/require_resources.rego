package kubernetes.admission

import rego.v1

deny_missing_cpu_limit contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    not container.resources.limits.cpu
    msg := sprintf("Container %v is missing CPU limit — not allowed", [container.name])
}

deny_missing_memory_limit contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    not container.resources.limits.memory
    msg := sprintf("Container %v is missing memory limit — not allowed", [container.name])
}

deny_missing_cpu_request contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    not container.resources.requests.cpu
    msg := sprintf("Container %v is missing CPU request — not allowed", [container.name])
}

deny_missing_memory_request contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    not container.resources.requests.memory
    msg := sprintf("Container %v is missing memory request — not allowed", [container.name])
}

warn_excessive_cpu contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    cpu := container.resources.limits.cpu
    is_number(cpu)
    cpu > 8
    msg := sprintf("Container %v has excessive CPU limit (%v) — consider reducing", [container.name, cpu])
}

warn_excessive_memory contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    mem := container.resources.limits.memory
    is_number(mem)
    mem > 17179869184
    msg := sprintf("Container %v has excessive memory limit (%v) — consider reducing", [container.name, mem])
}

deny_non_guaranteed_qos contains msg if {
    namespace := input.request.object.metadata.namespace
    contains(namespace, "production")
    container := input.request.object.spec.template.spec.containers[_]
    container.resources.requests.cpu != container.resources.limits.cpu
    msg := sprintf("Container %v in production namespace requires equal CPU requests and limits for Guaranteed QoS", [container.name])
}

deny_missing_resources_production contains msg if {
    namespace := input.request.object.metadata.namespace
    contains(namespace, "production")
    container := input.request.object.spec.template.spec.containers[_]
    not container.resources.limits
    msg := sprintf("Container %v in production namespace is missing resource limits — not allowed", [container.name])
}
