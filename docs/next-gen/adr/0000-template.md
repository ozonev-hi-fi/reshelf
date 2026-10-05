# ADR-NNNN — <Decision title>

Status: Proposed | Accepted | Superseded by ADR-NNNN | Date: yyyy-MM-dd | Related requirements: NG-XXX-NNN

Copy this file to `adr/NNNN-short-title.md`. Use the next free number.

## Context

What problem needs a decision? Which requirements drive it? What constraints apply?

## Options

| Option | Short description |
|---|---|
| A | ... |
| B | ... |

## Pros and cons

| Option | Pros | Cons |
|---|---|---|
| A | ... | ... |
| B | ... | ... |

## License and bundling check

Fill this section for every dependency. That includes NuGet packages, native libraries and external tools. See NG-PLT-004.

| Option | License | Can we ship it inside our portable zip? | User must install it? |
|---|---|---|---|
| A | ... | yes / no (why) | yes / no |

## Decision

The chosen option, and why. Follow the order of the dependency rule: functionality first, then NuGet when equal, then the license check, then the install check.

## Consequences

What becomes easier or harder? What follow-up work does it create? For example, an in-app installation check (NG-PLT-006).
