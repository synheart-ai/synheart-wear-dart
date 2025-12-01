# Quick Start: CI/CD Publishing Setup

## ✅ What's Been Set Up

1. **`.github/workflows/publish.yml`** - Automatically publishes to pub.dev when a release is created
2. **`.github/workflows/ci.yml`** - Runs tests, analysis, and builds on every push/PR
3. **`test_release.sh`** - Helper script to test the release process

## 🚀 How to Test It (Before Your Meeting!)

### Option 1: Manual Workflow Test (Recommended for Testing)

1. **Set up the secret first:**

   - Go to your GitHub repo → Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `PUB_CREDENTIALS`
   - Value: Get it from `~/.pub-cache/credentials.json` on your local machine
     ```bash
     cat ~/.pub-cache/credentials.json
     ```
   - If you don't have it, run: `flutter pub publish --dry-run` and follow the prompts

2. **Test the workflow manually:**
   - Go to your GitHub repo → Actions tab
   - Click "Publish to pub.dev" workflow
   - Click "Run workflow" button
   - Enter version: `0.2.0` (or your current version)
   - Click "Run workflow"
   - Watch it run! It will validate and attempt to publish

### Option 2: Create a Test Release

1. **Update version in pubspec.yaml** (if needed):

   ```bash
   # Current version is 0.2.0
   ```

2. **Create and push a test tag:**

   ```bash
   git tag v0.2.0-test
   git push origin v0.2.0-test
   ```

3. **Create a GitHub release:**
   - Go to your repo → Releases → "Create a new release"
   - Tag: `v0.2.0-test`
   - Title: `Test Release 0.2.0`
   - Click "Publish release"
   - The workflow will automatically trigger!

## 📋 What the Workflow Does

1. ✅ Checks out the code
2. ✅ Sets up Dart & Flutter
3. ✅ Verifies version matches between release tag and pubspec.yaml
4. ✅ Runs `flutter pub publish --dry-run` to validate
5. ✅ Publishes to pub.dev (if PUB_CREDENTIALS is set)
6. ✅ Skips gracefully if credentials are missing

## ⚠️ Important Notes

- **Version must match**: The release tag (e.g., `v0.2.0`) must match `pubspec.yaml` version (`0.2.0`)
- **PUB_CREDENTIALS secret is required** for actual publishing
- **The workflow runs automatically** when you create a GitHub release
- **You can also trigger it manually** from the Actions tab

## 🔍 Verify It's Working

After pushing the workflows:

1. Go to your repo → Actions tab
2. You should see the workflows listed
3. Try running "Publish to pub.dev" manually with version `0.2.0`
4. Check the logs to see if it validates correctly

## 📝 For Your Meeting

You can show:

- ✅ Workflows are set up and enabled
- ✅ Automatic publishing on release creation
- ✅ Version validation to prevent mistakes
- ✅ Manual trigger option for testing
- ✅ Graceful handling when credentials are missing

## 🎯 Next Steps After Testing

Once you've verified it works:

1. Commit and push the workflow files
2. Set up the PUB_CREDENTIALS secret
3. Create your next release and watch it auto-publish!

---

**Need help?** Check the full documentation in `CI_CD_SETUP.md`
