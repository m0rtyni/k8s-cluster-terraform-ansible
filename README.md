# Kubernetes Cluster Bootstrap with Ansible and Terraform

## 1. Project Overview

This project automates the provisioning and bootstrapping of a self-managed Kubernetes cluster using **Terraform** and **Ansible**.

The infrastructure is provisioned on AWS using Terraform. Ansible configures the EC2 instances and bootstraps Kubernetes components without relying on managed Kubernetes services such as Amazon EKS.

The main goal is to understand and automate the process of building a Kubernetes cluster from individual components, including certificate generation, control-plane configuration, worker-node setup, networking, and cluster validation.

### Key technologies

- AWS EC2
- Terraform
- Ansible
- Ubuntu 24.04 LTS
- Kubernetes v1.32.0
- containerd v1.7.24
- etcd v3.5.17
- Calico v3.29.2
- CoreDNS v1.11.3

## 2. Architecture

The cluster consists of three EC2 instances deployed in AWS.

| Node | Role | Private IP |
|---|---|---|
| control-plane | Kubernetes Control Plane, etcd | `10.20.1.10` |
| worker-1 | Kubernetes Worker | `10.20.1.11` |
| worker-2 | Kubernetes Worker | `10.20.1.12` |

### Cluster configuration

- Cloud provider: AWS
- Region: `eu-central-1`
- Operating system: Ubuntu 24.04 LTS
- Container runtime: containerd
- Kubernetes version: `v1.32.0`
- Pod network: `10.200.0.0/16`
- Service network: `10.32.0.0/24`
- DNS service IP: `10.32.0.10`
- Network plugin: Calico

The control plane and etcd run on the same instance. Both worker nodes run containerd and kubelet.

The control-plane node is dedicated to cluster management. Workloads are scheduled on the worker nodes.

### Architecture overview

```text
                       Administrator
                            |
                            | kubectl
                            |
                    +-------------------+
                    |   Control Plane   |
                    |                   |
                    |   API Server      |
                    |   Scheduler       |
                    |   Controller Mgr  |
                    |   etcd            |
                    +-------------------+
                            |
                +-----------+-----------+
                |                       |
         +-------------+         +-------------+
         |  Worker 1   |         |  Worker 2   |
         |             |         |             |
         | kubelet     |         | kubelet     |
         | kube-proxy  |         | kube-proxy  |
         | containerd  |         | containerd  |
         | Calico      |         | Calico      |
         +-------------+         +-------------+
```

## 3. Repository Structure

```text
k8s-cluster-terraform-ansible/
│
├── ansible/
│   ├── inventory/
│   │   └── hosts.ini
│   ├── group_vars/
│   │   └── all.yml
│   ├── roles/
│   │   ├── bootstrap-etcd/
│   │   ├── configure-kubectl/
│   │   ├── generate-certs/
│   │   ├── generate-configs/
│   │   ├── setup-control-plane/
│   │   ├── setup-networking/
│   │   ├── setup-worker-nodes/
│   │   └── smoke-test/
│   ├── ansible.cfg
│   └── site.yml
│
├── terraform/
│   └── ...
│
├── .gitignore
└── README.md
```

Ansible roles are separated by responsibility to make the bootstrap process easier to maintain and troubleshoot.

Generated certificates, private keys, kubeconfig files, Terraform state files, and other sensitive artifacts must not be committed to the repository.

## 4. Prerequisites

The following tools are required:

- AWS account and configured AWS CLI credentials
- Terraform
- Ansible
- OpenSSH client
- Python 3
- Git
- WSL environment for running Ansible

The Ansible controller is operated from WSL. Terraform and AWS CLI can be run from an environment with the required AWS credentials and configuration.

The SSH private key is stored locally and referenced through `ansible/ansible.cfg`.

Before deployment, make sure that:

- AWS credentials are configured.
- The selected AWS region is correct.
- The SSH key exists and has appropriate permissions.
- The inventory contains the correct instance addresses.
- Terraform variables are configured for the deployment.

## 5. Infrastructure Provisioning

Terraform is responsible for provisioning the AWS infrastructure required by the cluster.

The infrastructure includes:

- VPC and networking resources
- Public and private subnets
- Security groups
- EC2 instances
- SSH access configuration

### Terraform workflow

```bash
cd terraform

terraform init
terraform validate
terraform plan
terraform apply
```

After provisioning, Terraform outputs can be used to obtain instance information.

The current deployment used the AWS region `eu-central-1` and three Ubuntu EC2 instances.

The instance addresses used during the deployment were:

| Node | Private IP | Public IP |
|---|---|---|
| control-plane | `10.20.1.10` | `3.70.229.157` |
| worker-1 | `10.20.1.11` | `18.196.145.209` |
| worker-2 | `10.20.1.12` | `35.158.93.234` |

Public IP addresses may change when the infrastructure is recreated.

## 6. Ansible Configuration

Ansible inventory is located at:

`ansible/inventory/hosts.ini`

The inventory defines three groups:

- `control_plane`
- `workers`
- `k8s_cluster`

