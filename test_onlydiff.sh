#!/bin/bash

set -e

# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#                                    SETUP                                     #
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #

# Store the original directory before moving to temp dir
ORIGINAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

TEST_DIR=$(mktemp -d)

cleanup() {
    echo "Cleaning up test directory..."
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

cd "$TEST_DIR"

# Initialize git repo
git init --quiet -b trunk
git config user.name "Test User"
git config user.email "test@example.com"

# Create a Python file with formatting issues in multiple places
# Use very long lines (>88 chars, black's default) and other violations
# Add extra blank lines to ensure black creates separate hunks for each function
cat > test.py << 'EOF'
def function_one(x,y,z):
    result={"key1":"value1","key2":"value2","key3":"value3","key4":"value4","key5":"value5","key6":"value6","key7":"value7"}
    return result


def function_two(a,b,c):
    # Another badly formatted function
    value={"data1":"item1","data2":"item2","data3":"item3","data4":"item4","data5":"item5","data6":"item6","data7":"item7"}
    return value


def function_three(p,q,r):
    answer={"thing1":"stuff1","thing2":"stuff2","thing3":"stuff3","thing4":"stuff4","thing5":"stuff5","thing6":"stuff6"}
    return answer


def function_four(m,n,o):
    total={"num1":"val1","num2":"val2","num3":"val3","num4":"val4","num5":"val5","num6":"val6","num7":"val7","num8":"val8"}
    return total
EOF

# Commit the badly formatted file
git add test.py >/dev/null 2>&1
git commit -m "Initial commit with bad formatting" --quiet


# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#                                    TESTS                                     #
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #


python3 -c 'from pathlib import Path; p = Path("test.py"); p.write_text(p.read_text().replace("def function_two(a,b,c):", "def    function_two( a , b , c ):", 1))'

if ! command -v black &> /dev/null; then
    echo "Black is not installed. Installing Black 25.9.0 with pip..."
    python3 -m pip install "black==25.9.0"
fi

ONLYDIFF="$ORIGINAL_DIR/onlydiff"

# Run black through onlydiff
"$ONLYDIFF" black test.py >/dev/null 2>&1

# Verify that function_one still has bad formatting (long line not wrapped)
if grep -q '"key7":"value7"' test.py && grep -q 'result={"key1"' test.py; then
    echo "✓ PASS: function_one still has bad formatting (untouched)"
else
    echo "✗ FAIL: function_one was formatted (should have been untouched)"
    exit 1
fi

# Verify that function_two was formatted (line should be wrapped by black)
# After black formats, the long dict should be split across multiple lines
# The dict assignment should no longer be all on one line
if grep -q 'def    function_two( a , b , c )' test.py; then
    echo "✗ FAIL: function_two was not formatted "
    exit 1
else
    echo "✓ PASS: function_two was formatted correctly"
fi

# Verify that function_three still has bad formatting (long line not wrapped)
if grep -q '"thing6":"stuff6"' test.py && grep -q 'answer={"thing1"' test.py; then
    echo "✓ PASS: function_three still has bad formatting (untouched)"
else
    echo "✗ FAIL: function_three was formatted (should have been untouched)"
    exit 1
fi

# Verify that function_four still has bad formatting (long line not wrapped)
if grep -q '"num8":"val8"' test.py && grep -q 'total={"num1"' test.py; then
    echo "✓ PASS: function_four still has bad formatting (untouched)"
else
    echo "✗ FAIL: function_four was formatted (should have been untouched)"
    exit 1
fi

if "$ONLYDIFF" false >/dev/null 2>&1; then
    echo "✗ FAIL: transformer failure was not propagated"
    exit 1
else
    echo "✓ PASS: transformer failure was propagated"
fi

ROOT_DIR="$TEST_DIR/root"
mkdir "$ROOT_DIR"
(
    cd "$ROOT_DIR"
    git init --quiet -b trunk
    git config user.name "Test User"
    git config user.email "test@example.com"
    printf 'root foo\n' > "root file.txt"
    python3 -c 'from pathlib import Path; Path("binary.bin").write_bytes(b"\x00\xff")'
    git add "root file.txt" binary.bin
    "$ONLYDIFF" --cached --append-files python3 -c \
        'from pathlib import Path; import sys; [(p := Path(name)).write_text(p.read_text().replace("foo", "bar")) for name in sys.argv[1:]]' \
        >/dev/null
    grep -qx 'root bar' "root file.txt"
    test "$(python3 -c 'from pathlib import Path; print(Path("binary.bin").read_bytes().hex())')" = "00ff"
)
echo "✓ PASS: cached mode handled an initial commit, spaces, and automatic binary exclusion"

CACHED_DIR="$TEST_DIR/cached"
mkdir "$CACHED_DIR"
(
    cd "$CACHED_DIR"
    git init --quiet -b trunk
    git config user.name "Test User"
    git config user.email "test@example.com"
    printf 'untouched foo\nseparator\nchanged foo\n' > "cached file.txt"
    git add "cached file.txt"
    git commit -m "Cached baseline" --quiet
    printf 'untouched foo\nseparator\nchanged foo touched\n' > "cached file.txt"
    git add "cached file.txt"
    "$ONLYDIFF" --cached python3 -c \
        'from pathlib import Path; import sys; p = Path(sys.argv[1]); p.write_text(p.read_text().replace("foo", "bar"))' \
        "cached file.txt" >/dev/null
    grep -qx 'untouched foo' "cached file.txt"
    grep -qx 'changed bar touched' "cached file.txt"
    if "$ONLYDIFF" --cached --file "cached file.txt" true >/dev/null 2>&1; then
        echo "✗ FAIL: cached mode accepted a file with unstaged changes"
        exit 1
    fi
)
echo "✓ PASS: cached mode formatted only the touched hunk and rejected mixed state"

echo ""
echo "=== ALL TESTS PASSED ==="
