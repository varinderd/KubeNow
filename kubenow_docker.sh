#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Start containers"

echo "Master"
docker run -it --privileged=true --name=docker-master --hostname docker-master -d --security-opt seccomp:unconfined --cap-add=SYS_ADMIN -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /var/run/docker.sock:/var/tmp/docker.sock andersla/kubenow-v020a1 /sbin/init
docker cp docker_version/ssh_key.pub docker-master:/root/.ssh/authorized_keys

echo "Edge"
docker run -it --privileged=true --name=docker-edge-00 --hostname docker-edge-00 -d --security-opt seccomp:unconfined --cap-add=SYS_ADMIN -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /var/run/docker.sock:/var/tmp/docker.sock andersla/kubenow-v020a1 /sbin/init
docker cp docker_version/ssh_key.pub docker-edge-00:/root/.ssh/authorized_keys

echo "Node"
docker run -it --privileged=true --name=docker-node-00 --hostname docker-node-00 -d --security-opt seccomp:unconfined --cap-add=SYS_ADMIN -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /var/run/docker.sock:/var/tmp/docker.sock andersla/kubenow-v020a1 /sbin/init
docker cp docker_version/ssh_key.pub docker-node-00:/root/.ssh/authorized_keys

echo "generate kubetoken"
kube_token=$(./generate_kubetoken.sh)


echo "Wait until master is up (responding on ssh)"
for i in $(seq 1 200); do nc -z -w3 172.17.0.2 22 && break || sleep 3; done;


echo "init kubeadm on master"
docker exec -it docker-master kubeadm init --skip-preflight-checks --pod-network-cidr=10.244.0.0/16 --token=$kube_token

echo "edge join master"
docker exec -it docker-node-00 kubeadm join --skip-preflight-checks --token=$kube_token 172.17.0.2

echo "node join master"
docker exec -it docker-edge-00 kubeadm join --skip-preflight-checks --token=$kube_token 172.17.0.2


# Generate inventory
cat > inventory << EOT
[master]
docker-master ansible_ssh_host=172.17.0.2 ansible_ssh_user=root
[edge]
docker-edge-00 ansible_ssh_host=172.17.0.3 ansible_ssh_user=root
[master:vars]
edge_names="docker-edge-00"
EOT

echo "apply kube-proxy workaround"
ansible-playbook playbooks/local_docker_workaround_proxy_error.yml 

echo "install core"
ansible-playbook -i inventory -e "nodes_count=3" --skip-tags "cloudflare" playbooks/install-core.yml


#
#
# Phenomenal extra deployment
#
# in /etc/hosts add:
# 172.17.0.3  notebook.docker.local
# 172.17.0.3  galaxy.docker.local
#
#

ansible_inventory_file="inventory"
domain="docker.local"
PORTAL_APP_REPO_FOLDER="../cloud-deploy"
TF_VAR_jupyter_password="password"
TF_VAR_galaxy_admin_password="password"
TF_VAR_galaxy_admin_email="anders@ormbunkar.se"

# wait for all pods in core stack to be ready
ansible-playbook -i $ansible_inventory_file \
                 $PORTAL_APP_REPO_FOLDER'/playbooks/wait_for_all_pods_ready.yml'

# deploy jupyter
JUPYTER_PASSWORD_HASH=$( $PORTAL_APP_REPO_FOLDER'/bin/generate-jupyter-password-hash.sh' $TF_VAR_jupyter_password )
ansible-playbook -i $ansible_inventory_file \
                 -e "domain=$domain" \
                 -e "sha1_pass_jupyter=$JUPYTER_PASSWORD_HASH" \
                 $PORTAL_APP_REPO_FOLDER'/playbooks/jupyter/main.yml'
                 
# deploy luigi
ansible-playbook -i $ansible_inventory_file \
                 -e "domain=$domain" \
                 $PORTAL_APP_REPO_FOLDER'/playbooks/luigi/main.yml'

# deploy galaxy
galaxy_api_key="lkhsfoihnejnkjcsdkhkehrjkbsdlak099"
ansible-playbook -i $ansible_inventory_file \
                 -e "domain=$domain" \
                 -e "galaxy_admin_password=$TF_VAR_galaxy_admin_password" \
                 -e "galaxy_admin_email=$TF_VAR_galaxy_admin_email" \
                 -e "galaxy_api_key=$galaxy_api_key" \
                 $PORTAL_APP_REPO_FOLDER'/playbooks/galaxy.yml'
                                 
# wait for jupyter notebook http response != Bad Gateway
jupyter_url="http://notebook.$domain"
ansible-playbook -i $ansible_inventory_file \
                 -e "name=jupyter-notebook" \
                 -e "url=$jupyter_url" \
                 $PORTAL_APP_REPO_FOLDER'/playbooks/wait_for_http_not_down.yml'
                 
# wait for galaxy http response 200 OK
galaxy_url="http://galaxy.$domain"
ansible-playbook -i $ansible_inventory_file \
                 -e "name=galaxy" \
                 -e "url=$galaxy_url" \
                 $PORTAL_APP_REPO_FOLDER'/playbooks/wait_for_http_ok.yml'
