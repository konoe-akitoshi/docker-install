#!/usr/bin/env bash

set -eo pipefail

# 色付きメッセージ用の関数
print_info() {
    echo -e "\033[34m[INFO]\033[0m $1"
}

print_success() {
    echo -e "\033[32m[SUCCESS]\033[0m $1"
}

print_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

print_warning() {
    echo -e "\033[33m[WARNING]\033[0m $1"
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
    if docker compose version &> /dev/null; then
        local compose_version
        compose_version=$(docker compose version --short 2>/dev/null || echo "不明")
        print_info "Docker Compose は既にインストールされています: $compose_version"
        return 0
    else
        return 1
    fi
}

# Dockerのインストール
install_docker() {
    print_info "Dockerのインストールを開始します..."

    # Dockerがすでにインストールされているかチェック
    if check_docker_installed; then
        print_success "Dockerのインストールをスキップします"
        exit 0
    fi

    # Dockerの公式インストールスクリプトを実行
    print_info "Docker公式インストールスクリプトを詳細ログ付きで実行中..."
    print_info "Docker公式インストールスクリプトを詳細デバッグ出力付きで実行中..."
    if curl -fsSL https://get.docker.com | bash -x; then
        print_success "Dockerのインストールが完了しました"
    else
        print_error "Dockerのインストールに失敗しました"
        print_error "手動で以下のコマンドを実行してください："
        echo "  curl -fsSL https://get.docker.com | bash -x"
        exit 1
    fi

    # dockerグループが存在しない場合は作成し、ユーザーを追加
    if ! getent group docker > /dev/null; then
        print_info "dockerグループが存在しないため作成します..."
        sudo groupadd docker
    fi
    print_info "ユーザーをdockerグループに追加中..."
    sudo usermod -aG docker "$USER"

    # Dockerサービスの開始と有効化
    print_info "Dockerサービスを開始・有効化中..."
    sudo systemctl start docker
    sudo systemctl enable docker

    print_success "Dockerの設定が完了しました"
    print_warning "新しいグループ権限を有効にするため、以下のいずれかを実行してください："
    echo "  1. newgrp docker"
    echo "  2. ログアウト後、再ログイン"
    echo "  3. このスクリプトを再実行"
}

# Dockerの動作確認
verify_docker() {
    print_info "Dockerの動作を確認中..."

    if ! command -v docker &> /dev/null; then
        print_error "Dockerがインストールされていません"
        exit 1
    fi

    # Dockerデーモンが動作しているかチェック
    if ! docker info &> /dev/null; then
        print_error "Dockerデーモンが動作していないか、権限がありません"
        print_info "以下を確認してください："
        echo "  1. sudo systemctl start docker"
        echo "  2. sudo usermod -aG docker \$USER"
        echo "  3. newgrp docker または再ログイン"
        exit 1
    fi

    print_success "Dockerが正常に動作しています"
    exit 0
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
        exit 0
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
        exit 1
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
        exit 0
    else
        print_error "Docker Composeのインストール確認に失敗しました"
        exit 1
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
            if ! verify_docker; then
                print_warning "Dockerの権限設定のため、新しいシェルセッションが必要です"
                print_info "以下のコマンドを実行してください："
                echo "newgrp docker"
                echo "または、ログアウト後に再ログインしてください"
                echo ""
                local yn
                read -r -p "新しいグループ権限で続行しますか？ (y/n): " yn
                echo
                if [[ ! "$yn" =~ ^[Yy]$ ]]; then
                    print_info "スクリプトを終了します。権限設定後に再実行してください。"
                    exit 0
                fi
            fi
            verify_docker_compose
            ;;
        3)
            # 両方未インストール
            install_docker
            if ! verify_docker; then
                print_warning "Dockerの権限設定のため、新しいシェルセッションが必要です"
                print_info "以下のコマンドを実行してください："
                echo "newgrp docker"
                echo "または、ログアウト後に再ログインしてください"
                echo ""
                local yn
                read -r -p "新しいグループ権限で続行しますか？ (y/n): " yn
                echo
                if [[ ! "$yn" =~ ^[Yy]$ ]]; then
                    print_info "スクリプトを終了します。権限設定後に再実行してください。"
                    exit 0
                fi
            fi

            local latest_version
            latest_version=$(get_latest_version)
            print_info "最新バージョン: $latest_version"
            install_docker_compose "$latest_version" "$arch"
            verify_docker_compose
            ;;
    esac

    print_success "全ての処理が完了しました！"
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