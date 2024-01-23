# Terraform-Project-Gallery

* Industry grade terraform project collection using aws cloud

### Project 1: AWS Private/Public Subnet Application Deployment

![](./VPC-concepts/aws-private-subnet-vm.png)

* concept: 

When deploying within a public cloud solution provider, we consistently prioritize the security aspect. AWS has presented the reference architecture outlined below for secure project deployment, wherein our primary application is secured within a private subnet, with all internet traffic being managed through the public subnet and application load balancer. To address scalability concerns, EC2 instances are instantiated through the use of an auto-scaling group.

- The public subnet is exposed to the internet via an internet gateway, and internet traffic is managed through the application load balancer.

- Routing of public to private traffic is handled through routing tables.

- NAT gateways provide IP masking for the application server when communication with the external world is required.

- Security groups, which are stateful, are employed to manage instance-level inbound and outbound traffic.

- Network Access Control Lists (NACL) operate in a stateless manner and govern inbound and outbound traffic within the subnet boundary.

> check ```aws-vpc``` folder for the terraform codebase. 