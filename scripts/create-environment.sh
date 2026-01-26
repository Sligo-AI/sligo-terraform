#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
EXAMPLES_DIR="$REPO_ROOT/examples"
ENVIRONMENTS_DIR="$REPO_ROOT/environments"

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to prompt for input with validation
prompt_input() {
    local prompt_text="$1"
    local var_name="$2"
    local default_value="${3:-}"
    local validation_func="${4:-}"
    
    while true; do
        if [ -n "$default_value" ]; then
            read -p "$(echo -e "${BLUE}?${NC} $prompt_text ${YELLOW}[$default_value]${NC}: ")" input
            input="${input:-$default_value}"
        else
            read -p "$(echo -e "${BLUE}?${NC} $prompt_text: ")" input
        fi
        
        if [ -z "$input" ]; then
            print_error "This field is required. Please enter a value."
            continue
        fi
        
        if [ -n "$validation_func" ] && ! $validation_func "$input"; then
            continue
        fi
        
        eval "$var_name='$input'"
        break
    done
}

# Validation functions
validate_infrastructure_type() {
    local infra="$1"
    if [[ "$infra" != "aws-eks" && "$infra" != "gcp-gke" ]]; then
        print_error "Invalid infrastructure type. Must be 'aws-eks' or 'gcp-gke'"
        return 1
    fi
    return 0
}

