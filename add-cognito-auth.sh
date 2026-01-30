#!/bin/bash
# Add Cognito Authentication to EC2 Dashboard API
# Run in AWS CloudShell

set -e

echo "🔐 Add Cognito Authentication to EC2 Dashboard"
echo "=============================================="
echo ""

# Get inputs
read -p "Enter your API Gateway ID (e.g., p9bjabfhsb): " API_ID
read -p "Enter user pool name (e.g., EC2DashboardUsers): " USER_POOL_NAME
read -p "Enter first user email: " USER_EMAIL

AWS_REGION=$(aws configure get region || echo "eu-west-1")
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo ""
echo "📋 Configuration:"
echo "   API ID: $API_ID"
echo "   User Pool: $USER_POOL_NAME"
echo "   Region: $AWS_REGION"
echo "   First User: $USER_EMAIL"
echo ""
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Step 1: Create Cognito User Pool
echo ""
echo "📦 Step 1: Creating Cognito User Pool..."
USER_POOL_ID=$(aws cognito-idp create-user-pool \
  --pool-name $USER_POOL_NAME \
  --auto-verified-attributes email \
  --policies "PasswordPolicy={MinimumLength=8,RequireUppercase=true,RequireLowercase=true,RequireNumbers=true,RequireSymbols=false}" \
  --query 'UserPool.Id' \
  --output text)

echo "✅ User Pool created: $USER_POOL_ID"

# Step 2: Create App Client
echo ""
echo "📱 Step 2: Creating App Client..."
APP_CLIENT_ID=$(aws cognito-idp create-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-name EC2DashboardClient \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --query 'UserPoolClient.ClientId' \
  --output text)

echo "✅ App Client created: $APP_CLIENT_ID"

# Step 3: Create first user
echo ""
echo "👤 Step 3: Creating first user..."
aws cognito-idp admin-create-user \
  --user-pool-id $USER_POOL_ID \
  --username $USER_EMAIL \
  --user-attributes Name=email,Value=$USER_EMAIL Name=email_verified,Value=true \
  --temporary-password "TempPass123!" \
  --message-action SUPPRESS

echo "✅ User created: $USER_EMAIL"
echo "   Temporary password: TempPass123!"

# Step 4: Create Cognito Authorizer
echo ""
echo "🔒 Step 4: Creating API Gateway Authorizer..."
AUTHORIZER_ID=$(aws apigateway create-authorizer \
  --rest-api-id $API_ID \
  --name CognitoAuthorizer \
  --type COGNITO_USER_POOLS \
  --provider-arns arn:aws:cognito-idp:${AWS_REGION}:${AWS_ACCOUNT_ID}:userpool/${USER_POOL_ID} \
  --identity-source method.request.header.Authorization \
  --query 'id' \
  --output text)

echo "✅ Authorizer created: $AUTHORIZER_ID"

# Step 5: Update API Gateway method to use authorizer
echo ""
echo "🔧 Step 5: Updating API Gateway method..."
RESOURCE_ID=$(aws apigateway get-resources --rest-api-id $API_ID --query "items[?path=='/instances'].id" --output text)

aws apigateway update-method \
  --rest-api-id $API_ID \
  --resource-id $RESOURCE_ID \
  --http-method GET \
  --patch-operations op=replace,path=/authorizationType,value=COGNITO_USER_POOLS op=replace,path=/authorizerId,value=$AUTHORIZER_ID

echo "✅ Method updated with Cognito authorization"

# Step 6: Deploy changes
echo ""
echo "🚀 Step 6: Deploying API changes..."
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --description "Added Cognito authentication"

echo "✅ API deployed"

# Save configuration
cat > cognito-config.txt << EOF
Cognito Authentication Configuration
=====================================

User Pool ID: $USER_POOL_ID
App Client ID: $APP_CLIENT_ID
Region: $AWS_REGION
Authorizer ID: $AUTHORIZER_ID

First User:
-----------
Email: $USER_EMAIL
Temporary Password: TempPass123!

HTML Configuration:
-------------------
Add these values to your HTML file:

const COGNITO_CONFIG = {
    userPoolId: '$USER_POOL_ID',
    clientId: '$APP_CLIENT_ID',
    region: '$AWS_REGION'
};

Add More Users:
---------------
aws cognito-idp admin-create-user \\
  --user-pool-id $USER_POOL_ID \\
  --username user@example.com \\
  --user-attributes Name=email,Value=user@example.com Name=email_verified,Value=true \\
  --temporary-password "TempPass123!" \\
  --message-action SUPPRESS

Delete User:
------------
aws cognito-idp admin-delete-user \\
  --user-pool-id $USER_POOL_ID \\
  --username user@example.com

Remove Authentication:
----------------------
aws apigateway update-method \\
  --rest-api-id $API_ID \\
  --resource-id $RESOURCE_ID \\
  --http-method GET \\
  --patch-operations op=replace,path=/authorizationType,value=NONE

