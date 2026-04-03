# デプロイ手順書 (v3)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 3.0 |
| 前バージョン | [deploy_procedure_v2.md](deploy_procedure_v2.md) (v2.0) |

## 変更概要

v2 のデプロイ手順に対して以下の変更・追加を行う:

| # | 変更点 | 説明 |
|---|--------|------|
| 1 | Auto Scaling リソース追加 | Application Auto Scaling Target + Policy（2 リソース） |
| 2 | RDS Multi-AZ 有効化 | `multi_az = false` → `true`（DB 変更、約 2〜5 分かかる） |
| 3 | HTTPS コード追加 | https.tf が追加されるが `enable_https = false` のため作成なし |
| 4 | Auto Scaling 動作確認 | 負荷ツールで CPU を上昇させてタスク数増減を確認 |

アプリケーションコードおよび CI/CD パイプラインへの変更はなし。

## 1. 前提条件

v2 のデプロイ手順完了済みであること（v2 リソースが `terraform apply` 済み）。

| 項目 | 要件 |
|------|------|
| AWS CLI v2 | インストール・設定済み |
| Terraform | インストール済み |
| Docker | インストール済み |
| v2 インフラ | `terraform apply` 済み、ECS サービスが稼働中 |
| Apache Bench | `ab` コマンド（Auto Scaling 動作確認用）|

> `ab` がない場合: `sudo apt-get install -y apache2-utils`（Ubuntu / WSL）でインストール可能。

## 2. AWS インフラ更新（Terraform）

### 2.1 terraform init 不要

v3 で追加されたリソース（autoscaling, https）はすべて既存の `hashicorp/aws` プロバイダーで対応しており、`terraform init` は不要。

```bash
cd ~/sample_cicd/infra
```

### 2.2 実行計画の確認

```bash
terraform plan
```

以下の変更が表示されることを確認する:

| 変更種別 | リソース | 説明 |
|---------|---------|------|
| `+` 追加 | `aws_appautoscaling_target.ecs_service` | ECS をスケーラブルターゲットとして登録 |
| `+` 追加 | `aws_appautoscaling_policy.ecs_cpu` | CPU ターゲット追跡ポリシー (70%) |
| `~` 変更 | `aws_db_instance.main` | `multi_az: false → true` |

ACM・Route53・HTTPS リスナー（https.tf）は `enable_https = false` のため **変更なし** であることを確認する。

期待される plan サマリ:

```
Plan: 2 to add, 1 to change, 0 to destroy.
```

### 2.3 インフラ更新の適用

```bash
terraform apply
```

`Enter a value:` に対して `yes` を入力する。

完了まで **約 5〜10 分** かかる（RDS Multi-AZ 有効化に約 3〜5 分）。

> **注意**: RDS の `multi_az` 変更中は DB が一時的に再起動され、接続が短時間切断される場合がある。
> SQLAlchemy が自動再接続するため、アプリへの影響は最小限（ECS タスクのエラーログが数秒出る可能性あり）。

完了後のメッセージ:

```
Apply complete! Resources: 2 added, 1 changed, 0 destroyed.
```

### 2.4 Auto Scaling リソースの確認

```bash
# Auto Scaling Target の確認
aws application-autoscaling describe-scalable-targets \
  --service-namespace ecs \
  --region ap-northeast-1 \
  --query 'ScalableTargets[?ResourceId==`service/sample-cicd/sample-cicd`]'
```

期待される出力:

```json
[
  {
    "ServiceNamespace": "ecs",
    "ResourceId": "service/sample-cicd/sample-cicd",
    "ScalableDimension": "ecs:service:DesiredCount",
    "MinCapacity": 1,
    "MaxCapacity": 3
  }
]
```

### 2.5 RDS Multi-AZ の確認

```bash
aws rds describe-db-instances \
  --db-instance-identifier sample-cicd \
  --region ap-northeast-1 \
  --query 'DBInstances[0].MultiAZ'
```

期待される出力: `true`

## 3. Auto Scaling 動作確認

> **注意**: この手順は学習目的の負荷テストである。本番環境では実施前にチームへ告知すること。

### 3.1 現在のタスク数確認

```bash
aws ecs describe-services \
  --cluster sample-cicd \
  --services sample-cicd \
  --region ap-northeast-1 \
  --query 'services[0].runningCount'
```

