# Environment variables used in CI build
ALPHA_VERSION="${VERSION}-alpha.${CI_PIPELINE_ID}" # used if CI_COMMIT_TAG is not present
export APP_VERSION="${CI_COMMIT_TAG:-${ALPHA_VERSION}}"
export CURRENT_UID="$(id -u):$(id -g)"
export ECR_NAMESPACE="truedat"
export K8S_DEPLOYMENT="dq"
export K8S_CONTAINER="dq"

subcommand=$1
case "$subcommand" in
  ecr-login)
    LOGIN_SCRIPT=$(docker run --rm -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION mesosphere/aws-cli ecr get-login --no-include-email --region ${AWS_DEFAULT_REGION})
    eval ${LOGIN_SCRIPT}
    export ECR=$(echo $LOGIN_SCRIPT | cut -d/ -f3)
    ;;
esac
