#!/bin/bash

##
# (c) 2018 42Gears Mobility Systems Pvt Ltd. All Rights Reserved.
##

DQT='"'             # Single Quotes
RED='\033[0;31m'    # Red
GREEN='\033[0;32m'  # Green
PURPLE='\033[0;35m' # Purple
NC='\033[0m'        # No Color

CURLBIN="$(type -p curl)"
LSBLKBIN="$(type -p lsblk)"

installDPKGs () { 

  if [ -z "$CURLBIN" ]; then
    apt-get install curl -y > /dev/null;
  fi
  
 REQUIRED_PKG="libpam-pwquality"
 PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")
 if [ "" = "$PKG_OK" ]; then
  apt-get --yes install $REQUIRED_PKG
 fi

 REQUIRED_PKG_SSH="openssh-server"
 SSH_PKG_OK=$(dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG_SSH|grep "install ok installed")
 if [ "" = "$SSH_PKG_OK" ]; then
  apt-get --yes install $REQUIRED_PKG_SSH
 fi
 #For app analytics
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

installRPMPKGs () { 

  if [ -z "$CURLBIN" ]; then
    yum install curl -y > /dev/null;
  fi
  
  yum -q list installed libpwquality &>/dev/null && echo "" || yum install libpwquality -y

  yum install -y openssh-server

  systemctl enable sshd --now

  yum install -y ca-certificates

  update-ca-trust force-enable
# for app analytics
  yum install -y wmctrl
  
  yum install -y cryptsetup
}

echo -e "${PURPLE}SureMDM Nix Installer version 3.6.1${NC}"
# Installer should run as root in order to successfully install Nix Service
if [ "$EUID" -ne 0 ]
  then echo -e "${RED}Permission denied. Please run as root.${NC}"
  exit 126
fi

# ABSDIR is the absolute path where the installer is placed.
ABSDIR="$(dirname $(readlink -f $0))"

# Check if Java is installed.
JAVABIN="$(type -p java)"
if [ -z "$JAVABIN" ]; then
  echo -e "${RED}Java Not Found. Please Install JRE/JDK 1.7 or above and continue installation process.${NC}"
  exit 127
fi

# Execute Java Test Jar to verify it cn run Java 7
"$JAVABIN" -jar "$ABSDIR/pilot/probe.jar" > /dev/null 2>&1
if [ $? != 0 ]; then
    echo -e "${RED}Either Java 7 (or higher version of JRE) is not installed or not set as default Java.${NC}"
    exit 127
fi


# Check if this platfrom is supported
#if [ ! -z "type -p systemctl" ] && [ ! -d "/lib/systemd/system" ]; then
if [ ! -z `type -p systemctl` ]; then
  echo -e "${GREEN}Found systemd init system.${NC}"
elif [[ `/sbin/init --version` =~ upstart ]]; then
  echo -e "${GREEN}Found upstart init system.${NC}"
elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then
  echo -e "${GREEN}Found sysv init system.${NC}"
else
  echo -e "${RED}SureMDM Nix installer is not supported on your platfrom${NC}"
  exit 1
fi

# Check which package is supported & install required packages
DPKG=$(type -p dpkg) 
RPM=$(type -p rpm)

if [ ! -z  $DPKG ]; then
  installDPKGs
elif [ ! -z  $RPM ]; then
  installRPMPKGs
fi

# Check for Arguments
if [ ! -z "$1" ]; then
  # Arguments were passed. Parse each one.
  for ARGVAR in "$@"
  do
    case $ARGVAR in 
    -c*)
      CUSTOMERID=${ARGVAR#"-c"}
      echo -e "${GREEN}Customer Id  = "$CUSTOMERID"${NC}"
      ;;
    -s* )
      SERVERURL=${ARGVAR#"-s"}
      echo -e "${GREEN}SureMDM Server = "$SERVERURL"${NC}"
      ;;
    -g*)
      GROUP_PATH=${ARGVAR#"-g"}
      echo -e "${GREEN}Group Path  = "$GROUP_PATH"${NC}"
      ;;
    -p*)
      PASSWORD=${ARGVAR#"-p"}
      ;;
    -t*)
      Device_Name_Type=${ARGVAR#"-t"}
      if [ "$Device_Name_Type" == "1" ] || [ "$Device_Name_Type" == "2" ] || [ "$Device_Name_Type" == "3" ] || [ "$Device_Name_Type" == "4" ]; then
      	echo -e "${GREEN}Device Name Type  = "$Device_Name_Type"${NC}"
      fi
      ;;
    -d*)
      Device_Name=${ARGVAR#"-d"}
      if [ "$Device_Name_Type" == "3" ]; then
	      echo -e "${GREEN}Device Name = "$Device_Name"${NC}"
      fi
      ;;
    -e* )
      USEREMAIL=${ARGVAR#"-e"}
      echo -e "${GREEN}User Email = "$USEREMAIL"${NC}"
      ;;
    -n* )
      MDM_USER_NAME=${ARGVAR#"-n"}
      echo -e "${GREEN}User Name = "$MDM_USER_NAME"${NC}"
      ;;
    -u* )
      USE_UUID=${ARGVAR#"-u"}
      echo -e "${GREEN}Use UUID = "$USE_UUID"${NC}"
      ;;
    -y* )
      OVERWRITE="Yes"
      echo -e "${GREEN}Assuming YES for all prompts${NC}"
      ;;
    *)
      echo -e "${RED}Invalid Argument "$ARGVAR"${NC}"
      echo -e "${PURPLE}Usage: sudo ./installnix.sh [-c<customerid>] [-s<serverpath>] [-g<group_path>] [-p<password>] [-t<device_name_type>] [-d<device_name>] [-u<use_uuid>] [-y]${NC}"
      exit 1
      ;;
    esac
  done
