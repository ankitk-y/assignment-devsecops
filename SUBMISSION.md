## A ranked list of every issue you found, each with a severity.

| Rank | Severity | File | Finding | Status |
| ---- | -------- | ---- | ------- | ------ |
| 1  | CRITICAL | `terraform/iam.tf` | `app_node` policy was `Action="*"`/`Resource="*"` (full admin). `ci_deployer` had unrestricted `ec2:RunInstances` + `iam:PassRole`, letting CI launch an EC2 instance, attach the admin role, and get full account access. | Fixed: removed `app_node`'s role/policy (unused, no instance profile attached it). Removed `ec2:RunInstances`, `iam:PassRole`, and unused `ecr:*` from `ci_deployer`; scoped `eks:DescribeCluster` to the prod cluster ARN. |
| 2  | CRITICAL | `terraform/terraform.tfvars`, `k8s/deployment.yaml`, `.github/workflows/deploy.yml` | Real credentials showed up in three places: hardcoded AWS keys/DB password in tfvars, plaintext `DB_PASSWORD`/`AWS_SECRET_ACCESS_KEY`/`OPENAI_API_KEY` as container env vars, and secrets echoed into CI build logs. | Fixed: removed all three. tfvars now points to `TF_VAR_*`/a secrets manager, variables marked `sensitive = true`. `deploy.yml` only logs `$GITHUB_SHA` now. |
| 3  | CRITICAL | `terraform/main.tf` | `call_recordings` S3 bucket had `acl = "public-read"`. Anyone online could read raw borrower call recordings. | Fixed: changed to `private`. |
| 4  | CRITICAL | `terraform/main.tf` | `aws_db_instance.primary` had `publicly_accessible = true`. | Fixed: set to `false`. App nodes already reach it privately via the attached security group. |
| 5  | CRITICAL | `terraform/main.tf` | `app_nodes` security group allowed SSH and all internal TCP ports from `0.0.0.0/0`. | Partially fixed: internal ports scoped to the VPC CIDR. SSH left open, no admin CIDR evidenced, TODO added. `lifecycle { ignore_changes = [ingress] }` blocks this fix from applying until resolved. |
| 6  | CRITICAL | `terraform/main.tf` | `transcripts` KMS key allowed `kms:Decrypt` to `Principal = "*"`, and its S3 bucket policy allowed `s3:GetObject` to `Principal = "*"`. Together, anyone could decrypt and read transcript data. | Fixed: removed both statements. No consumer was evidenced, so nothing was invented to replace them. |
| 7  | CRITICAL | `k8s/deployment.yaml` | `voice-gateway` ran `privileged: true` as `runAsUser: 0`. | Partially fixed: removed `privileged: true`, added `allowPrivilegeEscalation: false`, dropped all capabilities. Didn't set `runAsNonRoot`/`runAsUser`, Dockerfile only defines `USER root`, no verified non-root UID exists. |
| 8  | CRITICAL | `.github/workflows/pr-checks.yml` | `pull_request_target` ran with repo secrets while checking out and executing untrusted PR code. Also handed an AWS secret to a third-party action. | Fixed: switched to `pull_request` (no secrets for fork PRs), removed the AWS secret from the coverage action. |
| 9  | CRITICAL | `k8s/asr-streamer.yaml`, `app/server.py` | `/health/deep` claims to check Postgres+Redis, but the NetworkPolicy only allows egress to `voice-gateway`, so the probe will likely fail. Separately, the only app code in the repo is a static placeholder that implements no such check. | Not fixed. No verified Postgres/Redis network details exist to build a safe rule from, and no source exists for the real `asr-streamer` image. |
| 10 | CRITICAL | `k8s/deployment.yaml` | `voice-gateway` requested `16 CPU`/`64Gi` per pod; the largest staging node is `8 CPU`/`32Gi`. Pods could never schedule. | Fixed: sized to `2 CPU`/`4Gi`. Not load-tested, just structurally schedulable. |
| 11 | HIGH | `terraform/iam.tf` | `ci_deployer`'s OIDC trust condition is `repo:prodigal/*:*`, matching any repo/branch in the org, not just this one. | Not fixed. Repo doesn't specify the exact deploying repo/branch. |
| 12 | HIGH | `k8s/asr-streamer.yaml` | `asr-streamer` had no `securityContext` at all. | Partially fixed: added `allowPrivilegeEscalation: false`, dropped capabilities. Left `runAsNonRoot`/`runAsUser` out, no Dockerfile exists for this image to verify against. |
| 13 | HIGH | `k8s/rbac.yaml`, `k8s/asr-streamer.yaml` | `asr-streamer`'s ServiceAccount was bound to the built-in `edit` ClusterRole, and the Deployment never even referenced that ServiceAccount, so it ran as `default` instead. | Fixed: replaced with a namespaced `Role` (`get`/`list`/`watch` on configmaps/secrets) and added `serviceAccountName` so it actually applies. |
| 14 | HIGH | `.github/workflows/deploy.yml` | Every push to `main` deploys straight to production, no approval gate, no dependency on `pr-checks` passing. | Not fixed. Repo doesn't specify the intended approval process, and the team ships many times a day, a heavy gate risks encouraging bypass. |
| 15 | HIGH | `terraform/iam.tf`, `.github/workflows/deploy.yml` | `ci_deployer`'s `eks:DescribeCluster` only gets AWS-side connection info; `kubectl apply` also needs Kubernetes-side RBAC (`aws-auth` or an access entry), which doesn't exist anywhere in the repo. | Not fixed. Recommended a least-privilege ClusterRole via an EKS access entry, not `cluster-admin`, but the cluster's auth mode isn't evidenced. |
| 16 | HIGH | `terraform/main.tf` | RDS had `backup_retention_period = 0`, `deletion_protection = false`, `skip_final_snapshot = true`. No recovery path on accidental deletion. | Fixed: 7-day retention, deletion protection on, final snapshot required. |
| 17 | HIGH | `k8s/service.yaml`, `app/server.py` | TLS termination doesn't exist anywhere: the Service exposes `443` with a plain HTTP backend and no LB/certificate config, and the app itself is a plain `http.server` with no TLS support. | Not fixed. Ingress architecture and certificate ownership need to be decided first. |
| 18 | MEDIUM | `terraform/iam.tf`, `terraform/main.tf` | Two unverified placeholder identifiers: `vendor_analytics` trusts the vendor's whole account root instead of a specific principal, and the transcripts KMS key's `Root` statement trusts an account ID that looks like a doc placeholder. | Not fixed. No real values evidenced in the repo for either. |
| 19 | MEDIUM | `.github/workflows/pr-checks.yml` | The coverage-comment action is pinned to `@main`, a mutable branch, not a fixed commit. | Not fixed. No verified commit SHA to pin to. |

