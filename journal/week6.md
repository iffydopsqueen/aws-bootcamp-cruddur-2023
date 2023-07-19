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

<details><summary>Create the Backend Service</summary>
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

<details><summary>Troubleshooting ECS Unknown Health Check</summary>
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

![Image of Execute-Command Error](assets/execute-command-error.png)

```bash
aws ecs update-service --force-new-deployment --cluster cruddur --task-definition backend-flask --service backend-flask --enable-execute-command
```

<details><summary>Script to Connect to the backend service Container</summary>
<p> 

In the `backend-flask/bin/` directory, create a folder `ecs` with a file `connect-to-service`:

```bash
# create folder 
mkdir backend-flask/bin/ecs

# create file
touch backend-flask/bin/ecs/connect-to-service
```

Content of the `connect-to-service` file:

```bash
#! /usr/bin/bash

if [ -z "$1" ]; then
  echo "No TASK_ID argument supplied eg ./bin/ecs/connect-to-service 99b2f8953616495e99545e5a6066fbb5d backend-flask"
  exit 1
fi
TASK_ID=$1

if [ -z "$2" ]; then
  echo "No CONTAINER_NAME argument supplied eg ./bin/ecs/connect-to-service 99b2f8953616495e99545e5a6066fbb5d backend-flask"
  exit 1
fi
CONTAINER_NAME=$2

echo "TASK ID : $TASK_ID"
echo "Container Name: $CONTAINER_NAME"

aws ecs execute-command  \
--region $AWS_DEFAULT_REGION \
--cluster cruddur \
--task $TASK_ID \
--container $CONTAINER_NAME \
--command "/bin/bash" \
--interactive
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# By default, you will get permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/ecs/connect-to-service

# execute the script 
./backend-flask/bin/ecs/connect-to-service
```

</p>
</details>

Inside your backend container, run the command below to confirm the `health-check` status of the app server.

```bash
# check the status of the application server
./bin/flask/health-check
```

![Image of a Successful Health Check using Execute-Command](assets/successful-health-check-with-execute-cmd.png)

After confirming the server is running, go into your AWS console and refresh. It should have a **green checkmark** that says `healthy`. 

![Image of a Healthy Task on ECS Console](assets/healthy-task-on-ecs-console.png)

</p>
</details>

Now let's try out our configuration in the browser. In the ECS service console, navigate to the **Configurations** tab, then select the `task`. You should now see a **public IP**, go ahead and copy that and then append `:4567` to see if you can access the backend. If you are not able to access the backend, follow these steps to resolve it. 

- In the AWS console, navigate to the security group attached to the ECS service. Go ahead and edit it. Change the `security group rule ID` to have a **Custom TCP** with port range `4567` and source as **Anywhere**.
  
- You can also check to see if a **Network Interface**(eni) was created for your ECS service.

Now try out the URL again; it should work. 

- `public IP:4567`

- You can also check the health status by appending the `health-check` endpoint like `public IP:4567/api/health-check`. 

</p>
</details>

<details><summary>Update RDS Security Group</summary>
<p> 

Let’s make sure our security group, `CRUD_SERVICE_SG` has access to our RDS instance. 

First, we have to modify the security group, and create a connection script that tests out our connection inside the ECS service containers. 

```python
# create test file 
touch backend-flask/bin/db/test

# file content 

#!/usr/bin/env python3
import psycopg
import os
import sys

connection_url = os.getenv("CONNECTION_URL")

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

Before implementing this solution, try typing the public IP of your ECS container (IP:4567) and then append `/api/activities/home`. You shouldn’t be getting any results displayed. 

Our RDS instance uses the default SG, so we should add another inbound rule to accept our `CRUD_SERVICE_SG` used for our ECS services.

For our default security group (which is the one connected to our RDS instance)

- Add a new rule,
- Add **Type** as `PostgreSQL`
- Source as `Custom` and then select the security group of your ECS service
- By choice, you can add a **Description** as `ECS-CruddurServices`

After the modification, shell back into your ECS `backend-flask` service container. 

```bash
# get task_ID
aws ecs list-tasks --cluster cruddur

# connect to task container
./backend-flask/bin/ecs/connect-to-service 317d3a2c18044cc18beb1238323ba1b2 backend-flask
```

Inside the container, run this script to ensure we have a database connection. 

```bash
./bin/db/test
```

You should have a **Connection successful!** message displayed.

![Image of Connection Successful for RDS](assets/connection-successful-for-RDS.png)

Now, try typing the public IP of your ECS container `(IP:4567)` again and appending `/api/activities/home`. You should get some JSON back. 

</p>
</details>

<details><summary>Add a Service Connect Configuration</summary>
<p> 

In the `aws/json/service-backend-flask.json` file, make these modifications to add the `service-connect` configurations.

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
  // NEW configuration added
  "serviceConnectConfiguration": {
    "enabled": true,
    "namespace": "cruddur",
    "services": [
      {
        // portName is same as what we called it in our task definitions
        "portName": "backend-flask",
        "discoveryName": "backend-flask",
        "clientAliases": [{"port": 4567}]
      }
    ]
  },
  "propagateTags": "SERVICE",
  "serviceName": "backend-flask",
  "taskDefinition": "backend-flask"
}
```

Use these commands below to find your `security grp` and `subnets`

```bash
# grab the custom security grp ID
export CRUD_SERVICE_SG=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=crud-srv-sg \
  --query 'SecurityGroups[*].GroupId' \
  --output text)

# grab the DEFAULT security grp
export DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
--filters "Name=isDefault, Values=true" \
--query "Vpcs[0].VpcId" \
--output text)

echo $DEFAULT_VPC_ID

# grab the DEFAULT subnets 
export DEFAULT_SUBNET_IDS=$(aws ec2 describe-subnets  \
 --filters Name=vpc-id,Values=$DEFAULT_VPC_ID \
 --query 'Subnets[*].SubnetId' \
 --output json | jq -r 'join(",")')

echo $DEFAULT_SUBNET_IDS
```

Now, we can recreate our service to be sure every configuration checks out. 

```bash
aws ecs create-service --cli-input-json file://aws/json/service-backend-flask.json
```

Go over to your AWS console to confirm the service is created and the task in it is `running` successfully.

Also, check the endpoint on the browser to be sure; everything is still okay `public IP:4567/api/health-check` OR `public IP:4567/api/activities/home`. Any of the endpoints should work.

</p>
</details>


### 5. Provision and Configure Application Load Balancer (ALB) along with Target Groups

We will be provisioning our ALB through the AWS console.

<details><summary>Steps to Provision an ALB</summary>
<p> 

Let's navigate to **Load Balancers** located under the **EC2** service. 

- Select the **Application Load Balancers** - these are used for web applications and HTTPS requests. Because of the `service-connect` feature in our ECS service, we are able to use ALB and not NLB (Network Load Balancer).
  
- Choose a name for the load balancer; mine is `cruddur-alb`.
  
- Leave the **Scheme** as `Internet-facing` and the **IP address type** as `IPv4`

