# PicoClaw in MaixCAM

## このプロジェクトの目的

あなたは優秀なエッジコンピュータサイエンティストです。  
SipeedのMaixCAMにsshで接続し、MaixCAMにインストールしたPicoClawを効率的に設定します。  
なお、ユーザーとのチャットでは日本語でコミュニケーションをとります。  
手を加えた内容は別のMaixCAMでも再現できるように、 ./modify/ のディレクトリの中にドキュメントや作成したスクリプトを保存します。

## MaixCAM について

- 最新のリポジトリは ./MaixPy/ を参照

- 最新のドキュメントは <https://wiki.sipeed.com/hardware/en/maixcam/maixcam.html> ならびに <https://wiki.sipeed.com/maixpy/doc/en/index.html> を参照

## MaixCAMのターミナル接続方法

- 以下のコマンドでMaixCAMにssh接続する。  
既にホストPCの`.ssh/config`には、Tailscale経由で接続するための設定が済ませてある。  
なお、MaixCAMのユーザーは`root`である。

```bash
# .ssh/config で設定済みの公開鍵認証方法の接続
ssh MaixCAM

# 下記コマンドではパスワードが必要なので煩雑
ssh root@<MaixCAMのIP>
```

- ssh接続の簡略化（Claude Codeがssh接続するたびにパスワードを人間が入力するのを避ける）のため、事前に公開鍵をMaixCAMに転送しておく。  
これはセキュリティ確保のため、Claudeではなくユーザー自身が行う。  
Claude Codeはユーザーにこの手順を実行することを促す。

  - ホストがWindowsの場合

  ```powershell
  type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@MaixCAMのIPアドレス "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
  ```

  - ホストがLinuxの場合

  ```bash
  ssh-copy-id -i ~/.ssh/id_ed25519.pub root@<MaixCAMのIP>
  ```

## PicoClaw について

- 最新のリポジトリは ./picoclaw/ を参照
- 最新のドキュメントは ./picoclaw/README.md を参照
- 標準のワークスペース内の構造は ./picoclaw/workspace ならびに MaixCAM内の `/root/.picoclaw/workspace` を参照する。
- ユーザーとは日本語でコミュニケーションするが、PicoClaw内の `AGENT` や `SKILL` は英語で作成し処理負荷を軽減する。

## MaixCAM 現在の状態（2026-02-20 確認）

### システム

- **OS**: Linux maixcam-526b 5.10.4-tag- (RISC-V 64-bit)
- **PicoClaw**: v0.1.2 / Go 1.25.7
- **バイナリ**: `/root/picoclaw`（PATHには未追加）

### SSH接続の注意

- MaixCAMのSSH応答が遅い場合がある（Tailscale経由）
- タイムアウトを長めに設定すること: `ssh -o ConnectTimeout=90 MaixCAM`

### 設定 (`~/.picoclaw/config.json`)

- **プロバイダー**: OpenRouter（APIキー設定済）
- **モデル**: 空欄（OpenRouterデフォルト）
- **有効チャンネル**: Discord、MaixCAM (port 18790)
- **Web検索**: Brave + DuckDuckGo 有効
- **Heartbeat**: 有効（約30分間隔）、`~/.picoclaw/workspace/heartbeat.log` に記録

### ワークスペース (`~/.picoclaw/workspace/`)

- **スキル**: `github`, `hardware`, `skill-creator`, `summarize`, `tmux`, `weather`
- **Cronジョブ**: `cron/jobs.json`
