---
name: infra-cleanup
description: "Clean up all AWS infrastructure. Handles S3/ECR emptying, Secrets Manager restore, terraform destroy, and orphan resource detection."
user-invocable: true
---

# Infra Cleanup

AWS インフラを安全にクリーンアップする。`terraform destroy` の前処理（S3/ECR の中身削除等）を自動化。

All output must be in Japanese.

## 実行フロー

### Step 1: 現状確認
- `terraform state list` で管理リソース数を表示
- `terraform workspace show` で対象環境を確認
- ユーザーに確認:「{ENV} 環境の全リソースを削除します。よろしいですか？」

### Step 2: 前処理（terraform destroy が失敗するリソース）
以下を terraform destroy **前に** 実行:

```bash
# ECR: イメージを全削除
aws ecr list-images --repository-name sample-cicd-$ENV --query "imageIds[*]" | \
  xargs -I{} aws ecr batch-delete-image --repository-name sample-cicd-$ENV --image-ids '{}'

# S3 webui: 中身を空に
aws s3 rm s3://sample-cicd-$ENV-webui --recursive

# S3 attachments: 中身を空に
aws s3 rm s3://sample-cicd-$ENV-attachments --recursive
```

### Step 3: Secrets Manager チェック
削除予定（scheduled for deletion）のシークレットがある場合:
```bash
aws secretsmanager restore-secret --secret-id "sample-cicd-$ENV/db-credentials"
```
→ 復元してから terraform destroy に任せる

### Step 4: terraform destroy
```bash
cd infra
terraform workspace select $ENV
terraform destroy -var-file=$ENV.tfvars -auto-approve
```
- タイムアウト: 最大 30 分（Lambda VPC ENI の削除に時間がかかる）
- 失敗時: エラーメッセージを分析して個別対処

### Step 5: 残存リソース確認
destroy 後に以下を確認:
- `terraform state list` が空であること
- AWS CLI でリソースが残っていないか確認:
  - ECR, S3, Secrets Manager, CloudFront, ECS, RDS, VPC

### Step 6: 結果レポート
削除されたリソース数と残存リソース（あれば）を報告。

## 注意事項
- `prod` 環境の場合は二重確認を要求

## 保持リソース（削除しない）

以下のリソースは **常時残しておく**。無料または誤差レベルのコスト（合計 ~$0.55/月）で、CI/CD パイプラインの前提となるため。

| リソース | Terraform リソース名 | 月額 | 理由 |
|----------|---------------------|------|------|
| IAM OIDC Provider | `aws_iam_openid_connect_provider.github_actions` | $0 | CI の terraform-plan で OIDC 認証に必要 |
| IAM Role (GitHub Actions) | `aws_iam_role.github_actions` | $0 | 同上 |
| IAM Role Policy (GitHub Actions) | `aws_iam_role_policy.github_actions` | $0 | 同上 |
| S3 (terraform-state) | Bootstrap 管理 | ~$0.02 | Remote State。消すと全インフラ管理不能 |
| DynamoDB (terraform-lock) | Bootstrap 管理 | $0 | State ロック。Free Tier 内 |
| Route 53 Hosted Zone | `aws_route53_zone` (該当あれば) | $0.50 | カスタムドメイン前提。再作成で NS 変更が必要になる |
| ECR Repository | `aws_ecr_repository.app` | ~$0.03 | イメージ 1 つ残す場合。空なら $0 |
| Cognito User Pool | `aws_cognito_user_pool.main` | $0 | 50,000 MAU まで無料 |
| Cognito App Client | `aws_cognito_user_pool_client.spa` | $0 | User Pool とセット |

### 実装方法

`terraform destroy` の代わりに、保持リソースを除外した targeted destroy を実行するか、保持リソースを `terraform state rm` で state から外してから destroy する。

```bash
# 方法: 保持リソースを state から退避 → destroy → state に戻す
# Step 1: 保持リソースの state を退避
terraform state pull > backup.tfstate

# Step 2: 保持リソースを state から除外
terraform state rm aws_iam_openid_connect_provider.github_actions
terraform state rm aws_iam_role.github_actions
terraform state rm aws_iam_role_policy.github_actions
terraform state rm aws_ecr_repository.app
terraform state rm aws_cognito_user_pool.main
terraform state rm aws_cognito_user_pool_client.spa

# Step 3: destroy（保持リソース以外を削除）
terraform destroy -var-file=$ENV.tfvars -auto-approve

# Step 4: 保持リソースを state に再 import
terraform import aws_iam_openid_connect_provider.github_actions <arn>
terraform import aws_iam_role.github_actions <role-name>
# ... 以下同様
```

> **注**: Bootstrap リソース（S3 tfstate, DynamoDB tflock）は Terraform 管理外（bootstrap/ で別管理）のため上記に含まない。