fi

# Automatically detect SAAS server path
if [ ! -z "$CUSTOMERID" ] && [ "$CUSTOMERID" != "1" ] && [ -z "$SERVERURL" ]; then
  SERVERURL="https://suremdm.42gears.com"
  echo -e "${GREEN}Assuming SureMDM Server = "$SERVERURL"${NC}"
fi

# Parse Server URL passed as parameters
if [ ! -z "$SERVERURL" ]; then
  case $SERVERURL in 
  http://*)
    SERVER=${SERVERURL#"http://"}
    SERVER=${SERVER%"/"}
    echo -e "${GREEN}Server = "$SERVER"${NC}"
    ;;
  https://* )
    SERVER=${SERVERURL#"https://"}
    SERVER=${SERVER%"/"}
    echo -e "${GREEN}Server = "$SERVER"${NC}"
    ;;
  *)
    echo -e "${RED}Invalid Server Path "$SERVERURL"${NC}"
    echo -e "${PURPLE}Server Path should start from http:// or https://${NC}"
    exit 1
    ;;
  esac
fi

# Put Nix related files in an appropriate directory
WORKDIR="/usr/share/java"
if [ -d "$WORKDIR" ]; then
  echo -e "${GREEN}Nix files will be installed to $WORKDIR/nix${NC}"
else
  # Almost all machines have /usr/share/java. In case if its no there, use /opt/nix
  WORKDIR="/opt/nix"
  if [ ! -d "/opt/nix" ]; then
    mkdir -p "/opt/nix";
  fi

  if [ ! -d "/opt/nix" ]; then
    echo -e "${RED}$WORKDIR does not exist.${NC}"
    exit 1
  else
    echo -e "${GREEN}Nix files will be installed to $WORKDIR/nix${NC}"
  fi
fi

# Check if destination directory already exists
WORKDIR="$WORKDIR/nix"
if [ -d "$WORKDIR" ]; then

  if [ "$OVERWRITE" = "Yes" ]; then
    echo -e "${GREEN}Overwriting existing Nix installation${NC}"
  else
    echo -e "${PURPLE}Destination directory already exists.${NC}"
    read -p "Do you wish to overwrite existing nix? (y/n) : " yn
    case $yn in
      [Yy]* ) echo -e "${GREEN}Overwriting existing Nix installation${NC}";;
      [Nn]* ) exit 2;;
      * )     exit 2;;
    esac
  fi

else
  mkdir $WORKDIR
fi

#Recreate nix/lib folder
rm -rf $WORKDIR/lib
mkdir $WORKDIR/lib

# Fix permissions and ownership of nix directory
if [ -d "$WORKDIR" ]; then
  chmod -R 0750 $WORKDIR
  chown root:root $WORKDIR
