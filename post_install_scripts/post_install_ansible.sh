### Tableau post config

# Register with RHN and enable repos if Red Hat detected system
swtype=$(awk '{print $1 " " $2}' /etc/redhat-release)
if [[ $swtype == "Red Hat" ]]; then
/usr/sbin/subscription-manager register --username=devit-tableau --password=P@ssw0rd! --auto-attach --force
fi

# Add it and devlocal user and set passwd
/usr/sbin/useradd -p '$1$dXpBbMXn$bbe9bdyuZK6X8p6qrQOGb.' -G wheel,adm,systemd-journal it
/usr/sbin/useradd -p '$1$vSaIsmF4$9EruGmdayNV/iWvD6dJhm/' -G adm devlocal

# # Create DevIT dir
# mkdir -p /usr/local/devit
# chmod 775 /usr/local/devit
# chown it:root /usr/local/devit

# Tell NetworkManager to STEP OFF of resolv.conf, we got dis
echo 'dns=none' >> /etc/NetworkManager/NetworkManager.conf

# disable network manager for loopback device
echo 'NM_CONTROLLED=no' >> /etc/sysconfig/network-scripts/ifcfg-lo

# add dev.tsi.lan DNS to interface
echo 'DNS1=10.26.128.10' >> /etc/sysconfig/network-scripts/ifcfg-em1

# Enable network manager wait online
systemctl enable NetworkManager-wait-online.service

# Configure resolv.conf
cat > /etc/resolv.conf <<EOF
search tsi.lan dev.tsi.lan tableaucorp.com db.tsi.lan test.tsi.lan
nameserver 10.26.160.31
nameserver 10.26.160.32
EOF
chmod 644 /etc/resolv.conf

# Install git
yum -y install git

# Install git repo for devit
# cd /tmp
# /usr/bin/git clone https://devit-admin:1xKAWF6mm6@gitlab.tableausoftware.com/devit/linux.git
# rm linux/imaging/packer*
# mv linux/imaging/* /usr/local/devit
# chmod +x /usr/local/devit/*
# chown it:root /usr/local/devit/*
# rm -rf linux

# Fix broken CentOS lvm2 package
yum -y upgrade lvm2

# Install required tools
yum -y install net-tools openssh-server nfs-utils samba-client samba-common cifs-utils wget perl zip redhat-lsb-core bind-utils tree

# Replace sudoers file
# curl -o /etc/sudoers http://puppetshare.dev.tsi.lan/sudoers/centos.sudoers
cat > /etc/sudoers.d/tableau-devit <<EOF
# Tableau DevIT Managed
# Allow zabbix user to restart puppet agent
zabbix ALL=NOPASSWD: /etc/init.d/puppet restart

# Allow following accounts full admin with no password prompt
builder  ALL=(ALL)  NOPASSWD: ALL

# Allow following groups full admin with password prompt
%devit  ALL=(ALL)   NOPASSWD: ALL
%development    ALL=(ALL)       ALL
EOF
sudo chmod 644 /etc/sudoers.d/tableau-devit

# Install EPEL repo
swver=$(lsb_release -r | awk '{print $2}')
if [[ $swver == 6.* ]]; then
    wget -O /tmp/epel.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
else
    wget -O /tmp/epel.rpm https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
fi
yum -y install /tmp/epel.rpm

yum -y install htop screen yum-utils mlocate gcc

# Add devit dir to system path
# echo 'PATH=$PATH:/usr/local/devit' >> /etc/profile
# echo 'export PATH' >> /etc/profile

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

### Configure Sendmail to use our relays
sed -i 's/^DS$/DSsmarthost.tsi.lan/' /etc/mail/sendmail.cf

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
syslocation Tableau DevIT, Internap
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

/bin/cp -f /etc/issue /etc/issue.net

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
# Disable ipv6
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1

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
chmod 644 /etc/cron.allow /etc/cron.deny
chmod 0400 /etc/crontab

#### Configure sshd
cat >> /etc/ssh/sshd_config <<EOF
PermitRootLogin yes
UsePrivilegeSeparation yes
ClientAliveInterval 300
Banner /etc/issue
EOF

