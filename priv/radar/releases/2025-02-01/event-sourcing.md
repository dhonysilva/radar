---
title: "Event Sourcing"
ring: assess
quadrant: techniques
tags: [architecture, data]
related: [cqrs, domain-driven-design, kafka]
---

**Event sourcing** stores every state change as an immutable event rather than just the current state, giving a full audit trail for free. It's powerful but adds real operational complexity, so we're still assessing where the trade-off is worth it.
