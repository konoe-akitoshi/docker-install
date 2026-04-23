#!/usr/bin/env bash

set -eo pipefail

# 色付きメッセージ用の関数（stderrに出力し、stdoutとの混在を防ぐ）
print_info() {
    echo -e "\033[34m[INFO]\033[0m $1" >&2
}

print_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1" >&2
}

print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1" >&2
}

print_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1" >&2
}

# OSの検出
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        print_error "サポートされていないOS: $OSTYPE"
        exit 1
    fi
}

# アーキテクチャの検出
detect_architecture() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        x86_64)
            echo "linux-x86_64"
            ;;
        aarch64|arm64)
            echo "linux-aarch64"
            ;;
        armv7l)
            echo "linux-armv7"
            ;;
        *)
            print_error "サポートされていないアーキテクチャ: $arch"
            exit 1
            ;;
    esac
}

# Dockerがインストール済みかチェック
check_docker_installed() {
    set +e
    if command -v docker &> /dev/null; then
        local docker_version
        docker_version=$(docker --version 2>/dev/null || echo "不明")
        print_info "Docker は既にインストールされています: $docker_version"
        set -e
        return 0
    else
        set -e
        return 1
    fi
}

# Docker Composeがインストール済みかチェック
check_docker_compose_installed() {
    set +e
    if docker compose version &> /dev/null; then
        local compose_version
        compose_version=$(docker compose version --short 2>/dev/null || echo "不明")
        print_info "Docker Compose は既にインストールされています: $compose_version"
        set -e
        return 0
    else
        set -e
        return 1
    fi
}

# Dockerのインストール
install_docker() {
    print_info "Dockerのインストールを開始します..."

    # Dockerがすでにインストールされているかチェック
    if check_docker_installed; then
        print_success "Dockerのインストールをスキップします"
        return 0
    fi

    # Dockerの公式インストールスクリプトを実行
    print_info "Docker公式インストールスクリプトを実行中..."
    if curl -fsSL https://get.docker.com | bash -x; then
        print_success "Dockerのインストールが完了しました"
    else
        print_error "Dockerのインストールに失敗しました"
        print_error "手動で以下のコマンドを実行してください："
        echo "  curl -fsSL https://get.docker.com | bash -x"
        return 1
    fi

    # dockerグループが存在しない場合は作成し、ユーザーを追加
    if ! getent group docker > /dev/null; then
        print_info "dockerグループが存在しないため作成します..."
        sudo groupadd docker
    fi
    print_info "ユーザーをdockerグループに追加中..."
    sudo usermod -aG docker "$USER"

    # containerdサービスの有効化（Dockerサービスはget.docker.comが自動で開始・有効化済み）
    print_info "containerdサービスを有効化中..."
    sudo systemctl enable containerd.service

    print_success "Dockerの設定が完了しました"
}

# Dockerの動作確認
# post_install=true の場合、sg経由でグループ反映を確認（インストール直後に使用）
verify_docker() {
    local post_install="${1:-false}"
    print_info "Dockerの動作を確認中..."

    if ! command -v docker &> /dev/null; then
        print_error "Dockerがインストールされていません"
        return 1
    fi

    # Dockerデーモンが動作しているかチェック
    if [ "$post_install" = true ]; then
        # インストール直後はグループが現在のセッションに未反映のため sg 経由で確認
        if ! sg docker -c "docker info" &> /dev/null; then
            print_error "Dockerデーモンが動作していないか、グループ設定に問題があります"
            return 1
        fi
    else
        if ! docker info &> /dev/null; then
            print_error "Dockerデーモンが動作していないか、権限がありません"
            print_info "以下を確認してください："
            echo "  1. sudo systemctl start docker"
            echo "  2. sudo usermod -aG docker \$USER"
            echo "  3. newgrp docker または再ログイン"
            return 1
        fi
    fi

    print_success "Dockerが正常に動作しています"
    return 0
}

# Docker Composeの最新バージョンを取得
get_latest_version() {
    print_info "Docker Composeの最新バージョンを取得中..."
    local latest_version
    latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    if [ -z "$latest_version" ]; then
        print_error "最新バージョンの取得に失敗しました"
        exit 1
    fi
    echo "$latest_version"
}

# Docker Composeをダウンロードしてインストール
install_docker_compose() {
    local version="$1"
    local arch="$2"

    print_info "Docker Composeのインストールを開始します..."

    # Docker Composeがすでにインストールされているかチェック
    if check_docker_compose_installed; then
        print_success "Docker Composeのインストールをスキップします"
        return 0
    fi

    local plugin_dir="$HOME/.docker/cli-plugins"
    local binary_name="docker-compose"
    local download_url="https://github.com/docker/compose/releases/download/$version/docker-compose-$arch"

    print_info "Docker Compose $version をダウンロード中..."

    # プラグインディレクトリを作成
    mkdir -p "$plugin_dir"

    # バイナリをダウンロード
    if curl -L "$download_url" -o "$plugin_dir/$binary_name"; then
        print_success "ダウンロード完了"
    else
        print_error "ダウンロードに失敗しました"
        return 1
    fi

    # 実行権限を付与
    chmod +x "$plugin_dir/$binary_name"
    print_success "実行権限を付与しました"
}

