require "vagrant"

module VagrantPlugins
  module GuestNetworkd

    class Guest < Vagrant.plugin("2", :guest)
      def detect?(machine)
        machine.communicate.test("systemctl") and
        machine.communicate.test("/etc/systemd/network")
      end
    end

    module Cap
      class ChangeHostName
        def self.change_host_name(machine, name)
          name = name.split('.')
          hostname = name.shift
          domain = name.empty? ? "local" : name.join('.')
          machine.communicate.tap do |comm|
            # Only do this if the hostname is not already set
            if !comm.test("sudo hostname | grep '#{hostname}'")
              comm.sudo("hostnamectl set-hostname #{hostname}")
              comm.sudo("sed -i 's@^\\(127[.]0[.]0[.]1[[:space:]]\\+\\)@\\1#{hostname}.#{domain} #{hostname} @' /etc/hosts")
            end
          end
        end
      end

      class ConfigureNetworks
        def self.configure_networks(machine, networks)
          networks.each do |network|
          interfaces = Array.new
          cmd = 'ip addr | awk \'/: ./ && !/lo/ { sub(/:/, "", $2); print $2 }\''
          machine.communicate.sudo(cmd) do |_, result|
            interfaces = result.split("\n")
          end
          machine.communicate.sudo("rm -rf /etc/systemd/network/vagrant_*")
          networks.each do |network|
            network[:device] = interfaces[network[:interface]]
            templateFile = File.expand_path("../../templates/network_#{network[:type]}.erb", __FILE__)
            template = File.read(templateFile)
            configFile = "/etc/systemd/network/vagrant_#{network[:device]}.network"            
            config = ERB.new(template).result            
            machine.communicate.sudo("echo -e #{config} > #{filename}")
          end
          machine.communicate.sudo("systemctl restart systemd-networkd.service")
        end
      end
    end

    class Plugin < Vagrant.plugin("2")
      name "networkd based guest"
      description "networkd based guest support."

      guest("networkd", "linux") do
        Guest
      end

      guest_capability("networkd", "change_host_name") do
        Cap::ChangeHostName
      end

      guest_capability("networkd", "configure_networks") do
        Cap::ConfigureNetworks
      end
    end
  end
end
