#!/usr/bin/env bash
set -euo pipefail

LOCATION="${LOCATION:-${loc:-EastUS2}}"
RESOURCE_GROUP="${RESOURCE_GROUP:-${rg:-Lab_ARSDual}}"
ADMIN_USERNAME="${ADMIN_USERNAME:-${username:-azureuser}}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-${password:-MyP@SSword123!}}"
VM_SIZE="${VM_SIZE:-${vmsize:-Standard_D2_v2}}"
CSR_IMAGE="cisco:cisco-csr-1000v:17_3_4a-byol:latest"

log() {
  printf '\n==> %s\n' "$1"
}

wait_for_gateway() {
  local gateway_name="$1"
  log "Waiting for gateway ${gateway_name}"
  az network vnet-gateway wait -g "$RESOURCE_GROUP" -n "$gateway_name" --created
}

log "Creating resource group"
az group create -n "$RESOURCE_GROUP" -l "$LOCATION" --output none

log "Creating VNets and subnets"
az network vnet create --address-prefixes 172.16.1.0/24 -n hub -g "$RESOURCE_GROUP" -l "$LOCATION" --output none
az network vnet subnet create --name RouteServerSubnet --address-prefixes 172.16.1.0/25 --resource-group "$RESOURCE_GROUP" --vnet-name hub --output none
az network vnet subnet create --name csroutside --address-prefixes 172.16.1.128/26 --resource-group "$RESOURCE_GROUP" --vnet-name hub --output none
az network vnet subnet create --name csrinside --address-prefixes 172.16.1.192/27 --resource-group "$RESOURCE_GROUP" --vnet-name hub --output none
az network vnet subnet create --name GatewaySubnet --address-prefixes 172.16.1.224/28 --resource-group "$RESOURCE_GROUP" --vnet-name hub --output none
az network vnet subnet create --name vmsubnet --address-prefixes 172.16.1.240/29 --resource-group "$RESOURCE_GROUP" --vnet-name hub --output none

az network vnet create --address-prefixes 172.16.2.0/24 -n hub2 -g "$RESOURCE_GROUP" -l "$LOCATION" --output none
az network vnet subnet create --name RouteServerSubnet --address-prefixes 172.16.2.0/25 --resource-group "$RESOURCE_GROUP" --vnet-name hub2 --output none
az network vnet subnet create --name csroutside --address-prefixes 172.16.2.128/26 --resource-group "$RESOURCE_GROUP" --vnet-name hub2 --output none
az network vnet subnet create --name csrinside --address-prefixes 172.16.2.192/27 --resource-group "$RESOURCE_GROUP" --vnet-name hub2 --output none
az network vnet subnet create --name GatewaySubnet --address-prefixes 172.16.2.224/28 --resource-group "$RESOURCE_GROUP" --vnet-name hub2 --output none
az network vnet subnet create --name vmsubnet --address-prefixes 172.16.2.240/29 --resource-group "$RESOURCE_GROUP" --vnet-name hub2 --output none

az network vnet create --address-prefixes 172.16.3.0/24 -n spoke -g "$RESOURCE_GROUP" -l "$LOCATION" --output none
az network vnet subnet create --name RouteServerSubnet --address-prefixes 172.16.3.0/25 --resource-group "$RESOURCE_GROUP" --vnet-name spoke --output none
az network vnet subnet create --name vmsubnet --address-prefixes 172.16.3.240/29 --resource-group "$RESOURCE_GROUP" --vnet-name spoke --output none

az network vnet create --address-prefixes 172.16.4.0/24 -n branch -g "$RESOURCE_GROUP" -l "$LOCATION" --output none
az network vnet subnet create --name vmsubnet --address-prefixes 172.16.4.0/25 --resource-group "$RESOURCE_GROUP" --vnet-name branch --output none
az network vnet subnet create --name GatewaySubnet --address-prefixes 172.16.4.224/28 --resource-group "$RESOURCE_GROUP" --vnet-name branch --output none

az network vnet create --address-prefixes 172.16.5.0/24 -n branch2 -g "$RESOURCE_GROUP" -l "$LOCATION" --output none
az network vnet subnet create --name vmsubnet --address-prefixes 172.16.5.0/25 --resource-group "$RESOURCE_GROUP" --vnet-name branch2 --output none
az network vnet subnet create --name GatewaySubnet --address-prefixes 172.16.5.224/28 --resource-group "$RESOURCE_GROUP" --vnet-name branch2 --output none

