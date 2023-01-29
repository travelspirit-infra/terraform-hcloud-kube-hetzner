[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

<!-- PROJECT LOGO -->
<br />
<p align="center">
  <a href="https://github.com/mysticaltech/kube-hetzner">
    <img src="https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/raw/master/.images/kube-hetzner-logo.png" alt="Logo" width="112" height="112">
  </a>

  <h2 align="center">Kube-Hetzner</h2>

  <p align="center">
    A highly optimized, easy-to-use, auto-upgradable, HA-default & Load-Balanced, Kubernetes cluster powered by k3s-on-MicroOS and deployed for peanuts on <a href="https://hetzner.com" target="_blank">Hetzner Cloud</a> 🤑 🚀
  </p>
  <hr />
</p>

## About The Project

[Hetzner Cloud](https://hetzner.com) is a good cloud provider that offers very affordable prices for cloud instances, with data center locations in both Europe and the US.

This project aims to create a highly optimized Kubernetes installation that is easy to maintain, secure and automatically upgrades both the nodes and Kubernetes. We aimed for functionality as close as possible to GKE's Auto-Pilot. _Please note that we are not affiliates of Hetzner; but we do strive to be an optimal solution for deploying and maintaining Kubernetes clusters on Hetzner Cloud._

To achieve this, we built up on the shoulders of giants by choosing [openSUSE MicroOS](https://en.opensuse.org/Portal:MicroOS) as the base operating system and [k3s](https://k3s.io/) as the k8s engine.

![Product Name Screen Shot][product-screenshot]

**Why OpenSUSE MicroOS (and not Ubuntu)?**
- Optimized container OS that is fully locked down, most of the filesystem is read-only!
- Hardened by default with automatic ban for abusive IPs on SSH for instance.
- Evergreen release, your node will stay valid forever, as it piggy-backs into OpenSUSE Tumbleweed's rolling-release!
- Automatic updates by default and automatically roll-backs if something breaks, thanks to its use of BTRFS snapshots.
- Supports [Kured](https://github.com/kubereboot/kured) to properly drain and reboot nodes in an HA fashion.

**Why k3s?**
- Certified Kubernetes Distribution, it is automatically synced to k8s source.
- Fast deployment, as it is a single binary and can be deployed with a single command.
- Comes batteries included, with its in-cluster [helm-controller](https://github.com/k3s-io/helm-controller).
- Easy automatic updates, via the [system-upgrade-controller](https://github.com/rancher/system-upgrade-controller).

### Features

- [x] **Maintenance-free** with auto-upgrades to the latest version of MicroOS and k3s.
- [x] Proper use of the **Hetzner private network** to minimize latency.
- [x] **Traefik** or **Nginx** as ingress controller attached to a Hetzner load balancer with Proxy Protocol turned on.
- [x] **Automatic HA** with the default setting of three control-plane nodes and two agent nodes.
- [x] **Autoscaling** nodes via the [kubernetes autoscaler](https://github.com/kubernetes/autoscaler).
- [x] **Super-HA** with Nodepools for both control-plane and agent nodes that can be in different locations.
- [x] Possibility to have a **single node cluster** with a proper ingress controller.
- [x] Can use Klipper as an **on-metal LB** or the **Hetzner LB**.
- [x] Ability to **add nodes and nodepools** when the cluster is running.
- [x] Possibility to turn on **Longhorn** and/or **Hetzner CSI**.
- [x] Choose between **Flannel, Calico, or Cilium** as CNI.
- [x] Optional **Wireguard** encryption of the Kube network for added security.
- [x] **Flexible configuration options** via variables, and an extra Kustomization option.

_It uses Terraform to deploy as it's easy to use, and Hetzner has a great [Hetzner Terraform Provider](https://registry.terraform.io/providers/hetznercloud/hcloud/latest/docs)._

<!-- GETTING STARTED -->

## Getting Started

Follow those simple steps, and your world's cheapest Kubernetes cluster will be up and running.

### ✔️ Prerequisites

First and foremost, you need to have a Hetzner Cloud account. You can sign up for free [here](https://hetzner.com/cloud/).

Then you'll need to have [terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli),  [kubectl](https://kubernetes.io/docs/tasks/tools/) cli and [hcloud](<https://github.com/hetznercloud/cli>) the Hetzner cli. The easiest way is to use the [homebrew](https://brew.sh/) package manager to install them (available on Linux, Mac, and Windows Linux Subsystem).

```sh
brew install terraform
brew install kubectl
brew install hcloud

```

### 💡 [Do not skip] Creating your kube.tf file

1. Create a project in your [Hetzner Cloud Console](https://console.hetzner.cloud/), and go to **Security > API Tokens** of that project to grab the API key. Take note of the key! ✅
1. Generate a passphrase-less ed25519 SSH key pair for your cluster; take note of the respective paths of your private and public keys. Or, see our detailed [SSH options](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/blob/master/docs/ssh.md). ✅
1. Prepare the module by copying `kube.tf.example` to `kube.tf` **in a new folder** which you cd into, then replace the values from steps 1 and 2. ✅
1. (Optional) Many variables in `kube.tf` can be customized to suit your needs, you can do so if you want. ✅
1. At this stage you should be in your new folder, with a fresh `kube.tf` file, if it is so, you can proceed forward! ✅

_A complete reference of all inputs, outputs, modules etc. can be found in the [terraform.md](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/blob/master/docs/terraform.md) file._

_It's important to realize that your kube.tf needs to reside in a NEW folder, not a clone of this git repo (the module by default will be fetched from the Terraform registry). All you need, is to re-use the [kube.tf.example](https://raw.githubusercontent.com/kube-hetzner/terraform-hcloud-kube-hetzner/master/kube.tf.example) file to make sure you get the format right._

### 🎯 Installation

```sh
terraform init --upgrade
terraform validate
terraform apply -auto-approve
```

It will take around 5 minutes to complete, and then you should see a green output confirming a successful deployment.

_Once you start with Terraform, it's best not to change the state of the project manually via the Hetzner UI; otherwise, you may get an error when you try to run terraform again for that cluster (when trying to change the number of nodes for instance)._

## Usage

When your brand-new cluster is up and running, the sky is your limit! 🎉

You can immediately kubectl into it (using the `clustername_kubeconfig.yaml` saved to the project's directory after the installation). By doing `kubectl --kubeconfig clustername_kubeconfig.yaml`, but for more convenience, either create a symlink from `~/.kube/config` to `clustername_kubeconfig.yaml` or add an export statement to your `~/.bashrc` or `~/.zshrc` file, as follows (you can get the path of `clustername_kubeconfig.yaml` by running `pwd`):

```sh
export KUBECONFIG=/<path-to>/clustername_kubeconfig.yaml
```

If chose to turn `create_kubeconfig` to false in your kube.tf (good practice), you can still create this file by running `terraform output --raw kubeconfig > clustername_kubeconfig.yaml` and then use it as described above.

You can also use it in an automated flow, in which case `create_kubeconfig` should be set to false, and you can use the `kubeconfig` output variable to get the kubeconfig file in a structured data format.

_You can view all kinds of details about the cluster by running `terraform output kubeconfig` or `terraform output -json kubeconfig | jq`._

## CNI

The default is Flannel, but you can also choose Calico or Cilium, by setting the `cni_plugin` variable in `kube.tf` to "calico" or "cilium".

As Cilium has a lot of interesting and powerful configurations' possibility. We give you the possibility to configure your Cilium with the helm `cilium_values` variable (see the cilium specific [helm values](https://github.com/cilium/cilium/blob/master/install/kubernetes/cilium/values.yaml])) before you deploy your cluster.

## Scaling Nodes

Two things can be scaled: the number of nodepools or the number of nodes in these nodepools. You have two lists of nodepools you can add to your `kube.tf`, the control plane nodepool and the agent nodepool list. Combined, they cannot exceed 255 nodepools (you are extremely unlikely to reach this limit). As for the count of nodes per nodepools, if you raise your limits in Hetzner, you can have up to 64,670 nodes per nodepool (also very unlikely to need that much).

There are some limitations (to scaling down mainly) that you need to be aware of:

_Once the cluster is up; you can change any nodepool count and even set it to 0 (in the case of the first control-plane nodepool, the minimum is 1); you can also rename a nodepool (if the count is to 0), but should not remove a nodepool from the list after once the cluster is up. That is due to how subnets and IPs get allocated. The only nodepools you can remove are those at the end of each list of nodepools._

_However, you can freely add other nodepools at the end of each list. And for each nodepools, you can freely increase or decrease the node count (if you want to decrease a nodepool node count make sure you drain the nodes in question before, you can use `terraform show` to identify the node names at the end of the nodepool list, otherwise, if you do not drain the nodes before removing them, it could leave your cluster in a bad state). The only nodepool that needs to have always at least a count of 1 is the first control-plane nodepool._

## Autoscaling Node Pools

We support autoscaling node pools powered by the Kubernetes [Cluster Autoscaler](https://github.com/kubernetes/autoscaler).

By adding at least one map to the array of `autoscaler_nodepools` the feature will be enabled. More on this in the corresponding section of kube.tf.example.

_Important to know, the nodes are booted based on a snapshot that is created from the initial control_plane. So please ensure that the disk of your chosen server type is at least the same size (or bigger) as the one of the first control_plane._

## High Availability

By default, we have three control planes and three agents configured, with automatic upgrades and reboots of the nodes.

If you want to remain HA (no downtime), it's essential to **keep a count of control planes nodes of at least three** (two minimum to maintain quorum when one goes down for automated upgrades and reboot), see [Rancher's doc on HA](https://rancher.com/docs/k3s/latest/en/installation/ha-embedded/).

Otherwise, it is essential to turn off automatic OS upgrades (k3s can continue to update without issue) for the control-plane nodes (when two or fewer control-plane nodes) and do the maintenance yourself.

## Automatic Upgrade

### The Default Setting

By default, MicroOS gets upgraded automatically on each node and reboot safely via [Kured](https://github.com/weaveworks/kured) installed in the cluster.

As for k3s, it also automatically upgrades thanks to Rancher's [system upgrade controller](https://github.com/rancher/system-upgrade-controller). By default it will be set to the `initial_k3s_channel`, but you can also set it to `stable`, `latest`, or one more specific like `v1.23` if needed or specify a target version to upgrade to via the upgrade plan (this also allows for downgrades).

You can copy and modify the [one in the templates](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/blob/master/templates/plans.yaml.tpl) for that! More on the subject in [k3s upgrades](https://rancher.com/docs/k3s/latest/en/upgrades/basic/).

### Configuring update timeframes

Per default a node that installed updates will reboot within the next few minutes and updates are installed roughly every 24 hours.
Kured can be instructed with specific timeframes for rebooting, to prevent too frequent drains and reboots.
All options from the [docs](https://kured.dev/docs/configuration/) are available for modification.

⚠️ Kured is also used to reboot nodes after configuration updates (`registries.yaml`, ...), so keep in mind that configuration changes can take some time to propagate!

### Turning Off Automatic Upgrades

_If you wish to turn off automatic MicroOS upgrades (Important if you are not launching an HA setup which requires at least 3 control-plane nodes), you need to set:_

```terraform
automatically_upgrade_os = false
```

_Alternatively ssh into each node and issue the following command:_

```sh
systemctl --now disable transactional-update.timer
```

_If you wish to turn off automatic k3s upgrades, you need to set:_

```terraform
automatically_upgrade_k3s = false
```

_Alternatively, you can either remove the `k3s_upgrade=true` label or set it to `false`. This needs to happen for all the nodes too! To remove it, apply:_

```sh
kubectl -n system-upgrade label node <node-name> k3s_upgrade-
```

Alternatively, you can disable the k3s automatic upgrade without individually editing the labels on the nodes. Instead, you can just delete the two system controller upgrade plans with:

```sh
kubectl delete plan k3s-agent -n system-upgrade
kubectl delete plan k3s-server -n system-upgrade
```

Also, note that after turning off nodes upgrades, you will need to manually upgrade the nodes when needed. You can do so by SSH'ing into each node and running the following commands (and don't forget to drain the node before with `kubectl drain <node-name>`):

```sh
transactional-update
reboot
```

### Individual Components Upgrade

Rarely needed, but can be handy in the long run. During the installation, we automatically download a backup of the kustomization to a `kustomization_backup.yaml` file. You will find it next to your `clustername_kubeconfig.yaml` at the root of your project.

1. First create a duplicate of that file and name it `kustomization.yaml`, keeping the original file intact, in case you need to restore the old config.
1. Edit the `kustomization.yaml` file; you want to go to the very bottom where you have the links to the different source files; grab the latest versions for each on GitHub, and replace. If present, remove any local reference to traefik_config.yaml, as Traefik is updated automatically by the system upgrade controller.
1. Apply the updated `kustomization.yaml` with `kubectl apply -k ./`.

## Customizing the Cluster Components

Most cluster components of Kube-Hetzner are deployed with the Rancher [Helm Chart](https://rancher.com/docs/k3s/latest/en/helm/) yaml definition and managed by the Helm Controller inside k3s.

By default, we strive to give you optimal defaults, but if wish, you can customize them.

### Before deploying

In the case of Traefik, Rancher, and Longhorn, we provide you with variables to configure everything you need.

On top of the above, for Nginx, Rancher, Cilium, Traefik and Longhorn, for maximum flexibility, we give you the ability to configure them even better via helm values variables (e.g. `cilium_values`, see the advanced section in the kube.tf.example for more).

### After deploying

Once the Cluster is up and running, you can easily customize most components like Traefik, Nginx, Rancher, Cilium, Cert-Manager and Longhorn by using HelmChartConfig definitions. See the [examples](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner#examples) section, for more information.

For other components like Calico and Kured (which uses manifests), we automatically save a `kustomization_backup.yaml` file in the root of your module during the deployment, so you can use that as a starting point. This is also useful when creating the HelmChartConfig definitions, as both HelmChart and HelmChartConfig definitions are very similar.

There is yet another option for power-users, to **force the new state of your kube.tf config on the cluster**, which will reconfigure all higher level components (Traefik, Rancher, etc.) to use the new configuration as updated in your `kube.tf` file. Basically it will update and re-apply all manifests including the HelmChart definitions. There is no destructive action on the cluster itself, just an alignment of the cluster state with the new configuration.

Do do so, you have to run:
  
```sh
terraform destroy -target 'module.kube-hetzner.null_resource.kustomization'
terraform apply
```

## Adding Extras

If you need to install additional Helm charts or Kubernetes manifests that are not provided by default, you can easily do so by using [Kustomize](https://kustomize.io). This is done by creating the `extra-manifests/kustomization.yaml.tpl` directory/file besides your `kube.tf`.

This file needs to be a valid `Kustomization` manifest, but it supports terraform templating! (The templating parameters can be passed via the `extra_kustomize_parameters` variable (via a map) to the module).

All files in the `extra-manifests` directory including the rendered version of `kustomization.yaml.tpl` will be applied to k3s with `kubectl apply -k` (which will be executed after and independently of the basic cluster configuration).

_You can use the above to pass all kinds of kubernetes YAML configs, including HelmChart and/or HelmChartConfig definitions (see the previous section if you do not know what those are in the context of k3s)._

## Examples

<details>
  
<summary>Useful Cilium commands</summary>

With Kube-Hetzner, you have the possibility to use Cilium as a CNI. It's very powerful and has great observability features. Below you will find a few useful commands.

- Check the status of cilium with the following commands (get the cilium pod name first and replace it in the command):

```sh
kubectl -n kube-system exec --stdin --tty cilium-xxxx -- cilium status
kubectl -n kube-system exec --stdin --tty cilium-xxxx -- cilium status --verbose
```

- Monitor cluster traffic with:

```sh
kubectl -n kube-system exec --stdin --tty cilium-xxxx -- cilium monitor
```

- See the list of kube services with:

```sh
kubectl -n kube-system exec --stdin --tty cilium-xxxx -- cilium service list
```

_For more cilium commands, please refer to their corresponding [Documentation](https://docs.cilium.io/en/latest/cheatsheet)._
  
</details>

<details>

<summary>Ingress with TLS</summary>

You have two options, the first is to use `Cert-Manager` to take care of the certificates, and the second is to let `Traefik` bear this responsibility.

_We advise you to use `Cert-Manager`, as it supports HA setups without requiring you to use the enterprise version of Traefik. The reason for that is that according to Traefik themselves, Traefik CE (community edition) is stateless, and it's not possible to run multiple instance of Traefik CE with LetsEncrypt enabled. Meaning, you cannot have your ingress be HA with Traefik if you use the community edition and have activated the LetsEncrypt resolver. You could however use Traefik EE (enterprise edition) to achieve that. Long story short, if you are going to use Traefik CE (like most of us), you should use cert-manager to generate the certificates. Source [here](https://doc.traefik.io/traefik/v2.0/providers/kubernetes-crd/)._

### Via Cert-Manager (recommended)

In your module variables, set `enable_cert_manager` to `true`, and just create your issuers as described here <https://cert-manager.io/docs/configuration/acme/>.

Then in your Ingress definition, just mentioning the issuer as an annotation and giving a secret name will take care of instructing cert-manager to generate a certificate for it! It simpler than the alternative, you just have to configure your issuer(s) first with the method of your choice.

Ingress example:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
spec:
  tls:
  - hosts:
    - '*.example.com'
    secretName: example-com-letsencrypt-tls
  rules:
  - host: '*.example.com'
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-service
            port:
              number: 80
```
  
_⚠️ In case of using Ingress-Nginx as ingress controller, if you choose to use the HTTP challenge method you need to do an additional step of adding variable `lb_hostname = "cluster.example.org"` to your kube.tf. You must set it to a FQDN that points to your LB address._
  
_This is to circumvent this known issue https://github.com/cert-manager/cert-manager/issues/466, also see https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/issues/354. Otherwise, you can just use the DNS challenge, which does not require any additional tweaks to work._

</details>

<details>

<summary>Single-node cluster</summary>

Running a development cluster on a single node without any high availability is also possible.

When doing so, `automatically_upgrade_os` should be set to `false`, especially with attached volumes the automatic reboots won't work properly. In this case, we don't deploy an external load-balancer but use the default [k3s service load balancer](https://rancher.com/docs/k3s/latest/en/networking/#service-load-balancer) on the host itself and open up port 80 & 443 in the firewall (done automatically).

</details>

<details>

<summary>Use in Terraform cloud</summary>

To use Kube-Hetzner on Terraform cloud, use as a Terraform module as mentioned above, but also change the execution mode from `remote` to `local`.

</details>

<details>

<summary>Configure add-ons with HelmChartConfig</summary>

For instance, to customize the Rancher install, if you choose to enable it, you can create and apply the following `HelmChartConfig`:

```yaml
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: rancher
  namespace: kube-system
spec:
  valuesContent: |-
    **values.yaml content you want to customize**
```

The helm options for Rancher can be seen here <https://github.com/rancher/rancher/blob/release/v2.6/chart/values.yaml>.

Same goes for all add-ons, like Longhorn, Cert-manager, and Traefik.

</details>

## Debugging

First and foremost, it depends, but it's always good to have a quick look into Hetzner quickly without logging in to the UI. That is where the `hcloud` cli comes in.

- Activate it with `hcloud context create Kube-hetzner`; it will prompt for your Hetzner API token, paste that, and hit `enter`.
- To check the nodes, if they are running, use `hcloud server list`.
- To check the network, use `hcloud network describe k3s`.
- To look at the LB, use `hcloud loadbalancer describe traefik`.

Then for the rest, you'll often need to log in to your cluster via ssh, to do that, use:

```sh
ssh root@xxx.xxx.xxx.xxx -i ~/.ssh/id_ed25519 -o StrictHostKeyChecking=no

```

Then, for control-plane nodes, use `journalctl -u k3s` to see the k3s logs, and for agents, use `journalctl -u k3s-agent` instead.

Last but not least, to see when the previous reboot took place, you can use both `last reboot` and `uptime`.

## Takedown

If you want to take down the cluster, you can proceed as follows:

```sh
terraform destroy -auto-approve
```

And if the network is slow to delete, just issue `hcloud load-balancer delete clustername` in another terminal tab! As the load-balancer is a ressource requested to the CCM by the ingress controller, and not deployed by Terraform itself.

Same thing for autoscaled nodes, if you have any, you can delete them with `hcloud server delete nodename` (run `hcloud server list` before to get the names).
In that latter case, if terraform gives you an error that the firewall was not deleted correctly, just re-run `terraform destroy -auto-approve` again.

_Also, if you had a full-blown cluster in use, it would be best to delete the whole project in your Hetzner account directly as operators or deployments may create other resources (like volumes) during regular operation._

<!-- CONTRIBUTING -->

## History

This project has tried two other OS flavors before settling on MicroOS. Fedora Server, and k3OS. The latter, k3OS, is now defunct! However, our code base for it lives on in the [k3os branch](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/tree/k3os). Do not hesitate to check it out, it should still work.

There is also a branch where openSUSE MicroOS came preinstalled with the k3s RPM from devel:kubic/k3s, but we moved away from that solution as the k3s version was rarely getting updates. See the [microOS-k3s-rpm](https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/tree/microOS-k3s-rpm) branch for more.

## Contributing

🌱 This project currently installs openSUSE MicroOS via the Hetzner rescue mode, making things a few minutes slower. To help with that, you could **take a few minutes to send a support request to Hetzner, asking them to please add openSUSE MicroOS as a default image**, not just an ISO. The more requests they receive, the likelier they are to add support for it, and if they do, that will cut the deployment time by half. The official link to openSUSE MicroOS is <https://get.opensuse.org/microos>, and their `OpenStack Cloud` image has full support for Cloud-init, which would probably very much suit the Hetzner Ops team!

Code contributions are very much **welcome**.

1. Fork the Project
1. Create your Branch (`git checkout -b AmazingFeature`)
1. Commit your Changes (`git commit -m 'Add some AmazingFeature')
1. Push to the Branch (`git push origin AmazingFeature`)
1. Open a Pull Request targeting the `staging` branch.

<!-- ACKNOWLEDGEMENTS -->

## Acknowledgements

- [k-andy](https://github.com/StarpTech/k-andy) was the starting point for this project. It wouldn't have been possible without it.
- [Best-README-Template](https://github.com/othneildrew/Best-README-Template) made writing this readme a lot easier.
- [Hetzner Cloud](https://www.hetzner.com) for providing a solid infrastructure and terraform package.
- [Hashicorp](https://www.hashicorp.com) for the amazing terraform framework that makes all the magic happen.
- [Rancher](https://www.rancher.com) for k3s, an amazing Kube distribution that is the core engine of this project.
- [openSUSE](https://www.opensuse.org) for MicroOS, which is just next level Container OS technology.

[contributors-shield]: https://img.shields.io/github/contributors/mysticaltech/kube-hetzner.svg?style=for-the-badge
[contributors-url]: https://github.com/mysticaltech/kube-hetzner/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/mysticaltech/kube-hetzner.svg?style=for-the-badge
[forks-url]: https://github.com/mysticaltech/kube-hetzner/network/members
[stars-shield]: https://img.shields.io/github/stars/mysticaltech/kube-hetzner.svg?style=for-the-badge
[stars-url]: https://github.com/mysticaltech/kube-hetzner/stargazers
[issues-shield]: https://img.shields.io/github/issues/mysticaltech/kube-hetzner.svg?style=for-the-badge
[issues-url]: https://github.com/mysticaltech/kube-hetzner/issues
[license-shield]: https://img.shields.io/github/license/mysticaltech/kube-hetzner.svg?style=for-the-badge
[license-url]: https://github.com/mysticaltech/kube-hetzner/blob/master/LICENSE.txt
[product-screenshot]: https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner/raw/master/.images/kubectl-pod-all-17022022.png
