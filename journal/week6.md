# Week 6 — Deploying Containers

## Required Homework/Tasks

All the tasks under this section are done using the `Gitpod` workspace.

### 1. Provision ECS Cluster 

Before we start provisioning our ECS cluster, let's create a script to always test our RDS connection. We will also need a way to perform health checks at the load balancer and container level.

<details><summary>Test RDS Connection</summary>
<p> 

Let's create a script that will help us test the connection in our RDS instance.

In the `backend-flask/bin/db/` directory, create a script file named `test`. This script easily checks our connection from our container. so we just need to run the script from our container to test that our RDS instance (database) is connected. 

```python
#!/usr/bin/env python3

import psycopg
import os
import sys

connection_url = os.getenv("CONNECTION_URL")

# use this one to test if it works
# connection_url = os.getenv("PRD_CONNECTION_URL")

conn = None
try:
  print('attempting connection')
  conn = psycopg.connect(connection_url)
  print("Connection successful!")
except psycopg.Error as e:
  print("Unable to connect to the database:", e)
finally:
  conn.close()
```

**NOTE:** Make sure your RDS instance in AWS is started before executing the above script. 

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# By default, you will get permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/db/test
  
# execute the script 
./backend-flask/bin/db/test
```

</p>
</details>

<details><summary>Install Boto3</summary>
<p> 

Now let's do a health check for our `Flask` app. We'll add the following endpoint in our `app.py` file. This could be added at the top or bottom of where the other endpoints go, your preference. 

```python
@app.route('/api/health-check')
def health_check():
  return {'success': True}, 200
```

In the `backend-flask/bin/` directory, create a folder named `flask` and a file inside the folder called `health-check`.

```bash
# creates the "flask" folder
mkdir backend-flask/bin/flask

# creates the "health-check" file
touch backend-flask/bin/flask/health-check
```

We are using a `python` script for our `health-check` because we don't want to package network utilities like `curl` and `wget` in our script to avoid someone easily getting into our containers. 

Content of the `health-check` script:

```python
#!/usr/bin/env python3

import urllib.request

try:
  response = urllib.request.urlopen('http://localhost:4567/api/health-check')
  if response.getcode() == 200:
    print("[OK] Flask server is running")
    exit(0) # success
  else:
    print("[BAD] Flask server is not running")
    exit(1) # error

# This "except ConnectionRefusedError as e:" for some reason, is not capturing the error...
# So we'll just catch on all, even though this is a bad practice

except Exception as e:
  print(e)
  exit(1) # false


# If the exit codes aren't explicitly called, 
# It will automatically exit with a code 0, even if it exited with an error.
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# By default, you will get permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/flask/health-check
  
# execute the script 
./backend-flask/bin/flask/health-check
```

</p>
</details>

Let's briefly create a CloudWatch log group for our Fargate cluster. Run the following commands in your terminal. 

```bash
# create CloudWatch Log grp
aws logs create-log-group --log-group-name "/cruddur/fargate-cluster"

# add a 1 day retention for the logs - for cost 
aws logs put-retention-policy --log-group-name "/cruddur/fargate-cluster" --retention-in-days 1
```

<details><summary>Create Our ECS Cluster</summary>
<p> 

We will be using `service-connect` to create our ECS cluster. `Service-Connect` uses namespaces, and these namespaces can be viewed in your AWS Cloud Map. AWS Cloud Map is a way to name your resources dynamically. It’s sort of a way to map your AWS resources. [Read more here](https://blog.kerosene.cloud/using-aws-cloudmap-with-ecs-for-service-discovery-e9c04808e33b) 

```bash
aws ecs create-cluster \
--cluster-name cruddur \
--service-connect-defaults namespace=cruddur
```

After creation, go to your AWS console to confirm that your cluster was created or is being created. 

If you encounter this error while trying to create your ECS cluster, simply retry a couple of times. 

![Image of ECS API Error](assets/ecs-api-error.png)

Here's the reason for the error: [ServerException](https://repost.aws/knowledge-center/ecs-api-common-errors) 

</p>
</details>

### 2. Create ECR repo and push image - BASE image

ECR is our container image registry. We will be using it to store the container images in our application - backend & frontend.

<details><summary>Base Image - Python</summary>
<p> 

Check the `Dockerfile` of your `backend` folder and see what image it’s using. Let's create our repo for the base image.

```bash
# create the repo
aws ecr create-repository \
  --repository-name cruddur-python \
  --image-tag-mutability MUTABLE