log "Creating spoke-to-hub peerings"
az network vnet peering create -g "$RESOURCE_GROUP" -n HubtoSpoke --vnet-name hub --remote-vnet spoke --allow-vnet-access --allow-forwarded-traffic --output none
az network vnet peering create -g "$RESOURCE_GROUP" -n SpoketoHub --vnet-name spoke --remote-vnet hub --allow-vnet-access --allow-forwarded-traffic --output none
az network vnet peering create -g "$RESOURCE_GROUP" -n Hub2toSpoke --vnet-name hub2 --remote-vnet spoke --allow-vnet-access --allow-forwarded-traffic --output none
az network vnet peering create -g "$RESOURCE_GROUP" -n SpoketoHub2 --vnet-name spoke --remote-vnet hub2 --allow-vnet-access --allow-forwarded-traffic --output none

log "Creating Cisco CSR NVAs"
az vm image terms accept --urn "$CSR_IMAGE" --output none
az network public-ip create --name CSRPubIP --resource-group "$RESOURCE_GROUP" --idle-timeout 30 --allocation-method Static --location "$LOCATION" --output none
az network nic create --name CSROutsideInt -g "$RESOURCE_GROUP" --subnet csroutside --vnet hub --public-ip-address CSRPubIP --ip-forwarding true --location "$LOCATION" --output none
az network nic create --name CSRInsideInt -g "$RESOURCE_GROUP" --subnet csrinside --vnet hub --ip-forwarding true --location "$LOCATION" --output none
az vm create --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --name hubCSR --size "$VM_SIZE" --nics CSROutsideInt CSRInsideInt --image "$CSR_IMAGE" --admin-username "$ADMIN_USERNAME" --admin-password "$ADMIN_PASSWORD"

az network public-ip create --name CSRPubIP2 --resource-group "$RESOURCE_GROUP" --idle-timeout 30 --allocation-method Static --location "$LOCATION" --output none
az network nic create --name CSROutsideInt2 -g "$RESOURCE_GROUP" --subnet csroutside --vnet hub2 --public-ip-address CSRPubIP2 --ip-forwarding true --location "$LOCATION" --output none
az network nic create --name CSRInsideInt2 -g "$RESOURCE_GROUP" --subnet csrinside --vnet hub2 --ip-forwarding true --location "$LOCATION" --output none
az vm create --resource-group "$RESOURCE_GROUP" --location "$LOCATION" --name hub2CSR --size "$VM_SIZE" --nics CSROutsideInt2 CSRInsideInt2 --image "$CSR_IMAGE" --admin-username "$ADMIN_USERNAME" --admin-password "$ADMIN_PASSWORD"

log "Creating hub and branch VPN gateway public IPs"
for pip in hub-vpngw-pip hub-vpngwPIP hub2-vpngw-pip hub2-vpngwPIP branch-vpngw-pip branch-vpngwPIP branch2-vpngw-pip branch2-vpngwPIP; do
  az network public-ip create -n "$pip" -g "$RESOURCE_GROUP" --location "$LOCATION" --sku Basic --output none
done

log "Creating VPN gateways (this can take 30-45 minutes)"
az network vnet-gateway create -n hub-vpngw --public-ip-addresses hub-vpngw-pip hub-vpngwPIP -g "$RESOURCE_GROUP" --vnet hub --asn 65515 --gateway-type Vpn -l "$LOCATION" --sku VpnGw1 --vpn-gateway-generation Generation1 --active-active true --no-wait
az network vnet-gateway create -n hub2-vpngw --public-ip-addresses hub2-vpngw-pip hub2-vpngwPIP -g "$RESOURCE_GROUP" --vnet hub2 --asn 65515 --gateway-type Vpn -l "$LOCATION" --sku VpnGw1 --vpn-gateway-generation Generation1 --active-active true --no-wait
az network vnet-gateway create -n branch-vpngw --public-ip-addresses branch-vpngw-pip branch-vpngwPIP -g "$RESOURCE_GROUP" --vnet branch --asn 65511 --gateway-type Vpn -l "$LOCATION" --sku VpnGw1 --vpn-gateway-generation Generation1 --active-active true --no-wait
az network vnet-gateway create -n branch2-vpngw --public-ip-addresses branch2-vpngw-pip branch2-vpngwPIP -g "$RESOURCE_GROUP" --vnet branch2 --asn 65512 --gateway-type Vpn -l "$LOCATION" --sku VpnGw1 --vpn-gateway-generation Generation1 --active-active true --no-wait
wait_for_gateway hub-vpngw
wait_for_gateway hub2-vpngw
wait_for_gateway branch-vpngw
wait_for_gateway branch2-vpngw