- For the **Network Mapping**, select all 3 of your subnets in each of the AZs
  
- For the **Security Group**, we will be creating a new one, select `Create a new one`
  
    - New security group name: `cruddur-alb-sg`
      
    - Description: `cruddur-alb-sg`
      
    - VPC: **Leave as is**
    
    - Inbound rules:
        - HTTP, source = Anywhere
        - HTTPS, source = Anywhere
          
    - Outbound rules: **Leave as is**
      
    - Now go ahead and **Create**

***Important!*** - We need to add this new security group (SG) to our ECS service SG so that instead of hitting an IP address, it will now be a load balancer. 

- Go into your SG for ECS located under the **EC2** service and edit its inbound rules
  
- Add another rule with **Type** = Custom TCP, **Port range** = 4567,  **Source** = sg_of_alb and **Description** = CruddurALB
  
- Now, only through the LB can we gain access to our services. Yay!!! 🎉
  
- For the **Listeners and routing**, let’s create a target group by clicking the blue link that says `Create target group`
  
    - In this section, select `IP addresses` as the **target type** (because we are using FARGATE and we are pointing to an IP address)
      
    - Target group name: `cruddur-backend-flask-tg`
      
    - Protocol & Port: `HTTP` and `4567`. The listener listens on port `80`, and the target group points to the port of the container, in our case is `4567`
      
    - Leave the **IP address type** and **Protocol version** as is.
      
    - For the **Health checks**, our path will be `/api/health-check`
      
        - Go on and expand the **Advanced health check settings**
          
        - Leave the **Port** as `traffic port`
          
        - Healthy threshold: `3`
          
        - Unhealthy threshold: `2`
          
        - Timeout: `5`
          
        - Interval: `30`
          
        - Success codes: `200`
        
        - Now go on and click **Next,** then **Create.**
        
- Now back to our **Listeners and routing**, let’s select our target group
  
    - Protocol: `HTTP`
    
    - Port: `4567`
  
    - Let’s add one for our `frontend` as well
      
        - Click **Add listener**
          
        - Protocol: `HTTP`
          
        - Port: `3000`
          
        - Default action: select the frontend target group
          
            - Let’s create the `cruddur-frontend-react-js-tg`
              
            - Use the same configurations for the backend, **EXCEPT*** adding a health check path
              
- Now, after those configurations, go ahead and click **Create load balancer**

</p>
</details>

<details><summary>Add ALB Configs to our backend service</summary>
<p> 

Now we need to add our ALB configurations to our backend service; go to your `aws/json/service-backend-flask.json` file and make the following updates. 

```json
{
  "cluster": "cruddur",
  "launchType": "FARGATE",
  "desiredCount": 1,
  "enableECSManagedTags": true,
  "enableExecuteCommand": true,

  // NEW configuration added
  "loadBalancers": [
    {
        // REPLACE "targetGroupArn" with yours 
        "targetGroupArn": "arn:aws:elasticloadbalancing:ca-central-1:387543059434:targetgroup/cruddur-backend-flask-tg/87ed2a3daf2d2b1d",
        "containerName": "backend-flask",
        "containerPort": 4567
    }
  ],

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
  "serviceConnectConfiguration": {
    "enabled": true,
    "namespace": "cruddur",
    "services": [
      {
        "portName": "backend-flask",
        "discoveryName": "backend-flask",
        "clientAliases": [{"port": 4567}]
      }
    ]
  },
  "propagateTags": "SERVICE",
  "serviceName": "backend-flask",
  "taskDefinition": "backend-flask"
}
```

Now you can go ahead and launch another backend service with the new features using this command:

```bash
# launch service 
aws ecs create-service --cli-input-json file://aws/json/service-backend-flask.json
```

In your **Load balancer** page, if your endpoints say ***Not reachable***, let’s go and edit our inbound rules for our load balancer security group, `cruddur-alb-sg`

![Image of Not reachable LB endpoints](assets/not-reachable-LB-endpoints.png)

- Add a new rule with the following configurations for the **backend**
  
    - Type: `Custom TCP`
      
    - Port range: `4567`
      
    - Source: `Anywhere`
      
    - Description: `TEMP1`  means temporary
      
- Add a new rule with the following configurations for the **frontend**
  
    - Type: `Custom TCP`
      
    - Port range: `3000`
      
    - Source: `Anywhere`
      
    - Description: `TEMP2` meaning temporary

Go back to your **load balancer** under the **EC2** service to confirm the error is gone. You can also check the **Targets** if they say `healthy` or `unhealthy`. 

Also, check your ECS service tasks. You can view the logs of the container by clicking the logs in the running container in ECS. 

**Important:** If your **target group** keeps saying `unhealthy`, but your ECS tasks say `healthy`. Just check the **outbound rules** for your **ALB*** security group. Make sure that there is a **rule** to allow all traffic from **anywhere**. That should resolve that error. 

![Image of the Newly Added Security Group](assets/newly-added-security-group.png)

In your load balancer, copy the `DNS name:4567` or `DNS name:4567/api/health-check` to your browser.
 
</p>
</details>


### 6. Create ECR repo and push image - `fronted-react-js` image

For our frontend image, we will be using `react` and `javascript`. 

<details><summary>Backend Image - Python</summary>
<p> 

Check the `Dockerfile` of your frontend folder and see what image it’s using. Let's create our repo for the `frontend-react-js` image.

```bash
# create the repo
aws ecr create-repository \
  --repository-name frontend-react-js \
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
export ECR_FRONTEND_REACT_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/frontend-react-js"

# set our URL as an environment variable - GitPod
gp env ECR_FRONTEND_REACT_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/frontend-react-js"

# ensure it matches the one in your AWS console
echo $ECR_FRONTEND_REACT_URL
```

### Build Image 

Now, let’s build our image.

```bash
# DON'T if you've run this already
# make sure to be in your frontend-react-js folder 
docker build \
--build-arg REACT_APP_BACKEND_URL="https://4567-$GITPOD_WORKSPACE_ID.$GITPOD_WORKSPACE_CLUSTER_HOST" \
--build-arg REACT_APP_AWS_PROJECT_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_COGNITO_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_USER_POOLS_ID="$REACT_APP_AWS_USER_POOLS_ID" \
--build-arg REACT_APP_CLIENT_ID="$REACT_APP_CLIENT_ID" \
-t frontend-react-js \
-f Dockerfile.prod \
.
```

### Tag Image 

Let’s tag the image we just built.

```bash
docker tag frontend-react-js:latest $ECR_FRONTEND_REACT_URL:latest

# to confirm the image was properly tagged
docker images  
```

### Push Image 

Now, go ahead and push the image to ECR.

```bash
docker push $ECR_FRONTEND_REACT_URL:latest
```

To test locally,

```bash
# start up app [only start up backend & db],
# make sure not to include "frontend" cuz we want to test if it can start up
docker compose up

# locally test
docker run --rm -p 3000:3000 -it frontend-react-js
```


