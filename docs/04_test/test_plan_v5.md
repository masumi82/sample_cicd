# テスト計画書 v5 — ファイル添付機能

## 1. テスト目的

v5 で追加したファイル添付機能（S3 Presigned URL + CloudFront + スキーマバリデーション）が正しく動作することを確認する。
また、v4 までの既存テスト（TC-01〜TC-23）が引き続き全件 PASS することを確認する。

---

## 2. テスト範囲

| 対象 | 内容 |
|------|------|
| `app/routers/attachments.py` | 添付ファイル CRUD エンドポイント（4 個） |
| `app/services/storage.py` | S3 Presigned URL 生成 + オブジェクト削除 |
| `app/schemas.py` | `AttachmentCreate` のファイル名サニタイズバリデータ |
| `app/routers/tasks.py` | タスク削除時の S3 オブジェクト一括削除 |
| 既存テスト (TC-01〜TC-23) | リグレッション確認 |

---

## 3. テスト環境

| 項目 | 値 |
|------|----|
| 実行環境 | ローカル / GitHub Actions |
| Python | 3.12 |
| テストフレームワーク | pytest |
| DB | SQLite in-memory（conftest.py で設定済み） |
| AWS モック | moto 5.x（`mock_aws`）+ `unittest.mock.patch` |

### 依存パッケージ（テスト実行時に追加インストール）

```bash
pip install -r app/requirements.txt
pip install ruff pytest httpx "moto[sqs,events,s3]"
```

### AWS 認証情報（moto 使用時）

moto は実際の AWS 接続を行わないため、ダミー認証情報を環境変数でセットする。
`aws_credentials` pytest fixture（conftest.py で定義済み）にて設定する。

---

## 4. テストケース一覧

### 4.1 リグレッションテスト（TC-01〜TC-23）

| TC | テスト内容 | ファイル | 期待結果 |
|----|-----------|---------|---------|
| TC-01〜TC-06 | Hello World / health check | `tests/test_main.py` | PASS |
| TC-07〜TC-18 | タスク CRUD 全件 | `tests/test_tasks.py` | PASS |
| TC-19〜TC-23 | SQS / EventBridge イベント | `tests/test_tasks.py` | PASS |

> v5 追加後も S3_BUCKET_NAME が未設定であれば S3 関連処理はスキップされるため、
> 既存テストへの影響はない。

### 4.2 v5 新規テスト（TC-24〜TC-39）

#### TC-24: 添付ファイル作成 — Presigned URL 生成成功

| 項目 | 内容 |
|------|------|
| テスト対象 | `POST /tasks/{task_id}/attachments` |
| 前提条件 | `S3_BUCKET_NAME` をモックバケット名にセット、moto S3 でバケット作成済み |
| モック手法 | `moto mock_aws` — boto3 の S3 呼び出しを moto が代替 |
| 操作 | タスク作成後、`POST /tasks/{id}/attachments {"filename": "test.pdf", "content_type": "application/pdf"}` |
| 確認内容 | レスポンス 201、`upload_url` が空でないこと、DB に Attachment レコードが作成されていること |
| 確認項目 | `id` が正の整数、`filename == "test.pdf"`、`upload_url` が `http` で始まること |

#### TC-25: 添付ファイル作成 — 存在しないタスク

| 項目 | 内容 |
|------|------|
| テスト対象 | `POST /tasks/9999/attachments` |
| 前提条件 | task_id=9999 のタスクが存在しない |
| 確認内容 | レスポンス 404、`detail == "Task not found"` |

#### TC-26: 添付ファイル作成 — 許可されていない content_type

| 項目 | 内容 |
|------|------|
| テスト対象 | `POST /tasks/{id}/attachments` |
| 前提条件 | `S3_BUCKET_NAME` セット済み |
| 操作 | `{"filename": "test.exe", "content_type": "application/x-msdownload"}` |
| 確認内容 | レスポンス 422、`detail` に "not allowed" が含まれること |

#### TC-27: 添付ファイル作成 — S3_BUCKET_NAME 未設定

| 項目 | 内容 |
|------|------|
| テスト対象 | `POST /tasks/{id}/attachments` |
| 前提条件 | `S3_BUCKET_NAME` 環境変数が未設定 |
| 確認内容 | レスポンス 503、`detail == "Storage service not configured"` |

#### TC-28: 添付ファイル一覧 — 空リスト

| 項目 | 内容 |
|------|------|
| テスト対象 | `GET /tasks/{id}/attachments` |
| 前提条件 | タスクに添付ファイルなし |
| 確認内容 | レスポンス 200、空の配列 `[]` |

#### TC-29: 添付ファイル一覧 — 複数件

