#!/bin/bash

#V1.3

# Check which package is supported & install required packages
DPKG=$(type -p dpkg) 
RPM=$(type -p rpm)

# ABSDIR is the absolute path where the installer is placed.
ABSDIR="$(dirname $(readlink -f $0))"
ABSDIR=$ABSDIR/nix

JAVABIN="$(type -p java)"
WORKDIR="/usr/share/java/nix"
NIXSERVICEFILE_D="/lib/systemd/system/nix.service"
NIXROBOTSERVICEFILE_D="/lib/systemd/system/nixr.service"
NIXJARFILE_D="$WORKDIR/nix.jar"
NIXROBOTJARFILE_D="$WORKDIR/nixr.jar"
NIXEVEFILE=/usr/share/java/nix/nix.eve


# Add Keystore File

addKeyStore() {
	if [ ! -f "$WORKDIR/nix.keystore" ]; then
		cp $ABSDIR/nix.keystore $WORKDIR/
	fi
}

addKeyStore

installDPKGs() {

	# Installing DEB Dependency Packages
	REQUIRED_PKG_SSH="openssh-server"
	SSH_PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG_SSH|grep "install ok installed")
	if [ "" = "$SSH_PKG_OK" ]; then
		apt-get --yes install $REQUIRED_PKG_SSH
	fi
	
	REQUIRED_PKG_WMCTRL="wmctrl"
	WMCTRL_PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG_WMCTRL|grep "install ok installed")
	if [ "" = "$WMCTRL_PKG_OK" ]; then
		apt-get --yes install $REQUIRED_PKG_WMCTRL
	fi
	  #For USB Enc
 	REQUIRED_PKG_CRYPTSETUP="cryptsetup"
	CRYPTSETUP_PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG_CRYPTSETUP|grep "install ok installed")
	if [ "" = "$CRYPTSETUP_PKG_OK" ]; then
		apt-get --yes install $REQUIRED_PKG_CRYPTSETUP
	fi
}

installRPMPKGs() {

	# Installing RPM Dependency Packages
	yum install -y openssh-server
	systemctl enable sshd --now
	yum install -y ca-certificates
	update-ca-trust force-enable
	yum install -y wmctrl
	yum install -y cryptsetup
}

if [ ! -z  $DPKG ]; then
  installDPKGs
elif [ ! -z  $RPM ]; then
  installRPMPKGs
fi

if [ ! -d "/usr/share/java/nix/lib" ]; then
    mkdir /usr/share/java/nix/lib
    chmod -R 0750 /usr/share/java/nix/lib
    chown root:root /usr/share/java/nix/lib
fi

updateServiceFileData() {

	STARTCMD="$JAVABIN -Djava.library.path=$WORKDIR/lib -jar $NIXJARFILE_D"
	STARTCMD=$(echo "$STARTCMD" | sed 's/\//\\\//g')
	NIX_SERVICESTATUS=$(cat "$NIXSERVICEFILE_D" | grep Djava.library.path)
	if [ -z "$NIX_SERVICESTATUS" ]; then
		sed -i "/ExecStart/c\ExecStart=$STARTCMD" $NIXSERVICEFILE_D
	fi

	STARTROBOTCMD="$JAVABIN -Djava.library.path=$WORKDIR/lib -jar $NIXROBOTJARFILE_D"
	STARTROBOTCMD=$(echo "$STARTROBOTCMD" | sed 's/\//\\\//g')
	NIXR_SERVICESTATUS=$(cat "$NIXROBOTSERVICEFILE_D" | grep Djava.library.path)
	if [ -z "$NIXR_SERVICESTATUS" ]; then
		sed -i "/ExecStart/c\ExecStart=$STARTROBOTCMD" $NIXROBOTSERVICEFILE_D
	fi
}

updateServiceFileData

cp $ABSDIR/app/*.jar /usr/share/java/nix/
cp $ABSDIR/app/lib/* /usr/share/java/nix/lib/

updateLatestAppStore() {

	# Removing Older AppStore
	rm -f /usr/share/java/nix/electron.png
	rm -f /usr/share/java/nix/Appstore.AppImage
	
	cp $ABSDIR/electron.png /usr/share/java/nix/
	cp $ABSDIR/Appstore.AppImage /usr/share/java/nix/
	cp $ABSDIR/Appstore.AppImage /opt
	
	chmod 700 /usr/share/java/nix/electron.png
	chmod 700 /usr/share/java/nix/Appstore.AppImage
	chmod 700 /opt/Appstore.AppImage
}

updateConfFile() {
	USE_UUID_STATUS=$(cat "$WORKDIR/nix.conf" | grep use_uuid)
	if [ -z "$USE_UUID_STATUS" ]; then
		sed -i '/^device_name_type.*/a use_uuid=' $WORKDIR/nix.conf
	fi
}

addEnvironmentFile() {
	
	# Removing Surelock jar
	
	rm /usr/share/java/nix/surelock.jar

	#update nix.eve file

	cp $ABSDIR/bootstrap/nix.eve /usr/share/java/nix/

	# Write ENV File
	UUID1=$(uuidgen)
	UUID2=$(uuidgen)

	VAL1=$(echo $UUID1 | base64)
	VAL2=$(echo $UUID2 | base64)

	sed -i "s/\("CYPHER_KEY_RUNTIME" * = *\).*\$/\1 $VAL1/" $NIXEVEFILE
	sed -i "s/\("CYPHER_VECTOR_RUNTIME" * = *\).*\$/\1 $VAL2/" $NIXEVEFILE

	#make change in service file of newly added nix.ene file

	NIXSERVICEFILE_D=/usr/lib/systemd/system/nix.service

	NIXROBOTSERVICEFILE_D=/usr/lib/systemd/system/nixr.service

	NixServiceEnv=$(grep 'EnvironmentFile' NIXSERVICEFILE_D | grep cut -f1 -d: )

	NixRServiceEnv=$(grep 'EnvironmentFile' NIXROBOTSERVICEFILE_D | grep cut -f1 -d: )

	if [ -z "$NixServiceEnv" ]
	then
		echo "$NixServiceEnv not having envorinment file path"
		sed -i '/WorkingDirectory=/a EnvironmentFile='$NIXEVEFILE $NIXSERVICEFILE_D
	else
		echo "$NixServiceEnv having envorinment file path"
	fi

	if [ -z "$NixRServiceEnv" ]
	then
		echo "$NixRServiceEnv not having envorinment file path"
		sed -i '/WorkingDirectory=/a EnvironmentFile='$NIXEVEFILE $NIXROBOTSERVICEFILE_D
	else
		echo "$NixRServiceEnv having envorinment file path"
	fi
}

updateEnvironmentFile() {
	DEVICE_UUID_STATUS=$(cat "$WORKDIR/nix.eve" | grep DEVICE_UUID)
	if [ -z "$DEVICE_UUID_STATUS" ]; then
		sed -i -e '$aDEVICE_UUID =' $WORKDIR/nix.eve
	fi
}

reloadService() {
	systemctl daemon-reload
	systemctl enable nix.service
	systemctl enable nixr.service
}

updateLatestAppStore

if [ ! -f "$NIXEVEFILE" ]; then
    echo "Adding Environment Variable File Path to Services"
    addEnvironmentFile
    echo "Service File Updated"
fi

updateConfFile
updateEnvironmentFile
reloadService

sleep 5 && service nixr restart && service nix restart &

echo "Internal Upgrade Complete"
