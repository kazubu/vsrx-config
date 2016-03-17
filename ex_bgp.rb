require 'ipaddr'

VSRX_NUM = 300

PEER0_BASE = '10.1.0.0'
PEER0_LOCAL = '10.1.255.254'
ROUTE0_BASE = '10.10.0.0'
ROUTE0_NH = '10.100.1.1'
BP_IF0 = '10.100.1.254'
ASN0 = '65500'

PEER1_BASE = '10.2.0.0'
PEER1_LOCAL = '10.2.255.254'
ROUTE1_BASE = '10.20.0.0'
ROUTE1_NH = '10.100.2.1'
BP_IF1 = '10.100.2.254'
ASN1 = '65501'

ASN_BASE = 65000

if true
  ip_base = PEER0_BASE
  local_ip = PEER0_LOCAL
  route_base = ROUTE0_BASE
  nexthop = ROUTE0_NH
  local_asn = ASN0
  bp_if = BP_IF0
else
  ip_base = PEER1_BASE
  local_ip = PEER1_LOCAL
  route_base = ROUTE1_BASE
  nexthop = ROUTE1_NH
  local_asn = ASN1
  bp_if = BP_IF1
end

puts <<EOL
set interfaces xe-0/0/17 unit 0 family ethernet-switching vlan members vsrx
set interfaces xe-0/0/18 unit 0 family ethernet-switching vlan members vsrx
set interfaces xe-0/0/19 unit 0 family ethernet-switching vlan members vsrx
set interfaces xe-0/0/20 unit 0 family ethernet-switching vlan members vsrx
set interfaces xe-0/0/21 unit 0 family inet address #{bp_if}/24
set interfaces irb unit 99 family inet address #{local_ip}/16
set vlans vsrx vlan-id 99 l3-interface irb.99
set routing-options autonomous-system #{local_asn}
set routing-options static route #{route_base}/16 next-hop #{nexthop}
set policy-options policy-statement export-all from route-filter #{route_base}/16 exact
set policy-options policy-statement export-all then accept
EOL

(1..VSRX_NUM).each{|rid|
  addr = IPAddr.new((IPAddr.new(ip_base).to_i + rid), Socket::AF_INET)
  route = IPAddr.new((IPAddr.new(route_base).to_i + rid), Socket::AF_INET)
  asn = (ASN_BASE + rid).to_s

  puts <<EOL
set routing-options static route #{route}/32 next-hop #{nexthop}
set policy-options policy-statement export-#{asn} from route-filter #{route}/32 exact
set policy-options policy-statement export-#{asn} then accept
set protocols bgp group VSRX neighbor #{addr} peer-as #{asn} export [ export-#{asn} export-all ]
EOL
}