else
  echo -e "${RED}Cannot create directory $WORKDIR.${NC}"
  exit 1
fi

# Fix permissions and ownership of nix/Lib directory
if [ -d "$WORKDIR/lib" ]; then
  chmod -R 0750 $WORKDIR/lib
  chown root:root $WORKDIR/lib
else
  echo -e "${RED}Cannot create directory $WORKDIR/lib.${NC}"
  exit 1
fi

SURELOCKDIR="/usr/share/Surelock"

if [ -d "$SURELOCKDIR" ]; then
  rm -r $SURELOCKDIR
fi

mkdir $SURELOCKDIR

# Prepare the list of file to be copied
NIXJARFILE_S="$ABSDIR/app/nix.jar"
NIXROBOTJARFILE_S="$ABSDIR/app/nixr.jar"
NIXLIBFILE_S="$ABSDIR/app/lib/*.jar"
NIXCONFIGFILE_S="$ABSDIR/app/nix.conf"
NIXEVEFILE_S="$ABSDIR/bootstrap/nix.eve"
NIXAPPIMGFILE_S="$ABSDIR/Appstore.AppImage"
NIXKEYSTOREFILE_S="$ABSDIR/nix.keystore"
NIXAPPICONFILE_S="$ABSDIR/electron.png"

NIXJARFILE_D="$WORKDIR/nix.jar"
NIXROBOTJARFILE_D="$WORKDIR/nixr.jar"
NIXLIBFILE_D="$WORKDIR/lib/"
NIXCONFIGFILE_D="$WORKDIR/nix.conf"
NIXDATAFILE_D="$WORKDIR/data"
NIXEVEFILE_D="$WORKDIR/nix.eve"
NIXAPPIMGFILE_D="$WORKDIR/Appstore.AppImage"
NIXKEYSTOREFILE_D="$WORKDIR/nix.keystore"
NIXAPPICONFILE_D="$WORKDIR/electron.png"

# Copy Files
cp $NIXJARFILE_S $NIXJARFILE_D
cp $NIXROBOTJARFILE_S $NIXROBOTJARFILE_D
cp $NIXLIBFILE_S $NIXLIBFILE_D
cp $NIXCONFIGFILE_S $NIXCONFIGFILE_D
cp $NIXAPPIMGFILE_S $NIXAPPIMGFILE_D
cp $NIXAPPICONFILE_S $NIXAPPICONFILE_D
cp $NIXKEYSTOREFILE_S $NIXKEYSTOREFILE_D

if [ ! -f "$NIXEVEFILE_D" ]; then
  cp $NIXEVEFILE_S $NIXEVEFILE_D

  # Write ENV File
  UUID1=$(uuidgen)
  UUID2=$(uuidgen)

  VAL1=$(echo $UUID1 | base64)
  VAL2=$(echo $UUID2 | base64)

  sed -i "s/\("CYPHER_KEY_RUNTIME" * = *\).*\$/\1 $VAL1/" $NIXEVEFILE_D
  sed -i "s/\("CYPHER_VECTOR_RUNTIME" * = *\).*\$/\1 $VAL2/" $NIXEVEFILE_D
fi


chmod 0640 $NIXJARFILE_D
chown root:root $NIXJARFILE_D

chmod 0600 $NIXEVEFILE_D
chown root:root $NIXEVEFILE_D

chmod 0640 $NIXROBOTJARFILE_D
chown root:root $NIXROBOTJARFILE_D

chmod -R 0640 $NIXLIBFILE_D
chown -R root:root $NIXLIBFILE_D

chmod 0640 $NIXCONFIGFILE_D
chown root:root $NIXCONFIGFILE_D

chmod 0700 $NIXAPPIMGFILE_D
chmod 0700 $NIXAPPICONFILE_D
chmod 0600 $NIXKEYSTOREFILE_D

NIXSTOPFILE="$WORKDIR/NixStopped"
# delete nix stopFile

if [ -f "$NIXSTOPFILE" ]; then 
    echo "$NIXSTOPFILE exist"
	rm -f $NIXSTOPFILE
fi



