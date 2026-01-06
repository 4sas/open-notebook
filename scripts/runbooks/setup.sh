#!/usr/bin/env bash
set -euo pipefail

# Docker の起動
docker compose -p open-notebook -f docker-compose.full.yml up -d --build
