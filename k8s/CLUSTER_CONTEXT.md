# Cluster context (staging)

You do not have live cluster access for this exercise. Use this as ground truth
when reasoning about scheduling.

- EKS 1.29, managed by Karpenter.
- Default on-demand node pool: `m5.2xlarge` (8 vCPU, 32 GiB) — max 4 nodes.
- GPU node pool: `g5.xlarge` (4 vCPU, 16 GiB, 1x A10G) — taint `nvidia.com/gpu=true:NoSchedule`, max 2 nodes.
- No nodes larger than `m5.2xlarge` are permitted in staging (cost guardrail).

`kubectl get pods -n proagent` currently shows:

```
NAME                             READY   STATUS    RESTARTS   AGE
voice-gateway-6c9d4f7b8f-2xk4p   0/1     Pending   0          11m
voice-gateway-6c9d4f7b8f-h7ttq   0/1     Pending   0          11m
```

`kubectl describe` on a pod ends with:

```
Warning  FailedScheduling  default-scheduler  0/3 nodes are available:
3 Insufficient cpu, 3 Insufficient memory. preemption not helpful.
```