| 項目 | 内容 |
|------|------|
| テスト対象 | `GET /tasks/{id}/attachments` |
| 前提条件 | タスクに 2 件の添付ファイルを作成済み |
| 確認内容 | レスポンス 200、配列の長さが 2 |

#### TC-30: 添付ファイル一覧 — 存在しないタスク

| 項目 | 内容 |
|------|------|
| テスト対象 | `GET /tasks/9999/attachments` |
| 確認内容 | レスポンス 404 |

#### TC-31: 添付ファイル取得 — CloudFront ダウンロード URL 付き

| 項目 | 内容 |
|------|------|
| テスト対象 | `GET /tasks/{id}/attachments/{attachment_id}` |
| 前提条件 | 添付ファイル作成済み、`CLOUDFRONT_DOMAIN_NAME=d123.cloudfront.net` をセット |
| 確認内容 | レスポンス 200、`download_url` が `https://d123.cloudfront.net/` で始まること |
| 確認項目 | `download_url` に S3 キーが含まれること |

#### TC-32: 添付ファイル取得 — CLOUDFRONT_DOMAIN_NAME 未設定

| 項目 | 内容 |
|------|------|
| テスト対象 | `GET /tasks/{id}/attachments/{attachment_id}` |
| 前提条件 | `CLOUDFRONT_DOMAIN_NAME` 環境変数が未設定 |
| 確認内容 | レスポンス 200、`download_url == ""` |

#### TC-33: 添付ファイル取得 — 存在しない添付

| 項目 | 内容 |
|------|------|
| テスト対象 | `GET /tasks/{id}/attachments/9999` |
| 確認内容 | レスポンス 404、`detail == "Attachment not found"` |

#### TC-34: 添付ファイル取得 — 別タスクの添付 ID

| 項目 | 内容 |
|------|------|
| テスト対象 | `GET /tasks/{task_A}/attachments/{attachment_of_task_B}` |
| 前提条件 | タスク A とタスク B を作成、添付はタスク B にのみ作成 |
| 確認内容 | レスポンス 404（task_id と attachment の task_id が不一致） |

#### TC-35: 添付ファイル削除 — 正常削除

| 項目 | 内容 |
|------|------|
| テスト対象 | `DELETE /tasks/{id}/attachments/{attachment_id}` |
| 前提条件 | 添付ファイル作成済み |
| モック手法 | `unittest.mock.patch("app.routers.attachments.delete_object")` |
| 確認内容 | レスポンス 204、`delete_object` が呼び出されたこと、DB からレコードが削除されていること |

#### TC-36: 添付ファイル削除 — 存在しない添付

| 項目 | 内容 |
|------|------|
| テスト対象 | `DELETE /tasks/{id}/attachments/9999` |
| 確認内容 | レスポンス 404 |

#### TC-37: タスク削除時の S3 オブジェクト一括削除

| 項目 | 内容 |
|------|------|
| テスト対象 | `DELETE /tasks/{id}` |
| 前提条件 | タスクに添付ファイル 2 件作成済み、`S3_BUCKET_NAME` セット済み |
| モック手法 | `unittest.mock.patch("app.routers.tasks.delete_object")` |
| 確認内容 | レスポンス 204、`delete_object` が 2 回呼び出されたこと |

#### TC-38: ファイル名サニタイズ — パストラバーサル等の除去

| 項目 | 内容 |
|------|------|
| テスト対象 | `AttachmentCreate` Pydantic バリデータ |
| モック | 不要（スキーマ検証のみ） |
| 操作 | 各種危険なファイル名でインスタンス生成 |
| 確認内容 | `../` → `_`、`/` → `_`、`\` → `_`、`<>` → `_` に置換されること |

#### TC-39: ファイル名サニタイズ — 空文字化で ValueError

| 項目 | 内容 |
|------|------|
| テスト対象 | `AttachmentCreate` Pydantic バリデータ |
| 操作 | `filename="..."` （サニタイズ後に空文字になるケース） |
| 確認内容 | `ValidationError` が発生すること |

---

## 5. テスト実行手順

```bash
# プロジェクトルートから実行
cd /home/m-horiuchi/sample_cicd

# 依存インストール
pip install -r app/requirements.txt
pip install ruff pytest httpx "moto[sqs,events,s3]"

# lint
ruff check app/ tests/ lambda/

# 全テスト実行（既存 + v5 追加）
DATABASE_URL=sqlite:// pytest tests/ -v

# v5 テストのみ実行
DATABASE_URL=sqlite:// pytest tests/test_attachments.py -v
```

---

## 6. 合格基準

| 確認項目 | 基準 |
|---------|------|
| TC-01〜TC-23（既存） | 全件 PASS |
| TC-24〜TC-39（v5 新規） | 全件 PASS |
| ruff lint | エラーなし |
| `terraform validate` | OK（実装フェーズ確認済み） |
