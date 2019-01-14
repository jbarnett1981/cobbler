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

bootloader --location=mbr --driveorder=sda --append="crashkernel=auto quiet"
clearpart --initlabel --drives=sda,sdb --all
zerombr

part /boot --fstype=ext4 --size=500 --ondisk=sda
part pv.01 --asprimary --grow --size=1 --ondisk=sda
part pv.02 --asprimary --grow --size=1 --ondisk=sdb

volgroup vg00 --pesize=4096 pv.01
logvol / --fstype=ext4 --name=lv_root --vgname=vg00 --grow --size=1

volgroup vg01 --pesize=4096 pv.02
logvol /data --fstype=ext4 --name=lv_data --vgname=vg01 --grow --size=1

%pre
$SNIPPET('pre_anamon')
$SNIPPET('kickstart_start')
%end

%packages
@core
%end

%post
cd /tmp
curl -O -k https://cobbler.dev.tsi.lan/bits/post_install_scripts/post_install_no_devtools.sh
bash /tmp/post_install_no_devtools.sh
$SNIPPET('kickstart_done')
%end
