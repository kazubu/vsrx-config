#!/usr/bin/env ruby
require 'net/netconf'
require 'ipaddr'
require 'erb'
require 'net/ssh'

POD_CONFIG_TMPL = 'test_config_template.xml.erb'

VSRX_NUM = 300

VSRX_USER = 'root'
VSRX_PASS = 'admin123'

MGMT_BASE = '10.0.0.0'
GE0_BASE = '10.1.0.0'
GE1_BASE = '10.2.0.0'
LO0_BASE = '10.255.0.0'
ASN_BASE = 65000


def do_command(_cmd)
  stdout = `#{_cmd}`
  ret = $?

  puts _cmd if ret != 0
  raise 'command execution error' if ret != 0
  return stdout
end

def generate_config(_routerid)
  rid = _routerid

  ge0_addr = IPAddr.new((IPAddr.new(GE0_BASE).to_i + rid), Socket::AF_INET)
  ge1_addr = IPAddr.new((IPAddr.new(GE1_BASE).to_i + rid), Socket::AF_INET)
  lo0_addr = IPAddr.new((IPAddr.new(LO0_BASE).to_i + rid), Socket::AF_INET)
  asn = (ASN_BASE + rid).to_s

  puts "ge0: #{ge0_addr}\nge1: #{ge1_addr}\nlo0: #{lo0_addr}\nasn: #{asn}"

  config_tmpl = File.read(POD_CONFIG_TMPL)
  return ERB.new(config_tmpl).result(binding)
end

def put_configuration(config, ipaddr)
  Netconf::SSH.new({:target => ipaddr, :username => VSRX_USER, :password => VSRX_PASS}) do |device|
    begin
      puts 'Trying to get lock of configuration...'
      device.rpc.lock 'candidate'
    rescue
      puts 'lock failed. Waiting 10 seconds...'
      sleep 10
      retry
    end

    puts device.rpc.edit_config(Nokogiri::XML(config))#, {:format => 'xml', :action => 'override'})
    device.rpc.commit

    device.rpc.unlock 'candidate'
  end
end

def wait_ping(_addr)
  while true do
    `ping -c 1 -W 2 #{_addr}`
    break if $? == 0

    puts "Waiting ..."
    sleep 10
  end
  puts "Host returns pong!"
  sleep 10
end

def main

  (1..VSRX_NUM).each{|rid|
    addr = IPAddr.new((IPAddr.new(MGMT_BASE).to_i + rid), Socket::AF_INET)
    puts "Generating a configuration of #{rid}(#{addr})"
    config = generate_config rid

    puts "Waiting to boot the vSRX ..."
    wait_ping(addr)

    puts "Complete to boot. Pushing a startup configuration ..."
    put_configuration(config, addr)
  }

  puts "Finished!" 
end

main