期待される出力: `1`（初期状態）

### 3.2 スケールアウトの確認（TC-19）

ALB の DNS 名を取得してから負荷をかける:

```bash
ALB_DNS=$(cd ~/sample_cicd/infra && terraform output -raw alb_dns_name)

# 5 分間の負荷テスト（並列 50 リクエスト、合計 30000 リクエスト）
ab -n 30000 -c 50 http://$ALB_DNS/health
```

別ターミナルで CloudWatch メトリクスを監視する:

```bash
# 30 秒ごとに CPU 使用率を確認（手動ポーリング）
watch -n 30 'aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ClusterName,Value=sample-cicd Name=ServiceName,Value=sample-cicd \
  --start-time $(date -u -d "5 minutes ago" +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 \
  --statistics Average \
  --region ap-northeast-1 \
  --query "Datapoints[-1].Average"'
```

CPU が 70% を超えたら、タスク数が増加することを確認する:

```bash
# タスク数確認（1 分ごとに実行）
aws ecs describe-services \
  --cluster sample-cicd \
  --services sample-cicd \
  --region ap-northeast-1 \
  --query 'services[0].{running: runningCount, desired: desiredCount}'
```

期待される変化: `running: 1` → `running: 2`（または `3`）

> **タイムライン目安:**
> - CPU 70% 超 → 60 秒（scale_out_cooldown）後にスケールアウト発火
> - 新タスク起動 → ECS タスクが `RUNNING` になるまで約 30〜60 秒
> - ALB がヘルスチェックを通過してトラフィックが分散されるまで約 30 秒

### 3.3 スケールインの確認（TC-20）

負荷ツールを停止した後、タスク数が 1 に戻ることを確認する:

```bash
# 10 分ほど待機してから確認（scale_in_cooldown = 300 秒 × 段階削減）
aws ecs describe-services \
  --cluster sample-cicd \
  --services sample-cicd \
  --region ap-northeast-1 \
  --query 'services[0].{running: runningCount, desired: desiredCount}'
```

期待される変化: `running: 2` → `running: 1`

> **スケールインはゆっくり進む:** タスク数が多い場合（例: 3 タスク）、300 秒ごとに 1 タスクずつ削減されるため、1 タスクに戻るまで最大 10 分かかる。

### 3.4 Auto Scaling イベントの確認（AWS コンソール）

1. AWS コンソール > ECS > クラスター `sample-cicd` > サービス `sample-cicd`
2. 「オートスケーリング」タブ → スケーリングアクティビティを確認
3. スケールアウト・スケールインのイベントが記録されていることを確認

## 4. HTTPS コード確認（TC-22）

HTTPS リソースが `enable_https = false` のため作成されていないことを確認する:

```bash
cd ~/sample_cicd/infra

# https.tf のリソースが count=0 であることを確認
terraform plan 2>&1 | grep -E "acm|route53|https"
```

期待される出力: 何も表示されない（変更なし）

ALB にポート 443 のリスナーが存在しないことも確認:

```bash
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names sample-cicd-alb \
  --region ap-northeast-1 \
  --query 'LoadBalancers[0].LoadBalancerArn' \
  --output text)

aws elbv2 describe-listeners \
  --load-balancer-arn $ALB_ARN \
  --region ap-northeast-1 \
  --query 'Listeners[*].Port'
```

期待される出力: `[ 80 ]`（ポート 80 のみ）

## 5. CI/CD デプロイ確認

### 5.1 コードの push と CI/CD 実行

```bash
cd ~/sample_cicd
git add infra/autoscaling.tf infra/https.tf infra/rds.tf infra/variables.tf infra/alb.tf infra/security_groups.tf
git commit -m "v3: ECS Auto Scaling + RDS Multi-AZ + HTTPS preparation"
git push origin main
```

### 5.2 CI ジョブの確認

GitHub Actions で以下が成功することを確認:

1. **Lint** — `ruff check` がエラー 0 件
2. **Test** — `pytest tests/ -v` で **18 テスト** 全 PASS
3. **Build** — `docker build -f app/Dockerfile .` が成功

> v3 はアプリコードの変更がないため、CI の動作は v2 と同一。

### 5.3 CD ジョブの確認

Terraform の変更は CI/CD では自動適用されない（手動 `terraform apply` が必要）。
CD ジョブは v2 と同様に ECS のローリングデプロイを実行する。

