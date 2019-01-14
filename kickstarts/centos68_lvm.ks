## kickstart for centos6.8 LVM disk LVM server
## jbarnett@tableausoftware.com @ `06/13/2016 09:08`
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
clearpart --initlabel --drives=sda --all
zerombr

part /boot --fstype=ext4 --size=500 --ondisk=sda
part pv.01 --asprimary --grow --size=1 --ondisk=sda

volgroup vg00 --pesize=4096 pv.01
logvol swap --name=lv_swap --vgname=vg00 --grow --size=8192 --maxsize=8192
logvol / --fstype=ext4 --name=lv_root --vgname=vg00 --grow --size=1

%pre
$SNIPPET('pre_anamon')
$SNIPPET('kickstart_start')
%end

%packages --nobase
@Core
binutils
make
python
sudo
vim-minimal
which
-indexhtml
%end

%post
cd /tmp
curl -O -k https://$server/bits/post_install_scripts/post_install.sh
bash /tmp/post_install.sh

$SNIPPET('kickstart_done')
%end