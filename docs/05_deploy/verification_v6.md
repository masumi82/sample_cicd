# 動作確認記録 (v6)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-07 |
| バージョン | 6.0 |
| 前バージョン | [verification_v5.md](verification_v5.md) (v5.0) |

## 1. 確認概要

本ドキュメントは `deploy_procedure_v6.md` に従ってデプロイを実施した後の動作確認記録である。
各項目を実施し、結果を記録する。

v6 では以下の機能が追加される:
- **構造化ログ**: FastAPI + Lambda の JSON 形式ログ出力
- **X-Ray 分散トレーシング**: ECS サイドカー + Lambda Active tracing
- **CloudWatch Dashboard**: 12 ウィジェットによる統合監視
- **CloudWatch Alarms**: 12 アラーム + SNS 通知
- **Web UI**: React SPA on S3 + CloudFront

## 2. 環境情報

| 項目 | 値 |
|------|------|
| AWS アカウント ID | （セキュリティのため省略） |
| AWS リージョン | ap-northeast-1 |
| Terraform Workspace | dev |
| ALB DNS 名 | terraform output alb_dns_name で確認済み |
| Web UI CloudFront ドメイン名 | dXXXXXXXXXXXXX.cloudfront.net |
| Web UI CloudFront ディストリビューション ID | terraform output で確認済み |
| CloudWatch Dashboard URL | terraform output dashboard_url で確認済み |
| SNS Topic ARN | terraform output sns_topic_arn で確認済み |
| 実施日 | 2026-04-07 |
| 実施者 | m-horiuchi |

## 3. コミット・プッシュ / CI パイプライン

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | git commit 成功 | `git log --oneline -1` | v6 コミットが最新 | PASS | |
| 2 | git push 成功 | `git push origin main` の出力 | エラーなし | PASS | |
| 3 | CI: ruff lint PASS | `gh run view --log \| grep ruff` | All checks passed | PASS | |
| 4 | CI: pytest 54 件 PASS | `gh run view --log \| grep "passed"` | 54 passed | PASS | |
| 5 | CI: docker build 成功 | `gh run view --log \| grep "docker build"` | Build 成功 | PASS | |
| 6 | CI: npm build 成功 | `gh run view --log \| grep "npm run build"` | ✓ built | PASS | |

## 4. Terraform apply

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 7 | Workspace 確認 | `terraform workspace show` | `dev` | PASS | |
| 8 | terraform plan 確認 | `terraform plan -var-file=dev.tfvars` | 追加リソースが計画に含まれる | PASS | |
| 9 | terraform apply 成功 | `terraform apply -var-file=dev.tfvars` | "Apply complete!" | PASS | Secrets Manager 競合・Lambda Layer ARN 修正後に成功 |
| 10 | Dashboard URL 出力 | `terraform output dashboard_url` | URL が出力される | PASS | |
| 11 | Web UI CloudFront 出力 | `terraform output webui_cloudfront_domain_name` | ドメイン名が出力される | PASS | dXXXXXXXXXXXXX.cloudfront.net |

## 5. CloudWatch Dashboard 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 12 | Dashboard 存在確認 | `aws cloudwatch list-dashboards --query 'DashboardEntries[*].DashboardName'` | `sample-cicd-dev` が含まれる | PASS | |
| 13 | Dashboard 表示確認 | ブラウザで dashboard_url を開く | ALB/ECS/RDS/Lambda/SQS ウィジェットが表示される | PASS | |

## 6. CloudWatch Alarms 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 14 | アラーム件数確認 | `aws cloudwatch describe-alarms --alarm-name-prefix sample-cicd-dev --query 'length(MetricAlarms)'` | `12` | PASS | |
| 15 | アラーム状態確認 | `aws cloudwatch describe-alarms --alarm-name-prefix sample-cicd-dev --query 'MetricAlarms[*].[AlarmName,StateValue]' --output table` | 大部分が OK or INSUFFICIENT_DATA | PASS | 低負荷のため INSUFFICIENT_DATA が大半 |

## 7. SNS Topic 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 16 | SNS Topic 存在確認 | `aws sns list-topics --query 'Topics[?contains(TopicArn, \`sample-cicd-dev\`)]'` | ARN が返る | PASS | |

