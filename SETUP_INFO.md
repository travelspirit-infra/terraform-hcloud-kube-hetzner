The hcloud token is exported in ./hcloud-env.sh
Use location nbg1
Use MicroOS (required by kube-hetzner module for automatic updates and security)
Use CX21. Create 3 instances at most. 1 control panel and 2 workers. 

Currently we are in a `https://github.com/kube-hetzner/terraform-hcloud-kube-hetzner.git` clone so prefer that solution.

Let's start with IPv4 but I want to move to IPv6 to save on costs. You can use the private network features if possible.
If possible. There is an already defined SSH key called `pcmulder`. Use that.