#!/bin/bash
# ============================================================================
# the MSP — multi-tenant rollout runner
#
# Fans a shared-module change out to every client tenant. Each client folder
# under clients/ (except _TEMPLATE) is planned against its own tenant; you
# review the combined report and approve applies PER CLIENT.
#
# Usage:
#   ./apply-all.sh              # plan every client, report who has changes
#   ./apply-all.sh apply        # plan every client, then prompt y/N per
#                               #   client and apply the SAVED plan on yes
#   ./apply-all.sh plan Pilot    # limit to client folders matching "Pilot"
#
# Notes:
#   - Applies always run -parallelism=1 (Jamf Cloud load balancer).
#   - The apply uses the exact saved plan file from the review step — what
#     you approved is what runs.
#   - A client folder is skipped (with a warning) if terraform.tfvars is
#     missing. First-time folders are auto-initialized.
#   - Compatible with macOS's default bash 3.2.
# ============================================================================

set -u

MODE="${1:-plan}"
FILTER="${2:-}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
PLANFILE=".tfplan-rollout"

if [ "$MODE" != "plan" ] && [ "$MODE" != "apply" ]; then
  echo "Usage: $0 [plan|apply] [client-name-filter]"
  exit 1
fi

CHANGED=""
CLEAN=""
FAILED=""
SKIPPED=""

echo "=== MSP rollout: ${MODE} across client tenants ==="
echo ""

for dir in "$ROOT"/clients/*/; do
  name="$(basename "$dir")"
  [ "$name" = "_TEMPLATE" ] && continue
  if [ -n "$FILTER" ] && ! echo "$name" | grep -qi "$FILTER"; then
    continue
  fi

  if [ ! -f "$dir/terraform.tfvars" ]; then
    echo "--- $name: SKIPPED (no terraform.tfvars)"
    SKIPPED="$SKIPPED $name"
    continue
  fi

  echo "--- $name: planning..."

  if [ ! -d "$dir/.terraform" ]; then
    terraform -chdir="$dir" init -input=false >/dev/null 2>&1 || {
      echo "--- $name: INIT FAILED"
      FAILED="$FAILED $name"
      continue
    }
  fi

  terraform -chdir="$dir" plan -input=false -parallelism=1 \
    -detailed-exitcode -out="$PLANFILE" >"$dir/.rollout-plan.log" 2>&1
  rc=$?

  if [ $rc -eq 0 ]; then
    echo "--- $name: no changes"
    CLEAN="$CLEAN $name"
    rm -f "$dir/$PLANFILE"
  elif [ $rc -eq 2 ]; then
    summary="$(grep -E '^Plan:' "$dir/.rollout-plan.log" | tail -1)"
    echo "--- $name: CHANGES PENDING — ${summary:-see .rollout-plan.log}"
    CHANGED="$CHANGED $name"
  else
    echo "--- $name: PLAN FAILED — details in clients/$name/.rollout-plan.log"
    FAILED="$FAILED $name"
    rm -f "$dir/$PLANFILE"
  fi
done

echo ""
echo "=== Summary ==="
echo "  Changes pending:${CHANGED:- (none)}"
echo "  Up to date:     ${CLEAN:- (none)}"
echo "  Failed:         ${FAILED:- (none)}"
echo "  Skipped:        ${SKIPPED:- (none)}"

if [ "$MODE" = "plan" ] || [ -z "$CHANGED" ]; then
  [ "$MODE" = "plan" ] && [ -n "$CHANGED" ] && {
    echo ""
    echo "Review details: clients/<Name>/.rollout-plan.log"
    echo "Then roll out with:  ./apply-all.sh apply"
  }
  exit 0
fi

echo ""
echo "=== Apply phase (per-client approval) ==="
for name in $CHANGED; do
  dir="$ROOT/clients/$name"
  echo ""
  grep -E '^Plan:' "$dir/.rollout-plan.log" | tail -1 | sed "s/^/  $name — /"
  printf "  Apply to %s? [y/N] " "$name"
  read -r answer
  if [ "$answer" = "y" ] || [ "$answer" = "Y" ]; then
    terraform -chdir="$dir" apply -parallelism=1 "$PLANFILE"
    rc=$?
    if [ $rc -eq 0 ]; then
      echo "  $name: APPLIED"
    else
      echo "  $name: APPLY FAILED (exit $rc) — stopping so you can investigate."
      exit $rc
    fi
  else
    echo "  $name: skipped by operator"
  fi
  rm -f "$dir/$PLANFILE"
done

echo ""
echo "=== Rollout complete ==="