# Configure things
while true; do

  # Ask For Customer ID if required
  if [ -z "$CUSTOMERID" ]; then
    while true; do
      read -p "Enter SureMDM Customer ID / Account ID: " CUSTOMERID
      if [ -z "$CUSTOMERID" ]; then
        echo -e "${RED}Customer ID / Account ID cannot be empty.${NC}"
      else
        break
      fi
    done
  fi

  # Ask for Server Path If required
  if [ "$CUSTOMERID" == "1" ]; then
    echo -e "${GREEN}You are running on-premise solution.${NC}"
    
    if [ -z "$SERVER" ]; then
      # Ask For Server Path
      while true; do
        read -p "Enter Server Path (Examples: 192.168.1.10, mymdm.exmaple.com/suremdm) " SERVER
        if [ -z "$SERVER" ]; then
          echo -e "${RED}Server Path cannot be empty.${NC}"
        else
          break
        fi
      done
    else
      echo -e "${RED}Server is $SERVER ${NC}"
    fi

  # Ask For Group Path if required
  if [ -z "$GROUP_PATH" ]; then
    while true; do
      read -p "Enter SureMDM Group Path: " GROUP_PATH
      if [ -z "$GROUP_PATH" ]; then
        echo -e "${RED}Group Path cannot be empty.${NC}"
      else
        break
      fi
    done
  fi

  # Ask For Password if required
  if [ -z "$PASSWORD" ]; then
    read -p "Enter SureMDM Password: " PASSWORD
  fi

  # Ask For Device Name Type if required
  if [ "$Device_Name_Type" != "1" ] && [ "$Device_Name_Type" != "2" ] && [ "$Device_Name_Type" != "3" ] && [ "$Device_Name_Type" != "4" ] || [ -z "$Device_Name_Type" ]; then
    while true; do
    echo -e "${PURPLE}Device Name Type :${NC}"
    echo -e "${PURPLE}1 = Serial Number${NC}"
    echo -e "${PURPLE}2 = Host Name${NC}"
    echo -e "${PURPLE}3 = Manual Name ${NC}"
    echo -e "${PURPLE}4 = System Generated Name${NC}"
      read -p "Enter Device Name Type: " Device_Name_Type
      if [ -z "$Device_Name_Type" ]; then
        echo -e "${RED}Device Name Type cannot be empty.${NC}"
      elif [ "$Device_Name_Type" != "1" ] && [ "$Device_Name_Type" != "2" ] && [ "$Device_Name_Type" != "3" ] && [ "$Device_Name_Type" != "4" ]; then
      	 echo -e "${RED}Enter Device Name Type Between 1 to 4.${NC}"
      else
        break
      fi
    done
  fi
  # Ask For Device Name if required
  if [ "$Device_Name_Type" == "3" ]; then
    if [ -z "$Device_Name" ]; then
      while true; do
        read -p "Enter Device Name: " Device_Name
        if [ -z "$Device_Name" ]; then
          echo -e "${RED}Device Name cannot be empty.${NC}"
        else
          break
        fi
      done
    fi
  fi

  else
    # SAAS Version
    if [ -z "$SERVER" ]; then
      SERVER="suremdm.42gears.com"
    fi
      
  fi

  # Ask For Group Path if required
  if [ -z "$GROUP_PATH" ]; then
    group_path=$(grep group_path $NIXCONFIGFILE_S | cut -d '=' -f2)
    while true; do
      if [ -z "$group_path" ]; then
        read -p "Enter SureMDM Group Path : " GROUP_PATH
      else
        read -p "Enter SureMDM Group Path (Default:-$group_path): " GROUP_PATH
      fi
      if [ -z "$GROUP_PATH" ]; then
        GROUP_PATH=$group_path
        if [ -z "$GROUP_PATH" ]; then
          echo -e "${RED}Group Path cannot be empty.${NC}"
        else
          break
        fi
      else
        break
      fi
    done
  fi
  
  # Ask For Password if required
  if [ -z "$PASSWORD" ] && [ "$CUSTOMERID" != "1" ]; then
    read -p "Enter SureMDM Password: " PASSWORD
  fi

  # Ask For Device Name Type if required
  if [ "$Device_Name_Type" != "1" ] && [ "$Device_Name_Type" != "2" ] && [ "$Device_Name_Type" != "3" ] && [ "$Device_Name_Type" != "4" ] || [ -z "$Device_Name_Type" ]; then
    device_name_type=$(grep device_name_type $NIXCONFIGFILE_S | cut -d '=' -f2)
    while true; do
      echo -e "${PURPLE}Device Name Type :${NC}"
      echo -e "${PURPLE}1 = Serial Number${NC}"
      echo -e "${PURPLE}2 = Host Name${NC}"
      echo -e "${PURPLE}3 = Manual Name ${NC}"
      echo -e "${PURPLE}4 = System Generated Name${NC}"
      if [ -z "$device_name_type" ]; then
        read -p "Enter Device Name Type: " Device_Name_Type
      else
        read -p "Enter Device Name Type (Default:-$device_name_type): " Device_Name_Type
      fi
      if [ -z "$Device_Name_Type" ]; then
        Device_Name_Type=$device_name_type
        if [ -z "$Device_Name_Type" ]; then
          echo -e "${RED}Device Name Type cannot be empty.${NC}"
        else
          break
        fi
      elif [ "$Device_Name_Type" != "1" ] && [ "$Device_Name_Type" != "2" ] && [ "$Device_Name_Type" != "3" ] && [ "$Device_Name_Type" != "4" ]; then
        echo -e "${RED}Enter Device Name Type Between 1 to 4.${NC}"
      else
        break
      fi
    done
  fi

  # Ask For Device Name if required
  if [ "$Device_Name_Type" == "3" ]; then
    if [ -z "$Device_Name" ]; then
      device_name=$(grep device_name= $NIXCONFIGFILE_S | cut -d '=' -f2)
      while true; do
        if [ -z "$device_name" ]; then
          read -p "Enter Device Name: " Device_Name
        else
          read -p "Enter Device Name (Default:-$device_name):" Device_Name
        fi
        if [ -z "$Device_Name" ]; then
          Device_Name=$device_name
          if [ -z "$Device_Name" ]; then
            echo -e "${RED}Device Name cannot be empty.${NC}"
          else
            break
          fi
        else
          break
        fi
      done
    fi
  fi

  if [ -z "$USE_UUID" ]; then
    # Ask if use UUID
    read -p "Use UUID: (y/N): " yn
    case $yn in
    [Yy]* )
      USE_UUID="true"
      DEVICE_UUID=$(uuidgen)
      ;;
    * )
      USE_UUID="false"
      ;;
    esac
  elif [ "$USE_UUID" | awk '{print tolower($0)}' == "y"] || [ "$USE_UUID" | awk '{print tolower($0)}' == "yes"]; then
      USE_UUID="true"
      DEVICE_UUID=$(uuidgen)
  else
      USE_UUID="false"
  fi
  
  # Print final values  
  echo -e "${GREEN}Customer Id : $CUSTOMERID${NC}"
  NUMREGX='^[0-9]+$'
  if ! [[ $CUSTOMERID =~ $NUMREGX ]] ; then
    echo -e "${RED}Warning: $CUSTOMERID does not appear to be a valid Customer Id.${NC}"
  fi

  echo -e "${GREEN}Group Path  : "$GROUP_PATH"${NC}"

  echo -e "${GREEN}Device Name Type  : "$Device_Name_Type"${NC}"
  if [ ! -z "$Device_Name" ]; then
    echo -e "${GREEN}Device Name : "$Device_Name"${NC}"
  fi

  echo -e "${GREEN}Use UUID  : "$USE_UUID"${NC}"
  # Check Server Status
  echo -e "${GREEN}SureMDM Server : https://$SERVER${NC}"
  CURLBIN="$(type -p curl)"
  if [ -z "$CURLBIN" ]; then
    echo -e "${RED}Curl command not found.${NC}"
  else
    if curl -s --head  --request GET https://$SERVER/test.html | grep "200" > /dev/null; then 
      echo -e "${GREEN}https://$SERVER is running${NC}"
    else
      echo -e "${RED}https://$SERVER is currently not reachable${NC}"
    fi
  fi

  # Proceed if Ok
  if [ "$OVERWRITE" = "Yes" ]; then
    echo -e "${GREEN}Proceeding Nix installation${NC}"
    break
  else
    read -p "Is this information correct? Proceed? (y/N): " yn
    case $yn in
      [Yy]* ) break;;
      * ) echo -e "${PURPLE}Re-enter details${NC}"
        unset CUSTOMERID SERVER GROUP_PATH PASSWORD Device_Name_Type Device_Name CURLBIN USE_UUID;;
    esac
  fi

