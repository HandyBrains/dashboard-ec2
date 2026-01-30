#!/bin/bash
# EC2 Dashboard - CloudShell Deployment
# Region: eu-west-1
# Run in AWS CloudShell

set -e

echo "🚀 EC2 Dashboard Deployment"
echo "============================"
echo ""

# Set region explicitly
AWS_REGION="eu-west-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "📍 Region: $AWS_REGION"
echo "📍 Account: $AWS_ACCOUNT_ID"
echo ""

# Create Lambda function
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
                'state': instance['State']['Name']
            })
    
    return {
        'statusCode': 200,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*'
        },
        'body': json.dumps(instances)
    }
EOF

echo "✅ Lambda function file created"

# Create trust policy
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

echo "✅ Trust policy created"
echo ""
echo "📋 Step 1: Creating IAM Role..."

# Create role
aws iam create-role \
  --role-name EC2DashboardRole \
  --assume-role-policy-document file://trust-policy.json \
  --region $AWS_REGION 2>/dev/null && echo "Role created" || echo "Role already exists"

# Attach policies
aws iam attach-role-policy \
  --role-name EC2DashboardRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole 2>/dev/null || true

aws iam attach-role-policy \
  --role-name EC2DashboardRole \
  --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess 2>/dev/null || true

echo "✅ IAM Role configured"
echo "⏳ Waiting 15 seconds for IAM propagation..."
sleep 15

echo ""
echo "📦 Step 2: Deploying Lambda..."

# Zip Lambda
zip -q lambda_function.zip lambda_function.py
echo "✅ Lambda zipped"

# Delete existing function
aws lambda delete-function \
  --function-name EC2Dashboard \
  --region $AWS_REGION 2>/dev/null && echo "Deleted existing Lambda" || echo "No existing Lambda"

sleep 3

# Create Lambda
aws lambda create-function \
  --function-name EC2Dashboard \
  --runtime python3.11 \
  --role arn:aws:iam::${AWS_ACCOUNT_ID}:role/EC2DashboardRole \
  --handler lambda_function.lambda_handler \
  --zip-file fileb://lambda_function.zip \
  --timeout 30 \
  --region $AWS_REGION

echo "✅ Lambda deployed"

echo ""
echo "🌐 Step 3: Creating API Gateway..."

# Delete existing API
EXISTING_API=$(aws apigateway get-rest-apis \
  --query "items[?name=='EC2DashboardAPI'].id" \
  --output text \
  --region $AWS_REGION)

if [ ! -z "$EXISTING_API" ]; then
  echo "Deleting existing API: $EXISTING_API"
  aws apigateway delete-rest-api \
    --rest-api-id $EXISTING_API \
    --region $AWS_REGION
  sleep 3
fi

# Create REST API
API_ID=$(aws apigateway create-rest-api \
  --name EC2DashboardAPI \
  --query 'id' \
  --output text \
  --region $AWS_REGION)

echo "✅ API created: $API_ID"

# Get root resource
ROOT_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --query 'items[0].id' \
  --output text \
  --region $AWS_REGION)

# Create /instances resource
RESOURCE_ID=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_ID \
  --path-part instances \
  --query 'id' \
  --output text \
  --region $AWS_REGION)

echo "✅ Resource created"

# Create GET method
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --authorization-type NONE \
  --region $AWS_REGION

echo "✅ GET method created"

# Integrate with Lambda
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri arn:aws:apigateway:${AWS_REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${AWS_REGION}:${AWS_ACCOUNT_ID}:function:EC2Dashboard/invocations \
  --region $AWS_REGION

echo "✅ Lambda integration configured"

# Deploy API
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --region $AWS_REGION

echo "✅ API deployed to prod stage"

# Add Lambda permission
aws lambda add-permission \
  --function-name EC2Dashboard \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${AWS_REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/*" \
  --region $AWS_REGION 2>/dev/null || echo "Permission already exists"

echo "✅ Lambda permission granted"

# API Endpoint
API_ENDPOINT="https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod/instances"

echo ""
echo "📄 Step 4: Creating HTML Dashboard..."

# Create HTML with embedded API endpoint
cat > dashboard.html << HTMLEOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EC2 Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }
        .container { max-width: 1200px; margin: 0 auto; }
        h1 { color: white; text-align: center; margin-bottom: 30px; font-size: 2em; text-shadow: 2px 2px 4px rgba(0,0,0,0.2); }
        .refresh-btn { display: block; margin: 0 auto 20px; padding: 12px 30px; background: white; border: none; border-radius: 25px; font-size: 16px; font-weight: 600; cursor: pointer; box-shadow: 0 4px 15px rgba(0,0,0,0.2); transition: transform 0.2s; }
        .refresh-btn:hover { transform: translateY(-2px); box-shadow: 0 6px 20px rgba(0,0,0,0.3); }
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
        <button class="refresh-btn" onclick="loadInstances()">🔄 Refresh</button>
        <div class="card"><div id="content"><div class="loading">Loading...</div></div></div>
    </div>
    <script>
        const API_ENDPOINT = '${API_ENDPOINT}';
        async function loadInstances() {
            const content = document.getElementById('content');
            content.innerHTML = '<div class="loading">Loading...</div>';
            try {
                const response = await fetch(API_ENDPOINT);
                if (!response.ok) throw new Error('Failed to fetch data');
                const instances = await response.json();
                if (instances.length === 0) {
                    content.innerHTML = '<div class="loading">No instances found</div>';
                    return;
                }
                let html = '<table><thead><tr><th>Name</th><th>Instance ID</th><th>Private IP</th><th>State</th></tr></thead><tbody>';
                instances.forEach(inst => {
                    const stateClass = inst.state === 'running' ? 'running' : 'stopped';
                    html += \`<tr><td><strong>\${inst.name}</strong></td><td>\${inst.instanceId}</td><td>\${inst.privateIp}</td><td><span class="state \${stateClass}">\${inst.state}</span></td></tr>\`;
                });
                html += '</tbody></table>';
                content.innerHTML = html;
            } catch (error) {
                content.innerHTML = \`<div class="error">❌ Error: \${error.message}</div>\`;
            }
        }
        window.onload = () => loadInstances();
    </script>
</body>
</html>
HTMLEOF

echo "✅ Dashboard HTML created"

echo ""
echo "🎉 Deployment Complete!"
echo "======================="
echo ""
echo "📍 API Endpoint:"
echo "$API_ENDPOINT"
echo ""
echo "📝 Next Steps:"
echo "1. Download dashboard.html from CloudShell"
echo "   Actions → Download file → dashboard.html"
echo ""
echo "2. Open dashboard.html in your browser"
echo ""
echo "3. Or upload to SharePoint"
echo ""
echo "🧪 Test API now:"
echo "curl $API_ENDPOINT"
echo ""
