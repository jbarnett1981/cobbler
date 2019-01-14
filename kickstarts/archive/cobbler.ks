## kickstart for cobbler server
## jbarnett@tableausoftware.com @ `07/30/2014 01:24`

# Install options
install
text
url --url http://repo.tsi.lan/yum/centos/6/os/x86_64/
lang en_US.UTF-8
keyboard us
#network --onboot=yes --device=eth0 --mtu=1500  --noipv6 --bootproto=static ip=10.26.129.136 --netmask=255.255.254.0 --gateway=10.26.128.1 --nameserver 10.26.160.31,10.26.160.32 --hostname=dvcobblerlv001.tsi.lan
network --onboot=yes --device=eth0 --mtu=1500 --noipv6 --bootproto=dhcp
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
logvol swap --name=lv_swap --vgname=vg00 --grow --size=4096 --maxsize=4096
logvol / --fstype=ext4 --name=lv_root --vgname=vg00 --grow --size=1

volgroup vg01 --pesize=4096 pv.02
logvol /var --fstype=ext4 --name=lv_var --vgname=vg01 --grow --size=1

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
### Turn on/off services
chkconfig ntpd on
chkconfig psacct on
chkconfig snmpd on
chkconfig iptables off
chkconfig ip6tables off
chkconfig sendmail off
chkconfig atd off

### Yum setup and update
echo "metadata_expire=1800" >> /etc/yum.conf
echo "installonlypkgs=kernel kernel*" >> /etc/yum.conf
rpm --import /etc/pki/rpm-gpg/*

### Update system to current
yum update -y
yum clean all
yum -y remove rhnsd
yum clean all

### base build is complete ###

#######################################################
### Tableau Custom Configurations ###

### resolv.conf
cat > /etc/resolv.conf <<EOF
search tsi.lan dev.tsi.lan
nameserver 10.26.160.32
nameserver 10.26.160.31
EOF
chmod 644 /etc/resolv.conf

### Enable sudo for members of the wheel group
sed -i '0,/# %wheel/s//%wheel/' /etc/sudoers

### Configure Sendmail to use our relays
sed -i 's/^DS$/DSsmarthost.tsi.lan/' /etc/mail/sendmail.cf

### Configure etc/snmpd
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
syslocation Tableau DevIT, Kirkland
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
sed -i 's/^exec/#exec/' /etc/init/control-alt-delete.conf

### Modify kernel parameters
### remove dumb progress bar at boot
### enable fifo disk writes
grubby --update-kernel=ALL --remove-args="rhgb"
grubby --update-kernel=ALL --args="elevator=noop"


### Add login banner
cat > /etc/issue <<EOF
*** WARNING ***

________________ __________.____     ___________   _____   ____ ___               
\__    ___/  _  \\______   \    |    \_   _____/  /  _  \ |    |   \              
  |    | /  /_\  \|    |  _/    |     |    __)_  /  /_\  \|    |   /              
  |    |/    |    \    |   \    |___  |        \/    |    \    |  /               
  |____|\____|__  /______  /_______ \/_______  /\____|__  /______/                
                \/       \/        \/        \/         \/                        
  _________________  ________________________      __  _____ _____________________
 /   _____/\_____  \ \_   _____/\__    ___/  \    /  \/  _  \\______   \_   _____/
 \_____  \  /   |   \ |    __)    |    |  \   \/\/   /  /_\  \|       _/|    __)_ 
 /        \/    |    \|     \     |    |   \        /    |    \    |   \|        \
/_______  /\_______  /\___  /     |____|    \__/\  /\____|__  /____|_  /_______  /
        \/         \/     \/                     \/         \/       \/        \/ 

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
PermitRootLogin no
UsePrivilegeSeparation yes
ClientAliveInterval 300
Banner /etc/issue
EOF

#### Install Puppet 3.5.1
rpm -Uvh http://yum.puppetlabs.com/puppetlabs-release-el-6.noarch.rpm
yum -y install puppet-3.5.1

cat > /etc/puppet/puppet.conf << EOF
[main]
server=puppet.dev.tsi.lan
pluginsync=true
autoflush=true
report=true
rundir = /var/run/puppet
EOF

chkconfig puppet on

#### Install Dell OMSA (14.10.00)
yum -y install net-snmp
if [ "`/usr/sbin/dmidecode -s system-manufacturer`" = "Dell Inc." ]
  then
        wget -q -O - http://linux.dell.com/repo/hardware/Linux_Repository_14.10.00/bootstrap.cgi | bash
        yum -y install srvadmin-all
fi

# Manifest - collect info about how the server was built

echo > /root/build.manifest
echo "Created with gitlab.ks" >> /root/build.manifest
echo "Created on a platform of: `(uname -m)` ." >> /root/build.manifest
cat /etc/redhat-release >> /root/build.manifest
date >> /root/build.manifest
uname -a >> /root/build.manifest
echo -e "\n-----\nPackage listing:\n\n" >> /root/build.manifest
rpm -qa --qf "%{n}-%{v}-%{r}.%{arch}\n" | sort >> /root/build.manifest
$SNIPPET('kickstart_done')
%end
