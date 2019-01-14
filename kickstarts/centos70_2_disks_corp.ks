## kickstart for centos7.0 2 disks non-LVM Dev Desktop
## jbarnett@tableausoftware.com @ `02/23/2016 09:47`
# Install options
install
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
services --disabled atd,autofs,avahi-daemon,bluetooth,cups,fcoe,haldaemon,ip6tables,iptables,iscsi,iscsid,jexec,livesys-late,lldapd,messagebus,netfs,nfslock,openct,pcscd,rpcbind,rpcidmapd,NetworkManager
services --enabled=sshd

bootloader --location=mbr --driveorder=sda --append="crashkernel=auto quiet selinux=0"
clearpart --initlabel --drives=sda,sdb --all
zerombr

part /boot --fstype=ext4 --size=250 --ondisk=sda
part swap --fstype=swap --grow --size=2048 --maxsize=2048
part / --fstype=ext4 --size=1 --grow --ondisk=sda
part /home --fstype=ext4 --size=1 --grow --ondisk=sdb

%pre
$SNIPPET('pre_anamon')
$SNIPPET('kickstart_start')

#!/bin/sh
cd /tmp/
echo "network --onboot=yes --device=eth0 --mtu=1500 --noipv6 --bootproto=dhcp --hostname $name" > /tmp/hostname

%end

%packages
@^Development and Creative Workstation
%end

%post
### Tableau post config

USER=devlocal
/usr/sbin/useradd -p $1$4KN4SX3e$t3QHrNnqrwEIexkuojXAk. \$USER

# Add devlocal to sudoers
echo "devlocal  ALL=(ALL)   ALL" >> /etc/sudoers

# Configure resolv.conf and disable PEERDNS
for i in /etc/sysconfig/network-scripts/ifcfg-*
do
 if [ "$i" != "/etc/sysconfig/network-scripts/ifcfg-lo" ]
        then
               echo PEERDNS=no >> $i; echo NM_CONTROLLED=no >> $i;
        fi
done
cat > /etc/resolv.conf <<EOF
search tsi.lan
nameserver 10.26.160.31
nameserver 10.26.160.32
EOF
chmod 644 /etc/resolv.conf

# Install required tools
yum -y install net-tools openssh-server nfs-utils git samba-client samba-common cifs-utils wget perl zip

# Install EPEL repo
swver=\$(lsb_release -r | awk '{print \$2}')
if [[ \$swver == 6.* ]]; then
    wget -O /tmp/epel.rpm https://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
else
    wget -O /tmp/epel.rpm https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
fi
yum -y install /tmp/epel.rpm
yum -y install htop screen yum-utils mlocate

# Install and start NTP
yum -y install ntp
systemctl start ntpd
systemctl enable ntpd

### Yum setup and update
echo "metadata_expire=1800" >> /etc/yum.conf
echo "installonlypkgs=kernel kernel*" >> /etc/yum.conf
#rpm --import /etc/pki/rpm-gpg/*

### base build is complete ###

#######################################################
### Tableau Custom Configurations ###

### Enable sudo for members of the wheel group
sed -i '0,/# %wheel/s//%wheel/' /etc/sudoers

### Configure Sendmail to use our relays
sed -i 's/^DS\$/DSsmarthost.tsi.lan/' /etc/mail/sendmail.cf

### Configure etc/snmpd
yum -y install net-snmp
cp /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.orig
cat > /etc/snmp/snmpd.conf <<EOF
com2sec local     localhost       public
com2sec mynetwork 10.0.0.0/8      public
group MyRWGroup v1         local
group MyRWGroup v2c        local
group MyRWGroup usm        local
group MyROGroup v1         mynetwork
group MyROGroup v2c        mynetwork
group MyROGroup usm        mynetwork
view all    included  .1                               80
access MyROGroup ""      any       noauth    exact  all    none   none
access MyRWGroup ""      any       noauth    exact  all    none   none
syslocation Tableau CorpIT
syscontact DevIT_Infrastructure <devit-inf@tableausoftware.com>
proc sshd
disk / 15%
load 8 8 8
EOF

### Configure sysconfig/snmpd
echo "OPTIONS=\"-LS0-5d -Lf /dev/null -p /var/run/snmpd.pid -a\"" >> /etc/sysconfig/snmpd

