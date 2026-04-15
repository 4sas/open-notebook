ifndef __MAKE_AGE_MK__
__MAKE_AGE_MK__ := 1

-include .make/system.mk

# -----------------------------------------------------------------------------
# age
# -----------------------------------------------------------------------------
# 役割:
# - age の存在確認、インストール、アンインストールを行う
# - AGE_VERSION 指定時は可能な範囲でそのバージョンを導入する
# - インストール可能なバージョン候補を出力する
# - .agekey が無い場合のみ age-keygen で鍵を作成する
# - 既存 .agekey がある場合は public key を再利用する
#
# 対応環境:
# - Windows        : winget
# - WSL / Ubuntu   : apt-get
# - macOS          : Homebrew
# -----------------------------------------------------------------------------
AGE_KEY_FILE ?= .agekey
AGE_PUBLIC_KEY_PREFIX := # public key:
# 公式を確認: https://github.com/FiloSottile/age/tags
AGE_VERSION ?=
AGE_WINGET_ID := FiloSottile.age
AGE_BREW_FORMULA := age

# age のインストール済みバージョンを正規化して返す。
define age_detect_installed_version
if command -v age >$(NULLDEV) 2>&1; then \
 age --version 2>$(NULLDEV) | head -n 1 | sed 's/^v//' | sed 's/ .*//'; \
fi
endef

# Homebrew の versioned formula 名を解決する。
# - まず age@<major.minor.patch> を試す
# - 次に age@<major.minor> を試す
# - 見つからなければ通常 formula を返す
# 注意:
# - Homebrew に versioned formula が無い場合は age を通常インストールする
# - その場合、指定バージョンと一致しない可能性がある
.PHONY: age-brew-formula
age-brew-formula:
	@requested_version='$(AGE_VERSION)'; \
	if [ -z "$$requested_version" ]; then \
	 echo '$(AGE_BREW_FORMULA)'; \
	elif brew info --formula "$(AGE_BREW_FORMULA)@$$requested_version" >$(NULLDEV) 2>&1; then \
	 echo "$(AGE_BREW_FORMULA)@$$requested_version"; \
	else \
	 short_version="$$(printf '%s' "$$requested_version" | awk -F. '{ if (NF >= 2) print $$1 "." $$2; }')"; \
	 if [ -n "$$short_version" ] && brew info --formula "$(AGE_BREW_FORMULA)@$$short_version" >$(NULLDEV) 2>&1; then \
	  echo "$(AGE_BREW_FORMULA)@$$short_version"; \
	 else \
	  echo '$(AGE_BREW_FORMULA)'; \
	 fi; \
	fi

