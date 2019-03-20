# -*- mode: ruby -*-
# vi: set ft=ruby :
Database={
    :name => "eventscase",
    :test => "phpunit_database",
    :admin => {
        :user => "root",
        :pwd => "123"
    }
}
EventsCase={
    :name => "eventscase",
    :vbox => {
        :box_image => "bento/debian-9.5",
        :cpu => "75",
        :ram => "512"
    },
    :host => {
        :name => "v-eventscase",
        :ip_address => "192.168.33.22",
        :domain => "eventscase.loc"
    },
    :user => "root",
    :synced_folder => "/media/websites",
    :synced_folder_origin => "eventscase",
    :project_subpath => "platform",
    :provision_dir => "vagrant-provision/eventscase"
}
Gearman={
    :name => "gearman",
    :vbox => {
        :box_image => "bento/debian-9.5",
        :cpu => "75",
        :ram => "512"
    },
    :host => {
        :name => "v-gearman",
        :ip_address => "192.168.33.66"
    },
    :user => "root",
    :synced_folder => "/home/eventscase",
    :synced_folder_origin => "gearman",
    :project_subpath => "gworkers",
    :provision_dir => "vagrant-provision/gearman"
}

Vagrant.configure("2") do |config|
    config.vm.define Gearman[:name] do |tools|
        tools.vbguest.auto_update = false
        tools.vm.box = Gearman[:vbox][:box_image]
        tools.vm.box_check_update = false
        tools.vm.hostname = Gearman[:host][:name]
        tools.vm.network "private_network", ip: Gearman[:host][:ip_address]
        tools.vm.synced_folder Gearman[:provision_dir], "/vagrant"
        tools.vm.synced_folder Gearman[:synced_folder_origin], Gearman[:synced_folder]

        tools.vm.provision :shell, inline: "apt-get -y update"
        tools.vm.provision :shell, inline: "DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" upgrade"
        tools.vm.provision :shell, path: "#{Gearman[:provision_dir]}/bootstrap.sh", env: {
            "SSH_USER" => Gearman[:user],
            "BASE_PATH" => Gearman[:synced_folder],
            "PROJECT_PATH" => "#{Gearman[:synced_folder]}/#{Gearman[:project_subpath]}",
            "PROVISION_PATH" => "/vagrant",
            "GEARMAN_HOST" => Gearman[:host][:name],
            "GEARMAN_IP" => Gearman[:host][:ip_address],
            "EVENTSCASE_HOST" => EventsCase[:host][:name],
            "EVENTSCASE_IP" => EventsCase[:host][:ip_address],
            "EVENTSCASE_DOMAIN" => EventsCase[:host][:domain],
            "DB_NAME" => Database[:name],
            "DB_TEST" => Database[:test],
            "DB_USER" => Database[:admin][:user],
            "DB_PASS" => Database[:admin][:pwd]
        }

        tools.vm.provider "virtualbox" do |vbox|
            vbox.customize ["modifyvm", :id, "--cpuexecutioncap", Gearman[:vbox][:cpu], "--memory", Gearman[:vbox][:ram], "--name", Gearman[:host][:name]]
        end
    end

    config.vm.define EventsCase[:name], primary: true do |tools|
        tools.vbguest.auto_update = false
        tools.vm.box = EventsCase[:vbox][:box_image]
        tools.vm.box_check_update = false
        tools.vm.hostname = EventsCase[:host][:name]
        tools.vm.network "private_network", ip: EventsCase[:host][:ip_address]
        tools.vm.synced_folder EventsCase[:provision_dir], "/vagrant"
        tools.vm.synced_folder EventsCase[:synced_folder_origin], EventsCase[:synced_folder], owner: "www-data", group: "www-data"

        tools.vm.provision :shell, inline: "apt-get -y update"
        tools.vm.provision :shell, inline: "DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\" upgrade"
        tools.vm.provision :shell, path: "#{EventsCase[:provision_dir]}/bootstrap.sh", env: {
            "SSH_USER" => EventsCase[:user],
            "BASE_PATH" => EventsCase[:synced_folder],
            "PROJECT_PATH" => "#{EventsCase[:synced_folder]}/#{EventsCase[:project_subpath]}",
            "PROVISION_PATH" => "/vagrant",
            "GEARMAN_HOST" => Gearman[:host][:name],
            "GEARMAN_IP" => Gearman[:host][:ip_address],
            "EVENTSCASE_HOST" => EventsCase[:host][:name],
            "EVENTSCASE_IP" => EventsCase[:host][:ip_address],
            "EVENTSCASE_DOMAIN" => EventsCase[:host][:domain],
            "DB_NAME" => Database[:name],
            "DB_TEST" => Database[:test],
            "DB_USER" => Database[:admin][:user],
            "DB_PASS" => Database[:admin][:pwd]
        }

        tools.vm.provider "virtualbox" do |vbox|
            vbox.customize ["modifyvm", :id, "--cpuexecutioncap", EventsCase[:vbox][:cpu], "--memory", EventsCase[:vbox][:ram], "--name", EventsCase[:host][:name]]
        end
    end
end
