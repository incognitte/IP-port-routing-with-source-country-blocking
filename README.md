# port_routing_country_block

This script updates the iptables to:
1. Route specific external ports to their corresponding LXD containers
2. Uses **allowlist** to filter packets from specific IP sources
