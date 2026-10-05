# eJPT Pivot Lab — one-command, cross-platform (VirtualBox + Vagrant)
# Topology:
#   Red A (host-only 192.168.56.0/24)  <- tu Kali se conecta aca
#     gateway (dual-homed) 192.168.56.101  +  172.16.50.10 (Red B)
#   Red B (internal "ejpt_internal", aislada, solo via pivot)
#     services  172.16.50.22
#     windows   172.16.50.23
#
# Uso:  vagrant up          (levanta todo)
#       vagrant halt        (apaga)   |   vagrant destroy -f (borra)

Vagrant.configure("2") do |config|
  config.vm.boot_timeout = 600

  # ---------- Gateway / pivot (Linux, cargado de servicios) ----------
  config.vm.define "gateway" do |gw|
    gw.vm.box = "rapid7/metasploitable3-ub1404"
    gw.vm.hostname = "gateway"
    gw.vm.synced_folder ".", "/vagrant", disabled: true   # box sin Guest Additions
    # metasploitable3 (Linux) autentica con vagrant:vagrant por password y
    # no tolera el reemplazo automatico de clave SSH -> forzamos password.
    gw.ssh.username   = "vagrant"
    gw.ssh.password   = "vagrant"
    # insert_key=true: Vagrant conecta por password y luego inserta una key
    # (arregla el auth del box Y deja 'vagrant ssh' funcionando)
    gw.vm.network "private_network", ip: "192.168.56.101"                              # Red A (host-only)
    gw.vm.network "private_network", ip: "172.16.50.10", virtualbox__intnet: "ejpt_internal"  # Red B (intnet)
    gw.vm.provider "virtualbox" do |vb|
      vb.name   = "ejpt-gateway"
      vb.memory = 2048
      vb.cpus   = 2
    end
  end

  # ---------- services-box (Linux interno: rsync/snmp/webdav/wordpress/shellshock) ----------
  config.vm.define "services" do |sv|
    sv.vm.box = "bento/ubuntu-20.04"
    sv.vm.hostname = "services-box"
    sv.vm.network "private_network", ip: "172.16.50.22", virtualbox__intnet: "ejpt_internal"  # solo Red B
    sv.vm.provider "virtualbox" do |vb|
      vb.name   = "ejpt-services"
      vb.memory = 2560
      vb.cpus   = 2
    end
    sv.vm.provision "shell", path: "provision/services-provision.sh"
  end

  # ---------- Windows interno (SMB/RDP/WinRM/IIS/MSSQL-apps) ----------
  config.vm.define "windows" do |win|
    win.vm.box = "rapid7/metasploitable3-win2k8"
    win.vm.communicator = "winrm"
    win.vm.network "private_network", ip: "172.16.50.23", virtualbox__intnet: "ejpt_internal"  # solo Red B
    win.vm.provider "virtualbox" do |vb|
      vb.name   = "ejpt-windows"
      vb.memory = 4096
      vb.cpus   = 2
    end
  end
end