## Prioritisation

I fixed account/data compromise first: IAM escalation, exposed credentials, public storage/DB access, and CI secret exposure. Next was availability, especially the Kubernetes scheduling failure. I then addressed workload/RBAC hardening and recovery controls. Lower-risk configuration and supply-chain issues were left documented where the repo didn't provide enough information for a safe fix.

## What I didn't fix, and why

- Vendor's IAM principal, `ci_deployer`'s exact repo/branch, the SSH admin CIDR, and the KMS `Root` account ID: unconfirmed identifiers.
- `asr-streamer`'s Postgres/Redis egress: no real subnet, port, or Redis endpoint exists in the repo.
- `ci_deployer`'s Kubernetes-side RBAC mapping: depends on the cluster's auth mode, and the cluster itself isn't defined here.
- TLS termination and the deploy approval gate: architecture/process decisions that belong to the team.
- `asr-streamer`'s actual health-check behavior and the coverage action's commit history: need artifacts outside this repo.

I fixed what could be fixed from the repo. Where a safe fix required a missing fact, I left it documented rather than guessing.

## Answers to the three questions

**1. Secrets and encryption; SOC2 evidence of least privilege**

Nothing should be committed to the repo, credentials belong in a secrets manager (AWS Secrets Manager or SSM), pulled in via `TF_VAR_*` at apply time and via the Secrets Store CSI Driver or External Secrets in Kubernetes, never plaintext env vars. Every credential that was ever committed here should be treated as compromised and rotated. Data at rest should use KMS keys scoped to specific roles, not `Principal = "*"`, and everything in transit needs TLS end to end, which this repo can't currently show. For a SOC2 auditor, I'd bring resource-scoped IAM policies, S3 Block Public Access status, IAM Access Analyzer results showing no external access, `kubectl auth can-i --list` output per ServiceAccount matched to its Role, and a recurring signed-off access review, not a one-time snapshot.

**2. CI security controls: block vs. warn, and avoiding routing around it**

Block a deploy on known critical exposure: committed secrets, a wildcard `Resource`/`Principal` or public data access in an IaC change, privileged/root containers, and failing tests. TLS for the public borrower-facing endpoint belongs here too once the ingress architecture is decided, it shouldn't be warning-only given the data involved. Warn, don't block, on tuning issues that don't expose anything by themselves: resource sizing, missing PDBs/HPAs, an unpinned action. To avoid people routing around it, keep blocking checks fast with specific, actionable messages, and give one sanctioned override path (a required second approver) instead of none, if there's no legitimate fast lane, people build their own.

**3. The Kubernetes scheduling problem**

`voice-gateway` requested `16 CPU`/`64Gi` per pod, but the largest permitted staging node is `8 CPU`/`32Gi`, so the pod could never schedule no matter how many nodes existed, this isn't a capacity problem, it's a request bigger than any node can ever provide. I fixed it by sizing the request to `2 CPU`/`4Gi`, which fits with headroom, though it's not a load-tested number. With a request that actually fits, Karpenter can provision nodes and bin-pack multiple pods per node, and an HPA (not currently present) would actually work if added later. This doesn't touch the separate GPU node pool at all, neither workload requests GPU resources or tolerates its taint, so if that pool exists for something real, it's an unresolved cost question outside this repo's evidence.
