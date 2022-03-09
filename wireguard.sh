#!/bin/bash

############################################################
# Globals                                                  #
############################################################

WIREGUARD_BIN="/usr/bin/wg"
VERSION="1.0"
VERBOSE=0
SYSTEMD=0
SERVER=""
IDENTITYFILE=""
USERNAME=""
IP=""
ALLOWED_IPS=""
PRIVATE_KEY=""
PUBLIC_KEY=""
SERVER_PUBLIC_KEY=""
KEY_LOCATION="/etc/wireguard/privatekey"
CONFIG_LOCATION="/etc/wireguard/wg0.conf"
KEEPALIVE=0

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
   echo "--deamon          Start as systemd service"
   echo "--server          The remote servers hostname or ip with port ip:port"
   echo "--local_ip        The ip address that the local connection should use with subnet exmpl: 10.20.30.2/24"
   echo "--allowed_ips     the allowed list of ip addresses that the local client should be able to reach ip/subnet. If empty it will be 0.0.0.0/0 (forward all trafic trough the vpn)"
   echo "--keepalive       Set the keepalive option in seconds (0 is disabled) in example -k 60"
   echo "--pub_key         Set the publickey of the remote server. If you set the ssh connection variables the application with retrieve the public key from the server"
   echo "--verbose         Enables debugging messages"
   echo
   echo "If you want add the client to the server trough ssh set the following option:"
   echo "--identity_file   The identityfile to connect via ssh to the remote server"
   echo "--ssh_username    Username to connect to trough ssh (optional)"
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
# Install serverside                                       #
############################################################



############################################################
# Argument parsing                                         #
############################################################
_setArgs(){
  while [ "${1:-}" != "" ]; do
    case "$1" in
      "--help" | '-h') # display Help
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
      "--server")
         shift
         SERVER=$1
         ;;
      "--identity_file")
         shift
         IDENTITYFILE=$1
         ;;
      "--local_ip")
         shift
         IP=$1
         ;; 
      "--allowed_ips")
         shift
         ALLOWED_IPS=$1
         ;;
      "--keepalive")
         shift
         KEEPALIVE=$1
         ;;
      "--ssh_username")
         shift
         USERNAME=$1
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
   echo "This script must be run as root" 
   exit 1
fi

# Check userinput


## Server address
if [[ "$SERVER" == "" ]]; then
   echo "Please use the -s option to set the server address. exiting"
   exit
fi


## Local IP
if [[ "$IP" == "" ]]; then
   echo "Please use the -a option to set the local ip and subnet. exiting"
   exit
fi


## Allowed_IPS
if [[ "$ALLOWED_IPS" == "" ]]; then
   echo "No Allowed_IPS set. Using 0.0.0.0/0"
   ALLOWED_IPS="0.0.0.0/0"
fi


# Check if wireguard is installed and otherwise install it
if test -f "$WIREGUARD_BIN"; then
    echo "Wireguard is installed."
else
    echo "Installing Wireguard"
    apt install -y wireguard
fi


# Check if config allready exists.
if [ -f "$CONFIG_LOCATION" ]; then
   echo "A wireguard config allready exists in $CONFIG_LOCATION. Do you want to continue? enter YES"
   read input
   if ! [[ "$input" == "YES" ]]; then
   echo "Cancelled by user. exiting"
   exit
   fi
fi

# Check if wireguard allready has a tunnel
if [[ $(ip a | grep wg0) ]]; then
   echo "Wireguard is allready running. Killing current connection"
   wg-quick down wg0
fi

# Check if a privatekey is generated
if ! [ -f "$KEY_LOCATION" ]; then
   echo "Generating private key"
   wg genkey | tee $KEY_LOCATION
fi

# Load keys
PUBLIC_KEY=`cat $KEY_LOCATION | wg pubkey`
PRIVATE_KEY=`cat $KEY_LOCATION`

# Verbose logging of state
if [[ $VERBOSE -eq 1 ]]; then
   echo
   echo
   echo "[*] Verbose logging enabled"
   echo "[*] Application version:            $VERSION"
   echo
   echo "[*] Set options:"
   echo "[*] Server address                  $SERVER"
   echo "[*] Local tunnel IP                 $IP"
   echo "[*] Local allowed IP's              $ALLOWED_IPS"
   echo "[*] Keepalive option =              $KEEPALIVE"
   echo "[*] SSH Username =                  $USERNAME"
   echo "[*] SSH idenitityfile location =    $IDENTITYFILE"
   echo "[*] Start application as systemd =  $SYSTEMD"

   echo "[*] Local public key =              $PUBLIC_KEY"
   echo "[*] Local Private key =             $PRIVATE_KEY"
   echo 
   echo
fi




############################################################
# Setting the server configuration                         #
############################################################

IFS='/' read -ra IP_ip <<< "$IP"

if [[ "$IDENTITYFILE" == "" ]]; then
   echo "No setup trough ssh"
   echo "Run the command on the server:"
   echo "sudo wg set wg0 peer $PUBLIC_KEY allowed-ips ${IP_ip[0]}/32"
else
   IFS=':' read -ra SERVER_IP <<< "$SERVER"

   echo "Setup trough ssh"
   echo "If sudo requires a password type the remote servers sudo password in the upcoming message."

   if [[ "$USERNAME" == "" ]]; then
      SERVER_PUBLIC_KEY=`ssh -t -i $IDENTITYFILE ${SERVER_IP[0]} "sudo wg set wg0 peer $PUBLIC_KEY allowed-ips ${IP_ip[0]}/32 && wg show wg0 public-key"`
   else
      SERVER_PUBLIC_KEY=`ssh -t -i $IDENTITYFILE $USERNAME@${SERVER_IP[0]} "sudo wg set wg0 peer $PUBLIC_KEY allowed-ips ${IP_ip[0]}/32 && wg show wg0 public-key"`
   fi

   if [[ $VERBOSE -eq 1 ]]; then
   echo
   echo
   echo "[*] Server public key:              $SERVER_PUBLIC_KEY"
   echo
   echo
fi

fi

############################################################
# Generating and installing config                         #
############################################################

echo """
[Interface]
Address = $IP
SaveConfig = true
ListenPort = 47462
PrivateKey = $PRIVATE_KEY

[Peer]
PublicKey = $SERVER_PUBLIC_KEY
AllowedIPs = $ALLOWED_IPS
Endpoint = $SERVER""" > /etc/wireguard/wg0.conf

if ! [[ "$KEEPALIVE" == 0 ]]; then
   echo "PersistentKeepalive = $KEEPALIVE" >> $CONFIG_LOCATION
fi

############################################################
# Starting the wireguard tunnel                            #
############################################################ALLOWED_IPS_ip

if [[ $SYSTEMD -ne 0 ]]; then
   echo "Starting the tunnel as a service with persistency"
   sudo systemctl enable --now wg-quick@wg0.service
else 
   echo "Starting the tunnel as a process"
   sudo wg-quick up wg0
fi