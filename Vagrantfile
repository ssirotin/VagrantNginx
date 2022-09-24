# -*- mode: ruby -*-
# vim: set ft=ruby :

servers = [
      {
        :hostname => 'WEB',
        :boxname => "ubuntu/focal64",
        :ip_addr => '192.168.0.77',
      },  
]

Vagrant.configure("2") do |config|

  servers.each do |machine|

      config.vm.define machine[:hostname] do |nodeconfig|

          nodeconfig.vm.box = machine[:boxname]
          nodeconfig.vm.hostname = machine[:hostname]

          #box.vm.network "forwarded_port", guest: 3260, host: 3260+offset

          nodeconfig.vm.network "private_network", ip: machine[:ip_addr]

          nodeconfig.vm.provider :virtualbox do |vb|
            vb.customize ["modifyvm", :id, "--memory", "1024"]
            vb.name = machine[:hostname]
          nodeconfig.vm.provision "shell", path: "./Nginxconf.sh"  
             end
          end
      end
  end