# age のインストール可能なバージョン候補を出力する。
# - macOS は通常 formula の stable version と versioned formula 一覧を出力する
# - macOS で versioned formula が見つからない場合はその旨を出力する
# - Ubuntu / Debian 系は apt-cache madison をそのまま使う
# - Windows は winget show --versions を使う
# 例) make age-installable-versions
.PHONY: age-installable-versions
age-installable-versions:
	@if [ "$(HOST_OS)" = "Darwin" ]; then \
	 command -v brew >$(NULLDEV) 2>&1 || { echo 'Homebrew が見つかりません'; exit 1; }; \
	 stable_version="$$(brew info --json=v2 "$(AGE_BREW_FORMULA)" 2>$(NULLDEV) | sed -n 's/.*"stable":"\([^"]*\)".*/\1/p' | head -n 1)"; \
	 [ -n "$$stable_version" ] && echo "$$stable_version"; \
	 formulas="$$(brew search --formula '/^$(AGE_BREW_FORMULA)@([0-9]+(\\.[0-9]+)?)$$/' 2>$(NULLDEV) | grep '^$(AGE_BREW_FORMULA)@[0-9][0-9.]*$$' || true)"; \
	 if [ -n "$$formulas" ]; then \
	  printf '%s\n' "$$formulas" | sed 's/^$(AGE_BREW_FORMULA)@//'; \
	 else \
	  echo 'Homebrew で age の versioned formula は見つかりません'; \
	 fi; \
	elif [ -f /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease 2>$(NULLDEV); then \
	 command -v apt-cache >$(NULLDEV) 2>&1 || { echo 'apt-cache が見つかりません'; exit 1; }; \
	 apt-cache madison age 2>$(NULLDEV) | awk 'NF >= 3 { print $$3 }'; \
	elif [ "$(HOST_OS)" = "Linux" ] || [ "$(HOST_OS)" = "GNU/Linux" ]; then \
	 command -v apt-cache >$(NULLDEV) 2>&1 || { echo 'apt-cache が見つかりません'; exit 1; }; \
	 apt-cache madison age 2>$(NULLDEV) | awk 'NF >= 3 { print $$3 }'; \
	elif [ "$(HOST_OS)" = "Windows" ] || [ -n "$(IS_WINDOWS)" ]; then \
	 command -v powershell.exe >$(NULLDEV) 2>&1 || { echo 'powershell.exe が見つかりません'; exit 1; }; \
	 powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "winget show --id $(AGE_WINGET_ID) -e --versions --source winget"; \
	else \
	 echo "未対応の OS です: $(HOST_OS)"; \
	 exit 1; \
	fi

# age のインストール済みバージョンを出力する。
# - age が未導入なら失敗する
# 例) make age-version
.PHONY: age-version
age-version:
	@version="$$( $(call age_detect_installed_version) )"; \
	[ -n "$$version" ] || { echo 'age が見つかりません'; exit 1; }; \
	echo "$$version"

# age をアンインストールする。
# - 未導入なら何もしない
# - macOS は age と age@* の両方を対象にする
# - Ubuntu / Debian 系は purge を使う
# - Windows は winget を使う
# 例) make age-uninstall
.PHONY: age-uninstall
age-uninstall:
	@if [ "$(HOST_OS)" = "Darwin" ]; then \
	 command -v brew >$(NULLDEV) 2>&1 || { echo 'Homebrew が見つかりません'; exit 1; }; \
	 formulas="$$(brew list --formula 2>$(NULLDEV) | grep '^$(AGE_BREW_FORMULA)\(@.*\)\?$$' || true)"; \
	 if [ -n "$$formulas" ]; then \
	  for formula in $$formulas; do \
	   brew uninstall --formula "$$formula"; \
	  done; \
	 fi; \
	elif [ -f /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease 2>$(NULLDEV); then \
	 command -v apt-get >$(NULLDEV) 2>&1 || { echo 'apt-get が見つかりません'; exit 1; }; \
	 if dpkg -s age >$(NULLDEV) 2>&1; then \
	  sudo apt-get purge -y age; \
	 fi; \
	elif [ "$(HOST_OS)" = "Linux" ] || [ "$(HOST_OS)" = "GNU/Linux" ]; then \
	 command -v apt-get >$(NULLDEV) 2>&1 || { echo 'Ubuntu / Debian 系の apt-get が見つかりません'; exit 1; }; \
	 if dpkg -s age >$(NULLDEV) 2>&1; then \
	  sudo apt-get purge -y age; \
	 fi; \
	elif [ "$(HOST_OS)" = "Windows" ] || [ -n "$(IS_WINDOWS)" ]; then \
	 command -v powershell.exe >$(NULLDEV) 2>&1 || { echo 'powershell.exe が見つかりません'; exit 1; }; \
	 powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$$ErrorActionPreference = 'Stop'; if (winget list --id $(AGE_WINGET_ID) -e --source winget 2>$$null | Select-String '$(AGE_WINGET_ID)') { winget uninstall --id $(AGE_WINGET_ID) -e --source winget --accept-source-agreements }"; \
	else \
	 echo "未対応の OS です: $(HOST_OS)"; \
	 exit 1; \
	fi

# age をインストールする。
# - AGE_VERSION 未指定時は最新版を導入する
# - AGE_VERSION 指定時、異なるバージョンが入っていれば先にアンインストールする
# - macOS は versioned formula が見つかる場合のみ age@<version> を使う
# - macOS で versioned formula が見つからない場合は brew install age を使う
# 例) make age-install
# 例) make age-install AGE_VERSION=1.3.1
.PHONY: age-install
age-install:
	@requested_version='$(AGE_VERSION)'; \
	installed_version="$$( $(call age_detect_installed_version) )"; \
	if [ -n "$$requested_version" ] && [ -n "$$installed_version" ] && [ "$$installed_version" != "$$requested_version" ]; then \
	 $(MAKE) age-uninstall; \
	 installed_version=''; \
	fi; \
	if [ -n "$$installed_version" ]; then \
	 :; \
	elif [ "$(HOST_OS)" = "Darwin" ]; then \
	 command -v brew >$(NULLDEV) 2>&1 || { echo 'Homebrew が見つかりません'; exit 1; }; \
	 formula="$$( $(MAKE) --no-print-directory age-brew-formula AGE_VERSION="$$requested_version" )"; \
	 brew install "$$formula"; \
	elif [ -f /proc/sys/kernel/osrelease ] && grep -qi microsoft /proc/sys/kernel/osrelease 2>$(NULLDEV); then \
	 command -v apt-get >$(NULLDEV) 2>&1 || { echo 'apt-get が見つかりません'; exit 1; }; \
	 sudo apt-get update; \
	 if [ -n "$$requested_version" ]; then \
	  sudo apt-get install -y "age=$$requested_version"; \
	 else \
	  sudo apt-get install -y age; \
	 fi; \
	elif [ "$(HOST_OS)" = "Linux" ] || [ "$(HOST_OS)" = "GNU/Linux" ]; then \
	 command -v apt-get >$(NULLDEV) 2>&1 || { echo 'Ubuntu / Debian 系の apt-get が見つかりません'; exit 1; }; \
	 sudo apt-get update; \
	 if [ -n "$$requested_version" ]; then \
	  sudo apt-get install -y "age=$$requested_version"; \
	 else \
	  sudo apt-get install -y age; \
	 fi; \
	elif [ "$(HOST_OS)" = "Windows" ] || [ -n "$(IS_WINDOWS)" ]; then \
	 command -v powershell.exe >$(NULLDEV) 2>&1 || { echo 'powershell.exe が見つかりません'; exit 1; }; \
	 if [ -n "$$requested_version" ]; then \
	  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "winget install --id $(AGE_WINGET_ID) -e --source winget --version $$requested_version --accept-package-agreements --accept-source-agreements"; \
	 else \
	  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "winget install --id $(AGE_WINGET_ID) -e --source winget --accept-package-agreements --accept-source-agreements"; \
	 fi; \
	else \
	 echo "未対応の OS です: $(HOST_OS)"; \
	 exit 1; \
	fi

# age をインストールする。
# - AGE_VERSION 未指定時は最新版を導入する
# - AGE_VERSION 指定時、異なるバージョンが入っていれば先にアンインストールする
# - macOS は versioned formula が見つかる場合のみ age@<version> を使う
# - macOS で versioned formula が見つからない場合は brew install age を使う
# 例) make age-install@1.3.1
.PHONY: age-install@%
age-install@%:
	$(MAKE) age-install AGE_VERSION=$*

# .agekey が無い場合のみ鍵を生成し、public key を出力する。
# - 既存 .agekey がある場合は再生成しない
# - 既存鍵がある場合も public key を出力する
# 例) make age-keygen
.PHONY: age-keygen
age-keygen: age-install
	@if [ -f "$(AGE_KEY_FILE)" ]; then \
	 grep '^# public key:' "$(AGE_KEY_FILE)" | sed 's/^# public key: /public key: /'; \
	else \
	 age-keygen -o "$(AGE_KEY_FILE)" >$(NULLDEV); \
	fi

endif
