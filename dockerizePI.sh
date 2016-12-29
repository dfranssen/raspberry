#!/bin/bash
# Use at own risk ;-)
# Author: dirk.franssen@gmail.com

usage() {
cat << EOF
As docker-machine create does not seem to work with arm devices...

Usage: dockerizePI.sh -a {install|regenerateCerts} -n <hostname>

Parameters:

  -a: action to be performed (install or regenerateCerts). Required.

        install:          initialize a fresh Raspberry PI with the latest
                          docker installation, change the hostname, secure the
                          daemon for tcp and configure docker-machine locally.

        regenerateCerts : regenerate the server certificates signed by the ca
                          docker-machine certificate.
                          This could be handy when switching ip addresses when
                          connecting to different wireless routers.

  -n: hostname to be used. E.g. 'pi3'. Required.
EOF
exit 0
}

install() {
  echo "Starting installation..."

  echo "Creating 'id_rsa_iot' certificate if not yet available"
  cat /dev/zero | ssh-keygen -q -N "" -f ~/.ssh/id_rsa_iot -t rsa -C "Iot Devices" > /dev/null

  echo "Removing 'raspberrypi.local' from known_hosts"
  sed -i.bak '/raspberrypi.local/d' ~/.ssh/known_hosts

  echo "Adding iot certificate to the Raspbery pi and change its hostname"
  PI_IP=$(ping -c1 raspberrypi.local | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p')
  command='install -d -m 700 ~/.ssh && cat >> .ssh/authorized_keys && sudo sed -i "s/raspberrypi/'$hostname'/" /etc/hosts && sudo sed -i "s/raspberrypi/'$hostname'/" /etc/hostname && echo "'$PI_IP'" > ~/current_ip && sudo /etc/init.d/hostname.sh start'
  test=$(which sshpass)
  if [ "$test" == "sshpass not found" ]
  then
    cat ~/.ssh/id_rsa_iot.pub | ssh -o 'StrictHostKeyChecking no' pi@$hostname.local $command
  else
    cat ~/.ssh/id_rsa_iot.pub | sshpass -p raspberry ssh -o 'StrictHostKeyChecking no' pi@$hostname.local $command
  fi
  echo "Adding existing docker-machine certificates to the Raspberry pi"
  scp -i ~/.ssh/id_rsa_iot ~/.docker/machine/certs/*.pem pi@$hostname.local:~

  echo "Installing latest Docker from test.docker.com"
  ssh -i ~/.ssh/id_rsa_iot pi@$hostname.local 'curl -sSL test.docker.com | sh && sudo systemctl enable docker && sudo systemctl start docker && sudo usermod -aG docker pi'

  echo "Securing the docker daemon"
  ssh -i ~/.ssh/id_rsa_iot pi@$hostname.local '
  openssl genrsa -out server-key.pem 2048 &&
  openssl req -subj "/O=dfranssen.pi3" -sha256 -new -key server-key.pem -out server.csr &&
  (echo [req] && echo req_extensions = v3_req && echo distinguished_name = req_distinguished_name && echo [req_distinguished_name] && echo [v3_req] && echo keyUsage = critical, digitalSignature, keyEncipherment, keyAgreement && echo basicConstraints = critical,CA:false && echo extendedKeyUsage = serverAuth && echo subjectAltName = DNS:localhost,IP:$(cat current_ip)) > extfile.cnf &&
  openssl x509 -req -days 3650 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server.pem -extfile extfile.cnf -passin pass:. -extensions v3_req &&
  sudo cp /home/pi/*.pem /etc/docker &&
  sudo chown root:root /etc/docker/{ca,ca-key,cert,key,server,server-key}.pem &&
  sudo chmod -v 0400 /etc/docker/{ca-key,key,server-key}.pem &&
  sudo chmod -v 0444 /etc/docker/{ca,server,cert}.pem &&
  sudo mkdir -p /lib/systemd/system/docker.service.d &&
  (echo "[Service]" && echo "ExecStart=" && echo "ExecStart=/usr/bin/dockerd -H 0.0.0.0:2376 -H fd:// --tlsverify --tlscacert=/etc/docker/ca.pem --tlscert=/etc/docker/server.pem --tlskey=/etc/docker/server-key.pem") > secured.conf &&
  sudo mv secured.conf /lib/systemd/system/docker.service.d/secured.conf && sudo chown root:root /lib/systemd/system/docker.service.d/secured.conf &&
  sudo systemctl daemon-reload &&
  sudo systemctl restart docker'

  echo "Configuring docker-machine locally"
  mkdir -p ~/.docker/machine/machines/$hostname
  scp -i ~/.ssh/id_rsa_iot pi@$hostname.local:~/\{ca,cert,key,server-key,server\}.pem ~/.docker/machine/machines/$hostname
  ssh -i ~/.ssh/id_rsa_iot pi@$hostname.local "rm -rf *.pem"
  createConfigJson

  echo "done"
}

regenerate() {
  echo "Starting certificate regeneration..."
  echo "Removing '"$hostname".local' from known_hosts"
  sed -i.bak '/'$hostname'.local/d' ~/.ssh/known_hosts

  echo "Adding new ip"
  PI_IP=$(ping -c1 $hostname.local | sed -nE 's/^PING[^(]+\(([^)]+)\).*/\1/p')
  command='echo "'$PI_IP'" > ~/current_ip'
  test=$(which sshpass)
  if [ "$test" == "sshpass not found" ]
  then
    cat ~/.ssh/id_rsa_iot.pub | ssh -o 'StrictHostKeyChecking no' pi@$hostname.local $command
  else
    cat ~/.ssh/id_rsa_iot.pub | sshpass -p raspberry ssh -o 'StrictHostKeyChecking no' pi@$hostname.local $command
  fi
  echo "Adding existing docker-machine certificates to the Raspberry pi"
  scp -i ~/.ssh/id_rsa_iot ~/.docker/machine/certs/*.pem pi@$hostname.local:~

  echo "Regenerating certificates and restart docker daemon"
  ssh -i ~/.ssh/id_rsa_iot pi@$hostname.local '
  openssl genrsa -out server-key.pem 2048 &&
  openssl req -subj "/O=dfranssen.pi3" -sha256 -new -key server-key.pem -out server.csr &&
  (echo [req] && echo req_extensions = v3_req && echo distinguished_name = req_distinguished_name && echo [req_distinguished_name] && echo [v3_req] && echo keyUsage = critical, digitalSignature, keyEncipherment, keyAgreement && echo basicConstraints = critical,CA:false && echo extendedKeyUsage = serverAuth && echo subjectAltName = DNS:localhost,IP:$(cat current_ip)) > extfile.cnf &&
  openssl x509 -req -days 3650 -sha256 -in server.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out server.pem -extfile extfile.cnf -passin pass:. -extensions v3_req &&
  sudo rm -f /etc/docker/{ca,ca-key,cert,key,server,server-key}.pem
  sudo cp /home/pi/*.pem /etc/docker &&
  sudo chown root:root /etc/docker/{ca,ca-key,cert,key,server,server-key}.pem &&
  sudo chmod -v 0400 /etc/docker/{ca-key,key,server-key}.pem &&
  sudo chmod -v 0444 /etc/docker/{ca,server,cert}.pem &&
  sudo systemctl restart docker'

  echo "Re-configuring docker-machine locally"
  sed -i '.original' 's/\("IPAddress": "\).*/\1'$PI_IP'",/g' ~/.docker/machine/machines/$hostname/config.json
  scp -i ~/.ssh/id_rsa_iot pi@$hostname.local:~/\{ca,cert,key,server-key,server\}.pem ~/.docker/machine/machines/$hostname
  ssh -i ~/.ssh/id_rsa_iot pi@$hostname.local "rm -rf *.pem"

  echo "done"
}

createConfigJson() {
echo '{
  "ConfigVersion": 3,
  "Driver": {
      "IPAddress": "'$PI_IP'",
      "MachineName": "'$hostname'",
      "SSHUser": "pi",
      "SSHPort": 22,
      "SSHKeyPath": "/Users/'$(whoami)'/.docker/machine/machines/'$hostname'/id_rsa_iot",
      "StorePath": "/Users/'$(whoami)'/.docker/machine",
      "SwarmMaster": false,
      "SwarmHost": "",
      "SwarmDiscovery": "",
      "EnginePort": 2376,
      "SSHKey": "/Users/'$(whoami)'/.ssh/id_rsa_iot"
  },
  "DriverName": "generic",
  "HostOptions": {
      "Driver": "",
      "Memory": 0,
      "Disk": 0,
      "EngineOptions": {
          "ArbitraryFlags": [],
          "Dns": null,
          "GraphDir": "",
          "Env": [],
          "Ipv6": false,
          "InsecureRegistry": [],
          "Labels": [],
          "LogLevel": "",
          "StorageDriver": "overlay",
          "SelinuxEnabled": false,
          "TlsVerify": true,
          "RegistryMirror": [],
          "InstallURL": "https://get.docker.com"
      },
      "SwarmOptions": {
          "IsSwarm": false,
          "Address": "",
          "Discovery": "",
          "Agent": false,
          "Master": false,
          "Host": "tcp://0.0.0.0:3376",
          "Image": "swarm:latest",
          "Strategy": "spread",
          "Heartbeat": 0,
          "Overcommit": 0,
          "ArbitraryFlags": [],
          "ArbitraryJoinFlags": [],
          "Env": null,
          "IsExperimental": false
      },
      "AuthOptions": {
          "CertDir": "/Users/'$(whoami)'/.docker/machine/certs",
          "CaCertPath": "/Users/'$(whoami)'/.docker/machine/certs/ca.pem",
          "CaPrivateKeyPath": "/Users/'$(whoami)'/.docker/machine/certs/ca-key.pem",
          "CaCertRemotePath": "",
          "ServerCertPath": "/Users/'$(whoami)'/.docker/machine/machines/'$hostname'/server.pem",
          "ServerKeyPath": "/Users/'$(whoami)'/.docker/machine/machines/'$hostname'/server-key.pem",
          "ClientKeyPath": "/Users/'$(whoami)'/.docker/machine/certs/key.pem",
          "ServerCertRemotePath": "",
          "ServerKeyRemotePath": "",
          "ClientCertPath": "/Users/'$(whoami)'/.docker/machine/certs/cert.pem",
          "ServerCertSANs": [],
          "StorePath": "/Users/'$(whoami)'/.docker/machine/machines/'$hostname'"
      }
  },
  "Name": "'$hostname'"
}' > ~/.docker/machine/machines/$hostname/config.json
}

argumentCnt=0
hostname=""
action=""

while getopts "ha:n:" optname; do
  case "$optname" in
    "h")
      usage
      ;;
    "a")
      action="$OPTARG"
      ((argumentCnt++))
      ;;
    "n")
      hostname="$OPTARG"
      ((argumentCnt++))
      ;;
    *)
      # should not occur
      echo "Unknown error while processing options inside dockerizePI.sh"
      ;;
  esac
done

if [ $argumentCnt -ne 2 ]; then usage; fi

case "$action" in
  "install")
    install
    ;;
  "regenerateCerts")
    regenerate
    ;;
  *)
    usage
    ;;
esac
