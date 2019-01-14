## kickstart for rhel6.6 1 disk LVM server
## jbarnett@tableausoftware.com @ `11/20/2015 02:45`
# Install options
install
text
url --url=$tree
lang en_US.UTF-8
keyboard us
network --onboot=yes --device=em1 --mtu=1500 --noipv6 --bootproto=dhcp
rootpw --iscrypted saEc3hETSoOp2
firewall --disabled --service=ssh
selinux --disabled
authconfig --enableshadow --enablemd5
timezone --utc America/Los_Angeles
skipx
reboot
services --disabled atd,autofs,avahi-daemon,bluetooth,cups,fcoe,haldaemon,ip6tables,iptables,iscsi,iscsid,jexec,livesys-late,lldapd,messagebus,netfs,nfslock,openct,pcscd,rpcbind,rpcidmapd

%include /tmp/partitioning.txt

%pre
$SNIPPET('pre_anamon')
$SNIPPET('kickstart_start')

$SNIPPET('disk_part')

%end

%post
cd /tmp
curl -O -k https://$server/bits/post_install_scripts/post_install.sh
bash /tmp/post_install.sh
$SNIPPET('kickstart_done')
%end
