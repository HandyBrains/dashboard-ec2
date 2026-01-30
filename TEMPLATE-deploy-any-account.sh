#!/bin/bash
# EC2 Dashboard - Reusable Deployment Template
# Works for ANY AWS account and region
# Run in AWS CloudShell

set -e

echo "🚀 EC2 Dashboard - Automated Deployment"
echo "========================================"
echo ""

# Get AWS account details
AWS_REGION=$(aws configure get region 2>/dev/null || echo "eu-west-1")
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ACCOUNT_ALIAS=$(aws iam list-account-aliases --query 'AccountAliases[0]' --output text 2>/dev/null || echo "aws-account")

echo "📍 Deploying to:"
echo "   Account ID: $AWS_ACCOUNT_ID"
echo "   Account Alias: $ACCOUNT_ALIAS"
echo "   Region: $AWS_REGION"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 1
fi

# Create Lambda function
echo ""
echo "📦 Step 1: Creating Lambda function..."
cat > lambda_function.py << 'EOF'
import json
import boto3

def lambda_handler(event, context):
    ec2 = boto3.client('ec2')
    response = ec2.describe_instances()
    
    instances = []
    for reservation in response['Reservations']:
        for instance in reservation['Instances']:
            tags = {tag['Key']: tag['Value'] for tag in instance.get('Tags', [])}
            instances.append({
                'name': tags.get('Name', 'N/A'),
                'instanceId': instance['InstanceId'],
                'privateIp': instance.get('PrivateIpAddress', 'N/A'),
                'state': instance['State']['Name'],
                'tags': tags
            })
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Allow-Methods': 'GET,OPTIONS'
        },
        'body': json.dumps(instances)
    }
EOF

# Create IAM role
echo "📋 Step 2: Creating IAM role..."
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Service": "lambda.amazonaws.com"},
    "Action": "sts:AssumeRole"
  }]
}
EOF

ROLE_NAME="EC2Dashboard-${ACCOUNT_ALIAS}-Role"
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust-policy.json \
  --region $AWS_REGION 2>/dev/null || echo "Role exists"

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess 2>/dev/null || true

echo "✅ IAM role ready"
echo "⏳ Waiting 15 seconds for IAM propagation..."
sleep 15

# Deploy Lambda
echo ""
echo "📦 Step 3: Deploying Lambda..."
zip -q lambda_function.zip lambda_function.py

LAMBDA_NAME="EC2Dashboard-${ACCOUNT_ALIAS}"
aws lambda delete-function --function-name $LAMBDA_NAME --region $AWS_REGION 2>/dev/null || true
sleep 2

aws lambda create-function \
  --function-name $LAMBDA_NAME \
  --runtime python3.11 \
  --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/${ROLE_NAME} \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda_function.zip \
  --timeout 30 \
  --region $AWS_REGION

echo "✅ Lambda deployed"

# Create API Gateway
echo ""
echo "🌐 Step 4: Creating API Gateway..."
API_NAME="EC2Dashboard-${ACCOUNT_ALIAS}-API"

# Delete existing API if present
EXISTING_API=$(aws apigateway get-rest-apis --query "items[?name=='${API_NAME}'].id" --output text --region $AWS_REGION)
if [ ! -z "$EXISTING_API" ]; then
  echo "Deleting existing API..."
  aws apigateway delete-rest-api --rest-api-id $EXISTING_API --region $AWS_REGION
  sleep 2
fi

API_ID=$(aws apigateway create-rest-api --name $API_NAME --region $AWS_REGION --query 'id' --output text)
ROOT_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query 'items[0].id' --output text --region $AWS_REGION)
RESOURCE_ID=$(aws apigateway create-resource --rest-api-id $API_ID --parent-id $ROOT_ID --path-part instances --query 'id' --output text --region $AWS_REGION)

aws apigateway put-method --rest-api-id $API_ID --resource-id $RESOURCE_ID --http-method GET --authorization-type NONE --region $AWS_REGION

aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:${LAMBDA_NAME}/invocations \
  --region $AWS_REGION

aws apigateway create-deployment --rest-api-id $API_ID --stage-name prod --region $AWS_REGION

aws lambda add-permission \
  --function-name $LAMBDA_NAME \
  --statement-id api-$(date +%s) \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
  --region $AWS_REGION 2>/dev/null || true

echo "✅ API Gateway deployed"

# API Endpoint
API_ENDPOINT="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod/instances"

# Create HTML dashboard
echo ""
echo "📄 Step 5: Creating HTML dashboard..."
cat > ec2-dashboard-${ACCOUNT_ALIAS}.html << HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EC2 Dashboard - ${ACCOUNT_ALIAS}</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { color: white; text-align: center; margin-bottom: 10px; font-size: 2em; text-shadow: 2px 2px 4px rgba(0,0,0,0.2); }
        .subtitle { color: white; text-align: center; margin-bottom: 30px; opacity: 0.9; }
        .controls { background: white; border-radius: 15px; padding: 20px; margin-bottom: 20px; box-shadow: 0 4px 15px rgba(0,0,0,0.2); }
        .filter-row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
        input { padding: 10px; border: 1px solid #ddd; border-radius: 8px; font-size: 14px; flex: 1; min-width: 150px; }
        button { padding: 10px 20px; background: #667eea; color: white; border: none; border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; transition: background 0.2s; }
        button:hover { background: #5568d3; }
        .btn-clear { background: #6c757d; }
        .btn-clear:hover { background: #5a6268; }
        .info { margin-top: 10px; color: #666; font-size: 14px; }
        .card { background: white; border-radius: 15px; padding: 25px; box-shadow: 0 10px 30px rgba(0,0,0,0.2); }
        table { width: 100%; border-collapse: collapse; }
        th { background: #667eea; color: white; padding: 15px; text-align: left; font-weight: 600; text-transform: uppercase; font-size: 12px; letter-spacing: 1px; }
        td { padding: 15px; border-bottom: 1px solid #f0f0f0; }
        tr:hover { background: #f8f9ff; }
        .state { display: inline-block; padding: 5px 12px; border-radius: 20px; font-size: 12px; font-weight: 600; text-transform: uppercase; }
        .running { background: #d4edda; color: #155724; }
        .stopped { background: #f8d7da; color: #721c24; }
        .loading { text-align: center; padding: 40px; color: #666; font-size: 18px; }
        .error { background: #f8d7da; color: #721c24; padding: 15px; border-radius: 8px; margin: 20px 0; text-align: center; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🖥️ EC2 Dashboard</h1>
        <div class="subtitle">Account: ${ACCOUNT_ALIAS} | Region: ${AWS_REGION}</div>
        
        <div class="controls">
            <div class="filter-row">
                <input type="text" id="tagKey" placeholder="Tag Key (e.g., EnvironmentType)" />
                <input type="text" id="tagValue" placeholder="Tag Value (e.g., Test)" />
                <button onclick="filterInstances()">🔍 Filter</button>
                <button class="btn-clear" onclick="clearFilter()">✖ Clear</button>
                <button onclick="loadInstances()">🔄 Refresh</button>
            </div>
            <div class="info" id="info">Click Refresh to load all instances</div>
        </div>
        
        <div class="card">
            <div id="content">
                <div class="loading">Click Refresh to load instances</div>
            </div>
        </div>
    </div>
    <script>
        const API_ENDPOINT = '${API_ENDPOINT}';
        let allInstances = [];
        
        async function loadInstances() {
            const content = document.getElementById('content');
            const info = document.getElementById('info');
            content.innerHTML = '<div class="loading">Loading...</div>';
            info.textContent = 'Loading...';
            
            try {
                const response = await fetch(API_ENDPOINT);
                if (!response.ok) throw new Error('Failed to fetch data');
                allInstances = await response.json();
                info.textContent = \`Total instances: \${allInstances.length}\`;
                displayInstances(allInstances);
            } catch (error) {
                content.innerHTML = \`<div class="error">❌ Error: \${error.message}</div>\`;
                info.textContent = 'Error loading instances';
            }
        }
        
        function filterInstances() {
            const tagKey = document.getElementById('tagKey').value.trim();
            const tagValue = document.getElementById('tagValue').value.trim();
            const info = document.getElementById('info');
            
            if (!tagKey || !tagValue) {
                alert('Please enter both Tag Key and Tag Value');
                return;
            }
            
            const filtered = allInstances.filter(inst => 
                inst.tags[tagKey] && inst.tags[tagKey].toLowerCase() === tagValue.toLowerCase()
            );
            
            info.textContent = \`Filtered: \${filtered.length} of \${allInstances.length} instances (\${tagKey}=\${tagValue})\`;
            displayInstances(filtered);
        }
        
        function clearFilter() {
            document.getElementById('tagKey').value = '';
            document.getElementById('tagValue').value = '';
            document.getElementById('info').textContent = \`Total instances: \${allInstances.length}\`;
            displayInstances(allInstances);
        }
        
        function displayInstances(instances) {
            const content = document.getElementById('content');
            if (instances.length === 0) {
                content.innerHTML = '<div class="loading">No instances found</div>';
                return;
            }
            
            let html = '<table><thead><tr><th>Name</th><th>Instance ID</th><th>Private IP</th><th>State</th></tr></thead><tbody>';
            instances.forEach(inst => {
                const stateClass = inst.state === 'running' ? 'running' : 'stopped';
                html += \`<tr>
                    <td><strong>\${inst.name}</strong></td>
                    <td>\${inst.instanceId}</td>
                    <td>\${inst.privateIp}</td>
                    <td><span class="state \${stateClass}">\${inst.state}</span></td>
                </tr>\`;
            });
            html += '</tbody></table>';
            content.innerHTML = html;
        }
        
        window.onload = () => loadInstances();
    </script>
</body>
</html>
HTMLEOF

echo "✅ HTML dashboard created"

# Save deployment info
cat > deployment-info-${ACCOUNT_ALIAS}.txt << EOF
EC2 Dashboard Deployment Information
=====================================

Account ID: $AWS_ACCOUNT_ID
Account Alias: $ACCOUNT_ALIAS
Region: $AWS_REGION
Deployment Date: $(date)

Resources Created:
------------------
Lambda Function: $LAMBDA_NAME
IAM Role: $ROLE_NAME
API Gateway: $API_NAME
API ID: $API_ID

API Endpoint:
-------------
$API_ENDPOINT

HTML Dashboard:
---------------
ec2-dashboard-${ACCOUNT_ALIAS}.html

Test API:
---------
curl $API_ENDPOINT

Cleanup Commands:
-----------------
aws lambda delete-function --function-name $LAMBDA_NAME --region $AWS_REGION
aws apigateway delete-rest-api --rest-api-id $API_ID --region $AWS_REGION
aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
aws iam detach-role-policy --role-name $ROLE_NAME --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
aws iam delete-role --role-name $ROLE_NAME
EOF

echo ""
echo "🎉 Deployment Complete!"
echo "======================="
echo ""
echo "📍 Account: $ACCOUNT_ALIAS ($AWS_ACCOUNT_ID)"
echo "📍 Region: $AWS_REGION"
echo ""
echo "📍 API Endpoint:"
echo "   $API_ENDPOINT"
echo ""
echo "📄 Files Created:"
echo "   - ec2-dashboard-${ACCOUNT_ALIAS}.html"
echo "   - deployment-info-${ACCOUNT_ALIAS}.txt"
echo ""
echo "📝 Next Steps:"
echo "   1. Download: ec2-dashboard-${ACCOUNT_ALIAS}.html"
echo "   2. Open in browser"
echo "   3. Upload to SharePoint"
echo ""
echo "🧪 Test API:"
echo "   curl $API_ENDPOINT"
echo ""
