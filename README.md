# AV Crypto API call w/ Lambda to Dynamo data ingestion using Terraform





### Creating the Python deployment package for the Lambda function

https://medium.com/bi3-technologies/creating-python-deployment-package-for-aws-lambda-function-25205f033ac5


Logging into AWS from Terminal:
1. In Terminal run: aws sso login
2. Username: 
3. Pw:
   
Start URL: https://d-9067e02247.awsapps.com/start



aws sso-admin list-permission-sets --instance-arn arn:aws:sso:::instance/ssoins-72232292b9efe35a --account-id d-9067e02247

### YT video for getting Lambda function to work using a function layer
https://www.youtube.com/watch?v=I13FPeC5LTw&list=LL&index=1

python3.8 -m venv env

### High-level Steps to Perform:

1. Create an S3 bucket to store the Lambda deployment package.
2. Write the Lambda function code.
3. Define the DynamoDB table in Terraform.
4. Define the Lambda function in Terraform, including the necessary IAM roles and policies.
5. Create a CloudWatch Events rule to trigger the Lambda function daily.
6. Deploy the Lambda function using Terraform.