### 7. Deploy Frontend React JS app as a service to FARGATE

Let’s go ahead and deploy our `frontend-react-js` application as a service to FARGATE. 

Before we can deploy our app to FARGATE, we have to create a **task definition**. It is sort of a way to provision an application; it is like creating a **docker-compose*** file. Again, you can choose to do this creation through the AWS console under the ECS service. 

<details><summary>Create Frontend Task Definition</summary>
<p> 

In the `aws/` folder, create a file `frontend-react-js.json` for your task definitions. 

```bash
# create file
touch aws/task-definitions/frontend-react-js.json
```

Content of the `frontend-react-js.json` file:

```json
{
  "family": "frontend-react-js",
  // change AWS acct ID
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
      "name": "frontend-react-js",
      // change to YOURS
      "image": "387543059434.dkr.ecr.ca-central-1.amazonaws.com/frontend-react-js",
      "essential": true,
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:3000 || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3
      },
      "portMappings": [
        {
          "name": "frontend-react-js",
          "containerPort": 3000,
          "protocol": "tcp", 
          "appProtocol": "http"
        }
      ],

      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
            "awslogs-group": "cruddur",
            // change region
            "awslogs-region": "ca-central-1",
            "awslogs-stream-prefix": "frontend-react-js"
        }
      }
    }
  ]
}
```

</p>
</details>

Since we didn’t pass an environment variable as we did in our `backend`, we need to do a 2-build step or multi-stage stage for our docker files. 

<details><summary>Create Dockerfile for Production</summary>
<p> 

Now let’s  create a separate `Dockerfile` for production. 

In `frontend-react-js` folder, create a `Dockerfile.prod` file

```bash
# create file
touch frontend-react-js/Dockerfile.prod
```

Content of the `Dockerfile.prod` file:

```bash
# Base Image ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
FROM node:16.18 AS build

# This is to assign environment variables
ARG REACT_APP_BACKEND_URL
ARG REACT_APP_AWS_PROJECT_REGION
ARG REACT_APP_AWS_COGNITO_REGION
ARG REACT_APP_AWS_USER_POOLS_ID
ARG REACT_APP_CLIENT_ID

# This is to call our assigned environment variables
ENV REACT_APP_BACKEND_URL=$REACT_APP_BACKEND_URL
ENV REACT_APP_AWS_PROJECT_REGION=$REACT_APP_AWS_PROJECT_REGION
ENV REACT_APP_AWS_COGNITO_REGION=$REACT_APP_AWS_COGNITO_REGION
ENV REACT_APP_AWS_USER_POOLS_ID=$REACT_APP_AWS_USER_POOLS_ID
ENV REACT_APP_CLIENT_ID=$REACT_APP_CLIENT_ID

COPY . ./frontend-react-js
WORKDIR /frontend-react-js
RUN npm install
RUN npm run build

# New Base Image ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
FROM nginx:1.23.3-alpine

# --from=build is coming from the Base Image
COPY --from=build /frontend-react-js/build /usr/share/nginx/html
COPY --from=build /frontend-react-js/nginx.conf /etc/nginx/nginx.conf

EXPOSE 3000
```

Because of the `nginx` configuration, we have in our new `Dockerfile`, we now have to create an `nginx.conf` file. The `nginx.conf` file in the `Dockerfile` is used to configure the Nginx web server that is being used to serve the static content generated by our react application.

In the `frontend-react-js` folder, create a `nginx.conf` file

```bash
# Set the worker processes
# 1 task, 1 container -> always have this practice 
worker_processes 1;

# Set the events module
events {
  worker_connections 1024;
}

# Set the http module
http {
  # Set the MIME types
  include /etc/nginx/mime.types;
  default_type application/octet-stream;

  # Set the log format
  log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

  # Set the access log
  access_log  /var/log/nginx/access.log main;

  # Set the error log
  error_log /var/log/nginx/error.log;

  # Set the server section
  server {
    # Set the listen port
    listen 3000;

    # Set the root directory for the app
    root /usr/share/nginx/html;

    # Set the default file to serve
    index index.html;

    location / {
        # First attempt to serve request as file, then
        # as directory, then fall back to redirecting to index.html
        try_files $uri $uri/ $uri.html /index.html;
    }

    # Set the error page
    error_page  404 /404.html;
    location = /404.html {
      internal;
    }

    # Set the error page for 500 errors
    error_page  500 502 503 504  /50x.html;
    location = /50x.html {
      internal;
    }
  }
}
```

This configuration file sets up the server to listen on port `3000` and serves the static files located in the `/usr/share/nginx/html` directory. It also sets up error pages and logging.

The `location / block` in the configuration file is particularly important as it specifies how `nginx` will handle incoming requests. In this case, it uses the `try_files` directive to first attempt to serve the request as a file, then as a directory, and finally fall back to redirecting to `index.html`.

In the `frontend-react-js` directory, do an `npm run build` to build our configuration.

If you encounter a `setCognitoErrors` error, go into the mentioned files and change `setCognitoErrors` to `setErrors` instead. 

![Image of setCognitoErrors During an NPM build](assets/setCognitoErrors-during-npm-build.png)

After you have resolved the above error, your build should be successful now. 

In your `.gitignore` file, you can add these file paths so as to not commit them. 

```bash
docker/**/*
frontend-react-js/build/*
```

Now let’s build our new docker image from `Dockerfile.prod`. 

```bash
# remember to replace with your own values
docker build \
--build-arg REACT_APP_BACKEND_URL="http://cruddur-alb-402134244.us-west-2.elb.amazonaws.com:4567" \
--build-arg REACT_APP_AWS_PROJECT_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_COGNITO_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_USER_POOLS_ID="$REACT_APP_AWS_USER_POOLS_ID" \
--build-arg REACT_APP_CLIENT_ID="$REACT_APP_CLIENT_ID" \
-t frontend-react-js \
-f Dockerfile.prod \
.
```
  
</p>
</details>

<details><summary>Create the Frontend Service</summary>
<p> 

Now let’s create a JSON file for our frontend service to enable us easily launch the service. 

```bash
# create file
touch aws/json/service-frontend-react-js.json
```

Add the following content to the file:

```json
{
  "cluster": "cruddur",
  "launchType": "FARGATE",
  "desiredCount": 1,
  "enableECSManagedTags": true,
  "enableExecuteCommand": true,

  // NEW configuration added
  "loadBalancers": [
    {
        // replace with yours [frontend] 
        "targetGroupArn": "arn:aws:elasticloadbalancing:ca-central-1:387543059434:targetgroup/FRONTEND_TARGET_GRP/87ed2a3daf2d2b1d",
        "containerName": "frontend-react-js",
        "containerPort": 3000
    }
  ],

  "networkConfiguration": {
    "awsvpcConfiguration": {
      "assignPublicIp": "ENABLED",
      // replace with yours 
      "securityGroups": [
        "sg-04bdc8d5443cc8283"
      ],
      // replace with yours
      "subnets": [
        "subnet-0462b87709683ccaa",
        "subnet-066a53dd88d557e05",
        "subnet-021a6adafb79249e3"
      ]
    }
  },
  "propagateTags": "SERVICE",
  "serviceName": "frontend-react-js",
  "taskDefinition": "frontend-react-js",
  "serviceConnectConfiguration": {
    "enabled": true,
    "namespace": "cruddur",
    "services": [
      {
        "portName": "frontend-react-js",
        "discoveryName": "frontend-react-js",
        "clientAliases": [{"port": 3000}]
      }
    ]
  }
}
```

