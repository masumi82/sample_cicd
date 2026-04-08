# 動作確認記録 v10 — API Gateway + ElastiCache Redis + レート制限

## 概要

v10 デプロイ後の動作確認項目と結果を記録する。

## 確認項目

| # | 確認項目 | コマンド / 操作 | 期待結果 | 結果 |
|---|---------|---------------|---------|------|
| 1 | Terraform apply 成功 | `terraform apply -var-file=dev.tfvars` | Apply complete! Resources: ~20 added | - |
| 2 | API Gateway Invoke URL 取得 | `terraform output api_gateway_invoke_url` | URL が出力される | - |
| 3 | Redis Endpoint 取得 | `terraform output redis_endpoint` | エンドポイントアドレスが出力される | - |
| 4 | API キー付きリクエスト | `curl "${APIGW_URL}/tasks" -H "x-api-key: ${API_KEY}"` | 200 OK + JSON レスポンス | - |
| 5 | API キーなしリクエスト | `curl "${APIGW_URL}/tasks"` | 403 Forbidden | - |
| 6 | CloudFront 経由アクセス | `curl "${APP_URL}/tasks"` | 200 OK（API キー自動注入） | - |
| 7 | タスク作成 | `curl -X POST "${APP_URL}/tasks" ...` | 201 Created | - |
| 8 | キャッシュヒット確認 | CloudWatch CacheHitCount メトリクス | > 0 | - |
| 9 | キャッシュ無効化確認 | POST 後に GET → 新データ反映 | 最新データが返る | - |
| 10 | Redis CPU メトリクス | CloudWatch Dashboard Row 7 | メトリクスが表示される | - |
| 11 | API Gateway メトリクス | CloudWatch Dashboard Row 6 | Request Count が表示される | - |
| 12 | CI パイプライン成功 | GitHub Actions CI ワークフロー | 84 テスト PASS + lint 通過 | - |
| 13 | CD パイプライン成功 | GitHub Actions CD ワークフロー | デプロイ完了 | - |
| 14 | Web UI 動作確認 | ブラウザで APP_URL にアクセス | SPA が正常表示 | - |

## 備考

- 結果欄はデプロイ実施後に記入する
- 全項目 PASS で Phase 5 完了とする
