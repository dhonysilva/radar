---
title: "Blue-Green Deployments"
ring: adopt
quadrant: techniques
tags: [deployment, reliability]
related: [trunk-based-development, dark-launching, kubernetes]
---

**Blue-green deployments** run two identical production environments and switch traffic between them, making rollback a router change instead of a redeploy. It's our standard release strategy for anything stateful enough that a bad rollout is expensive.