```

### Login to ECR 

To be able to pull and push images to ECR, we need to log in to ECR. So to retrieve an authentication token and authenticate your Docker client to your registry, run the following command in your terminal.

```bash
aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
```

### Set URL

This is a way to map to our new repo’s URI.

```bash
# set your URL as an environment variable 
export ECR_PYTHON_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/cruddur-python"

# set your URL as an environment variable - GitPod
gp env ECR_PYTHON_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/cruddur-python"

# ensure it matches the one in your AWS console
echo $ECR_PYTHON_URL
```

### Pull Image 

Now, let’s pull our image from docker.

```bash
docker pull python:3.10-slim-buster
```

### Tag Image 

Let’s tag the image we just pulled.

```bash
docker tag python:3.10-slim-buster $ECR_PYTHON_URL:3.10-slim-buster

# to confirm the image was properly tagged
docker images 
```

### Push Image 

Now, go ahead and push the image to ECR.

```bash
docker push $ECR_PYTHON_URL:3.10-slim-buster
```

</p>
</details>

Now, we have to update our `Dockerfile` to use our image on ECR. 

In `backend-flask/Dockerfile`, update your image URI (the first line in the file) to use the ECR image URI now. You can get it by going to your AWS console and navigating to ECR.

```bash
# change this 
FROM python:3.10-slim-buster

# to this 
FROM <YOUR_ECR_IMAGE_URI>:3.10-slim-buster

# to avoid getting those errors when we start up our backend
# change this line 
ENV FLASK_ENV=development

# to this 
ENV FLASK_DEBUG=1
```

To ensure our configuration works, make sure you run the ECR login command to be sure your image is rightly pulled from ECR. Also, make sure that you don’t have that image locally on your machine by running `docker images`. Now do a `docker compose up` to start up your application and then a `docker compose down`. 

To do a `docker compose up` for selected services, you just have to list the services name like so:

```bash
# check your docker-compose.yml for the services name
docker compose up backend-flask db 
# that will only spin up backend and the DB
```

When it’s all spun up, you can make sure your health check is running by appending `/api/health-check` to your backend URL.


### 3. Create ECR repo and push image - `backend-flask` image

For our backend image, we will also be using `python`. 

<details><summary>Backend Image - Python</summary>
<p> 

Check the `Dockerfile` of your backend folder and see what image it’s using. Let's create our repo for the `backend-flask` image.

```bash
# create the repo
aws ecr create-repository \
  --repository-name backend-flask \
  --image-tag-mutability MUTABLE
```

### Login to ECR 

To be able to pull and push images to ECR, we need to log in to ECR. So to retrieve an authentication token and authenticate your Docker client to your registry, run the following command in your terminal.

```bash
aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
```

### Set URL

This is a way to map to our new repo’s URI.

```bash
# set our URL as an environment variable 
export ECR_BACKEND_FLASK_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/backend-flask"

# set our URL as an environment variable - GitPod
gp env ECR_BACKEND_FLASK_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/backend-flask"

# ensure it matches the one in your AWS console
echo $ECR_BACKEND_FLASK_URL
```

### Build Image 

Now, let’s build our image.

```bash
# make sure to be in your backend-flask folder 
docker build -t backend-flask .
```

### Tag Image 

Let’s tag the image we just built.

```bash
docker tag backend-flask:latest $ECR_BACKEND_FLASK_URL:latest

