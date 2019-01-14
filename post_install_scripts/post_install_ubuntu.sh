### Tableau post config

# Update default editor from nano to vi
update-alternatives --set editor /usr/bin/vim.basic

# apt-get update
sudo /usr/bin/apt-get update
sudo /usr/bin/apt-get upgrade
sudo /usr/bin/apt-get autoremove

# Configure hostname from Racktables
/usr/bin/apt-get -y install python-pip
/usr/bin/pip install pymysql==0.6.3
curl -k -o /tmp/get_host_info.py http://puppetshare.dev.tsi.lan/scripts/get_host_info.py
/usr/bin/python /tmp/get_host_info.py --get_hostname > /etc/hostname
/usr/bin/python /tmp/get_host_info.py --get_domain > /tmp/domain

# Allow root login from ssh
/bin/sed -i "s/PermitRootLogin.*/PermitRootLogin yes/g" /etc/ssh/sshd_config

# create user devlocal with password of P@ssw0rd!
/usr/sbin/useradd -m -d /home/devlocal -s /bin/bash -p '$1$bsVx7TxS$VuBulM.4dhVRAbD2ip/ws.' -G sudo,audio,cdrom,video devlocal
# create user it with password see keepass
/usr/sbin/useradd -m -d /home/it -s /bin/bash -p '$1$6982c48E$5Ap/qdWzYDGG.8fqsNSpz0' -G sudo,audio,cdrom,video it
# create directory /usr/local/devit
# /bin/mkdir /usr/local/devit
# modify directory /usr/local/devit
# /bin/chmod 775 /usr/local/devit
# /bin/chown it:root /usr/local/devit
# Create DevIT dir
# /bin/mkdir -p /usr/local/devit
# /bin/chmod 775 /usr/local/devit
# /bin/chown it:root /usr/local/devit

# Configure resolv.conf
/bin/cat >> /etc/resolvconf/resolv.conf.d/base <<EOF
search tsi.lan dev.tsi.lan tableaucorp.com dev.tsi.lan db.tsi.lan test.tsi.lan
nameserver 10.26.160.31
nameserver 10.26.160.32
EOF

/sbin/resolvconf -u

# Configure eth0 with DOMAIN parameter to pass to NetworkManager
# temp test
/bin/cp /etc/network/interfaces /etc/network/interfaces.bu

/bin/cat >> /etc/network/interfaces <<EOF
dns-nameservers 10.26.160.31 10.26.160.32
dns-search tsi.lan dev.tsi.lan tableaucorp.com dev.tsi.lan db.tsi.lan test.tsi.lan
EOF

# Install required tools
/usr/bin/apt-get install -y openssh-server build-essential nfs-common git smbclient cifs-utils wget sysv-rc-conf vim

# Install git repo for devit
# cd /tmp
# /usr/bin/git clone https://devit-admin:1xKAWF6mm6@gitlab.tableausoftware.com/devit/linux.git
# /bin/rm linux/imaging/packer*
# /bin/mv linux/imaging/* /usr/local/devit
# /bin/chmod +x /usr/local/devit/*
# /bin/chown it:root /usr/local/devit/*
# /bin/rm -rf linux

# Replace sudoers file
curl -o /etc/sudoers http://puppetshare.dev.tsi.lan/sudoers/ubuntu.sudoers

# Add devit dir to system path
# echo 'PATH=$PATH:/usr/local/devit' >> /etc/profile
# echo 'export PATH' >> /etc/profile



### base build is complete ###

#######################################################
### Tableau Custom Configurations ###

/usr/bin/apt-get install -y snmpd
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

## Configure sysconfig/snmpd
#echo "OPTIONS=\"-LS0-5d -Lf /dev/null -p /var/run/snmpd.pid -a\"" >> /etc/sysconfig/snmpd

### Disable core dumps by default
/bin/echo "* soft core 0" >> /etc/security/limits.conf
/bin/echo "* hard core 0" >> /etc/security/limits.conf

### Protect root directory
/bin/chmod -R go-rwx /root

### Configure Manufacturer variable
hwtype=$(dmesg | grep "DMI:" | awk '{print $4}')

#### Install Latest Dell OMSA if host is type "Dell"
if [[ $hwtype = *"Dell"* ]]; then

/bin/echo 'deb http://linux.dell.com/repo/community/ubuntu precise openmanage' | sudo tee -a /etc/apt/sources.list.d/linux.dell.com.sources.list
/usr/bin/gpg --keyserver pool.sks-keyservers.net --recv-key 1285491434D8786F
/usr/bin/gpg -a --export 1285491434D8786F | sudo apt-key add -
/usr/bin/apt-get update
/usr/bin/apt-get install -y srvadmin-all
fi

if [[ $hwtype = *"VMware"* ]]; then
# Vmware Virtual Machine
/usr/bin/apt-get install -y open-vm-tools
fi

### Install Puppet
wget https://apt.puppetlabs.com/puppetlabs-release-pc1-trusty.deb
dpkg -i puppetlabs-release-pc1-trusty.deb
/usr/bin/apt-get update
/usr/bin/apt-get install puppet-agent

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

### Configure /tmp cleanup for every 7 days (default every boot, which breaks startup scripts placed in this dir)
sed -i '/TMPTIME/c\TMPTIME=7' /etc/default/rcS

# Delete yourself
rm -f $0