set -e

# Populate Required Variables
AWS_PARTITION=aws
VENDED_ACCOUNT_ID=259487073613
DEFAULT_PATH=$(pwd)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
TF_VERSION=$(aws ssm get-parameter --name "/aft/config/terraform/version" --query "Parameter.Value" --output text --profile aft)
TF_DISTRIBUTION=$(aws ssm get-parameter --name "/aft/config/terraform/distribution" --query "Parameter.Value" --output text --profile aft)
CT_MGMT_REGION=$(aws ssm get-parameter --name "/aft/config/ct-management-region" --query "Parameter.Value" --output text --profile aft)
AFT_MGMT_ACCOUNT=$(aws ssm get-parameter --name "/aft/account/aft-management/account-id" --query "Parameter.Value" --output text --profile aft)
AFT_EXEC_ROLE_ARN=arn:$AWS_PARTITION:iam::$AFT_MGMT_ACCOUNT:role/AWSAFTExecution
VENDED_EXEC_ROLE_ARN=arn:$AWS_PARTITION:iam::$VENDED_ACCOUNT_ID:role/AWSAFTExecution
AFT_ADMIN_ROLE_NAME=$(aws ssm get-parameter --name /aft/resources/iam/aft-administrator-role-name --profile aft | jq --raw-output ".Parameter.Value")
AFT_ADMIN_ROLE_ARN=arn:$AWS_PARTITION:iam::$AFT_MGMT_ACCOUNT:role/$AFT_ADMIN_ROLE_NAME
ROLE_SESSION_NAME=$(aws ssm get-parameter --name /aft/resources/iam/aft-session-name --profile aft | jq --raw-output ".Parameter.Value")
AFT_MGMT_ROLE=$(aws ssm get-parameter --name /aft/resources/iam/aft-administrator-role-name --profile aft | jq --raw-output ".Parameter.Value")
CUSTOMIZATION=master-account

#echo AWS_PARTITION: ${AWS_PARTITION}
#echo TF_VERSION: ${TF_VERSION}
#echo TF_DISTRIBUTION: ${TF_DISTRIBUTION}
#echo CT_MGMT_REGION: ${CT_MGMT_REGION}
#echo AFT_MGMT_ACCOUNT: ${AFT_MGMT_ACCOUNT}
#echo AFT_EXEC_ROLE_ARN: ${AFT_EXEC_ROLE_ARN}
#echo VENDED_EXEC_ROLE_ARN: $VENDED_EXEC_ROLE_ARN
#echo AFT_ADMIN_ROLE_NAME: $AFT_ADMIN_ROLE_NAME
#echo AFT_ADMIN_ROLE_ARN: $AFT_ADMIN_ROLE_ARN
#echo ROLE_SESSION_NAME: $ROLE_SESSION_NAME
#echo CUSTOMIZATION: $CUSTOMIZATION