# to confirm the image was properly tagged
docker images 
```

### Push Image 

Now, go ahead and push the image to ECR.

```bash
docker push $ECR_BACKEND_FLASK_URL:latest
```

</p>
</details>


### 4. Deploy the Backend Flask app as a service to FARGATE

Let’s go ahead and deploy our `backend-flask` application as a service to FARGATE. The difference between a `service` and a `task` is that a **task** runs and terminates when it’s done (like a batch job), ***while*** a **service** runs continuously, which is what we need because we are running a web app. 

If you want to do this in the AWS console, navigate to the ECS service and create a `service`, not a `task`.

Before we can deploy our app to FARGATE, we have to create a `task definition`. It is sort of a way to provision an application; it is like creating a ***docker compose*** file. Again, you can choose to do this creation through the AWS console under the ECS service.

<details><summary>Creating Our Task Definition</summary>
<p> 
  
In the `aws/` directory, create a folder named `task-definitions` with a file called `backend-flask.json` for the task definitions. 

```bash
# create folder
mkdir aws/task-definitions

# create file
touch aws/task-definitions/backend-flask.json
```

Content of the `backend-flask.json` file:

```json
{
  "family": "backend-flask",
  // REMEMBER to change the AWS account id
  "executionRoleArn": "arn:aws:iam::387543059434:role/CruddurServiceExecutionRole",
  "taskRoleArn": "arn:aws:iam::387543059434:role/CruddurTaskRole",
  "networkMode": "awsvpc",
  "cpu": "256",
  "memory": "512",
  "requiresCompatibilities": [ 
    "FARGATE" 
  ],
  "containerDefinitions": [
    {
      "name": "backend-flask",
      // REMEMBER to change the AWS account id & region
      // make sure you grab yours from your ECR
      "image": "387543059434.dkr.ecr.ca-central-1.amazonaws.com/backend-flask",
      "essential": true,
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "python /backend-flask/bin/flask/health-check"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "portMappings": [
        {
          "name": "backend-flask",
          "containerPort": 4567,
          "protocol": "tcp", 
          "appProtocol": "http"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "cruddur",
            // REMEMBER to change the AWS region
            "awslogs-region": "ca-central-1",
            "awslogs-stream-prefix": "backend-flask"
        }
      },

      // REMEMBER to change the values to yours
      "environment": [
        {"name": "OTEL_SERVICE_NAME", "value": "backend-flask"},
        {"name": "OTEL_EXPORTER_OTLP_ENDPOINT", "value": "https://api.honeycomb.io"},
        {"name": "AWS_COGNITO_USER_POOL_ID", "value": "ca-central-1_CQ4wDfnwc"},
        {"name": "AWS_COGNITO_USER_POOL_CLIENT_ID", "value": "5b6ro31g97urk767adrbrdj1g5"},
        
        // we won't be leaving our origin open to the internet (*)
        {"name": "FRONTEND_URL", "value": "*"},
        {"name": "BACKEND_URL", "value": "*"},
        {"name": "AWS_DEFAULT_REGION", "value": "ca-central-1"}
      ],
      // REMEMBER to change the AWS account ids & regions
      "secrets": [
        {"name": "AWS_ACCESS_KEY_ID"    , "valueFrom": "arn:aws:ssm:ca-central-1:387543059434:parameter/cruddur/backend-flask/AWS_ACCESS_KEY_ID"},
        {"name": "AWS_SECRET_ACCESS_KEY", "valueFrom": "arn:aws:ssm:ca-central-1:387543059434:parameter/cruddur/backend-flask/AWS_SECRET_ACCESS_KEY"},
        {"name": "CONNECTION_URL"       , "valueFrom": "arn:aws:ssm:ca-central-1:387543059434:parameter/cruddur/backend-flask/CONNECTION_URL" },
        {"name": "ROLLBAR_ACCESS_TOKEN" , "valueFrom": "arn:aws:ssm:ca-central-1:387543059434:parameter/cruddur/backend-flask/ROLLBAR_ACCESS_TOKEN" },
        {"name": "OTEL_EXPORTER_OTLP_HEADERS" , "valueFrom": "arn:aws:ssm:ca-central-1:387543059434:parameter/cruddur/backend-flask/OTEL_EXPORTER_OTLP_HEADERS" }
      ]
    }
  ]
}
```

Make sure to create a log group in your AWS console - CloudWatch, called `cruddur` to match our configuration in this task definition file. 

```bash
# create a log group with retention days of 1 
aws logs create-log-group --log-group-name cruddur
aws logs put-retention-policy --log-group-name cruddur --retention-in-days 1
```

Also, we have to make sure both `AWS roles` (execution & task role) mentioned above already exist. 

In a **task definition** file, 

- a `TaskRole` is the IAM role that grants permissions to the actual application once the container is started (the permissions the container will have when it’s running), and
- an `ExecutionRole` is the IAM role that executes ECS actions, such as pulling the image, storing the application logs in CloudWatch, and making many more AWS API calls. This role grants permissions to start the containers defined in a task.

<details><summary>Task and Execution Roles</summary>
<p> 

### Task Execution Role

Now we will be creating the [task execution role](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html). This is simply allowing ECS tasks to assume the execution role to be able to launch tasks. 

In the `aws/policies/` directory, add a file `service-assume-role-execution-policy.json` with the following content:

```json
{
  "Version":"2012-10-17",
  "Statement":[{
      "Action":["sts:AssumeRole"],
      "Effect":"Allow",
      "Principal":{
        "Service":["ecs-tasks.amazonaws.com"]
    }}]
}
```

In the `aws/policies/` directory, add another file `service-execution-policy.json` with the following content:

```bash
// REMEMBER TO CHANGE to your own ARN
{
  "Version":"2012-10-17",
  "Statement":[{
    "Effect": "Allow",
    "Action": [
      "ssm:GetParameters",
      "ssm:GetParameter"
    ],
    "Resource": "arn:aws:ssm:ca-central-1:387543059434:parameter/cruddur/backend-flask/*"
  }]
}
```

Let’s create the role now in AWS using these commands:

```bash
# create role
# make sure to be in the root directory 
aws iam create-role \
    --role-name CruddurServiceExecutionRole \
    --assume-role-policy-document "file://aws/policies/service-assume-role-execution-policy.json"

