#/bin/bash

set -x

APP_NAME=$1
PORT=$2
NAMESPACE=$3

oc project --short=true >> /dev/null

if [ "$?" -ne 0 ]; then
	echo "Not Logged in Openshift Console"
	exit 1
fi

if [ "$#" -gt 3 ] || [ "$#" -lt 2 ]; then
    echo "Usage:    ./port-forward.sh <app-name> <port> <namespace>"
    echo "or        ./port-forward.sh <app-name> <port>"
    echo "Examples:"
    echo "          ./port-forward.sh vesba 8080"
    echo "          ./port-forward.sh vesba 8080 vesba-dev-axa-ch"
    exit 1
fi

[ -z "$APP_NAME" ] && { echo "Need to set APP_NAME "; exit 1; }
[ -z "$PORT" ] && { echo "Need to set PORT "; exit 1; }

if [ -z "$NAMESPACE" ]
then
	NAMESPACE=`oc project --short`
	echo "Using namespace [${NAMESPACE}]"
fi

POD=`oc get pod -l app=${APP_NAME} -o template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}' -n ${NAMESPACE}`

if [ -z "${POD}" ]
then
	echo "No Pod found in Namespace [${NAMESPACE}] with labels [app=${APP_NAME}]"
	exit 1
fi

PODS=`echo $POD | tr " " "\n"`



offset=0
for single_pod in $PODS
do
    offset_port=`expr $PORT + $offset`
    echo "Forwarding Port [${offset_port}:${PORT}] in Pod [${single_pod}] of Namespace [${NAMESPACE}]"
    oc port-forward ${single_pod} ${offset_port}:${PORT} -n ${NAMESPACE} &
    offset=`expr $offset + 1`
done