## 8. CD パイプライン確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 17 | CD: ECS ローリングデプロイ成功 | `gh run view --log \| grep "ECS"` | "Service updated" | PASS | |
| 18 | CD: Lambda 更新成功 | `gh run view --log \| grep "lambda"` | 3 関数の更新成功 | PASS | |
| 19 | CD: フロントエンド S3 sync 成功 | `gh run view --log \| grep "s3 sync"` | "upload:" ログが出力 | PASS | |
| 20 | CD: CloudFront invalidation 成功 | `gh run view --log \| grep "invalidation"` | invalidation ID が出力 | PASS | |
| 21 | Web UI S3 バケット内容確認 | `aws s3 ls s3://sample-cicd-dev-webui/` | index.html, config.js, assets/ が存在 | PASS | |

## 9. 構造化ログ確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 22 | ECS ログが JSON 形式 | `aws logs filter-log-events --log-group-name /ecs/sample-cicd-dev --limit 3 --query 'events[*].message' --output text` | `{"timestamp":...,"level":...}` 形式 | PASS | |
| 23 | Lambda ログが JSON 形式 | `aws logs filter-log-events --log-group-name /aws/lambda/sample-cicd-dev-task-created --limit 3 --query 'events[*].message' --output text` | JSON 形式 | PASS | |

## 10. X-Ray 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 24 | X-Ray daemon ログ確認 | `aws logs filter-log-events --log-group-name /ecs/sample-cicd-dev-xray --limit 5 --query 'events[*].message' --output text` | daemon 起動ログが出力 | PASS | 169.254.169.254 エラーは Fargate 環境で想定内（非致命的） |
| 25 | X-Ray トレース確認 | AWS コンソール → X-Ray → Service Map | ECS サービス → RDS のトレースが表示される | PASS | |

## 11. Web UI 動作確認

以下の操作を `https://<webui_cloudfront_domain_name>` にブラウザでアクセスして確認する。

| # | 確認項目 | 操作 | 期待結果 | 結果 | 備考 |
|---|---------|------|---------|------|------|
| 26 | Web UI アクセス | ブラウザで CloudFront URL を開く | タスク一覧画面が表示される | PASS | demo.gif で記録済み |
| 27 | タスク作成 | 「New Task」ボタン → タイトル入力 → 「Create Task」 | タスクが作成され、詳細画面に遷移 | PASS | demo.gif で記録済み |
| 28 | タスク一覧表示 | ホームに戻る | 作成したタスクが一覧に表示される | PASS | demo.gif で記録済み |
| 29 | タスク編集 | 「Edit」ボタン → タイトル変更 → 「Save Changes」 | タイトルが更新される | PASS | |
| 30 | タスク完了切替 | 「Mark Complete」ボタン | バッジが「Completed」になる | PASS | demo.gif で記録済み |
| 31 | フィルタ動作 | 「Completed」タブをクリック | 完了済みタスクのみ表示される | PASS | demo.gif で記録済み |
| 32 | 添付ファイルアップロード | 「Upload File」→ PDF ファイル選択 | ファイルリストに表示される | PASS | |
| 33 | 添付ファイルダウンロード | 「Download」ボタン | ファイルがダウンロードされる | PASS | |
| 34 | 添付ファイル削除 | 「Delete」ボタン → 確認 | ファイルリストから削除される | PASS | |
| 35 | タスク削除 | 「Delete」ボタン → 確認 | 一覧から削除される | PASS | |
| 36 | SPA ルーティング | `/tasks/1` などのURLに直接アクセス | 404 にならず正しい画面が表示される | PASS | CloudFront 403/404 → index.html フォールバック |

## 12. 確認結果サマリ

| カテゴリ | 確認件数 | PASS | FAIL | 備考 |
|---------|---------|------|------|------|
| CI/CD パイプライン | 6 | 6 | 0 | |
| Terraform apply | 5 | 5 | 0 | |
| CloudWatch Dashboard | 2 | 2 | 0 | |
| CloudWatch Alarms | 2 | 2 | 0 | |
| SNS Topic | 1 | 1 | 0 | |
| CD パイプライン | 5 | 5 | 0 | |
| 構造化ログ | 2 | 2 | 0 | |
| X-Ray | 2 | 2 | 0 | |
| Web UI 動作 | 11 | 11 | 0 | |
| **合計** | **36** | **36** | **0** | **全項目 PASS** |
