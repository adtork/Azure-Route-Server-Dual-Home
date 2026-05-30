#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-${rg:-Lab_ARSDual}}"

section() {
  printf '\n==> %s\n' "$1"
}

show_routeserver_peering() {
  local routeserver="$1"
  local peering="$2"
  section "${routeserver}/${peering} learned routes"
  az network routeserver peering list-learned-routes \
    --resource-group "$RESOURCE_GROUP" \
    --routeserver "$routeserver" \
    --name "$peering" \
    --output table

  section "${routeserver}/${peering} peering state"
  az network routeserver peering show \
    --resource-group "$RESOURCE_GROUP" \
    --routeserver "$routeserver" \
    --name "$peering" \
    --query '{name:name, peerIp:peerIp, peerAsn:peerAsn, provisioningState:provisioningState}' \
    --output table
}

show_connection() {
  local connection="$1"
  section "VPN connection ${connection}"
  az network vpn-connection show \
    --resource-group "$RESOURCE_GROUP" \
    --name "$connection" \
    --query '{name:name, connectionStatus:connectionStatus, ingressBytes:ingressBytesTransferred, egressBytes:egressBytesTransferred, enableBgp:enableBgp, provisioningState:provisioningState}' \
    --output table
}

show_effective_routes() {
  local vm_name="$1"
  section "Effective routes for ${vm_name}"
  local nic_id
  nic_id=$(az vm show -g "$RESOURCE_GROUP" -n "$vm_name" --query 'networkProfile.networkInterfaces[0].id' -o tsv)
  local nic_name
  nic_name=$(basename "$nic_id")
  az network nic show-effective-route-table \
    --resource-group "$RESOURCE_GROUP" \
    --name "$nic_name" \
    --output table
}

show_routeserver_peering HubRouteServer hubCSR
show_routeserver_peering Hub2RouteServer hub2CSR
show_routeserver_peering SpokeRouteServer hubCSR
show_routeserver_peering SpokeRouteServer hub2CSR

show_connection hubtobranch
show_connection branchtohub
show_connection hub2tobranch2
show_connection branch2tohub2

show_effective_routes spokeVM
