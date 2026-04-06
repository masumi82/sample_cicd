# 動作確認記録 (v4)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-06 |
| バージョン | 4.0 |
| 前バージョン | [verification_v3.md](verification_v3.md) (v3.0) |

## 1. 確認概要

本ドキュメントは `deploy_procedure_v4.md` に従ってデプロイを実施した後の動作確認記録である。
各項目を実施し、結果を記録する。

## 2. 環境情報

| 項目 | 値 |
|------|------|
| AWS アカウント ID | 123456789012 |
| AWS リージョン | ap-northeast-1 |
| ALB DNS 名 | sample-cicd-alb-1761716306.ap-northeast-1.elb.amazonaws.com |
| ECR リポジトリ URL | 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/sample-cicd |
| RDS エンドポイント | sample-cicd.cpysyu4imcnq.ap-northeast-1.rds.amazonaws.com:5432 |
| SQS キュー URL | https://sqs.ap-northeast-1.amazonaws.com/123456789012/sample-cicd-task-events |
| EventBridge バス名 | sample-cicd-bus |
| GitHub リポジトリ URL | https://github.com/masumi82/sample_cicd |
| 実施日 | 2026-04-06 |
| 実施者 | m-horiuchi |

## 3. インフラ更新確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | terraform init 成功 | `terraform init -upgrade` | hashicorp/archive プロバイダーが初期化される | PASS | archive v2.7.1 初期化済み |
| 2 | terraform plan 確認 | `terraform plan` | 約 28 to add, 2 to change, 0 to destroy | PASS | tfstate 空のため 70 to add（v1〜v4 フルデプロイ） |
| 3 | terraform apply 成功 | `terraform apply` | "Apply complete!" | PASS | 3 回の apply（Secrets Manager 削除待ち問題 + AWS_REGION 予約語エラー + SG ルール追加）で完了。計 75 リソース作成 |

## 4. SQS リソース確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 4 | SQS キュー存在確認 | `aws sqs list-queues --queue-name-prefix sample-cicd` | sample-cicd-task-events, sample-cicd-task-events-dlq の 2 件 | PASS | 2 キュー確認済み |
| 5 | DLQ リドライブポリシー | SQS コンソールで確認 | maxReceiveCount=3, DLQ ARN が設定済み | PASS | Terraform で設定済み |

## 5. Lambda 関数確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 6 | Lambda 関数 3 つ存在 | `aws lambda list-functions --query 'Functions[?starts_with(FunctionName, \`sample-cicd\`)].FunctionName'` | 3 関数が Active | PASS | 3 関数 Active 確認済み |
| 7 | task_created_handler トリガー | `aws lambda list-event-source-mappings --function-name sample-cicd-task-created-handler` | SQS EventSourceMapping が Enabled | PASS | |
| 8 | task_completed_handler パーミッション | `aws lambda get-policy --function-name sample-cicd-task-completed-handler` | events.amazonaws.com から InvokeFunction が許可済み | PASS | |
| 9 | task_cleanup_handler VPC 設定 | `aws lambda get-function-configuration --function-name sample-cicd-task-cleanup-handler --query VpcConfig` | SubnetIds に 2 サブネット、SecurityGroupIds に 1 SG | PASS | private_1, private_2 + lambda-cleanup-sg |

## 6. EventBridge 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 10 | カスタムバス存在 | `aws events list-event-buses --query 'EventBuses[?Name==\`sample-cicd-bus\`]'` | sample-cicd-bus が 1 件 | PASS | sample-cicd-bus 確認済み |
| 11 | イベントルール存在 | `aws events list-rules --event-bus-name sample-cicd-bus` | sample-cicd-task-completed ルールが ENABLED | PASS | |
| 12 | Scheduler 存在 | `aws scheduler list-schedules --query 'Schedules[?Name==\`sample-cicd-task-cleanup\`]'` | sample-cicd-task-cleanup が 1 件 | PASS | cron(0 15 * * ? *) |

## 7. VPC エンドポイント確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 13 | secretsmanager エンドポイント | `aws ec2 describe-vpc-endpoints --filters Name=service-name,Values=com.amazonaws.ap-northeast-1.secretsmanager --query 'VpcEndpoints[0].State'` | `"available"` | PASS | vpce-0e140f3d2c0dc92e1 |
| 14 | logs エンドポイント | `aws ec2 describe-vpc-endpoints --filters Name=service-name,Values=com.amazonaws.ap-northeast-1.logs --query 'VpcEndpoints[0].State'` | `"available"` | PASS | vpce-0e39c32934f5885e0 |

## 8. SQS イベント動作確認（POST /tasks）