validate_environment_name() {
    local name="$1"
    # Check for valid characters (alphanumeric, hyphens, underscores)
    if [[ ! "$name" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        print_error "Environment name can only contain letters, numbers, hyphens, and underscores"
        return 1
    fi
    
    # Check if environment already exists
    local env_dir="$ENVIRONMENTS_DIR/${infrastructure_type}-${name}"
    if [ -d "$env_dir" ]; then
        print_error "Environment '${infrastructure_type}-${name}' already exists at $env_dir"
        return 1
    fi
    
    return 0
}

validate_aws_region() {
    local region="$1"
    # Basic AWS region format validation (us-east-1, eu-west-1, etc.)
    if [[ ! "$region" =~ ^[a-z]+-[a-z]+-[0-9]+$ ]]; then
        print_error "Invalid AWS region format. Expected format: us-east-1, eu-west-1, etc."
        return 1
    fi
    return 0
}

validate_gcp_region() {
    local region="$1"
    # Basic GCP region format validation (us-central1, europe-west1, etc.)
    if [[ ! "$region" =~ ^[a-z]+-[a-z]+[0-9]*$ ]]; then
        print_error "Invalid GCP region format. Expected format: us-central1, europe-west1, etc."
        return 1
    fi
    return 0
}

# Function to get default cluster name
get_default_cluster_name() {
    local env_name="$1"
    echo "sligo-${env_name}"
}

# Function to get default domain name
get_default_domain_name() {
    local env_name="$1"
    echo "${env_name}.example.com"
}

# Function to get default GCP zones from region
get_default_gcp_zones() {
    local region="$1"
    echo "[\"${region}-a\", \"${region}-b\"]"
}

# Main script
main() {
    echo ""
    print_info "Creating a new Sligo Cloud environment"
    echo ""
    
    # Check if examples directory exists
    if [ ! -d "$EXAMPLES_DIR" ]; then
        print_error "Examples directory not found: $EXAMPLES_DIR"
        exit 1
    fi
    
    # Create environments directory if it doesn't exist
    mkdir -p "$ENVIRONMENTS_DIR"
    
    # Prompt for infrastructure type
    prompt_input "Infrastructure type (aws-eks/gcp-gke)" "infrastructure_type" "" "validate_infrastructure_type"
    
    # Check if example template exists
    local example_dir="$EXAMPLES_DIR/$infrastructure_type"
    if [ ! -d "$example_dir" ]; then
        print_error "Example template not found: $example_dir"
        exit 1
    fi
    
    # Prompt for environment name
    prompt_input "Environment name (e.g., dev, staging, prod, prod-eu, customer-xyz)" "environment_name" "" "validate_environment_name"
    
    # Set up region validation based on infrastructure type
    if [ "$infrastructure_type" = "aws-eks" ]; then
        prompt_input "AWS region (e.g., us-east-1, us-west-2, eu-west-1, eu-central-1)" "region" "us-east-1" "validate_aws_region"
    else
        prompt_input "GCP region (e.g., us-central1, us-east1, europe-west1, europe-west4)" "region" "us-central1" "validate_gcp_region"
    fi
    
    # Prompt for optional fields with defaults
    local default_cluster_name=$(get_default_cluster_name "$environment_name")
    prompt_input "Cluster name" "cluster_name" "$default_cluster_name"
    
    local default_domain=$(get_default_domain_name "$environment_name")
    prompt_input "Domain name" "domain_name" "$default_domain"
    
    # Create environment directory
    local env_dir="$ENVIRONMENTS_DIR/${infrastructure_type}-${environment_name}"
    
    echo ""
    print_info "Creating environment directory: $env_dir"
    mkdir -p "$env_dir"
    
    # Copy files from example template
    print_info "Copying files from example template..."
    cp -r "$example_dir"/* "$env_dir/"
    
    # Remove terraform.tfvars.example if it exists (we'll create terraform.tfvars)
    if [ -f "$env_dir/terraform.tfvars.example" ]; then
        rm "$env_dir/terraform.tfvars.example"
    fi
    
    # Generate terraform.tfvars from example
    if [ -f "$example_dir/terraform.tfvars.example" ]; then
        print_info "Generating terraform.tfvars..."
        
        # Read the example file and substitute values
        local tfvars_file="$env_dir/terraform.tfvars"
        
        # Copy the example file
        cp "$example_dir/terraform.tfvars.example" "$tfvars_file"
        
        # Update values based on infrastructure type
        # Detect sed syntax for macOS vs Linux
        if [[ "$OSTYPE" == "darwin"* ]]; then
            local sed_inplace="sed -i ''"
        else
            local sed_inplace="sed -i"
        fi
        
        if [ "$infrastructure_type" = "aws-eks" ]; then
            # Update AWS-specific values
            $sed_inplace "s/cluster_name.*=.*\".*\"/cluster_name    = \"$cluster_name\"/" "$tfvars_file"
            $sed_inplace "s/aws_region.*=.*\".*\"/aws_region      = \"$region\"/" "$tfvars_file"
            $sed_inplace "s/domain_name.*=.*\".*\"/domain_name                    = \"$domain_name\"/" "$tfvars_file"
        else
            # Update GCP-specific values
            $sed_inplace "s/cluster_name.*=.*\".*\"/cluster_name    = \"$cluster_name\"/" "$tfvars_file"
            $sed_inplace "s/gcp_region.*=.*\".*\"/gcp_region      = \"$region\"/" "$tfvars_file"
            $sed_inplace "s/domain_name.*=.*\".*\"/domain_name              = \"$domain_name\"/" "$tfvars_file"
            
            # Update GCP zones based on region
            local default_zones=$(get_default_gcp_zones "$region")
            $sed_inplace "s/gcp_zones.*=.*\[.*\]/gcp_zones       = $default_zones/" "$tfvars_file"
        fi
    else
        print_warning "terraform.tfvars.example not found in example template"
    fi
    
    # Create a simple README for the environment
    local env_readme="$env_dir/README.md"
    cat > "$env_readme" << EOF
# ${infrastructure_type}-${environment_name}

This environment was created using the \`make create-environment\` command.

## Configuration

- **Infrastructure**: ${infrastructure_type}
- **Region**: ${region}
- **Cluster Name**: ${cluster_name}
- **Domain**: ${domain_name}

## Next Steps

1. Copy your Sligo service account key to this directory:
   \`\`\`bash
   cp /path/to/sligo-service-account-key.json ${env_dir}/
   \`\`\`

2. Update \`terraform.tfvars\` with your secrets and configuration:
   - Set \`client_repository_name\` (provided by Sligo support)
   - Set \`sligo_service_account_key_path\` to \`"./sligo-service-account-key.json"\`
   - Update all secrets (jwt_secret, api_key, nextauth_secret, gateway_secret, etc.)
   - Generate encryption_key: \`openssl rand -hex 32\`

3. Initialize Terraform:
   \`\`\`bash
   cd ${env_dir}
   terraform init
   \`\`\`

4. Review and apply:
   \`\`\`bash
   terraform plan
   terraform apply
   \`\`\`

## Important Notes

- This \`terraform.tfvars\` file contains sensitive information and is ignored by git
- Never commit secrets to version control
- Use environment variables or secrets managers for production deployments
EOF
    
    echo ""
    print_success "Environment created successfully!"
    echo ""
    print_info "Environment directory: $env_dir"
    echo ""
    print_info "Next steps:"
    echo "  1. Copy your Sligo service account key to: $env_dir/"
    echo "  2. Edit $env_dir/terraform.tfvars with your configuration"
    echo "  3. Run: cd $env_dir && terraform init"
    echo ""
}

# Run main function
main
