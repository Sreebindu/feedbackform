# Student Feedback Form — Deployment on AWS EC2 with Docker and Amazon ECR

A hands-on Cloud Computing and DevOps project demonstrating how to deploy a responsive student feedback webpage from GitHub to an AWS EC2 Ubuntu server, containerize it using Apache HTTP Server, and publish its Docker image to Amazon Elastic Container Registry (ECR).

> **Deployment status:** The Apache Docker container was observed running and serving HTTP `200 OK` in the lab. The steps to push the image to ECR were prepared, but successful ECR upload has **not yet been verified** in the shared terminal output.

## Tech stack

- **Frontend:** HTML, CSS, Bootstrap 5, JavaScript
- **Version control:** Git and GitHub
- **Cloud VM:** Amazon EC2 (Ubuntu)
- **Web server:** Apache HTTP Server (`httpd:2.4`)
- **Containerization:** Docker
- **Image registry:** Amazon ECR (private repository)
- **Automation:** Bash and AWS CLI v2

## Architecture

```text
Developer
   |
   v
GitHub repository (index.html, Dockerfile)
   |
   | git clone / git pull
   v
AWS EC2 Ubuntu
   |
   | docker build
   v
Docker image (Apache + feedback form)
   |                           |
   | docker run -p 80:80       | docker tag && docker push
   v                           v
Web browser                 Amazon ECR
http://EC2-PUBLIC-IP        feedbackform:latest
```

## Project files

```text
feedbackform/
├── index.html       # Feedback form UI and client-side success message
├── Dockerfile       # Apache HTTP Server image configuration
└── README.md        # Deployment documentation
```

> **Important:** The current frontend shows “Feedback submitted successfully!” after client-side validation; it **does not store submissions**. A backend API/database is required to collect actual student feedback.

## Prerequisites

1. AWS account with permissions to manage EC2, IAM roles, and ECR.
2. Ubuntu EC2 instance with a **public IPv4 address** and a subnet route to an internet gateway.
3. EC2 security group allowing **SSH (22) from your IP** and **HTTP (80)** for intended website visitors.
4. An existing GitHub repository containing `index.html` and `Dockerfile`.
5. An EC2 instance IAM role with permissions to push Docker images to ECR (use least-privilege permissions for production).

## 1. Launch and connect to EC2

In the AWS console, open **EC2 → Launch instance**, select **Ubuntu Server**, choose an appropriate instance size, select a key pair, and configure the security group. Connect using **EC2 Instance Connect**, SSH, or MobaXterm.

Verify the operating system:

```bash
cat /etc/os-release
```

## 2. Install Git and Docker

```bash
sudo apt update
sudo apt install -y git docker.io curl unzip
sudo systemctl enable --now docker
sudo docker --version
git --version
```

The commands below use `sudo docker` for compatibility with default Ubuntu permissions.

## 3. Clone the application from GitHub

Replace `YOUR_USERNAME` with your GitHub account name:

```bash
cd ~
git clone https://github.com/YOUR_USERNAME/feedbackform.git
cd feedbackform
ls -la
```

If the repo already exists:

```bash
cd ~/feedbackform
git pull origin main
```

## 4. Containerize the feedback form with Apache

Create this `Dockerfile` beside `index.html`:

```dockerfile
FROM httpd:2.4
WORKDIR /usr/local/apache2/htdocs/
COPY index.html /usr/local/apache2/htdocs/index.html
RUN echo "ServerName localhost" >> /usr/local/apache2/conf/httpd.conf
EXPOSE 80
ENTRYPOINT ["httpd"]
CMD ["-D", "FOREGROUND"]
```

The `ServerName` line suppresses a harmless Apache startup warning. Avoid adding `--address 0.0.0.0` after the image name in `docker run`: it overrides the Dockerfile's `CMD` and causes Apache to exit.

## 5. Build and launch the application

```bash
cd ~/feedbackform
sudo docker build -t feedbackform:v1 .
sudo docker rm -f feedbackform 2>/dev/null || true
sudo docker run -d \
  --name feedbackform \
  --restart unless-stopped \
  -p 80:80 \
  feedbackform:v1
```

Check the deployment:

```bash
sudo docker ps
sudo docker logs --tail 30 feedbackform
curl -I http://localhost
```

Expected HTTP response: `HTTP/1.1 200 OK`.

