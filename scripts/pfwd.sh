#
# Script to open a connection to prometheus
# Requires kubectl config to be already pointing to the target cluster
#
PROM=`kubectl get pods -n monitoring -l app=prometheus --no-headers=true -o name`
# AMAN=`kubectl get pods -n monitoring -l app=alertmanager --no-headers=true -o name`
GRAF=`kubectl get pods -n monitoring -l app=grafana --no-headers=true -o name`
THANOS=`kubectl get service -n monitoring -l app=thanos-querier --no-headers=true -o name`
echo $PROM
# echo $AMAN
# echo $GRAF
kubectl port-forward -n monitoring $PROM 8080:9090 &
# kubectl port-forward -n monitoring $AMAN 8081:9093 &
kubectl port-forward -n monitoring $GRAF 3000:3000 &
kubectl port-forward -n monitoring $THANOS 8082:9090 &
echo
echo Prometheus at http://localhost:8080
# echo Alertmanager at http://localhost:8081
echo Grafana at http://localhost:3000
echo Thanos at http://localhost:8082
echo
echo kill with pkill kubectl
echo
