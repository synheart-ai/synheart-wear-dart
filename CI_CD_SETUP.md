# CI/CD Setup Guide

This document explains the CI/CD setup for the Synheart Wear SDK.

## Files Created

### 1. `dartdoc_options.yaml`

Configuration file for generating API documentation using `dart doc`.

**Usage:**

```bash
dart doc
```

Documentation will be generated in `doc/api/`

### 2. `.github/workflows/ci.yml`

Main CI workflow that runs on:

- Push to `main`, `dev`, or `feature/**` branches
- Pull requests to `main` or `dev`
- Release creation

**Jobs:**

- **test**: Runs tests, code analysis, and formatting checks
- **build**: Builds example app for Android and iOS
- **publish**: Publishes to pub.dev (only on release)
- **docs**: Generates and deploys API documentation to GitHub Pages

### 3. `.github/workflows/publish.yml`

Dedicated workflow for publishing to pub.dev, triggered by:

- Release creation
- Manual workflow dispatch

## Setup Instructions

### 1. GitHub Secrets

To enable publishing to pub.dev, add the following secret to your GitHub repository:

1. Go to your repository → Settings → Secrets and variables → Actions
2. Add a new secret named `PUB_CREDENTIALS`
3. Get your pub.dev credentials:
   ```bash
   flutter pub publish --dry-run
   ```
   This will show you where to find/create your credentials file.
4. Copy the contents of `~/.pub-cache/credentials.json` and paste it as the secret value

### 2. Enable GitHub Pages

To enable automatic documentation deployment:

1. Go to repository → Settings → Pages
2. Source: Select "GitHub Actions"
3. The documentation will be automatically deployed on each push to `main`

### 3. Testing Locally

You can test the workflows locally using [act](https://github.com/nektos/act):

```bash
# Install act
brew install act  # macOS
# or download from https://github.com/nektos/act/releases

# Run the CI workflow
act push
```

### 4. Generate Documentation Locally

```bash
# Install dartdoc
dart pub global activate dartdoc

# Generate docs
dart doc

# View docs
open doc/api/index.html
```

## Workflow Triggers

### CI Workflow (`ci.yml`)

- **Triggers**: Push to branches, PRs, releases
- **Runs**: Tests, builds, generates docs
- **Publishes**: Only on release creation

### Publish Workflow (`publish.yml`)

- **Triggers**: Release creation, manual dispatch
- **Runs**: Version verification, pub.dev publishing
- **Requires**: `PUB_CREDENTIALS` secret

## Version Management

When creating a release:

1. Update version in `pubspec.yaml`
2. Update version in `README.md` badge
3. Update version in `ios/synheart_wear.podspec`
4. Create a git tag matching the version: `git tag v0.2.0`
5. Push the tag: `git push origin v0.2.0`
6. Create a GitHub release with the same tag
7. The publish workflow will automatically publish to pub.dev

## Troubleshooting

### CI fails on "PUB_CREDENTIALS not found"

- Make sure you've added the `PUB_CREDENTIALS` secret in GitHub repository settings
- The secret should contain the contents of your `~/.pub-cache/credentials.json` file

### Documentation not deploying

- Check GitHub Pages settings are enabled
- Verify the `docs` job in CI workflow completed successfully
- Check Actions tab for any errors

### Version mismatch error

- Ensure the version in `pubspec.yaml` matches the release tag
- Example: If tag is `v0.2.0`, `pubspec.yaml` should have `version: 0.2.0`
