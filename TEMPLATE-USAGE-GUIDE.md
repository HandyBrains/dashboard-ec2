# EC2 Dashboard - Reusable Template Guide

## 🎯 Use This Template for ANY AWS Account

This template automatically deploys the EC2 Dashboard to any AWS account with unique resource names.

---

## 🚀 Quick Deploy to New Account

### Step 1: Login to Target AWS Account
1. Open AWS Console for the target account
2. Open CloudShell (click >_ icon)
3. Wait for CloudShell to initialize

### Step 2: Download and Run Template
```bash
curl -o deploy.sh https://raw.githubusercontent.com/HandyBrains/dashboard-ec2/refs/heads/main/TEMPLATE-deploy-any-account.sh
chmod +x deploy.sh
./deploy.sh
```

### Step 3: Download Dashboard
- CloudShell: **Actions** → **Download file**
- Enter: `ec2-dashboard-ACCOUNT-NAME.html`
- Open in browser

---

## 📋 What Gets Created (Per Account)

| Resource | Naming Pattern | Example |
|----------|---------------|---------|
| Lambda Function | EC2Dashboard-{AccountAlias} | EC2Dashboard-prod-account |
| IAM Role | EC2Dashboard-{AccountAlias}-Role | EC2Dashboard-prod-account-Role |
| API Gateway | EC2Dashboard-{AccountAlias}-API | EC2Dashboard-prod-account-API |
| HTML File | ec2-dashboard-{AccountAlias}.html | ec2-dashboard-prod-account.html |

**Benefits:**
- ✅ Unique names per account (no conflicts)
- ✅ Easy to identify which account
- ✅ Can deploy to multiple accounts

---

## 🔄 Deploy to Multiple Accounts

### Account 1: Production
```bash
# Login to Production account
# Run in CloudShell:
curl -o deploy.sh https://raw.githubusercontent.com/HandyBrains/dashboard-ec2/refs/heads/main/TEMPLATE-deploy-any-account.sh
chmod +x deploy.sh
./deploy.sh
# Download: ec2-dashboard-prod.html
```

### Account 2: Development
```bash
# Login to Development account
# Run in CloudShell:
curl -o deploy.sh https://raw.githubusercontent.com/HandyBrains/dashboard-ec2/refs/heads/main/TEMPLATE-deploy-any-account.sh
chmod +x deploy.sh
./deploy.sh
# Download: ec2-dashboard-dev.html
```

### Account 3: Staging
```bash
# Login to Staging account
# Run in CloudShell:
curl -o deploy.sh https://raw.githubusercontent.com/HandyBrains/dashboard-ec2/refs/heads/main/TEMPLATE-deploy-any-account.sh
chmod +x deploy.sh
./deploy.sh
# Download: ec2-dashboard-staging.html
```

---

## 📁 Organize Your Dashboards

```
My-EC2-Dashboards/
├── ec2-dashboard-prod.html          (Production account)
├── ec2-dashboard-dev.html           (Development account)
├── ec2-dashboard-staging.html       (Staging account)
├── ec2-dashboard-test.html          (Test account)
└── deployment-info/
    ├── deployment-info-prod.txt
    ├── deployment-info-dev.txt
    ├── deployment-info-staging.txt
    └── deployment-info-test.txt
```

---

## 🎨 Customization Options

### Change Region
Edit the script or set before running:
```bash
export AWS_DEFAULT_REGION=us-east-1
./deploy.sh
```

### Custom Resource Names
Edit these lines in the script:
```bash
ROLE_NAME="MyCustom-EC2Dashboard-Role"
LAMBDA_NAME="MyCustom-EC2Dashboard"
API_NAME="MyCustom-EC2Dashboard-API"
```

### Change Dashboard Title
Edit HTML section in script:
```html
<title>My Custom EC2 Dashboard</title>
<h1>🖥️ My Custom Dashboard</h1>
```

---

## 🔐 Security Best Practices

### For Production Accounts:
1. **Add API Key Authentication:**
```bash
aws apigateway create-api-key --name EC2DashboardKey-prod --enabled
aws apigateway create-usage-plan --name EC2DashboardPlan-prod
```

2. **Restrict IAM Role:**
   - Use least privilege
   - Add resource tags
   - Enable CloudTrail logging

3. **Use Private API:**
   - Deploy API in VPC
   - Use VPC endpoints
   - Restrict to internal network

---

## 📊 Multi-Account Dashboard (Advanced)

### Option 1: Separate Dashboards
- Deploy to each account
- One HTML file per account
- Users switch between files

### Option 2: Unified Dashboard
Create a master HTML that calls multiple APIs:
```javascript
const ACCOUNTS = {
    'Production': 'https://api1.execute-api.eu-west-1.amazonaws.com/prod/instances',
    'Development': 'https://api2.execute-api.eu-west-1.amazonaws.com/prod/instances',
    'Staging': 'https://api3.execute-api.eu-west-1.amazonaws.com/prod/instances'
};
```

---

## 🧹 Cleanup Per Account

Each deployment creates a `deployment-info-{account}.txt` file with cleanup commands.

**Quick cleanup:**
```bash
# Use the commands from deployment-info file
aws lambda delete-function --function-name EC2Dashboard-ACCOUNT --region REGION
aws apigateway delete-rest-api --rest-api-id API_ID --region REGION
aws iam detach-role-policy --role-name EC2Dashboard-ACCOUNT-Role --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam detach-role-policy --role-name EC2Dashboard-ACCOUNT-Role --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
aws iam delete-role --role-name EC2Dashboard-ACCOUNT-Role
```

---

## 💡 Use Cases

### 1. MSP (Managed Service Provider)
- Deploy to all client accounts
- Branded dashboards per client
- Centralized monitoring

### 2. Multi-Account Organization
- Deploy to all AWS accounts
- Separate dashboards per environment
- Easy account switching

### 3. Development Teams
- Each team has own account
- Each team has own dashboard
- No cross-account access needed

---

## 🎯 Template Features

✅ **Auto-detects account** - Uses account alias/ID
✅ **Unique resource names** - No conflicts between accounts
✅ **Region-aware** - Uses current CloudShell region
✅ **Idempotent** - Safe to run multiple times
✅ **Self-documenting** - Creates deployment info file
✅ **Clean HTML** - Account name in dashboard title

---

## 📞 Troubleshooting

**Script fails on IAM role creation:**
- Role might exist from previous run
- Script continues anyway (safe)

**API returns 403:**
- Wait 30 seconds for IAM propagation
- Re-run the Lambda permission command

**Wrong account deployed:**
- Check `aws sts get-caller-identity`
- Verify you're in correct CloudShell session

---

## 🚀 Next Steps

1. **Upload template to GitHub** (already done!)
2. **Share with team** - One command deployment
3. **Deploy to all accounts** - Consistent dashboards
4. **Customize per account** - Branding, colors, features

---

## 📖 Related Files

- `TEMPLATE-deploy-any-account.sh` - Main deployment script
- `FINAL-lambda-function.py` - Lambda code (embedded in script)
- `FINAL-EXPLANATION.md` - Technical details
- `FINAL-QUICK-REFERENCE.md` - Quick commands

---

## ✅ Success Checklist

- [ ] Template script uploaded to GitHub
- [ ] Tested in Account 1
- [ ] Tested in Account 2
- [ ] HTML dashboards downloaded
- [ ] Deployment info files saved
- [ ] Team trained on deployment process
- [ ] Documentation shared

---

**You now have a fully reusable template for deploying EC2 dashboards to any AWS account!** 🎉
