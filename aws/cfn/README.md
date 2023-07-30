## Architecture Guide

Before you run any templates, be sure to create an S3 bucket to contain
all of our artifacts for CloudFormation.

```
# create an S3 bucket 
aws s3 mb s3://cfn-artifacts --region us-west-1 

# set in terminal
export CFN_BUCKET="cfn-artifacts"
gp env CFN_BUCKET="cfn-artifacts"
```

> remember bucket names are unique to the provide code example you may need to adjust