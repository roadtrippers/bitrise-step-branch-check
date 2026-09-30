# Branch Check (Bitrise step)

Fails the build if the branch being built is behind its base branch (`main`, `master`, `develop`, etc.).

Intended for distribution workflows such as Firebase App Distribution or TestFlight, where a
build should never ship from a branch that is missing changes already on `main`.

## Usage

Add the step right after **Git Clone Repository** so a stale branch fails before any expensive
build work runs.

```yaml
- git::https://github.com/roadtrippers/bitrise-step-branch-check.git@1.0.0:
    inputs:
    - base_branch: main
```

In the Bitrise workflow editor you can also add it as a **Custom step from git URL** using the
same repository URL and tag.

## Inputs

| Input           | Description                                                                                   | Default               |
| --------------- | --------------------------------------------------------------------------------------------- | --------------------- |
| `base_branch`   | The branch that represents "main" for the project. The source branch must contain all of it.  | `main`                |
| `source_branch` | The branch being built.                                                                       | `$BITRISE_GIT_BRANCH` |
| `skip_branches` | Additional branches to skip the check on, separated by spaces or commas.                      | (none)                |

Builds of `base_branch` itself are always skipped.

## Outputs

| Output                        | Description                                                        |
| ----------------------------- | ------------------------------------------------------------------ |
| `BRANCH_CHECK_COMMITS_BEHIND` | Number of commits on the base branch missing from the source branch. `0` when up to date or skipped. |

## How it works

1. Fetches `base_branch` and the tip of `source_branch` from `origin`, unshallowing the clone if needed.
2. Runs `git merge-base --is-ancestor <base> <source>`.
3. If the base has commits the source branch lacks, the step prints them and exits non-zero.

On pull request builds Bitrise checks out a merge commit of the PR into its target branch, so `HEAD`
would always look up to date. The step therefore compares the remote tip of the source branch
(`origin/$BITRISE_GIT_BRANCH`) rather than `HEAD`. If that branch cannot be fetched (for example it
was deleted), it falls back to `HEAD`.

## Example failure output

```
[branch-check] Source branch: feature/new-map
[branch-check] Base branch:   main
[branch-check] FAILED: 'feature/new-map' is 3 commit(s) behind 'main'.
[branch-check] Commits on 'main' missing from 'feature/new-map':
[branch-check]   8d34324 Updating versions
[branch-check]   a549ffb Adding log level to see free drive billing logs
[branch-check]   f52767a Merge pull request #113 from roadtrippers/mk-hide_mapbox_components
[branch-check] Merge or rebase 'main' into 'feature/new-map' and push again.
```

## Testing locally

With the [Bitrise CLI](https://github.com/bitrise-io/bitrise) installed, from inside any git
checkout:

```bash
BITRISE_GIT_BRANCH=my-feature bitrise run test --config /path/to/bitrise-step-branch-check/bitrise.yml
```

Or run the script directly:

```bash
base_branch=main source_branch=my-feature ./step.sh
```

## Releasing

Tag a release and reference the tag from your apps:

```bash
git tag 1.0.0
git push origin 1.0.0
```

## License

MIT
