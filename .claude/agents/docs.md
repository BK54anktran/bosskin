---
name: docs
description: Read-only. Pulls the API / permission / schema reference for an endpoint or module from docs/he-thong/ (api.md, quyen.md, csdl.md, phan-quyen.md).
tools: Read, Grep, Glob
model: haiku
---
Answer from docs/he-thong/ first (api.md, quyen.md and csdl.md are generated, so trust them over memory), then confirm against the controller.
Return the endpoint, method, required permission, scope and DTO fields. Note it if the docs and the code disagree. Do not edit anything.