### Configure Manufacturer variable
hwtype=$(dmesg | grep "DMI:" | awk '{print $4}')

#### Install Latest Dell OMSA if host is type "Dell"
if [[ $hwtype = *"Dell"* ]]; then
wget -q -O - http://linux.dell.com/repo/hardware/latest/bootstrap.cgi | bash
yum -y install syscfg srvadmin-all
fi

#### Install VMware Tools if host is type "VMware"

if [[ $hwtype = *"VMware"* ]]; then
# Vmware Virtual Machine
yum -y install open-vm-tools
fi

# convert cli parameters to descriptive vars
server_class=$1
vault_pass=$2
switchname=$3
switchinterface=$4

# Copy private key to /tmp for passwordless git/ansible-pull
cat >> /tmp/gitkey <<EOF
-----BEGIN RSA PRIVATE KEY-----
MIIEowIBAAKCAQEAv+BnmpqeiMsbMUJ2IB7ZlTidz2Jck/D5+ZK+1U9ahVLsKs63
zYz+5nuitEX1fVvhTyfEMZBlD1LR3bT4glsPPMyHlJL58sRf5t2SP1V4TlJ4IwmE
wVjFrRs8oWdiyGxuK1D10V1VASCSO4GQuvJbNOODeUZFun/xhqgS0AlCAvPtXmOt
i98OMSFi0GPahrOxw7Y6LFdoDES1ZYPDB98gyyZoZQ72SSiHbth8uRIMIQQOk+Ul
Ts7X9zKMIR/n2kqV+gJtmxJ/bNTmdkcvxvsS2WCQj0Sy9IraB/cSAtWozVKwIK1K
JjQd4vrnvM0O37GYAVXCE+p7wmY3ibbmOlSiyQIDAQABAoIBAQCwCZMj/d2bRTSC
giZcG9GmHRZz8Rtcw8akGeUpUS+MiGKSd6ucU1J9ZUsGN/UdeRGCjMpsary9TU+s
J9+jwSV+s2tkfWACQfZ2miwWHTVOLk14X8BDn01lH0sGDhNMLGb7KMEOv6FAcoCX
RaziR340TNQPjNBmZgHSeBsicIv2pfwIJF05FINRvw2RQB4+ZU4N1LqadHZ+tpWs
0Y9vFERK5taEVywMSe3tD+1HXrFg3OzDPcfCTc30QTRp82x+fxZO5IpiM2BvogMq
kBCQHyxpznPRNcBeFpjSgDUEdpNy6xLV3Y31w1M8YEScwNqUMXt0zqCal2NqF6yd
REwJas79AoGBAOJ613Pm+QrIyRZR51Fp4e9ziIuBoobCf7lPfpoq1XNmRLn81JWR
hcIW0rtNUG0z94ifLEHrYQnPLwySqbFly0ZzfZW9hxgBP8Ef8Y2Ol3C/p+uhq6Nw
6G3NJcrUw3EWG7vO9vK1LY1l718UgiB/Zw8H5l7PCRoWvl0RUwPRDJ2DAoGBANji
7KjUtXUStqA08Oqeg4KLtKTShQUbaFP2WLGYZJXOUmNcZ+YkSXljJxH7pe0DZEz4
haFdVXV8c2dTVQfqPGtiJXu9R/OWIbaSaLYxL7V1yhOiAUxdgvadqtZ1wCFkBJMY
jTWIPc2gGbY8SWsUEOwF8IIGgpJxtWghlvmYbDjDAoGALfVFkVR2hxS1kZzvNtso
qQGl3MFirLv9VSpng3tbsz42hhNjRDKylO8ytiV7Q52/Bm9eeMX9/BKZ9pAwdTo1
5Mb83g0Gw/1E5bjIuLQN0ShjN/KntNPtppJxr9Y7DtCwsgzOmfPgGYhs6btsqJGR
5T/yJJ0YuL2SxaoFUYnzaGcCgYArj7Bu3IIxqHeLx/ZXeUz6rGq07B+Rfga/TmxU
B0K0oAMGN+oaXFFxkwum3f9ekl7T4tqcJW3jsgJPz3n1pANMoiLbLpJEB3RwAgoM
BecKMEVNGi3ek62ZMOO+PVpAmqEclkLObLXVFgH0CznHyvj3Ht5Gj14sYbBI4O48
5XNfFwKBgCMmU1mawoysswNlHYkDPBRYU11aidOa3wzXlNivi8ylIac/Au5VhP7+
6ifHDJdSD7ht+TYaKvIKo+lePdf/vkCEigjXLgnViEXMMkxYW/LsljAL68YUvI/+
BOr4tX0xR1rbQ+gkh4iIATaAa/EhM4DyAXgz1SeMM79iQGsZHSL7
-----END RSA PRIVATE KEY-----
EOF
chmod 600 /tmp/gitkey

