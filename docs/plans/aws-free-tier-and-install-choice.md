# AWS Free Tier setup, install choice and managed AWS guide plan

**Status:** executed in the working tree (revision 4), awaiting review and commit.

## Goal and scope

Three changes to the install documentation, all published on the Pages site:

1. **A checklist** for opening an AWS Free Tier account and unlocking all of the $200 in credits, that a developer can follow top to bottom with links.
2. **A decision guide** on when to use a local install and when to use a managed AWS cluster, that leads into the two existing install guides.
3. **A revision of the managed AWS guide**, which today says only that AWS may bill the account. That is true of a standard AWS account but not of a Free Tier account, so the guide needs to account for both.

Out of scope: creating an AWS account, changing the platform install steps themselves, and the Pages deployment settings.

## What the sources say, and what you have told me

**From AWS's own pages** (links in "Sources"):

- New customers choose a **Free plan** or a **Paid plan** at sign-up. Both give **$100 in credits**, and you can earn **up to $100 more** by completing activities. That is the "$200".
- **Five activities, $20 each:** launch an EC2 instance and then terminate it; learn the basic configuration options for launching an RDS database; build a simple Lambda web app with a function URL; submit a prompt in the Amazon Bedrock text playground; set a cost budget in AWS Budgets. Credits can take up to 10 minutes to appear. No deadline for earning them is stated.
- **Free plan:** no charges while on it. It ends after **six months or when the credits are used up, whichever is first**. After that the account closes, AWS keeps the content for 90 days, and you can upgrade to a Paid plan within those 90 days. Remaining credits carry over to the Paid plan.
- **Credits expire 12 months after the account is opened.**
- The Free plan **withholds services that could drain credits** (for example Savings Plans, Reserved Instances, some Marketplace offers) and is **not eligible for other promotional credits**. It upgrades automatically if the account joins AWS Organizations, Control Tower or the Partner Network, among other triggers. AWS says it should not be used for sensitive data.
- Credits are for **one account per entity**, for accounts opened **after 15 July 2025**; older accounts keep the previous Free Tier. Not available in GovCloud or China regions.
- The Billing and Cost Management console shows the plan end date and credit balance, and AWS emails a usage alert at 85% of a free-usage limit.

**Resolved by you** (these were my open questions in revision 1):

| # | Question | Answer | Effect on the plan |
|---|---|---|---|
| U1 | Does the Quickstart stack and an EKS cluster run on a Free plan account? | Yes. First-party use of the Free Tier with the Free Zetaris system: it installs and runs, drawing the credits down over time. | **Recommend the Free plan.** No "upgrade to Paid" branch is needed. EKS and the other resources are not a separate concern. |
| U2 | What does the Mini cluster cost? | Not an hourly figure, but a test: running non-stop for about a week took the balance from roughly $150 to roughly $70. | A five-day event fits within the credits. I can state this as **Zetaris testing, approximate**, and not as an AWS price. |
| U3 | Do credits apply to EFS and the stack's other resources? | EFS works, and the cluster runs. | No caveat about eligible services is needed beyond AWS's own statement. |
| U4 | The exact sign-up screens and labels | You will not be producing these. | **Link to AWS for the sign-up flow** and describe only what AWS's documentation states. No invented screen labels. |
| U5 | Event-specific AWS credits? | None. Zetaris is free; AWS provides only its standard Free Tier. | Nothing about event credits. The Free plan's "no other promotions" rule is not a conflict. |

You also settled the install-choice stance (revision 3):

- **Hardware decides.** If your machine meets the local requirements, start local. If it does not, use AWS.
- **You can do both.** Nothing stops a user running a local install and an AWS cluster.
- **The Zetaris software, at this size, remains free.** Only AWS's own charges can apply, and on a Free Tier account those draw on credits.

One assumption to confirm: the one-week test was the **Mini** cluster size, as in the existing guide.

## Deliverables

### D1. AWS Free Tier checklist: `docs/install/aws-free-tier-checklist.md`

A checklist page (`- [ ]` items) titled for the outcome, "Set up an AWS Free Tier account and unlock all $200 in credits". Each item has a link and a "done when". Numbers and screens come from AWS's own pages, linked, with a "checked on" date, because AWS changed this program in 2025.