Use these commands below to find your `security grp` and `subnets` ids.

```bash
# grab the custom security grp ID
export CRUD_SERVICE_SG=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=crud-srv-sg \
  --query 'SecurityGroups[*].GroupId' \
  --output text)

# grab the DEFAULT security grp
export DEFAULT_VPC_ID=$(aws ec2 describe-vpcs \
--filters "Name=isDefault, Values=true" \
--query "Vpcs[0].VpcId" \
--output text)

echo $DEFAULT_VPC_ID

# grab the DEFAULT subnets 
export DEFAULT_SUBNET_IDS=$(aws ec2 describe-subnets  \
 --filters Name=vpc-id,Values=$DEFAULT_VPC_ID \
 --query 'Subnets[*].SubnetId' \
 --output json | jq -r 'join(",")')

echo $DEFAULT_SUBNET_IDS
```

Now we can go ahead to register our task definition.

```bash
aws ecs register-task-definition --cli-input-json file://aws/task-definitions/frontend-react-js.json
```

Confirm in your AWS console by navigating to your **ECS service** and selecting `task definitions`.

Now, we can create our service: 

```bash
aws ecs create-service --cli-input-json file://aws/json/service-frontend-react-js.json
```

Go over to your AWS console to confirm the service is created and the task in it is `running` successfully.

But in our case, we are getting `unhealthy` status for our `frontend` task.

<details><summary>Troubleshooting Unhealthy Status of the Frontend</summary>
<p> 

Go ahead and stop the `frontend` service from the AWS console. Now we will edit our `frontend-react-js.json` service file to remove the load balancer configuration so we can shell into our container to troubleshoot. Detaching the load balancer from our service enables us to shell into the container to debug. 

```json
// REMOVE
  "loadBalancers": [
    {
        // replace with yours [frontend] 
        "targetGroupArn": "arn:aws:elasticloadbalancing:ca-central-1:387543059434:targetgroup/FRONTEND_TARGET_GRP/87ed2a3daf2d2b1d",
        "containerName": "frontend-react-js",
        "containerPort": 3000
    }
  ],
```

After that update, relaunch the service again and check the AWS console to be sure the service started up alright and `healthy`.

Now let’s connect/shell into our frontend service container using the scripts we created for this purpose.

```bash
# enter into the task container 
./bin/ecs/connect-to-service TASK_ID frontend-react-js
```

This still fails with this error:

![Image of Failed Task - Frontend](assets/failed-task-frontend.png)

Let’s run a couple of debugging steps to resolve the error.

1. Let’s rebuild our `prd` environment locally to debug further 

```bash
# using our BACKEND_URL means we are building it locally
# be sure to be in the "frontend-react-js" directory
docker build \
--build-arg REACT_APP_BACKEND_URL="https://4567-$GITPOD_WORKSPACE_ID.$GITPOD_WORKSPACE_CLUSTER_HOST" \
--build-arg REACT_APP_AWS_PROJECT_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_COGNITO_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_USER_POOLS_ID="ca-central-1_CQ4wDfnwc" \
--build-arg REACT_APP_CLIENT_ID="5b6ro31g97urk767adrbrdj1g5" \
-t frontend-react-js \
-f Dockerfile.prod \
.
```

Now let’s run and test it:

```bash
docker run --rm -p 3000:3000 -it frontend-react-js
```

Let’s do an `inspect` inside the docker container to further debug. 

```bash
# check container ID
docker ps 

# inspect container 
docker inspect CONTAINER_ID
```

Check for the CMD and see what commands it has. You would notice there aren’t `bash` commands indicated, and it also says `daemon off`

Because of that, we had to make sure the image version, `alpine`, actually uses `bash`. But we found out that, by default, `bash` is not included with `BusyBox` and `Alpine` images. Because of this, we cannot shell into the container. But you can use the `sh` shell instead of `bash` for the `alpine` images.

Because we can't use `bash`, we need to hardcode `bin/sh` into our `connect-to-service` script in `backend-flask/bin/ecs` and create separate ones for frontend and backend services.

Now rename the `connect-to-service` file to `connect-to-backend-flask` and create another one for the frontend service, `connect-to-frontend-react-js`.

Content of the `connect-to-backend-flask` file:

```bash
#! /usr/bin/bash

if [ -z "$1" ]; then
  echo "No TASK_ID argument supplied eg ./bin/ecs/connect-to-backend-flask 99b2f8953616495e99545e5a6066fbb5d"
  exit 1
fi
TASK_ID=$1

CONTAINER_NAME=backend-flask

echo "TASK ID : $TASK_ID"
echo "Container Name: $CONTAINER_NAME"

aws ecs execute-command  \
--region $AWS_DEFAULT_REGION \
--cluster cruddur \
--task $TASK_ID \
--container $CONTAINER_NAME \
--command "/bin/bash" \
--interactive
```

Content of the `connect-to-frontend-react-js` file:

```bash
#! /usr/bin/bash

if [ -z "$1" ]; then
  echo "No TASK_ID argument supplied eg ./bin/ecs/connect-to-frontend-react-js 99b2f8953616495e99545e5a6066fbb5d"
  exit 1
fi
TASK_ID=$1

CONTAINER_NAME=frontend-react-js

echo "TASK ID : $TASK_ID"
echo "Container Name: $CONTAINER_NAME"

aws ecs execute-command  \
--region $AWS_DEFAULT_REGION \
--cluster cruddur \
--task $TASK_ID \
--container $CONTAINER_NAME \
--command "/bin/sh" \
--interactive
```

Don’t forget to give permission to script files. 

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/ecs/connect-to-frontend-react-js
chmod 555 backend-flask/bin/ecs/connect-to-backend-flask
  
