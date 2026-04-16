#!/usr/bin/env bash
set -euo pipefail

PROFILE="${OCI_CLI_PROFILE:-DEFAULT}"
CONFIG_FILE="${OCI_CLI_CONFIG_FILE:-$HOME/.oci/config}"
OUT_FILE="${1:-terraform.tfvars}"

if [[ ! -r "$CONFIG_FILE" ]]; then
  echo "OCI CLI config not found: $CONFIG_FILE" >&2
  exit 1
fi

get_cfg_value() {
  local key="$1"
  awk -v profile="[$PROFILE]" -v key="$key" '
    BEGIN { in_profile=0 }
    $0 == profile { in_profile=1; next }
    /^\[/ { in_profile=0 }
    in_profile && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub("^[[:space:]]*" key "[[:space:]]*=[[:space:]]*", "", $0)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
      print
      exit
    }
  ' "$CONFIG_FILE"
}

TENANCY_OCID="$(get_cfg_value tenancy || true)"
REGION="$(get_cfg_value region || true)"

if [[ -z "$TENANCY_OCID" || -z "$REGION" ]]; then
  echo "Could not read tenancy or region from $CONFIG_FILE profile [$PROFILE]." >&2
  exit 1
fi

COMPARTMENT_OCID="${COMPARTMENT_OCID:-}"
if [[ -z "$COMPARTMENT_OCID" ]]; then
  tmp_json="$(mktemp)"
  trap 'rm -f "$tmp_json"' EXIT

  oci iam compartment list \
    -c "$TENANCY_OCID" \
    --compartment-id-in-subtree true \
    --access-level ANY \
    --all \
    --output json > "$tmp_json"

  mapfile -t ids < <(jq -r '.data[].id' "$tmp_json")
  mapfile -t names < <(jq -r '.data[].name' "$tmp_json")
  mapfile -t descs < <(jq -r '.data[].description // ""' "$tmp_json")

  if [[ "${#ids[@]}" -eq 0 ]]; then
    echo "No accessible compartments were found." >&2
    exit 1
  fi

  echo "Choose a compartment:"
  for i in "${!ids[@]}"; do
    printf '%3d) %-30s %s\n' "$((i + 1))" "${names[$i]}" "${ids[$i]}"
  done

  read -r -p "Number: " choice
  if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#ids[@]} )); then
    echo "Invalid selection." >&2
    exit 1
  fi
  COMPARTMENT_OCID="${ids[$((choice - 1))]}"
fi

SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"
if [[ -z "$SSH_PUBLIC_KEY" ]]; then
  SSH_PUBLIC_KEY_FILE="${SSH_PUBLIC_KEY_FILE:-$HOME/.ssh/id_rsa.pub}"
  if [[ -r "$SSH_PUBLIC_KEY_FILE" ]]; then
    SSH_PUBLIC_KEY="$(tr -d '\n' < "$SSH_PUBLIC_KEY_FILE")"
  fi
fi

{
  printf 'region = "%s"\n' "$REGION"
  printf 'tenancy_ocid = "%s"\n' "$TENANCY_OCID"
  printf 'compartment_ocid = "%s"\n' "$COMPARTMENT_OCID"
  printf 'ssh_public_key = "%s"\n' "$SSH_PUBLIC_KEY"
} > "$OUT_FILE"

echo "Wrote $OUT_FILE"