### Disable core dumps by default
echo "* soft core 0" >> /etc/security/limits.conf
echo "* hard core 0" >> /etc/security/limits.conf

### Disable Ctl-alt-del reboot
systemctl mask ctrl-alt-del.target

### Modify kernel parameters
### remove dumb progress bar at boot
### enable fifo disk writes
grubby --update-kernel=ALL --remove-args="rhgb"
grubby --update-kernel=ALL --args="elevator=noop"


### Add login banner
cat > /etc/issue <<EOF
*** WARNING ***

THIS IS A PRIVATE COMPUTER SYSTEM. It is for authorized use only.
Users (authorized or unauthorized) have no explicit or implicit
expectation of privacy. THERE IS NO RIGHT OF PRIVACY IN THIS SYSTEM.
System personnel may disclose any potential evidence of crime found
on computer systems for any reason.  USE OF THIS SYSTEM BY ANY USER,
AUTHORIZED OR UNAUTHORIZED, CONSTITUTES CONSENT TO THIS MONITORING,
INTERCEPTION, RECORDING, READING, COPYING, or CAPTURING and DISCLOSURE.

EOF
cp -f /etc/issue /etc/issue.net

### Protect root directory
chmod -R go-rwx /root

### Configure auth.* syslog channel
echo "auth.* /var/log/secure" >> /etc/syslog.conf

# Turn on reverse path filtering.
echo "net.ipv4.conf.all.rp_filter = 1" >> /etc/sysctl.conf
# Don't allow outsiders to alter the routing tables.
echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.conf
echo "net.ipv4.conf.all.secure_redirects = 0" >> /etc/sysctl.conf
# Don't reply to broadcasts.  Prevents joining a smurf attack.
echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" >> /etc/sysctl.conf
# Bump up TCP socket queue to help with syn floods.
echo "net.ipv4.tcp_max_syn_backlog = 4096" >> /etc/sysctl.conf

### Configure auditd
cp /etc/audit/auditd.conf /etc/audit/auditd.conf.orig
cat > /etc/audit/auditd.conf <<EOF
# This file controls the configuration of the audit daemon
log_file = /var/log/audit/audit.log
log_format = RAW
log_group = root
priority_boost = 4
flush = INCREMENTAL
freq = 20
num_logs = 5
disp_qos = lossy
dispatcher = /sbin/audispd
name_format = NONE
max_log_file = 10
max_log_file_action = ROTATE
space_left = 150
space_left_action = SYSLOG
action_mail_acct = root
admin_space_left = 80
admin_space_left_action = SUSPEND
disk_full_action = SUSPEND
disk_error_action = SUSPEND
tcp_listen_queue = 5
tcp_max_per_addr = 1
tcp_client_max_idle = 0
enable_krb5 = no
krb5_principal = auditd
EOF
cp /etc/audit/audit.rules /etc/audit/audit.rules.orig
cat > /etc/audit/audit.rules <<EOF
# This file contains the auditctl rules that are loaded
# whenever the audit daemon is started via the initscripts.
# The rules are simply the parameters that would be passed
# to auditctl.
# First rule - delete all
-D
# Increase the buffers to survive stress events.
# Make this bigger for busy systems
-b 8192
## Set failure mode to syslog.notice
-f 1
# Things that could affect time
-a exit,always -F arch=b64 -S adjtimex -S settimeofday -k time-change
-w /etc/localtime -p wa -k time-change
# Things that affect identity
-w /etc/group -p wa -k identity
-w /etc/passwd -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
# Things that could affect system locale
-a exit,always -F arch=b64 -S sethostname -S setdomainname -k system-locale
-w /etc/issue -p wa -k system-locale
-w /etc/issue.net -p wa -k system-locale
-w /etc/hosts -p wa -k system-locale
-w /etc/sysconfig/network -p wa -k system-locale
# Things that could affect MAC policy
-w /etc/selinux/ -p wa -k MAC-policy
# Discretinary access control permission modification (unsuccessful and successful use of chown/chomd)
-a exit,always -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=500 -F auid!=4294967295 -k perm_mod
-a exit,always -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=500 -F auid!=4294967295 -k perm_mod
-a exit,always -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>500 -F auid!=4294967295 -k perm_mod
# Unauthorized access attempts to files (only unsuccessful)
-a exit,always -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=500 -F auid!=4294967295 -k access
-a exit,always -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=500 -F auid!=4294967295 -k access
# Files deleted by the user (successful and unsuccessful)
-a exit,always -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=500 -F auid!=4294967295 -k delete
# Watch actions to sudoers
-w /etc/sudoers -p wa -k priv_actions
## Make rule changed immutable - reboot is required to change audit rules
-e 2
EOF

