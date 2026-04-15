-include .make/system.mk

# -----------------------------------------------------------------------------
# git
# -----------------------------------------------------------------------------
# 役割:
# - 差分、ログ、patch の保存
# - Conventional Commits ベースの簡易 semver 計算
# - upstream remote の確認・設定
# - upstream からブランチ / タグを最新化
# -----------------------------------------------------------------------------

# 一時ファイルの出力先
TEMP_DIR := temp
GIT_DIFF_FILE := $(TEMP_DIR)/git_diff.diff
GIT_LOG_FILE := $(TEMP_DIR)/git_log.log
GIT_PATCH_FILE := $(TEMP_DIR)/git_patch.patch

# upstream の URL。
# - 指定時は対話入力より優先する
# - 未指定かつ upstream 未設定時は対話入力を受け付ける
# - 例) make git-upstream-setup GIT_UPSTREAM_URL=https://github.com/ORIGINAL_OWNER/ORIGINAL_REPO.git
GIT_UPSTREAM_URL ?=

MKDIR_TEMP := mkdir -p "$(TEMP_DIR)"

# temp ディレクトリを作成する。
.PHONY: temp-dir
temp-dir:
	@$(MKDIR_TEMP)

# 空白差分を無視して stage に追加する。
# - 引数未指定: 変更中の全ファイルを対象
# - TARGET 指定: 指定ファイルのみ対象
# 例) make git-add
# 例) make git-add TARGET=path/to/file
.PHONY: git-add
git-add:
	@target='$(TARGET)'; \
	if [ -n "$$target" ]; then \
	  git diff -w -- "$$target" | git apply --cached -; \
	else \
	  git diff -w | git apply --cached -; \
	fi

# ドット記法で対象ファイルを渡す省略形。
# 例) make git-add.path/to/file
.PHONY: git-add.%
git-add.%:
	@$(MAKE) git-add TARGET='$*'

# git diff --staged の差分を temp に保存する。
# 例) make git-staged-diff
.PHONY: git-staged-diff gsd
git-staged-diff gsd: | temp-dir
	git diff --staged -w > "$(GIT_DIFF_FILE)"

# 2 ブランチ間の差分を temp に保存する。
# 例) make gbd BASE=main TARGET=feature/my-branch
.PHONY: git-branch-diff gbd
git-branch-diff gbd: | temp-dir
	@if [ -z "$(BASE)" ] || [ -z "$(TARGET)" ]; then \
	  echo "Usage: make gbd BASE=<base-branch> TARGET=<target-branch>"; \
	  echo "Example: make gbd BASE=main TARGET=feature/my-branch"; \
	  exit 1; \
	fi
	git diff -w "$(BASE)"..."$(TARGET)" > "$(GIT_DIFF_FILE)"
	echo "created: $(GIT_DIFF_FILE)"

# 直近 N 件の git log を temp に保存する。
# 例) make git-log.10
.PHONY: git-log.% gl.%
git-log.% gl.%: | temp-dir
	git log -n $* > "$(GIT_LOG_FILE)"

# 当日 0:00 以降の git log -p を temp に保存する。
# 例) make git-log-midnight
.PHONY: git-log-midnight glm
git-log-midnight glm: | temp-dir
	git log --since=midnight -p -w > "$(GIT_LOG_FILE)"

# 特定の日の git log -p を temp に保存する。
# 例) make gls.2025-12-06
.PHONY: git-log-since.% gls.%
git-log-since.% gls.%: | temp-dir
	git log --since="$* 00:00" --until="$* 23:59:59" -p -w > "$(GIT_LOG_FILE)"

# patch を作る。
# - BASE/TARGET 未指定: 作業ツリー差分を保存
# - BASE/TARGET 指定: 2 ブランチ間差分を保存
# 例) make git-patch
# 例) make git-patch BASE=main TARGET=feature/my-branch
.PHONY: git-patch
git-patch: | temp-dir
	@if [ -n "$(BASE)" ] || [ -n "$(TARGET)" ]; then \
	  if [ -z "$(BASE)" ] || [ -z "$(TARGET)" ]; then \
	    echo "Usage: make git-patch BASE=<base-branch> TARGET=<target-branch>"; \
	    echo "Example: make git-patch BASE=main TARGET=feature/my-branch"; \
	    exit 1; \
	  fi; \
	  git diff -w "$(BASE)"..."$(TARGET)" > "$(GIT_PATCH_FILE)"; \
	else \
	  git diff -w > "$(GIT_PATCH_FILE)"; \
	fi
	@echo "created: $(GIT_PATCH_FILE)"

