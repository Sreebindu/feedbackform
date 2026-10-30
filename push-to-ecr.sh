#!/usr/bin/env bash
set -Eeuo pipefail

AWS_REGION="ap-south-1"
ECR_REPO="feedbackform"
IMAGE_TAG="latest"

echo "=================================="
echo " AWS ECR Automated Image Push"
echo "=================================="

# 1. Check prerequisites
for cmd in aws docker; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd is not installed."
        exit 1
    fi
done

if ! docker info >/dev/null 2>&1; then
    echo "ERROR: Cannot access Docker daemon."
    echo "Check Docker permissions or service."
    exit 1
fi

# 2. Fetch AWS Account ID automatically
echo "[1/6] Fetching AWS Account ID..."

AWS_ACCOUNT_ID=$(aws sts get-caller-identity \
    --query Account --output text)

if [[ ! "$AWS_ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
    echo "ERROR: Invalid AWS account ID."
    exit 1
fi

echo "AWS Account ID: $AWS_ACCOUNT_ID"

# 3. Find newest local Docker image
echo "[2/6] Finding latest local Docker image..."

SOURCE_IMAGE=$(docker image ls \
    --format '{{.Repository}}:{{.Tag}}' \
    --filter dangling=false | \
    while IFS= read -r image; do
        [[ "$image" == *"<none>"* ]] && continue
        created=$(docker image inspect "$image" \
            --format '{{.Created}}')
        printf '%s %s\n' "$created" "$image"
    done | sort -r | head -n 1 | cut -d' ' -f2-)

if [[ -z "$SOURCE_IMAGE" ]]; then
    echo "ERROR: No usable Docker images found."
    exit 1
fi

echo "Selected image: $SOURCE_IMAGE"

# 4. Create ECR repository if missing
echo "[3/6] Checking ECR repository..."

if ! aws ecr describe-repositories \
    --repository-names "$ECR_REPO" \
    --region "$AWS_REGION" >/dev/null 2>&1; then

    echo "Creating ECR repository: $ECR_REPO"

    aws ecr create-repository \
        --repository-name "$ECR_REPO" \
        --region "$AWS_REGION" >/dev/null
fi

# 5. Authenticate Docker with ECR
echo "[4/6] Logging into AWS ECR..."

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_IMAGE="${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"

aws ecr get-login-password --region "$AWS_REGION" | \
    docker login \
        --username AWS \
        --password-stdin "$ECR_REGISTRY"

# 6. Tag and push image
echo "[5/6] Tagging image..."

docker tag "$SOURCE_IMAGE" "$ECR_IMAGE"

echo "[6/6] Pushing image to ECR..."

docker push "$ECR_IMAGE"

echo ""
echo "=================================="
echo " IMAGE PUSH COMPLETED"
echo "=================================="
echo "Source image : $SOURCE_IMAGE"
echo "ECR image    : $ECR_IMAGE"
echo "Region       : $AWS_REGION"
echo "Repository   : $ECR_REPO"
