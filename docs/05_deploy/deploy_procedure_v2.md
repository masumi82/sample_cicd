# デプロイ手順書 (v2)

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-03 |
| バージョン | 2.0 |
| 前バージョン | [deploy_procedure.md](deploy_procedure.md) (v1.0) |

## 変更概要

v1 のデプロイ手順に対して以下の変更・追加を行う:

| # | 変更点 | 説明 |
|---|--------|------|
| 1 | Terraform リソース追加 | RDS, Secrets Manager, プライベートサブネット等 +13 リソース |
| 2 | Docker ビルドコンテキスト | `./app` → `-f app/Dockerfile .`（プロジェクトルート） |
| 3 | 初回デプロイ後の DB 確認 | RDS 接続と tasks テーブルの確認 |
| 4 | CRUD エンドポイント確認 | タスク API の動作確認 |
| 5 | コスト増加 | RDS ($15/月) + Secrets Manager ($0.40/月) が追加 |

## 1. 前提条件

v1 の前提条件に加え、以下が必要:

| 項目 | 要件 | v1 から |
|------|------|---------|
| AWS CLI v2 | インストール・設定済み | 変更なし |
| Terraform | インストール済み | 変更なし |
| Docker | インストール済み | 変更なし |
| GitHub リポジトリ | 作成済み | 変更なし |
| GitHub Secrets | `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` 設定済み | 変更なし |

> v1 で環境セットアップ・GitHub リポジトリ作成・IAM ユーザー作成が完了していること。
> 未実施の場合は [deploy_procedure.md](deploy_procedure.md) のセクション 2〜5 を先に実施する。

## 2. AWS インフラ構築（Terraform）

### 2.1 Terraform 初期化

v2 で `random` プロバイダーが追加されたため、再度 `terraform init` が必要。

```bash
cd ~/sample_cicd/infra

terraform init
```

期待される出力:

```
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Finding hashicorp/random versions matching "~> 3.0"...
...
Terraform has been successfully initialized!
```

### 2.2 実行計画の確認

```bash
terraform plan
```

以下の **新規リソース** が作成されることを確認する:

| # | リソース | 説明 | ファイル |
|---|---------|------|----------|
| 1 | `aws_subnet.private_1` | プライベートサブネット (AZ-a, 10.0.11.0/24) | main.tf |
| 2 | `aws_subnet.private_2` | プライベートサブネット (AZ-c, 10.0.12.0/24) | main.tf |
| 3 | `aws_route_table.private` | プライベートルートテーブル | main.tf |
| 4 | `aws_route_table_association.private_1` | ルートテーブル関連付け | main.tf |
| 5 | `aws_route_table_association.private_2` | ルートテーブル関連付け | main.tf |
| 6 | `aws_security_group.rds` | RDS セキュリティグループ | security_groups.tf |
| 7 | `aws_db_subnet_group.main` | DB サブネットグループ | rds.tf |
| 8 | `aws_db_instance.main` | RDS PostgreSQL | rds.tf |
| 9 | `random_password.db_password` | DB パスワード自動生成 | secrets.tf |
| 10 | `aws_secretsmanager_secret.db_credentials` | Secrets Manager シークレット | secrets.tf |
| 11 | `aws_secretsmanager_secret_version.db_credentials` | シークレット値 | secrets.tf |
| 12 | `aws_iam_policy.secrets_manager_read` | Secrets Manager 読み取りポリシー | iam.tf |
| 13 | `aws_iam_role_policy_attachment.ecs_secrets_manager` | ポリシーアタッチ | iam.tf |

加えて、既存リソースの変更:

| リソース | 変更内容 |
|---------|---------|
| `aws_ecs_task_definition.app` | `secrets` ブロック追加（5 環境変数） |

> **注意**: v1 のリソースが `terraform destroy` で削除済みの場合、v1 リソース (21) + v2 新規 (13) = 34 リソースが作成される。
> v1 リソースが残っている場合は、v2 新規 13 + 変更 1 が表示される。

### 2.3 インフラ作成

```bash
terraform apply
```

`Enter a value:` に対して `yes` を入力する。

完了まで **約 10〜15 分** かかる（RDS インスタンスの作成に約 10 分）。

> **注意**: RDS の作成は v1 より大幅に時間がかかる。途中で中断しないこと。

### 2.4 出力値の確認

```bash
terraform output
```

以下の **6 つの値** が出力される（v1 の 4 つ + v2 の 2 つ）:

