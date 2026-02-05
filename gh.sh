#!/usr/bin/env bash
set -euo pipefail

# Deploy the static site to GitHub Pages.
#
# Target:
# - GitHub user: FilekBananas
# - Repo:        staszek
# - Pages:       gh-pages branch (root)

GITHUB_USER="${GITHUB_USER:-FilekBananas}"
REPO_NAME="${REPO_NAME:-staszek}"
REMOTE_NAME="${REMOTE_NAME:-origin}"
REMOTE_URL="${REMOTE_URL:-https://github.com/${GITHUB_USER}/${REPO_NAME}.git}"
BRANCH_MAIN="${BRANCH_MAIN:-main}"
PAGES_BRANCH="${PAGES_BRANCH:-gh-pages}"
COMMIT_MSG="${COMMIT_MSG:-deploy}"
SOURCE_DIR="${SOURCE_DIR:-.}"
FORCE_MAIN_PUSH="${FORCE_MAIN_PUSH:-0}"

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git not found."
  exit 1
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: missing source directory: '$SOURCE_DIR/'."
  exit 1
fi

if [[ ! -d .git ]]; then
  git init
  git checkout -b "$BRANCH_MAIN"
fi

current_remote_url="$(git remote get-url "$REMOTE_NAME" 2>/dev/null || true)"
if [[ -z "$current_remote_url" ]]; then
  git remote add "$REMOTE_NAME" "$REMOTE_URL"
elif [[ "$current_remote_url" != "$REMOTE_URL" ]]; then
  echo "Updating remote '$REMOTE_NAME':"
  echo "  from: $current_remote_url"
  echo "  to:   $REMOTE_URL"
  git remote set-url "$REMOTE_NAME" "$REMOTE_URL"
fi

# Commit current changes to main branch (optional but useful).
git add -A
if ! git diff --cached --quiet; then
  git commit -m "$COMMIT_MSG"
fi

git branch -M "$BRANCH_MAIN"
push_main() {
  if [[ "$FORCE_MAIN_PUSH" == "1" ]]; then
    git push -u -f "$REMOTE_NAME" "$BRANCH_MAIN"
  else
    git push -u "$REMOTE_NAME" "$BRANCH_MAIN"
  fi
}

if ! push_main; then
  echo "Main push rejected. Trying to rebase onto remote '$REMOTE_NAME/$BRANCH_MAIN'…"
  git fetch "$REMOTE_NAME" "$BRANCH_MAIN" || true
  if git pull --rebase "$REMOTE_NAME" "$BRANCH_MAIN"; then
    push_main
  else
    cat <<EOF

Rebase failed (probably conflicts).

Options:
1) Resolve conflicts, then run: git rebase --continue
2) Abort rebase:            git rebase --abort
3) If you want to overwrite the remote main branch:
     FORCE_MAIN_PUSH=1 bash gh.sh

EOF
    exit 1
  fi
fi

if ! git rev-parse --verify "$BRANCH_MAIN" >/dev/null 2>&1; then
  cat <<EOF

Push failed.

Common fixes:
1) Make sure the repo exists: https://github.com/${GITHUB_USER}/${REPO_NAME}
2) If using HTTPS, authenticate with a GitHub token (not your password).
3) If you prefer SSH, run:
     REMOTE_URL=git@github.com:${GITHUB_USER}/${REPO_NAME}.git bash gh.sh
   and add your SSH key to GitHub: Settings → SSH and GPG keys.

EOF
  exit 1
fi

# Deploy the site to the Pages branch.
#
# NOTE: this FORCE UPDATES the gh-pages branch.
#
# Implementation uses a temporary git worktree so we don't trash your working tree.
tmp_dir="$(mktemp -d 2>/dev/null || mktemp -d -t staszek-pages)"
cleanup() {
  set +e
  git worktree remove --force "$tmp_dir" >/dev/null 2>&1 || true
  rm -rf "$tmp_dir" >/dev/null 2>&1 || true
}
trap cleanup EXIT

git worktree add -B "$PAGES_BRANCH" "$tmp_dir" "$BRANCH_MAIN" >/dev/null

# Clear worktree contents (keep .git file/dir used by worktree).
find "$tmp_dir" -mindepth 1 -maxdepth 1 ! -name ".git" -exec rm -rf {} + >/dev/null 2>&1 || true

# Copy site files from SOURCE_DIR into the worktree root.
# Exclude git internals and the deploy script itself.
rsync -a \
  --exclude ".git" \
  --exclude ".DS_Store" \
  --exclude "gh.sh" \
  --exclude ".pages-worktree" \
  --exclude ".pages-worktree/" \
  --exclude ".gitignore" \
  "$SOURCE_DIR"/ "$tmp_dir"/

git -C "$tmp_dir" add -A
if ! git -C "$tmp_dir" diff --cached --quiet; then
  git -C "$tmp_dir" commit -m "$COMMIT_MSG" >/dev/null
fi
git -C "$tmp_dir" push -f "$REMOTE_NAME" "$PAGES_BRANCH:$PAGES_BRANCH"

echo "Done."
echo "If needed, enable GitHub Pages: Settings → Pages → Deploy from branch → $PAGES_BRANCH / (root)."