done

if [[ -n $PASSWORD ]]; then
  PASSWORD_HASH=$(echo -n $PASSWORD | sha512sum  | awk '{print $1}')
fi

if [[ -n $PASSWORD ]];then
    sed -i "s/\("PASSWORD_HASH" * = *\).*\$/\1 $PASSWORD_HASH/" $NIXEVEFILE_D
fi

if [[ -n $DEVICE_UUID ]];then
    sed -i "s/\("DEVICE_UUID" * = *\).*\$/\1 $DEVICE_UUID/" $NIXEVEFILE_D
fi

# Write configuration
SERVER=$(echo "$SERVER" | sed 's/\//\\\//g')
sed -i "s/\("server" *= *\).*/\1$SERVER/" $NIXCONFIGFILE_D
sed -i "s/\("customer_id" *= *\).*/\1$CUSTOMERID/" $NIXCONFIGFILE_D
sed -i "/group_path/c\group_path=$GROUP_PATH" $NIXCONFIGFILE_D
sed -i "s/\("device_name_type" *= *\).*/\1$Device_Name_Type/" $NIXCONFIGFILE_D
sed -i "s/\("device_name" *= *\).*/\1$Device_Name/" $NIXCONFIGFILE_D
sed -i "s/\("use_uuid" *= *\).*/\1$USE_UUID/" $NIXCONFIGFILE_D

