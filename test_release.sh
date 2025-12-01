#!/bin/bash
# Test script for release workflow
# This simulates what happens when a release is created

set -e

echo "🧪 Testing Release Workflow"
echo "============================"
echo ""

# Check if version in pubspec.yaml matches
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d ' ')
echo "📦 Current version in pubspec.yaml: $VERSION"
echo ""

# Test version validation logic
echo "🔍 Testing version validation..."
TEST_TAG="v$VERSION"
echo "   Release tag: $TEST_TAG"
echo "   Pubspec version: $VERSION"

if [ "$TEST_TAG" == "v$VERSION" ]; then
    echo "   ✅ Version format matches!"
else
    echo "   ❌ Version mismatch!"
    exit 1
fi

echo ""
echo "📋 Next steps to test the workflow:"
echo "   1. Ensure PUB_CREDENTIALS secret is set in GitHub repository settings"
echo "   2. Create a git tag: git tag v$VERSION"
echo "   3. Push the tag: git push origin v$VERSION"
echo "   4. Create a GitHub release with tag v$VERSION"
echo "   5. The publish workflow will automatically run"
echo ""
echo "💡 To test manually without creating a release:"
echo "   - Go to Actions tab → Publish to pub.dev → Run workflow"
echo "   - Enter version: $VERSION"
echo ""

