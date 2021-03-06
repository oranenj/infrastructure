#!/usr/bin/bash
set -eu
DNS="10.1.1.1"
NET_NAME="libvirt-network"
TYPE="centos8"
CPUS="1"
RAM="2048"
OCTET=""

usage() {
	echo $0 [-t centos8] [-c CPUs] [-m RAM] vmhost vm.fqdn.example.com
  echo
  echo "the script will output a hopefully-working virt-install line that allows kickstarting a CentOS 8 VM"
  echo "The vm should have a DNS record"
  exit 1
}

while getopts "c:t:m:" OPT; do
	case $OPT in
		c)
		CPUS=$OPTARG;
		;;
		t)
		TYPE=$OPTARG;
		;;
		m)
		RAM=$((OPTARG*1024));
		;;
	esac
	shift
	shift
done
if [ $# -ne 2 ]; then
  usage
fi
VMHOST="$1"
NAME="$2"
CONN="qemu+ssh://$VMHOST/system"

# assume the vms are named with the FQDN for now
FQDN="$NAME"


# Get IP from DNS
ip=$(dig +short -t A ${FQDN})
if [ -z "$ip" ]; then
	echo "No DNS record found: $FQDN"
	exit 1
else 
	ROUTER="$(echo $ip | cut -d. -f1-3).1"
	NETMASK="255.255.255.0"
fi

# Add ,portgroup=$PG if needed
NETWORK="network=${NET_NAME}"

IP="ip=${ip}::${ROUTER}:${NETMASK}:${FQDN}:eth0:none nameserver=${DNS}";

source "${TYPE}/params.sh"


if [ $CPUS -ge 4 ]; then
	echo "Did you mix CPUs and RAM?"
	usage
	exit 1
fi

echo virt-install --connect \"$CONN\" \
	--name \"$NAME\" \
	--vcpus \"$CPUS\" \
	--ram \"$RAM\" \
	--os-variant $OS_VARIANT \
	--disk \"path=/var/lib/libvirt/images/${NAME}_root.qcow2,size=$DISK_SIZE,format=qcow2,bus=scsi\" \
	--network \"$NETWORK\" \
	--location \"$MIRROR\" \
	--initrd-inject \"$KICKSTART_FILE\" \
	--extra-args \"ks=file:/kickstart.cfg console=tty0 net.ifnames=0 $IP\" \
	$EXTRA_ARGS
