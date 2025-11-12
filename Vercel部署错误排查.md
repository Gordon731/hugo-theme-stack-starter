# Vercel 部署错误排查文档

## 🔍 常见错误分析

### 错误类型 1: Hugo 未安装或版本不匹配

**错误现象：**
```
bash: hugo: command not found
```
或
```
Error: Hugo version mismatch
```

**原因分析：**
- Vercel 构建环境默认不包含 Hugo
- 需要先安装 Hugo Extended 版本
- 当前 `vercel-build.sh` 脚本假设 Hugo 已安装

**解决方案：**
需要在构建脚本中先安装 Hugo，或通过环境变量指定。

---

### 错误类型 2: Go 安装路径权限问题

**错误现象：**
```
tar: /vercel/go: Cannot open: Permission denied
```
或
```
mkdir: cannot create directory '/vercel': Permission denied
```

**原因分析：**
- `vercel-build.sh` 脚本尝试将 Go 安装到 `/vercel` 目录
- Vercel 构建环境可能没有该目录的写入权限
- 应该使用用户可写的目录，如 `/tmp` 或 `$HOME`

**当前脚本问题：**
```bash
# 问题代码
tar -C /vercel -xzf /tmp/go.tar.gz
export GOROOT="/vercel/go"
```

**解决方案：**
修改为使用临时目录或用户目录。

---

### 错误类型 3: Go 版本不匹配

**错误现象：**
```
go: go.mod requires go >= 1.17 (running go 1.22.0; GOROOT=/vercel/go)
```
或模块下载失败

**原因分析：**
- `go.mod` 要求 Go 1.17+
- 脚本安装的是 Go 1.22.0（版本过新可能导致兼容性问题）
- 应该使用与项目兼容的 Go 版本

**当前配置：**
- `go.mod`: `go 1.17`
- `vercel-build.sh`: 安装 `go1.22.0`

---

### 错误类型 4: 缺少 vercel.json 配置文件

**错误现象：**
- 构建命令未正确执行
- 输出目录未指定
- 环境变量未设置

**原因分析：**
- 项目缺少 `vercel.json` 配置文件
- Vercel 无法识别 Hugo 项目类型
- 需要明确指定构建设置

---

### 错误类型 5: Hugo Modules 下载失败

**错误现象：**
```
Error: failed to download module
```
或
```
timeout: context deadline exceeded
```

**原因分析：**
- 网络连接问题
- Go 代理配置不当
- 模块路径错误

---

### 错误类型 6: 输出目录未指定

**错误现象：**
- 构建成功但部署失败
- 找不到输出文件

**原因分析：**
- Vercel 默认输出目录可能不是 `public`
- 需要明确指定输出目录

---

## 🛠️ 解决方案

### 方案 1: 修复 vercel-build.sh 脚本

**修复后的脚本：**

```bash
#!/usr/bin/env bash
set -euo pipefail

# 1) 安装 Hugo Extended（如果未安装）
if ! command -v hugo &> /dev/null; then
    echo "Installing Hugo Extended..."
    HUGO_VERSION=${HUGO_VERSION:-"0.123.8"}
    ARCH="64bit"
    if [ "$(uname -m)" = "aarch64" ]; then
        ARCH="ARM64"
    fi
    wget -O /tmp/hugo.tar.gz "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_Linux-${ARCH}.tar.gz"
    tar -xzf /tmp/hugo.tar.gz -C /tmp
    sudo mv /tmp/hugo /usr/local/bin/hugo
    chmod +x /usr/local/bin/hugo
    hugo version
fi

# 2) 安装 Go（用于下载 Hugo 模块）
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    GO_VERSION="1.21.0"
    GO_ARCH="amd64"
    if [ "$(uname -m)" = "aarch64" ]; then
        GO_ARCH="arm64"
    fi
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -o /tmp/go.tar.gz
    mkdir -p "$HOME/go"
    tar -C "$HOME" -xzf /tmp/go.tar.gz
    export GOROOT="$HOME/go"
    export PATH="$GOROOT/bin:$PATH"
    go version
fi

# 3) 设置 Go 代理（加速模块下载）
export GOPROXY="https://proxy.golang.org,direct"
export GOSUMDB="sum.golang.org"

# 4) 拉取 Hugo 模块并构建
echo "Downloading Hugo modules..."
hugo mod tidy

echo "Building site..."
hugo --gc --minify

echo "Build completed successfully!"
```

