#!/usr/bin/env python3
"""Pre-import check for an AWX / Automation Platform object graph defined as code.

It is what your CI runs before importing the graph into the controller: the
controller would reject a dangling reference; your review would reject a plaintext
secret or an over-broad grant. It exits non-zero on the first problem it finds, and
zero when the graph resolves and is safe to import.

    validate.py <objects.yml> <project_dir>
"""
import os
import sys

import yaml

ALLOWED_ROLES = {"execute", "read", "use", "approve"}
RESOURCE_KINDS = {"job_template", "workflow", "inventory", "project", "credential"}
# credential types that fetch a secret from a third-party system (AWX: "secret lookups")
EXTERNAL_TYPES = {"HashiCorp Vault Secret Lookup", "HashiCorp Vault Signed SSH",
                  "CyberArk Central Credential Provider Lookup", "Microsoft Azure Key Vault",
                  "AWS Secrets Manager lookup"}
# credential fields whose value is a secret: never in the graph
SECRET_FIELDS = {"password", "ssh_key_data", "ssh_key_unlock", "become_password", "token", "secret_id"}


def reject(msg):
    print("REJECT:", msg, file=sys.stderr)
    sys.exit(1)


def main(objects_path, project_dir):
    d = yaml.safe_load(open(objects_path)) or {}
    projects = {p["name"] for p in d.get("projects", [])}
    inventories = {i["name"] for i in d.get("inventories", [])}
    creds = {c["name"]: c for c in d.get("credentials", [])}
    jts = {j["name"]: j for j in d.get("job_templates", [])}
    workflows = {w["name"] for w in d.get("workflows", [])}

    # 1. every job template resolves: project, inventory, playbook file, credentials
    for name, j in jts.items():
        if j.get("project") not in projects:
            reject(f"job template '{name}' references unknown or missing project '{j.get('project')}'")
        if j.get("inventory") not in inventories:
            reject(f"job template '{name}' references unknown or missing inventory '{j.get('inventory')}'")
        pb = j.get("playbook")
        if not pb or not os.path.isfile(os.path.join(project_dir, pb)):
            reject(f"job template '{name}' references playbook '{pb}' that is missing from the project")
        jcreds = j.get("credentials") or []
        if not jcreds:
            reject(f"job template '{name}' has no credentials: it could not authenticate")
        for c in jcreds:
            if c not in creds:
                reject(f"job template '{name}' references unknown credential '{c}'")

    # 2. governing access: no secret in the graph, secrets linked through input sources,
    #    RBAC least privilege
    for cname, c in creds.items():
        for field, value in (c.get("inputs") or {}).items():
            if "{{" in str(value):
                reject(f"credential '{cname}' field '{field}' holds a template expression: the controller "
                       "does not evaluate it; link the field to a secret manager through an input source")
            if field in SECRET_FIELDS:
                reject(f"credential '{cname}' stores '{field}' in the graph; link it to a secret manager "
                       "through an input source instead")
    for s in d.get("credential_input_sources", []):
        tgt, src = s.get("target_credential"), s.get("source_credential")
        if tgt not in creds:
            reject(f"an input source targets unknown credential '{tgt}'")
        if src not in creds:
            reject(f"the input source for '{tgt}' uses unknown source credential '{src}'")
        if creds[src].get("credential_type") not in EXTERNAL_TYPES:
            reject(f"the input source for '{tgt}' uses '{src}', which is not an external secret-manager credential")
        if creds[tgt].get("credential_type") in EXTERNAL_TYPES:
            reject(f"'{tgt}' is an external credential: its fields cannot be linked to another secret manager")
        if not s.get("input_field_name") or not s.get("metadata"):
            reject(f"the input source for '{tgt}' needs an input_field_name and the metadata locating the secret")
    for g in d.get("rbac", []):
        who = g.get("team") or g.get("user")
        if not who:
            reject("an rbac grant names neither a team nor a user")
        if g.get("role") not in ALLOWED_ROLES:
            reject(f"rbac grant to '{who}' uses over-broad role '{g.get('role')}'; use a scoped role {sorted(ALLOWED_ROLES)}")
        kind, _, rname = str(g.get("resource", "")).partition(":")
        if kind not in RESOURCE_KINDS or not rname:
            reject(f"rbac grant to '{who}' must target a specific resource (kind:name), not '{g.get('resource')}'")
        universe = {"job_template": set(jts), "workflow": workflows, "inventory": inventories,
                    "project": projects, "credential": set(creds)}[kind]
        if rname not in universe:
            reject(f"rbac grant to '{who}' targets unknown {kind} '{rname}'")

    # 3. every workflow is a well-formed DAG with a failure path to a rollback
    for w in d.get("workflows", []):
        nodes = {n["id"]: n for n in w["nodes"]}
        edges, targets, failure_targets = {}, set(), set()
        for nid, n in nodes.items():
            if n.get("job_template") not in jts:
                reject(f"workflow '{w['name']}' node '{nid}' runs unknown job template '{n.get('job_template')}'")
            succ = n.get("success_nodes") or []
            failn = n.get("failure_nodes") or []
            for t in succ + failn:
                if t not in nodes:
                    reject(f"workflow '{w['name']}' has an edge to unknown node '{t}'")
                targets.add(t)
            failure_targets.update(failn)
            edges[nid] = succ + failn
        roots = [nid for nid in nodes if nid not in targets]
        if len(roots) != 1:
            reject(f"workflow '{w['name']}' must have exactly one root node, found {len(roots)}")
        color = {nid: 0 for nid in nodes}  # 0 white, 1 grey, 2 black

        def dfs(u):
            color[u] = 1
            for v in edges[u]:
                if color[v] == 1:
                    reject(f"workflow '{w['name']}' has a cycle through node '{v}'")
                if color[v] == 0:
                    dfs(v)
            color[u] = 2

        for nid in nodes:
            if color[nid] == 0:
                dfs(nid)
        rollbacks = {nid for nid, n in nodes.items() if n.get("job_template") == "rollback"}
        if not (rollbacks & failure_targets):
            reject(f"workflow '{w['name']}' has no failure path leading to a rollback template")

    print("OK: the object graph resolves, secrets are linked not stored, access is scoped, the workflow is a valid DAG")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
