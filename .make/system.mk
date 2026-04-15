ifndef __MAKE_SYSTEM_MK__
__MAKE_SYSTEM_MK__ := 1

# -----------------------------------------------------------------------------
# system
# -----------------------------------------------------------------------------
# 役割:
# - OS / アーキテクチャ判定
# - shell / null device の共通設定
# - 他の .mk から使う共通ヘルパー定義
#
# 前提:
# - Unix 系では /bin/sh を利用する
# - Windows は Git Bash / MSYS2 / Cygwin など POSIX shell を想定する
# -----------------------------------------------------------------------------

# GNU Make on Unix normally uses /bin/sh.
# This project expects POSIX-shell based recipes.
SHELL := /bin/sh
.SHELLFLAGS := -eu -c

# Null device
NULLDEV := /dev/null

# OS / architecture detection
UNAME_S := $(shell uname -s 2>$(NULLDEV) || echo unknown)
UNAME_M := $(shell uname -m 2>$(NULLDEV) || echo unknown)

HOST_OS := $(UNAME_S)
ARCH := $(UNAME_M)

# Windows-like environments running POSIX shell (Git Bash / MSYS2 / Cygwin)
IS_WINDOWS := $(filter Windows MINGW% MSYS% CYGWIN%,$(HOST_OS))

# Native Windows fallback
ifeq ($(OS),Windows_NT)
HOST_OS := Windows
IS_WINDOWS := 1
NULLDEV := NUL
endif

# -----------------------------------------------------------------------------
# Command helpers
# -----------------------------------------------------------------------------
# 使い方:
# - レシピ内で $(call require_cmd,<command>) と書く
# - 例) $(call require_cmd,ffmpeg)
define require_cmd
 @command -v $(1) >$(NULLDEV) 2>&1 || { \
  echo "$(1) が見つかりません。PATH を確認してください"; \
  exit 1; \
 }
endef

# -----------------------------------------------------------------------------
# System info
# -----------------------------------------------------------------------------
# 現在の OS / CPU アーキテクチャを表示する。
# 例) make arch
.PHONY: arch
arch:
	@echo "==> CPU Architecture Information"
	@echo "HOST_OS: $(HOST_OS)"
	@echo "ARCH: $(ARCH)"
	@if [ "$(HOST_OS)" = "Windows" ]; then \
	  echo "Platform: Windows (POSIX shell required)"; \
	 else \
	  echo "Platform: Unix-like ($(HOST_OS))"; \
	 fi

endif