**关键改进：**
1. ✅ 检查并安装 Hugo Extended
2. ✅ 使用 `$HOME` 目录安装 Go（避免权限问题）
3. ✅ 使用 Go 1.21.0（与 go.mod 兼容）
4. ✅ 添加错误检查和日志输出
5. ✅ 支持 ARM64 架构

---

### 方案 2: 创建 vercel.json 配置文件

**创建 `vercel.json`：**

```json
{
  "buildCommand": "bash vercel-build.sh",
  "outputDirectory": "public",
  "installCommand": "",
  "framework": null,
  "devCommand": "hugo server -D",
  "cleanUrls": true,
  "trailingSlash": false,
  "rewrites": [
    {
      "source": "/(.*)",
      "destination": "/$1"
    }
  ],
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-XSS-Protection",
          "value": "1; mode=block"
        }
      ]
    }
  ]
}
```

---

### 方案 3: 使用 Vercel 环境变量

在 Vercel 项目设置中添加以下环境变量：

| 变量名 | 值 | 说明 |
|--------|-----|------|
| `HUGO_VERSION` | `0.123.8` | Hugo Extended 版本 |
| `GO_VERSION` | `1.21.0` | Go 版本（可选） |
| `GOPROXY` | `https://proxy.golang.org,direct` | Go 代理（可选） |

**设置步骤：**
1. 登录 Vercel 控制台
2. 进入项目设置（Settings）
3. 选择 "Environment Variables"
4. 添加上述变量
5. 重新部署

---

### 方案 4: 简化构建脚本（推荐）

如果 Vercel 已预装 Hugo，可以使用更简单的脚本：

```bash
#!/usr/bin/env bash
set -euo pipefail

# 检查 Hugo 是否安装
if ! command -v hugo &> /dev/null; then
    echo "Error: Hugo is not installed. Please set HUGO_VERSION environment variable."
    exit 1
fi

# 显示 Hugo 版本
hugo version

# 安装 Go（如果未安装，用于下载模块）
if ! command -v go &> /dev/null; then
    echo "Installing Go..."
    # 使用系统包管理器安装（如果可用）
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y golang-go
    elif command -v yum &> /dev/null; then
        sudo yum install -y golang
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y golang
    else
        # 手动安装 Go
        GO_VERSION="1.21.0"
        curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
        sudo tar -C /usr/local -xzf /tmp/go.tar.gz
        export PATH="/usr/local/go/bin:$PATH"
    fi
    go version
fi

# 设置 Go 环境
export GOPROXY="https://proxy.golang.org,direct"
export GOSUMDB="sum.golang.org"

# 下载模块并构建
echo "Downloading Hugo modules..."
hugo mod tidy

echo "Building site..."
hugo --gc --minify

echo "✅ Build completed!"
```

---

## 📋 完整部署检查清单

### 部署前检查

- [ ] `vercel.json` 文件已创建并配置正确
- [ ] `vercel-build.sh` 脚本可执行（`chmod +x vercel-build.sh`）
- [ ] `go.mod` 和 `go.sum` 文件已提交到 Git
- [ ] `config/_default/config.toml` 中的 `baseurl` 已更新
- [ ] 环境变量 `HUGO_VERSION` 已在 Vercel 中设置
- [ ] 构建命令设置为 `bash vercel-build.sh`
- [ ] 输出目录设置为 `public`

### Vercel 项目设置

1. **Framework Preset**: 选择 "Other" 或 "Hugo"
2. **Build Command**: `bash vercel-build.sh`
3. **Output Directory**: `public`
4. **Install Command**: （留空，或根据需要设置）
5. **Root Directory**: （留空，除非项目在子目录中）

### 环境变量配置

在 Vercel 项目设置中添加：

```
HUGO_VERSION=0.123.8
```

（使用最新的 Hugo Extended 版本）

---

## 🐛 调试步骤

### 步骤 1: 查看构建日志

1. 登录 Vercel 控制台
2. 进入项目 → Deployments
3. 点击失败的部署记录
4. 查看 "Build Logs"

### 步骤 2: 本地测试构建脚本

在本地或 Docker 容器中测试：

```bash
# 模拟 Vercel 环境
docker run -it --rm -v $(pwd):/workspace -w /workspace ubuntu:22.04 bash

# 在容器中执行
apt-get update
apt-get install -y curl wget tar
bash vercel-build.sh
```

### 步骤 3: 检查文件权限

