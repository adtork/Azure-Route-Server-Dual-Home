# Azure-Route-Server Dual Home
In this lab, we are going to deploy ARS in a dual home topology following this public article: https://learn.microsoft.com/en-us/azure/route-server/about-dual-homed-network
This is an alternative approach besides using VNET peering to connect resources in a hub+spoke model and allow connections to and from on-premise. This could be useful in a side car environment. If say one of the hubs went down with ARS, the spoke would still be reachable via the other hub. In this lab, we are going to use Vnet-to-Vnet IPSEC connections with BGP simmulating on-premise instead of two ExpressRoute circuits. This is also needed, because you cannot do both VNG and LNG with ASN 65515, when building S2S IPSEC connections.

This lab is using serial console for all VM connections including the CSRs. The VM username is "azureser" and password is "MyP@SSword123!"

# Topology

![image](https://user-images.githubusercontent.com/55964102/193950333-6de95954-4e3e-471e-aa4c-e61efdd33b9c.png)

