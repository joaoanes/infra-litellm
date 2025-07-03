#!/bin/bash
set -ex
set -o pipefail

# Install Docker
for i in {1..5}; do sudo apt-get update -y && break; sleep 5; done
sudo apt-get install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -a -G docker ubuntu

# Install Docker Compose
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo curl -SL "https://github.com/docker/compose/releases/download/v2.2.3/docker-compose-linux-x86_64" -o /usr/local/lib/docker/cli-plugins/docker-compose
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# Install Caddy
sudo apt-get install -y curl gnupg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt-get update
sudo apt-get install caddy

# Create LiteLLM config
mkdir -p /home/ubuntu/litellm
cat <<EOF > /home/ubuntu/litellm/config.yaml
model_list:
  - model_name: gpt-4.1
    litellm_params:
      model: openai/gpt-4.1
      litellm_credential_name: openai_credential
  - model_name: o4-mini
    litellm_params:
      model: openai/o4-mini
      litellm_credential_name: openai_credential
  - model_name: o3
    litellm_params:
      model: openai/o3
      litellm_credential_name: openai_credential
  - model_name: claude-4-opus-20250514
    litellm_params:
      model: anthropic/claude-4-opus-20250514
      litellm_credential_name: anthropic_credential
  - model_name: gemini-2.5-pro
    litellm_params:
      model: gemini/gemini-2.5-pro
      litellm_credential_name: gemini_credential
  - model_name: gemini-2.5-flash
    litellm_params:
      model: gemini/gemini-2.5-flash
      litellm_credential_name: gemini_credential

litellm_settings:
  set_verbose: True

credential_list:
  - credential_name: openai_credential
    credential_values:
      api_key: os.environ/OPENAI_API_KEY
    credential_info:
      description: "OpenAI API Key"
  - credential_name: anthropic_credential
    credential_values:
      api_key: os.environ/ANTHROPIC_API_KEY
    credential_info:
      description: "Anthropic API Key"
  - credential_name: gemini_credential
    credential_values:
      api_key: os.environ/GEMINI_API_KEY
    credential_info:
      description: "Gemini API Key"
EOF

# Create .env file
cat <<EOF > /home/ubuntu/litellm/.env
OPENAI_API_KEY=$1
ANTHROPIC_API_KEY=$2
GEMINI_API_KEY=$3
AZURE_API_KEY=$4
AZURE_API_BASE=$5
LITELLM_MASTER_KEY=$6
UI_USERNAME=$7
UI_PASSWORD=$8
DATABASE_URL=postgresql://llmproxy:${10}@db:5432/litellm
POSTGRES_USER=llmproxy
POSTGRES_PASSWORD=${10}
POSTGRES_DB=litellm
STORE_MODEL_IN_DB=True
EOF
# Create Docker Compose file
cat <<EOF > /home/ubuntu/litellm/docker-compose.yml
version: "3.11"
services:
  litellm:
    image: ghcr.io/berriai/litellm:main-stable
    ports:
      - "127.0.0.1:4000:4000"
    environment:
      DATABASE_URL: "postgresql://llmproxy:${10}@db:5432/litellm"
      STORE_MODEL_IN_DB: "True"
    env_file:
      - .env
    depends_on:
      - db
    healthcheck:
      test: [ "CMD-SHELL", "wget --no-verbose --tries=1 http://localhost:4000/health/liveliness || exit 1" ]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    volumes:
      - ./config.yaml:/app/config.yaml
    command:
      - "--config=/app/config.yaml"

  db:
    image: postgres:16
    restart: always
    container_name: litellm_db
    environment:
      POSTGRES_DB: litellm
      POSTGRES_USER: llmproxy
      POSTGRES_PASSWORD: ${10}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -d litellm -U llmproxy"]
      interval: 1s
      timeout: 5s
      retries: 10

volumes:
  postgres_data:
    name: litellm_postgres_data
EOF

# Create Caddyfile
cat <<EOF | sudo tee /etc/caddy/Caddyfile
$9 {
    reverse_proxy localhost:4000
}
EOF

# Start services
sudo docker compose -f /home/ubuntu/litellm/docker-compose.yml up -d

sudo systemctl reload caddy
