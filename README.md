# Azure-Route-Server Dual Home
In this lab, we are going to deploy ARS in a dual home topology following this public article: https://learn.microsoft.com/en-us/azure/route-server/about-dual-homed-network
This is an alternative approach besides using VNET peering to connect resources in a hub+Spoke model and allow connections to and from on-premise. This could be useful as a side car environment. If say one of the hubs went down with ARS, the spoke would still be reachable via the other hub. In this lab, we are going to use Vnet-to-Vnet IPSEC connections simmulating on-prem instead of two ExpressRoute circuits. This is also needed, because you cannot do both a VNG and LNG both with ASN 65515, which is needed for ARS.

# Topology
