# -*- mode: ruby -*-
# vi: set ft=ruby :

bridged_interface_name = ""

Vagrant.configure(2) do |config|
  config.vm.box = "ubuntu/trusty64"
  
  config.vm.network "public_network",
    bridge: bridged_interface_name
  
  config.vm.provision "shell",
    path: "bootstrap.sh"
end
