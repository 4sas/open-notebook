-include .make/system.mk
-include docker/docker.mk

# -----------------------------------------------------------------------------
# ghcr
# -----------------------------------------------------------------------------
# 役割:
# - ローカル image を GHCR に push する
# - Windows / Unix 系で実装を分ける
#
# 前提:
# - GHCR_OWNER に GitHub の user / org 名を設定する
# - GHCR_USERNAME に docker login 用の GitHub user 名を設定する
# - GHCR_TOKEN に GHCR へ push 可能な Personal access tokens (classic) を設定する
#
# 使い方:
# - make ghcr-push.staging
# - make ghcr-push.v1.2.3.production
# - make ghcr-push-b.v1.2.3.production
# -----------------------------------------------------------------------------
GHCR_REGISTRY ?= ghcr.io
GHCR_ENV ?= local
GHCR_ENV_RESOLVED := $(call normalize_env,$(or $(GHCR_ENV),$(ENV),$(env)))
GHCR_OWNER ?= 4sas
GHCR_USERNAME ?= 4sas
GHCR_TOKEN_FILE ?= .secrets/ghcr.token
GHCR_IMAGE_BASE_NAME ?= $(IMAGE_LOCAL_NAME)

.PHONY: ghcr-push
ifneq ($(IS_WINDOWS),)
# Windows 系では PowerShell 経由で push する。
ghcr-push:
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -Command " \
	  $$ErrorActionPreference = 'Stop'; \
	  $$envName = '$(GHCR_ENV_RESOLVED)'; \
	  if ('local', 'staging', 'production' -notcontains $$envName) { throw 'GHCR_ENV must be one of: local | staging | production (shorthand: l | 	stg | prd)' }; \
	  $$owner = '$(GHCR_OWNER)'.Trim(); \
	  $$username = '$(GHCR_USERNAME)'.Trim(); \
	  $$tokenFile = '$(GHCR_TOKEN_FILE)'.Trim(); \
	  if ([string]::IsNullOrWhiteSpace($$owner)) { throw 'GHCR_OWNER is required' }; \
	  if ([string]::IsNullOrWhiteSpace($$username)) { throw 'GHCR_USERNAME is required' }; \
	  if ([string]::IsNullOrWhiteSpace($$tokenFile)) { throw 'GHCR_TOKEN_FILE is required' }; \
	  if (-not (Test-Path $$tokenFile)) { throw ('GHCR_TOKEN_FILE not found: ' + $$tokenFile) }; \
	  $$token = (Get-Content -Raw $$tokenFile).Trim(); \
	  if ([string]::IsNullOrWhiteSpace($$token)) { throw 'GHCR token is empty' }; \
	  $$suffix = if ($$envName -eq 'local') { '-local' } elseif ($$envName -eq 'staging') { '-staging' } else { '' }; \
	  $$registry = '$(GHCR_REGISTRY)'; \
	  $$owner = $$owner.ToLowerInvariant(); \
	  $$imageName = ('$(GHCR_IMAGE_BASE_NAME)' + $$suffix).ToLowerInvariant(); \
	  $$tag = '$(BUILD_TAG)'; \
	  $$imageUri = $$registry + '/' + $$owner + '/' + $$imageName + ':' + $$tag; \
	  $$token | docker login $$registry --username $$username --password-stdin; \
	  docker tag '$(IMAGE_LOCAL_NAME):$(BUILD_TAG)' $$imageUri; \
	  docker push $$imageUri; \
	  Write-Host ('Pushed: ' + $$imageUri);"
else
# Unix 系では POSIX shell 経由で push する。
ghcr-push:
	@set -eu; \
	  case "$(GHCR_ENV_RESOLVED)" in \
	  local) suffix="-local" ;; \
	  staging) suffix="-staging" ;; \
	  production) suffix="" ;; \
	  *) echo "GHCR_ENV must be one of: local | staging | production (shorthand: l | stg | prd)" >&2; exit 2 ;; \
	  esac; \
	  owner='$(GHCR_OWNER)'; \
	  username='$(GHCR_USERNAME)'; \
	  token_file='$(GHCR_TOKEN_FILE)'; \
	  [ -n "$$owner" ] || { echo 'GHCR_OWNER is required' >&2; exit 2; }; \
	  [ -n "$$username" ] || { echo 'GHCR_USERNAME is required' >&2; exit 2; }; \
	  [ -n "$$token_file" ] || { echo 'GHCR_TOKEN_FILE is required' >&2; exit 2; }; \
	  [ -f "$$token_file" ] || { echo "GHCR_TOKEN_FILE not found: $$token_file" >&2; exit 2; }; \
	  token="$$(tr -d '\r' < "$$token_file" | sed -n '1p')"; \
	  [ -n "$$token" ] || { echo 'GHCR token is empty' >&2; exit 2; }; \
	  registry='$(GHCR_REGISTRY)'; \
	  owner_lc="$$(printf '%s' "$$owner" | tr '[:upper:]' '[:lower:]')"; \
	  image_name="$$(printf '%s' '$(GHCR_IMAGE_BASE_NAME)')$${suffix}"; \
	  image_name_lc="$$(printf '%s' "$$image_name" | tr '[:upper:]' '[:lower:]')"; \
	  image_uri="$$registry/$$owner_lc/$$image_name_lc:$(BUILD_TAG)"; \
	  printf '%s' "$$token" | docker login "$$registry" --username "$$username" --password-stdin; \
	  docker tag "$(IMAGE_LOCAL_NAME):$(BUILD_TAG)" "$$image_uri"; \
	  docker push "$$image_uri"; \
	  echo "Pushed: $$image_uri"
endif

# ドット記法で tag / env を渡す省略形。
# 例) make ghcr-push.production
# 例) make ghcr-push.v1.2.3.staging
.PHONY: ghcr-push.%
ghcr-push.%:
	$(MAKE) ghcr-push \
	  BUILD_TAG=$(call parse_tag_or_default,$*,$(BUILD_TAG)) \
	  GHCR_ENV=$(call parse_env_or_default,$*)

# build と push をまとめて実行する。
# 例) make ghcr-push-b.production
# 例) make ghcr-push-b.v1.2.3.staging
.PHONY: ghcr-push-b.%
ghcr-push-b.%:
	$(MAKE) dc-build \
	  BUILD_TAG=$(call parse_tag_or_default,$*,$(BUILD_TAG)) \
	  BUILD_ENV=$(call parse_env_or_default,$*)
	$(MAKE) ghcr-push \
	  BUILD_TAG=$(call parse_tag_or_default,$*,$(BUILD_TAG)) \
	  GHCR_ENV=$(call parse_env_or_default,$*)