Open **`http://YOUR-EC2-PUBLIC-IP`** on your own computer. Use the actual public IPv4 address from EC2, not the instance's private `172.31.x.x` address or `localhost`. If it doesn't load externally, check public IP, security group, route table, network ACL, and host firewall.

## 6. Install AWS CLI v2 on Ubuntu

Check architecture:

```bash
uname -m
```

For **x86_64** instances:

```bash
curl -fsSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip -q awscliv2.zip
sudo ./aws/install
aws --version
```

For **aarch64** instances, download `https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip` instead.

## 7. Configure ECR permissions and create the repository

In the AWS console:

1. Go to **IAM → Roles → Create role**, choose **AWS service → EC2**, and attach appropriate ECR push permissions (for a lab, `AmazonEC2ContainerRegistryPowerUser` can be used).
2. Go to **EC2 → Instances → select instance → Actions → Security → Modify IAM role** and attach the role. Check whether an existing role must be preserved before replacing it.
3. Open **Amazon ECR → Private repositories → Create repository**. Choose region **Asia Pacific (Mumbai), `ap-south-1`**, and name the repository **`feedbackform`**.

Verify identity from EC2:

```bash
aws sts get-caller-identity
```

An EC2 role provides temporary credentials, so there is no need to put AWS access keys in the repository.

## 8. Authenticate, tag, and push the image to ECR

This example pushes the image built in Step 5 (`feedbackform:v1`). The AWS account ID is obtained automatically:

```bash
set -e
AWS_REGION=ap-south-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_IMAGE="${ECR_REGISTRY}/feedbackform:latest"

aws ecr get-login-password --region "$AWS_REGION" | \
  sudo docker login --username AWS --password-stdin "$ECR_REGISTRY"

sudo docker tag feedbackform:v1 "$ECR_IMAGE"
sudo docker push "$ECR_IMAGE"

echo "Pushed: $ECR_IMAGE"
```

If you prefer to push your **existing Docker Hub image** instead of the locally built one, first run `sudo docker pull dockerdemo/dockerproject:latest` and change the tag command to:

```bash
sudo docker tag dockerdemo/dockerproject:latest "$ECR_IMAGE"
```

Only tag the image you intend to deploy; the newest local image is not always the feedback application.

### Verify the ECR image

```bash
aws ecr describe-images \
  --repository-name feedbackform \
  --region ap-south-1
```

You should see an image with the `latest` tag and a digest after a successful push. You can also verify it in **Amazon ECR → Private repositories → feedbackform → Images**.

## 9. Optional: Pull from ECR and run on EC2

Use the same `ECR_IMAGE` variables from Step 8:

```bash
sudo docker pull "$ECR_IMAGE"
sudo docker rm -f feedbackform
sudo docker run -d \
  --name feedbackform \
  --restart unless-stopped \
  -p 80:80 \
  "$ECR_IMAGE"
curl -I http://localhost
```

ECR stores container images; EC2, ECS, or EKS actually runs them.

## 10. Redeploy after updating GitHub

```bash
cd ~/feedbackform
git pull origin main
sudo docker build -t feedbackform:v2 .
sudo docker rm -f feedbackform
sudo docker run -d \
  --name feedbackform \
  --restart unless-stopped \
  -p 80:80 \
  feedbackform:v2
```

To publish this new version to ECR, retag `feedbackform:v2` with the ECR URI and push again.

## Useful troubleshooting commands

| Purpose | Command |
|---|---|
| Show local images | `sudo docker images` |
| Show running containers | `sudo docker ps` |
| Show stopped containers | `sudo docker ps -a` |
| Inspect application logs | `sudo docker logs feedbackform` |
| Test Apache locally | `curl -I http://localhost` |
| Check Git remote | `git remote -v` |
| Verify AWS identity | `aws sts get-caller-identity` |
| Check ECR image tags | `aws ecr list-images --repository-name feedbackform --region ap-south-1` |

## Learning outcomes

This practical exercise demonstrates source control, cloud VM provisioning, Linux administration, Dockerfile creation, image builds, container deployment, HTTP testing, IAM roles, and ECR image publishing.

## Future enhancements

- Implement a backend API and database to actually save submitted feedback.
- Add HTTPS and a domain name before using the site with real students.
- Add GitHub Actions to automate Docker builds and ECR pushes.
- Deploy the image using Amazon ECS for managed container orchestration.

---

**Project:** Student Feedback Form | **Platform:** AWS | **Web server:** Apache HTTP Server | **Image repository:** Amazon ECR
