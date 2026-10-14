# Self-managed AWS EC2 and Docker Compose

This guide installs the Zetaris Docker Compose bundle on an AWS virtual machine that you manage. It is separate from the [managed AWS cluster](managed-aws-cluster-guide.md) provisioned from Zetaris Cloud. For your own computer, use [Install locally](updated_zetaris_installation_guide.md).

The self-managed AWS VM steps have not been run on AWS. The sizing and cost estimates below were checked for the original guide dated 24 September 2026. Check current prices and account eligibility before launch. These VM estimates do not apply to managed clusters.

## 1. Obtain the bundle

Follow [Download and licensing](updated_zetaris_installation_guide.md#download-and-licensing) to obtain `zetaris-platform.zip` and registry access. Both installation paths use the same bundle.

**Which AWS free tier fits:** this bundle's preflight check requires at least 6 GB of memory available to Docker and recommends 8 GB. AWS accounts created on or after 15 July 2025 have a Free plan whose eligible instance types include `m7i-flex.large` (8 GiB), which meets that requirement. Accounts created before that date have the older free tier, which only covers 1 GiB `t2.micro`/`t3.micro` instances; those accounts need a paid instance such as `t3.xlarge`. [AWS free-tier instance types](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-free-tier-usage.html)

## 2. Set up the AWS account and session budget

1. Use your organisation's AWS account, or create an account from [AWS signup](https://aws.amazon.com/resources/create-account/). Complete the displayed email, contact, payment and identity verification steps, and select Basic Support for this quickstart. Obtain console access with permission to manage EC2, EBS, security groups and this session's billing information.
2. Choose the plan. A new account can stay on the **Free plan** and use `m7i-flex.large`, paid from its credits. The Free plan lasts six months or until the credits are used up, whichever comes first. Choose the **Paid plan** instead if your account was created before 15 July 2025, or if you want the larger `t3.xlarge`. To upgrade a Free-plan account, use **Upgrade Plan** in the console's Billing console; upgrading keeps any remaining credits until they expire.
3. Open **Billing and Cost Management → Credits**. Record the balance, expiry and applicable services. Redeem a separately issued promotional code there if applicable. New-customer credits start at $100, with up to $100 more earned through qualifying activities; a $200 balance is not automatic. [AWS plan and credit rules](https://aws.amazon.com/free/free-tier-faqs/)
4. In **Billing → Budgets**, create a $10 monthly cost budget with an email notification at $5 of actual cost. Include usage before credits when configuring the cost calculation so the alert remains useful during a credited session. This is a notification, not an automatic shutdown.
5. Schedule an **eight-hour session**, with the first hour reserved for provisioning, downloads, startup and verification. Set a reminder to terminate the demo before the eight hours end and before the Free plan or credits expire.

The following estimate uses AWS's On-Demand Linux rates for Asia Pacific (Sydney), `ap-southeast-2`, from the AWS price list published on 21 September 2026. AWS bills in US dollars.

| Item | Rate | Eight-hour session |
| --- | --- | --- |
| One `m7i-flex.large` (Free-plan eligible) | $0.1197/hour | $0.9576 |
| One public IPv4 address | $0.005/hour | $0.0400 |
| 40 GB gp3 at baseline performance | $0.096/GB-month | About $0.042 if deleted after eight hours, using a 730-hour month |
| **Estimated total** | | **About $1.04** |

If you keep the disk for a full month after that eight-hour session, the estimate becomes **$4.84**. Leaving the complete environment running for 730 hours is approximately **$94.87**.

With a `t3.xlarge` ($0.2112/hour) instead, the session costs about **$1.77**, keeping the disk for a month about **$5.57**, and running for 730 hours about **$161.67**.

Sources: [EC2 On-Demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/), [EBS pricing](https://aws.amazon.com/ebs/pricing/), [IPv4 pricing](https://aws.amazon.com/vpc/pricing/). These estimates exclude data transfer, taxes, snapshots, extra storage and any platform licence charge. Reserve **$10 of eligible credits** for this short session and check the price the console displays before launch. Use the [AWS Pricing Calculator](https://calculator.aws/) if changing the region or configuration.

## 3. Provision the VM

Use these instance settings. With the local sizing profile, the Zetaris containers used about 1.9 GiB of memory at idle and about 2.3 GiB after running the data recipes, on a machine giving Docker 7.7 GiB. An 8 GiB `m7i-flex.large` gives the same memory; its 2 vCPUs match the local profile's two cores, so expect slower queries than on a larger machine. Choose `t3.xlarge` (4 vCPUs, 16 GiB) for heavier work or on a Paid-plan account.

| Setting | Value |
| --- | --- |
| Region | Asia Pacific (Sydney), `ap-southeast-2` |
| AMI | Canonical Ubuntu Server 24.04 LTS, **x86_64** |
| Instance | `m7i-flex.large` (2 vCPUs, 8 GiB RAM), or `t3.xlarge` (4 vCPUs, 16 GiB RAM) |
| Disk | 40 GiB encrypted gp3 root volume; review delete-on-termination |
| Network | VPC subnet with internet access and a public IPv4 address for the SSH path below |
| Access | SSH key pair; inbound TCP 22 restricted to your public IP |
| Metadata | Require IMDSv2 |
| CPU credits | `t3.xlarge` only: Standard, with Unlimited disabled |

`t3.xlarge` is burstable: in Standard mode, sustained CPU use is limited to the credits it earns, which avoids surplus CPU-credit charges but can throttle long queries. [AWS CPU-credit configuration](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances-how-to.html)

This installation uses EC2, EBS, VPC networking and a security group. It does not require RDS, Kubernetes, a load balancer or a NAT gateway. S3 is optional for recipes that use your own stored files. Allow outbound access for package installation, image pulls and source queries. Keep application ports closed to inbound internet access for the SSH-tunnel setup.

In the EC2 console:

1. Select **Asia Pacific (Sydney)** and choose **Launch instance**. Name it `zetaris-quickstart`.
2. Select Ubuntu 24.04 LTS from Canonical and **64-bit (x86)**, then select `m7i-flex.large` (marked **Free tier eligible**) or `t3.xlarge`.
3. Create/download a `.pem` key pair, or select a key whose private file you already hold.
4. Under **Network settings**, select the default VPC and a subnet, enable a public IP, and create a security group allowing SSH only from **My IP**. Leave HTTP/HTTPS closed for the tunnel path.
5. Set the root disk to 40 GiB gp3 with encryption, baseline IOPS/throughput and delete-on-termination enabled. Under **Advanced details**, require IMDSv2; for `t3.xlarge`, also disable Unlimited CPU credits.
6. Review one instance and its costs, then launch. Wait for **Running** and successful instance status checks. Record its instance ID, public IPv4 and root-volume ID for access and teardown.

If the account has no default VPC, use an approved public subnet. To build an isolated one, create a VPC and subnet with non-overlapping private CIDRs, attach an internet gateway, and associate the subnet with a route table containing `0.0.0.0/0` to that gateway. Enable VPC DNS resolution and assign a public IP at launch. Record these additional resources for teardown. [EC2 launch procedure](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-launch-instance-wizard.html)

## 4. Install the bundle on the VM

Transfer the supplied archive, substituting your key path and instance address:

```bash
chmod 600 /path/to/key.pem
scp -i /path/to/key.pem zetaris-platform.zip ubuntu@YOUR_PUBLIC_IP:~/
ssh -i /path/to/key.pem ubuntu@YOUR_PUBLIC_IP
```

On the VM, install Docker Engine and the Compose plugin using [Docker's Ubuntu installation instructions](https://docs.docker.com/engine/install/ubuntu/). Install `unzip` if absent. Confirm your chosen account can run `docker version` and `docker compose version`; if group membership was changed, reconnect first. Use the same account for registry login and Compose operations.

```bash
unzip zetaris-platform.zip
cd zetaris-platform
docker login zetarishackathon.azurecr.io
./preflight.sh
```

Based on the bundle's thresholds, preflight is expected to pass on `m7i-flex.large` with warnings for memory below the recommended 8 GB and fewer than 4 CPUs. This has not been verified on AWS.

For an individual developer, use the supplied local `.env` and apply the configuration below, including a unique administrator password and `UI_PORT=127.0.0.1:3000`. The small local heap settings are a starting point even on the larger VM; increase them only when needed.

Edit the supplied `.env` in an editor. Keep the issued image settings and other supplied values. Set or confirm:

| Variable | Value or action |
| --- | --- |
| `ZETARIS_ADMIN_EMAIL` | Initial administrator email |
| `ZETARIS_ADMIN_PASSWORD` | Your own strong password, following the policy below |
| `ZETARIS_ADMIN_ORG` | Initial organisation name; choose before the first startup |
| `ZSPARK_DRIVER_MEM` | `2g` |
| `ZSPARK_DRIVER_CORES` | `2` |
| `ZSPARK_MASTER_URL` | `local[2]` |
| `ZETARIS_API_MAX_HEAP` | `1g` |
| `UI_PORT` | `127.0.0.1:3000` |
| `ALLOWED_ORIGINS` | `http://localhost:3000` |
| `GUI_URL` | `http://localhost:3000` |
| `COMPOSE_PROFILES` | Empty/unset for this SSH-tunnel setup |
| `ZETARIS_SEED_TPCH` | `true` to retain the supplied sample-data setup |

The administrator password must be at least eight characters and contain lowercase, uppercase, a digit and one of `$ @ ! % * ? &`. Other punctuation is rejected.

Keep `.env` private and out of version control:

```bash
chmod 600 .env
docker compose config --quiet
```

`--quiet` validates the configuration without printing resolved secrets.

```bash
chmod 600 .env
docker compose config --quiet
docker compose pull
docker compose up -d
docker compose ps --all
./verify.sh
```

From another terminal on your laptop, establish the tunnel and leave it running:

```bash
ssh -i /path/to/key.pem -N -o ExitOnForwardFailure=yes \
  -L 127.0.0.1:3000:127.0.0.1:3000 ubuntu@YOUR_PUBLIC_IP
```

Open <http://localhost:3000> on your laptop. The traffic travels over SSH, and the browser treats it as localhost.

## 5. Sign in and query

With the SSH tunnel running, follow [First login and initial verification](updated_zetaris_installation_guide.md#3-first-login-and-initial-verification), then [Get your first rows](../guides/first-dataset.md).

## 6. Stop and tear down

Stopping containers does not stop EC2 billing. For a temporary break, stop the instance in AWS; storage and retained public addresses can still incur charges. A non-reserved public IP can change at the next start, affecting SSH and DNS.

At the end of the quickstart:

1. Back up anything you need to retain.
2. Terminate the demo instance when its data can be discarded.
3. Inspect and remove unneeded retained EBS volumes, snapshots and Elastic IPs.
4. Remove this demo's unused security group and any optional recipe storage you created.
5. Check Billing for remaining resources and charges before the credit window ends.
