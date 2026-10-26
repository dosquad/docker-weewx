# Automatic WeeWX updates

The `Update WeeWX` workflow checks the latest stable release of
[`weewx/weewx`](https://github.com/weewx/weewx/releases) daily at 03:23 UTC.
When a newer version is available, it commits the `WEEWX_RELEASE` change in
`Dockerfile` directly to `main`. It skips drafts, prereleases, unchanged versions,
and downgrades. Development commits are not tracked.

That commit triggers the existing CI and Docker Release workflows, which build
for amd64 and arm64 and publish `ghcr.io/dosquad/weewx:latest`. Running containers
still need to pull the new image and be recreated to use it.

## Enable updates

1. Create a fine-grained GitHub personal access token with this repository selected
   and **Contents: read and write**. Its owner must be allowed to commit directly
   to `main` under the repository's branch rules. Obtain organization approval if
   required. No Workflows permission is needed because only `Dockerfile` is edited.
2. In **Settings → Secrets and variables → Actions**, add a repository secret named
   **`WEEWX_UPDATE_TOKEN`** containing the token. Do not put the token in a file or chat.
3. Merge the workflow into the default branch so its schedule becomes active.
   To check immediately, select **Actions → Update WeeWX → Run workflow**.
4. Check the resulting commit and the CI / Docker Release runs. Renew the secret
   when its token expires. A missing or invalid token fails the update workflow.

The token is necessary because pushes made using the automatic `GITHUB_TOKEN`
do not trigger push workflows; see
[GitHub's workflow triggering documentation](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).
GitHub schedules can be delayed, and scheduled workflows in inactive public
repositories can be disabled by GitHub. The manual trigger remains available.

The update uses the current Dockerfile's blob SHA, so a concurrent change to that
file causes a conflict rather than being overwritten. Rerun the workflow after
resolving a conflict. This automation does not create repository release tags.
