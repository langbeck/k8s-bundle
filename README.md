```bash
kubeadm init --apiserver-advertise-address $(hostname -i) --pod-network-cidr 10.5.0.0/16
kubectl apply -f https://raw.githubusercontent.com/cloudnativelabs/kube-router/master/daemonset/kubeadm-kuberouter.yaml

git clone https://github.com/langbeck/k8s-bundle.git /bundle
cd /bundle
./install-deps.sh
./prepare-master.sh
```
