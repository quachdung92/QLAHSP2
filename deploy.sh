#!/usr/bin/env bash
# Đồng bộ qlva.html/qlva-dev.html/qlahs-sup.html vào thư mục hosting rồi deploy lên Firebase.
#
# (2026-07-20) qlahsp2.web.app CHÍNH THỨC CHUYỂN SANG SUPABASE — "prod" giờ deploy qlahs-sup.html
# (trước đây là qlva.html/Firestore). qlva.html KHÔNG bị xoá, vẫn deploy được thủ công nếu cần
# rollback khẩn cấp: `cp qlva.html public-prod/index.html && firebase deploy --only hosting:prod
# --project prod` (KHÔNG dùng lệnh ./deploy.sh nào bên dưới cho việc rollback, vì "prod" giờ trỏ
# thẳng qlahs-sup.html).
#
# Cách dùng:
#   ./deploy.sh test    -> deploy qlva-dev.html lên https://qlahs-test.web.app (Firestore, cũ)
#   ./deploy.sh prod    -> deploy qlahs-sup.html lên https://qlahsp2.web.app (Supabase, DỮ LIỆU THẬT)
#   ./deploy.sh sup     -> deploy qlahs-sup.html lên https://qlahs-sup.web.app (Supabase, site
#                          test riêng dưới project qlahs-test — dùng để thử trước khi lên prod)
#   ./deploy.sh all     -> deploy test + sup (KHÔNG gồm prod — prod đụng dữ liệu thật của 4 cán bộ,
#                          luôn gõ riêng ./deploy.sh prod để chủ động, không gộp vào "all")
set -e
cd "$(dirname "$0")"

deploy_test() {
  echo "== Đồng bộ qlva-dev.html -> public-test/index.html =="
  mkdir -p public-test
  cp qlva-dev.html public-test/index.html
  firebase deploy --only hosting:test --project test
}

deploy_prod() {
  echo "== Đồng bộ qlahs-sup.html -> public-prod/index.html (Supabase, production) =="
  mkdir -p public-prod
  cp qlahs-sup.html public-prod/index.html
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
  all)  deploy_test; deploy_sup ;;
  *)
    echo "Cách dùng: ./deploy.sh test | prod | sup | all"
    exit 1
    ;;
esac
