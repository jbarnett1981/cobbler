## kickstart for centos7.0 2 disks LVM server
## jbarnett@tableausoftware.com @ `10/19/2015 10:00`
# Install options
install
eula --agreed
text
url --url=$tree
lang en_US.UTF-8
keyboard us
%include /tmp/hostname
rootpw --iscrypted $1$fxk/CP04$AXhdn0bZAqCaibnHwi0dy1
firewall --disabled --service=ssh
selinux --disabled
authconfig --enableshadow --enablemd5
timezone --utc America/Los_Angeles
skipx
reboot
services --disabled atd,autofs,avahi-daemon,bluetooth,cups,fcoe,haldaemon,ip6tables,iptables,iscsi,iscsid,jexec,livesys-late,lldapd,messagebus,netfs,nfslock,openct,pcscd,rpcbind,rpcidmapd
services --enabled=NetworkManager,sshd

bootloader --location=mbr --driveorder=sda --append="crashkernel=auto quiet selinux=0"
clearpart --initlabel --drives=sda,sdb --all
zerombr

part /boot --fstype=ext4 --size=250 --ondisk=sda
part pv.01 --fstype=lvmpv --asprimary --grow --size=1 --ondisk=sda
part pv.02 --fstype=lvmpv --asprimary --grow --size=1 --ondisk=sdb

volgroup vg00 --pesize=4096 pv.01
logvol swap --fstype=swap --name=lv_swap --vgname=vg00 --grow --size=2048 --maxsize=2048
logvol / --fstype=ext4 --name=lv_root --vgname=vg00 --grow --size=1

volgroup vg01 --pesize=4096 pv.02
logvol /data --fstype=ext4 --name=lv_data --vgname=vg01 --grow --size=1

%pre
$SNIPPET('pre_anamon')
$SNIPPET('kickstart_start')
#!/bin/sh

cd /tmp/

wget https://bootstrap.pypa.io/get-pip.py
/usr/bin/python get-pip.py
/usr/bin/pip install pymysql==0.6.3

wget http://puppetshare.dev.tsi.lan/scripts/get_host_info.py

HOSTNAME=`/usr/bin/python get_host_info.py --get_hostname`
DOMAIN=`/usr/bin/python get_host_info.py --get_domainname`

echo "network --onboot=yes --device=em1 --mtu=1500 --noipv6 --bootproto=dhcp --hostname $HOSTNAME" > /tmp/hostname
echo "$DOMAIN" > /tmp/domain
echo "$HOSTNAME"."$DOMAIN" > /tmp/hostnamefqdn

%end

%packages
@core
%end

# %post --nochroot
# cp /tmp/domain /mnt/sysimage/tmp/
# %end

%post --nochroot
FQDN=$(cat /tmp/hostnamefqdn)
hostnamectl set-hostname $FQDN
hostnamectl --pretty set-hostname $FQDN
cp /etc/hostname /mnt/sysimage/etc/hostname
cp /etc/machine-info /mnt/sysimage/etc/machine-info
%end

%post
cd /tmp
curl -O -k https://$server/bits/post_install_scripts/post_install.sh
bash /tmp/post_install.sh

$SNIPPET('kickstart_done')
%end
