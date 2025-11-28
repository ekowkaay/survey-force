#!/bin/bash
#
# Survey Force LWC Package - Deployment Script
# This script helps deploy the LWC-only package to a Salesforce org
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Salesforce CLI is installed
if ! command -v sf &> /dev/null; then
    print_error "Salesforce CLI (sf) is not installed. Please install it first."
    echo "Visit: https://developer.salesforce.com/tools/salesforcecli"
    exit 1
fi

print_info "Salesforce CLI found: $(sf --version)"

# Get org alias
echo ""
echo "Enter your Salesforce org alias (or press Enter to authenticate a new org):"
read -r ORG_ALIAS

if [ -z "$ORG_ALIAS" ]; then
    print_info "No alias provided. Please authenticate to your org..."
    sf org login web --alias survey-force-lwc
    ORG_ALIAS="survey-force-lwc"
fi

# Verify org connection
print_info "Verifying connection to org: $ORG_ALIAS"
if ! sf org display --target-org "$ORG_ALIAS" &> /dev/null; then
    print_error "Cannot connect to org '$ORG_ALIAS'. Please check the alias or authenticate again."
    echo ""
    echo "To list authenticated orgs, run: sf org list"
    echo "To authenticate, run: sf org login web --alias $ORG_ALIAS"
    exit 1
fi

print_info "Connected to org: $ORG_ALIAS"

# Ask for deployment method
echo ""
echo "Choose deployment method:"
echo "1) Deploy from source (recommended)"
echo "2) Deploy using manifest"
echo "3) Validate only (no deployment)"
echo ""
read -rp "Enter choice (1-3): " DEPLOY_METHOD

case $DEPLOY_METHOD in
    1)
        print_info "Deploying LWC package from source..."
        sf project deploy start --source-dir force-app-lwc --target-org "$ORG_ALIAS" --wait 10
        ;;
    2)
        print_info "Deploying LWC package using manifest..."
        sf project deploy start --manifest force-app-lwc/manifest/package.xml --target-org "$ORG_ALIAS" --wait 10
        ;;
    3)
        print_info "Validating LWC package..."
        sf project deploy start --source-dir force-app-lwc --target-org "$ORG_ALIAS" --wait 10 --dry-run
        ;;
    *)
        print_error "Invalid choice. Exiting."
        exit 1
        ;;
esac

if [ $? -eq 0 ]; then
    print_info "✅ Deployment completed successfully!"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Post-Installation Steps"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "1. Configure object and field-level security"
    echo "   - Grant read/create access to Survey objects"
    echo "   - Configure guest user permissions if needed"
    echo ""
    echo "2. Add LWC components to Lightning pages"
    echo "   - Use Lightning App Builder"
    echo "   - Add surveyTaker component to pages"
    echo ""
    echo "3. For Experience Sites:"
    echo "   - Configure guest user permissions"
    echo "   - Add components via Experience Builder"
    echo "   - Mark surveys as 'Publicly Available'"
    echo ""
    echo "4. Run tests to verify installation:"
    echo "   sf apex run test --target-org $ORG_ALIAS --result-format human"
    echo ""
    echo "For detailed instructions, see: LWC_PACKAGE_README.md"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    print_error "❌ Deployment failed. Please check the errors above."
    exit 1
fi
