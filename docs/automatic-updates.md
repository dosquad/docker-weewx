# Automatic WeeWX updates

The `Update WeeWX` workflow checks the latest stable release of
[`weewx/weewx`](https://github.com/weewx/weewx/releases) daily at 03:23 UTC.
When a newer version is available, it commits the `WEEWX_RELEASE` change in
`Dockerfile` directly to `main`. It skips drafts, prereleases, unchanged versions,
and downgrades. Development commits are not tracked. It creates a matching Git
tag (for example, `v5.2.0`) at the version-update commit. If the pin is already
current but its tag is missing, it tags the inspected `main` commit instead.
Existing tags are never moved.

Commits to `main` and pull requests run CI, including build validation for amd64
and arm64, without publishing images. Only tag pushes trigger Docker Release.
A stable version tag such as `v5.2.0` builds once for both architectures and
publishes that same image as `ghcr.io/dosquad/weewx:5.2.0`,
`ghcr.io/dosquad/weewx:5.2`, and `ghcr.io/dosquad/weewx:latest`.
`latest` therefore follows the most recently published stable tagged release.
Prerelease tags do not update `latest`. Running containers still need to pull
the new image and be recreated to use it.

## Enable updates

1. Create a fine-grained GitHub personal access token with this repository selected
   and **Contents: read and write**. Its owner must be allowed to commit directly
   to `main` and create `v*` tags under the repository's branch and tag rules. Obtain organization approval if
   required. The updater edits only `Dockerfile` and creates Git tag references.
2. In **Settings → Secrets and variables → Actions**, add a repository secret named
   **`WEEWX_UPDATE_TOKEN`** containing the token. Do not put the token in a file or chat.
3. Merge the workflow into the default branch so its schedule becomes active.
   To check immediately, select **Actions → Update WeeWX → Run workflow**.
4. Check the resulting commit, Git tag, and the CI / Docker Release runs. Renew the secret
   when its token expires. A missing or invalid token fails the update workflow.

The token is necessary because pushes made using the automatic `GITHUB_TOKEN`
do not trigger push workflows; see
[GitHub's workflow triggering documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).
GitHub schedules can be delayed, and scheduled workflows in inactive public
repositories can be disabled by GitHub. The manual trigger remains available.

The update uses the current Dockerfile's blob SHA, so a concurrent change to that
file causes a conflict rather than being overwritten. Rerun the workflow after
resolving a conflict. If tagging fails after the commit succeeds, rerunning the
updater recovers the missing tag. If an image build fails after tagging succeeds,
rerun the failed Docker Release run; the updater will not recreate an existing tag.
GitHub Release entries are not needed: Renovate discovers image versions from GHCR.

## Renovate in deployment repositories

Use the published image name `ghcr.io/dosquad/weewx` and a full version tag in
`compose.yml` (or your Kubernetes manifests). For example, **after that version
has been published**:

```yaml
services:
  weewx:
    image: ghcr.io/dosquad/weewx:5.2.0
```

Enable Renovate in the repository containing those deployment files. Its standard
Docker support detects these numeric tags without a custom versioning rule.
A minimal `renovate.json` is:

```json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"]
}
```

Renovate opens PRs updating the version when a newer image is published. Your
existing deployment process must apply the merged changes to recreate containers;
Renovate itself does not restart them. Use full `major.minor.patch` tags to receive
patch upgrades; `latest` does not identify an upstream version. See
[Renovate's Docker documentation](https://docs.renovatebot.com/docker/).

The automatic tags track WeeWX releases. Container-only changes on `main` run CI
but do not publish images or change `latest`. Publish a new version tag to release
those changes.