# add inline policy to role
aws iam put-role-policy \
  --policy-name CruddurServiceExecutionPolicy \
  --role-name CruddurServiceExecutionRole \
  --policy-document "file://aws/policies/service-execution-policy.json"
```

Go back to your AWS console and navigate to IAM Role to confirm it was created. 

### Task Role

Now let’s create our `task` role. 

Run the following commands to create a role and attach a policy to it.

```bash
# create role
aws iam create-role \
    --role-name CruddurTaskRole \
    --assume-role-policy-document "{
  \"Version\":\"2012-10-17\",
  \"Statement\":[{
    \"Action\":[\"sts:AssumeRole\"],
    \"Effect\":\"Allow\",
    \"Principal\":{
      \"Service\":[\"ecs-tasks.amazonaws.com\"]
    }
  }]
}"

# add inline policy to role 
aws iam put-role-policy \
  --policy-name SSMAccessPolicy \
  --role-name CruddurTaskRole \
  --policy-document "{
  \"Version\":\"2012-10-17\",
  \"Statement\":[{
    \"Action\":[
      \"ssmmessages:CreateControlChannel\",
      \"ssmmessages:CreateDataChannel\",
      \"ssmmessages:OpenControlChannel\",
      \"ssmmessages:OpenDataChannel\"
    ],
    \"Effect\":\"Allow\",
    \"Resource\":\"*\"
  }]
}
"
```

Grant CloudWatch and X-ray access:

```bash
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess --role-name CruddurTaskRole
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess --role-name CruddurTaskRole
```

Confirm that these policies are attached to the `CruddurTaskRole` in your AWS console. 

</p>
</details>

AWS has 2 different services for secret storage, **Secrets Manager** and **Parameter Store**. Using the **Secrets Manager** costs money compared to the **Parameter Store**, which is free. They are both easy to use and integrate with applications. 

<details><summary>Storing Our Secrets </summary>
<p> 

This feature is found under the **Systems Manager** service in the AWS console if you want to create them through the console. 

Before running each of these lines, make sure they exist as an environment variable in your bash terminal, not just your `docker compose` file. 

**For example:** Instead of hardcoding your environment variables this way `ACCESS_KEY: hdrgsdgcr` in your docker file, do this instead `ACCESS_KEY: $ACCESS_KEY` and make sure that value has been exported already to your terminal using the `export` command. 

Using the CLI, let’s store our sensitive data in the parameter store:

```bash
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/AWS_ACCESS_KEY_ID" --value $AWS_ACCESS_KEY_ID
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/AWS_SECRET_ACCESS_KEY" --value $AWS_SECRET_ACCESS_KEY
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/CONNECTION_URL" --value $PRD_CONNECTION_URL
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/ROLLBAR_ACCESS_TOKEN" --value $ROLLBAR_ACCESS_TOKEN
aws ssm put-parameter --type "SecureString" --name "/cruddur/backend-flask/OTEL_EXPORTER_OTLP_HEADERS" --value "x-honeycomb-team=$HONEYCOMB_API_KEY"
```

Afterward, go into your AWS console and confirm these were properly set. Check each of the values and ensure they are all correct.

</p>
</details>

Before we can create our task, we need to register the task definition. Let's do that using this command:

```bash
aws ecs register-task-definition --cli-input-json file://aws/task-definitions/backend-flask.json
```

Confirm in your AWS console by navigating to your ECS service and clicking `task definitions`.

![Image of Task Definition Registration](assets/task-definition-registration.png)

</p>
</details>

<details><summary>Create `backend-flask` service</summary>
<p> 
  
Now, we can create our `backend-flask` service. Let's use the CLI to deploy this service. Remember it is your choice to either create it through the console or CLI. 

If we are creating this service through the CLI, we will need to create a JSON configuration file for the service. This enables us easily launch the service. 

```bash
# create file
touch aws/json/service-backend-flask.json
```

Content of the `service-backend-flask.json` file:

```json
{
  "cluster": "cruddur",
  "launchType": "FARGATE",
  "desiredCount": 1,
  "enableECSManagedTags": true,
  "enableExecuteCommand": true,
  "networkConfiguration": {
    "awsvpcConfiguration": {
      "assignPublicIp": "ENABLED",
      "securityGroups": [
        "sg-04bdc8d5443cc8283" // replace with yours
      ],
      "subnets": [
        // replace with yours
        "subnet-0462b87709683ccaa",
        "subnet-066a53dd88d557e05",
        "subnet-021a6adafb79249e3"
      ]
    }
  },
  "propagateTags": "SERVICE",
  "serviceName": "backend-flask",
  "taskDefinition": "backend-flask"
}
```

Make sure the `crud-srv-SG` security group exists; if not, use the commands below to create one. This will serve as the security group for our ECS services. 

```bash
# run in your terminal
export CRUD_SERVICE_SG=$(aws ec2 create-security-group \
  --group-name "crud-srv-SG" \
  --description "Security group for Cruddur services on ECS" \
  --vpc-id $DEFAULT_VPC_ID \
  --query "GroupId" --output text)

