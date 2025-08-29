#!/bin/bash

# kubectl Version Manager - Simple nvm-like tool for kubectl
# Usage: 
#   source kubectl-version-manager.sh
#   kubectl-use 1.32.2
#   kubectl-use 1.34.0
#   kubectl-list

KUBECTL_VERSIONS_DIR="$HOME/.kubectl-versions"
CURRENT_KUBECTL_LINK="$HOME/.local/bin/kubectl"

# Ensure directories exist
mkdir -p "$KUBECTL_VERSIONS_DIR"
mkdir -p "$HOME/.local/bin"

# Add to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi

kubectl-use() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        echo "Usage: kubectl-use <version>"
        echo "Example: kubectl-use 1.32.2"
        return 1
    fi
    
    local kubectl_path=""
    
    # Try to find the version in known locations
    case "$version" in
        "1.34.0"|"1.34"|"latest")
            kubectl_path="/opt/homebrew/bin/kubectl"
            version="1.34.0"
            ;;
        "1.32.2"|"1.32"|"docker")
            kubectl_path="/usr/local/bin/kubectl"
            version="1.32.2"
            ;;
        *)
            # Check if it exists in our managed versions
            if [[ -f "$KUBECTL_VERSIONS_DIR/kubectl-$version" ]]; then
                kubectl_path="$KUBECTL_VERSIONS_DIR/kubectl-$version"
            else
                echo "❌ kubectl version $version not found"
                echo "💡 Available versions:"
                kubectl-list
                return 1
            fi
            ;;
    esac
    
    if [[ ! -f "$kubectl_path" ]]; then
        echo "❌ kubectl binary not found at: $kubectl_path"
        return 1
    fi
    
    # Create/update symlink
    ln -sf "$kubectl_path" "$CURRENT_KUBECTL_LINK"
    
    echo "✅ Switched to kubectl $version"
    echo "📍 Using: $kubectl_path"
    echo "🔗 Linked to: $CURRENT_KUBECTL_LINK"
    
    # Verify
    "$CURRENT_KUBECTL_LINK" version --client 2>/dev/null || echo "⚠️  Version check failed"
}

kubectl-list() {
    echo "📦 Available kubectl versions:"
    echo ""
    
    # Check known system installations
    if [[ -f "/opt/homebrew/bin/kubectl" ]]; then
        local version=$(grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' <<< "$(/opt/homebrew/bin/kubectl version --client 2>/dev/null)" | head -1)
        echo "  homebrew: $version → /opt/homebrew/bin/kubectl"
    fi
    
    if [[ -f "/usr/local/bin/kubectl" ]]; then
        local version=$(grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' <<< "$(/usr/local/bin/kubectl version --client 2>/dev/null)" | head -1)
        echo "  docker:   $version → /usr/local/bin/kubectl"
    fi
    
    # Check managed versions
    if [[ -d "$KUBECTL_VERSIONS_DIR" ]] && ls "$KUBECTL_VERSIONS_DIR"/kubectl-* >/dev/null 2>&1; then
        echo ""
        echo "  managed versions:"
        for kubectl_bin in "$KUBECTL_VERSIONS_DIR"/kubectl-*; do
            if [[ -f "$kubectl_bin" ]]; then
                local version=$(basename "$kubectl_bin" | sed 's/kubectl-//')
                echo "  $version → $kubectl_bin"
            fi
        done
    fi
    
    echo ""
    # Show current
    if [[ -L "$CURRENT_KUBECTL_LINK" ]]; then
        local current_target=$(readlink "$CURRENT_KUBECTL_LINK")
        local current_version=$(grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' <<< "$("$CURRENT_KUBECTL_LINK" version --client 2>/dev/null)" | head -1)
        echo "🔗 Currently using: $current_version → $current_target"
    else
        echo "🔗 Currently using: system kubectl ($(which kubectl))"
    fi
}

kubectl-current() {
    if [[ -L "$CURRENT_KUBECTL_LINK" ]]; then
        "$CURRENT_KUBECTL_LINK" version --client 2>/dev/null
    else
        echo "Using system kubectl: $(which kubectl)"
        kubectl version --client 2>/dev/null
    fi
}

kubectl-install() {
    local version="$1"
    
    if [[ -z "$version" ]]; then
        echo "Usage: kubectl-install <version>"
        echo "Example: kubectl-install 1.33.3"
        return 1
    fi
    
    local download_url="https://dl.k8s.io/release/v${version}/bin/darwin/amd64/kubectl"
    local target_path="$KUBECTL_VERSIONS_DIR/kubectl-$version"
    
    echo "📥 Downloading kubectl $version..."
    
    if curl -fsSL "$download_url" -o "$target_path"; then
        chmod +x "$target_path"
        echo "✅ kubectl $version installed to $target_path"
        echo "💡 Use 'kubectl-use $version' to switch to it"
    else
        echo "❌ Failed to download kubectl $version"
        rm -f "$target_path"
        return 1
    fi
}

# Show current status when sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "💡 Source this script to use kubectl version management:"
    echo "   source kubectl-version-manager.sh"
else
    echo "🚀 kubectl Version Manager loaded"
    echo "💡 Commands: kubectl-use, kubectl-list, kubectl-current, kubectl-install"
    echo ""
    kubectl-list
fi