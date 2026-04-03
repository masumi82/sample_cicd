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
| ALB DNS 名 | sample-cicd-alb-986356397.ap-northeast-1.elb.amazonaws.com |
| ECR リポジトリ URL | 123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/sample-cicd |
| RDS エンドポイント | sample-cicd.cpysyu4imcnq.ap-northeast-1.rds.amazonaws.com:5432 |
| Secrets Manager ARN | arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:sample-cicd/db-credentials-Qf3GTy |
| GitHub リポジトリ URL | https://github.com/masumi82/sample_cicd |
| 実施日 | 2026-04-03 |
| 実施者 | m-horiuchi |

## 3. インフラ更新確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 1 | Terraform plan 確認 | `terraform plan` | 2 to add, 1 to change, 0 to destroy | PASS | v2 インフラが削除済みだったため 36 to add から全リソース再構築。Auto Scaling 2 リソース + RDS Multi-AZ 変更を含む |
| 2 | Terraform apply 成功 | `terraform apply` | "Apply complete! Resources: 2 added, 1 changed, 0 destroyed." | PASS | 全リソース再構築のため "Resources: 8 added, 0 changed, 0 destroyed."（2回目 apply）。Secrets Manager の削除待ち問題を `--force-delete-without-recovery` で解消後に成功 |

## 4. Auto Scaling リソース確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 3 | Scalable Target 登録 | `aws application-autoscaling describe-scalable-targets --service-namespace ecs` | `ResourceId: "service/sample-cicd/sample-cicd"`, `MinCapacity: 1`, `MaxCapacity: 3` | PASS | `Min: 1`, `Max: 3` 確認済み |
| 4 | Scaling Policy 登録 | `aws application-autoscaling describe-scaling-policies --service-namespace ecs` | `PolicyType: TargetTrackingScaling`, `TargetValue: 70.0` | PASS | `TargetTrackingScaling`, `TargetValue: 70.0` 確認済み |

## 5. RDS Multi-AZ 確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 5 | RDS Multi-AZ 有効 | `aws rds describe-db-instances --db-instance-identifier sample-cicd --query 'DBInstances[0].MultiAZ'` | `true` | PASS | `true` 確認済み |
| 6 | RDS ステータス正常 | `aws rds describe-db-instances --db-instance-identifier sample-cicd --query 'DBInstances[0].DBInstanceStatus'` | `"available"` | PASS | `"available"` 確認済み |

## 6. HTTPS コード（count=0）確認

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 7 | HTTPS リソース未作成 | `terraform plan 2>&1 \| grep -E "acm\|route53\|https"` | 何も表示されない | PASS | 出力なし。`enable_https = false` のため ACM・Route53・HTTPS リスナーは作成されていない |
| 8 | ALB リスナーは :80 のみ | `aws elbv2 describe-listeners --load-balancer-arn <ALB_ARN> --query 'Listeners[*].Port'` | `[ 80 ]` | PASS | `[ 80 ]` 確認済み |

## 7. アプリケーション動作確認（継続）

| # | 確認項目 | 確認コマンド | 期待結果 | 結果 | 備考 |
|---|---------|-------------|---------|------|------|
| 9 | GET / | `curl http://<ALB_DNS>/` | `{"message":"Hello, World!"}` (200) | PASS | `{"message":"Hello, World!"}` |
| 10 | GET /health | `curl http://<ALB_DNS>/health` | `{"status":"healthy"}` (200) | PASS | `{"status":"healthy"}` |
| 11 | GET /tasks | `curl http://<ALB_DNS>/tasks` | `[]` (200) | PASS | `[]` |
| 12 | POST /tasks | `curl -X POST http://<ALB_DNS>/tasks -H "Content-Type: application/json" -d '{"title":"v3 test"}'` | 201, タスクオブジェクト | PASS | `{"id":1,"title":"v3 test","description":null,"completed":false,...}` |
| 13 | GET /tasks/{id} | `curl http://<ALB_DNS>/tasks/1` | 200, 作成したタスク | PASS | id:1 のタスクを取得確認 |

