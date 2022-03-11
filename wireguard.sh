#!/bin/bash

############################################################
# Globals                                                  #
############################################################

WIREGUARD_BIN="/usr/bin/wg"
VERSION="1.1"
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
SERVER_INSTALL=0
SERVER_FORWARD=0
SERVER_WIREGUARD_IP=""
SERVER_PUBLIC_INTERFACE=""

############################################################
# Help                                                     #
############################################################

Help()
{
   # Display Help
   echo "Adds a wireguard setup to the local machine."
   echo
   echo "Syntax: wireguard.sh [options]"
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
   echo
   echo "To Install the server use the following options:"
   echo "--server_install  To set the script to install the server component"
   echo "--server_forward  To set the server to allow ip forwarding"
   echo "--server_vpn_ip   Set the ip of the server example: 10.20.30.1/24"
   echo "--server_int      Set the public interface of the server. ususually eth0"
   echo
   echo "An example command could be:"
   echo
   echo "sudo ./wireguard.sh --keepalive 10 --server x.x.x.x:51820 --local_ip 10.20.30.2/24 --allowed_ips 10.20.30.0/24 --identity_file ~/.ssh/digitalocean --verbose --server_install --server_vpn_ip 10.20.30.1/24 --server_int eth0
"
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
      "--pub_key")
         shift
         SERVER_PUBLIC_KEY=$1
         ;;
      "--ssh_username")
         shift
         USERNAME=$1
         ;;
      "--server_install")
         SERVER_INSTALL=1
         ;;
      "--server_forward")
         SERVER_FORWARD=1
         ;;
      "--server_vpn_ip")
         shift
         SERVER_WIREGUARD_IP=$1
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
   echo "This script must be run as root" 
   exit 1
fi

############################################################
#                    Input checks                          #
############################################################

# Server address
if [[ "$SERVER" == "" ]]; then
   echo "Please use the --server option to set the server address. exiting"
   exit
fi


# Local IP
if [[ "$IP" == "" ]]; then
   echo "Please use the --local_ip option to set the local ip and subnet. exiting"
   exit
fi


# Allowed_IPS
if [[ "$ALLOWED_IPS" == "" ]]; then
   echo "No Allowed_IPS set. Using 0.0.0.0/0"
   ALLOWED_IPS="0.0.0.0/0"
fi

# Install check
if [[ "$SERVER_INSTALL" -eq 1 ]]; then
   if [[ "$SERVER_WIREGUARD_IP" == "" ]]; then
      echo "Server install detected. Please use the --server_vpn_ip option to set the local vpn ip *.*.*.*/*"
      exit
   fi
   if [[ "$SERVER_PUBLIC_INTERFACE" == "" ]]; then
      echo "Server install detected. Please use the --server_int option to set the server's public interface"
      exit
   fi
fi

# Check if Identityfile is set. otherwise make sure the pubkey is set.
if [[ "$IDENTITYFILE" == "" ]]; then
   if [[ "$SERVER_PUBLIC_KEY" == "" ]]; then
      echo
      echo "No ssh connection will be made but the servers public key is not given."
      echo "Please use the --pub_key option to the servers public key"
      exit
   fi
fi

############################################################
#                    Configuration checks                  #
############################################################

# Check if wireguard is installed and otherwise install it
if test -f "$WIREGUARD_BIN"; then
    echo "Wireguard is installed."
else
    echo "Installing Wireguard"
    apt install -y wireguard
fi

# Check if wireguard allready has a tunnel
if [[ $(ip a | grep wg0) ]]; then
   echo "Wireguard is allready running. Killing current connection"
   wg-quick down wg0
fi


# Check if config allready exists.
if [ -f "$CONFIG_LOCATION" ]; then
   echo "A wireguard config allready exists in $CONFIG_LOCATION. Do you want to continue? enter YES"
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
   echo "Generating private key"
   wg genkey | tee $KEY_LOCATION
fi

# Load keys
PUBLIC_KEY=`cat $KEY_LOCATION | wg pubkey`
PRIVATE_KEY=`cat $KEY_LOCATION`


############################################################
# Verbose logging                                          #
############################################################


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
   if [[ $SERVER_INSTALL -eq 1 ]]; then
       echo "[*] Setting server forwarding = $SERVER_FORWARD"
       echo "[*] Server vpn address =        $SERVER_WIREGUARD_IP"
       echo "[*] Server public interface =   $SERVER_PUBLIC_INTERFACE"
       echo
   fi
fi

############################################################
# Server Installation                                          #
############################################################

if [[ $SERVER_INSTALL -eq 1 ]]; then
   IFS=':' read -ra SERVER_IP <<< "$SERVER"

   echo
   echo "Starting the installation of the server. First copying the installation script over. A password for the identity file may be required"
   if [[ "$USERNAME" == "" ]]; then
      scp -i $IDENTITYFILE server.sh ${SERVER_IP[0]}:~/
   else
      scp -i $IDENTITYFILE server.sh $USERNAME@${SERVER_IP[0]}:~/
   fi
   echo
   echo "---- executing install script -----"
   echo "A password for the identityfile may be required"
   if [[ $SERVER_FORWARD -eq 1 ]]; then
      if [[ "$USERNAME" == "" ]]; then
         ssh -t -i $IDENTITYFILE ${SERVER_IP[0]} "./server.sh --server_vpn_ip $SERVER_WIREGUARD_IP --server_int $SERVER_PUBLIC_INTERFACE --server_forward"
      else
         ssh -t -i $IDENTITYFILE $USERNAME@${SERVER_IP[0]} "./server.sh --server_vpn_ip $SERVER_WIREGUARD_IP --server_int $SERVER_PUBLIC_INTERFACE --server_forward"
      fi
   else
      if [[ "$USERNAME" == "" ]]; then
         ssh -t -i $IDENTITYFILE ${SERVER_IP[0]} "./server.sh --server_vpn_ip $SERVER_WIREGUARD_IP --server_int $SERVER_PUBLIC_INTERFACE"
      else
         ssh -t -i $IDENTITYFILE $USERNAME@${SERVER_IP[0]} "./server.sh --server_vpn_ip $SERVER_WIREGUARD_IP --server_int $SERVER_PUBLIC_INTERFACE"
      fi
   fi
fi

############################################################
# Setting the server configuration                         #
############################################################

IFS='/' read -ra IP_ip <<< "$IP"

if [[ "$IDENTITYFILE" == "" ]]; then
   echo
   echo "No setup trough ssh"
   echo "Run the command on the server:"
   echo "sudo wg set wg0 peer $PUBLIC_KEY allowed-ips ${IP_ip[0]}/32"
else
   IFS=':' read -ra SERVER_IP <<< "$SERVER"

   echo
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
############################################################

if [[ $SYSTEMD -ne 0 ]]; then
   echo "Starting the tunnel as a service with persistency"
   sudo systemctl enable --now wg-quick@wg0.service
else 
   echo "Starting the tunnel as a process"
   sudo wg-quick up wg0
fi