#!/bin/bash
set -euo pipefail

rm -rf build dist
mkdir -p build dist

python3 -m pip install -t build pymysql >/dev/null
cp lambda/mysql_rotation/lambda_function.py build/

(cd build && zip -qr ../dist/rotation.zip .)

echo "Built dist/rotation.zip"
