---
title: Verifying a set
sidebar_position: 6
description: "Check that the certified set you are about to install is the one the umbrella published: cosign over the signed checksum file, gh attestation for build provenance, and the gitlinks that make the set reproducible."
---

# Verifying a set

A [certified set](certified-sets.md) is a claim: these three product versions
were built and tested together, and this is what installs them. Until you can
check where that claim came from, it is a file in a repository — and anyone
with write access, or anyone who takes it, can edit a file in a repository.

Releases cut from the first signed tag onward therefore publish the set as
assets you can verify without trusting the release page, and this is how you
consume them.

## What a set release publishes

| Asset | What it is |
| --- | --- |
| `versions.yaml` | The manifest, verbatim from the tagged tree — the three pillars and every sibling module, with the version each one was certified at. |
| `require.txt` | The same set as a pasteable `go.mod` `require` block, with every module path resolved against the real tree rather than guessed from its name. |
| `gitlinks.txt` | The commit of each product repository at this tag. |
| `SET.md` | A short index: which set, which umbrella commit, what each file is. |
| `checksums.txt` | SHA-256 of the four files above. |
| `checksums.txt.sig` / `checksums.txt.pem` | A keyless signature over `checksums.txt`, and the short-lived certificate that made it. |

There is no long-lived signing key to trust, and none is published. The
signature is made by the release workflow itself with a certificate minted for
that single run, so what you check is not "who holds the key" but **which
workflow, in which repository, at which tag** produced the package. A build
provenance attestation, stored by GitHub rather than on the release page,
records the same thing a second way.

Signing cannot be applied retroactively — a release is signed by the run that
publishes it — so sets cut before this workflow existed carry no assets at
all. Look at the release page before you start: a verifiable set release lists
`checksums.txt.sig`.

### What this does *not* cover

- **The suite tag itself is not signed.** It is an annotated tag, cut by hand
  when the set is certified. What the workflow signs is the *content* of the
  set, not the pointer to it — which is why `gitlinks.txt` matters more than
  the tag name (see [step 4](#4-confirm-the-set-you-are-installing)).
- **The products' own binaries are verified in their own repositories.** A set
  release contains no executable: it names versions. Each pillar publishes
  signed binaries with their own SBOMs; verify those where you download them.
- **Libraries arrive through the Go module proxy**, where the checksum database
  is the equivalent guarantee. Nothing here replaces it.

## Before you start

Install [cosign](https://docs.sigstore.dev/cosign/system_config/installation/)
and the [GitHub CLI](https://cli.github.com/). Then set the set you are
verifying and download its assets into their own directory:

```bash
export TAG=vX.Y.Z             # the suite tag, e.g. v1.30.0

gh release download "$TAG" --repo jcsvwinston/quantum --dir "quantum-$TAG"
cd "quantum-$TAG"
```

## 1. Verify the signature over the checksum file

```bash
cosign verify-blob checksums.txt \
  --signature checksums.txt.sig \
  --certificate checksums.txt.pem \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity "https://github.com/jcsvwinston/quantum/.github/workflows/release-set.yml@refs/tags/${TAG}"
```

`Verified OK` means the checksum file was produced by
[`.github/workflows/release-set.yml`](https://github.com/jcsvwinston/quantum/blob/main/.github/workflows/release-set.yml)
in `jcsvwinston/quantum`, running at the tag you named, and has not been
altered since.

:::caution The identity ends at the tag, not at `main`
Nearly every cosign example on the internet ends the identity in
`@refs/heads/main`. That string verifies nothing here. The release workflow
runs at the **tag** ref, so the certificate it signs with names
`@refs/tags/<tag>` — substitute the tag you are verifying, exactly as the
command above does. An identity ending in `refs/heads/main` will fail with
`none of the expected identities matched`, and that failure is correct.
:::

From a script, match the shape rather than rewriting the identity per tag:

```bash
cosign verify-blob checksums.txt \
  --signature checksums.txt.sig \
  --certificate checksums.txt.pem \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  --certificate-identity-regexp '^https://github\.com/jcsvwinston/quantum/\.github/workflows/release-set\.yml@refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$'
```

Keep the anchors and keep `refs/tags/` in the pattern. A regexp loose enough to
match any ref accepts a signature made from any branch of the repository, which
is most of the guarantee gone.

## 2. Carry the proof across to the manifest

The signature covers `checksums.txt`. The checksum file covers the other four,
so one more command moves the trust onto the files you are about to read:

```bash
sha256sum -c checksums.txt
```

On macOS, where there is no `sha256sum`, that is `shasum -a 256 -c checksums.txt`.

## 3. Verify the build provenance

The second, independent proof does not use the release assets at all: it asks
GitHub which workflow run produced the file in front of you.

```bash
gh attestation verify versions.yaml \
  --repo jcsvwinston/quantum \
  --signer-workflow jcsvwinston/quantum/.github/workflows/release-set.yml
```

This matches the file by digest against the attestation the release job wrote,
and `--signer-workflow` is the part that matters: it refuses an attestation
signed by any other workflow, in any other repository. One attestation covers
every file listed in the checksum file, so the same command works for
`require.txt`, `gitlinks.txt` and `SET.md`. It reads public data and needs no
credentials beyond a logged-in `gh`.

## 4. Confirm the set you are installing

Verification so far proves where the files came from. This step is what makes
them useful.

**Install exactly what the set certifies.** `require.txt` is the block; paste
it into your `go.mod` in one commit, rather than moving one pillar at a time:

```bash
cat require.txt
```

**Rebuild the certified tree, if you need to.** `versions.yaml` names *tags*,
and a tag is a movable pointer in someone else's repository. `gitlinks.txt`
names *commits*, which are not movable — so those three lines, and not the
version numbers, are what makes a set reproducible years later:

```bash
git clone https://github.com/jcsvwinston/quantum
cd quantum && git checkout "$TAG" && git submodule update --init
git ls-tree HEAD quark nucleus orbit      # compare against gitlinks.txt
```

If a line differs, the tree you just checked out is not the tree the set was
certified on, whatever the tags say.

## When verification fails

- **`no matching signatures` or `none of the expected identities matched`** —
  the identity string is the first thing to check, and the tag inside it the
  first part of that. See the note in step 1.
- **The release publishes no `checksums.txt.sig`** — it predates signed set
  releases. Its `versions.yaml` is still readable in the repository at that
  tag; it simply carries no proof of its own.
- **`gh attestation verify` reports no attestation** — same reason, same
  answer.
- **The digests match but a gitlink does not** — stop. A signed manifest whose
  tree does not reconstruct is the one case worth reporting rather than working
  around.

Report anything that verifies against an identity other than the one above, or
a set file whose digest is absent from a validly signed checksum file, through
the [security policy](https://github.com/jcsvwinston/quantum/blob/main/SECURITY.md)
rather than a public issue.