The `k8s_cluster` group includes both the control-plane and worker groups.

Global cluster variables are stored in:

`ansible/group_vars/all.yml`

These variables define:

- Kubernetes and component versions
- Network CIDRs
- Node addresses
- Installation paths
- Certificate configuration
- Artifact directories

The main playbook is:

`ansible/site.yml`

### Running Ansible

From WSL:

```bash
cd /mnt/e/k8s-cluster-terraform-ansible/ansible

ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook site.yml
```

To validate the playbook syntax without executing tasks:

```bash
ANSIBLE_CONFIG="$PWD/ansible.cfg" ansible-playbook site.yml --syntax-check
```

## 7. Kubernetes Bootstrap Process

The main playbook `ansible/site.yml` executes the bootstrap stages in order.

### 7.1. Generate Kubernetes Certificates

Role: `generate-certs`

Generates the Kubernetes Certificate Authority and component certificates.

The process includes:

- Creating a private CA key and self-signed CA certificate.
- Generating private keys and CSRs for Kubernetes components.
- Signing component certificates with the cluster CA.
- Configuring certificate subjects, SANs, and extended key usages.

Generated certificates are stored locally in the Ansible artifacts directory.

Certificate verification against the CA was successful.

Worker kubelet certificates include both TLS server and client authentication usages. This is required because the kubelet communicates with the API Server and also serves requests from the API Server.

### 7.2. Generate Kubernetes Configuration Files

Role: `generate-configs`

Generates kubeconfig files for Kubernetes components.

These configurations provide authentication and API Server connection settings.

Generated configurations include those for:

- Admin
- Kubelet worker nodes
- Kube-proxy
- Controller Manager
- Scheduler

ServiceAccount signing keys are also generated.

Configuration generation was tested locally.

### 7.3. Bootstrap etcd

Role: `bootstrap-etcd`

Installs and configures etcd on the control-plane node.

The role performs the following tasks:

- Installs required packages.
- Downloads and installs etcd binaries.
- Configures etcd directories and certificates.
- Installs the systemd service.
- Enables and starts etcd.

The current architecture uses a single-member etcd cluster.

The API Server communicates with etcd using mutual TLS authentication.

### 7.4. Bootstrap Kubernetes Control Plane

Role: `setup-control-plane`

Installs and configures the Kubernetes control-plane components:

- kube-apiserver
- kube-controller-manager
- kube-scheduler
- kubectl

The role also configures:

- Kubernetes component certificates.
- ServiceAccount signing keys.
- API Server encryption configuration for Kubernetes Secrets.
- Component kubeconfig files.
- systemd services.
- RBAC permissions required for API Server access to kubelet endpoints.

A ClusterRoleBinding named `kube-apiserver-kubelet-client` binds the API Server's kubelet client identity to the built-in `system:kubelet-api-admin` ClusterRole.

This permission is required for API Server operations such as retrieving Pod logs and executing commands inside containers.

### 7.5. Bootstrap Kubernetes Worker Nodes

Role: `setup-worker-nodes`

Prepares both worker nodes.

The role installs and configures:

- containerd
- runc
- CNI plugins
- kubelet
- kubectl

It also deploys worker certificates, kubeconfig files, and kubelet configuration.

Containerd is configured to use the systemd cgroup driver.

The kubelet configuration explicitly uses:

`/run/systemd/resolve/resolv.conf`

as its resolver configuration file. This avoids forwarding the local systemd stub resolver address (`127.0.0.53`) into Pods and allows workloads to resolve cluster DNS correctly.

### 7.6. Configure kube-proxy

Role: `setup-networking`, task file: `kube-proxy.yml`

Configures kube-proxy on all Kubernetes nodes.

The configuration uses:

- iptables mode
- The cluster Pod CIDR
- A dedicated kubeconfig
- A systemd service

kube-proxy provides network routing for Kubernetes Services.

### 7.7. Configure Kubernetes Networking

Role: `setup-networking`

Deploys the Calico network plugin and CoreDNS.

Calico provides Pod networking using the configured cluster CIDR.

CoreDNS provides DNS resolution for Kubernetes services and Pods.

The CoreDNS configuration includes:

- ServiceAccount
- RBAC permissions
- ConfigMap with CoreDNS Corefile
- Deployment with two replicas
- kube-dns Service

### 7.8. Configure Remote kubectl Access

Role: `configure-kubectl`

Retrieves the administrator kubeconfig from the control-plane node and configures it locally.

The local kubeconfig uses a loopback API endpoint. Access to this endpoint is intended to be provided through an SSH tunnel.

### 7.9. Smoke Tests

Role: `smoke-test`

Runs checks intended to verify that the cluster is operational.

The validation process covers Kubernetes node status and system components.

Additional manual tests were performed after deployment to verify:

- Worker-node registration.
- CoreDNS availability.
- Internal Kubernetes DNS resolution.
- API Server communication with kubelet.
- Pod log retrieval.
- Remote command execution inside containers.

## 8. Validation and Testing

The cluster was deployed and its main components were validated.

### Validation summary