确保脚本有执行权限：

```bash
chmod +x vercel-build.sh
git add vercel-build.sh
git commit -m "Add executable permission to build script"
git push
```

### 步骤 4: 验证配置文件

检查 `config/_default/config.toml`：

```toml
baseurl = "https://your-domain.vercel.app"  # 更新为实际域名
```

---

## 🔧 快速修复方案

### 最小化修复（最快）

1. **创建 `vercel.json`**：
```json
{
  "buildCommand": "hugo mod tidy && hugo --gc --minify",
  "outputDirectory": "public"
}
```

2. **在 Vercel 设置中**：
   - 添加环境变量：`HUGO_VERSION=0.123.8`
   - 确保 Vercel 自动检测到 Hugo 项目

3. **如果仍然失败**，使用修复后的 `vercel-build.sh`

---

## 📝 常见错误信息对照表

| 错误信息 | 可能原因 | 解决方案 |
|---------|---------|---------|
| `hugo: command not found` | Hugo 未安装 | 设置 `HUGO_VERSION` 环境变量或修改构建脚本 |
| `Permission denied` | 文件权限问题 | 使用 `chmod +x vercel-build.sh` |
| `go: cannot find module` | Go 模块下载失败 | 检查网络连接，设置 `GOPROXY` |
| `Build output directory not found` | 输出目录错误 | 在 `vercel.json` 中设置 `outputDirectory: "public"` |
| `Module not found` | Hugo 模块未下载 | 确保 `hugo mod tidy` 在构建命令中 |
| `tar: Cannot open` | 路径权限问题 | 修改脚本使用 `$HOME` 或 `/tmp` |

---

## 🚀 推荐的最佳实践

1. **使用 vercel.json**：明确指定所有构建设置
2. **版本固定**：在环境变量中固定 Hugo 和 Go 版本
3. **错误处理**：在脚本中添加错误检查和日志
4. **缓存优化**：利用 Vercel 的构建缓存
5. **监控部署**：定期检查部署日志，及时发现问题

---

## 📚 参考资源

- [Vercel Hugo 部署文档](https://vercel.com/docs/frameworks/hugo)
- [Hugo 官方文档](https://gohugo.io/documentation/)
- [Go Modules 文档](https://go.dev/ref/mod)
- [Vercel 构建日志查看](https://vercel.com/docs/concepts/deployments/build-logs)

---

## ⚠️ 注意事项

1. **Hugo Extended 版本**：确保使用 Extended 版本以支持 SCSS
2. **Go 版本兼容性**：Go 版本应与 `go.mod` 要求匹配
3. **网络环境**：如果在中国大陆，可能需要配置 Go 代理为国内镜像
4. **构建时间**：首次构建可能需要较长时间下载依赖
5. **缓存清理**：如果遇到奇怪问题，尝试清除 Vercel 构建缓存

---

## 🎯 快速修复指南

### 修复已完成

项目已包含以下修复后的文件：

1. **`vercel-build.sh`** - 已修复的构建脚本
   - ✅ 自动检测并安装 Hugo Extended
   - ✅ 使用用户目录安装 Go（避免权限问题）
   - ✅ 添加错误检查和日志输出
   - ✅ 支持 ARM64 架构
   - ✅ Go 版本已修复为 1.21.0（与 go.mod 兼容）

2. **`vercel.json`** - Vercel 配置文件
   - ✅ 指定构建命令和输出目录
   - ✅ 配置安全头
   - ✅ 优化 URL 重写规则

### 使用步骤

1. **确保脚本可执行**：
   ```bash
   chmod +x vercel-build.sh
   ```

2. **验证配置文件**：
   - 项目根目录已有 `vercel.json` 文件
   - 构建命令已配置为：`bash vercel-build.sh`

3. **设置环境变量**：
   在 Vercel 项目设置中添加：
   - `HUGO_VERSION`: `0.123.8`（或最新版本）

4. **提交并推送**：
   ```bash
   git add vercel-build.sh vercel.json
   git commit -m "Fix Vercel deployment configuration"
   git push
   ```

5. **重新部署**：
   - 在 Vercel 控制台触发新的部署
   - 或等待自动部署触发

---

## 🔄 更新记录

- **2024-01-XX**: 初始版本，记录常见错误和解决方案
- **2024-01-XX**: 添加修复后的构建脚本和配置文件
- 建议根据实际部署错误持续更新本文档

