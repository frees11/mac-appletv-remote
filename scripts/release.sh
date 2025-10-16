#!/bin/bash

# Release script for ATV Remote
# Creates a new version tag and triggers deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🚀 ATV Remote - Release Manager${NC}"
echo ""

# Get current version from package.json
CURRENT_VERSION=$(node -p "require('./package.json').version")
echo -e "Current version: ${GREEN}v$CURRENT_VERSION${NC}"
echo ""

# Ask for new version
echo "Enter new version (or leave empty to cancel):"
echo -e "${YELLOW}Examples: 1.0.1, 1.1.0, 2.0.0${NC}"
read -p "New version: " NEW_VERSION

if [ -z "$NEW_VERSION" ]; then
    echo -e "${RED}❌ Cancelled${NC}"
    exit 1
fi

# Remove 'v' prefix if present
NEW_VERSION=${NEW_VERSION#v}

# Validate version format (basic check)
if ! [[ "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo -e "${RED}❌ Invalid version format. Use semantic versioning (e.g., 1.0.0)${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}📝 Release Plan:${NC}"
echo "  1. Update version in package.json to $NEW_VERSION"
echo "  2. Commit changes"
echo "  3. Create git tag v$NEW_VERSION"
echo "  4. Push to repository"
echo ""

read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${RED}❌ Cancelled${NC}"
    exit 1
fi

# Update package.json version
echo -e "${GREEN}📦 Updating package.json...${NC}"
npm version $NEW_VERSION --no-git-tag-version

# Create release notes file
RELEASE_NOTES="RELEASE_NOTES_v$NEW_VERSION.md"
cat > $RELEASE_NOTES << EOF
# Release v$NEW_VERSION

## Changes
-

## Bug Fixes
-

## Known Issues
-

---
*Generated on $(date "+%Y-%m-%d %H:%M:%S")*
EOF

echo -e "${YELLOW}✏️  Please edit release notes: $RELEASE_NOTES${NC}"
echo "Press Enter when done..."
read

# Commit changes
echo -e "${GREEN}💾 Committing changes...${NC}"
git add package.json package-lock.json
git commit -m "chore: bump version to $NEW_VERSION"

# Create tag
echo -e "${GREEN}🏷️  Creating tag v$NEW_VERSION...${NC}"
TAG_MESSAGE=$(cat $RELEASE_NOTES)
git tag -a "v$NEW_VERSION" -m "$TAG_MESSAGE"

# Push
echo ""
echo -e "${YELLOW}Ready to push to repository?${NC}"
echo "This will:"
echo "  - Push commits to main branch"
echo "  - Push tag v$NEW_VERSION"
if [ -f ".github/workflows/deploy.yml" ]; then
    echo "  - Trigger CI/CD deployment"
fi
echo ""
read -p "Push now? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}🚀 Pushing to repository...${NC}"
    git push origin main
    git push origin "v$NEW_VERSION"

    echo ""
    echo -e "${GREEN}✅ Release v$NEW_VERSION created successfully!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Monitor CI/CD pipeline (if configured)"
    echo "  2. Download build artifacts from GitHub Releases"
    echo "  3. Test the release build"
    echo "  4. Share with testers"

    # Clean up release notes file
    rm -f $RELEASE_NOTES
else
    echo -e "${YELLOW}⚠️  Changes committed locally but not pushed${NC}"
    echo "To push manually later:"
    echo "  git push origin main"
    echo "  git push origin v$NEW_VERSION"
fi
