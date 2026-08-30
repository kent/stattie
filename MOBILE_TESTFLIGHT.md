# Ship Stattie to TestFlight from a phone
## One-line Cursor command

In Cursor Mobile, open `kent/stattie` and say:

> Deploy to TestFlight

An always-applied Cursor project rule treats this phrase—and obvious spelling variations—as authorization to finish the full workflow: pass hosted iOS CI, merge the relevant PR into `main`, issue the trusted `/testflight` trigger, monitor App Store Connect processing, and repair failures. If there is no relevant PR, it deploys the current `main` through manual workflow dispatch.
Cursor Mobile owns the coding and pull-request loop. GitHub Actions owns the macOS-only archive, signing, and upload loop. Apple signing credentials are deliberately not available to Cursor's Linux cloud agents.

## One-time phone setup

1. Install Cursor for iOS, sign in, and connect the GitHub repository `kent/stattie`. The native beta currently requires iOS 26; on an older iPhone, open `cursor.com/agents` in Safari and add the web app to the Home Screen instead.
2. Keep GitHub Mobile installed, or sign in to GitHub in Safari, so workflow runs and App Store processing links are easy to open.
3. In Cursor, select `kent/stattie` and start work from `main`.

## Ship a change

1. Ask Cursor Mobile to implement the change, run the available checks, and open a pull request. Cursor Cloud can edit Swift and open the PR, but it cannot run Xcode because its worker is Linux.
2. Review the diff and the **iOS CI / Build and test** check in Cursor Mobile. Ask the agent to fix any failure.
3. Mark the PR ready and merge it into `main` from Cursor Mobile.
4. On the now-merged PR, add a top-level comment whose complete body is:

   ```text
   /testflight
   ```

5. Follow the **TestFlight / Archive and upload** check. The workflow signs the merged `main` commit on a GitHub-hosted Mac and waits for App Store Connect to process the build.
6. Open TestFlight on the iPhone when processing finishes. Internal testers normally see the build without Beta App Review; external groups can still require Apple's beta review.

The trigger accepts only an exact `/testflight` comment from a repository owner, member, or collaborator, and only on a PR already merged into `main`. A comment on an open PR or a PR targeting another branch will fail before Apple credentials are made available.

App Store Connect group **Stattie Mobile CI** is an internal group with access to all builds. Kent's installed tester account is in that group, so each processed CI upload is distributed to the phone automatically.

## Manual recovery path

If the PR comment event was missed, open **GitHub → `kent/stattie` → Actions → TestFlight → Run workflow**, select `main`, and run it. GitHub requires the workflow to exist on the default branch before this button appears.

Do not rerun a workflow that already uploaded successfully just because App Store processing is slow. Start a new workflow run only when a new build number is needed.

## Versioning

- The marketing version comes from `MARKETING_VERSION` in the Xcode project. Change it when the public version should change.
- The workflow owns `CURRENT_PROJECT_VERSION`. Stattie's latest pre-automation upload is build 4, so workflow run 1 produces build 5, run 2 produces build 6, and so on.
- Renaming or replacing `.github/workflows/testflight.yml` resets GitHub's per-workflow run counter. If that ever happens, update the `+ 4` build-number offset before deploying.

## Credential boundary

The GitHub `TestFlight` environment is restricted to `main` and contains:

- Variable `APPSTORE_ISSUER_ID`
- Variable `APPSTORE_API_KEY_ID`
- Secret `APPSTORE_API_PRIVATE_KEY`
- Secret `APPSTORE_CERTIFICATES_FILE_BASE64`
- Secret `APPSTORE_CERTIFICATES_PASSWORD`

The API private key, CI distribution key, and provisioning profiles must never be committed. They also do not belong in Cursor Cloud secrets: Cursor does not need them to create or review a PR, and its Linux workers cannot use them to build iOS archives.

The CI distribution certificate and profile expire on August 30, 2027. Rotate them before expiry by creating a new CI certificate/profile, updating the two certificate secrets, and keeping the profile name `AppStore com.stattie.app CI`.

## If a deployment fails

- **iOS CI fails:** ask the same Cursor agent to inspect the check and push a fix to the PR.
- **Comment is ignored:** confirm the body is exactly `/testflight`, the PR is merged into `main`, and the workflow is present on `main`.
- **Signing fails:** verify all five GitHub environment values exist and the profile is active for `com.stattie.app`.
- **Duplicate build number:** start a new TestFlight workflow run; do not rerun the old attempt.
- **Apple processing fails:** open the build in App Store Connect and use the uploaded diagnostics artifact from the GitHub run.
