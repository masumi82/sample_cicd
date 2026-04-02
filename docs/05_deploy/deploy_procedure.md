# デプロイ手順書

| 項目 | 内容 |
|------|------|
| プロジェクト名 | sample_cicd |
| 作成日 | 2026-04-02 |
| バージョン | 1.0 |

## 1. 前提条件

| 項目 | 要件 |
|------|------|
| AWS アカウント | 管理者権限を持つ IAM ユーザーまたはルートアカウント |
| GitHub アカウント | リポジトリ作成権限あり |
| OS | Linux / WSL2 |
| Docker | インストール済み（`docker --version` で確認） |

## 2. 環境セットアップ

### 2.1 AWS CLI v2 インストール

```bash
# ダウンロードとインストール
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 確認
aws --version
```

### 2.2 AWS CLI 設定

```bash
aws configure
```

以下を入力する:

| 項目 | 値 |
|------|------|
| AWS Access Key ID | （IAM ユーザーのアクセスキー） |
| AWS Secret Access Key | （IAM ユーザーのシークレットキー） |
| Default region name | `ap-northeast-1` |
| Default output format | `json` |

設定確認:

```bash
aws sts get-caller-identity
```

### 2.3 Terraform インストール

```bash
# HashiCorp GPG キーの追加
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# リポジトリの追加
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# インストール
sudo apt update && sudo apt install terraform

# 確認
terraform --version
```

### 2.4 Git 初期化と GitHub リポジトリ作成

```bash
cd ~/sample_cicd

# Git 初期化
git init
git add .
git commit -m "Initial commit: Phase 1-4 complete"

# GitHub リポジトリ作成（gh CLI を使用する場合）
gh repo create sample_cicd --public --source=. --remote=origin --push

# gh CLI を使わない場合:
# 1. GitHub Web UI で "sample_cicd" リポジトリを作成
# 2. 以下を実行:
#    git remote add origin https://github.com/<YOUR_USERNAME>/sample_cicd.git
#    git branch -M main
#    git push -u origin main
```

## 3. AWS インフラ構築（Terraform）

### 3.1 Terraform 初期化

```bash
cd ~/sample_cicd/infra

terraform init
```

期待される出力:

```
Terraform has been successfully initialized!
```

### 3.2 実行計画の確認

```bash
terraform plan
```

以下の **20 リソース** が作成されることを確認する:

| # | リソース | 説明 |
|---|---------|------|
| 1 | `aws_vpc.main` | VPC (10.0.0.0/16) |
| 2 | `aws_subnet.public_1` | パブリックサブネット (AZ-a) |
| 3 | `aws_subnet.public_2` | パブリックサブネット (AZ-c) |
| 4 | `aws_internet_gateway.main` | インターネットゲートウェイ |
| 5 | `aws_route_table.public` | パブリックルートテーブル |
| 6 | `aws_route_table_association.public_1` | ルートテーブル関連付け 1 |
| 7 | `aws_route_table_association.public_2` | ルートテーブル関連付け 2 |
| 8 | `aws_security_group.alb` | ALB セキュリティグループ |
| 9 | `aws_security_group.ecs_tasks` | ECS タスクセキュリティグループ |
| 10 | `aws_lb.main` | Application Load Balancer |
| 11 | `aws_lb_target_group.app` | ALB ターゲットグループ |
| 12 | `aws_lb_listener.http` | ALB リスナー (HTTP:80) |
| 13 | `aws_ecr_repository.app` | ECR リポジトリ |
| 14 | `aws_ecr_lifecycle_policy.app` | ECR ライフサイクルポリシー |
| 15 | `aws_ecs_cluster.main` | ECS クラスター |
| 16 | `aws_ecs_task_definition.app` | ECS タスク定義 |
| 17 | `aws_ecs_service.app` | ECS サービス |
| 18 | `aws_iam_role.ecs_task_execution` | タスク実行ロール |
| 19 | `aws_iam_role.ecs_task` | タスクロール |
| 20 | `aws_iam_role_policy_attachment.ecs_task_execution` | ポリシーアタッチメント |
| 21 | `aws_cloudwatch_log_group.app` | CloudWatch ロググループ |

> **注意**: `terraform plan` の出力で `Plan: 21 to add` と表示される（lifecycle policy を含む）。

### 3.3 インフラ作成

```bash
terraform apply
```

`Enter a value:` に対して `yes` を入力する。

完了まで **約 3〜5 分** かかる（ALB の作成に時間がかかる）。

### 3.4 出力値の確認

```bash
terraform output
```

以下の 4 つの値が出力される:

```
alb_dns_name      = "sample-cicd-alb-XXXXXXXXX.ap-northeast-1.elb.amazonaws.com"
ecr_repository_url = "123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/sample-cicd"
ecs_cluster_name   = "sample-cicd"
ecs_service_name   = "sample-cicd"
```