Auto Scaling が有効な状態でのデプロイ動作:
- デプロイ中は `desired_count` が ECS サービスに設定された値に従う
- Auto Scaling は `deployment_minimum_healthy_percent = 100` を維持する
- デプロイ完了後、Auto Scaling が引き続きタスク数を管理する

## 6. クリーンアップ手順

> **重要**: v3 は RDS が Multi-AZ になりコストが増加している（約 $60/月）。学習完了後は必ず削除すること。

### 6.1 費用が発生する主なリソース

| リソース | 概算費用（東京リージョン） | v2 | v3 |
|----------|--------------------------|:--:|:--:|
| ALB | 約 $0.03/時間 + トラフィック | o | o |
| Fargate (0.25 vCPU / 512 MB) | 約 $0.01/時間 × タスク数 | o | o |
| ECR | ストレージ $0.10/GB/月 | o | o |
| CloudWatch Logs | 取り込み $0.76/GB | o | o |
| RDS (db.t3.micro, **Multi-AZ**) | **約 $0.04/時間（約 $30/月）** | $15 | **$30** |
| Secrets Manager | $0.40/月 | o | o |

> **概算**: 1 日稼働で約 $2.50〜3.00。月間放置すると約 $60。

### 6.2 Terraform でリソース削除

```bash
cd ~/sample_cicd/infra

# ECR リポジトリ内のイメージを先に削除
aws ecr batch-delete-image \
  --repository-name sample-cicd \
  --image-ids "$(aws ecr list-images --repository-name sample-cicd --query 'imageIds[*]' --output json)" \
  --region ap-northeast-1

# 全リソース削除
terraform destroy
```

`Enter a value:` に対して `yes` を入力する。

> **Auto Scaling ポリシーが先に削除される。** Terraform は依存関係に従い、
> `aws_appautoscaling_policy` → `aws_appautoscaling_target` → `aws_ecs_service` の順で削除する。

### 6.3 IAM / GitHub Secrets のクリーンアップ

v2 の [deploy_procedure_v2.md](deploy_procedure_v2.md) セクション 6.3 を参照。

## 7. トラブルシューティング

### v1・v2 のトラブルシューティング

[deploy_procedure_v2.md](deploy_procedure_v2.md) セクション 7 を参照。

### v3 固有の問題

#### Auto Scaling がスケールアウトしない

```bash
# Auto Scaling ポリシーの設定確認
aws application-autoscaling describe-scaling-policies \
  --service-namespace ecs \
  --region ap-northeast-1 \
  --query 'ScalingPolicies[?ResourceId==`service/sample-cicd/sample-cicd`]'
```

よくある原因:
- **ECS サービスの `desired_count` が min/max の外にある**: `min_capacity = 1`, `max_capacity = 3` の範囲内か確認
- **CPU メトリクスが上がっていない**: ALB に十分なトラフィックが流れているか確認
- **クールダウン期間中**: 直前のスケーリングから 60 秒未満の場合はスケールアウトが保留される

#### RDS Multi-AZ 変更後に DB 接続エラーが続く

Multi-AZ への変更中（約 3〜5 分）は一時的な接続切断が発生することがある。
変更完了後もエラーが続く場合:

```bash
# RDS ステータス確認
aws rds describe-db-instances \
  --db-instance-identifier sample-cicd \
  --region ap-northeast-1 \
  --query 'DBInstances[0].{Status: DBInstanceStatus, MultiAZ: MultiAZ}'
```

`Status: "available"` かつ `MultiAZ: true` であれば DB は正常稼働中。
ECS タスクのログでエラーが出ていれば、タスクを強制再起動する:

```bash
aws ecs update-service \
  --cluster sample-cicd \
  --service sample-cicd \
  --force-new-deployment \
  --region ap-northeast-1
```

#### `terraform apply` で Auto Scaling の `resource_id` がエラーになる

```
Error: ResourceId "service/sample-cicd/sample-cicd" does not match
```

ECS クラスター名またはサービス名が `var.project_name` と異なる場合に発生する。
`infra/variables.tf` の `project_name` のデフォルト値（`"sample-cicd"`）と
実際に作成された ECS クラスター名・サービス名が一致することを確認する:

```bash
aws ecs list-clusters --region ap-northeast-1
aws ecs list-services --cluster sample-cicd --region ap-northeast-1
```
