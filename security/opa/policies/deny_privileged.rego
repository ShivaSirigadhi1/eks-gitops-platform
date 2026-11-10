package kubernetes.admission

import rego.v1

deny_privileged contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    container.securityContext.privileged == true
    msg := sprintf("Container %v is privileged — not allowed", [container.name])
}

deny_root_user contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    not container.securityContext.runAsNonRoot
    msg := sprintf("Container %v does not set runAsNonRoot — not allowed", [container.name])
}

deny_privilege_escalation contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    container.securityContext.allowPrivilegeEscalation == true
    msg := sprintf("Container %v allows privilege escalation — not allowed", [container.name])
}

deny_writable_rootfs contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    container.securityContext.readOnlyRootFilesystem == false
    msg := sprintf("Container %v has writable root filesystem — not allowed", [container.name])
}

deny_dangerous_capabilities contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    caps := container.securityContext.capabilities.add[_]
    caps in ["SYS_ADMIN", "NET_ADMIN", "SYS_PTRACE", "SYS_MODULE", "SYS_RAWIO", "SYS_BOOT"]
    msg := sprintf("Container %v adds dangerous capability %v — not allowed", [container.name, caps])
}

deny_keep_capabilities contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    container.securityContext.capabilities.drop[_] != "ALL"
    msg := sprintf("Container %v does not drop all capabilities — not allowed", [container.name])
}

deny_missing_seccomp contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    not container.securityContext.seccompProfile
    msg := sprintf("Container %v is missing seccomp profile — not allowed", [container.name])
}

deny_invalid_seccomp contains msg if {
    container := input.request.object.spec.template.spec.containers[_]
    container.securityContext.seccompProfile.type != "RuntimeDefault"
    msg := sprintf("Container %v has invalid seccomp profile type — must be RuntimeDefault", [container.name])
}
