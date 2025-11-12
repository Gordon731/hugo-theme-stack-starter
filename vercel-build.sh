#!/usr/bin/env bash
set -euo pipefail

# Vercel 构建脚本 - 修复版本
# 此脚本修复了原脚本中的权限问题和依赖安装问题

echo "🚀 Starting Vercel build process..."

# 1) 安装 Hugo Extended（如果未安装）
if ! command -v hugo &> /dev/null; then
    echo "📦 Installing Hugo Extended..."
    HUGO_VERSION=${HUGO_VERSION:-"0.123.8"}
    
    # 检测架构
    ARCH="64bit"
    if [ "$(uname -m)" = "aarch64" ]; then
        ARCH="ARM64"
    fi
    
    echo "   Hugo version: ${HUGO_VERSION}"
    echo "   Architecture: ${ARCH}"
    
    # 下载 Hugo Extended
    wget -q -O /tmp/hugo.tar.gz "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_Linux-${ARCH}.tar.gz" || {
        echo "❌ Failed to download Hugo"
        exit 1
    }
    
    # 解压并安装
    tar -xzf /tmp/hugo.tar.gz -C /tmp
    sudo mv /tmp/hugo /usr/local/bin/hugo || mv /tmp/hugo /usr/local/bin/hugo
    chmod +x /usr/local/bin/hugo
    
    echo "✅ Hugo installed successfully"
    hugo version
else
    echo "✅ Hugo already installed"
    hugo version
fi

# 2) 安装 Go（用于下载 Hugo 模块）
if ! command -v go &> /dev/null; then
    echo "📦 Installing Go..."
    GO_VERSION="1.21.0"
    
    # 检测架构
    GO_ARCH="amd64"
    if [ "$(uname -m)" = "aarch64" ]; then
        GO_ARCH="arm64"
    fi
    
    echo "   Go version: ${GO_VERSION}"
    echo "   Architecture: ${GO_ARCH}"
    
    # 使用用户目录避免权限问题
    GO_INSTALL_DIR="$HOME/go"
    mkdir -p "$GO_INSTALL_DIR"
    
    # 下载 Go
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz || {
        echo "❌ Failed to download Go"
        exit 1
    }
    
    # 解压到用户目录
    tar -C "$HOME" -xzf /tmp/go.tar.gz
    export GOROOT="$HOME/go"
    export PATH="$GOROOT/bin:$PATH"
    
    echo "✅ Go installed successfully"
    go version
else
    echo "✅ Go already installed"
    go version
fi

# 3) 设置 Go 代理（加速模块下载，特别是中国大陆）
export GOPROXY=${GOPROXY:-"https://proxy.golang.org,direct"}
export GOSUMDB=${GOSUMDB:-"sum.golang.org"}

# 4) 拉取 Hugo 模块
echo "📥 Downloading Hugo modules..."
hugo mod tidy || {
    echo "⚠️  Warning: hugo mod tidy failed, continuing anyway..."
}

# 5) 构建网站
echo "🔨 Building site..."
hugo --gc --minify || {
    echo "❌ Build failed"
    exit 1
}

echo "✅ Build completed successfully!"
echo "📁 Output directory: public/"
