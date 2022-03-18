#!/bin/bash

# dryrun or prod?
DRY_RUN=0

#Allowed countries
ISO="us uk de"

# port forwarding configuration matrix
IS_ENABLED=(		1		0 )
CONTAINER_NAMES=( 	"countainer-name1"	"countainer-name2" )
PORT_NUMBERS=(		80		443 )
INTERFACES=(		'br-lan'	'eth0' )
IS_IPS_RESTRICTED=(	1		0 )

#--- DO NOT CHANGE BELOW THIS LINE-----
DLROOT="http://www.ipdeny.com/ipblocks/data/countries"
ALLOWEDLIST="countryallowed"

# ipset/iptables command (used for debugging and dry run)
if [ $DRY_RUN -eq 1 ]
then
	IPSET=echo
	IPTABLES=echo
else
	IPSET=ipset
	IPTABLES=iptables
fi

#clean all
$IPTABLES -F -t nat
$IPSET destroy $ALLOWEDLIST

# create a new iptables list
$IPSET -F $ALLOWEDLIST
$IPSET -N $ALLOWEDLIST nethash

findIPAddress () {
        IP=$(lxc list $CONTAINER_NAME -c 4 | grep $INTERFACE |  awk '!/IPV4/{ if ( $2 != "" ) print $2}')
}

forwardPorts () {
        if [ $IS_IP_RESTRICTED -eq 1 ]
        then
		FILTER="-m set --match-set $ALLOWEDLIST src"
        else
		FILTER=""
        fi

        $IPTABLES -t nat -A PREROUTING -i eth0 $FILTER -p tcp --dport $PORT_NUMBER -j DNAT --to-destination $IP:$PORT_NUMBER
        $IPTABLES -t nat -A PREROUTING -i eth0 $FILTER -p udp --dport $PORT_NUMBER -j DNAT --to-destination $IP:$PORT_NUMBER

	echo port $PORT_NUMBER forwarded to $IP container
}

TMP=$(mktemp -d -t)

for country in $ISO
do
        # local zone file
        tDB=$TMP/$country.zone

        # get fresh zone file
        wget -4 -O $tDB $DLROOT/$country.zone

        # get good IP ranges
        GOODIPS=$(grep -E -v "^#|^$" $tDB)
        for ipblock in $GOODIPS
        do
                $IPSET -A $ALLOWEDLIST $ipblock
        done
done

# Allowed access from Intranet
$IPSET -A $ALLOWEDLIST 10.0.0.0/8
$IPSET -A $ALLOWEDLIST  172.16.0.0/12
$IPSET -A $ALLOWEDLIST  192.168.0.0/16

# now let's do the actual work
index=0
for CONTAINER_NAME in "${CONTAINER_NAMES[@]}"
do
	if [ ${IS_ENABLED[index]} -eq 1 ]
        then

		PORT_NUMBER=${PORT_NUMBERS[index]}
		INTERFACE=${INTERFACES[index]}
		IS_IP_RESTRICTED=${IS_IPS_RESTRICTED[index]}
		
		#find the IP address for the container
		findIPAddress
		# Open port to LXD container
		forwardPorts
	fi
	
	index=$index+1
done
