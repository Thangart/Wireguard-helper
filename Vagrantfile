# -*- mode: ruby -*-
# vi: set ft=ruby :

$update_repo_script = <<SCRIPT
echo "Updating repo ..."
sudo apt-get update
if [ ! -f "/ssh/id_ed25519.pub" ]; then
  ssh-keygen -o -a 100 -t ed25519 -f /ssh/id_ed25519 -N '' <<<$'\n'
fi 
cat /ssh/id_ed25519.pub >> /home/vagrant/.ssh/authorized_keys
cp /ssh/id_ed25519 /home/vagrant/.ssh/
chown vagrant:vagrant /home/vagrant/.ssh/id_ed25519
SCRIPT

BOX_NAME = "bento/ubuntu-20.04"
MEMORY = "2048"
CPUS = 2
SERVERS = 1
SERVER_IP = "192.168.60.1"
CLIENTS = 3
CLIENT_IP = "192.168.60.10"
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  #Common setup
  config.vm.box = BOX_NAME
  config.vm.synced_folder ".", "/wireguard_scripts"
  config.vm.provision "shell",inline: $update_repo_script, privileged: true
  config.vm.provider "virtualbox" do |vb|
    vb.memory = MEMORY
    vb.cpus = CPUS
  config.vm.synced_folder "./ssh", "/ssh"
  config.hostmanager.enabled = true
  config.hostmanager.manage_guest = true
  config.hostmanager.ignore_private_ip = false
  config.hostmanager.include_offline = true
  end

  #Setup server Nodes
  (1..SERVERS).each do |i|
    config.vm.define "server0#{i}" do |server|
    server.vm.network :private_network, ip: "#{SERVER_IP}#{i}"
    server.vm.hostname = "server0#{i}"
      if i == 1
        #Only configure port to host for server01
        server.vm.network :forwarded_port, guest: 51820, host: 51820
      end
      # server.vm.provision "shell", path: "./scripts/bootstrap.sh"
      # server.vm.provision "shell", path: "./scripts/manager.sh"
  end
end

  #Setup client Nodes
  (1..CLIENTS).each do |i|
    config.vm.define "client0#{i}" do |client|
      client.vm.network :private_network, ip: "#{CLIENT_IP}#{i}"
      client.vm.hostname = "client0#{i}"
        # worker.vm.provision "shell", path: "./scripts/bootstrap.sh"
        # worker.vm.provision "shell", path: "./scripts/worker.sh"
    end
  end

  config.vm.provision :hostmanager
end
