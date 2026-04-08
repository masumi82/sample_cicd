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
- Bootstrap リソース（S3 tfstate, DynamoDB tflock）は **削除しない**（Remote State 基盤）
- `prod` 環境の場合は二重確認を要求
- Hosted Zone / ドメイン登録は **削除しない**（ドメイン費用が無駄になる）
