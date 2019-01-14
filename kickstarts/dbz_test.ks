#version=DEVEL
install
text

url --url=$tree
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

bootloader --location=mbr --driveorder=sda --append="panic=10"
zerombr
clearpart --drives=sda --all --initlabel
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

### ntp.conf config (per Travis)

cat > /etc/ntp.conf <<EOF
# For more information about this file, see the man pages
# ntp.conf(5), ntp_acc(5), ntp_auth(5), ntp_clock(5), ntp_misc(5), ntp_mon(5).

driftfile /var/lib/ntp/drift

# Permit time synchronization with our time source, but do not
# permit the source to query or modify the service on this system.
restrict default kod nomodify notrap nopeer noquery
restrict -6 default kod nomodify notrap nopeer noquery

# Permit all access over the loopback interface.  This could
# be tightened as well, but to do so would effect some of
# the administrative functions.
restrict 127.0.0.1
restrict -6 ::1

# Use public servers from the pool.ntp.org project.
# Please consider joining the pool (http://www.pool.ntp.org/join.html).
server  time1.tsi.lan
server  time2.tsi.lan

# Enable public key cryptography.
#crypto

includefile /etc/ntp/crypto/pw

# Key file containing the keys and key identifiers used when operating
# with symmetric key cryptography.
keys /etc/ntp/keys
EOF
chmod 644 /etc/ntp.conf

#### Install VMware Tools if host is type "VMware"

$SNIPPET('tableau/vmware_tools_install')

$SNIPPET('kickstart_done')
%end
