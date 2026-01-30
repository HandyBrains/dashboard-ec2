# EC2 Dashboard - AWS CloudShell Deployment

Simple EC2 instance dashboard showing Name, Instance ID, Private IP, and State.

## 🚀 Quick Deploy (AWS CloudShell)

### Step 1: Open AWS CloudShell
- Login to AWS Console (eu-west-1 region)
- Click CloudShell icon (>_) in top navigation

### Step 2: Run This Command

```bash
curl -o deploy.sh https://raw.githubusercontent.com/HandyBrains/dashboard-ec2/main/deploy.sh && chmod +x deploy.sh && ./deploy.sh
```

### Step 3: Download Dashboard
- In CloudShell: **Actions** → **Download file**
- Enter: `dashboard.html`
- Open in browser

## ✅ What Gets Created

- Lambda function: `EC2Dashboard`
- IAM role: `EC2DashboardRole`
- API Gateway: `EC2DashboardAPI`
- HTML dashboard with embedded API endpoint

## 📤 SharePoint Upload

1. Download `dashboard.html` from CloudShell
2. Upload to SharePoint Documents library
3. Click to view

## 🧹 Cleanup

```bash
# Delete Lambda
aws lambda delete-function --function-name EC2Dashboard --region eu-west-1

# Delete API Gateway
API_ID=$(aws apigateway get-rest-apis --query "items[?name=='EC2DashboardAPI'].id" --output text --region eu-west-1)
aws apigateway delete-rest-api --rest-api-id $API_ID --region eu-west-1

# Delete IAM role
aws iam detach-role-policy --role-name EC2DashboardRole --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam detach-role-policy --role-name EC2DashboardRole --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
aws iam delete-role --role-name EC2DashboardRole
```

## 🐛 Troubleshooting

**Error: Role not found**
- Wait 15 seconds and retry (IAM propagation delay)

**No instances showing**
- Check Lambda CloudWatch logs
- Verify EC2 instances exist in eu-west-1

**403 Forbidden**
- Re-run Lambda permission command from script

## 💰 Cost

Free tier eligible - $0/month for typical usage