log "Creating VNet-to-VNet IPsec+BGP connections"
az network vpn-connection create -n hubtobranch -g "$RESOURCE_GROUP" -l "$LOCATION" --vnet-gateway1 hub-vpngw --vnet-gateway2 branch-vpngw --enable-bgp --shared-key 'abc123' --output none
az network vpn-connection create -n branchtohub -g "$RESOURCE_GROUP" -l "$LOCATION" --vnet-gateway1 branch-vpngw --vnet-gateway2 hub-vpngw --enable-bgp --shared-key 'abc123' --output none
az network vpn-connection create -n hub2tobranch2 -g "$RESOURCE_GROUP" -l "$LOCATION" --vnet-gateway1 hub2-vpngw --vnet-gateway2 branch2-vpngw --enable-bgp --shared-key 'abc123' --output none
az network vpn-connection create -n branch2tohub2 -g "$RESOURCE_GROUP" -l "$LOCATION" --vnet-gateway1 branch2-vpngw --vnet-gateway2 hub2-vpngw --enable-bgp --shared-key 'abc123' --output none

log "Creating Azure Route Servers"
az network public-ip create --name HubRouteServerIP --resource-group "$RESOURCE_GROUP" --version IPv4 --sku Standard --output none
az network public-ip create --name Hub2RouteServerIP --resource-group "$RESOURCE_GROUP" --version IPv4 --sku Standard --output none
az network public-ip create --name SpokeRouteServerIP --resource-group "$RESOURCE_GROUP" --version IPv4 --sku Standard --output none
arshubsubnet_id=$(az network vnet subnet show --name RouteServerSubnet --resource-group "$RESOURCE_GROUP" --vnet-name hub --query id -o tsv)
arshub2subnet_id=$(az network vnet subnet show --name RouteServerSubnet --resource-group "$RESOURCE_GROUP" --vnet-name hub2 --query id -o tsv)
arsspokesubnet_id=$(az network vnet subnet show --name RouteServerSubnet --resource-group "$RESOURCE_GROUP" --vnet-name spoke --query id -o tsv)
az network routeserver create --name HubRouteServer --resource-group "$RESOURCE_GROUP" --hosted-subnet "$arshubsubnet_id" --public-ip-address HubRouteServerIP --output none
az network routeserver create --name Hub2RouteServer --resource-group "$RESOURCE_GROUP" --hosted-subnet "$arshub2subnet_id" --public-ip-address Hub2RouteServerIP --output none
az network routeserver create --name SpokeRouteServer --resource-group "$RESOURCE_GROUP" --hosted-subnet "$arsspokesubnet_id" --public-ip-address SpokeRouteServerIP --output none

log "Creating ARS-to-CSR BGP peerings"
az network routeserver peering create --name hubCSR --peer-ip 172.16.1.196 --peer-asn 65002 --routeserver HubRouteServer --resource-group "$RESOURCE_GROUP" --output none
az network routeserver peering create --name hub2CSR --peer-ip 172.16.2.196 --peer-asn 65003 --routeserver Hub2RouteServer --resource-group "$RESOURCE_GROUP" --output none
az network routeserver peering create --name hubCSR --peer-ip 172.16.1.196 --peer-asn 65002 --routeserver SpokeRouteServer --resource-group "$RESOURCE_GROUP" --output none
az network routeserver peering create --name hub2CSR --peer-ip 172.16.2.196 --peer-asn 65003 --routeserver SpokeRouteServer --resource-group "$RESOURCE_GROUP" --output none

log "Creating test VMs"
az vm create -n hubVM -g "$RESOURCE_GROUP" --image ubuntults --public-ip-sku Standard --size "$VM_SIZE" -l "$LOCATION" --subnet vmsubnet --vnet-name hub --admin-username "$ADMIN_USERNAME" --admin-password "$ADMIN_PASSWORD" --no-wait
az vm create -n hub2VM -g "$RESOURCE_GROUP" --image ubuntults --public-ip-sku Standard --size "$VM_SIZE" -l "$LOCATION" --subnet vmsubnet --vnet-name hub2 --admin-username "$ADMIN_USERNAME" --admin-password "$ADMIN_PASSWORD" --no-wait
az vm create -n spokeVM -g "$RESOURCE_GROUP" --image ubuntults --public-ip-sku Standard --size "$VM_SIZE" -l "$LOCATION" --subnet vmsubnet --vnet-name spoke --admin-username "$ADMIN_USERNAME" --admin-password "$ADMIN_PASSWORD" --no-wait
az vm create -n branchVM -g "$RESOURCE_GROUP" --image ubuntults --public-ip-sku Standard --size "$VM_SIZE" -l "$LOCATION" --subnet vmsubnet --vnet-name branch --admin-username "$ADMIN_USERNAME" --admin-password "$ADMIN_PASSWORD" --no-wait
az vm create -n branch2VM -g "$RESOURCE_GROUP" --image ubuntults --public-ip-sku Standard --size "$VM_SIZE" -l "$LOCATION" --subnet vmsubnet --vnet-name branch2 --admin-username "$ADMIN_USERNAME" --admin-password "$ADMIN_PASSWORD" --no-wait

log "Deployment submitted. Paste scripts/csr-config.txt into the CSR serial consoles, then run scripts/verify.sh"
