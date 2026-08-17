#!/bin/bash

# Yet Another LuCI App Local Build Script
# Usage: ./scripts/build.sh [community|playstore|all] [--official|--unofficial] [--apk|--appbundle] [--enable-ads] [--enable-support-dev]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Auto-load Java 17/21 if default Java is 25 to avoid Gradle compatibility issues
if [ -z "${JAVA_HOME}" ] || "${JAVA_HOME}/bin/java" -version 2>&1 | grep -q 'version "25'; then
    for jdk in "${HOME}/development/jdk17" "${HOME}/.gradle/jdks/eclipse_adoptium-17-amd64-linux.2" "/usr/lib/jvm/java-17-openjdk" "/usr/lib/jvm/java-21-openjdk"; do
        if [ -d "${jdk}" ] && [ -x "${jdk}/bin/java" ]; then
            export JAVA_HOME="${jdk}"
            export PATH="${JAVA_HOME}/bin:${PATH}"
            break
        fi
    done
fi

# Ensure Flutter binary is in PATH
if ! command -v flutter &> /dev/null; then
    if [ -d "${HOME}/development/flutter/bin" ]; then
        export PATH="${HOME}/development/flutter/bin:${PATH}"
    fi
fi

# Auto-load Community Keystore credentials from .private/nightcode-community if available
COMMUNITY_DIR="${PROJECT_ROOT}/.private/nightcode-community"
if [ -f "${COMMUNITY_DIR}/nightcode-community-release.jks" ] && [ -f "${COMMUNITY_DIR}/passwords.txt" ]; then
    export KEYSTORE_PATH="${COMMUNITY_DIR}/nightcode-community-release.jks"
    export KEYSTORE_PASSWORD=$(grep '^KEYSTORE_PASSWORD=' "${COMMUNITY_DIR}/passwords.txt" | cut -d'=' -f2)
    export KEY_PASSWORD=$(grep '^KEY_PASSWORD=' "${COMMUNITY_DIR}/passwords.txt" | cut -d'=' -f2)
    export KEY_ALIAS=$(grep '^KEY_ALIAS=' "${COMMUNITY_DIR}/passwords.txt" | cut -d'=' -f2)
fi

cd "${PROJECT_ROOT}"

# Extract version from pubspec.yaml
VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | tr -d '\r\n')
RAW_VER=$(echo "${VERSION}" | cut -d'+' -f1)
BUILD_NUM=$(echo "${VERSION}" | cut -d'+' -f2)

FLAVOR="community"
OFFICIAL="false"
TARGET="apk"
ENABLE_ADS="false"
ENABLE_SUPPORT_DEV="false"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    community|playstore|all|--all)
      if [[ "$1" == "--all" ]]; then
        FLAVOR="all"
      else
        FLAVOR="$1"
      fi
      shift
      ;;
    --official)
      OFFICIAL="true"
      shift
      ;;
    --unofficial)
      OFFICIAL="false"
      shift
      ;;
    --apk)
      TARGET="apk"
      shift
      ;;
    --appbundle|--aab)
      TARGET="appbundle"
      shift
      ;;
    --enable-ads)
      ENABLE_ADS="true"
      shift
      ;;
    --enable-support-dev)
      ENABLE_SUPPORT_DEV="true"
      shift
      ;;
    -h|--help)
      echo "Yet Another LuCI App Local Build Helper"
      echo ""
      echo "Usage: ./scripts/build.sh [FLAVOR] [FLAGS...]"
      echo ""
      echo "Flavors:"
      echo "  community        Build FOSS Community Edition (default)"
      echo "  playstore        Build Play Store Edition"
      echo "  all              Build both Community & Play Store flavors"
      echo ""
      echo "Flags:"
      echo "  --official       Flag build as Official Release (OFFICIAL_BUILD=true)"
      echo "  --unofficial     Flag build as Unofficial / Local Release (default: OFFICIAL_BUILD=false)"
      echo "  --apk            Build APK package (default)"
      echo "  --appbundle      Build App Bundle (.aab)"
      echo "  --enable-ads     Enable AdMob ads SDK"
      echo "  --enable-support-dev  Enable Support Developer UI"
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Run './scripts/build.sh --help' for usage."
      exit 1
      ;;
  esac
done

build_and_archive() {
  local target_flavor=$1
  local target_type=$2
  
  echo "=========================================="
  echo " Building Yet Another LuCI App (v${VERSION})"
  echo " Flavor: $target_flavor"
  echo " Target: $target_type"
  echo " Build Verification: OFFICIAL_BUILD=$OFFICIAL"
  echo " Enable Ads: $ENABLE_ADS"
  echo " Enable Support Dev: $ENABLE_SUPPORT_DEV"
  echo "=========================================="

  flutter build $target_type --release \
    --flavor $target_flavor \
    --dart-define=FLAVOR=$target_flavor \
    --dart-define=OFFICIAL_BUILD=$OFFICIAL \
    --dart-define=ENABLE_ADS=$ENABLE_ADS \
    --dart-define=ENABLE_SUPPORT_DEV=$ENABLE_SUPPORT_DEV

  # Copy output to .private/releases/v<RAW_VER>_build<BUILD_NUM>/<flavor>/ if .private directory exists
  if [ -d "${PROJECT_ROOT}/.private" ]; then
    OUTPUT_DIR="${PROJECT_ROOT}/.private/releases/v${RAW_VER}_build${BUILD_NUM}/${target_flavor}"
    mkdir -p "${OUTPUT_DIR}"
    
    if [ "$target_flavor" = "community" ]; then
      cp build/app/outputs/flutter-apk/app-community-release.apk "${OUTPUT_DIR}/app-community-release-v${RAW_VER}.apk"
      echo "✔ Archived Community APK to: ${OUTPUT_DIR}/app-community-release-v${RAW_VER}.apk"
    elif [ "$target_flavor" = "playstore" ]; then
      if [ "$target_type" = "apk" ]; then
        cp build/app/outputs/flutter-apk/app-playstore-release.apk "${OUTPUT_DIR}/app-playstore-release-v${RAW_VER}.apk"
        echo "✔ Archived Play Store APK to: ${OUTPUT_DIR}/app-playstore-release-v${RAW_VER}.apk"
      elif [ "$target_type" = "appbundle" ]; then
        cp build/app/outputs/bundle/playstoreRelease/app-playstore-release.aab "${OUTPUT_DIR}/app-playstore-release-v${RAW_VER}.aab"
        echo "✔ Archived Play Store AAB to: ${OUTPUT_DIR}/app-playstore-release-v${RAW_VER}.aab"
      fi
    fi
  fi
}

if [ "$FLAVOR" = "all" ]; then
  echo "Building all release flavors (v${VERSION})..."
  build_and_archive "community" "apk"
  build_and_archive "playstore" "apk"
  build_and_archive "playstore" "appbundle"
else
  build_and_archive "$FLAVOR" "$TARGET"
fi

echo ""
echo "=========================================="
echo " Build process completed successfully!"
if [ -d "${PROJECT_ROOT}/.private" ]; then
  echo " Output structured at: .private/releases/v${RAW_VER}_build${BUILD_NUM}/"
fi
echo "=========================================="
