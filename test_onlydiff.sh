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
git init --quiet
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
git commit --no-verify -m "Initial commit with bad formatting" --quiet


# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #
#                                    TESTS                                     #
# ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ #


sed -i '' '6s/def function_two(a,b,c)/def    function_two( a , b , c )/' test.py

if ! command -v black &> /dev/null; then
    echo "Black is not installed. Installing with pip..."
    pip3 install black
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

echo ""
echo "=== ALL TESTS PASSED ==="