> **重要**: `alb_dns_name` と `ecr_repository_url` を控えておくこと。以降の手順で使用する。

## 4. 初回デプロイ（手動）

ECS タスク定義は `<ECR_URL>:latest` イメージを参照するため、初回は手動でイメージを push する必要がある。

### 4.1 ECR へのログイン

```bash
# ECR リポジトリ URL を変数に設定
ECR_URL=$(cd ~/sample_cicd/infra && terraform output -raw ecr_repository_url)
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=ap-northeast-1

# ECR にログイン
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

期待される出力:

```
Login Succeeded
```

### 4.2 Docker イメージのビルドとプッシュ

```bash
cd ~/sample_cicd/app

# イメージビルド
docker build -t $ECR_URL:latest .

# ECR にプッシュ
docker push $ECR_URL:latest
```

### 4.3 ECS サービスの更新

```bash
# ECS サービスに新しいイメージをデプロイ
aws ecs update-service \
  --cluster sample-cicd \
  --service sample-cicd \
  --force-new-deployment \
  --region ap-northeast-1
```

### 4.4 デプロイ完了の待機

```bash
aws ecs wait services-stable \
  --cluster sample-cicd \
  --services sample-cicd \
  --region ap-northeast-1
```

このコマンドはサービスが安定するまでブロックする（通常 1〜3 分）。

### 4.5 動作確認

```bash
# ALB DNS 名を取得
ALB_DNS=$(cd ~/sample_cicd/infra && terraform output -raw alb_dns_name)

# GET / の確認
curl http://$ALB_DNS/

# GET /health の確認
curl http://$ALB_DNS/health
```

期待される出力:

```json
{"message":"Hello, World!"}
{"status":"healthy"}
```

## 5. GitHub Actions CI/CD セットアップ

### 5.1 CI/CD 用 IAM ユーザーの作成

GitHub Actions から AWS にアクセスするための専用 IAM ユーザーを作成する。

```bash
# IAM ユーザー作成
aws iam create-user --user-name github-actions-sample-cicd

# アクセスキーの発行
aws iam create-access-key --user-name github-actions-sample-cicd
```

> **重要**: 出力される `AccessKeyId` と `SecretAccessKey` を安全に控えること。以降の GitHub Secrets 設定で使用する。

### 5.2 IAM ポリシーの作成とアタッチ

CI/CD に必要な最小権限ポリシーを作成する。

```bash
cat > /tmp/github-actions-policy.json << 'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "ECRPush",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:ap-northeast-1:*:repository/sample-cicd"
    },
    {
      "Sid": "ECSDescribe",
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeServices",
        "ecs:DescribeTasks"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSUpdate",
      "Effect": "Allow",
      "Action": [
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMPassRole",
      "Effect": "Allow",
      "Action": "iam:PassRole",
      "Resource": [
        "arn:aws:iam::*:role/sample-cicd-ecs-task-execution",
        "arn:aws:iam::*:role/sample-cicd-ecs-task"
      ]
    }
  ]
}
POLICY

# ポリシー作成
aws iam create-policy \
  --policy-name github-actions-sample-cicd \
  --policy-document file:///tmp/github-actions-policy.json

# ポリシーをユーザーにアタッチ
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
aws iam attach-user-policy \
  --user-name github-actions-sample-cicd \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/github-actions-sample-cicd
```

### 5.3 GitHub Secrets の設定

GitHub リポジトリの **Settings → Secrets and variables → Actions** で以下を設定する:

| Secret 名 | 値 |
|------------|------|
| `AWS_ACCESS_KEY_ID` | 5.1 で発行したアクセスキー ID |
| `AWS_SECRET_ACCESS_KEY` | 5.1 で発行したシークレットアクセスキー |

```bash
# gh CLI を使用する場合
gh secret set AWS_ACCESS_KEY_ID --body "<ACCESS_KEY_ID>"
gh secret set AWS_SECRET_ACCESS_KEY --body "<SECRET_ACCESS_KEY>"
```

### 5.4 コードの push と CI/CD 実行

```bash
cd ~/sample_cicd

# まだ push していない場合
git add .
git commit -m "Phase 5: deployment setup"
git push origin main
```

push 後、GitHub リポジトリの **Actions** タブで CI/CD パイプラインの実行を確認する。

## 6. CI/CD デプロイ確認

### 6.1 CI ジョブの確認

GitHub Actions の CI ジョブで以下が成功することを確認:

1. **Lint** — `ruff check app/ tests/` がエラー 0 件
2. **Test** — `pytest tests/ -v` で 6 テスト全 PASS
3. **Build** — `docker build` が成功

### 6.2 CD ジョブの確認

CI ジョブ成功後、CD ジョブで以下が成功することを確認:

1. **AWS Auth** — AWS 認証成功
2. **ECR Login** — ECR ログイン成功
3. **ECR Push** — イメージのビルド・タグ付け・プッシュ成功
4. **ECS Deploy** — タスク定義の更新と ECS デプロイ成功

### 6.3 デプロイ後の動作確認

```bash
# ALB 経由でアプリケーションにアクセス
curl http://$ALB_DNS/
# → {"message":"Hello, World!"}

