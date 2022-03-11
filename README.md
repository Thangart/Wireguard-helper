# Wireguard helper

A simple script that can be used to setup a wireguard server and connect a client trough ssh.

Can be used as a standalone client without ssh to generate a local config and a wg-quick command to add on the server. (You'll need the pub key of the server in order for it to work.

```
Syntax: wireguard.sh [options]
   options:
   --help            Print this Help.
   --version         Print software version and exit.
   --destroy         Remove the current config locally and from server
   --deamon          Start as systemd service
   --server          The remote servers hostname or ip with port ip:port
   --local_ip        The ip address that the local connection should use with subnet exmpl: 10.20.30.2/24
   --allowed_ips     the allowed list of ip addresses that the local client should be able to reach ip/subnet. If empty it will be 0.0.0.0/0 (forward all trafic trough the vpn)
   --keepalive       Set the keepalive option in seconds (0 is disabled) in example -k 60
   --pub_key         Set the publickey of the remote server. If you set the ssh connection variables the application with retrieve the public key from the server
   --verbose         Enables debugging messages
   
   If you want add the client to the server trough ssh set the following option:
   --identity_file   The identityfile to connect via ssh to the remote server
   --ssh_username    Username to connect to trough ssh (optional)
   
   To Install the server use the following options:
   --server_install  To set the script to install the server component
   --server_forward  To set the server to allow ip forwarding
   --server_vpn_ip   Set the ip of the server example: 10.20.30.1/24
   --server_int      Set the public interface of the server. ususually eth0
   
   An example command could be:
   
   sudo ./wireguard.sh --keepalive 10 --server x.x.x.x:51820 --local_ip 10.20.30.2/24 --allowed_ips 10.20.30.0/24 --identity_file ~/.ssh/ident --verbose --server_install --server_vpn_ip 10.20.30.1/24 --server_int eth0
)
```

# SSH keys
The SSH keys in the ssh folder are for easy interconectability only. not to be used in real world examples

# Vagrant
The Vagrantfile provides a litle playground to test out the script. 
By default there is one server and three clients to be provisioned by vagrant.

It uses the vagrant hostmanager plugin in order to set the hosts file of the boxes to allow easy name convention.
This can be installed with:
```
vagrant plugin install vagrant-hostmanager
```

Start the boxes and connect to client01 with:
```
vagrant up
vagrant ssh client01
```
Then you can use the wireguard script located in the folder /wireguard_script to install the server and clients on the many devices.
The server and client01 can be installed with the command:
```
sudo /wireguard_scripts/wireguard.sh --deamon --server server01:51820 --allowed_ips 10.20.30.0/24 --keepalive 10 --verbose --identity_file ~/.ssh/id_ed25519 --ssh_username vagrant --local_ip 10.20.30.1/24 --server_install --server_forward --server_vpn_ip 10.20.30.11/24 --server_int eth1
```
This sets the server to the vpn ip 10.20.30.11 and the client to 10.20.30.1 and allows only the vpn subnet to be routed trough the vpn. Other clients can now be added with the command (The local_ip should be changed to an unique IP everytime its used (replace *)):
```
sudo /wireguard_scripts/wireguard.sh --deamon --server server01:51820 --allowed_ips 10.20.30.0/24 --keepalive 10 --verbose --identity_file ~/.ssh/id_ed25519 --ssh_username vagrant --local_ip 10.20.30.*/24
```

