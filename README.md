# draco_vagrant_VPN_client

This repository provides a Vagrantfile and provisioning script to bring up a Vagrant instance ready for routing an assigned static IP on the warzone VPN. It is useful for connecting a vulnerable host to the VPN that is incapable of running it's own OpenVPN client through a physcal interface bridged to the Vagrant box.

## Usage

* Install Vagrant

* Add Ubuntu Trusty box

* Edit Vagrantfile, setting bridged_interface_name to the name of the physical interface where the vulnerable host is attached

* Edit bootstrap.sh, setting VPN_STATIC_IP to your assigned static IP

* Bring up box

* Import OpenVPN config and subkey (NOTE: the subkey must have a role to allow routing your static IP on the VPN)

## TODO

* Instructions for configuring interfaces and routes
