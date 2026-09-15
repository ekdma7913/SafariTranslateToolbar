#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
ROOT_DIR="${SCRIPT_DIR:h}"
TEST_BUILD_DIR="${ROOT_DIR}/build/regression-tests"
DEVELOPER_DIR_PATH="$(xcode-select -p)"
TEST_FRAMEWORKS="${DEVELOPER_DIR_PATH}/Platforms/MacOSX.platform/Developer/Library/Frameworks"
TEST_LIBRARIES="${DEVELOPER_DIR_PATH}/Platforms/MacOSX.platform/Developer/usr/lib"

mkdir -p "${TEST_BUILD_DIR}"
# Compile the production policies unchanged, replacing only the app entry point.
# These tests use synthetic trees and never request Accessibility permission.
xcrun swiftc \
    -D REGRESSION_TESTS -parse-as-library -default-isolation MainActor \
    -module-cache-path "${TEST_BUILD_DIR}/ModuleCache" \
    -F "${TEST_FRAMEWORKS}" \
    -I "${TEST_LIBRARIES}" -L "${TEST_LIBRARIES}" \
    -Xlinker -rpath -Xlinker "${TEST_FRAMEWORKS}" \
    -Xlinker -rpath -Xlinker "${TEST_LIBRARIES}" \
    "${ROOT_DIR}/SafariTranslateToolbar/SafariTranslateToolbar/AppDelegate.swift" \
    "${ROOT_DIR}/Tests/TranslationRegressionTests.swift" \
    -o "${TEST_BUILD_DIR}/TranslationRegressionTests"
"${TEST_BUILD_DIR}/TranslationRegressionTests"
