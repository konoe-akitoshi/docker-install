#!/bin/bash  
set -e  
  
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
    local arch=$(uname -m)  
    case $arch in  
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
  
# Dockerのインストール  
install_docker() {  
    print_info "Dockerのインストールを開始します..."  
      
    # Dockerがすでにインストールされているかチェック  
    if command -v docker &> /dev/null; then  
        print_info "Dockerは既にインストールされています"  
        return 0  
    fi  
      
    # Dockerの公式インストールスクリプトを実行  
    print_info "Docker公式インストールスクリプトを実行中..."  
    if curl -fsSL https://get.docker.com | sh; then  
        print_success "Dockerのインストールが完了しました"  
    else  
        print_error "Dockerのインストールに失敗しました"  
        exit 1  
    fi  
      
    # ユーザーをdockerグループに追加  
    print_info "ユーザーをdockerグループに追加中..."  
    sudo usermod -aG docker $USER  
      
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
        return 1  
    fi  
      
    # Dockerデーモンが動作しているかチェック  
    if ! docker info &> /dev/null; then  
        print_error "Dockerデーモンが動作していないか、権限がありません"  
        print_info "以下を確認してください："  
        echo "  1. sudo systemctl start docker"  
        echo "  2. sudo usermod -aG docker \$USER"  
        echo "  3. newgrp docker または再ログイン"  
        return 1  
    fi  
      
    print_success "Dockerが正常に動作しています"  
    return 0  
}  
  
# Docker Composeの最新バージョンを取得  
get_latest_version() {  
    print_info "Docker Composeの最新バージョンを取得中..."  
    local latest_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')  
    if [ -z "$latest_version" ]; then  
        print_error "最新バージョンの取得に失敗しました"  
        exit 1  
    fi  
    echo "$latest_version"  
}  
  
# Docker Composeをダウンロードしてインストール  
install_docker_compose() {  
    local version=$1  
    local arch=$2  
    local plugin_dir="$HOME/.docker/cli-plugins"  
    local binary_name="docker-compose"  
    local download_url="https://github.com/docker/compose/releases/download/${version}/docker-compose-${arch}"  
      
    print_info "Docker Compose ${version} をダウンロード中..."  
      
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
        local installed_version=$(docker compose version --short)  
        print_success "Docker Compose v2 が正常にインストールされました"  
        print_info "インストールされたバージョン: $installed_version"  
          
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
    print_info "macOSではDocker Desktopの使用を推奨します"  
    print_warning "Docker DesktopにはDocker Compose v2が含まれています"  
    echo ""  
    print_info "Docker Desktopのダウンロード："  
    echo "https://www.docker.com/products/docker-desktop/"  
    echo ""  
    read -p "Docker Desktopをインストール済みですか？ (y/n): " -n 1 -r  
    echo  
    if [[ $REPLY =~ ^[Yy]$ ]]; then  
        verify_docker_compose  
    else  
        print_info "Docker Desktopをインストールしてから再実行してください"  
        exit 1  
    fi  
}  
  
# メイン処理  
main() {  
    print_info "Docker & Docker Compose v2 完全インストールスクリプト開始"  
    echo "============================================================"  
      
    # OS検出  
    local os=$(detect_os)  
    print_info "検出されたOS: $os"  
      
    # macOSの場合は別処理  
    if [ "$os" = "macos" ]; then  
        handle_macos  
        return 0  
    fi  
      
    # Linux向けの処理  
    print_info "Linuxシステム向けのインストールを開始します"  
      
    # アーキテクチャの検出  
    local arch=$(detect_architecture)  
    print_info "検出されたアーキテクチャ: $arch"  
      
    # Dockerのインストール  
    install_docker  
      
    # Dockerの動作確認（失敗した場合は権限の問題の可能性）  
    if ! verify_docker; then  
        print_warning "Dockerの権限設定のため、新しいシェルセッションが必要です"  
        print_info "以下のコマンドを実行してください："  
        echo "newgrp docker"  
        echo "または、ログアウト後に再ログインしてください"  
        echo ""  
        read -p "新しいグループ権限で続行しますか？ (y/n): " -n 1 -r  
        echo  
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then  
            print_info "スクリプトを終了します。権限設定後に再実行してください。"  
            exit 0  
        fi  
    fi  
      
    # Docker Composeの最新バージョン取得  
    local latest_version=$(get_latest_version)  
    print_info "最新バージョン: $latest_version"  
      
    # Docker Composeのインストール  
    install_docker_compose "$latest_version" "$arch"  
      
    # インストール確認  
    if verify_docker_compose; then  
        print_success "全てのインストールが完了しました！"  
        echo ""  
        print_info "サンプルのcompose.yamlファイルを作成してテストできます："  
        echo "mkdir test-compose && cd test-compose"  
        echo "cat > compose.yaml << 'EOF'"  
        echo "services:"  
        echo "  hello-world:"  
        echo "    image: hello-world"  
        echo "EOF"  
        echo "docker compose up"  
    else  
        print_error "インストールに問題があります"  
        exit 1  
    fi  
}  
  
# スクリプト実行  
main "$@"
