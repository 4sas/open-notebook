-include .make/system.mk

# -----------------------------------------------------------------------------
# repomix
# -----------------------------------------------------------------------------
# 役割:
# - repomix を npx 経由で実行する
# - 差分やログを含めたプレビュー出力にも対応する
# -----------------------------------------------------------------------------
REPOMIX := npx repomix@latest
REPOMIX_PREVIEW_OPTS := --include-diffs --include-logs --include-logs-count 10

# repomix を実行する。
# 例) make repo-mix
.PHONY: repo-mix rpmx
repo-mix rpmx:
	$(call require_cmd,npx)
	$(REPOMIX)

# 差分・ログを含めた repomix プレビューを実行する。
# 例) make repo-mix-preview
.PHONY: repo-mix-preview rpmx-p
repo-mix-preview rpmx-p:
	$(call require_cmd,npx)
	$(REPOMIX) $(REPOMIX_PREVIEW_OPTS)