| Component | Validation | Result |
|---|---|---|
| AWS infrastructure | Three EC2 instances provisioned | Passed |
| Ansible | Playbook syntax check | Passed |
| Kubernetes Control Plane | API Server operational | Passed |
| Worker nodes | Both nodes registered and Ready | Passed |
| containerd | Runtime operational on workers | Passed |
| Calico | Network plugin Pods running | Passed |
| CoreDNS | Both replicas running | Passed |
| Internal DNS | Kubernetes Service name resolution | Passed |
| API Server → kubelet TLS | Worker certificates accepted | Passed |
| API Server → kubelet RBAC | `nodes/proxy` permission verified | Passed |
| Pod logs | `kubectl logs` | Passed |
| Pod execution | `kubectl exec` | Passed |

### 8.1. Node Status

Check that all nodes are registered and Ready:

```bash
sudo kubectl --kubeconfig=/etc/kubernetes/admin.kubeconfig get nodes -o wide
```

Expected cluster state:

- `control-plane` — control-plane node
- `worker-1` — Ready
- `worker-2` — Ready

The control-plane node does not run kubelet and is not expected to appear as a worker node.

### 8.2. System Pods

Check the status of Kubernetes system workloads:

```bash
sudo kubectl --kubeconfig=/etc/kubernetes/admin.kubeconfig get pods -A
```

Calico and CoreDNS Pods were confirmed running.

### 8.3. DNS Resolution

A temporary BusyBox Pod was used to test internal DNS resolution:

```bash
kubectl run dns-test \
  --rm -i \
  --restart=Never \
  --image=busybox:1.36 \
  -- nslookup kubernetes.default.svc.cluster.local
```

The test returned:

```text
Server:    10.32.0.10
Name:      kubernetes.default.svc.cluster.local
Address:   10.32.0.1
```

This confirms that a Pod can resolve the Kubernetes default Service through CoreDNS.

### 8.4. Pod Logs

The API Server initially could not retrieve logs from worker Pods because the kubelet client identity lacked the required RBAC permissions.

After creating the `kube-apiserver-kubelet-client` ClusterRoleBinding, the following command succeeded:

```bash
kubectl logs dns-test
```

### 8.5. Pod Execution

A temporary BusyBox Pod was used to verify command execution through the API Server and kubelet:

```bash
kubectl exec exec-test -- hostname
```

The command executed successfully and returned the Pod hostname.

Temporary test Pods were removed after validation.

## 9. Challenges and Solutions

Several issues were encountered during cluster deployment and validation.

| Challenge | Cause | Solution |
|---|---|---|
| Pod DNS resolution failure | Kubelet forwarded the systemd stub resolver configuration | Configured kubelet to use `/run/systemd/resolve/resolv.conf` |
| API Server could not communicate with kubelet over TLS | Worker certificates lacked TLS server authentication usage | Added both `serverAuth` and `clientAuth` to worker certificate profiles and regenerated certificates |
| `kubectl logs` returned Forbidden | Missing ClusterRoleBinding for the API Server kubelet client identity | Bound `kube-apiserver-kubelet-client` to `system:kubelet-api-admin` |
| `kubectl exec` did not work | API Server lacked the required access to kubelet endpoints | Corrected the kubelet client RBAC binding |
| Worker DNS configuration was unsuitable for Pods | `/etc/resolv.conf` pointed to the local systemd stub resolver | Set the explicit resolver file in kubelet configuration |

The fixes were incorporated into the Ansible configuration so that they can be applied during subsequent deployments.

## 10. Cleanup

Terraform is used to remove the provisioned AWS infrastructure when it is no longer required.

```bash
cd terraform

terraform destroy
```

Review the Terraform plan before confirming destruction.

After cleanup, verify that the resources have been removed from AWS. Pay particular attention to EC2 instances, networking resources, security groups, and any other billable resources defined by the Terraform configuration.

## 11. Project Status

The Kubernetes cluster was successfully provisioned and bootstrapped.

### Completed

- AWS infrastructure provisioning.
- Ansible inventory and global configuration.
- Kubernetes CA and component certificate generation.
- Kubernetes kubeconfig generation.
- etcd bootstrap.
- Kubernetes control-plane setup.
- Kubernetes worker-node setup.
- containerd configuration.
- kube-proxy configuration.
- Calico deployment.
- CoreDNS deployment.
- Remote kubectl configuration.
- Kubelet DNS resolver configuration.
- Worker kubelet TLS certificate correction.
- API Server kubelet RBAC configuration.
- Kubernetes node and system Pod validation.
- Internal DNS resolution testing.
- `kubectl logs` verification.
- `kubectl exec` verification.
- Persistence of the discovered configuration fixes in Ansible.

### Result

A self-managed Kubernetes cluster consisting of one control-plane node and two worker nodes was successfully deployed on AWS.

The deployment demonstrates the process of building a Kubernetes cluster from individual components using Terraform and Ansible, including certificate management, control-plane configuration, worker setup, networking, DNS, RBAC, and operational validation.

The project can be redeployed using the Terraform infrastructure definitions and the Ansible playbook.