echo $CRUD_SERVICE_SG

# authorize port 80
aws ec2 authorize-security-group-ingress \
  --group-id $CRUD_SERVICE_SG \
  --protocol tcp \
  --port 80 \
  --cidr 0.0.0.0/0
```

To grab the `ID's` of the security group and subnets, use the following commands:

```bash
# grab the custom security grp ID
export CRUD_SERVICE_SG=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=crud-srv-SG \
  --query 'SecurityGroups[*].GroupId' \
  --output text)
# MAKE SURE NAME(Values) MATCHES YOUR OWN security grp

# grab the DEFAULT subnets 
export DEFAULT_SUBNET_IDS=$(aws ec2 describe-subnets  \
 --filters Name=vpc-id,Values=$DEFAULT_VPC_ID \
 --query 'Subnets[*].SubnetId' \
 --output json | jq -r 'join(",")')

echo $DEFAULT_SUBNET_IDS
```

Let’s go ahead and get our `VPC ID` from AWS and then set it as an environment variable in our terminal. 

```bash
# run in your terminal
export DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
--filters "Name=isDefault, Values=true" \
--query "Vpcs[0].VpcId" \
--output text)

echo $DEFAULT_VPC_ID
```

Navigate to your AWS console to make sure everything is properly created. 

Now, we can create our service 

