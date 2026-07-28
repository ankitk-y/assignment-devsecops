# DevSecOps Take-Home: Harden Prodigal's Staging Platform

Thanks for taking the time. We care about your judgment and prioritisation far
more than the number of things you fix — a focused, well-reasoned submission is
exactly what we're looking for.

## The scenario

You've just joined the two-person DevSecOps team. This repo is the `proagent`
**staging** platform for our real-time voice AI service. It works — it deploys,
it runs — but it was stood up quickly and has never had a security or reliability
pass. Your job is to do that pass.

Some context that matters:

- This platform handles **borrower call recordings and financial data**. We're
  driving toward SOC2.
- The voice team ships to `main` **many times a day** and the voice path has an
  **end-to-end latency budget under 1 second**. Whatever guardrails you add, the
  team has to be able to live with them.
- GPU capacity is expensive and staging has a hard cost guardrail (see
  `k8s/CLUSTER_CONTEXT.md`).

## What's in the repo

```
terraform/         AWS infra (VPC, S3, RDS, KMS, IAM, security groups)
k8s/               Kubernetes manifests (voice-gateway + asr-streamer, RBAC, netpol)
.github/workflows/ CI/CD pipelines (deploy + PR checks)
app/, Dockerfile   Placeholder service — not the focus, don't rewrite it
```

## What to do

> This repo has **a lot wrong with it — more than just the obvious.** Fix as much
> as you want; **we don't score by count.** What we actually evaluate is your
> **prioritisation and reasoning.** In your writeup, rank *every* issue you found
> by severity / blast radius, explain the order you'd fix them in production, and
> call out anything subtle you almost missed. A submission that fixes less but
> reasons sharply beats one that fixes everything mechanically.

1. **Audit** the repo. Find what's wrong — security, reliability, cost.
2. **Fix** what you can. Submit your changes as a fork. Do not raise PR or commit in the repo. Not
   everything is equally important; make your prioritisation visible.
3. **Write it up** (keep it tight — a ranked table plus short reasoning is
   perfect; put it at `SUBMISSION.md`):
   - A ranked list of **every** issue you found, each with a severity.
   - What you fixed, and *why in that order*.
   - Anything you chose not to fix (or would do differently with more runway),
     and why.
   - Answers to the three questions below.

## Three questions to answer in your writeup

1. Call recordings contain borrower PII and financial data. How would you handle
   secrets and encryption across this platform — and concretely, **what would you
   put in front of a SOC2 auditor** as evidence that least-privilege access is
   actually enforced?
2. The voice team ships many times a day and needs sub-1s latency. Your new CI
   security controls add friction. **What should block a deploy vs. only warn**,
   and how do you keep the team from routing around you?
3. The Kubernetes workload has a scheduling problem right now (see
   `k8s/CLUSTER_CONTEXT.md`). What's going on, how would you fix it, and how does
   your fix interact with autoscaling and GPU cost?

## Ground rules

- **You may use AI tools** (Claude, Copilot, Cursor, whatever you use day to day).
  We use them too. We're not testing whether you can work without them — we're
  interested in *how* you use them and whether you can stand behind the result.
- Assume you **cannot apply** against a live account. You don't need working
  credentials; reason from the code.
- If you make an assumption, write it down.
- Prioritise. A focused, well-reasoned submission beats an exhaustive one you
  can't explain.

## What happens next

We'll review your submission and then set up a **call** where we walk
through your reasoning together and work through a short live scenario. Come
ready to explain your choices — including the ones you'd push back on.
