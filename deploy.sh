#!/usr/bin/env bash
# Đồng bộ qlva.html/qlva-dev.html/qlahs-sup.html vào thư mục hosting rồi deploy lên Firebase.
# Cách dùng:
#   ./deploy.sh test    -> deploy qlva-dev.html lên https://qlahs-test.web.app (Firestore)
#   ./deploy.sh prod    -> deploy qlva.html lên https://qlahsp2.web.app (Firestore, DỮ LIỆU THẬT)
#   ./deploy.sh sup     -> deploy qlahs-sup.html lên https://qlahs-sup.web.app (Supabase, site
#                          test riêng dưới project qlahs-test — KHÔNG đụng qlahsp2 production)
#   ./deploy.sh all     -> deploy cả 2 bản Firestore (test trước, production sau) — KHÔNG gồm sup,
#                          gõ riêng ./deploy.sh sup vì đây là dòng code khác hẳn (Supabase)
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

deploy_sup() {
  echo "== Đồng bộ qlahs-sup.html -> public-sup/index.html =="
  mkdir -p public-sup
  cp qlahs-sup.html public-sup/index.html
  firebase deploy --only hosting:sup --project test
}

case "$1" in
  test) deploy_test ;;
  prod) deploy_prod ;;
  sup)  deploy_sup ;;
  all)  deploy_test; deploy_prod ;;
  *)
    echo "Cách dùng: ./deploy.sh test | prod | sup | all"
    exit 1
    ;;
esac
