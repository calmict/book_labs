# Chapter 21 — Answers (model solution)

## The hiring

    certificatesigningrequest.certificates.k8s.io/stagista approved
    Username  stagista
    Groups    [tirocinanti system:authenticated]

## The borders

    get pods                  -> No resources found (allowed!)
    run test                  -> Forbidden: cannot create pods
    get secrets               -> Forbidden: cannot list secrets
    get pods -n kube-system   -> Forbidden: wrong namespace
    can-i --list: pods [get list watch] plus the selfsubject reviews
    everyone has — the whole job description in five lines

## The robot

    before the binding:  "reason": "Forbidden", "code": 403
    after the binding:   { "kind": "PodList", ... }

## The three questions

**a. Where does the intern "exist"? Why are human users not API objects,
and what does that mean for revocation?**

She exists in exactly one place: a certificate signed by the cluster CA,
where CN carries the username and O the groups. The apiserver never
consulted a user database — it verified a signature and trusted what the
certificate declares. This keeps identity pluggable (certificates today,
OIDC tokens from your company SSO tomorrow, same RBAC downstream) and
keeps the API free of password management. The sting is revocation:
Kubernetes checks no certificate revocation lists, so a leaked certificate
is valid until it EXPIRES. That is why expirationSeconds: 86400 is not
stinginess but strategy — with humans, short-lived credentials and an
external issuer are the only sane setup, and the RoleBinding (which you
CAN delete instantly) is the real off switch.

**b. Read your Role as a verbs-resources-namespace triple, explain the
three Forbidden, and why least privilege is made of borders.**

The Role says: verbs get/list/watch, resources pods, and — implicit in the
object's own namespace — default. Three coordinates, three walls: run test
fails on the VERB wall (create is not in the list); get secrets fails on
the RESOURCE wall (secrets are not pods, even in the right namespace);
kube-system fails on the NAMESPACE wall (a Role cannot see beyond its own
fence; crossing it takes a ClusterRole). Least privilege is not a list of
prohibitions — nobody could enumerate everything a user must not do — it
is a tiny room whose walls are default-deny: everything outside the triple
is Forbidden without ever being named. You saw it in can-i --list: five
lines describe the entire universe of what stagista can do.

**c. Intern versus robot: the two authentications compared, who renews
what, and why one ServiceAccount per workload?**

The intern authenticates with something she HOLDS: a private key and a
certificate, issued once, renewed by repeating the ceremony (or by an
external identity provider); Kubernetes stores nothing about her. The
robot authenticates with something the platform GIVES it: a ServiceAccount
is a real API object, and the kubelet mounts into the pod a short-lived,
audience-bound token that it rotates automatically — the workload never
handles a long-lived secret. One ServiceAccount per workload is the same
least-privilege logic applied to software: shared identities mean shared
permissions (the union of everyone's needs) and unreadable audit logs.
With its own account, the robot's compromise is bounded by its own
binding, its token dies young, and the audit trail says exactly who did
what — system:serviceaccount:default:robot, black on white.
