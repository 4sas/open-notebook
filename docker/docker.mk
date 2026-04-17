ifndef __DOCKER_DOCKER_MK__
__DOCKER_DOCKER_MK__ := 1

-include .make/system.mk

# -----------------------------------------------------------------------------
# docker
# -----------------------------------------------------------------------------
# 役割:
# - docker compose の起動 / 停止 / 削除 / ログ確認
# - コンテナ build
# - docker compose selector 記法の解釈
#
# selector 記法:
# - dc-up.<project>        : docker/<project> 配下で compose 実行
# - dc-up@<service>        : service を指定
# - dc-up.<project>@<service>
# 例) make dc-up
# 例) make dc-up.app
# 例) make dc-up@web
# 例) make dc-up.app@web
# -----------------------------------------------------------------------------
DOCKER_DIR := docker
BUILD_TAG ?= latest
DOCKER_BUILD_IMAGE_NAME ?= open-notebook
DOCKER_BUILD_DOCKERFILE ?= Dockerfile.single
DOCKER_BUILD_CONTEXT ?= .

# macOS（Darwin）のときだけ amd64 を強制（Apple Silicon 対策）
ifeq ($(HOST_OS),Darwin)
DOCKER_COMPOSE_ENV := DOCKER_DEFAULT_PLATFORM=linux/amd64
else
DOCKER_COMPOSE_ENV :=
endif

# WSL 上で Docker Desktop の `desktop-linux` context が current だと、
# `npipe` を見に行って `protocol not available` で失敗することがある。
# WSL では `default` context（unix:///var/run/docker.sock）へ戻してから実行する。
define ensure_wsl_docker_context
 @if grep -qi microsoft /proc/sys/kernel/osrelease 2>$(NULLDEV); then \
  current_context="$$(docker context show 2>$(NULLDEV) || true)"; \
  if [ "$$current_context" = "desktop-linux" ]; then \
   echo "[fix] WSL detected: switch docker context from desktop-linux to default"; \
   docker context use default >$(NULLDEV); \
  fi; \
 fi
endef

# dc-up.<project>@<service> の suffix から project を取り出す。
define parse_selector_project_dir
$(strip $(if $(findstring @,$(1)),$(firstword $(subst @, ,$(1))),$(if $(word 2,$(subst ., ,$(1))),$(word 1,$(subst ., ,$(1))),$(1))))
endef

# dc-up.<project>@<service> の suffix から service を取り出す。
define parse_selector_service_name
$(strip $(if $(findstring @,$(1)),$(word 2,$(subst @, ,$(1))),$(if $(word 2,$(subst ., ,$(1))),$(word 2,$(subst ., ,$(1))),)))
endef

# docker compose を実行する作業ディレクトリ。
define compose_workdir
$(DOCKER_DIR)$(if $(PROJECT_DIR),/$(PROJECT_DIR),)
endef

# compose 実行前に WSL context 補正を行い、対象ディレクトリへ移動してコマンドを実行する。
define in_compose_dir
$(call ensure_wsl_docker_context)
cd $(call compose_workdir) && $(1)
endef

# short hand を正規化する。
# - l / local        -> local
# - s / stg / staging -> staging
# - p / prd / prod / production -> production
define normalize_env
$(strip $(if $(filter l local,$(1)),local,$(if $(filter s stg staging,$(1)),staging,$(if $(filter p prd prod production,$(1)),production,$(1)))))
endef

# dc-build.<BUILD_TAG>.<BUILD_ENV> / ecr-push.<BUILD_TAG>.<ECR_ENV> 用の tag 解決。
define parse_tag_or_default
$(strip $(if $(word 2,$(subst ., ,$(1))),$(word 1,$(subst ., ,$(1))),$(2)))
endef

# dc-build.<BUILD_TAG>.<BUILD_ENV> / ecr-push.<BUILD_TAG>.<ECR_ENV> 用の env 解決。
define parse_env_or_default
$(strip $(if $(word 2,$(subst ., ,$(1))),$(word 2,$(subst ., ,$(1))),$(word 1,$(subst ., ,$(1)))))
endef

# コンテナを起動する。
# 例) make dc-up
# 例) make dc-up.app@web
.PHONY: dc-up
dc-up:
	$(call in_compose_dir,$(DOCKER_COMPOSE_ENV) docker compose up -d $(SERVICE_NAME))

# コンテナを build 付きで起動する。
# 例) make dc-up-b
# 例) make dc-up-b.app@web
.PHONY: dc-up-b
dc-up-b:
	$(call in_compose_dir,$(DOCKER_COMPOSE_ENV) docker compose up -d --build $(SERVICE_NAME))

# コンテナを停止する。コンテナ自体は削除しない。
# 例) make dc-stop
.PHONY: dc-stop
dc-stop:
	$(call in_compose_dir,docker compose stop $(SERVICE_NAME))

# コンテナを停止し削除する。ボリュームは残す。
# 例) make dc-down
# 注意: サービス未指定時は compose down を実行する。
.PHONY: dc-down
dc-down:
	$(call ensure_wsl_docker_context)
	cd $(call compose_workdir) && \
	if [ -n "$(SERVICE_NAME)" ]; then \
	  docker compose rm -f -s $(SERVICE_NAME); \
	else \
	  docker compose down --rmi local; \
	fi

