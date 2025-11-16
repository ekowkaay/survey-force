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

# Check if SFDX is installed
if ! command -v sfdx &> /dev/null; then
    print_error "Salesforce CLI (sfdx) is not installed. Please install it first."
    echo "Visit: https://developer.salesforce.com/tools/sfdxcli"
    exit 1
fi

print_info "Salesforce CLI found: $(sfdx --version)"

# Get org alias
echo ""
echo "Enter your Salesforce org alias (or press Enter to authenticate a new org):"
read -r ORG_ALIAS

if [ -z "$ORG_ALIAS" ]; then
    print_info "No alias provided. Please authenticate to your org..."
    sfdx auth:web:login -a survey-force-lwc
    ORG_ALIAS="survey-force-lwc"
fi

# Verify org connection
print_info "Verifying connection to org: $ORG_ALIAS"
if ! sfdx force:org:display -u "$ORG_ALIAS" &> /dev/null; then
    print_error "Cannot connect to org '$ORG_ALIAS'. Please check the alias or authenticate again."
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
        sfdx force:source:deploy -p force-app-lwc -u "$ORG_ALIAS" -w 10
        ;;
    2)
        print_info "Deploying LWC package using manifest..."
        sfdx force:source:deploy -x force-app-lwc/manifest/package.xml -u "$ORG_ALIAS" -w 10
        ;;
    3)
        print_info "Validating LWC package..."
        sfdx force:source:deploy -p force-app-lwc -u "$ORG_ALIAS" -w 10 --checkonly
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
    echo "   sfdx force:apex:test:run -u $ORG_ALIAS -r human"
    echo ""
    echo "For detailed instructions, see: LWC_PACKAGE_README.md"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
else
    print_error "❌ Deployment failed. Please check the errors above."
    exit 1
fi
