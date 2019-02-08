#!/bin/bash

# add build group and jenkins user
groupadd build
useradd -p `perl -e 'print crypt("password", "salt"),"\n"'` -g build jenkins -s /bin/bash
usermod -G sudo -a jenkins
echo "jenkins ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# install jenkins and git
export DEBIAN_FRONTEND=noninteractive
wget -q -O - https://pkg.jenkins.io/debian-stable/jenkins.io.key | sudo apt-key add -
sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'
apt update
apt install -y default-jre git
apt install -y jenkins
/etc/init.d/jenkins stop

# clone buildmt repo
mkdir temp-git
git clone https://github.com/xtuml/buildmt.git --branch master --depth 1 temp-git
mv temp-git/* .
mv temp-git/.[!.]* .
rm -rf temp-git
git config core.sharedRepository group

# set jenkins user home dir
usermod -d $PWD/buildmt/jenkins-home jenkins

# modify jenkins home
TMPFILE=`mktemp`
sed '@^JENKINS_HOME=.*jenkins-home@b; s@^JENKINS_HOME=.*$@JENKINS_HOME='$PWD'/buildmt/jenkins-home@g' /etc/default/jenkins > $TMPFILE
cp $TMPFILE /etc/default/jenkins
sed -r '@^DAEMON_ARGS=.*umask@b; s@^DAEMON_ARGS="(.*)"@DAEMON_ARGS="\1 --umask=002"@g' /etc/init.d/jenkins > $TMPFILE
cp $TMPFILE /etc/init.d/jenkins

# put in place git update script
sed -r '@update-git.sh@b; s@(^.*)(\$SU -l \$JENKINS_USER.*i)@\1$SU -l $JENKINS_USER --shell=/bin/bash -c "bash '$PWD'/update-git.sh" || return 2\n\1\2@g' /etc/init.d/jenkins > $TMPFILE
cp $TMPFILE /etc/init.d/jenkins
systemctl daemon-reload

# fixup permissions
chmod -R g+rw .
chown -R jenkins:build .
echo "umask 002" >> /etc/profile

# run setup
su jenkins -c 'bash buildmt/setup.sh'

# restart jenkins
/etc/init.d/jenkins restart