## 8. Auto Scaling 動作確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 14 | 初期タスク数 | `aws ecs describe-services --cluster sample-cicd --services sample-cicd --query 'services[0].runningCount'` | `1` | PASS | `running: 1` 確認済み |
| 15 | スケールアウト（TC-19） | Python httpx × 2 プロセス並列（各 120 並列）で負荷をかけ、CPU > 70% の後にタスク数確認 | タスク数が 2 以上に増加 | PASS | CPU 84〜90%（3 分連続）で AlarmHigh が ALARM → desired: 1→2, running: 2 に増加 |
| 16 | スケールイン（TC-20） | 負荷停止後、CPU < 63% が 15 分連続でタスク数確認 | タスク数が 1 に戻る | PASS | AlarmLow が ALARM（15 データポイント連続）→ desired: 2→1, running: 1 に復帰 |
| 17 | Auto Scaling イベント | CloudWatch Alarm 状態確認 | スケールアウト・スケールインのイベントが記録されている | PASS | AlarmHigh: OK→ALARM→OK、AlarmLow: OK→ALARM を CLI で確認 |

## 9. CI/CD パイプライン確認

| # | 確認項目 | 確認方法 | 期待結果 | 結果 | 備考 |
|---|---------|---------|---------|------|------|
| 18 | CI — Lint | GitHub Actions ログ | `ruff check` エラー 0 件 | PASS | エラー 0 件 |
| 19 | CI — Test | GitHub Actions ログ | 18 tests passed | PASS | 18 tests passed |
| 20 | CI — Build | GitHub Actions ログ | `docker build -f app/Dockerfile .` 成功 | PASS | ビルド成功 |
| 21 | CD — ECR Push | GitHub Actions ログ | イメージ push 成功 | PASS | push 成功 |
| 22 | CD — ECS Deploy | GitHub Actions ログ | デプロイ完了（service stable） | PASS | ci: 33s / cd: 5m26s で完了 |

## 10. 確認結果サマリ

| カテゴリ | 合計 | PASS | FAIL | 合格率 |
|---------|------|------|------|--------|
| インフラ更新 (#1-2) | 2 | 2 | 0 | 100% |
| Auto Scaling リソース (#3-4) | 2 | 2 | 0 | 100% |
| RDS Multi-AZ (#5-6) | 2 | 2 | 0 | 100% |
| HTTPS コード確認 (#7-8) | 2 | 2 | 0 | 100% |
| アプリ動作確認 (#9-13) | 5 | 5 | 0 | 100% |
| Auto Scaling 動作 (#14-17) | 4 | 4 | 0 | 100% |
| CI/CD (#18-22) | 5 | 5 | 0 | 100% |
| **合計** | **22** | **22** | **0** | **100%** |

## 11. 判定

- ☑ **合格** — 全 22 項目が PASS
- ☐ **条件付き合格** — FAIL 項目があるが運用に支障なし（備考に理由を記載）
- ☐ **不合格** — 重大な FAIL 項目あり（是正処置が必要）

### 判定者コメント

全 22 項目 PASS。ECS Auto Scaling のスケールアウト（CPU 84〜90% × 3 分連続）およびスケールイン（CPU 0.5% × 15 分連続）の実動作を確認した。
RDS Multi-AZ・HTTPS コード（count=0）・アプリ全エンドポイント・CI/CD パイプラインも正常動作を確認。
v2 インフラがクリーンアップ済みだったため全リソースを再構築した（Secrets Manager 削除待ち問題は `--force-delete-without-recovery` で対処）。

### 検出された問題と対応

| # | 問題 | 原因 | 対応 |
|---|------|------|------|
| 1 | `terraform apply` が Secrets Manager 作成エラー | v2 の `terraform destroy` 時に 30 日保護期間付きで削除されたシークレットが残存 | `aws secretsmanager delete-secret --force-delete-without-recovery` で即時削除後、再 apply で解決 |
| 2 | `ab` による負荷テストが途中でタイムアウト | WSL2 → 東京 ALB 間の距離・コネクション上限 | Python httpx（非同期）× 2 プロセス並列に切り替えて 3 分以上の持続負荷を実現 |

## 12. クリーンアップ記録

| # | 作業項目 | 実施日 | 結果 | 備考 |
|---|---------|--------|------|------|
| 1 | ECR イメージ削除 | | ☐ | |
| 2 | `terraform destroy` 実行 | | ☐ | |
| 3 | IAM ユーザー削除 | — | ☐ スキップ | v1〜v3 継続利用 |
| 4 | GitHub Secrets 削除 | — | ☐ スキップ | IAM ユーザー保持のため維持 |
