#!/bin/bash

set -e  # Exit on error

REPO_NAME="merge-test"

gh repo delete $REPO_NAME --yes
rm -fr $REPO_NAME

echo "Creating GitHub repository..."
gh repo create "$REPO_NAME" \
  --public \
  --disable-wiki \
  --gitignore "" \
  --license "" \
  --clone

cd "$REPO_NAME"

# Configure repository settings
echo "Configuring repository settings..."
gh repo edit \
  --enable-merge-commit \
  --enable-squash-merge \
  --enable-rebase-merge \
  --delete-branch-on-merge

# Disable projects
gh api --silent "repos/{owner}/$REPO_NAME" -X PATCH -f has_projects=false >/dev/null

# Create initial README
echo "Creating initial README..."
echo "Hello World!" > README.md
git add README.md
git commit -m "Initial commit"
git push -u origin main

# Array of merge methods
methods=("merge" "squash" "rebase" "squash-merge")

# Process each method
for method in "${methods[@]}"; do
  branch="$method-example"
  echo "========================================="
  echo "Creating branch with commits: $branch"
  
  fn="$branch.md"

  # Create and checkout branch
  git checkout -b "$branch" main
  
  # First commit: Add section with "This is commit 1"
  echo "" >> "$fn"
  echo "## $branch" >> "$fn"
  echo "This is commit 1" >> "$fn"
  git add "$fn"
  git commit -m "$branch commit 1"
  
  # Second commit: Add "This is commit 2"
  echo "This is commit 2" >> "$fn"
  git add "$fn"
  git commit -m "$branch commit 2"
  
  # Push branch
  git push -u origin "$branch"
done

git checkout main
echo "========================================="
echo "All branches created:"
git branch -vv

# Create PRs for each method branch
for method in "${methods[@]}"; do
  branch="$method-example"
  echo "========================================="
  echo "Creating PR for branch: $branch"

  # Create PR
  gh pr create \
    --title "Example: $branch" \
    --body "This PR demonstrates the $branch workflow" \
    --base main \
    --head "$branch"
  
  # Merge using the appropriate method
  echo "Merging PR with --$method method..."
  if [ "$method" == "squash-merge" ]; then
    git checkout "$branch"
    git reset --soft main
    git commit -m "Squashed commits on $branch"
    git push --force
    git checkout main
    method="merge"
  fi
  gh pr merge "$branch" "--$method"
done

# Update local main branch
git checkout main
git pull origin main

echo "=========================================="
echo "Setup complete"
echo "Repository: https://github.com/$(gh repo view --json owner -q .owner.login)/$REPO_NAME"
echo "All three PRs have been created and merged using their respective methods"