# Check if customization directory exists
if [ ! -z $CUSTOMIZATION ]; then  
  if [ ! -d "$DEFAULT_PATH/$CUSTOMIZATION" ]; then
    echo "Error: ${CUSTOMIZATION} directory does not exist"
    exit 1
  fi
  echo "Found customization" $CUSTOMIZATION
  
  # Clone AFT
  AWS_MODULE_SOURCE=$(aws ssm get-parameter --name "/aft/config/aft-pipeline-code-source/repo-url" --query "Parameter.Value" --output text --profile aft)
  AWS_MODULE_GIT_REF=$(aws ssm get-parameter --name "/aft/config/aft-pipeline-code-source/repo-git-ref" --query "Parameter.Value" --output text --profile aft)
  #git config --global credential.helper '!aws codecommit credential-helper $@'
  #git config --global credential.UseHttpPath true
  #git clone --quiet -b $AWS_MODULE_GIT_REF $AWS_MODULE_SOURCE aws-aft-core-framework

  echo AWS_MODULE_SOURCE: $AWS_MODULE_SOURCE
  echo AWS_MODULE_GIT_REF: $AWS_MODULE_GIT_REF

  # Generate session profiles
  echo "Generating credentials for ${AFT_MGMT_ROLE} in aft-management account: ${AFT_MGMT_ACCOUNT}"
  credentials=$(aws sts assume-role --role-arn "arn:${AWS_PARTITION}:iam::${AFT_MGMT_ACCOUNT}:role/${AFT_MGMT_ROLE}" --role-session-name "${ROLE_SESSION_NAME}")

  echo $CREDENTIALS
  profile=aft-management-admin
  aws_access_key_id="$(echo "${credentials}" | jq --raw-output ".Credentials[\"AccessKeyId\"]")"
  aws_secret_access_key="$(echo "${credentials}" | jq --raw-output ".Credentials[\"SecretAccessKey\"]")"
  aws_session_token="$(echo "${credentials}" | jq --raw-output ".Credentials[\"SessionToken\"]")"

  aws configure set aws_access_key_id "${aws_access_key_id}" --profile "${profile}"
  aws configure set aws_secret_access_key "${aws_secret_access_key}" --profile "${profile}"
  aws configure set aws_session_token "${aws_session_token}" --profile "${profile}"

  if [ ! -z "$CUSTOMIZATION" ]; then 
    #source $DEFAULT_PATH/aft-venv/bin/activate
    if [ $TF_DISTRIBUTION = "oss" ]; then
      TF_BACKEND_REGION=$(aws ssm get-parameter --name "/aft/config/oss-backend/primary-region" --query "Parameter.Value" --output text --profile aft)
      TF_KMS_KEY_ID=$(aws ssm get-parameter --name "/aft/config/oss-backend/kms-key-id" --query "Parameter.Value" --output text --profile aft)
      TF_DDB_TABLE=$(aws ssm get-parameter --name "/aft/config/oss-backend/table-id" --query "Parameter.Value" --output text --profile aft)
      TF_S3_BUCKET=$(aws ssm get-parameter --name "/aft/config/oss-backend/bucket-id" --query "Parameter.Value" --output text --profile aft)
      TF_S3_KEY=$VENDED_ACCOUNT_ID-aft-master-account-customizations/terraform.tfstate

      #cd /tmp
      #echo "Installing Terraform"
      #curl -q -o terraform_${TF_VERSION}_linux_amd64.zip https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip
      #mkdir -p /opt/aft/bin
      #unzip -q -o terraform_${TF_VERSION}_linux_amd64.zip 
      #mv terraform /opt/aft/bin
      #/opt/aft/bin/terraform --version

      cd $DEFAULT_PATH/$CUSTOMIZATION/terraform
      for f in *.jinja; do jinja2 $f -D timestamp="$TIMESTAMP" -D tf_distribution_type=$TF_DISTRIBUTION -D provider_region=$CT_MGMT_REGION -D region=$TF_BACKEND_REGION -D aft_admin_role_arn=$AFT_EXEC_ROLE_ARN -D target_admin_role_arn=$VENDED_EXEC_ROLE_ARN -D bucket=$TF_S3_BUCKET -D key=$TF_S3_KEY -D dynamodb_table=$TF_DDB_TABLE -D kms_key_id=$TF_KMS_KEY_ID >> ./$(basename $f .jinja).tf; done
      for f in *.tf; do echo "\n \n"; echo $f; cat $f; done
            
      cd $DEFAULT_PATH/$CUSTOMIZATION/terraform
      export AWS_PROFILE=aft-management-admin
      
      #/opt/aft/bin/terraform init
      #/opt/aft/bin/terraform apply --auto-approve
      terraform init
      terraform plan
    #else
    #  TF_BACKEND_REGION=$(aws ssm get-parameter --name "/aft/config/oss-backend/primary-region" --query "Parameter.Value" --output text)
    #  TF_ORG_NAME=$(aws ssm get-parameter --name "/aft/config/terraform/org-name" --query "Parameter.Value" --output text)
    #  TF_TOKEN=$(aws ssm get-parameter --name "/aft/config/terraform/token" --with-decryption --query "Parameter.Value" --output text)
    #  TF_ENDPOINT=$(aws ssm get-parameter --name "/aft/config/terraform/api-endpoint" --query "Parameter.Value" --output text)
    #  TF_WORKSPACE_NAME=$VENDED_ACCOUNT_ID-aft-account-customizations
    #  TF_CONFIG_PATH="./temp_configuration_file.tar.gz"

    #  cd $DEFAULT_PATH/$CUSTOMIZATION/terraform
    #  for f in *.jinja; do jinja2 $f -D timestamp="$TIMESTAMP" -D provider_region=$CT_MGMT_REGION -D tf_distribution_type=$TF_DISTRIBUTION -D aft_admin_role_arn=$AFT_EXEC_ROLE_ARN -D target_admin_role_arn=$VENDED_EXEC_ROLE_ARN -D terraform_org_name=$TF_ORG_NAME -D terraform_workspace_name=$TF_WORKSPACE_NAME  >> ./$(basename $f .jinja).tf; done
    #  for f in *.tf; do echo "\n \n"; echo $f; cat $f; done
         
    #  cd $DEFAULT_PATH/$CUSTOMIZATION
    #  tar -czf temp_configuration_file.tar.gz -C terraform --exclude .git --exclude venv .
    #  python3 $DEFAULT_PATH/aws-aft-core-framework/sources/scripts/workspace_manager.py --operation "deploy" --organization_name $TF_ORG_NAME --workspace_name $TF_WORKSPACE_NAME --assume_role_arn $AFT_ADMIN_ROLE_ARN --assume_role_session_name $ROLE_SESSION_NAME --api_endpoint $TF_ENDPOINT --api_token $TF_TOKEN --terraform_version $TF_VERSION --config_file $TF_CONFIG_PATH
    fi
  fi
fi       

