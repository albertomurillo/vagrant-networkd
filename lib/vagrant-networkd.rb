require "tempfile"

module VagrantPlugins
  module GuestNetworkd
    class Guest < Vagrant.plugin("2", :guest)
      def detect?(machine)
        machine.communicate.test("test -x /usr/bin/systemctl") and
        machine.communicate.test("test -d /etc/systemd/network")
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
        def self.mask_2_ciddr mask
          "/" + mask.split(".").map { |e| e.to_i.to_s(2).rjust(8, "0") }.join.count("1").to_s
        end

        def self.configure_networks(machine, networks)
          interfaces = Array.new
          cmd = 'ip addr | awk \'/: ./ && !/lo/ { sub(/:/, "", $2); print $2 }\''
          machine.communicate.sudo(cmd) do |_, result|
            interfaces = result.split("\n")
          end
          machine.communicate.sudo("rm -rf /etc/systemd/network/vagrant_*")
          # Replace en* (if any) with the first device (usually vbox nat)
          machine.communicate.sudo("sed -i 's/Name=en\\*$/Name=#{interfaces[0]}/g' /etc/systemd/network/*")
          networks.each do |network|
            network[:device] = interfaces[network[:interface]]
            configFile = "/etc/systemd/network/vagrant_#{network[:device]}.network"
            templateFile = File.expand_path("../../templates/network_#{network[:type]}.erb", __FILE__)
            template = File.read(templateFile)
            temp = Tempfile.new("vagrant")
            temp.binmode
            temp.write(Erubis::Eruby.new(template, :trim => true).result(binding))
            temp.close
            machine.communicate.upload(temp.path, "/tmp/vagrant_network")
            machine.communicate.sudo("mv /tmp/vagrant_network #{configFile}")
            machine.communicate.sudo("chown root:root #{configFile}")
            machine.communicate.sudo("chmod 644 #{configFile}")
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