1. **Before you start:** you must be a new AWS customer with an account opened after 15 July 2025; credits cover one account per person; have an email address and a payment card ready (AWS's sign-up page will say what it needs); do not join the account to an AWS Organization, which upgrades the plan. If you already have an AWS account, say plainly that the credits will not apply. Do not suggest working around AWS's one-account rule.
2. **Create the account:** a link to AWS's sign-up, and one decision to make there: **choose the Free plan**. The page does not describe individual sign-up screens.
3. **Secure it:** turn on MFA for the root user, then set a cost budget with an email alert. The budget doubles as one of the five credit activities.
4. **Earn the $100 in activity credits,** one checklist item each, described at the level AWS states: EC2 (launch an instance, then terminate it), RDS (learn the basic launch configuration options), Lambda (a simple function-URL web app), Bedrock (submit a prompt in the text playground), Budgets (the cost budget from step 3). Each says what AWS counts, links AWS's page for it, says to clean up what you created, and says credits can take up to 10 minutes to appear.
5. **Check the balance:** where the Billing and Cost Management console shows the credit total and plan end date, and what the expected total looks like. Add calendar reminders for the six-month end and for credits running low.
6. **Know the clock:** the Free plan ends at six months or when the credits are gone; the account then closes and AWS deletes its content after 90 days. Credits expire 12 months after opening.
7. **Next step:** go to the managed AWS guide.

A short "if something looks wrong" list: credits not showing after 10 minutes, an unexpected plan upgrade, or the account closing.

### D2. Install decision guide: `docs/install/choose-install.md`

"Local install or AWS cluster?" A short page that leads into the two existing guides: a hardware rule that decides the choice, a note that you can do both, and a short comparison of the two options.

The page opens with the rule you gave: **if your machine meets the local requirements, start local; if it does not, use AWS.** The requirements are stated once, in a table taken from the local guide (Docker with at least 8 GB of memory and 4 CPUs available to it, 15 GB of free disk; the guide's own preflight check fails below 6 GB), so a reader can check their machine against them in a minute. It then says you can **do both**, and that at this size the Zetaris software is free in either place, so the only possible cost is AWS's, which a Free Tier account covers from credits.

A short comparison follows for people choosing between two workable options. Its factors come from the existing guides so nothing is invented: time to a first query (about 30 minutes to provision a cluster and 15 to delete it, per the managed guide, against the local pull-and-start); cost (nothing but your machine for local; credits on a Free Tier account for AWS); sharing with teammates (a cluster has a sign-in URL you can share, localhost does not); availability while you work (a laptop that sleeps against a cluster schedule); cleanup (retained AWS storage can keep drawing credits); permissions (CloudFormation and IAM in AWS, Docker on your machine); and how a coding assistant reaches the JDBC endpoint. These are things to weigh, not rules: the hardware check comes first.

### D3. Revise `docs/install/managed-aws-cluster-guide.md`

Specific passages that change:

- **"Before you start" cost bullet and the paragraph after it** ("Billable resources can incur charges..."): replace with a short "Costs and the AWS Free Tier" section. It says the guide runs on a Free Tier account, links D1, says what happens when the plan ends, and keeps the existing warning for standard accounts, so both kinds of reader get an accurate statement. It says the Zetaris software at this size is free and that only AWS's charges apply, drawn from credits on a Free Tier account. It includes the Zetaris testing observation (a cluster left running non-stop for about a week used roughly $80 of credits), labelled approximate and not a guarantee, with the point that **a five-day event fits within the $200**.
- **A pre-flight step:** check which plan the account is on and its credit balance before adding it in Zetaris.
- **Section 6, "Retained storage and charges":** add that retained EFS and S3 keep drawing on credits until you delete them, and that on a Free plan the account closes when credits run out or at six months, after which AWS deletes the data after 90 days. That matters for a team that leaves a cluster running.
- **Closing line** ("Use the current AWS account notice...") stays, since the in-product notice remains the authority for the actual estimate.

The step-by-step cluster instructions themselves do not change.

### Cross-cutting site changes

- **`website/build.mjs`:** the page list is an explicit publication boundary, so D1 and D2 need two entries in its `Installation` group (the list order sets the sidebar order). The builder throws on a link to a missing file, so the new pages and every link to them must resolve.
- **`START-HERE.md`:** the prerequisites table gets short links to the decision guide and the Free Tier checklist, without lengthening the page.
- **Cross-links** from the local and managed guide intros to the decision guide. Optionally `docs/guides/project-paths.md` and `recipe-readiness.md`, which say "local or AWS instance".
- **Deployment:** the workflow watches `docs/**` and `START-HERE.md`, so these edits rebuild on the branch it deploys from. Which branch that is remains the separate question from earlier.

## Order of work (after you approve)

1. Write D1, then D2, then edit D3, one commit each.
2. Add the site-list entries and `START-HERE.md` links in a fourth commit.
3. Verify: the repo's broken-link script, a local site build (`npm ci --prefix website && npm run build --prefix website`), and a read of the three generated pages.
4. Open one PR.

## Answers received

1. **Cost observation:** publish it as Zetaris testing, approximate. The test was the **Mini** size.
2. **"Free":** the Zetaris developer/free edition is scoped to the size available per platform, local or AWS, and nothing more. No support other than the GitHub getting-started repository, the Zetaris Knowledge base and Discord. Zetaris does not charge for storage.
3. **Names and placement:** `docs/install/aws-free-tier-checklist.md` and `docs/install/choose-install.md`, both on the site.
4. **Existing AWS accounts:** say that an existing account can host a small install, but it consumes AWS cost; a new account gets the free tier.
5. **Activity wording:** AWS's own words with links, no click paths.

## Execution record

Drafted in the working tree on `claude/aws-free-tier-docs`, **not committed**, for review: the two new pages, the managed guide revision, the `website/build.mjs` entries, the `START-HERE.md` links and three cross-links. Verified: all 14 external links return 200, no broken relative links, and the site builds (26 pages). Open item: the Zetaris Discord has no link on the new pages because no invite URL is in the repo.

## Risks

- **AWS changes its program** (it did in July 2025). Mitigation: link to AWS for numbers, add a "checked on" date, avoid restating terms I cannot keep current.
- **Account closure deletes data.** A Free plan account that runs out of credits closes and loses its data after 90 days. The guide must say this clearly, because a running cluster consumes credits.
- **The cost observation is one test.** It depends on cluster size, region and uptime; the wording must say so.
- **Checklist depth.** Without sign-up and console screenshots, the checklist is only as detailed as AWS's own documentation. It can send people to the right pages but cannot walk them through every click.
- **Not an AWS or legal statement.** The pages summarize AWS's terms and link to them, and say that AWS's own pages govern.

## Sources

- [Choosing a plan (AWS Billing docs)](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/free-tier-plans.html)
- [AWS Free Tier update: up to $200 in credits (AWS News Blog)](https://aws.amazon.com/blogs/aws/aws-free-tier-update-new-customers-can-get-started-and-explore-aws-with-up-to-200-in-credits)
- [AWS Free Tier terms](https://aws.amazon.com/free/terms)
- [Tracking your AWS Free Tier usage](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/tracking-free-tier-usage.html)
- [AWS Free Tier](https://aws.amazon.com/free)
