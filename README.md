# Azure-Route-Server Dual Home
In this lab, we are going to deploy ARS in a dual home topology following this public article: https://learn.microsoft.com/en-us/azure/route-server/about-dual-homed-network
This is an alternative approach besides using VNET peering to connect resources in a hub+spoke model and allow connections to and from on-premise. This could be useful in a side car environment. If say one of the hubs went down with ARS, the spoke would still be reachable via the other hub. In this lab, we are going to use Vnet-to-Vnet IPSEC connections with BGP simmulating on-premise instead of two ExpressRoute circuits. This is also needed, because you cannot do both VNG and LNG with ASN 65515, when building S2S IPSEC connections.

This lab is using serial console for all VM connections including the CSRs. The VM username is "azureser" and password is "MyP@SSword123!"

# Topology

![image](https://user-images.githubusercontent.com/55964102/193950333-6de95954-4e3e-471e-aa4c-e61efdd33b9c.png)

## Commands
```bash
#Paramaters

loc=EastUS2
rg=Lab_ARSDual
username=azureuser
password="MyP@SSword123!"
vmsize=Standard_D2_v2

#Create the VNETs (Hubs+Spoke) and VPN Branches

az network vnet create --address-prefixes 172.16.1.0/24 -n hub -g $rg -l $loc --output none
az network vnet subnet create --name RouteServerSubnet --address-prefixes 172.16.1.0/25 --resource-group $rg --vnet-name hub --output none
az network vnet subnet create --name csroutside --address-prefixes 172.16.1.128/26 --resource-group $rg --vnet-name hub --output none
az network vnet subnet create --name csrinside --address-prefixes 172.16.1.192/27 --resource-group $rg --vnet-name hub --output none
az network vnet subnet create --name GatewaySubnet --address-prefixes 172.16.1.224/28 --resource-group $rg --vnet-name hub --output none
az network vnet subnet create --name vmsubnet --address-prefixes 172.16.1.240/29 --resource-group $rg --vnet-name hub --output none

az network vnet create --address-prefixes 172.16.2.0/24 -n hub2 -g $rg -l $loc --output none
az network vnet subnet create --name RouteServerSubnet --address-prefixes 172.16.2.0/25 --resource-group $rg --vnet-name hub2 --output none
az network vnet subnet create --name csroutside --address-prefixes 172.16.2.128/26 --resource-group $rg --vnet-name hub2 --output none
az network vnet subnet create --name csrinside --address-prefixes 172.16.2.192/27 --resource-group $rg --vnet-name hub2 --output none
az network vnet subnet create --name GatewaySubnet --address-prefixes 172.16.2.224/28 --resource-group $rg --vnet-name hub2 --output none
az network vnet subnet create --name vmsubnet --address-prefixes 172.16.2.240/29 --resource-group $rg --vnet-name hub --output none

az network vnet create --address-prefixes 172.16.3.0/24 -n spoke -g $rg -l $loc --output none 
az network vnet subnet create --name RouteServerSubnet --address-prefixes 172.16.3.0/25 --resource-group $rg --vnet-name spoke --output none
az network vnet subnet create --name vmsubnet --address-prefixes 172.16.3.240/29 --resource-group $rg --vnet-name spoke --output none

az network vnet create --address-prefixes 172.16.4.0/24 -n branch -g $rg -l $loc --output none
az network vnet subnet create --name vmsubnet --address-prefixes 172.16.4.0/25 --resource-group $rg --vnet-name branch --output none
az network vnet subnet create --name GatewaySubnet --address-prefixes 172.16.4.224/28 --resource-group $rg --vnet-name branch --output none

az network vnet create --address-prefixes 172.16.5.0/24 -n branch2 -g $rg -l $loc --output none 
az network vnet subnet create --name vmsubnet --address-prefixes 172.16.5.0/25 --resource-group $rg --vnet-name branch2 --output none
az network vnet subnet create --name GatewaySubnet --address-prefixes 172.16.5.224/28 --resource-group $rg --vnet-name branch2 --output none

#Create the peering between spoke and hub vnets

az network vnet peering create -g $rg -n HubtoSpoke --vnet-name hub --remote-vnet spoke --allow-vnet-access --allow-forwarded-traffic --output none
az network vnet peering create -g $rg -n SpoketoHub --vnet-name spoke --remote-vnet hub --allow-vnet-access --allow-forwarded-traffic --output none
az network vnet peering create -g $rg -n Hub2toSpoke --vnet-name hub2 --remote-vnet spoke --allow-vnet-access --allow-forwarded-traffic --output none
az network vnet peering create -g $rg -n SpoketoHub2 --vnet-name spoke --remote-vnet hub2 --allow-vnet-access --allow-forwarded-traffic --output none

#Create the NVAs (CSR) in each hub

az vm image terms accept --urn cisco:cisco-csr-1000v:17_3_4a-byol:latest --output none

az network public-ip create --name CSRPubIP --resource-group $rg --idle-timeout 30 --allocation-method Static --location $loc --output none
az network nic create --name CSROutsideInt -g $rg --subnet csroutside --vnet hub --public-ip-address CSRPubIP --ip-forwarding true --location $loc --output none
az network nic create --name CSRInsideInt -g $rg --subnet csrinside --vnet hub --ip-forwarding true --location $loc --output none
az vm create --resource-group $rg --location $loc --name hubCSR --size $vmsize --nics CSROutsideInterface CSRInsideInterface --image cisco:cisco-csr-1000v:17_3_4a-byol:latest --admin-username azureuser --admin-password MyP@SSword123!

az network public-ip create --name CSRPubIP2 --resource-group $rg --idle-timeout 30 --allocation-method Static --location $loc --output none
az network nic create --name CSROutsideInt2 -g $rg --subnet csroutside --vnet hub2 --public-ip-address CSRPubIP2 --ip-forwarding true --location $loc --output none
az network nic create --name CSRInsideInt2 -g $rg --subnet csrinside --vnet hub2 --ip-forwarding true --location $loc --output none
az vm create --resource-group $rg --location $loc --name hub2CSR --size $vmsize --nics CSROutsideInt2 CSRInsideInt2 --image cisco:cisco-csr-1000v:17_3_4a-byol:latest --admin-username azureuser --admin-password MyP@SSword123!

#Create the GWs for the hub VNETs

(ARS requires A/A GWs and hub GW ASN must be 65515) 
az network public-ip create -n hub-vpngw-pip -g $rg --location $loc --sku Basic --output none
az network public-ip create -n hub-vpngwPIP -g $rg --location $loc --sku Basic --output none
az network public-ip create -n hub2-vpngw-pip -g $rg --location $loc --sku Basic --output none
az network public-ip create -n hub2-vpngwPIP -g $rg --location $loc --sku Basic --output none

az network vnet-gateway create -n hub-vpngw --public-ip-addresses hub-vpngw-pip hub-vpngwPIP -g $rg --vnet hub --asn 65515 --gateway-type Vpn -l $loc --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait 
az network vnet-gateway create -n hub2-vpngw --public-ip-addresses hub2-vpngw-pip hub2-vpngwPIP -g $rg --vnet hub2 --asn 65515 --gateway-type Vpn -l $loc --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait

#Create the GWs for the branch VNETS

az network public-ip create -n branch-vpngw-pip -g $rg --location $loc --sku Basic --output none
az network public-ip create -n branch-vpngwPIP -g $rg --location $loc --sku Basic --output none
az network public-ip create -n branch2-vpngw-pip -g $rg --location $loc --sku Basic --output none
az network public-ip create -n branch2-vpngwPIP -g $rg --location $loc --sku Basic --output none

az network vnet-gateway create -n branch-vpngw --public-ip-addresses branch-vpngw-pip branch-vpngwPIP -g $rg --vnet branch --asn 65511 --gateway-type Vpn -l $loc --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait 
az network vnet-gateway create -n branch2-vpngw --public-ip-addresses branch2-vpngw-pip branch2-vpngwPIP -g $rg --vnet branch2 --asn 65512 --gateway-type Vpn -l $loc --sku VpnGw1 --vpn-gateway-generation Generation1 --no-wait

#Get Pips and BGP Settings

hubbgp=$(az network vnet-gateway show -n hub-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
hubpip=$(az network vnet-gateway show -n hub-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
hub2bgp=$(az network vpn-gateway show -n hub2-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
hub2pip=$(az network vpn-gateway show -n hub2-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)

branchbgp=$(az network vpn-gateway show -n branch-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
branchpip=$(az network vnet-gateway show -n branch-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)
branch2bgp=$(az network vpn-gateway show -n branch2-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].defaultBgpIpAddresses[0]' -o tsv)
branch2pip=$(az network vpn-gateway show -n branch2-vpngw -g $rg --query 'bgpSettings.bgpPeeringAddresses[0].tunnelIpAddresses[0]' -o tsv)


#Create Connection objects (Have to do V2V since you cannot specify 65515 for both LNG and VPNGW for S2S with ARS)

az network vpn-connection create -n hubtobranch -g $rg -l $loc --vnet-gateway1 hub-vpngw --vnet-gateway2 branch-vpngw --enable-bgp --shared-key 'abc123' --output none
az network vpn-connection create -n branchtohub -g $rg -l $loc --vnet-gateway1 branch-vpngw --vnet-gateway2 hub-vpngw --enable-bgp --shared-key 'abc123' --output none
az network vpn-connection create -n hub2tobranch2 -g $rg -l $loc --vnet-gateway1 hub2-vpngw --vnet-gateway2 branch2-vpngw --enable-bgp --shared-key 'abc123' --output none
az network vpn-connection create -n branch2tohub2 -g $rg -l $loc --vnet-gateway1 branch2-vpngw --vnet-gateway2 hub2-vpngw --enable-bgp --shared-key 'abc123' --output none

#Create the ARS in hubs and spoke

#Create the Pips
az network public-ip create --name HubRouteServerIP --resource-group $rg  --version IPv4 --sku Standard --output none
az network public-ip create --name Hub2RouteServerIP --resource-group $rg  --version IPv4 --sku Standard --output none
az network public-ip create --name SpokeRouteServerIP --resource-group $rg  --version IPv4 --sku Standard --output none

#Get the ARS SubnetIds
arshubsubnet_id=$(az network vnet subnet show --name RouteServerSubnet --resource-group $rg --vnet-name hub --query id -o tsv)
echo @arshubsubnet_id

arshub2subnet_id=$(az network vnet subnet show --name RouteServerSubnet --resource-group $rg --vnet-name hub2 --query id -o tsv)
echo @routeserverhubsubnet_id

arsspokesubnet_id=$(az network vnet subnet show --name RouteServerSubnet --resource-group $rg --vnet-name spoke --query id -o tsv)
echo @routeserverhubsubnet_id

az network routeserver create --name HubRouteServer --resource-group $rg --hosted-subnet $arshubsubnet_id --public-ip-address HubRouteServerIP --output none
az network routeserver create --name Hub2RouteServer --resource-group $rg --hosted-subnet $arshub2subnet_id --public-ip-address Hub2RouteServerIP --output none
az network routeserver create --name SpokeRouteServer --resource-group $rg --hosted-subnet $arsspokesubnet_id --public-ip-address SpokeRouteServerIP   --output none
