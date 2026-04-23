# Docker & Docker Compose v2 インストールスクリプト

Linux および macOS 環境で Docker と Docker Compose v2 を自動的にインストール・確認・設定するためのスクリプトです。

---

## 特長

* **Docker / Docker Compose の検出・インストール**
* **OS（Linux/macOS）とアーキテクチャ（x86\_64 / arm64 など）を自動判別**
* **get.docker.com による公式インストール（Compose プラグイン含む）**
* **get.docker.com で Compose が入らなかった場合は GitHub から最新版を自動取得**
* **Docker グループへのユーザー追加、containerd サービスの有効化まで対応**
* **色付きログ出力による分かりやすい進捗表示**

---

## 対応環境

* Linux（Debian系 / Red Hat系など一般的なディストリビューション）
* macOS（Docker Desktop を利用）

---

## 使い方

### Linux

root 権限で実行してください。

```bash
curl -fsSL https://raw.githubusercontent.com/konoe-akitoshi/docker-install/main/install-dockercompose.sh | sudo bash
```

または、ダウンロードして実行：

```bash
wget https://raw.githubusercontent.com/konoe-akitoshi/docker-install/main/install-dockercompose.sh
chmod +x install-dockercompose.sh
sudo ./install-dockercompose.sh
```

### macOS

Docker Desktop の案内のみなので root 権限は不要です。

```bash
./install-dockercompose.sh
```

---

## スクリプトの処理内容

1. **OS とアーキテクチャの自動検出**
2. **Docker と Docker Compose のインストール状況確認**
3. **未インストールの場合は get.docker.com 経由で Docker をインストール**
4. **Docker グループへの実ユーザー追加と containerd サービスの有効化**
5. **Docker Compose が未インストールの場合は GitHub から最新版を取得してシステムワイドに配置**
6. **インストール後の動作確認とサンプル使用例の表示**

---

## サンプル `compose.yaml` の作成とテスト

```bash
mkdir test-compose && cd test-compose
cat > compose.yaml << 'EOF'
services:
  hello-world:
    image: hello-world
EOF

docker compose up
```

---

## 注意点

* Linux では **`sudo` で実行**してください。root 権限がない場合はエラーで終了します。
* 初回実行後は、**新しいグループ権限を反映するためにログアウトまたは `newgrp docker` の実行が必要**です。
* macOS の場合は **Docker Desktop のインストールが前提**です。

---

## ライセンス

MIT License