```
alb_dns_name        = "sample-cicd-alb-XXXXXXXXX.ap-northeast-1.elb.amazonaws.com"
ecr_repository_url  = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/sample-cicd"
ecs_cluster_name    = "sample-cicd"
ecs_service_name    = "sample-cicd"
rds_endpoint        = "sample-cicd.xxxxxxxxxxxx.ap-northeast-1.rds.amazonaws.com:5432"
secrets_manager_arn = "arn:aws:secretsmanager:ap-northeast-1:123456789012:secret:sample-cicd/db-credentials-XXXXXX"
```

> **重要**: `rds_endpoint` と `secrets_manager_arn` が新たに出力されることを確認する。

## 3. 初回デプロイ（手動）

### 3.1 ECR へのログイン

v1 と同じ手順。

```bash
ECR_URL=$(cd ~/sample_cicd/infra && terraform output -raw ecr_repository_url)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-northeast-1

aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

### 3.2 Docker イメージのビルドとプッシュ

> **v2 変更点**: ビルドコンテキストがプロジェクトルートに変更。

```bash
cd ~/sample_cicd

# v2: プロジェクトルートから Dockerfile を指定してビルド
docker build -t $ECR_URL:latest -f app/Dockerfile .

# ECR にプッシュ
docker push $ECR_URL:latest
```

### 3.3 ECS サービスの更新

```bash
aws ecs update-service \
  --cluster sample-cicd \
  --service sample-cicd \
  --force-new-deployment \
  --region ap-northeast-1
```

### 3.4 デプロイ完了の待機

```bash
aws ecs wait services-stable \
  --cluster sample-cicd \
  --services sample-cicd \
  --region ap-northeast-1
```

> **注意**: ECS タスク起動時に Alembic マイグレーションが自動実行される。
> tasks テーブルが RDS 上に作成される。

### 3.5 v1 エンドポイントの動作確認

```bash
ALB_DNS=$(cd ~/sample_cicd/infra && terraform output -raw alb_dns_name)

# GET /
curl http://$ALB_DNS/
# → {"message":"Hello, World!"}

# GET /health
curl http://$ALB_DNS/health
# → {"status":"healthy"}
```

### 3.6 v2 エンドポイントの動作確認

```bash
# タスク一覧（空）
curl http://$ALB_DNS/tasks
# → []

# タスク作成
curl -X POST http://$ALB_DNS/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "First task", "description": "Testing v2 deployment"}'
# → {"id":1,"title":"First task","description":"Testing v2 deployment","completed":false,"created_at":"...","updated_at":"..."}

# タスク取得
curl http://$ALB_DNS/tasks/1
# → {"id":1,"title":"First task",...}

# タスク更新
curl -X PUT http://$ALB_DNS/tasks/1 \
  -H "Content-Type: application/json" \
  -d '{"completed": true}'
# → {"id":1,...,"completed":true,...}

# タスク一覧（1 件）
curl http://$ALB_DNS/tasks
# → [{"id":1,...}]

# タスク削除
curl -X DELETE http://$ALB_DNS/tasks/1 -w "\n%{http_code}\n"
# → 204

# 削除後のタスク一覧（空）
curl http://$ALB_DNS/tasks
# → []
```

## 4. CI/CD デプロイ確認

### 4.1 コードの push と CI/CD 実行

```bash
cd ~/sample_cicd
git add .
git commit -m "v2: Task CRUD API with RDS PostgreSQL"
git push origin main
```

### 4.2 CI ジョブの確認

GitHub Actions の CI ジョブで以下が成功することを確認:

1. **Lint** — `ruff check app/ tests/` がエラー 0 件
2. **Test** — `pytest tests/ -v` で **18 テスト** 全 PASS
3. **Build** — `docker build -f app/Dockerfile .` が成功

### 4.3 CD ジョブの確認

CI 成功後、CD ジョブで以下を確認:

1. **AWS Auth** — 認証成功
2. **ECR Login** — ログイン成功
3. **ECR Push** — イメージのビルド・プッシュ成功（`-f app/Dockerfile .` でビルド）
4. **ECS Deploy** — タスク定義更新と ECS デプロイ成功

### 4.4 デプロイ後の動作確認

セクション 3.5 〜 3.6 の確認を再実行し、CI/CD 経由のデプロイでも正常動作することを確認する。

## 5. RDS 接続確認（オプション）

ECS タスクから RDS に正常接続されていることを追加確認する場合:

### 5.1 CloudWatch Logs でマイグレーションログ確認

```bash
# 最新のログストリームを取得
LOG_STREAM=$(aws logs describe-log-streams \
  --log-group-name /ecs/sample-cicd \
  --order-by LastEventTime \
  --descending \
  --limit 1 \
  --query 'logStreams[0].logStreamName' \
  --output text \
  --region ap-northeast-1)

