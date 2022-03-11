#!/bin/bash

############################################################
# Globals                                                  #
############################################################

WIREGUARD_BIN="/usr/bin/wg"
VERSION="1.1"
VERBOSE=0
IP=""
SERVER_PRIVATE_KEY=""
SERVER_PUBLIC_KEY=""
KEY_LOCATION="/etc/wireguard/privatekey"
CONFIG_LOCATION="/etc/wireguard/wg0.conf"
SERVER_CONFIG_IP=""
SERVER_FORWARD=0
SERVER_PUBLIC_INTERFACE=""

############################################################
# Help                                                     #
############################################################

Help()
{
   # Display Help
   echo "Adds a wireguard setup to the local machine."
   echo
   echo "Syntax: wireguard.sh [-h|v|d\s\i\a\n\k]"
   echo "options:"
   echo "--help            Print this Help."
   echo "--version         Print software version and exit."
   echo "--destroy         Remove the current config locally and from server"
   echo "--verbose         Enables debugging messages"
   echo
   echo "--server_forward  Enable IP forwarding if it isn't allready enabled on the server"
   echo "--server_vpn_ip   Set the server ip and subnet example: 10.20.30.1/24"
   echo "--server_int      Set the public interface of the server. ususually eth0"
   echo
   echo "Example commands:"
   echo
   echo "sudo ./wireguard.sh --verbose --server_forward=1 --server_ip=10.20.30.1/24"
}

############################################################
# Version                                                  #
############################################################

Version()
{
   # Display Help
   echo "Wireguard helper script version $VERSION"
}

############################################################
# Argument parsing                                         #
############################################################
_setArgs(){
  while [ "${1:-}" != "" ]; do
    case "$1" in
      "--help") # display Help
         Help
         exit;;
      "--version") #print version
         Version
         exit;;
      "--verbose")
         VERBOSE=1
         ;;
      "--deamon")
         SYSTEMD=1
         ;;
      "--server_forward")
         SERVER_FORWARD=1
         ;;
      "--server_vpn_ip")
         shift
         SERVER_CONFIG_IP=$1
         ;;
      "--server_int")
         shift
         SERVER_PUBLIC_INTERFACE=$1
         ;;
      \?) # Invalid option
         echo "Error: Invalid option"
         exit;;
    esac
    shift
  done
}

_setArgs "$@"


############################################################
# Preflight checks                                         #
############################################################

# Root check
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root or with sudo; exiting" 
   exit
fi

if [[ "$SERVER_CONFIG_IP" == "" ]]; then
   echo "Please use the --server_vpn_ip option to set the local vpn ip *.*.*.*/*"
   exit
fi
if [[ "$SERVER_PUBLIC_INTERFACE" == "" ]]; then
   echo "Please use the --server_int option to set the server's public interface"
   exit
fi


# Check if wireguard is installed and otherwise install it
if test -f "$WIREGUARD_BIN"; then
    echo "Wireguard is installed."
else
    echo "Installing Wireguard"
    apt install -y wireguard
fi

# Check if wireguard allready has a tunnel
if [[ $(ip a | grep wg0) ]]; then
   echo
   echo "Wireguard is allready running. Killing current connection"
   wg-quick down wg0
fi

# Check if config allready exists.
if [ -f "$CONFIG_LOCATION" ]; then
   echo
   echo "Warning. installing the server over an existing server will erase all current endpoints."
   echo "A wireguard SERVER configuration allready exists in $CONFIG_LOCATION. Do you want to continue? enter YES"
   read input
   if ! [[ "$input" == "YES" ]]; then
   echo "Cancelled by user. exiting"
   exit
   fi
   # Create a backup of the old config
   STAMP=`date +%m-%d-%Y-%T`
   mv "$CONFIG_LOCATION" "$CONFIG_LOCATION.$STAMP.bak"
fi

# Check if a privatekey is generated
if ! [ -f "$KEY_LOCATION" ]; then
   echo
   echo "Generating private key"
   wg genkey | tee $KEY_LOCATION
fi

# Load keys
SERVER_PUBLIC_KEY=`cat $KEY_LOCATION | wg pubkey`
SERVER_PRIVATE_KEY=`cat $KEY_LOCATION`

############################################################
# Setting the server configuration                         #
############################################################
echo """
[Interface]
PrivateKey=$SERVER_PRIVATE_KEY
Address=$SERVER_CONFIG_IP #<server-ip-address>/<subnet>
SaveConfig=true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o $SERVER_PUBLIC_INTERFACE -j MASQUERADE;
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o $SERVER_PUBLIC_INTERFACE -j MASQUERADE;
ListenPort = 51820""" > $CONFIG_LOCATION

############################################################
# Starting the server                                      #
############################################################

systemctl enable wg-quick@wg0.service
systemctl stop wg-quick@wg0.service
systemctl start wg-quick@wg0.service

echo "Server install script done."

############################################################
# Set IP forwading                                         #
############################################################

if [[ $SERVER_FORWARD -eq 1 ]]; then
   echo
   echo "Setting ip forwarding to 1"
   sysctl -w net.ipv4.ip_forward=1
   sed -i 's/#net.ipv4.ip_forward/net.ipv4.ip_forward/g' /etc/sysctl.conf
   sed -i 's/net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
fi