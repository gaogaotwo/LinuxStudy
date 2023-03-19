CMD=$1
 
showHelp(){
	echo "start  ---- start k8s cluster"
}
 
executeCommand(){
	echo "---------- $CMD etcd --------"
	systemctl $CMD etcd
	echo "---------- $CMD: docker --------"
	systemctl $CMD docker
	echo "---------- $CMD: kube-apiserver --------"
	systemctl $CMD kube-apiserver
	echo "---------- $CMD: kube-controller-manager --------"
	systemctl $CMD kube-controller-manager
	echo "---------- $CMD: kube-scheduler --------"
	systemctl $CMD kube-scheduler
	echo "---------- $CMD: kubelet--------"
	systemctl $CMD kubelet
	echo "---------- $CMD: kube-proxy--------"
	systemctl $CMD kube-proxy
}
 
 
if [ -z $CMD ]
then
	echo "The input parameter is null"
	showHelp
	exit 1
fi
if [ "$CMD" != "start" ] && [ "$CMD" != "stop" ] && [ "$CMD" != "status" ]
then
	echo "Parameter not valid"
	showHelp
	exit 1
fi
executeCommand
