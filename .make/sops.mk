ifndef __MAKE_SOPS_MK__
__MAKE_SOPS_MK__ := 1

-include .make/age.mk
-include .make/system.mk

# -----------------------------------------------------------------------------
# sops
# -----------------------------------------------------------------------------
# 役割:
# - sops の存在確認、インストール、アンインストールを行う
# - インストール可能なバージョン候補を出力する
# - 暗号化 / 復号の実処理は .sh へ委譲し、Makefile からは引数の受け渡しと依存関係の管理に専念する
# - .sops.yaml の creation_rules.path_regex に一致するファイルをまとめて暗号化 / 復号する
# - @ short hand で単一ファイルを指定できる
#
# 対応環境:
# - Windows        : winget
# - WSL / Ubuntu   : GitHub Releases のバイナリ配置
# - macOS          : Homebrew
# -----------------------------------------------------------------------------
# 公式を確認: https://github.com/getsops/sops/tags
SOPS_GITHUB_REPO ?= getsops/sops
SOPS_VERSION ?=
SOPS_BREW_FORMULA := sops
SOPS_WINGET_ID := SecretsOPerationS.SOPS
SOPS_INSTALL_DIR ?= /usr/local/bin
SOPS_CONFIG_FILE ?= .sops.yaml
SOPS_TARGET ?=
SOPS_CRYPT_SCRIPT ?= sops/crypt.sh

# sops のインストール済みバージョンを正規化して返す。
define sops_detect_installed_version
if command -v sops >$(NULLDEV) 2>&1; then \
 sops --version 2>$(NULLDEV) | head -n 1 | sed -E 's/.*[Vv]ersion[[:space:]]+//' | sed -E 's/^v//' | awk '{ print $$1 }'; \
fi
endef

# Linux / WSL 用のアーキテクチャ名を GitHub Releases の asset 名へ変換する。
define sops_linux_arch
$(strip $(if $(filter x86_64 amd64,$(ARCH)),amd64,$(if $(filter aarch64 arm64,$(ARCH)),arm64,$(ARCH))))
endef

# Linux / WSL 用のダウンロード URL を組み立てる。
define sops_release_url
https://github.com/$(SOPS_GITHUB_REPO)/releases/download/v$(1)/sops-v$(1).linux.$(call sops_linux_arch)
endef

# GitHub Releases の latest から最新 stable version を取得する。
define sops_latest_version
curl -fsSLI -o $(NULLDEV) -w '%{url_effective}' https://github.com/$(SOPS_GITHUB_REPO)/releases/latest | sed 's#.*/v##'
endef

