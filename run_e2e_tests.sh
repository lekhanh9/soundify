#!/usr/bin/env bash
# ==============================================================================
# Soundify E2E 4-Tier Automated Test Runner
#
# Runs comprehensive opaque-box tests across all 4 tiers on Linux:
#   Tier 1: Feature Coverage & Interface Contracts
#   Tier 2: Boundary & Corner Cases
#   Tier 3: Cross-Feature Interactions
#   Tier 4: Real-World Scenarios & Live CDN Streaming
# ==============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

TIER=""
MILESTONE=""
VERBOSE=""
SYNTAX_ONLY=false

print_usage() {
    cat << EOF
Soundify E2E Automated Test Runner

Usage: ./run_e2e_tests.sh [OPTIONS]

Options:
  -t, --tier <1|2|3|4>     Run specific tier only
  -m, --milestone <1|2|3>  Run tests matching milestone
  --syntax                 Run Swift syntax (-parse) and PBX lint only
  -v, --verbose            Run pytest in verbose mode
  -h, --help               Show this help message

Examples:
  ./run_e2e_tests.sh              # Run all 4 tiers
  ./run_e2e_tests.sh --tier 1     # Run Tier 1 (Feature Coverage)
  ./run_e2e_tests.sh --milestone 1 # Run Milestone 1 tests
  ./run_e2e_tests.sh --syntax     # Run swiftc syntax checks
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--tier)
            TIER="$2"
            shift 2
            ;;
        -m|--milestone)
            MILESTONE="$2"
            shift 2
            ;;
        --syntax)
            SYNTAX_ONLY=true
            shift
            ;;
        -v|--verbose)
            VERBOSE="-v"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

echo -e "${BOLD}${CYAN}==============================================================================${NC}"
echo -e "${BOLD}${CYAN}                Soundify E2E 4-Tier Test Runner (Linux)                       ${NC}"
echo -e "${BOLD}${CYAN}==============================================================================${NC}"
echo -e "Project Directory: ${SCRIPT_DIR}"
echo -e "Python Version:    $(python3 --version)"
echo -e "Swift Version:     $(swift --version | head -n 1)"
echo -e "Pytest Version:    $(pytest --version 2>&1 | head -n 1)"
echo -e "${CYAN}------------------------------------------------------------------------------${NC}"

# 1. Swift Syntax & Structure Checks
echo -e "${BOLD}${BLUE}Checking Swift syntax (swiftc -parse) across all source files...${NC}"
SWIFT_FILES=$(find Soundify Tests -name "*.swift")
SYNTAX_ERRORS=0

for sf in $SWIFT_FILES; do
    if ! swiftc -parse "$sf" 2>/dev/null; then
        echo -e "  [${RED}FAIL${NC}] $sf"
        swiftc -parse "$sf"
        SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
    fi
done

if [[ $SYNTAX_ERRORS -eq 0 ]]; then
    TOTAL_SWIFT=$(echo "$SWIFT_FILES" | wc -l)
    echo -e "  [${GREEN}PASS${NC}] All $TOTAL_SWIFT Swift source files passed syntax validation."
else
    echo -e "  [${RED}FAIL${NC}] $SYNTAX_ERRORS Swift file(s) failed syntax validation."
    exit 1
fi

# 1b. Swift Unit Tests (SoundifyTests.swift)
if [[ -f "Tests/SoundifyTests.swift" ]]; then
    echo -e "${BOLD}${BLUE}Executing Swift Unit Tests (Tests/SoundifyTests.swift)...${NC}"
    if swiftc -parse-as-library Soundify/Models/Song.swift Soundify/Services/MusicAPI.swift Tests/SoundifyTests.swift -o /tmp/soundify_unit_tests && /tmp/soundify_unit_tests; then
        echo -e "  [${GREEN}PASS${NC}] All Swift unit tests passed."
    else
        echo -e "  [${RED}FAIL${NC}] Swift unit tests failed."
        exit 1
    fi
fi

# 2. PBX Project Lint
echo -e "${BOLD}${BLUE}Linting Xcode project configuration (plutil -lint)...${NC}"
PBX_PATH="Soundify.xcodeproj/project.pbxproj"
if [[ -f "$PBX_PATH" ]]; then
    if plutil -lint "$PBX_PATH" > /dev/null 2>&1; then
        echo -e "  [${GREEN}PASS${NC}] $PBX_PATH is valid plist/ASCII PBX format."
    else
        echo -e "  [${RED}FAIL${NC}] $PBX_PATH failed plutil lint check."
        plutil -lint "$PBX_PATH"
        exit 1
    fi
fi

if [[ "$SYNTAX_ONLY" = true ]]; then
    echo -e "${BOLD}${GREEN}Syntax and PBX lint checks completed successfully!${NC}"
    exit 0
fi

# 3. Pytest Execution
PYTEST_ARGS=()
if [[ -n "$VERBOSE" ]]; then
    PYTEST_ARGS+=("-v")
fi

if [[ -n "$TIER" ]]; then
    echo -e "\n${BOLD}${YELLOW}Executing Tier $TIER Tests...${NC}"
    PYTEST_ARGS+=("-m" "tier${TIER}")
elif [[ -n "$MILESTONE" ]]; then
    echo -e "\n${BOLD}${YELLOW}Executing Milestone $MILESTONE Tests...${NC}"
    PYTEST_ARGS+=("-m" "m${MILESTONE}")
else
    echo -e "\n${BOLD}${YELLOW}Executing All 4 Tiers...${NC}"
fi

pytest "${PYTEST_ARGS[@]}"
PYTEST_EXIT=$?

echo -e "\n${CYAN}------------------------------------------------------------------------------${NC}"
if [[ $PYTEST_EXIT -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}✔ All executed tests PASSED with exit code 0!${NC}"
else
    echo -e "${BOLD}${RED}✘ Some tests failed with exit code $PYTEST_EXIT${NC}"
    exit $PYTEST_EXIT
fi
echo -e "${BOLD}${CYAN}==============================================================================${NC}"
exit 0