# execute the script for frontend
./backend-flask/bin/ecs/connect-to-frontend-react-js TASK_ID
```

Now inside the container, do a `curl` to be sure our app is there.

```bash
curl localhost:3000
```

![Image of a Successful Curl Run](assets/successful-curl-run.png)

Let’s write a health check for our frontend service using `curl`. Go to your `aws/task-definitions/frontend-react-js.json` file and add this segment of code:

```bash
# add in the "containerDefinitions" section after "essential"
"healthCheck": {
        "command": [
          "CMD-SHELL",
          "curl -f http://localhost:3000 || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3
      },
```

This is to check if our application is running locally. 

After this configuration, let’s re-register our frontend task definitions.

```bash
aws ecs register-task-definition --cli-input-json file://aws/task-definitions/frontend-react-js.json
```

Now add back the `load balancer` config we removed earlier to debug.

In the `aws/json/service-frontend-react-js.json` file, 

```json
// ADD BACK
  "loadBalancers": [
    {
        // replace with yours [frontend] 
        "targetGroupArn": "arn:aws:elasticloadbalancing:ca-central-1:387543059434:targetgroup/FRONTEND_TARGET_GRP/87ed2a3daf2d2b1d",
        "containerName": "frontend-react-js",
        "containerPort": 3000
    }
  ],
```

Now re-launch the service again. Make sure there’s no running or draining one in your console. If there is, tear it down. 

```json
aws ecs create-service --cli-input-json file://aws/json/service-frontend-react-js.json
```

If the task still says `unhealthy`, `failed deployment` or `healthy`. Check the frontend target group to confirm this. If it truly says either of those, go ahead and investigate the security group associated with the front-end app.

When you navigate to the `security group`, edit the inbound rule and add one for the frontend. 

- Type: `Custom TCP`
  
- Port range: `3000`
  
- Source: same source as the backend one
  
- Description: `ALBfrontend`
  
- Change the description for the backend one to `ALBbackend`

Save your changes; now, you should have a `healthy` status. 

Copy your LB’s DNS name in your load balancer page and append `3000` to it as so - `DNS_name:3000`. You should now see data. 

You can confirm the address of your frontend by right-clicking on your browser, then selecting `Inspect` and navigating to the `Networks` tab to view the URL.

</p>
</details>

</p>
</details>


### 8. Manage your Domain using Route53 

Now we need to configure the custom domain we set up at the beginning of the BootCamp. Navigate to **Route53** on your AWS console, go to **Hosted zones**, and you should see one for the domain you created earlier - if you created this domain with Route53. If your domain wasn’t created with Route53, you will have to create a **hosted zone** in AWS for that domain. 

<details><summary>Create an SSL certificate via ACM (Certificate Manager)</summary>
<p> 

We need to **create records** for our domain. But before that, we need to create SSL certificates. 

- Navigate to **Certificate Manager (ACM)**

- Select **Request a certificate**
  
- Under the **Certification type**, select `Request a public certificate`. This is a free option as well.
  
- Click **Next**, and enter your `Fully qualified domain name` FQDN, which should be your domain name
  
    - Click on **Add another name to this certificate**
      
    - Enter `*.mydomain.com` - this is usually for subdomains
      
- Under the **Validation method**, leave `DNS validation` selected
  
- Under the **Key algorithm**, leave `RSA 2048` selected
  
- Now go ahead and click **Request**

After you request, you will find out that it says `pending validation`. 

- Go ahead and click on the certificate you just requested.
  
- Scroll down to the **Domains** section, and click `Create records in Route 53` to create records for the domains we just requested.
  
    - Select both domains and click **Create**
    
- Be patient; it’s going to take a while to propagate those domains.
  
    - On your ACM page, after a while, you should now see a `Success` status for both FQDNs you requested.
      
- After some time, go back to Route53 and check if a record with a `CNAME` has been added.

</p>
</details>


### 9. Set Up a Record Set for a Naked Domain to point to the Frontend

Now we have our certificates ready, let’s navigate to our load balancers to re-route our applications. 

- On the load balancers page, select our load balancer, `cruddur-alb`
  
- Scroll down and select the **Listeners** tab to edit our listeners.
  
    - Click on `Add listener`
      
    - Under the **Listener details**, leave the port and protocol configurations as is.
    
    - For the default actions, add an action **Redirect** to redirect our port to the `HTTPS` protocol and `443` port - since we now have an SSL certificate
      
    - You can change the **status code** to `302 - Found`
      
- Now go ahead and **Add**

Let’s add another listener to forward our `HTTPS` port to our frontend app.

- Under the **Listener details**, change the protocol and port to `HTTPS` and `443`
  
- For the default actions, add an action **Forward** to forward our port to the `frontend-react-js` target group - this forwards the HTTPS port to our frontend app.
  
- Under the **Secure Listener settings**, add the SSL certificate we created.

- Now go ahead and **Add**

After those configurations, go ahead and delete the listeners we have for `3000` and `4567`.

<details><summary>Manage rules for HTTPS port</summary>
<p> 

Our `HTTPS` port already forwards to our frontend. 

- Select the `HTTPS:443` listener you just created, and click on **Actions** at the top left of the page.
  
- Click on **Manage rules**
  
- Click the **+** and then click the blue link that says **Insert Rule**
  
- In the **IF (all match)** column, click the `Add condition` and select **Host headers** with the value `api.mydomain.com`
  
- In the **THEN** column, click the `Add action` and select **Forward** with value backend target group.
    
![Image of Newly Configured Rules](assets/newly-configured-rules.png)

After this configuration, it is not going to work because we need to update our origins and rebuild our images. Also, we need to point our domain to our load balancer. 

- Navigate to **Route53**, and select your hosted zone to create another record.
  
    - Record type: `A - Routes traffic to an IPv4 address and some AWS resources`
      
    - Toggle on `Alias`
      
    - Route traffic to: `Alias to Application and Classic Load Balancer`, your_region, select your load balancer
      
    - Routing policy: `Simple routing`
      
    - Make sure the **Evaluate target health** is toggled on
      
    - Now go ahead and click **Create records**

</p>
</details>


### 10. Set Up a Record Set for API Subdomain to point to the Backend

We need to point our API subdomain to our backend in the load balancer. 

<details><summary>Set Up API Subdomain</summary>
<p> 

Let's navigate to **Route53** and select your hosted zone to create another record.

- Record name: `api`
  
- Record type: `A - Routes traffic to an IPv4 address and some AWS resources`
  
- Toggle on `Alias`
  
- Route traffic to: `Alias to Application and Classic Load Balancer`, your_region, select your load balancer
  
- Routing policy: `Simple routing`
  
- Make sure the **Evaluate target health** is toggled on

- Now go ahead and click **Create records**

To test out our subdomain, run this command in your CLI

```bash
ping api.mydomain.com
curl https://api.mydomain.com/api/health-check

# The URL might not work in the browser, but you can try 
# If it works in Firefox but not Chrome - try clearing the cache
https://api.mydomain.com/api/health-check
```

</p>
</details>


### 11. Configure CORS to Only Permit Traffic from our Domain 

Now let’s configure CORS only to allow traffic from our domain.

<details><summary>Configure CORS</summary>
<p> 

In your `aws/json/task-definitions/backend-flask.json` file, edit your `FRONTEND_URL` and `BACKEND_URL`:

```json
{"name": "FRONTEND_URL", "value": "mydomain.com"},
{"name": "BACKEND_URL", "value": "api.mydomain.com"},
```

Now let’s add these changes to our ECS by re-registering it:

```json
aws ecs register-task-definition --cli-input-json file://aws/task-definitions/backend-flask.json
```

### Login to ECR

We need to log in to ECR to retrieve an authentication token and authenticate your Docker client to your registry; run the following command in your terminal.

```bash
aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
```

### Set URL

This is a way to map to our new repo’s URI. 

```bash
# set our URL as an environment variable 
export ECR_FRONTEND_REACT_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/frontend-react-js"

# set our URL as an environment variable - GitPod
gp env ECR_FRONTEND_REACT_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/frontend-react-js"

# ensure it matches the one in your AWS console
echo $ECR_FRONTEND_REACT_URL
```

### Build Image

Now, let’s build our image. Be sure to change your `REACT_APP_BACKEND_URL` to your own subdomain for the backend. 

```bash
# make sure to be in your frontend-react-js folder 
docker build \
--build-arg REACT_APP_BACKEND_URL="https://api.simplynaturell.com" \
--build-arg REACT_APP_AWS_PROJECT_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_COGNITO_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_USER_POOLS_ID="$REACT_APP_AWS_USER_POOLS_ID" \
--build-arg REACT_APP_CLIENT_ID="$REACT_APP_CLIENT_ID" \
-t frontend-react-js \
-f Dockerfile.prod \
.
```

### Tag Image

Let’s tag the image we just built

```bash
docker tag frontend-react-js:latest $ECR_FRONTEND_REACT_URL:latest

# to confirm the image was properly tagged
docker images 
```

### Push Image

Now, go ahead and push the image to ECR

```bash
docker push $ECR_FRONTEND_REACT_URL:latest
```

If your ECS services were already running during the new update you made to the backend `task-definition` file, in your ECS service, update each of the services (frontend & backend).

### Update service - backend

- Click the backend service, then select an **Action** from the top right corner of your page
  
- Under the **Deployment configuration**, check the box for `Force new deployment`
  
    - Scroll down to **Revision** and change that to the `LATEST` - 11 (LATEST)
      
- Go ahead and click **Update**

### Update service - frontend

- Click the frontend service, then select an **Action** from the top right corner of your page
  
- Under the **Deployment configuration**, check the box for `Force new deployment`
  
    - Scroll down to **Revision** and change that to the `LATEST` - 7 (LATEST)
      
- Go ahead and click **Update**

After the updates, wait for a while for the services to finish deploying. When done, you should see a `healthy` status for the tasks. 

Also, make your way to the load balancer to be sure they are both passing their health checks - `healthy` status. 

Now go ahead and check your domain in the browser to be sure they work. 

**NOTE:** Chrome might or might not work. You can try another browser. 

*URLs to try:*

- `https://api.mydomain.com`
  
- `https://api.mydomain.com/api/health-check`
  
- `https://mydomain.com`

For the frontend, the app sure displays in the browser but no returned data. Also, doing an `Inspect` on that browser page, you should see a CORS error for your subdomain, `api.mydomain.com`.

<details><summary>Troubleshooting CORS on Subdomain</summary>
<p> 

Let’s investigate why the CORS error on our subdomain is happening. 

Grab the `TASK_ID` of your backend service to be able to connect to the container. 

```bash
# connect to my task
./bin/ecs/connect-to-backend-flask TASK_ID
```

Once inside the task, type `env` to be sure our URLs for the frontend and backend are properly set. 

You should see that our `FRONTEND_URL` is set to be `mydomain.com`, and our `BACKEND-URL` is set to be `api.mydomain.com`, with no protocols attached to it like `https://mydomain.com` and `https://api.mydomain.com` respectively.

Now navigate to your `backend-flask.json` file in your `task-definitions` folder to edit those URLs again. 

```json
{"name": "FRONTEND_URL", "value": "https://mydomain.com"},
{"name": "BACKEND_URL", "value": "https://api.mydomain.com"},
```

After these updates, we need to re-register our task definitions for our changes to be reflected. And also **force a new deployment** through ECS. 

After these changes, wait for a while for the new deployments to kick in, and then test the application again. Now, it should be returning data. You can also try signing into your app.

</p>
</details>

</p>
</details>


### 12. Secure Flask by not Running in DEBUG Mode

We don’t need the debug mode in our `backend-flask` for security purposes. It gives away too much information about our application. For our production environment, we need to remove this debugging mode. 

Check out this [documentation](https://flask.palletsprojects.com/en/2.2.x/debugging/) regarding debugging application errors in production.

Because of this information, we need to limit the IP address in our load balancer to only `My IP` for the time being. 

- Navigate to the **Security Group** of your load balancer located under the **EC2 service**
  
- Select the security group, `cruddur-alb-sg`, and edit the inbound rules
  
- Delete the port ranges `4567` and `3000`
  
- Edit the rest, `443` and `80` ports (HTTPS & HTTP protocols), with **Source** as `My IP`
  
- Go ahead and **Save** the changes.

This change will lock the application down to be accessed only from your computer.

<details><summary>Security - Backend Implementation</summary>
<p> 

Navigate to your `backend-flask` folder and edit the `Dockerfile` to add the flag `--debug` to the CMD command at the end of the file. This will allow debugging in our development environment. 

```bash
# CMD (Command)
# python3 -m flask run --host=0.0.0.0 --port=4567
CMD [ "python3", "-m" , "flask", "run", "--host=0.0.0.0", "--port=4567", "--debug"]
```

Still in the directory, create a `Dockerfile.prod` file for our backend production. The only difference with both docker files is the debugging flags in the CMD. 

Content of the `Dockerfile.prod` file:

```bash
# replace with your own ECR_PYTHON_URL
FROM 387543059434.dkr.ecr.ca-central-1.amazonaws.com/cruddur-python:3.10-slim-buster

# [TODO] For debugging, don't leave these in
#RUN apt-get update -y
#RUN apt-get install iputils-ping -y
# -----

# Inside Container
# make a new folder inside container
WORKDIR /backend-flask

# Outside Container -> Inside Container
# this contains the libraries want to install to run the app
COPY requirements.txt requirements.txt

# Inside Container
# Install the python libraries used for the app
RUN pip3 install -r requirements.txt

# Outside Container -> Inside Container
# . means everything in the current directory
# first period . - /backend-flask (outside container)
# second period . /backend-flask (inside container)
COPY . .

EXPOSE ${PORT}

# CMD (Command)
# python3 -m flask run --host=0.0.0.0 --port=4567
CMD [ "python3", "-m" , "flask", "run", "--host=0.0.0.0", "--port=4567", "--no-debug","--no-debugger","--no-reload"]
```

Let’s build our `Dockerfile.prod` file separately using the CLI. First, we have to log in to ECR again. 

### Login to ECR

Now to be able to pull and push to ECR, we need to log in to ECR. So to retrieve an authentication token and authenticate your Docker client to your registry, run the following command in your terminal.

```bash
aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
```

Logging into ECR is now a repetitive task, so let’s create a script to make our lives easier. 

In your `backend-flask/bin` folder, create a folder `ecr` with file `login` 

```bash
mkdir backend-flask/bin/ecr

# create file
touch backend-flask/bin/ecr/login

# FILE CONTENT 

#! /usr/bin/bash
aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com"
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/ecr/login
  
# execute the script 
./backend-flask/bin/ecr/login
```

Now we can build our `Dockerfile.prod`

```bash
# make sure to be in the "backend-flask" directory
docker build -f Dockerfile.prod -t backend-flask-prod .
```

Let’s test out this production build by running it with environment variables.

In your `backend-flask/bin` directory, create a folder `docker` with the file `backend-flask-prod`. 

```bash
mkdir backend-flask/bin/docker

# create file
touch backend-flask/bin/docker/backend-flask-prod

# FILE CONTENT 

#! /usr/bin/bash
docker run --rm \
-p 4567:4567 \
--env AWS_ENDPOINT_URL="http://dynamodb-local:8000" \
--env CONNECTION_URL="postgresql://postgres:password@db:5432/cruddur" \
--env FRONTEND_URL="https://3000-${GITPOD_WORKSPACE_ID}.${GITPOD_WORKSPACE_CLUSTER_HOST}" \
--env BACKEND_URL="https://4567-${GITPOD_WORKSPACE_ID}.${GITPOD_WORKSPACE_CLUSTER_HOST}" \
--env OTEL_SERVICE_NAME='backend-flask' \
--env OTEL_EXPORTER_OTLP_ENDPOINT="https://api.honeycomb.io" \
--env OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=${HONEYCOMB_API_KEY}" \
--env AWS_XRAY_URL="*4567-${GITPOD_WORKSPACE_ID}.${GITPOD_WORKSPACE_CLUSTER_HOST}*" \
--env AWS_XRAY_DAEMON_ADDRESS="xray-daemon:2000" \
--env AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION}" \
--env AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}" \
--env AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}" \
--env ROLLBAR_ACCESS_TOKEN="${ROLLBAR_ACCESS_TOKEN}" \
--env AWS_COGNITO_USER_POOL_ID="${AWS_COGNITO_USER_POOL_ID}" \
--env AWS_COGNITO_USER_POOL_CLIENT_ID="${AWS_COGNITO_USER_POOL_CLIENT_ID}" \
-it backend-flask-prod
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/docker/backend-flask-prod
  
# execute the script 
./backend-flask/bin/docker/backend-flask-prod
```

**Note**: Make sure you are running your PostgreSQL db to avoid getting a `connection pools error`. You can do that by simply doing a `docker compose up`. You can choose to do a select service and start up only the `db` and `dynamodb`, your choice.

Now try opening your backend URL on the browser and append `/api/activities/home` in the URL; you should notice that it is hanging. That’s because we are still getting connection errors. Right now, that shouldn’t be our problem; our major concern is to see if errors are logged in debug mode. 

Navigate to the `app.py` file so we can purposely raise an error in our health check API. 

```bash
# in your app.py file
# under the health-check API, before the return statement
# add these lines to introduce an error
hello = None
hello()
```

Make sure you have your app started up - `docker compose up`. 

Now rebuild production, and let’s test it out. Let’s create some scripts to help us with those rebuilds and tests. 

In `backend-flask/bin/docker/` directory, create another folder, `build`, and `run`. Move the `backend-flask-prod` script to the `run` folder. 

```bash
# create folders
mkdir backend-flask/bin/docker/build
mkdir backend-flask/bin/docker/run

# move file
mv backend-flask/bin/docker/backend-flask-prod backend-flask/bin/docker/run/backend-flask-prod

# create files
touch backend-flask/bin/docker/build/backend-flask-prod
touch backend-flask/bin/docker/build/frontend-react-js-prod
```

To ensure you have the right permissions to execute the newly created scripts, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/docker/build/backend-flask-prod
chmod 555 backend-flask/bin/docker/build/frontend-react-js-prod
  
# execute the script 
./backend-flask/bin/docker/build/backend-flask-prod
./backend-flask/bin/docker/build/frontend-react-js-prod
```

Content of the `build/backend-flask-prod` file:

```bash
#! /usr/bin/bash

docker build -f Dockerfile.prod -t backend-flask-prod .
```

Now let’s check if our changes work in development. Navigate to the backend URL, and append the `/api/health-check` endpoint to your URL. You should get a `TypeError` page due to the error we introduced in the health check API. 

Because we see a `TypeError` page with some details, we know our `--debug` flag works. 

![Image of Debug TypeError Page](assets/debug-typeerror-page.png)

To also test that our `--no-debug` flag works in our production environment, let’s test it out in our development environment. 

In your `Dockerfile` in the `backend-flask` folder, change the `--debug` flag to a `--no-debug` flag. 

After this update, restart your app again. Once it’s started up, open the backend URL and append `/api/health-check` endpoint to it. Now, you should get this error which shows that our flags in each environment work. 

![Image of No Debug Internal Server Error](assets/no-debug-internal-server-error-page.png)

Go ahead and redo the flags to what it was. `--debug` flag for development and `--no-debug` flag for production.

**Remember to delete the extra stuff you added to your health check API.**

<details><summary>Push & Tag the New Images Created</summary>
<p> 

Instead of having always to type in our push and tag commands, let’s create scripts for those.

### Backend

In `backend-flask/bin/docker` directory, create another folder, `push` with file `backend-flask-prod` 

```bash
mkdir backend-flask/bin/docker/push
touch backend-flask/bin/docker/push/backend-flask-prod
```

```bash
#! /usr/bin/bash

ECR_BACKEND_FLASK_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/backend-flask"
echo $ECR_BACKEND_FLASK_URL

# Tag image 
docker tag backend-flask-prod:latest $ECR_BACKEND_FLASK_URL:latest

# Push image
docker push $ECR_BACKEND_FLASK_URL:latest
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/docker/push/backend-flask-prod
  
# execute the script 
./backend-flask/bin/docker/push/backend-flask-prod
```

### Frontend

In `bin/docker/push` directory, create a file `frontend-react-js-prod`

```bash
# create file
touch backend-flask/bin/docker/push/frontend-react-js-prod
```

Content of the `frontend-react-js-prod` file:

```bash
#! /usr/bin/bash

ECR_FRONTEND_REACT_URL="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/frontend-react-js"
echo $ECR_FRONTEND_REACT_URL

# Tag image
docker tag frontend-react-js:latest $ECR_FRONTEND_REACT_URL:latest

# Push image
docker push $ECR_FRONTEND_REACT_URL:latest
```

</p>
</details>

<details><summary>Use Latest Task Definition for Deployment</summary>
<p> 

### Backend

To force a new deployment for our `backend-flask` service, every time we make an update to our task definition, we will create a script to do that for us.

In `backend-flask/bin/ecs` directory, create a file `force-deploy-backend-flask`

```bash
#! /usr/bin/bash

CLUSTER_NAME="cruddur"
SERVICE_NAME="backend-flask"
TASK_DEFINTION_FAMILY="backend-flask"

LATEST_TASK_DEFINITION_ARN=$(aws ecs describe-task-definition \
--task-definition $TASK_DEFINTION_FAMILY \
--query 'taskDefinition.taskDefinitionArn' \
--output text)

aws ecs update-service \
--cluster $CLUSTER_NAME \
--service $SERVICE_NAME \
--task-definition $LATEST_TASK_DEFINITION_ARN \
--force-new-deployment

#aws ecs describe-services \
#--cluster $CLUSTER_NAME \
#--service $SERVICE_NAME \
#--query 'services[0].deployments' \
#--output table
```

### Frontend

To force a new deployment for our `frontend-react-js` service, every time we make an update to our task definition, we will create a script to do that for us.

In `bin/ecs` directory, create a file `force-deploy-frontend-react-js`

```bash
# create file
touch backend-flask/bin/ecs/force-deploy-frontend-react-js
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/ecs/force-deploy-frontend-react-js
  
# execute the script 
./backend-flask/bin/ecs/force-deploy-frontend-react-js
```

Content of the `force-deploy-frontend-react-js` file:

```bash
#! /usr/bin/bash

CLUSTER_NAME="cruddur"
SERVICE_NAME="frontend-react-js"
TASK_DEFINTION_FAMILY="frontend-react-js"

LATEST_TASK_DEFINITION_ARN=$(aws ecs describe-task-definition \
--task-definition $TASK_DEFINTION_FAMILY \
--query 'taskDefinition.taskDefinitionArn' \
--output text)

aws ecs update-service \
--cluster $CLUSTER_NAME \
--service $SERVICE_NAME \
--task-definition $LATEST_TASK_DEFINITION_ARN \
--force-new-deployment
```

</p>
</details>

</p>
</details>



### 13. Refactor the `bin/` directory to be a top-level directory

Because we are experiencing some errors with pathing in our scripts, we are moving up our directories and removing some of the scripts. 

<details><summary>Refactoring the bin directory</summary>
<p> 

Let’s move our `backend-flask/bin` folder to our project root directory. 

```bash
# from the root of the project
mv backend-flask/bin/ bin/
```

Let’s start with our `frontend-react-js-prod` script,

```bash
#! /usr/bin/bash

ABS_PATH=$(readlink -f "$0")
BUILD_PATH=$(dirname $ABS_PATH)
DOCKER_PATH=$(dirname $BUILD_PATH)
BIN_PATH=$(dirname $DOCKER_PATH)
PROJECT_PATH=$(dirname $BIN_PATH)
FRONTEND_REACT_JS_PATH="$PROJECT_PATH/frontend-react-js"

docker build \
--build-arg REACT_APP_BACKEND_URL="https://4567-$GITPOD_WORKSPACE_ID.$GITPOD_WORKSPACE_CLUSTER_HOST" \
--build-arg REACT_APP_AWS_PROJECT_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_COGNITO_REGION="$AWS_DEFAULT_REGION" \
--build-arg REACT_APP_AWS_USER_POOLS_ID="$REACT_APP_AWS_USER_POOLS_ID" \
--build-arg REACT_APP_CLIENT_ID="$REACT_APP_CLIENT_ID" \
-t frontend-react-js \
-f "$FRONTEND_REACT_JS_PATH/Dockerfile.prod" \
"$FRONTEND_REACT_JS_PATH/."
```

Test out the file and see if it builds. 

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 bin/docker/build/frontend-react-js-prod
  
# execute the script 
./bin/docker/build/frontend-react-js-prod
```

After building your frontend production image, go ahead to tag and push to ECR. 

```bash
./bin/docker/push/frontend-react-js-prod
```

Let’s move on and do the same with our `backend-flask-prod` file in the `build` directory.

```bash
#! /usr/bin/bash

ABS_PATH=$(readlink -f "$0")
BUILD_PATH=$(dirname $ABS_PATH)
DOCKER_PATH=$(dirname $BUILD_PATH)
BIN_PATH=$(dirname $DOCKER_PATH)
PROJECT_PATH=$(dirname $BIN_PATH)
BACKEND_FLASK_PATH="$PROJECT_PATH/backend-flask"

docker build \
-f "$BACKEND_FLASK_PATH/Dockerfile.prod" \
-t backend-flask-prod \
"$BACKEND_FLASK_PATH/."
```

After changes, go ahead and rebuild the image and push to ECR.

```bash
# build image 
./bin/docker/build/backend-flask-prod

# tag and push
./bin/docker/push/backend-flask-prod
```

<details><summary>The db Folder</summary>
<p> 

In this folder, we will be modifying most of its files. 

For `db/schema-load`, 

```bash
# after the color definitions
ABS_PATH=$(readlink -f "$0")
BIN_PATH=$(dirname $ABS_PATH)
PROJECT_PATH=$(dirname $BIN_PATH)
BACKEND_FLASK_PATH="$PROJECT_PATH/backend-flask"
schema_path="$BACKEND_FLASK_PATH/db/schema.sql"
echo $schema_path

# below, change to this
psql $URL cruddur < $schema_path
```

For `db/seed`,

```bash
CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="db-seed"
printf "${CYAN}== ${LABEL}${NO_COLOR}\n"

ABS_PATH=$(readlink -f "$0")
BIN_PATH=$(dirname $ABS_PATH)
PROJECT_PATH=$(dirname $BIN_PATH)
BACKEND_FLASK_PATH="$PROJECT_PATH/backend-flask"
seed_path="$BACKEND_FLASK_PATH/db/seed.sql"
echo $seed_path

if [ "$1" = "prd" ]; then
  echo "Running in production mode"
  URL=$PRD_CONNECTION_URL
else
  URL=$CONNECTION_URL
fi

psql $URL cruddur < $seed_path
```

For `db/setup`,

```bash
#! /usr/bin/bash
set -e # stop if it fails at any point

CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="db-setup"
printf "${CYAN}==== ${LABEL}${NO_COLOR}\n"

ABS_PATH=$(readlink -f "$0")
DB_PATH=$(dirname $ABS_PATH)

source "$DB_PATH/drop"
source "$DB_PATH/create"
source "$DB_PATH/schema-load"
source "$DB_PATH/seed"
python "$DB_PATH/update_cognito_user_ids"
```

</p>
</details>

For `gitpod.yml`, 

```bash
# remove backend-flask
source "$THEIA_WORKSPACE_ROOT/bin/rds/update-sg-rule"
```

After all the modifications, rebuild both backend and frontend images, if not rebuilt already, so we can test out our production environment. 

- Navigate to the `prd` URL using your API subdomain - `api.mydomain.com`
  
- If it says `site not reached`, that’s not true. Clear your cache or use a different browser.
  
- Check out the following URLs
  
    - `api.mydomain.com/api/health-check`
      
    - `api.mydomain.com/api/activities/home`
      
    - append some erroneous stuff to the URL to be sure our `no-debug` flag is working properly in `prd`

</p>
</details>


### 14. Fix Messaging in Production

<details><summary>Install Boto3</summary>
<p> 
  
</p>
</details>

<details><summary>Install Boto3</summary>
<p> 
  
</p>
</details>