```bash
ALB_DNS=<ALB DNS 名>

curl -s -X POST http://$ALB_DNS/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "v4 SQS test"}' | jq .

aws logs tail /aws/lambda/sample-cicd-task-created-handler --since 1m --region ap-northeast-1
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 15 | POST /tasks レスポンス | HTTP 201、タスクオブジェクト | PASS | `{"id":1,"title":"v4 SQS test",...}` |
| 16 | task_created_handler Lambda ログ | `Task created: task_id=<ID>, title=v4 SQS test` | PASS | `Task created: task_id=1, title=v4 SQS test`（処理時間 2.20 ms） |

## 9. EventBridge イベント動作確認（PUT /tasks/{id} completed=true）

```bash
TASK_ID=$(curl -s http://$ALB_DNS/tasks | jq '.[0].id')

curl -s -X PUT http://$ALB_DNS/tasks/$TASK_ID \
  -H "Content-Type: application/json" \
  -d '{"completed": true}' | jq .

aws logs tail /aws/lambda/sample-cicd-task-completed-handler --since 1m --region ap-northeast-1
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 17 | PUT /tasks/{id} レスポンス | HTTP 200、`completed: true` | PASS | `{"id":1,"completed":true,...}` |
| 18 | task_completed_handler Lambda ログ | `Task completed: task_id=<ID>, title=v4 SQS test` | PASS | `Task completed: task_id=1, title=v4 SQS test`（処理時間 2.33 ms） |

## 10. Scheduler クリーンアップ Lambda 動作確認（手動実行）

```bash
aws lambda invoke \
  --function-name sample-cicd-task-cleanup-handler \
  --region ap-northeast-1 \
  --payload '{}' \
  /tmp/cleanup-output.json

cat /tmp/cleanup-output.json
aws logs tail /aws/lambda/sample-cicd-task-cleanup-handler --since 1m --region ap-northeast-1
```

| # | 確認項目 | 期待結果 | 結果 | 備考 |
|---|---------|---------|------|------|
| 19 | Lambda 実行レスポンス | `{"deleted": 0}` または正の整数 | PASS | `{"deleted": 0}`（保持期間超過タスクなし） |
| 20 | task_cleanup_handler ログ | `Cleanup done: deleted X tasks older than 30 days` | PASS | `Cleanup done: deleted 0 tasks older than 30 days`（処理時間 545 ms） |
| 21 | RDS 接続成功（エラーなし） | Secrets Manager / psycopg2 接続エラーログが出ていないこと | PASS | VPC エンドポイント経由で Secrets Manager 接続、psycopg2 で RDS 接続成功 |

## 11. CI/CD パイプライン確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 22 | CI — Lint | GitHub Actions ログ | `ruff check app/ tests/ lambda/` エラー 0 件 | PASS | エラー 0 件 |
| 23 | CI — Test | GitHub Actions ログ | 23 tests passed | PASS | TC-01〜TC-23 全件 PASS |
| 24 | CI — Build | GitHub Actions ログ | `docker build` 成功 | PASS | ビルド成功 |
| 25 | CD — ECR Push | GitHub Actions ログ | イメージ push 成功 | PASS | push 成功 |
| 26 | CD — ECS Deploy | GitHub Actions ログ | デプロイ完了（service stable） | PASS | 5m16s で完了 |
| 27 | CD — Lambda Deploy | GitHub Actions ログ | 3 関数の `update-function-code` が成功 | PASS | `lambda:UpdateFunctionCode` 権限追加後に成功 |

## 12. 確認結果サマリ

| カテゴリ | 合計 | PASS | FAIL | 合格率 |
|---------|------|------|------|--------|
| インフラ更新 (#1-3) | 3 | 3 | 0 | 100% |
| SQS (#4-5) | 2 | 2 | 0 | 100% |
| Lambda (#6-9) | 4 | 4 | 0 | 100% |
| EventBridge (#10-12) | 3 | 3 | 0 | 100% |
| VPC エンドポイント (#13-14) | 2 | 2 | 0 | 100% |
| SQS イベント動作 (#15-16) | 2 | 2 | 0 | 100% |
| EventBridge イベント動作 (#17-18) | 2 | 2 | 0 | 100% |
| Scheduler クリーンアップ (#19-21) | 3 | 3 | 0 | 100% |
| CI/CD (#22-27) | 6 | 6 | 0 | 100% |
| **合計** | **27** | **27** | **0** | **100%** |

## 13. 判定

- ☑ **合格** — 全 27 項目が PASS
- ☐ **条件付き合格**
- ☐ **不合格**

### 判定者コメント

全 27 項目 PASS。SQS → Lambda（task_created）、EventBridge → Lambda（task_completed）、Scheduler → VPC内Lambda（task_cleanup + RDS接続）の 3 イベントフローすべて正常動作を確認。CI/CD パイプラインも 23 テスト PASS・Lambda 3 関数デプロイ・ECS ローリングデプロイすべて成功（ci: 49s / cd: 5m16s）。

### 検出された問題と対応

| # | 問題 | 原因 | 対応 |
|---|------|------|------|
| 1 | Secrets Manager 作成エラー | v3 `terraform destroy` 時の 30 日保護期間付き削除済みシークレットが残存 | `aws secretsmanager delete-secret --force-delete-without-recovery` で即時削除後、再 apply |
| 2 | Lambda 作成エラー: `AWS_REGION` 予約語 | `AWS_REGION` は Lambda の予約済み環境変数のため明示設定不可 | `infra/lambda.tf` の environment ブロックから `AWS_REGION` を削除（Lambda が自動設定するため不要） |
| 3 | ECS タスク起動失敗: Secrets Manager 接続不可 | `private_dns_enabled = true` の VPC エンドポイントが VPC 全体の DNS を上書きするため、パブリックサブネットの ECS タスクも VPC エンドポイント経由となるが、VPCE SG が Lambda cleanup からしか許可していなかった | `infra/vpc_endpoints.tf` に ECS tasks SG からの ingress ルール追加、`terraform apply` で反映 |
| 4 | cleanup Lambda の RDS 接続タイムアウト | `aws_security_group.rds` のインライン ingress と `aws_security_group_rule.rds_from_lambda_cleanup` の競合により apply のたびに Lambda からのルールが削除される | `security_groups.tf` の RDS SG に `lifecycle { ignore_changes = [ingress] }` を追加、AWS CLI で RDS SG ルールを復旧 |

## 14. クリーンアップ記録

| # | 作業項目 | 実施日 | 結果 | 備考 |
|---|---------|--------|------|------|
| 1 | Lambda Layer 削除 | | ☐ | |
| 2 | ECR イメージ削除 | | ☐ | |
| 3 | `terraform destroy` 実行 | | ☐ | |
| 4 | IAM ポリシー（lambda-deploy）削除 | | ☐ | |