### Configure cron usage
echo "root" > /etc/cron.allow
echo "ALL" > /etc/cron.deny
chmod 0400 /etc/crontab

#### Configure sshd
cat >> /etc/ssh/sshd_config <<EOF
PermitRootLogin yes
UsePrivilegeSeparation yes
ClientAliveInterval 300
Banner /etc/issue
EOF

### Install and configure PBIS
cat >> /etc/yum.repos.d/pbis.repo <<EOF
[pbis]
name=PBISO- local packages for x86_64
baseurl=http://repo.pbis.beyondtrust.com/yum/pbiso/x86_64
enabled=1
gpgkey=http://repo.pbis.beyondtrust.com/yum/RPM-GPG-KEY-pbis
gpgcheck=1
EOF
yum -y install pbis-open

# Create PBIS domain join script
cat >> /tmp/pbis_domainjoin.sh <<'EOF'
#!/usr/bin/env bash
plymouth quit
# TSI.LAN domain join credentials
ADUSER='svc_domainjoin_devit'
ADPASS='Join2tsi.lan.Domain!'

# Joining tsi.lan
/opt/pbis/bin/domainjoin-cli join --ou "TSI Computers/Workstations/Dev Workstations" tsi.lan $ADUSER $ADPASS

# Configuring Domain Settings
/opt/pbis/bin/config AssumeDefaultDomain true 2>/dev/null
/opt/pbis/bin/config UserDomainPrefix tsi 2>/dev/null
/opt/pbis/bin/config LoginShellTemplate /bin/bash 2>/dev/null
/opt/pbis/bin/update-dns

# Updating DNS and adding to cron
cat >> /etc/cron.daily/dns << CRON
#!/bin/bash
sudo /opt/pbis/bin/update-dns
CRON
chmod u+x /etc/cron.daily/dns
/opt/pbis/bin/update-dns

# Remove unit file after run
/bin/systemctl disable pbis-domainjoin-rc.local.service
rm -f /etc/systemd/system/pbis-domainjoin-rc.local.service
rm -rf /tmp/*
/sbin/reboot
EOF
chmod u+x /tmp/pbis_domainjoin.sh

# Fix pbis broken / non-existing unit files for systemd
ln -s /etc/pbis/redhat/lwsmd.service /etc/systemd/system/lwsmd.service
/bin/cp /etc/pbis/redhat/lwsmd.service /lib/systemd/system/lwsmd.service
/bin/systemctl enable lwsmd.service

# Create pbis domain join unit file
cat >> /etc/systemd/system/pbis-domainjoin-rc.local.service <<EOF
[Unit]
Description=Add system to tsi.lan...
After=basic.target network.target lwsmd.service

[Service]
Type=oneshot
ExecStart=/tmp/pbis_domainjoin.sh

[Install]
WantedBy=multi-user.target
EOF
chmod 664 /etc/systemd/system/pbis-domainjoin-rc.local.service
/bin/systemctl enable pbis-domainjoin-rc.local.service

#### Install Puppet
cd /tmp
if [[ \$swver == 6.* ]]; then
    wget -O /tmp/puppetlabs-release.rpm http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm
else
    wget -O /tmp/puppetlabs-release.rpm http://yum.puppetlabs.com/puppetlabs-release-el-7.noarch.rpm
fi
yum -y install /tmp/puppetlabs-release.rpm
yum --enablerepo=puppetlabs-products -y install puppet

cat > /etc/puppet/puppet.conf <<EOF
[main]
server=puppet.dev.tsi.lan
pluginsync=true
autoflush=true
report=true
rundir = /var/run/puppet
EOF
chkconfig puppet on

# Boot to init 5 (GUI) by default
systemctl set-default graphical.target

# Update system to current
yum update -y

### System cleanup
# Remove Red Hat Network bits from CentOS...
if [[ \$swtype == *"CentOS"* ]]; then
yum -y remove rhnsd
fi

yum clean all
rm -f /var/log/wtmp /var/log/btmp
history -c

$SNIPPET('kickstart_done')
%end
