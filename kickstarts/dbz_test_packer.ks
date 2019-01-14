#version=DEVEL
install
text

#url --url=$tree
url --url http://repo.tsi.lan/yum/centos/6/os/x86_64
lang en_US.UTF-8
keyboard us
network --onboot yes --device eth0 --bootproto dhcp
rootpw --iscrypted saEc3hETSoOp2
reboot
firewall --disabled  --service=ssh
authconfig --useshadow --enablemd5
selinux --disabled
skipx
timezone --utc America/Los_Angeles
services --disabled atd,autofs,avahi-daemon,bluetooth,cups,fcoe,haldaemon,ip6tables,iptables,iscsi,iscsid,jexec,livesys-late,lldapd,messagebus,netfs,nfslock,openct,pcscd,rpcbind,rpcidmapd

bootloader --location=mbr --driveorder=sda --append="panic=10 console=tty0 console=ttyS0,115200"
zerombr
#clearpart --drives=sda --all --initlabel
clearpart --drives=vda --all --initlabel
part /boot --fstype=ext4 --size=500 --asprimary --ondisk=sda
part / --fstype=ext4 --grow --size=3000 --asprimary --ondisk=sda
part swap --grow --maxsize=2016 --size=2016 --asprimary --ondisk=sda

%pre
$SNIPPET('pre_anamon')
$SNIPPET('kickstart_start')
%end

%packages --nobase
@Core
binutils
bind-utils
gcc
git
jwhois
kernel-devel
lsof
make
man
nc
nmap
ntp
patch
python
rsync
screen
sudo
sysstat
strace
system-config-network-tui
system-config-firewall
unzip
vconfig
vim-minimal
vim-enhanced
wget
which
zip

-indexhtml
%end

%post
/usr/sbin/useradd -p '$1$ztD2tcK7$sZ.ir0lAyUeKTdAdGW4tk/' dbadmin
echo "dbadmin    ALL=(ALL)       ALL" > /etc/sudoers.d/dbadmin

yum -y install dmidecode
#wget -O /root/vmware-tools.sh http://$server/repo/bits/vmware-tools.sh
#chmod +x /root/vmware-tools.sh
#/root/vmware-tools.sh

#Travis and Brose added this next bit on 9.5.14
#comment out if it breaks everything.

awk '!/HWADDR/' /etc/sysconfig/network-scripts/ifcfg-eth0 > /tmp/temp_eth0
awk '!/UUID/' /tmp/temp_eth0 > /etc/sysconfig/network-scripts/ifcfg-eth0
echo "
#!/bin/bash
stop() {
       rm -f /etc/udev/rules.d/70-persistent-net.rules
}
case \"\$1\" in
  stop)
        stop
        ;;
esac
" > /tmp/test1
chmod +x /etc/init.d/delrules
ln -s /etc/init.d/delrules /etc/rc0.d/S00delrules
ln -s /etc/init.d/delrules /etc/rc6.d/S00delrules
echo "touch /var/lock/subsys/delrules" >> /etc/rc.local
touch /var/lock/subsys/delrules

### Install packer SSH key
cd /root
mkdir --mode=700 .ssh
cat >> .ssh/authorized_keys << "PUBLIC_KEY"
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDOubNyUEaQRfo8U/Q0z2pQYsRLchSdMmE6nl+v6O57UPjLAPp9D9bZi3p/CA/gd/XFdVtn4ywcy4kyOJo9BHUUiMSXWdyAzRiTqSRt/kFtP7dmhkrz8KE5B+GiSWZ9/texp0fDTQW2UYuNXcg5C3qN60JNHpQkpSUKNq6Dy8Xy3gGhbZw388AesfJ1l5ZE54OXn1KQLItl4mAiYQ2m/eoYuMZY3zPblHU4lEed9/CBE0C2OXX3pGZV6xZDBhraqtmIHwKk/qv70LeLQ+2Mo+Nqt3EZk04iSZEucrJY6s3G++kyLw3Z1szt74TzgMMc6STgiQW5E5HTfmAYJ0HBpReV root@dvdemopl002
PUBLIC_KEY
chmod 600 .ssh/authorized_keys

$SNIPPET('kickstart_done')
%end
