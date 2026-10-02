# Security policy

## Reporting a vulnerability

Please **do not** open a public issue for security problems.

Report vulnerabilities privately through GitHub's **"Report a vulnerability"** button on this
repository's **Security** tab (private vulnerability reporting). Include:

- the affected file(s) and a description of the issue;
- steps to reproduce or a proof of concept;
- the impact you expect.

You should receive an acknowledgement within a few days.

## Scope

This repository is reference code. In scope: flaws in the state issuing and verification, the frontend
nonce handling, the provider integrations, or documentation that would lead implementers into an
insecure setup.

Out of scope: vulnerabilities in your own application logic built on top of this code, in Xano itself,
or in Google or LinkedIn. Report those to the relevant vendor.

Never include real client secrets, `OAUTH_STATE_SECRET` values, authorization codes or access tokens in
a report.