# Install ansible and dependent tools
cat >> /tmp/ansible-setup.sh <<EOF
#!/bin/bash
(
cd /tmp
yum -y install python-devel gcc libffi-devel openssl-devel
wget https://bootstrap.pypa.io/get-pip.py
/usr/bin/python get-pip.py
/bin/pip install ansible==2.1.1.0
/bin/pip install zabbix-api==0.4
/bin/pip install xmltodict==0.10.2
/bin/pip install requests==2.10.0
/bin/pip install -U setuptools==25.1.2

### Set env vars and download ansible playbook and run it
# Download server class definitions
git clone https://gitlab.tableausoftware.com/devit/ServerClasses.git

# If server_class variable not set, or does not match existing definitions, default to TempServer.yml
if [ ! -f /tmp/ServerClasses/$server_class.yml ]; then export server_class="TempServer"; fi

echo -e "[${server_class}]\nlocalhost" > /tmp/hosts
echo $vault_pass > /tmp/vault_pass
ansible-pull --purge --accept-host-key -i /tmp/hosts --vault-password-file /tmp/vault_pass --private-key /tmp/gitkey -U git@gitlab.tableausoftware.com:devit/ansible-playbooks.git -d /root/ansible-playbook -e "switchname=$switchname switchinterface=$switchinterface" -e "@/tmp/ServerClasses/$server_class.yml"

# Remove cron job after run
rm -f /etc/cron.d/ansible-setup
/sbin/reboot
) 2>&1 | tee /root/ansible-first-boot.log
EOF
chmod u+x /tmp/ansible-setup.sh

# Add ansible-setup to cron and execute on reboot
echo "@reboot root sleep 120 && bash /tmp/ansible-setup.sh" >> /etc/cron.d/ansible-setup
chmod 644 /etc/cron.d/ansible-setup

#### Install Corp Root CA
curl -o /tmp/cert.crt http://pki.tableaucorp.com/aia/1NDCITVWPKI11.tsi.lan_CorpIT%20Issuing%20CA.crt
openssl x509 -inform der -in /tmp/cert.crt -out /tmp/tableau_corp_root_ca.pem
cp /tmp/tableau_corp_root_ca.pem /etc/pki/ca-trust/source/anchors/
update-ca-trust

# Update system to current
yum update -y

# Update GRUB2 config
echo 'GRUB_TERMINAL=serial' >> /etc/default/grub
echo 'GRUB_SERIAL_COMMAND="serial —speed=57600 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub

### System cleanup

# Remove external repos, as we're managing this internally
# rm -f /etc/yum.repos.d/CentOS-*
rm -f /root/anaconda-ks.cfg

# Remove Red Hat Network bits from CentOS...
if [[ $swtype == *"CentOS"* ]]; then
yum -y remove rhnsd
fi

yum clean all
rm -f /var/log/wtmp /var/log/btmp
history -c

### Manifest - collect info about how the server was built

echo > ~/build.manifest
echo "Created on a platform of: `(uname -m)` ." >> ~/build.manifest
cat /etc/redhat-release >> ~/build.manifest
date >> ~/build.manifest
uname -a >> ~/build.manifest
echo -e "\n-----\nPackage listing:\n\n" >> ~/build.manifest
rpm -qa --qf "%{n}-%{v}-%{r}.%{arch}\n" | sort >> ~/build.manifest

# Delete yourself
rm -f $0