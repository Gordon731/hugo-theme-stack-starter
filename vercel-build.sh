#!/usr/bin/env bash
set -euo pipefail

# 1) 安装 Go（仅在构建时临时用来下载模块）
curl -fsSL https://go.dev/dl/go1.22.0.linux-amd64.tar.gz -o /tmp/go.tar.gz
tar -C /vercel -xzf /tmp/go.tar.gz
export GOROOT="/vercel/go"
export PATH="$GOROOT/bin:$PATH"

# 2) 可选：设置 Go 代理（让下载更稳定）
export GOPROXY="https://proxy.golang.org,direct"

# 3) 拉取 Hugo 模块并构建
hugo mod tidy
hugo --gc --minify
