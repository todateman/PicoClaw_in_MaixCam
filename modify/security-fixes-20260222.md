# PicoClaw セキュリティ修正記録

**実施日**: 2026-02-22
**参考記事**: https://qiita.com/myougaTheAxo-VT/items/e69207396276ab7704eb
**対象**: MaixCAM上のPicoClaw v0.1.2

---

## 発見された脆弱性と対応状況

### 1. 設定ファイルのパーミッション問題 ✅ 修正済み

**問題**: ワークスペース内のファイルが `0644`（全ユーザー読み取り可能）で作成されていた。
セッション履歴・メモリ・ステートなどが第三者に読まれる可能性があった。

**MaixCAM上の修正内容**:
```bash
# バイナリ権限を 711→700 に変更
chmod 700 /root/picoclaw

# ワークスペース全ファイルを 600 に変更
find /root/.picoclaw/workspace -type f ! -name "*.sh" ! -name "*.py" -exec chmod 600 {} \;
find /root/.picoclaw/workspace -type f -name "*.sh" -exec chmod 700 {} \;
find /root/.picoclaw/workspace -type f -name "*.py" -exec chmod 700 {} \;
```

**残存リスク**: PicoClaw が内部的に新規ファイルを `0644` で書き込む実装（`filesystem.go:184` の WriteFileTool、セッションマネージャ等）は修正されていない。PicoClaw 起動後に新規作成されたファイルは再度 `chmod 600` が必要。

**恒久対策スクリプト**: `fix-permissions.sh` を参照。

---

### 2. Slackアクセス制御バイパス ⚠️ 非該当（Slack無効）

**問題**: `allow_from` が空の場合、ワークスペース内の全ユーザーがBotを操作可能になる。
`base.go` の `IsAllowed()` で空リストは全許可として扱われる。

**MaixCAM上の状況**: Slack チャネルは `enabled: false` のため現時点では非該当。
Slack を有効化する際は必ず `allow_from` にユーザーIDを設定すること。

---

### 3. cronジョブのパス制限突破 ⚠️ 部分対応

**問題**: ExecTool の `working_dir` パラメータでワークスペース外のディレクトリを指定すると、
`restrict_to_workspace: true` の設定を迂回してコマンド実行できる。

**MaixCAM上の状況**: `restrict_to_workspace: true` は設定済み。
デフォルト拒否パターンも有効（`enable_deny_patterns: true`）。

**設定で確認済み**:
```json
"agents": {
  "defaults": {
    "restrict_to_workspace": true
  }
},
"tools": {
  "exec": {
    "enable_deny_patterns": true
  }
}
```

**残存リスク**: `working_dir` による迂回は `shell.go` のコード修正が必要。バイナリ更新まで
デフォルト拒否パターンで一定の緩和は可能だが根本解決ではない。

---

### 4. cronジョブのストアファイル破損 ✅ 修正済み

**問題**: `cron/jobs.json` が全 null バイト（1291 bytes of `\x00`）で破損していた。

**修正内容**:
```bash
printf '{"version":1,"jobs":[]}' > /root/.picoclaw/workspace/cron/jobs.json
chmod 600 /root/.picoclaw/workspace/cron/jobs.json
```

---

### 5. MaixCAMチャネルのallow_from設定 ✅ 設定済み

**問題**: `allow_from: []`（空）でTCPポート18790に接続した全クライアントが
ボットを操作できる状態だった。

**修正内容**:
```json
"maixcam": {
  "enabled": true,
  "host": "0.0.0.0",
  "port": 18790,
  "allow_from": ["maixcam"]
}
```

**備考**: MaixCAMチャネルのsenderIDはコード内で `"maixcam"` にハードコードされているため、
`allow_from: ["maixcam"]` でのフィルタリングは同じsenderIDを持つ外部クライアントには
有効でない（IPベースの認証が必要）。Tailscale経由のネットワーク隔離が主要な防御層。

---

## 再現スクリプト

新しい MaixCAM に同じ設定を適用する場合:

```bash
ssh MaixCAM 'bash -s' < fix-permissions.sh
```

---

## 確認済み最終状態（2026-02-22）

| 項目 | 状態 |
|------|------|
| バイナリ権限 | `-rwx------` (700) ✅ |
| config.json | `-rw-------` (600) ✅ |
| workspace/*.md | `-rw-------` (600) ✅ |
| workspace/sessions/*.json | `-rw-------` (600) ✅ |
| workspace/memory/*.md | `-rw-------` (600) ✅ |
| workspace/state/state.json | `-rw-------` (600) ✅ |
| workspace/cron/jobs.json | `-rw-------` (600) ✅ |
| Discord allow_from | `["1313251908495872032"]` ✅ |
| MaixCAM allow_from | `["maixcam"]` ✅ |
| restrict_to_workspace | `true` ✅ |
| enable_deny_patterns | `true` ✅ |
