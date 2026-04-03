# 動作確認記録 (v3)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 3.0 |
| 前バージョン | [verification_v2.md](verification_v2.md) (v2.0) |

## 1. 確認概要

本ドキュメントは `deploy_procedure_v3.md` に従ってデプロイを実施した後の動作確認記録である。
各項目を実施し、結果を記録する。

## 2. 環境情報

| 項目 | 値 |
|------|------|
| AWS アカウント ID | （v2 と同一） |
| AWS リージョン | ap-northeast-1 |
| ALB DNS 名 | （terraform output で取得済み） |
| ECR リポジトリ URL | （terraform output で取得済み） |
| RDS エンドポイント | （terraform output で取得済み） |
| Secrets Manager ARN | （terraform output で取得済み） |
| GitHub リポジトリ URL | https://github.com/masumi82/sample_cicd |
| 実施日 | |
| 実施者 | m-horiuchi |

## 3. インフラ更新確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | Terraform plan 確認 | `terraform plan` | 2 to add, 1 to change, 0 to destroy | | |
| 2 | Terraform apply 成功 | `terraform apply` | "Apply complete! Resources: 2 added, 1 changed, 0 destroyed." | | |

## 4. Auto Scaling リソース確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 3 | Scalable Target 登録 | `aws application-autoscaling describe-scalable-targets --service-namespace ecs` | `ResourceId: "service/sample-cicd/sample-cicd"`, `MinCapacity: 1`, `MaxCapacity: 3` | | |
| 4 | Scaling Policy 登録 | `aws application-autoscaling describe-scaling-policies --service-namespace ecs` | `PolicyType: TargetTrackingScaling`, `TargetValue: 70.0` | | |

## 5. RDS Multi-AZ 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 5 | RDS Multi-AZ 有効 | `aws rds describe-db-instances --db-instance-identifier sample-cicd --query 'DBInstances[0].MultiAZ'` | `true` | | |
| 6 | RDS ステータス正常 | `aws rds describe-db-instances --db-instance-identifier sample-cicd --query 'DBInstances[0].DBInstanceStatus'` | `"available"` | | |

## 6. HTTPS コード（count=0）確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 7 | HTTPS リソース未作成 | `terraform plan 2>&1 \| grep -E "acm\|route53\|https"` | 何も表示されない | | |
| 8 | ALB リスナーは :80 のみ | `aws elbv2 describe-listeners --load-balancer-arn <ALB_ARN> --query 'Listeners[*].Port'` | `[ 80 ]` | | |

## 7. アプリケーション動作確認（継続）

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 9 | GET / | `curl http://<ALB_DNS>/` | `{"message":"Hello, World!"}` (200) | | |
| 10 | GET /health | `curl http://<ALB_DNS>/health` | `{"status":"healthy"}` (200) | | |
| 11 | GET /tasks | `curl http://<ALB_DNS>/tasks` | `[]` (200) | | |
| 12 | POST /tasks | `curl -X POST http://<ALB_DNS>/tasks -H "Content-Type: application/json" -d '{"title":"v3 test"}'` | 201, タスクオブジェクト | | |
| 13 | GET /tasks/{id} | `curl http://<ALB_DNS>/tasks/1` | 200, 作成したタスク | | |

## 8. Auto Scaling 動作確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 14 | 初期タスク数 | `aws ecs describe-services --cluster sample-cicd --services sample-cicd --query 'services[0].runningCount'` | `1` | | |
| 15 | スケールアウト（TC-19） | `ab -n 30000 -c 50 http://<ALB_DNS>/health` で負荷をかけ、CPU > 70% の後にタスク数確認 | タスク数が 2 以上に増加 | | スケールアウトまで約 2〜3 分 |
| 16 | スケールイン（TC-20） | 負荷停止後 300 秒以上待機してタスク数確認 | タスク数が 1 に戻る | | スケールインまで最大 10 分 |
| 17 | Auto Scaling イベント | AWS コンソール > ECS > サービス > オートスケーリングタブ | スケールアウト・スケールインのイベントが記録されている | | |

## 9. CI/CD パイプライン確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 18 | CI — Lint | GitHub Actions ログ | `ruff check` エラー 0 件 | | v3 はアプリコード変更なし |
| 19 | CI — Test | GitHub Actions ログ | 18 tests passed | | |
| 20 | CI — Build | GitHub Actions ログ | `docker build -f app/Dockerfile .` 成功 | | |
| 21 | CD — ECR Push | GitHub Actions ログ | イメージ push 成功 | | |
| 22 | CD — ECS Deploy | GitHub Actions ログ | デプロイ完了（service stable） | | |

## 10. 確認結果サマリ

| カテゴリ | 合計 | PASS | FAIL | 合格率 |
|---------|------|------|------|--------|
| インフラ更新 (#1-2) | 2 | | | |
| Auto Scaling リソース (#3-4) | 2 | | | |
| RDS Multi-AZ (#5-6) | 2 | | | |
| HTTPS コード確認 (#7-8) | 2 | | | |
| アプリ動作確認 (#9-13) | 5 | | | |
| Auto Scaling 動作 (#14-17) | 4 | | | |
| CI/CD (#18-22) | 5 | | | |
| **合計** | **22** | | | |

## 11. 判定

- ☐ **合格** — 全 22 項目が PASS
- ☐ **条件付き合格** — FAIL 項目があるが運用に支障なし（備考に理由を記載）
- ☐ **不合格** — 重大な FAIL 項目あり（是正処置が必要）

### 判定者コメント

（デプロイ実施後に記入）

### 検出された問題と対応

| # | 問題 | 原因 | 対応 |
|---|------|------|------|
| — | — | — | — |

## 12. クリーンアップ記録

| # | 作業項目 | 実施日 | 結果 | 備考 |
|---|---------|--------|------|------|
| 1 | ECR イメージ削除 | | ☐ | |
| 2 | `terraform destroy` 実行 | | ☐ | |
| 3 | IAM ユーザー削除 | — | ☐ スキップ | v1〜v3 継続利用 |
| 4 | GitHub Secrets 削除 | — | ☐ スキップ | IAM ユーザー保持のため維持 |
