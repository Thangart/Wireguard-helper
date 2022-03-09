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