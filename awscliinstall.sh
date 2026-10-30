# Update packages
sudo apt update

# Install required packages
sudo apt install -y curl unzip

# Download AWS CLI v2 (x86_64)
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Extract
unzip -q awscliv2.zip

# Install
sudo ./aws/install
