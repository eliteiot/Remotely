#!/bin/bash
HostName=
Organization=
GUID=$(cat /proc/sys/kernel/random/uuid)
UpdatePackagePath=""


Args=( "$@" )
ArgLength=${#Args[@]}

for (( i=0; i<${ArgLength}; i+=2 ));
do
    if [ "${Args[$i]}" = "--uninstall" ]; then
        systemctl stop remotely-agent
        rm -r -f /usr/local/bin/Remotely
        rm -f /etc/systemd/system/remotely-agent.service
        rm -f /usr/bin/dotnet
        systemctl daemon-reload
        exit
    elif [ "${Args[$i]}" = "--path" ]; then
        UpdatePackagePath="${Args[$i+1]}"
    fi
done

UbuntuVersion=$(lsb_release -r -s)

apt-get -y install libx11-dev libxrandr-dev unzip libc6-dev libgdiplus libxtst-dev xclip jq curl wget make gcc g++

# Install .NET Core Runtime.
cd /tmp
rm -f dotnet-install*
wget https://dot.net/v1/dotnet-install.sh
chmod +x dotnet-install.sh

mkdir -p /usr/local/bin/dotnet
./dotnet-install.sh -c 6.0 --runtime dotnet --install-dir /usr/local/bin/dotnet
ln -s /usr/local/bin/dotnet/dotnet /usr/bin/dotnet

rm -f dotnet-install*

sudo curl -fsSL https://deb.nodesource.com/setup_17.x | bash -
sudo apt install nodejs

if [ -f "/usr/local/bin/Remotely/ConnectionInfo.json" ]; then
    SavedGUID=`cat "/usr/local/bin/Remotely/ConnectionInfo.json" | jq -r '.DeviceID'`
     if [[ "$SavedGUID" != "null" && -n "$SavedGUID" ]]; then
        GUID="$SavedGUID"
    fi
fi

rm -r -f /usr/local/bin/Remotely
rm -f /etc/systemd/system/remotely-agent.service

mkdir -p /usr/local/bin/Remotely/
cd /usr/local/bin/Remotely/

if [ -z "$UpdatePackagePath" ]; then
    echo  "Downloading client..." >> /tmp/Remotely_Install.log
    wget $HostName/Content/Remotely-Linux-arm64.zip
else
    echo  "Copying install files..." >> /tmp/Remotely_Install.log
    cp "$UpdatePackagePath" /usr/local/bin/Remotely/Remotely-Linux-arm64.zip
    rm -f "$UpdatePackagePath"
fi

unzip ./Remotely-Linux-arm64.zip
rm -f ./Remotely-Linux-arm64.zip
chmod +x ./Remotely_Agent
chmod +x ./Desktop/Remotely_Desktop


connectionInfo="{
    \"DeviceID\":\"$GUID\", 
    \"Host\":\"$HostName\",
    \"OrganizationID\": \"$Organization\",
    \"ServerVerificationToken\":\"\"
}"

echo "$connectionInfo" > ./ConnectionInfo.json

runtimeOptions="{
   \"runtimeOptions\": {
      \"configProperties\": {
         \"System.Drawing.EnableUnixSupport\": true
      }
   }
}"

echo "$runtimeOptions" > ./Desktop/Remotely_Desktop.runtimeconfig.json

curl --head $HostName/Content/Remotely-Linux-arm64.zip | grep -i "etag" | cut -d' ' -f 2 > ./etag.txt

echo Creating service... >> /tmp/Remotely_Install.log

serviceConfig="[Unit]
Description=The Remotely agent used for remote access.

[Service]
WorkingDirectory=/usr/local/bin/Remotely/
ExecStart=/usr/local/bin/Remotely/Remotely_Agent
Restart=always
StartLimitIntervalSec=0
RestartSec=10

[Install]
WantedBy=graphical.target"

echo "$serviceConfig" > /etc/systemd/system/remotely-agent.service

systemctl enable remotely-agent
systemctl restart remotely-agent

echo Install complete. >> /tmp/Remotely_Install.log