# sops のインストール可能なバージョン候補を出力する。
# - macOS は Homebrew formula の stable version を出力する
# - Linux / WSL は GitHub Releases の tag 一覧を新しい順で出力する
# - Windows は winget show --versions を使う
# 例) make sops-installable-versions
.PHONY: sops-installable-versions
sops-installable-versions:
	@if [ "$(HOST_OS)" = "Darwin" ]; then \
	 command -v brew >$(NULLDEV) 2>&1 || { echo 'Homebrew が見つかりません'; exit 1; }; \
	 stable_version="$$(brew info --json=v2 "$(SOPS_BREW_FORMULA)" 2>$(NULLDEV) | sed -n 's/.*"stable":"\([^"]*\)".*/\1/p' | head -n 1)"; \
	 [ -n "$$stable_version" ] || { echo 'Homebrew で sops の stable version を取得できません'; exit 1; }; \
	 echo "$$stable_version"; \
	elif [ -f /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease 2>$(NULLDEV); then \
	 command -v curl >$(NULLDEV) 2>&1 || { echo 'curl が見つかりません'; exit 1; }; \
	 curl -fsSL "https://api.github.com/repos/$(SOPS_GITHUB_REPO)/releases?per_page=100" \
	 | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p'; \
	elif [ "$(HOST_OS)" = "Linux" ] || [ "$(HOST_OS)" = "GNU/Linux" ]; then \
	 command -v curl >$(NULLDEV) 2>&1 || { echo 'curl が見つかりません'; exit 1; }; \
	 curl -fsSL "https://api.github.com/repos/$(SOPS_GITHUB_REPO)/releases?per_page=100" \
	 | sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p'; \
	elif [ "$(HOST_OS)" = "Windows" ] || [ -n "$(IS_WINDOWS)" ]; then \
	 command -v powershell.exe >$(NULLDEV) 2>&1 || { echo 'powershell.exe が見つかりません'; exit 1; }; \
	 powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "winget show --id $(SOPS_WINGET_ID) -e --versions --source winget"; \
	else \
	 echo "未対応の OS です: $(HOST_OS)"; \
	 exit 1; \
	fi

# sops のインストール済みバージョンを出力する。
# - sops が未導入なら失敗する
# 例) make sops-version
.PHONY: sops-version
sops-version:
	@version="$$( $(call sops_detect_installed_version) )"; \
	[ -n "$$version" ] || { echo 'sops が見つかりません'; exit 1; }; \
	echo "$$version"

# sops をアンインストールする。
# - 未導入なら何もしない
# - macOS は brew uninstall を使う
# - Linux / WSL は配置済みバイナリを削除する
# - Windows は winget を使う
# 例) make sops-uninstall
.PHONY: sops-uninstall
sops-uninstall:
	@if [ "$(HOST_OS)" = "Darwin" ]; then \
	 command -v brew >$(NULLDEV) 2>&1 || { echo 'Homebrew が見つかりません'; exit 1; }; \
	 if brew list --formula 2>$(NULLDEV) | grep '^$(SOPS_BREW_FORMULA)$$' >$(NULLDEV) 2>&1; then \
	  brew uninstall --formula "$(SOPS_BREW_FORMULA)"; \
	 fi; \
	elif [ -f /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease 2>$(NULLDEV); then \
	 if [ -x "$(SOPS_INSTALL_DIR)/sops" ]; then \
	  sudo rm -f "$(SOPS_INSTALL_DIR)/sops"; \
	 fi; \
	elif [ "$(HOST_OS)" = "Linux" ] || [ "$(HOST_OS)" = "GNU/Linux" ]; then \
	 if [ -x "$(SOPS_INSTALL_DIR)/sops" ]; then \
	  sudo rm -f "$(SOPS_INSTALL_DIR)/sops"; \
	 fi; \
	elif [ "$(HOST_OS)" = "Windows" ] || [ -n "$(IS_WINDOWS)" ]; then \
	 command -v powershell.exe >$(NULLDEV) 2>&1 || { echo 'powershell.exe が見つかりません'; exit 1; }; \
	 powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$$ErrorActionPreference = 'Stop'; if (winget list --id $(SOPS_WINGET_ID) -e --source winget 2>$$null | Select-String '$(SOPS_WINGET_ID)') { winget uninstall --id $(SOPS_WINGET_ID) -e --source winget --accept-source-agreements }"; \
	else \
	 echo "未対応の OS です: $(HOST_OS)"; \
	 exit 1; \
	fi

# sops をインストールする。
# - SOPS_VERSION 未指定時は最新版を導入する
# - SOPS_VERSION 指定時、異なるバージョンが入っていれば先にアンインストールする
# - macOS は Homebrew を使う
# - Linux / WSL は GitHub Releases のバイナリを配置する
# - Windows は winget を使う
# 例) make sops-install
# 例) make sops-install SOPS_VERSION=3.12.2
.PHONY: sops-install
sops-install:
	@requested_version='$(SOPS_VERSION)'; \
	installed_version="$$( $(call sops_detect_installed_version) )"; \
	if [ -n "$$requested_version" ] && [ -n "$$installed_version" ] && [ "$$installed_version" != "$$requested_version" ]; then \
	 $(MAKE) sops-uninstall; \
	 installed_version=''; \
	fi; \
	if [ -n "$$installed_version" ]; then \
	 :; \
	elif [ "$(HOST_OS)" = "Darwin" ]; then \
	 command -v brew >$(NULLDEV) 2>&1 || { echo 'Homebrew が見つかりません'; exit 1; }; \
	 brew install "$(SOPS_BREW_FORMULA)"; \
	elif [ -f /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease 2>$(NULLDEV); then \
	 command -v curl >$(NULLDEV) 2>&1 || { echo 'curl が見つかりません'; exit 1; }; \
	 version="$$requested_version"; \
	 [ -n "$$version" ] || version="$$( $(call sops_latest_version) )"; \
	 [ -n "$$version" ] || { echo '最新の SOPS_VERSION を取得できません'; exit 1; }; \
	 tmpfile="$$(mktemp)"; \
	 trap 'rm -f "$$tmpfile"' EXIT HUP INT TERM; \
	 curl -fL "$(call sops_release_url,$$version)" -o "$$tmpfile"; \
	 sudo install -m 0755 "$$tmpfile" "$(SOPS_INSTALL_DIR)/sops"; \
	elif [ "$(HOST_OS)" = "Linux" ] || [ "$(HOST_OS)" = "GNU/Linux" ]; then \
	 command -v curl >$(NULLDEV) 2>&1 || { echo 'curl が見つかりません'; exit 1; }; \
	 version="$$requested_version"; \
	 [ -n "$$version" ] || version="$$( $(call sops_latest_version) )"; \
	 [ -n "$$version" ] || { echo '最新の SOPS_VERSION を取得できません'; exit 1; }; \
	 tmpfile="$$(mktemp)"; \
	 trap 'rm -f "$$tmpfile"' EXIT HUP INT TERM; \
	 curl -fL "$(call sops_release_url,$$version)" -o "$$tmpfile"; \
	 sudo install -m 0755 "$$tmpfile" "$(SOPS_INSTALL_DIR)/sops"; \
	elif [ "$(HOST_OS)" = "Windows" ] || [ -n "$(IS_WINDOWS)" ]; then \
	 command -v powershell.exe >$(NULLDEV) 2>&1 || { echo 'powershell.exe が見つかりません'; exit 1; }; \
	 if [ -n "$$requested_version" ]; then \
	  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "winget install --id $(SOPS_WINGET_ID) -e --source winget --version $$requested_version --accept-package-agreements --accept-source-agreements"; \
	 else \
	  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "winget install --id $(SOPS_WINGET_ID) -e --source winget --accept-package-agreements --accept-source-agreements"; \
	 fi; \
	else \
	 echo "未対応の OS です: $(HOST_OS)"; \
	 exit 1; \
	fi

# sops をインストールする。
# - 例) make sops-install@3.12.2
.PHONY: sops-install@%
sops-install@%:
	$(MAKE) sops-install SOPS_VERSION=$*

# 暗号化 / 復号処理を make から分離した .sh へ委譲する。
# - CI/CD や githooks でも同じスクリプトを直接再利用できる
# - Makefile 側は引数と依存関係の受け渡しだけに絞る
.PHONY: sops-crypt-script-check
sops-crypt-script-check:
	@[ -f "$(SOPS_CRYPT_SCRIPT)" ] || { echo "$(SOPS_CRYPT_SCRIPT) が見つかりません"; exit 1; }
	@chmod +x "$(SOPS_CRYPT_SCRIPT)"

# .sops.yaml の path_regex に一致するファイル、または指定ファイルを暗号化する。
# - 指定ファイルは @ short hand を使う
# - すでに暗号化済みのファイルはスキップする
# 例) make sops-encrypt
# 例) make sops-encrypt@secrets/dev.yaml
.PHONY: sops-encrypt
sops-encrypt: sops-install sops-crypt-script-check
	$(call require_cmd,sops)
	@SOPS_CONFIG_FILE='$(SOPS_CONFIG_FILE)' \
	SOPS_TARGET='$(SOPS_TARGET)' \
	AGE_KEY_FILE='$(AGE_KEY_FILE)' \
	sh '$(SOPS_CRYPT_SCRIPT)' encrypt

.PHONY: sops-encrypt@%
sops-encrypt@%:
	$(MAKE) sops-encrypt SOPS_TARGET='$*'

# .sops.yaml の path_regex に一致するファイル、または指定ファイルを復号する。
# - 指定ファイルは @ short hand を使う
# - 未暗号化ファイルはスキップする
# 例) make sops-decrypt
# 例) make sops-decrypt@secrets/dev.yaml
.PHONY: sops-decrypt
sops-decrypt: sops-install sops-crypt-script-check
	$(call require_cmd,sops)
	@SOPS_CONFIG_FILE='$(SOPS_CONFIG_FILE)' \
	SOPS_TARGET='$(SOPS_TARGET)' \
	AGE_KEY_FILE='$(AGE_KEY_FILE)' \
	sh '$(SOPS_CRYPT_SCRIPT)' decrypt

.PHONY: sops-decrypt@%
sops-decrypt@%:
	$(MAKE) sops-decrypt SOPS_TARGET='$*'

endif