# Docker Composeのインストール確認
verify_docker_compose() {
    print_info "Docker Composeのインストールを確認中..."

    if docker compose version &> /dev/null; then
        local installed_version
        installed_version=$(docker compose version --short)
        print_success "Docker Compose v2 が正常に動作しています"
        print_info "バージョン: $installed_version"

        # 使用例を表示
        echo ""
        print_info "基本的な使用方法："
        echo "  docker compose up -d      # サービスをバックグラウンドで起動"
        echo "  docker compose down       # サービスを停止・削除"
        echo "  docker compose logs       # ログを表示"
        echo "  docker compose ps         # 実行中のコンテナを表示"
        echo "  docker compose restart    # サービスを再起動"
        return 0
    else
        print_error "Docker Composeのインストール確認に失敗しました"
        return 1
    fi
}

# macOS用の処理
handle_macos() {
    print_info "macOSが検出されました"

    # Docker Composeがすでに利用可能かチェック
    if check_docker_compose_installed; then
        print_success "Docker Compose は既に利用可能です"
        verify_docker_compose
        exit 0
    fi

    print_info "macOSではDocker Desktopの使用を推奨します"
    print_warning "Docker DesktopにはDocker Compose v2が含まれています"
    echo ""
    print_info "Docker Desktopのダウンロード："
    echo "https://www.docker.com/products/docker-desktop/"
    echo ""
    local yn
    read -r -p "Docker Desktopをインストール済みですか？ (y/n): " yn
    echo
    if [[ "$yn" =~ ^[Yy]$ ]]; then
        verify_docker_compose
    else
        print_info "Docker Desktopをインストールしてから再実行してください"
        exit 1
    fi
}

# システム状態の確認
check_system_status() {
    print_info "システム状態を確認中..."

    local docker_installed=false
    local compose_installed=false

    if check_docker_installed; then
        docker_installed=true
    fi

    if check_docker_compose_installed; then
        compose_installed=true
    fi

    if [ "$docker_installed" = true ] && [ "$compose_installed" = true ]; then
        print_success "Docker と Docker Compose は既にインストールされています"
        print_info "インストール処理をスキップして確認のみ実行します"
        echo 0
    elif [ "$docker_installed" = true ]; then
        print_info "Docker はインストール済み、Docker Compose のみインストールします"
        echo 1
    elif [ "$compose_installed" = true ]; then
        print_warning "Docker Compose は検出されましたが、Docker が見つかりません"
        print_info "Docker をインストールします"
        echo 2
    else
        print_info "Docker と Docker Compose の両方をインストールします"
        echo 3
    fi
}

# メイン処理
main() {
    print_info "Docker & Docker Compose v2 スマートインストールスクリプト開始"
    echo "============================================================"

    # OS検出
    local os
    os=$(detect_os)
    print_info "検出されたOS: $os"

    # macOSの場合は別処理
    if [ "$os" = "macos" ]; then
        handle_macos
        exit 0
    fi

    # Linux向けの処理
    print_info "Linuxシステム向けの処理を開始します"

    # システム状態確認
    local status
    status=$(check_system_status)

    # アーキテクチャの検出
    local arch
    arch=$(detect_architecture)
    print_info "検出されたアーキテクチャ: $arch"
    print_info "システム状態の判定結果: $status"

    local need_relogin=false

    # 状態に応じた処理
    case $status in
        0)
            # 両方インストール済み - 確認のみ
            verify_docker
            verify_docker_compose
            ;;
        1)
            # Dockerのみインストール済み
            verify_docker
            local latest_version
            latest_version=$(get_latest_version)
            print_info "最新バージョン: $latest_version"
            install_docker_compose "$latest_version" "$arch"
            verify_docker_compose
            ;;
        2)
            # Docker Composeのみインストール済み（異常な状態）
            install_docker
            # インストール直後はグループ未反映のため sudo で検証
            verify_docker true
            verify_docker_compose
            need_relogin=true
            ;;
        3)
            # 両方未インストール
            install_docker
            # インストール直後はグループ未反映のため sudo で検証
            verify_docker true

            local latest_version
            latest_version=$(get_latest_version)
            print_info "最新バージョン: $latest_version"
            install_docker_compose "$latest_version" "$arch"
            verify_docker_compose
            need_relogin=true
            ;;
    esac

    print_success "全ての処理が完了しました！"

    if [ "$need_relogin" = true ]; then
        echo ""
        print_warning "sudo なしで docker を使うには、再ログインが必要です："
        echo "  ログアウト後、再ログインしてください"
        echo "  または: newgrp docker（現在のターミナルのみ有効）"
    fi

    echo ""
    print_info "サンプルのcompose.yamlファイルを作成してテストできます："
    echo "mkdir test-compose && cd test-compose"
    echo "cat > compose.yaml << 'EOF'"
    echo "services:"
    echo "  hello-world:"
    echo "    image: hello-world"
    echo "EOF"
    echo "docker compose up"
}

# スクリプト実行
main "$@"