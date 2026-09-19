---
name: release
description: Release Krowi_Brokers_Currency. Verifies branch, working tree, Libs/ submodules, Changelog.md and TOC version are release-ready, then runs the Krowi Addon Manager "Full Package" (release notes, README, commit, tag, zip, upload to Wago, CurseForge and GitHub). Use when the user says release, ship, publish, cut a version, or full package.
---

Release Krowi_Brokers_Currency by driving the existing Krowi Addon Manager. Do not re-implement any packaging step; the Python project already does all of it.

## What "Full Package" does

Operation 10 in the addon manager (`--operation package`) runs, in this order, from
`E:\World of Warcraft Addon Development\Krowi_AddonManager\Krowi_AddonManager_Python\main.py`:

1. Generate `_Packaging/ReleaseNotes.md` from `_Packaging/Changelog.md` (all entries whose major version matches the TOC version).
2. Regenerate `README.md` from `_Packaging/Description.md` plus badges built from the TOC `Interface` lines.
3. `git add .` then `git commit -m "Release <version>"` then `git push` on the **current branch**.
4. Create annotated tag `<version>` and `git push origin <version> --force`.
5. Zip the addon to `%LOCALAPPDATA%\Temp\Krowi_Brokers_Currency Export\` (opens Explorer). The zip walks the working tree, so the `Libs/` submodule checkouts are included as they are on disk. Dotfiles, `.md` files and `.toc` files under `Libs/` are skipped.
6. Upload to Wago, CurseForge, and GitHub Releases with `ReleaseNotes.md` as changelog. Project IDs come from `X-CurseForge-ID` and `X-Wago-ID` in the TOC.

Everything after step 3 is outward-facing and not reversible. Preflight exists to make sure step 3 commits exactly what is intended.

## Conventions in this repo

- Releases are tagged on `dev`. Every `Release X.Y` commit and tag lives on `dev`. `main` is behind and is not part of the release flow today.
- Version is `major.minor` (e.g. `9.0`, `7.2`). Tag name equals the TOC `## Version:` value.
- The changelog header must be `## <version> - <YYYY-MM-DD>`. Without the date the regex in the addon manager does not match and the release fails with "No changelog entries found".
- The TOC is multi-flavor: `## Interface:` lists Retail, Mists Classic, TBC Anniversary and Classic Era builds. The badges and the upload game-version list are built from that list.
- Libraries are git submodules under `Libs/`: `Krowi_Util`, `Krowi_Menu`, `Krowi_Currency`, `Krowi_Brokers`. The release commit records whichever commit each submodule is checked out on. Bumping a library means checking out the wanted commit in the submodule first; `git add .` then commits the new pointer.
- `Krowi_Brokers_Time` and `Krowi_Brokers_System` share the `Krowi_Brokers` library. A library change that motivates this release usually motivates releasing those too; mention it, but release only what the user asked for.
- The commit made by the tool includes `.vscode/settings.json` and anything else modified. That is accepted practice here.

## Steps

### 1. Preflight

Run the check script from the repo root. It exits non-zero if anything blocks the release.

```powershell
& ".claude\skills\release\Check-ReleaseReady.ps1"
```

Pass `-Version 9.1` to also assert the intended version, or `-AllowUntracked` if the user has confirmed untracked files should be committed as part of the release.

It checks:
- Current branch is `dev` and not behind `origin/dev`.
- Working tree has no untracked files. `git add .` would sweep them into the release commit. `.claude/worktrees/` is a common culprit because it contains embedded git checkouts.
- Every `Libs/` submodule is initialized (an uninitialized one ships as an empty folder and the addon fails to load). A submodule on a commit other than the one recorded in HEAD is a warning, since the release commit will bump the pointer. Local uncommitted changes inside a submodule are a warning: they get zipped but committed nowhere.
- Top `Changelog.md` entry has a version and a date, and the date equals the day the script runs. A stale date blocks the release; update it to today before packaging.
- TOC `## Version:` equals the changelog version.
- TOC has `X-CurseForge-ID` and `X-Wago-ID`.
- Tag does not already exist locally or on origin. The tool would force-overwrite it.
- The addon manager and its venv exist.

Fix what it reports. Typical fixes, in order of likelihood:
- Bump `## Version:` in `Krowi_Brokers_Currency.toc` to the new version.
- Add ` - <today>` to the top changelog header.
- Remove, ignore, or deliberately stage stray untracked files.
- Run `git submodule update --init --recursive` if a submodule is missing.

Read the top changelog entry and sanity-check it against `git log <last tag>..HEAD --oneline` and `git diff <last tag> --submodule=log -- Libs`. If a fix or a library bump is missing from the changelog, add it before releasing. Follow the existing style: past-tense bullets under `### Added`, `### Changed`, `### Fixed`, with an optional `(dev note: ...)` for technical detail. Library updates are listed as "Updated Krowi_<Lib> library".

Also glance at `## Interface:` in the TOC. If a new game build went live on any flavor since the last release, the interface numbers need updating first, because the badges and the upload game-version list come from them.

### 2. Optional dry run

Generates release notes, README, and zip without git or uploads. Useful when the changelog format changed, after a long gap between releases, or after a submodule change to confirm the `Libs/` folders land in the zip.

```powershell
& "E:\World of Warcraft Addon Development\Krowi_AddonManager\.venv\Scripts\python.exe" "E:\World of Warcraft Addon Development\Krowi_AddonManager\Krowi_AddonManager_Python\tests\test_operations.py" Krowi_Brokers_Currency
```

Review the generated `_Packaging/ReleaseNotes.md`. It becomes the CurseForge, Wago and GitHub release text.

### 3. Confirm, then run the full package

Show the user the version, the top changelog entry, the list of files that will be committed (`git status --short`), and any submodule pointer changes (`git submodule status`). Ask for a go-ahead unless they already said to release without asking. Then run:

```powershell
Set-Location "E:\World of Warcraft Addon Development\Krowi_AddonManager\Krowi_AddonManager_Python"
& "E:\World of Warcraft Addon Development\Krowi_AddonManager\.venv\Scripts\python.exe" main.py --addon Krowi_Brokers_Currency --operation package --stability stable
```

`--stability` defaults to **alpha**. Always pass `stable` for a normal release. Use `beta` only if the user asks for a beta build.

### 4. Verify

Read the tool output. Each upload prints a `✓` or `✗` line. A `✗` on one host does not stop the others, so check all three. Then confirm:

```powershell
git -C "E:\World of Warcraft Addon Development\Krowi_Brokers_Currency" ls-remote --tags origin <version>
gh release view <version> --repo TheKrowi/Krowi_Brokers_Currency
```

Report the version, the commit hash, and which hosts succeeded. If a host failed, the single-host operations (`--operation wago`, `curseforge`, `github`) re-upload without redoing git or the tag.

## Gotchas

- Do not run the package step twice for the same version. The tool deletes and force-pushes the tag, and the hosts reject or duplicate the file.
- The tool commits on whatever branch is checked out. Being on a feature branch means the release commit and tag land there.
- If the changelog has an entry for the new version but the TOC still has the old version, release notes are generated for the old version and the tag is created for the old version. Preflight catches this.
- Submodule pointers are part of the release commit. If a library was updated on disk but the user did not intend to ship it, check out the recorded commit (`git submodule update Libs/<Lib>`) before packaging.
- The zip skips every `.toc` under `Libs/` and all `.md` files, so a library that needs its own TOC or a bundled markdown file will not work through this tool.
- The Python project reads hosting tokens from its own `resources.py`. Never copy those into this repo or into chat output.