curl http://<ALB_DNS>/health/
# → {"status":"healthy"}
```

### 6.4 CloudWatch Logs の確認

```bash
# 最新のログストリームを確認
aws logs describe-log-streams \
  --log-group-name /ecs/sample-cicd \
  --order-by LastEventTime \
  --descending \
  --limit 1 \
  --region ap-northeast-1

# ログイベントの取得（<LOG_STREAM_NAME> を上記の結果に置き換え）
aws logs get-log-events \
  --log-group-name /ecs/sample-cicd \
  --log-stream-name app/app/06bcb5fb563048d7b43d6566c0d64cce \
  --limit 20 \
  --region ap-northeast-1
```

uvicorn の起動ログが表示されれば正常。

## 7. クリーンアップ手順

> **重要**: 学習用プロジェクトのため、動作確認後は必ずリソースを削除して AWS 費用の発生を防ぐこと。

### 7.1 費用が発生する主なリソース

| リソース | 概算費用（東京リージョン） |
|----------|--------------------------|
| ALB | 約 $0.03/時間 + トラフィック |
| Fargate (0.25 vCPU / 512 MB) | 約 $0.01/時間 |
| ECR | ストレージ $0.10/GB/月 |
| CloudWatch Logs | 取り込み $0.76/GB |

> 1 日稼働で約 $1 程度。不要時は速やかに削除すること。

### 7.2 Terraform でリソース削除

```bash
cd ~/sample_cicd/infra

# ECR リポジトリ内のイメージを先に削除（Terraform だけでは削除できない場合がある）
aws ecr batch-delete-image \
  --repository-name sample-cicd \
  --image-ids "$(aws ecr list-images --repository-name sample-cicd --query 'imageIds[*]' --output json)" \
  --region ap-northeast-1

# 全リソース削除
terraform destroy
```

`Enter a value:` に対して `yes` を入力する。

### 7.3 IAM ユーザーのクリーンアップ

```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# アクセスキーの削除
ACCESS_KEY_ID=$(aws iam list-access-keys --user-name github-actions-sample-cicd --query 'AccessKeyMetadata[0].AccessKeyId' --output text)
aws iam delete-access-key \
  --user-name github-actions-sample-cicd \
  --access-key-id $ACCESS_KEY_ID

# ポリシーのデタッチ
aws iam detach-user-policy \
  --user-name github-actions-sample-cicd \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/github-actions-sample-cicd

# ポリシーの削除
aws iam delete-policy \
  --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/github-actions-sample-cicd

# IAM ユーザーの削除
aws iam delete-user --user-name github-actions-sample-cicd
```

### 7.4 GitHub Secrets の削除

GitHub リポジトリの **Settings → Secrets and variables → Actions** から以下を削除:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 7.5 ローカルの Terraform state 削除

```bash
cd ~/sample_cicd/infra
rm -f terraform.tfstate terraform.tfstate.backup
rm -rf .terraform .terraform.lock.hcl
```

## 8. トラブルシューティング

### ECS タスクが起動しない

```bash
# タスクの停止理由を確認
aws ecs list-tasks --cluster sample-cicd --desired-status STOPPED --region ap-northeast-1
aws ecs describe-tasks \
  --cluster sample-cicd \
  --tasks <TASK_ARN> \
  --region ap-northeast-1 \
  --query 'tasks[0].stoppedReason'
```

よくある原因:
- ECR にイメージが存在しない → セクション 4 の手動 push を実行
- セキュリティグループでポート 8000 が開いていない → `infra/security_groups.tf` を確認
- タスク実行ロールの権限不足 → `infra/iam.tf` を確認

### ALB のヘルスチェックが失敗する

```bash
# ターゲットグループのヘルスステータスを確認
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --region ap-northeast-1
```

よくある原因:
- アプリケーションが `/health` エンドポイントで 200 を返していない
- ECS タスクがまだ起動中 → 数分待ってから再確認
- セキュリティグループで ALB → ECS (8000) の通信が許可されていない

### GitHub Actions CD ジョブが失敗する

- **AWS credentials error**: GitHub Secrets の `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` を確認
- **ECR push failed**: IAM ポリシーに ECR push 権限があるか確認（セクション 5.2）
- **ECS deploy failed**: IAM ポリシーに ECS update 権限と `iam:PassRole` があるか確認
