#!/usr/bin/env bash
# Renders every kustomization and validates the output against Kubernetes and
# CRD schemas. Same checks as CI, so you can catch mistakes before pushing.
set -euo pipefail
CRD_SCHEMAS='https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json'
fail=0
while IFS= read -r k; do
  dir=$(dirname "$k")
  echo "==> ${dir}"
  if ! kustomize build "$dir" \
      | kubeconform -strict -summary -ignore-missing-schemas \
          -schema-location default -schema-location "$CRD_SCHEMAS" -; then
    fail=1
  fi
done < <(find . -name kustomization.yaml -not -path './clusters/*/flux-system/*' | sort)
exit $fail
