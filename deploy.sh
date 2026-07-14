#!/usr/bin/env bash
# Đồng bộ qlva.html/qlva-dev.html vào thư mục hosting rồi deploy lên Firebase.
# Cách dùng:
#   ./deploy.sh test    -> deploy qlva-dev.html lên https://qlahs-test.web.app
#   ./deploy.sh prod    -> deploy qlva.html lên https://qlahsp2.web.app (DỮ LIỆU THẬT)
#   ./deploy.sh all     -> deploy cả 2 (test trước, production sau)
set -e
cd "$(dirname "$0")"

deploy_test() {
  echo "== Đồng bộ qlva-dev.html -> public-test/index.html =="
  mkdir -p public-test
  cp qlva-dev.html public-test/index.html
  firebase deploy --only hosting:test --project test
}

deploy_prod() {
  echo "== Đồng bộ qlva.html -> public-prod/index.html =="
  mkdir -p public-prod
  cp qlva.html public-prod/index.html
  firebase deploy --only hosting:prod --project prod
}

case "$1" in
  test) deploy_test ;;
  prod) deploy_prod ;;
  all)  deploy_test; deploy_prod ;;
  *)
    echo "Cách dùng: ./deploy.sh test | prod | all"
    exit 1
    ;;
esac