```bash
aws ecs create-service --cli-input-json file://aws/json/service-backend-flask.json
```

Give the task some time to deploy. 

If you are encountering this error, it is due to some permissions issues with our roles. Let's go ahead and resolve that. 

![Image of ECS Roles Permissions Error](assets/ecs-roles-permissions-error.png)

<details><summary>Troubleshooting ECS Roles</summary>
<p> 

Make the following updates to your `CruddurServiceExecutionRole` in AWS. That will be your `service-execution-policy.json` file in your source code. 

```json
// Modify your code with these new changes

{
  "Version":"2012-10-17",
  "Statement":[
  {
    "Effect": "Allow",
    "Action": [
      "ecr:GetAuthorizationToken",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ],
    "Resource": "*"
  },
  {
    "Effect": "Allow",
    "Action": [
      "ssm:GetParameters",
      "ssm:GetParameter"
    ],
    // REMEMBER to change the acct id & region
    "Resource": "arn:aws:ssm:ca-central-1:387543059434:parameter/cruddur/backend-flask/*"
  }]
}
```

After the modifications, try recreating the roles and creating the service again through the CLI. For some reason, creating the service through the console doesn’t give us a `health-check` status, and we can’t ssh (shell) into the container either to check it out. So it is best to create the `fargate` services through the CLI. 

</p>
</details>

After that permissions issue has been resolved, go over to your AWS console to confirm the service is created and the task in it is `running` successfully. If the `health-check` status is still `unknown`, let’s follow the steps below to resolve it.

<details><summary>Troubleshooting ECS `unknown` health check</summary>
<p> 

We need to download a session manager plugin to enable us to shell into our container. To make that easy for us, add this to your `gitpod.yml` file to install it for us on startup. 

```yaml
# add after backend-flask
- name: fargate
    before: | # if you use "init", u won't c it wen u start up ur env 
      curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
      sudo dpkg -i session-manager-plugin.deb
      cd backend-flask
```

To verify the `session-manager` is working, run this command:

```bash
session-manager-plugin
```

Now to resolve the `unknown` health check error, run this command to shell into the container and investigate the problem.

```bash
aws ecs execute-command  \
	--region $AWS_DEFAULT_REGION \
	--cluster cruddur \
	--task 467e033cabe94949a05d844b449976da \ # replace with your TASK_ID
	--container backend-flask \
	--command "/bin/bash" \
	--interactive
```

To list your ECS tasks, use this command:

```bash
aws ecs list-tasks --cluster cruddur
```

I keep getting this error:


</p>
</details>








</p>
</details>







<details><summary>Install Boto3</summary>
<p> 
  
</p>
</details>


<details><summary>Install Boto3</summary>
<p> 
  
</p>
</details>

<details><summary>Install Boto3</summary>
<p> 
  
</p>
</details>



