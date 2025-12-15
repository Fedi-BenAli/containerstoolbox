#!/usr/bin/env bash
# check_br_ex_duplicate_ips.sh
#
# Find duplicate IPs configured on br-ex on OpenShift worker nodes.

set -euo pipefail

# Get worker nodes
nodes=$(oc get nodes -l node-role.kubernetes.io/worker -o name)

if [[ -z "$nodes" ]]; then
  echo "No worker nodes found"
  exit 1
fi

tmpfile="$(mktemp)"
trap 'rm -f "$tmpfile"' EXIT

# Collect "IP NODE" lines
for node in $nodes; do
  nodename=${node#node/}
  echo "Checking node: $nodename" >&2

  # Run ip addr inside a debug pod on the node
  oc debug "$node" -- chroot /host ip -4 addr show dev br-ex 2>/dev/null \
    | awk '/inet / {print $2}' \
    | cut -d/ -f1 \
    | while read -r ip; do
        echo "$ip $nodename"
      done
done > "$tmpfile"

echo
echo "=== All br-ex IPs per worker node ==="
column -t "$tmpfile" | sort

echo
echo "=== Duplicate IPs across worker nodes ==="

# Find
