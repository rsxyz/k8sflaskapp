

mkdir tools
cd tools

----upgrade aws
https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html
aws --version

mac:
curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
sudo installer -pkg AWSCLIV2.pkg -target /

linux:
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip

$ which aws
/usr/bin/aws

sudo ./aws/install --bin-dir /usr/bin --install-dir /usr/bin/aws-cli --update

$ aws --version
aws-cli/2.2.5 Python/3.8.8 Linux/4.14.231-173.361.amzn2.x86_64 exe/x86_64.amzn.2 prompt/off

$ aws sts get-caller-identity


---install kubectl:
https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
mac:
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.20.4/2021-04-12/bin/darwin/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$HOME/bin:$PATH
echo 'export PATH=$HOME/bin:$PATH' >> ~/.bash_profile
kubectl version --short --client


linux:
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.20.4/2021-04-12/bin/linux/amd64/kubectl

chmod +x ./kubectl
mkdir -p $HOME/bin && cp ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc
kubectl version --short --client
  
----install eksctl:
https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html

mac:
brew tap weaveworks/tap
install if new:
brew install weaveworks/tap/eksctl 
upgrade if already installed:
brew upgrade eksctl && brew link --overwrite eksctl

eksctl completion bash >> ~/.bash_completion
. ~/.bash_completion

linux:
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl version
eksctl help

https://github.com/awslabs/amazon-eks-ami/blob/master/files/eni-max-pods.txt
t3.micro -- 4 pods
t3.medium -- 17 pods
t3.large 35
m4.large 20
m4.xlarge 58

export AWS_PROFILE=xxxxxxx
export AWS_REGION=us-east-1
aws sts get-caller-identity

---create cluster
eksctl create cluster \
--name dev-cluster \
--region us-east-1 \
--nodegroup-name standard-workers \
--node-type t3.medium \
--nodes 3 \
--nodes-min 1 \
--nodes-max 4 \
--enable-ssm \
--managed

---- using config file:
cat << EOF > eksworkshop.yaml
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: dev-cluster
  region: us-east-1

availabilityZones: [us-east-1a,us-east-1b,us-east-1c]

managedNodeGroups:
  - name: nodegroup
    desiredCapacity: 3
    instanceType: t3.medium
    ssh:
      enableSsm: true 

EOF

eksctl create cluster -f eksworkshop.yaml

-----
eksctl get cluster
aws eks update-kubeconfig --name dev-cluster --region us-east-1

kubectl get nodes
kubectl get pods
kubectl get services
kubectl get deployments

sudo yum install git -y

--------------------------------

export AWS_REGION=us-east-1
eksctl get cluster
aws eks list-clusters
aws eks describe-cluster --name dev-cluster

----Create an IAM OIDC provider for your cluster

https://docs.aws.amazon.com/eks/latest/userguide/enable-iam-roles-for-service-accounts.html
  
aws eks describe-cluster --name dev-cluster --query "cluster.identity.oidc.issuer" --output text

https://oidc.eks.us-east-1.amazonaws.com/id/51ED36544390C2520EE0B9454B5B205A

aws iam list-open-id-connect-providers|grep 51ED36544390C2520EE0B9454B5B205A

eksctl utils associate-iam-oidc-provider --cluster dev-cluster --approve



$ aws iam list-open-id-connect-providers|grep 51ED36544390C2520EE0B9454B5B205A



------ AWS Load Balancer Controller
https://docs.aws.amazon.com/eks/latest/userguide/aws-load-balancer-controller.html

1.Download an IAM policy
curl -o iam_policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.2.0/docs/install/iam_policy.json

2. Create an IAM Policy
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json

==> Arn": "arn:aws:iam::{AccountId}:policy/AWSLoadBalancerControllerIAMPolicy"	

3. Create an IAM role and annotate the Kubernetes service account named aws-load-balancer-controller in the kube-system namespace for the AWS Load Balancer Controller using eksctl

eksctl create iamserviceaccount \
  --region us-east-1 \
  --cluster=dev-cluster \
  --namespace=kube-system \
  --name=aws-load-balancer-controller \
  --attach-policy-arn=arn:aws:iam::{AccountId}:policy/AWSLoadBalancerControllerIAMPolicy \
  --override-existing-serviceaccounts \
  --approve   



$ kubectl get sa -n kube-system|grep aws-load-balancer-controller


4. Uninstall existing controller
kubectl get deployment -n kube-system alb-ingress-controller

5. Install the AWS Load Balancer Controller using Helm V3 or later or by applying a Kubernetes manifest.
kubectl apply \
    --validate=false \
    -f https://github.com/jetstack/cert-manager/releases/download/v1.1.1/cert-manager.yaml


kubectl get po -n cert-manager

curl -o v2_2_0_full.yaml https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.2.0/docs/install/v2_2_0_full.yaml

Make the following edits to the v2_2_0_full.yaml file:

Delete the ServiceAccount section in lines 546-553 of the file. Deleting this section prevents the annotation with the IAM role from being overwritten when the controller is deployed and preserves the service account that you created in step 4 if you delete the controller.

Replace your-cluster-name on line 797 in the Deployment spec section of the file with the name of your cluster.


kubectl apply -f v2_2_0_full.yaml

kubectl get deployment -n kube-system aws-load-balancer-controller


kubectl get pods -n kube-system


kubectl logs -f $(kubectl get po -n kube-system | egrep -o 'aws-load-balancer-controller-[A-Za-z0-9-]+') -n kube-system

kubectl logs -f $(kubectl get po | egrep -o 'flaskapp-deployment-[A-Za-z0-9-]+')


kubectl apply -f k8s-app-deployment.yaml
kubectl apply -f k8s-app-nodeport-service.yaml
kubectl apply -f k8s-app-ingress.yaml