# temp/git_patch.patch を適用する。
# 例) make git-apply
.PHONY: git-apply
git-apply: | temp-dir
	git apply --ignore-whitespace "$(GIT_PATCH_FILE)"

# Conventional Commits 作業用の補助。
# - staged diff
# - 直近 10 件の log
# をまとめて生成する。
# 例) make cc
.PHONY: conventional-commits cc
conventional-commits cc:
	$(MAKE) git-staged-diff
	$(MAKE) git-log.10

# upstream remote を確認し、必要なら追加する。
# - まず git remote -v を表示する
# - upstream が無ければ GIT_UPSTREAM_URL を優先して使う
# - GIT_UPSTREAM_URL も未指定なら対話入力を受け付ける
# 例) make git-upstream-setup
# 例) make git-upstream-setup GIT_UPSTREAM_URL=https://github.com/ORIGINAL_OWNER/ORIGINAL_REPO.git
.PHONY: git-upstream-setup gus
git-upstream-setup gus:
	$(call require_cmd,git)
	@git remote -v; \
	if git remote get-url upstream >$(NULLDEV) 2>&1; then \
	  :; \
	else \
	  upstream_url='$(GIT_UPSTREAM_URL)'; \
	  if [ -z "$$upstream_url" ]; then \
	    printf '%s' 'upstream URL を入力してください: '; \
	    IFS= read -r upstream_url; \
	  fi; \
	  if [ -z "$$upstream_url" ]; then \
	    echo 'upstream URL が未入力です'; \
	    exit 2; \
	  fi; \
	  git remote add upstream "$$upstream_url"; \
	  git remote -v; \
	fi

# upstream から全ブランチとタグを取得し、消えたブランチも反映する。
# - main 以外のブランチも対象
# - upstream remote がある前提
# 例) make git-upstream-fetch
.PHONY: git-upstream-fetch guf
git-upstream-fetch guf: git-upstream-setup
	$(call require_cmd,git)
	@git fetch upstream --prune --tags

# upstream から全ブランチとタグを取得し、消えたタグも反映する。
# - --prune-tags は --prune と組み合わせて使う
# - ローカルタグ削除も反映したい場合のみ使う
# 例) make git-upstream-fetch-prune-tags
.PHONY: git-upstream-fetch-prune-tags gufpt
git-upstream-fetch-prune-tags gufpt: git-upstream-setup
	$(call require_cmd,git)
	@git fetch upstream --prune --prune-tags --tags

# Git のタグと Conventional Commits から現在のバージョンを計算して出力する。
# - 破壊的変更: major
# - feat: minor
# - fix: patch
# 例) make semver
.PHONY: semver
semver:
	@last_tag=$$(git describe --tags --abbrev=0 2>$(NULLDEV) || echo "0.0.0"); \
	if git describe --tags --abbrev=0 >$(NULLDEV) 2>&1; then \
	  log_range="$$last_tag..HEAD"; \
	else \
	  log_range=""; \
	fi; \
	base_tag="$$last_tag"; \
	if echo "$$base_tag" | grep -q '^v'; then \
	  base_tag=$${base_tag#v}; \
	fi; \
	major=$$(echo "$$base_tag" | cut -d. -f1); \
	minor=$$(echo "$$base_tag" | cut -d. -f2); \
	patch=$$(echo "$$base_tag" | cut -d. -f3); \
	[ -z "$$major" ] && major=0; \
	[ -z "$$minor" ] && minor=0; \
	[ -z "$$patch" ] && patch=0; \
	breaking=0; feat=0; fix=0; \
	if [ -n "$$log_range" ]; then \
	  commits=$$(git log "$$log_range" --format='%s'); \
	else \
	  commits=$$(git log --format='%s'); \
	fi; \
	if [ -n "$$commits" ]; then \
	  IFS=$$'\n'; \
	  set -f; \
	  for subject in $$commits; do \
	    [ -z "$$subject" ] && continue; \
	    if echo "$$subject" | grep -Eq '^[a-zA-Z]+(\([^)]+\))?!:'; then \
	      breaking=1; \
	    fi; \
	    if echo "$$subject" | grep -Eq '^feat(\(|:)'; then \
	      feat=1; \
	    fi; \
	    if echo "$$subject" | grep -Eq '^fix(\(|:)'; then \
	      fix=1; \
	    fi; \
	  done; \
	  set +f; \
	fi; \
	if [ "$$breaking" -eq 1 ]; then \
	  major=$$((major+1)); minor=0; patch=0; \
	elif [ "$$feat" -eq 1 ]; then \
	  minor=$$((minor+1)); patch=0; \
	elif [ "$$fix" -eq 1 ]; then \
	  patch=$$((patch+1)); \
	fi; \
	echo "$$major.$$minor.$$patch"