aws apigateway create-deployment \\
  --rest-api-id $API_ID \\
  --stage-name prod
EOF

echo ""
echo "🎉 Cognito Authentication Enabled!"
echo "==================================="
echo ""
echo "📄 Configuration saved to: cognito-config.txt"
echo ""
echo "📝 Next Steps:"
echo "   1. Download cognito-config.txt"
echo "   2. Download ec2-dashboard-with-cognito.html (will be created next)"
echo "   3. First login will require password change from TempPass123!"
echo ""
echo "👥 Add more users:"
echo "   aws cognito-idp admin-create-user --user-pool-id $USER_POOL_ID --username EMAIL"
echo ""

# Create authenticated HTML
cat > ec2-dashboard-with-cognito.html << 'HTMLEOF'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EC2 Dashboard - Secure</title>
    <script src="https://cdn.jsdelivr.net/npm/amazon-cognito-identity-js@6.3.6/dist/amazon-cognito-identity.min.js"></script>
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
        .login-box, .controls, .card { background: white; border-radius: 15px; padding: 25px; margin-bottom: 20px; box-shadow: 0 4px 15px rgba(0,0,0,0.2); }
        .login-box { max-width: 400px; margin: 100px auto; }
        .login-box h2 { margin-bottom: 20px; color: #333; }
        input { width: 100%; padding: 12px; margin-bottom: 15px; border: 1px solid #ddd; border-radius: 8px; font-size: 14px; }
        button { width: 100%; padding: 12px; background: #667eea; color: white; border: none; border-radius: 8px; font-size: 14px; font-weight: 600; cursor: pointer; }
        button:hover { background: #5568d3; }
        .btn-logout { width: auto; padding: 8px 16px; background: #dc3545; margin-left: 10px; }
        .btn-logout:hover { background: #c82333; }
        .filter-row { display: flex; gap: 10px; align-items: center; flex-wrap: wrap; }
        .filter-row input { width: auto; flex: 1; min-width: 150px; margin: 0; }
        .filter-row button { width: auto; }
        .btn-clear { background: #6c757d; }
        .btn-clear:hover { background: #5a6268; }
        .info { margin-top: 10px; color: #666; font-size: 14px; }
        table { width: 100%; border-collapse: collapse; }
        th { background: #667eea; color: white; padding: 15px; text-align: left; font-weight: 600; text-transform: uppercase; font-size: 12px; }
        td { padding: 15px; border-bottom: 1px solid #f0f0f0; }
        tr:hover { background: #f8f9ff; }
        .state { display: inline-block; padding: 5px 12px; border-radius: 20px; font-size: 12px; font-weight: 600; text-transform: uppercase; }
        .running { background: #d4edda; color: #155724; }
        .stopped { background: #f8d7da; color: #721c24; }
        .loading { text-align: center; padding: 40px; color: #666; font-size: 18px; }
        .error { background: #f8d7da; color: #721c24; padding: 15px; border-radius: 8px; margin: 20px 0; text-align: center; }
        .hidden { display: none; }
        .user-info { color: white; text-align: right; margin-bottom: 20px; }
    </style>
</head>
<body>
    <!-- Login Screen -->
    <div id="loginScreen" class="login-box">
        <h2>🔐 Login</h2>
        <input type="email" id="loginEmail" placeholder="Email" />
        <input type="password" id="loginPassword" placeholder="Password" />
        <button onclick="login()">Login</button>
        <div id="loginError" class="error hidden"></div>
    </div>

    <!-- Dashboard Screen -->
    <div id="dashboardScreen" class="hidden">
        <div class="container">
            <h1>🖥️ EC2 Dashboard</h1>
            <div class="user-info">
                Logged in as: <span id="userEmail"></span>
                <button class="btn-logout" onclick="logout()">Logout</button>
            </div>
            
            <div class="controls">
                <div class="filter-row">
                    <input type="text" id="tagKey" placeholder="Tag Key" />
                    <input type="text" id="tagValue" placeholder="Tag Value" />
                    <button onclick="filterInstances()">🔍 Filter</button>
                    <button class="btn-clear" onclick="clearFilter()">✖ Clear</button>
                    <button onclick="loadInstances()">🔄 Refresh</button>
                </div>
                <div class="info" id="info">Click Refresh to load instances</div>
            </div>
            
            <div class="card">
                <div id="content">
                    <div class="loading">Click Refresh to load instances</div>
                </div>
            </div>
        </div>
    </div>

    <script>
        // ⚠️ REPLACE THESE VALUES FROM cognito-config.txt
        const COGNITO_CONFIG = {
            userPoolId: 'YOUR_USER_POOL_ID',
            clientId: 'YOUR_APP_CLIENT_ID',
            region: 'YOUR_REGION'
        };
        const API_ENDPOINT = 'YOUR_API_ENDPOINT';

        let userPool, cognitoUser, idToken, allInstances = [];

        // Initialize Cognito
        const poolData = {
            UserPoolId: COGNITO_CONFIG.userPoolId,
            ClientId: COGNITO_CONFIG.clientId
        };
        userPool = new AmazonCognitoIdentity.CognitoUserPool(poolData);

        // Check if already logged in
        window.onload = () => {
            cognitoUser = userPool.getCurrentUser();
            if (cognitoUser) {
                cognitoUser.getSession((err, session) => {
                    if (!err && session.isValid()) {
                        idToken = session.getIdToken().getJwtToken();
                        showDashboard(cognitoUser.getUsername());
                    }
                });
            }
        };

        function login() {
            const email = document.getElementById('loginEmail').value;
            const password = document.getElementById('loginPassword').value;
            const errorDiv = document.getElementById('loginError');

            const authData = {
                Username: email,
                Password: password
            };
            const authDetails = new AmazonCognitoIdentity.AuthenticationDetails(authData);
            const userData = { Username: email, Pool: userPool };
            cognitoUser = new AmazonCognitoIdentity.CognitoUser(userData);

            cognitoUser.authenticateUser(authDetails, {
                onSuccess: (result) => {
                    idToken = result.getIdToken().getJwtToken();
                    showDashboard(email);
                },
                onFailure: (err) => {
                    errorDiv.textContent = err.message;
                    errorDiv.classList.remove('hidden');
                },
                newPasswordRequired: () => {
                    const newPass = prompt('First login! Enter new password (min 8 chars, uppercase, lowercase, number):');
                    if (newPass) {
                        cognitoUser.completeNewPasswordChallenge(newPass, {}, {
                            onSuccess: (result) => {
                                idToken = result.getIdToken().getJwtToken();
                                showDashboard(email);
                            },
                            onFailure: (err) => {
                                errorDiv.textContent = err.message;
                                errorDiv.classList.remove('hidden');
                            }
                        });
                    }
                }
            });
        }

        function logout() {
            if (cognitoUser) {
                cognitoUser.signOut();
            }
            document.getElementById('loginScreen').classList.remove('hidden');
            document.getElementById('dashboardScreen').classList.add('hidden');
        }

        function showDashboard(email) {
            document.getElementById('userEmail').textContent = email;
            document.getElementById('loginScreen').classList.add('hidden');
            document.getElementById('dashboardScreen').classList.remove('hidden');
            loadInstances();
        }

        async function loadInstances() {
            const content = document.getElementById('content');
            const info = document.getElementById('info');
            content.innerHTML = '<div class="loading">Loading...</div>';
            info.textContent = 'Loading...';

            try {
                const response = await fetch(API_ENDPOINT, {
                    headers: { 'Authorization': idToken }
                });
                if (!response.ok) throw new Error('Failed to fetch data');
                allInstances = await response.json();
                info.textContent = `Total instances: ${allInstances.length}`;
                displayInstances(allInstances);
            } catch (error) {
                content.innerHTML = `<div class="error">❌ Error: ${error.message}</div>`;
                info.textContent = 'Error loading instances';
            }
        }

        function filterInstances() {
            const tagKey = document.getElementById('tagKey').value.trim();
            const tagValue = document.getElementById('tagValue').value.trim();
            if (!tagKey || !tagValue) {
                alert('Enter both Tag Key and Tag Value');
                return;
            }
            const filtered = allInstances.filter(inst => 
                inst.tags[tagKey] && inst.tags[tagKey].toLowerCase() === tagValue.toLowerCase()
            );
            document.getElementById('info').textContent = `Filtered: ${filtered.length} of ${allInstances.length}`;
            displayInstances(filtered);
        }

        function clearFilter() {
            document.getElementById('tagKey').value = '';
            document.getElementById('tagValue').value = '';
            document.getElementById('info').textContent = `Total instances: ${allInstances.length}`;
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
                html += `<tr>
                    <td><strong>${inst.name}</strong></td>
                    <td>${inst.instanceId}</td>
                    <td>${inst.privateIp}</td>
                    <td><span class="state ${stateClass}">${inst.state}</span></td>
                </tr>`;
            });
            html += '</tbody></table>';
            content.innerHTML = html;
        }
    </script>
</body>
</html>
HTMLEOF

# Update HTML with actual values
sed -i "s|YOUR_USER_POOL_ID|$USER_POOL_ID|g" ec2-dashboard-with-cognito.html
sed -i "s|YOUR_APP_CLIENT_ID|$APP_CLIENT_ID|g" ec2-dashboard-with-cognito.html
sed -i "s|YOUR_REGION|$AWS_REGION|g" ec2-dashboard-with-cognito.html
sed -i "s|YOUR_API_ENDPOINT|https://${API_ID}.execute-api.${AWS_REGION}.amazonaws.com/prod/instances|g" ec2-dashboard-with-cognito.html

echo "✅ HTML dashboard created: ec2-dashboard-with-cognito.html"
echo ""
echo "📥 Download both files:"
echo "   - cognito-config.txt"
echo "   - ec2-dashboard-with-cognito.html"
