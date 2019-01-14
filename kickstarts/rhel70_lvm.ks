## kickstart for rhel7
## jbarnett@tableausoftware.com @ `11/17/2014 01:00`
# Install options
install
eula --agreed
text
url --url=$tree
lang en_US.UTF-8
keyboard us
#network --onboot=yes --device=em1 --mtu=1500 --noipv6 --bootproto=dhcp
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

%include /tmp/partitioning.txt

%pre --log=/mnt/sysimage/root/ks-pre.log
$SNIPPET('pre_anamon')
$SNIPPET('kickstart_start')
#!/bin/sh

cd /tmp/

wget https://bootstrap.pypa.io/get-pip.py
/usr/bin/python get-pip.py
/usr/bin/pip install pymysql==0.6.3

wget http://puppetshare/scripts/get_host_info.py

HOSTNAME=`/usr/bin/python get_host_info.py --get_hostname`
DOMAIN=`/usr/bin/python get_host_info.py --get_domainname`

echo "network --onboot=yes --device=em1 --mtu=1500 --noipv6 --bootproto=dhcp --hostname $HOSTNAME" > /tmp/hostname
echo "$DOMAIN" > /tmp/domain
echo "$HOSTNAME"."$DOMAIN" > /tmp/hostnamefqdn

$SNIPPET('disk_part')

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
