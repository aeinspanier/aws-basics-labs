# aws-basics-labs
Small, isolated deployments to learn individual services.

### What this includes
- **S3**: Private bucket with versioning and default SSE (SSE-S3)
- **DynamoDB**: On-demand table with a simple primary key
- **Lambda**: Python 3.12 function that writes to DynamoDB and S3
- **IAM basics**: Minimal execution role with least-privilege to the above
- **CloudWatch**: Log group with retention and an alarm on Lambda errors

### Prerequisites
- **AWS CLI** configured (`aws configure`) with permissions to create resources
- **Terraform** v1.6+ installed

### Deploy
```bash
cd terraform
terraform init
terraform apply
```

Outputs will include the S3 bucket, DynamoDB table, and Lambda function names.

### Invoke the Lambda
```bash
aws lambda invoke \
  --function-name aws-basics-labs-dev-hello \
  --payload '{"hello":"world"}' \
  out.json && cat out.json
```

Check logs:
```bash
aws logs tail \
  /aws/lambda/aws-basics-labs-dev-hello \
  --follow
```

### Destroy
```bash
cd terraform
terraform destroy
```

### Structure
```
aws-basics-labs/
  ├─ terraform/            # IaC for all labs
  │   ├─ provider.tf
  │   ├─ variables.tf
  │   ├─ main.tf
  │   └─ outputs.tf
  └─ lambda/
      └─ hello/
          └─ app.py       # Sample Python Lambda
```

### Notes
- The Lambda writes a JSON file to S3 and a row to DynamoDB on each invocation.
- Bucket names must be globally unique; a short random suffix is added automatically.