if [ ! -z "$USEREMAIL" ]; then
  sed -i "s/\("email" *= *\).*/\1$USEREMAIL/" $NIXCONFIGFILE_D
fi

if [ ! -z "$MDM_USER_NAME" ]; then
  sed -i "s/\("name" *= *\).*/\1$MDM_USER_NAME/" $NIXCONFIGFILE_D
fi

XDG_SESSION="$(loginctl show-session $(awk '/tty/ {print $1}' <(loginctl)) -p Type | awk -F= '{print $2}')"

if [ "${XDG_SESSION,,}" = "wayland" ]; then
  echo -e "${RED}Warning: Wayland detected. Remote Support is available only in Xorg sessions.${NC}"
else
  # Generate Remote Support Properties
  X11DISPLAYDIR="$XAUTHORITY"
  X11DISPLAYVAL="$DISPLAY"

  if [ -z "$X11DISPLAYVAL" ]; then
    X11DISPLAYVAL=':0'
  fi

  if [ -f "$X11DISPLAYDIR" ]; then
    echo "Environment Variables for Remote Support are: $X11DISPLAYDIR AND $X11DISPLAYVAL"
  else
    X11DISPLAY0=":$(ls /tmp/.X11-unix/* | sed 's#/tmp/.X11-unix/X##' | head -n 1)"
    X11USER=$(who | grep '('$X11DISPLAY0')' | awk '{print $1}')
    X11USERHOME=$(eval echo ~$X11USER)"/.Xauthority"
    if [ -f "$X11USERHOME" ]; then
      echo -e "${GREEN}$X11USERHOME will be used as default context for remote support.${NC}"
      X11DISPLAYDIR="$X11USERHOME"
    else
      echo -e "${RED}Remote support context not found.${NC}"
    fi
  fi

fi

# Run corrosponding sh file for this platfrom #
if [ ! -z `type -p systemctl` ]; then
  # echo -e "${GREEN}Initiating installer for systemd platfrom.${NC}"
  source $ABSDIR/bootstrap/systemd.sh
elif [[ `/sbin/init --version` =~ upstart ]]; then
  # echo -e "${GREEN}Initiating installer for upstart platform.${NC}"
  source $ABSDIR/canonical/upstart.sh
elif [[ -f /etc/init.d/cron && ! -h /etc/init.d/cron ]]; then
  source $ABSDIR/legacy/sysvinit.sh  
else
  echo -e "${RED}SureMDM Nix installer is not supported on your platform${NC}"
  exit 1
fi

echo -e "${GREEN}Installation Complete\n${NC}"