# コンテナを停止し削除する。ボリュームも削除する。
# 例) make dc-down-v
# 注意: データ破棄を伴う可能性がある。
.PHONY: dc-down-v
dc-down-v:
	$(call ensure_wsl_docker_context)
	cd $(call compose_workdir) && \
	if [ -n "$(SERVICE_NAME)" ]; then \
	  docker compose rm -f -s -v $(SERVICE_NAME); \
	else \
	  docker compose down --rmi local --volumes; \
	fi

# 起動中コンテナを確認する。
# 例) make dc-ps
.PHONY: dc-ps
dc-ps:
	$(call in_compose_dir,docker compose ps $(SERVICE_NAME))

# ログを追尾表示する。
# 例) make dc-logs
# 例) make dc-logs.app@web
.PHONY: dc-logs
dc-logs:
	$(call in_compose_dir,docker compose logs -f $(SERVICE_NAME))

# selector 記法を通常ターゲットへ展開する共通ルール。
# 生成される形式:
# - <target>.<project>
# - <target>@<service>
# - <target>.<project>@<service>
#
# 備考:
# - `@service` 単体指定は `$*` だけに依存せず、`$@` からも service 名を再解釈する。
#   これにより、上位 Makefile の generic rule や再帰呼び出しの影響で stem が壊れた場合でも、
#   このファイル単体では selector を安定して解決しやすくする。
define compose_selector_rules
.PHONY: $(1).%
$(1).%:
	@selector='$$*'; \
	project_dir="$$$$selector"; \
	service_name=''; \
	case "$$$$selector" in \
	  *@*) \
	    project_dir="$$$${selector%%@*}"; \
	    service_name="$$$${selector#*@}"; \
	    ;; \
	esac; \
	$(MAKE) --no-print-directory $(1) \
	  PROJECT_DIR="$$$$project_dir" \
	  SERVICE_NAME="$$$$service_name"

.PHONY: $(1)@%
$(1)@%:
	$(MAKE) --no-print-directory $(1) SERVICE_NAME="$$*"
endef

$(eval $(call compose_selector_rules,dc-up))
$(eval $(call compose_selector_rules,dc-up-b))
$(eval $(call compose_selector_rules,dc-stop))
$(eval $(call compose_selector_rules,dc-down))
$(eval $(call compose_selector_rules,dc-down-v))
$(eval $(call compose_selector_rules,dc-ps))
$(eval $(call compose_selector_rules,dc-logs))

# docker-compose.yaml を Helm Charts へ変換する。
# 例) make dc2helm.app
.PHONY: dc2helm
dc2helm:
	kompose convert -c -f $(DOCKER_DIR)/${PROJECT_DIR}/docker-compose.yaml -o helm/${PROJECT_DIR}

.PHONY: dc2helm.%
dc2helm.%:
	$(MAKE) dc2helm PROJECT_DIR=$*

# -----------------------------------------------------------------------------
# docker build
# -----------------------------------------------------------------------------
BUILD_ENV ?= local
BUILD_ENV_RESOLVED := $(call normalize_env,$(or $(BUILD_ENV),$(ENV),$(env)))

# アプリ用 Docker image を build する。
# 例) make dc-build
# 例) make dc-build.staging
# 例) make dc-build.v1.2.3.production
.PHONY: dc-build
dc-build:
	@if [ -z "$(BUILD_ENV_RESOLVED)" ] || ! printf '%s' "$(BUILD_ENV_RESOLVED)" | grep -Eq '^(local|staging|production)$$'; then \
	  echo "BUILD_ENV must be one of: local | staging | production (shorthand: l | stg | prd)" >&2; \
	  exit 2; \
	fi
	docker build -t $(DOCKER_BUILD_IMAGE_NAME):$(BUILD_TAG) -f $(DOCKER_BUILD_DOCKERFILE) --build-arg ENV=$(BUILD_ENV_RESOLVED) $(DOCKER_BUILD_CONTEXT)

# ドット記法で tag / env を渡す省略形。
# 例) make dc-build.staging
# 例) make dc-build.v1.2.3.production
.PHONY: dc-build.%
dc-build.%:
	$(MAKE) dc-build \
	  BUILD_TAG=$(call parse_tag_or_default,$*,$(BUILD_TAG)) \
	  BUILD_ENV=$(call parse_env_or_default,$*)

# -----------------------------------------------------------------------------
# Docker Desktop
# -----------------------------------------------------------------------------
# Docker Desktop の containerd image store の有効状態を確認する。
# 無効な場合のみ GUI での設定手順を案内する。
# 例) $(call docker_desktop_containerd_check)
define docker_desktop_containerd_check
 @status="$$(docker info -f '{{ .DriverStatus }}' 2>$(NULLDEV) || true)"; \
 echo "$$status"; \
 if printf '%s\n' "$$status" | grep -q 'io.containerd.snapshotter.v1'; then \
  echo 'Docker Desktop の containerd image store は有効です。'; \
 else \
  echo 'Docker Desktop の containerd image store は有効ではありません。'; \
  echo 'GUI で有効化してください: Docker Desktop -> Settings -> General -> Use containerd for pulling and storing images'; \
 fi
endef

endif
