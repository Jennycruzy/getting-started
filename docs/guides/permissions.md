# Permissions in Zetaris

How access is controlled in Zetaris, who can create and change things, and how to give agents, applications and people only the access they need.

This guide summarizes the Zetaris Knowledge base and links to each page for the full detail. Where it adds this repository's own recommendation, it says so. Section 6 uses the wording of the [Lightning SQL command reference](zetaris-lightning-sql-commands.md) for the privilege each statement needs.

## 1. How access works

Access is decided in two layers:

- **What you can do.** Your user type and roles decide which parts of the platform you can use and whether you can create objects there.
- **What data you can see.** Object-level access decides which databases, data sources, data marts, pipelines and views you can reach, and with which privileges. Row and column policies can narrow that further.

Data access is **denied by default**: unless a user is granted access, they are denied access to data. Administrators manage both layers.

## 2. User types

Zetaris has two user types ([User Types](https://kbase.zetaris.com/knowledge/user-types)).

| | Administrator | End-user |
|---|---|---|
| **Creating, updating and deleting objects** | Full access across the platform, including the Data Catalog, Query Builder, Virtual Data Mart, Data Pipeline, Data Quality, Access Control and User Management. | Not described. Can write ad hoc SQL and keep personal saved views in the Schema Store View. |
| **What they see** | All registered data connections: file sources, databases, REST API connections and streaming sources. | Only the data provisioned to them: specific data objects, columns and rows, some of which may be masked or encrypted. |
| **How they reach data** | The platform. | The platform, or third-party tools over ODBC, JDBC or REST API. |

## 3. Users and roles

- **Creating users and roles.** Administrators create and delete local users and roles under **Management → Users** and **Management → Roles** (the Knowledge base calls this User Management). Accounts can be authenticated and created locally, or Zetaris can connect to an existing LDAP provider ([User Management](https://kbase.zetaris.com/knowledge/user-management)). The **Management** menu also lists SSO, LDAP and OAuth for external sign-in, and API Tokens for creating API keys.
- **Granting access to parts of the platform.** An administrator does this under **Management → Permissions**, which the Knowledge base calls Roles & Permissions ([Roles & Permissions](https://kbase.zetaris.com/knowledge/roles-permissions)). The page is described as granting "per-resource access (View / Execute) to roles and users". Roles are listed on one side and users on the other, with a search box. Expand a role or a user to see a table of resources, with a **View** and an **Execute** checkbox for each, then **Save**. The checkboxes in the column headings tick a whole column. The resources are:
  - Data Catalog
  - Query Builder
  - Virtual Data Mart
  - Data Pipeline
  - Unified Semantic Layer
  - NDP File System
- **Two privileges.** In the command reference, View is called Read and Execute is called Write (section 6).
  - **View** opens the resource. The user cannot create data objects in it, and sees only the objects shared with them through Access Control.
  - **Execute** lets the user create objects there, for example data marts in the Data Mart widget. The Knowledge base describes this combination as **View & Execute**.
- **Use roles.** A grant to a role applies to every member. Zetaris recommends granting access at the role level where you can, because it makes ongoing user management easier: someone new joins a role that already carries its permissions ([Data Object Level Security](https://kbase.zetaris.com/knowledge/controlling-table-level-access)).

**To give a non-administrator user access**

1. Create the user under **Management → Users**, and a role under **Management → Roles** if you are granting through a role. Assign the user to the role.
2. Under **Management → Permissions**, expand the role (or the user) and tick **View** on each resource it should open. Tick **Execute** only on a resource where it must create things. Click **Save**.
3. Give it access to the data it needs: assign the objects and set SELECT, and INSERT only if it must write (section 4).

## 4. Data object access

The **Access Control** widget controls access to databases, data sources, data marts, pipelines and views, for users and for roles ([Data Object Level Security](https://kbase.zetaris.com/knowledge/controlling-table-level-access)).

1. Select the object and use **Assign** and **Revoke** to choose which users or roles can reach it, then **Apply**.
2. For each assigned user or role, set the privileges: **SELECT** and **INSERT**. Tick one box for all tables, or set them per table.
3. Anything not granted is denied.

The same model is available in SQL: **assignments** attach a user or role to an object, and **grants** give SELECT or INSERT on a table or namespace. See sections [20, Users and Roles](zetaris-lightning-sql-commands.md#20-users-and-roles) and [21, Access Control](zetaris-lightning-sql-commands.md#21-access-control) of the command reference.

## 5. Row and column security

For finer control, policies restrict database, file and streaming sources down to columns and rows, for users and their roles ([Row and Column Level Security](https://kbase.zetaris.com/knowledge/controlling-row-level-access)).

- **Column policies** can be Grant, Masked, Encrypted, Deny or Hide. Masking takes a regular expression; encryption takes an encryption key, and both apply to string columns.
- **Row filters** take a filter expression, which Zetaris validates when you apply it.
- **Assignment.** A policy is assigned to a role or to an individual user. **User policies take precedence over role policies.** A table with no custom policy defaults to grant-all.
- **Where.** In the UI, open the table's **Configure Columns** in the Schema Store View under the NDP Fabric Builder. Policies can also be set through the SQL interface.

## 6. What each SQL statement needs

The command reference gives every statement a **Privileges** line, and states the rule: commands marked *Administrators only* are refused for other users ([General rules](zetaris-lightning-sql-commands.md#3-general-rules)). The table groups the statements this repository uses, in the command reference's own wording.

| Task | Statements | Privilege |
|---|---|---|
| Look at what exists, and read | `SHOW DATASOURCES`, `SHOW LIGHTNING DATABASES`, `SHOW NAMESPACES OR TABLES`, `LOAD USL`, `RUN DQ` | Signed-in users; assigned objects only |
| Register sources | `CREATE LIGHTNING DATABASE`, `CREATE LIGHTNING REST TABLE`, `CREATE LIGHTNING FILESTORE TABLE`, `CREATE SCHEMASTORE CONTAINER` | Administrators only |
| Schema store views | `CREATE SCHEMASTORE VIEW`, `UPDATE SCHEMASTORE VIEW` | Administrators or Query Builder Write users |
| Remove sources and views | `DROP SCHEMASTORE VIEW`, `DROP LIGHTNING DATABASE`, `DROP LIGHTNING DATABASE TABLE` | Administrators only |
| Unified Semantic Layer | `COMPILE USL`, `ACTIVATE USL TABLE`, `MATERIALIZE USL TABLE`, `REMOVE USL` | Administrators only |
| Data quality rules and results | `REGISTER DQ`, `SHOW DQ ALL VALID / INVALID` | Administrators only |
| Pipelines | `CREATE PIPELINE CONTAINER`, `DROP PIPELINE CONTAINER` | Administrators or Data Pipeline Write users |
| Data marts | `CREATE DATAMART`, `DROP DATAMART` | Administrators or Virtual Data Mart Write users |
| Users and roles | `CREATE ROLE`, `DROP USER`, `ASSIGN USER … TO ROLE` | Administrators or User Management Write users |
| Grants and assignments | `GRANT`, `REVOKE`, `ASSIGN object TO ROLE` | Administrators or Access Control Write users |

The Permissions page labels its two privileges View and Execute, the Knowledge base describes View and View & Execute, and the command reference names its privileges after the area they cover, such as "Query Builder Write". **View on a resource is what the command reference calls Read, and Execute is what it calls Write**: View on Data Pipeline is Data Pipeline Read, and Execute on Query Builder is Query Builder Write. An entry that says "Data Pipeline Read or Write users" therefore means users with View or Execute on Data Pipeline. The vocabularies will be aligned over time. Check each statement's entry in the command reference for the exact privilege.

## 7. How clients and applications connect

A client or application connects as a Zetaris user. End-users reach provisioned data through third-party tools using ODBC, JDBC or REST API ([User Types](https://kbase.zetaris.com/knowledge/user-types)).

- **REST API.** You need your Org ID, a Zetaris username and password, and an API key. A login call returns an `idToken` and a `refreshToken`; later calls send the API key as a bearer token with the required headers ([Accessing Zetaris using API](https://kbase.zetaris.com/knowledge/accessing-zetaris-using-api), [REST API](https://kbase.zetaris.com/knowledge/rest-api)). This repository's [client setup](../connections/client-setup.md) notes that an API key you create has your account's permissions. Keys are created per user under **Management → API Tokens**, described there as programmatic access keys: up to three per user, each shown in plaintext exactly once. The list shows each key's name, masked value, and when it was created, expires and was last used.
- **JDBC.** Use `jdbc:zetaris:lightning@<host>:<port>`, port `10000` by default, with the driver class `com.zetaris.lightning.jdbc.LightningDriver` and a Zetaris username and password ([Global Data Sharing](https://kbase.zetaris.com/knowledge/global-data-sharing-technical-design-and-implementation)).
- **ODBC.** Windows clients only. Create a User DSN with the server address, port `10000` and your Zetaris username and password ([Setup ODBC Driver](https://kbase.zetaris.com/knowledge/setup-odbc-connectivity)).

In each case the connection authenticates with a Zetaris login, so that user's roles, grants and policies decide what the client can see and do. The Knowledge base pages describe logging in with a user's own credentials and do not discuss accounts set up specially for applications; the next section is this repository's guidance on that.

## 8. Least privilege for agents and applications

**The practice this repository recommends: give every person, agent and application only the permissions it needs. Creating, updating and deleting is for administrators. Reading is for ordinary users.**

An administrator can do anything, so an agent or application that only reads should never hold that power. If its credentials leak, or it makes a mistake, the damage is limited to what a read-only user can reach.

| Who | Account | Gets | Typical work |
|---|---|---|---|
| **Read-focused agent or application** (the default) | Its own non-administrator user | SELECT on the objects it needs, through a role; INSERT only if it must write | Queries and analysis, dashboards and services, the starter flows that only read |
| **Builder agent** | An administrator, or the narrowest delegated Write role that covers the task | Only for the creation work, kept separate from read accounts | Creating sources, schema store views and USLs; the onboarding workflows in this repository |
| **People** | The same rule applies | Role-based access for what they do | A person who only queries needs no administrator rights |

**How to apply it**

1. **Separate building from reading.** Use an administrator login for setup and creation: the statements for registering sources and compiling or activating a USL are Administrators only (section 6). Then switch to a non-administrator user for analysis and for any agent or application that only reads.
2. **Give each agent and application its own user.** Then its access can be granted, reviewed and revoked on its own, without touching anyone else's.
3. **Grant through roles.** Create a role for the work (for example a read-only analysis role) and assign the user to it. Under **Management → Permissions**, give the role **View** on the resources it needs and leave **Execute** unticked. Then assign the objects to the role with SELECT. Add INSERT only where writing is needed.
4. **Prefer a delegated Write role to administrator.** A Write role, which is Execute on that resource in the Permissions page, such as Query Builder Write, is not the Administrator type. Give a builder agent the narrowest one that covers its task, and use a full administrator only for statements that are Administrators only.
5. **Narrow the data where it is sensitive.** Use row and column policies (section 5) so a read-focused user sees masked, encrypted or filtered data where appropriate.
6. **Local installs and managed AWS clusters can both add users.** Each starts with an administrator account. On a local install that is the account you sign in with first. On a managed AWS cluster it is your organization's administrator email and password, shown under **Organisations** on the cluster's Overview page (see [Managed AWS cluster](../install/managed-aws-cluster-guide.md)). In either one you can create further users and roles. Create a non-administrator user for read-focused work, and keep the administrator for building.
7. **Do not work around a refusal.** If a statement is refused because the account lacks a privilege, report it and ask for the right access. Do not switch to an administrator login to get past it unless you have been told to.

The credentials an agent or application uses stay in `.env.local` or your secret store, never in prompts, logs or source files. For a REST client, sign in as the non-administrator user and create the API key there (**Management → API Tokens**), so the key carries only that user's permissions. Name the key for the agent or application that uses it. A user can hold up to three keys, which allows a replacement to be issued before the old one expires, and the **Expires** and **Last used** columns show which keys are due for renewal or no longer in use.

## 9. Where to read more

**Zetaris Knowledge base**

- [User Types](https://kbase.zetaris.com/knowledge/user-types)
- [User Management](https://kbase.zetaris.com/knowledge/user-management)
- [Roles & Permissions](https://kbase.zetaris.com/knowledge/roles-permissions)
- [Data Object Level Security](https://kbase.zetaris.com/knowledge/controlling-table-level-access)
- [Row and Column Level Security](https://kbase.zetaris.com/knowledge/controlling-row-level-access)
- [What security features does Zetaris offer?](https://kbase.zetaris.com/knowledge/what-security-features-does-zetaris-offer)
- [Accessing Zetaris using API](https://kbase.zetaris.com/knowledge/accessing-zetaris-using-api) and [REST API](https://kbase.zetaris.com/knowledge/rest-api)
- [Setup ODBC Driver](https://kbase.zetaris.com/knowledge/setup-odbc-connectivity)

**In this repository**

- [Lightning SQL command reference](zetaris-lightning-sql-commands.md): each statement's privilege, and the SQL for users, roles, grants and assignments.
- [Client setup](../connections/client-setup.md): connecting a client or assistant, and its safety rules.
- [Troubleshooting](troubleshooting.md): permission errors and HTTP 403.