# ログを確認
aws logs get-log-events \
  --log-group-name /ecs/sample-cicd \
  --log-stream-name $LOG_STREAM \
  --limit 30 \
  --region ap-northeast-1 \
  --query 'events[*].message' \
  --output text
```

Alembic のマイグレーションログ（`INFO [alembic.runtime.migration] Running upgrade -> 001`）と
uvicorn の起動ログが表示されれば正常。

### 5.2 Secrets Manager の確認

```bash
# シークレットの存在確認（値は表示しない）
aws secretsmanager describe-secret \
  --secret-id sample-cicd/db-credentials \
  --region ap-northeast-1 \
  --query '{Name: Name, ARN: ARN}'
```

### 5.3 RDS インスタンスの確認

```bash
aws rds describe-db-instances \
  --db-instance-identifier sample-cicd \
  --region ap-northeast-1 \
  --query 'DBInstances[0].{Status: DBInstanceStatus, Endpoint: Endpoint.Address, Engine: Engine, EngineVersion: EngineVersion}'
```

期待される出力:

```json
{
    "Status": "available",
    "Endpoint": "sample-cicd.xxxxxxxxxxxx.ap-northeast-1.rds.amazonaws.com",
    "Engine": "postgres",
    "EngineVersion": "15.x"
}
```

## 6. クリーンアップ手順

> **重要**: v2 は RDS が追加され、コストが増加している（約 $45/月）。学習完了後は必ず削除すること。

### 6.1 費用が発生する主なリソース

| リソース | 概算費用（東京リージョン） | v1 | v2 |
|----------|--------------------------|:--:|:--:|
| ALB | 約 $0.03/時間 + トラフィック | o | o |
| Fargate (0.25 vCPU / 512 MB) | 約 $0.01/時間 | o | o |
| ECR | ストレージ $0.10/GB/月 | o | o |
| CloudWatch Logs | 取り込み $0.76/GB | o | o |
| **RDS (db.t3.micro)** | **約 $0.02/時間（約 $15/月）** | - | **o** |
| **Secrets Manager** | **$0.40/月** | - | **o** |

> **概算**: 1 日稼働で約 $1.50〜2.00。月間放置すると約 $45。

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

> **注意**: RDS の削除には数分かかる。`skip_final_snapshot = true` のため、スナップショットは作成されない。

### 6.3 IAM / GitHub Secrets のクリーンアップ

v1 の [deploy_procedure.md](deploy_procedure.md) セクション 7.3〜7.5 を参照。

## 7. トラブルシューティング

### v1 のトラブルシューティング

v1 の [deploy_procedure.md](deploy_procedure.md) セクション 8 を参照。

### v2 固有の問題

#### ECS タスクが起動時にクラッシュする（DB 接続エラー）

```bash
# CloudWatch Logs でエラーを確認
aws logs get-log-events \
  --log-group-name /ecs/sample-cicd \
  --log-stream-name <LOG_STREAM> \
  --limit 30 \
  --region ap-northeast-1
```

よくある原因:
- **Secrets Manager の権限不足**: `iam.tf` で `secretsmanager:GetSecretValue` が付与されているか確認
- **RDS がまだ起動中**: `aws rds describe-db-instances` で `Status: available` を確認
- **セキュリティグループ**: ECS タスク SG → RDS SG (port 5432) の通信が許可されているか確認

#### Alembic マイグレーションが失敗する

```
alembic.util.exc.CommandError: Can't locate revision identified by '001'
```

- Alembic のバージョンファイルが Docker イメージに含まれているか確認
- `app/alembic/versions/001_create_tasks_table.py` が存在すること

#### タスク API が 500 を返す

- RDS への接続文字列が正しいか確認（環境変数 `DB_*` が ECS タスクに注入されているか）
- ECS タスク定義の `secrets` ブロックが正しいか確認

```bash
# タスク定義の secrets を確認
aws ecs describe-task-definition \
  --task-definition sample-cicd \
  --query 'taskDefinition.containerDefinitions[0].secrets' \
  --region ap-northeast-1
```
