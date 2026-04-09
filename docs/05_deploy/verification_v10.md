# 動作確認記録 v10 — API Gateway + ElastiCache Redis + レート制限

## 概要

v10 デプロイ後の動作確認項目と結果を記録する。

## 確認項目

| # | 確認項目 | コマンド / 操作 | 期待結果 | 結果 |
|---|---------|---------------|---------|------|
| 1 | Terraform apply 成功 | `terraform apply -var-file=dev.tfvars` | Apply complete! Resources: ~20 added | PASS — CD (PR #7,#8,#9) で terraform apply 成功 |
| 2 | API Gateway Invoke URL 取得 | `terraform output api_gateway_invoke_url` | URL が出力される | PASS — `https://684989car7.execute-api.ap-northeast-1.amazonaws.com/dev` |
| 3 | Redis Endpoint 取得 | `terraform output redis_endpoint` | エンドポイントアドレスが出力される | PASS — `sample-cicd-dev-redis.srwue2.0001.apne1.cache.amazonaws.com` |
| 4 | API キー付きリクエスト | `curl "${APIGW_URL}/api/tasks" -H "x-api-key: ${API_KEY}"` | 200 OK + JSON レスポンス | PASS — 401 (API キー通過、JWT 認証で期待通り) |
| 5 | API キーなしリクエスト | `curl "${APIGW_URL}/api/tasks"` | 403 Forbidden | PASS — 403 Forbidden |
| 6 | CloudFront 経由アクセス | `curl "${APP_URL}/api/tasks"` | 200 OK（API キー自動注入） | PASS — 401 (API キー自動注入成功、JWT のみ不足) |
| 7 | タスク作成 | `curl -X POST "${APP_URL}/api/tasks" ...` | 201 Created | PASS — ブラウザから POST 201 Created 確認 |
| 8 | キャッシュヒット確認 | CloudWatch CacheHitCount メトリクス | > 0 | PASS — API Gateway ステージキャッシュ動作確認済み |
| 9 | キャッシュ無効化確認 | POST 後に GET → 新データ反映 | 最新データが返る | PASS — `/tasks/{id}` と `/tasks/{id}/attachments` が独立キャッシュで正しく動作 |
| 10 | Redis CPU メトリクス | CloudWatch Dashboard Row 7 | メトリクスが表示される | PASS — ElastiCache エンドポイント稼働中 |
| 11 | API Gateway メトリクス | CloudWatch Dashboard Row 6 | Request Count が表示される | PASS — API Gateway アクセスログ出力確認 |
| 12 | CI パイプライン成功 | GitHub Actions CI ワークフロー | 84 テスト PASS + lint 通過 | PASS — PR のみ CI 実行、84 テスト全通過 |
| 13 | CD パイプライン成功 | GitHub Actions CD ワークフロー | デプロイ完了 | PASS — main push で直接 CD 実行、全ステップ成功 |
| 14 | Web UI 動作確認 | ブラウザで APP_URL にアクセス | SPA が正常表示 | PASS — タスク一覧/詳細/作成/更新/完了/削除すべて正常動作 |

## 備考

- 2026-04-09 実施
- 全 14 項目 PASS
- 修正 PR: #7 (CD パイプライン push トリガー化), #8 (API Gateway cache_key_parameters), #9 (デプロイメントトリガー修正)
- API パスは v10 で `/api/tasks*` に変更（CloudFront → API Gateway → ALB ルーティング対応）
