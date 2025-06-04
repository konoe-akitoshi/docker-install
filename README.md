# Docker & Docker Compose v2 インストールスクリプト

このスクリプトは、Linux および macOS 環境で Docker と Docker Compose v2 を自動的にインストール・確認・設定するためのスマートスクリプトです。

---

## 特長

* **Docker / Docker Compose の検出・インストール**
* **最新の Docker Compose v2 を GitHub API から取得**
* **OS（Linux/macOS）とアーキテクチャ（x86\_64 / arm64 など）を自動判別**
* **色付きログ出力による分かりやすい進捗表示**
* **Docker グループへのユーザー追加、サービスの有効化まで対応**

---

## 対応環境

* Linux（Debian系 / Red Hat系など一般的なディストリビューション）
* macOS（Docker Desktop を利用）

---

## 使い方

```bash
curl -fsSL https://raw.githubusercontent.com/konoe-akitoshi/docker-install/main/install-dockercompose.sh | bash
```

または、ダウンロードして実行：

```bash
wget https://raw.githubusercontent.com/konoe-akitoshi/docker-install/main/install-dockercompose.sh
chmod +x install-dockercompose.sh
./install-dockercompose.sh
```

---

## スクリプトの処理内容

1. **OSとアーキテクチャの自動検出**
2. **DockerとDocker Composeのインストール状況確認**
3. **未インストールの場合は自動でインストールを実施**
4. **Dockerグループへのユーザー追加とサービス有効化**
5. **Docker Composeの最新バージョンをGitHubから取得してインストール**
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

* 初回実行後は、**新しいグループ権限を反映するためにログアウトまたは `newgrp docker` の実行が必要**です。
* macOS の場合は **Docker Desktop のインストールが前提**です。

---

## ライセンス

MIT License
