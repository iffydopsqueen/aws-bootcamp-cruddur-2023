# Week 4 — Postgres and RDS

## Required Homework/Tasks

All the tasks under this section is done using `Gitpod` workspace.

### 1. Working with PostgreSQL

Before you start up this section, make sure you have already installed Postgres and its client like we did in the previous weeks. After you are sure it has been installed, let's test out its connection. Use the following commands to test it out.

```bash
# start up your application
docker compose up 

# connect to postgres client
psql -U postgres --host localhost 
```

Some of the postgres commands to play with:

```sql
# Postgres commands
\x on -- expanded display when looking at data
\q -- Quit PSQL
\l -- List all databases
\c database_name -- Connect to a specific database
\dt -- List all tables in the current database
\d table_name -- Describe a specific table
\du -- List all users and their roles
\dn -- List all schemas in the current database
CREATE DATABASE database_name; -- Create a new database
DROP DATABASE database_name; -- Delete a database
CREATE TABLE table_name (column1 datatype1, column2 datatype2, ...); -- Create a new table
DROP TABLE table_name; -- Delete a table
SELECT column1, column2, ... FROM table_name WHERE condition; -- Select data from a table
INSERT INTO table_name (column1, column2, ...) VALUES (value1, value2, ...); -- Insert data into a table
UPDATE table_name SET column1 = value1, column2 = value2, ... WHERE condition; -- Update data in a table
DELETE FROM table_name WHERE condition; -- Delete data from a table
```

**Step 1 - CREATE A DATABASE**

Run the following commands inside your Postgres client. Be sure you are logged into the client before attempting these commands. 

```sql
CREATE DATABASE cruddur;    # create a database in postgres

\l    # confirm the database has been created 
\q    # quit the database 
```
![Image of Creating Cruddur database](assets/creating-cruddur-database.png)

**Step 2 - CREATE A TABLE FOR THE DATABASE**

To create a table in the database, we will be using our `schema` file to give the database a structure. First, we have to create the `schema` file that creates the structure.

```bash
# let's create a db folder with a schema file 
mkdir backend-flask/db

# create the schema file 
touch backend-flask/db/schema.sql
```

Now let's add the following commands to our `schema.sql` file:

```sql
-- UUID -> Universally Unique Identifier 
-- this feature generates long unique identifiers for our users instead of just using 1, 2, or 3 as our IDs 

-- Adding a UUID Extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

Let's run the file to execute the commands:

```bash
# you have to be in the backend-flask directory 
psql cruddur < db/schema.sql -h localhost -U postgres

OR

# if you choose to run it in your root project 
psql cruddur < backend-flask/db/schema.sql -h localhost -U postgres
```

**Step 3 - ADD MORE TABLES TO THE `cruddur` DATABASE**

Still in the `backend-flask/db/schema.sql` file, let's add the following tables:

```sql
-- the name public is like a namespace for schemas in postgres 
-- you can still create the tables without specifying "public"

-- deletes the table "users" if it already exists
DROP TABLE IF EXISTS public.users; 

-- create a table called "users"
CREATE TABLE public.users (
  uuid UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  display_name text,
  handle text,
  cognito_user_id text,
  created_at TIMESTAMP default current_timestamp NOT NULL
);


-- deletes the table "activities" if it already exists
DROP TABLE IF EXISTS public.activities;

-- create a table called "activities"
CREATE TABLE public.activities (
  uuid UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
	user_uuid UUID NOT NULL,
  message text NOT NULL,
  replies_count integer DEFAULT 0,
  reposts_count integer DEFAULT 0,
  likes_count integer DEFAULT 0,
  reply_to_activity_uuid integer,
  expires_at TIMESTAMP,
  created_at TIMESTAMP default current_timestamp NOT NULL
);

# Note: schemas are like the excel files, and the tables/views are like the sheets in an excel file
```
![Image of Table Creation in Cruddur 1](assets/table-creation-in-cruddur-1.png)

![Image of Table Creation in Cruddur 2](assets/table-creation-in-cruddur-2.png)


### 2. Connect to the Postgres DB 

Instead of using the traditional method of signing in and entering your password with this command:

```bash
# connect to postgres client
psql -U postgres --host localhost
```

We will be setting up our connection to automatically detect our credentials and sign us in without requiring a password. 

```bash
# https://stackoverflow.com/questions/3582552/what-is-the-format-for-the-postgresql-connection-string-url
postgresql://[user[:password]@][netloc][:port][/dbname][?param1=value1&...]

# Automatically connect to Postgres without needing a password
# make sure to try out the command on your terminal before exporting to your terminal
CONNECTION_URL="postgresql://postgres:password@127.0.0.1:5432/cruddur"

OR

CONNECTION_URL="postgresql://postgres:password@localhost:5432/cruddur"

# now export it to your bash terminal
export CONNECTION_URL="postgresql://postgres:password@127.0.0.1:5432/cruddur"
gp env CONNECTION_URL="postgresql://postgres:password@127.0.0.1:5432/cruddur"

OR

export CONNECTION_URL="postgresql://postgres:password@localhost:5432/cruddur"
gp env CONNECTION_URL="postgresql://postgres:password@localhost:5432/cruddur"

# Test configuration
psql $CONNECTION_URL
```

### 3. Provision an RDS instance 

You can choose to provision by console or CLI. I will be using the CLI to provision mine. This configuration and set up will take about 10-15 mins. 

**Note:** When not in use, temporarily stop the database instance to avoid incurring costs. But remember, it's just for 7 days. After 7 days is up, the database starts up again. 

To create the RDS instnace with a Postgres engine, run the following command:

```bash
# confirm your AWS credentials are set
aws sts get-caller-identity

# provision an instance 
aws rds create-db-instance \
  --db-instance-identifier cruddur-db-instance \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --engine-version  14.6 \
  --master-username cruddurroot \ # change this to whatever name of your choice
  --master-user-password MYpassword789 \ # same here
  --allocated-storage 20 \
  --availability-zone us-west-2a \ # change this to your own availability zone
  --backup-retention-period 0 \
  --port 5432 \
  --no-multi-az \ # to avoid spend
  --db-name cruddur \
  --storage-type gp2 \ # you can change this storage type to a higher performing storage
  --publicly-accessible \
  --storage-encrypted \
  --enable-performance-insights \
  --performance-insights-retention-period 7 \
  --no-deletion-protection

# If the above style doesn't work in your terminal, do this instead
# the CLI can be crazy sometimes
aws rds create-db-instance --db-instance-identifier cruddur-db-instance --db-instance-class db.t3.micro --engine postgres --engine-version 14.6 --master-username cruddurroot --master-user-password MYpassword789 --allocated-storage 20 --availability-zone us-west-2a --backup-retention-period 0 --port 5432 --no-multi-az --db-name cruddur --storage-type gp2 --publicly-accessible --storage-encrypted --enable-performance-insights --performance-insights-retention-period 7 --no-deletion-protection
```

**-- Connect to the RDS instance**

Now let’s set the same connection configuration for our `prd` server, which is the RDS instance in AWS.

```bash
# connection URL for our RDS instance 
PRD_CONNECTION_URL="postgresql://<MASTER-USERNAME>:<MASTER-USER-PASSWORD>@<RDS_endpoint_from_AWS>:5432/cruddur"

# now export it to your bash terminal
export PRD_CONNECTION_URL="postgresql://<MASTER-USERNAME>:<MASTER-USER-PASSWORD>@<RDS_endpoint_from_AWS>:5432/cruddur"
gp env PRD_CONNECTION_URL="postgresql://<MASTER-USERNAME>:<MASTER-USER-PASSWORD>@<RDS_endpoint_from_AWS>:5432/cruddur"

# Test configuration
psql $PRD_CONNECTION_URL
```

### 4. Creating BASH scripts for DB Operations

**SCRIPT 1 - Script for connection**

Let’s create a connection script. In our `backend-flask/bin`, create a file called `db-connect`:

```bash
touch backend-flask/bin/db-connect 
```

Add the following configurations to the file, `backend-flask/bin/db-connect` just created:

```bash
#! /usr/bin/bash

# Make our prints a lot nicer 
CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="Connecting to database..."  
printf "${CYAN}=== ${LABEL}${NO_COLOR}\n"

# conditional statement for connection
# add prd connection 
if [ "$1" = "prd" ]; then
  echo "Running in production mode"
  URL=$PRD_CONNECTION_URL
else
  URL=$CONNECTION_URL
fi

# Connect to our database without needing a password
psql $URL
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/db-connect

# execute the script 
./bin/db-connect OR ./backend-flask/bin/db-connect

OR

sh bin/db-connect OR sh backend-flask/bin/db-connect
```

**SCRIPT 2 - Script for dropping DB**

Let’s create a script to drop our database anytime we want. In our `backend-flask/bin`, create a file called `db-drop`:

```bash
touch backend-flask/bin/db-drop 
```

Add the following configurations to the file, `backend-flask/bin/db-drop` just created:

```bash
#! /usr/bin/bash
set -e            # exit if there's an error

NO_DB_CONNECTION_URL=$(sed 's/\/cruddur//g' <<<"$CONNECTION_URL")

# drop the database
psql $NO_DB_CONNECTION_URL -c "DROP database IF EXISTS cruddur;"

RED="\e[31m"
NO_COLOR="\e[0m"

echo -e "${RED}Dropped database ${NO_COLOR}"
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command in your terminal to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/db-drop

# execute the script 
./bin/db-drop OR ./backend-flask/bin/db-drop

OR

sh bin/db-drop OR sh backend-flask/bin/db-drop
```

**SCRIPT 3 - Script for creating DB**

Let’s write a script that creates our database anytime we want. In our `backend-flask/bin`, create a file called `db-create`:

```bash
touch backend-flask/bin/db-create 
```

Add the following configurations to the file, `backend-flask/bin/db-create` just created:

```bash
#! /usr/bin/bash

set -e           # exit if there's an error

# Make our prints a lot nicer 
CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="Creating database..."  
printf "${CYAN}=== ${LABEL}${NO_COLOR}\n"

NO_DB_CONNECTION_URL=$(sed 's/\/cruddur//g' <<<"$CONNECTION_URL")

# create a database
psql $NO_DB_CONNECTION_URL -c "CREATE database cruddur;"
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/db-create

# execute the script 
./bin/db-create OR ./backend-flask/bin/db-create

OR

sh bin/db-create OR sh backend-flask/bin/db-create
```

**SCRIPT 4 - Script for loading our schema**

Let’s create a script to load our schema onto our database. In our `backend-flask/bin`, create a file called `db-schema-load`:

```bash
touch backend-flask/bin/db-schema-load 
```

Add the following configurations to the file, `backend-flask/bin/db-schema-load` just created:

```bash
#! /usr/bin/bash

set -e              # exit if there's an error

# Make our prints a lot nicer 
CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="Loading schema..."  
printf "${CYAN}== ${LABEL}${NO_COLOR}\n"

# conditional statement for connection
if [ "$1" = "prd" ]; then
  echo "Running in production mode"
  URL=$PRD_CONNECTION_URL
else
  URL=$CONNECTION_URL
fi

# Load schema into the database
psql $URL cruddur < backend-flask/db/schema.sql
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/db-schema-load

# execute the script 
./bin/db-schema-load OR ./backend-flask/bin/db-schema-load

OR

sh bin/db-schema-load OR sh backend-flask/bin/db-schema-load
```

**SCRIPT 5 - Script for seeding data**

Let’s create a script to seed data to our database. For this script, we will also need an SQL script with seed data in it, `seed.sql` to feed our database mock data. 

- For our `seed.sql` file, here are the steps to create and add mock data:

- In our `backend-flask/db`, create a file called `seed.sql`:

```bash
touch backend-flask/db/seed.sql 
```

Add the following configurations to the file, `backend-flask/db/seed.sql` just created:

```sql
-- insert mock data into our tables
INSERT INTO public.users (display_name, handle, cognito_user_id)
VALUES
  ('Andrew Brown', 'andrewbrown' ,'MOCK'),
  ('Oppy Queen', 'dopsqueen' ,'MOCK'),
  ('Andrew Bayko', 'bayko' ,'MOCK'),
  ('Zeus Sucker', 'godofthunder' ,'MOCK');

INSERT INTO public.activities (user_uuid, message, expires_at)
VALUES
  (
    (SELECT uuid from public.users WHERE users.handle = 'dopsqueen' LIMIT 1),
    'This was imported as seed data!',
    current_timestamp + interval '10 day'
  )
```

- For our `db-seed` file, here are the steps to create the script for mocking data: 

- In our `backend-flask/bin`, create a file called `db-seed`:

```bash
touch backend-flask/bin/db-seed 
```

Add the following configurations to the file, `backend-flask/bin/db-seed` just created:

```bash
#! /usr/bin/bash

# Make our prints a lot nicer 
CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="Seeding data..." 
printf "${CYAN}== ${LABEL}${NO_COLOR}\n"

seed_path="$(realpath .)/db/seed.sql"
echo $seed_path

# conditional statement for connection
if [ "$1" = "prd" ]; then
  echo "Running in production mode"
  URL=$PROD_CONNECTION_URL
else
  URL=$CONNECTION_URL
fi

psql $URL cruddur < $seed_path
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/db-seed

# execute the script 
./bin/db-seed OR ./backend-flask/bin/db-seed

OR

sh bin/db-seed OR sh backend-flask/bin/db-seed
```

**--View our mock data**

- First we need to log into our postgres client with our newly created scripts.

```bash
./bin/db-connect OR ./backend-flask/bin/db-connect

OR

sh bin/db-connect OR sh backend-flask/bin/db-connect
```

- Inside the postgres database, run the following commands:

```sql
# see the contents of your activities table 
SELECT * FROM activities;

# to see the expanded display of the table - it makes it easier to view records 
\x
OR 
\x auto # automatically display the expanded version of the table
SELECT * FROM activities;
```

**SCRIPT 6 - Script for viewing DB sessions**

Let’s create a script to view our database sessions. In our `backend-flask/bin`, create a file called `db-sessions`:

```bash
touch backend-flask/bin/db-sessions 
```

Add the following configurations to the file, `backend-flask/bin/db-sessions` just created:

```bash
#! /usr/bin/bash

# Make our prints a lot nicer 
CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="Current db sessions..."
printf "${CYAN}== ${LABEL}${NO_COLOR}\n"

# conditional statement for connection
if [ "$1" = "prd" ]; then
  echo "Running in production mode"
  URL=$PRD_CONNECTION_URL
else
  URL=$CONNECTION_URL
fi

NO_DB_URL=$(sed 's/\/cruddur//g' <<<"$URL")

psql $NO_DB_URL -c "select pid as process_id, \
       usename as user,  \
       datname as db, \
       client_addr, \
       application_name as app,\
       state \
from pg_stat_activity;"
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/db-connect

# execute the script 
./bin/db-sessions OR ./backend-flask/bin/db-sessions

OR

sh bin/db-sessions OR sh backend-flask/bin/db-sessions
```

![Image of database sessions](assets/database-sessions.png)

If you have so many database sessions opened like the picture above, go ahead and do a `docker compose down` and then start it up again doing a `docker compose up`. This kills all active and idle sessions running. 


**SCRIPT 7 - Setup script for DB**

Let’s create a script that sets up our database using the above created scripts. In our `backend-flask/bin`, create a file called `db-setup`:

```bash
touch backend-flask/bin/db-setup 
```

Add the following configurations to the file, `backend-flask/bin/db-setup` just created:

```bash
#! /usr/bin/bash

# Make our prints a lot nicer 
CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="Setting up database..."  
printf "${CYAN}=== ${LABEL}${NO_COLOR}\n"

bin_path="$(realpath .)/bin"

source "$bin_path/db-drop"
source "$bin_path/db-create"
source "$bin_path/db-schema-load"
source "$bin_path/db-seed"
```

To ensure you have the right permissions to execute the newly created script, run the following commands:

```bash
# by default, you will get a permission denied when trying to run a script you just created
# run this command to grant it permission - https://www.tutorialspoint.com/unix/unix-file-permission.htm
chmod 555 backend-flask/bin/db-setup

# execute the script 
./bin/db-setup OR ./backend-flask/bin/db-setup

OR

sh bin/db-setup OR sh backend-flask/bin/db-setup
```


### 5. View DB using DATABASE EXPLORER on VScode

To use this feature, you have to install the extension on VSCode. After installation, open it on the side panel of your editor like so;

![Image of DB Explorer on VSCode](assets/db-explorer-on-vscode.png)

- Now to connect to a DB server, click the `+` sign by the right hand of your side panel. Navigate to the `Postgres` tab and try connecting using the right credentials. 

![Image of Postgres Connection Using DB Explorer](assets/postgres-connection-using-db-explorer.png)

- After connection, go ahead and play around with the database.

![Image of the DB Explorer After Connection](assets/db-explorer-after-connection.png)


### 6. Set Up Postgres Driver 

PostgreSQL Drivers, also referred to as "client libraries", allow developers to interface with PostgreSQL from various programming languages. Since our application is done with `Flask`, we will be using the `python` driver. Click this [link](https://www.psycopg.org/psycopg3/) to learn more. 

- Now let's install the required libraries to use the `postgres - python` driver. In your `backend-flask/requirements.txt` file, add the following lines of code:

```
# add these to your requirements.txt file
psycopg[binary]
psycopg[pool]
```

- To install those libraries you've just added unto the application, run this command in your terminal:

```bash
pip install -r backend-flask/requirements.txt
```

***Connection Pooling***

There are a certain amount of connections your database is meant to handle. Some of those connections could be `idle` or `active`. That is why we are creating a connection pool. Pooling helps you manage several db connections. With connection pooling, instead of opening, maintaining, and closing a connection when a user sends a request, the server will assign an active connection to the user. 

In summary, connection pooling is simply ***the method of creating a pool of connections and caching those connections so that it can be reused again***. Learn more [here](https://arctype.com/blog/connnection-pooling-postgres/#:~:text=comes%20into%20play.-,What%20is%20connection%20pooling%3F,active%20connection%20to%20the%20user).

- Now let's create a `db.py` file for this pool connection. 

```bash
# create file in the lib directory
touch backend-flask/lib/db.py
```

- Add the following contents to the new file you just created, `backend-flask/lib/db.py`:

```python
from psycopg_pool import ConnectionPool
import os

def query_wrap_object(template):
  sql = f"""
  (SELECT COALESCE(row_to_json(object_row),'{{}}'::json) FROM (
  {template}
  ) object_row);
  """
  return sql

def query_wrap_array(template):
  sql = f"""
  (SELECT COALESCE(array_to_json(array_agg(row_to_json(array_row))),'[]'::json) FROM (
  {template}
  ) array_row);
  """
  return sql

connection_url = os.getenv("CONNECTION_URL")
pool = ConnectionPool(connection_url)
```

- Let's pass our environment variable for DB connection. We will be adding those in our `docker-compose.yml` file. 

```yaml
# in the environment variable section
CONNECTION_URL: ${CONNECTION_URL}
```

- Go ahead and make the following changes to your `backend-flask/services/home_activities.py` file:

```python
from lib.db import pool, query_wrap_array

      sql = query_wrap_array("""
      SELECT
        activities.uuid,
        users.display_name,
        users.handle,
        activities.message,
        activities.replies_count,
        activities.reposts_count,
        activities.likes_count,
        activities.reply_to_activity_uuid,
        activities.expires_at,
        activities.created_at
      FROM public.activities
      LEFT JOIN public.users ON users.uuid = activities.user_uuid
      ORDER BY activities.created_at DESC
      """)
      print(sql)

# DELETE THESE LINES 
      results = [{
        'uuid': '68f126b0-1ceb-4a33-88be-d90fa7109eee',
        'handle':  'Andrew Brown',
        'message': 'Cloud is fun!',
        'created_at': (now - timedelta(days=2)).isoformat(),
        'expires_at': (now + timedelta(days=5)).isoformat(),
        'likes_count': 5,
        'replies_count': 1,
        'reposts_count': 0,
        'replies': [{
          'uuid': '26e12864-1c26-5c3a-9658-97a10f8fea67',
          'reply_to_activity_uuid': '68f126b0-1ceb-4a33-88be-d90fa7109eee',
          'handle':  'Worf',
          'message': 'This post has no honor!',
          'likes_count': 0,
          'replies_count': 0,
          'reposts_count': 0,
          'created_at': (now - timedelta(days=2)).isoformat()
        }],
      },
      {
        'uuid': '66e12864-8c26-4c3a-9658-95a10f8fea67',
        'handle':  'Worf',
        'message': 'I am out of prune juice',
        'created_at': (now - timedelta(days=7)).isoformat(),
        'expires_at': (now + timedelta(days=9)).isoformat(),
        'likes': 0,
        'replies': []
      },
      {
        'uuid': '248959df-3079-4947-b847-9e0892d1bab4',
        'handle':  'Garek',
        'message': 'My dear doctor, I am just simple tailor',
        'created_at': (now - timedelta(hours=1)).isoformat(),
        'expires_at': (now + timedelta(hours=12)).isoformat(),
        'likes': 0,
        'replies': []
      }
      ]

      if cognito_user_id != None:
        extra_crud = {
          'uuid': '248959df-3079-4947-b847-9e0892d1bab4',
          'handle':  'Sandy',
          'message': 'My dear brother, it the humans that are the problem',
          'created_at': (now - timedelta(hours=1)).isoformat(),
          'expires_at': (now + timedelta(hours=12)).isoformat(),
          'likes': 1042,
          'replies': []
        }
        results.insert(0,extra_crud)

      span.set_attribute("app.result_length", len(results))

# ADD THESE LINES 
      with pool.connection() as conn:
        with conn.cursor() as cur:
          cur.execute(sql)
          # this will return a tuple
          # the first field being the data
          json = cur.fetchone()
      return json[0]
```

- After the above configurations, let's go ahead and spin up our application to be sure everything still works. 

```bash
# start up app
docker compose up
```

You should see some data in your front-end UI like so:

![Image of FrontEnd After Connection Pooling](assets/frontend-after-connection-pool.png)

If you are encountering this error, follow the instructions below to resolve them.

![Image of Error After Connection Pooling](assets/error-after-connection-pooling.png)


**Troubleshooting**

It is a connection problem with the Postgres database. We just need to hard code our connection environment variable and that should be resolved. Do that by changing the value of our `CONNECTION_URL` in our `docker-compose.yml` file.

```
CONNECTION_URL="${CONNECTION_URL}"

# we had this in our bash terminal when we exported it 
CONNECTION_URL="postgresql://postgres:password@localhost:5432/cruddur"

# add this instead in your docker-compose.yml file
CONNECTION_URL : "postgresql://postgres:password@db:5432/cruddur"
# the 'db' is from the service name we called our postgres in the docker-compose file
```

Make sure to restart your `gitpod` environment so changes are reflected. Gitpod doesn’t automatically detect those updates sometimes. 


### 7. Establish a connection to our RDS instance

Navigate to `RDS` in your AWS console, and select the database and click `Start` , if you stopped it before.

If you try connecting to the `RDS` instance via CLI, your command is going to hang. That’s because of the `security group rule` attached to the RDS instance. Follow the steps below to fix the issue:

- Navigate to your `RDS` instance in your AWS console
- Select the instance
- Under the `Connectivity & security`, you should see a section that says `Security` . Click on the VPC security group you see. That will take you to the security group’s page
- Scroll down the page and select the `inbound rules` tab
- Under the `inbound rules` tab, click on `Edit` to make changes to our rules

![Image of Security Group Inbound rule](assets/security-grp-inbound-rule.png)

- Click on `Add rule` to add a new rule
- Add the following to the new rule you are creating
 	- Type: `PostgreSQL`
 	- Protocol: `TCP`
	- Port range: `5432`
	- Source: `Custom` `<my_GITPOD_IP>`
	- Description: `GITPOD`

![Image of Editing Security Group Inbound rule](assets/editing-security-grp-inbound-rule.png)

To check the current `IP` address of your `gitpod` workspace, use the command below:

```bash
# set this in our terminal
export GITPOD_IP=$(curl ifconfig.me)

echo $GITPOD_IP
```

Now let's try connecting to our RDS instance through the CLI

```bash
# connect to RDS instance 
psql $PRD_CONNECTION_URL
```

**Note:** Anytime we want to connect to our RDS instance, we have to change our `GITPOD_IP`. Instead of having to do that all the time, let’s create a script to simplify it for us.

- First, we need our `security_grp_ID` and the `security_grp_rule_ID`, you should see that in your AWS console under security groups. For the rule ID, you have to `Edit` your inbound rules to see it. 

- Copy those IDs, and let’s set it as an env variable

```bash
# set security group as an env variable 
export DB_SG_ID="<security_grp_ID>"
export DB_SG_ID="sg-0085da8cc9ede9b58"
gp env DB_SG_ID="<security_grp_ID>"
gp env DB_SG_ID="sg-0085da8cc9ede9b58"

# set security group rule as an env variable 
export DB_SG_RULE_ID="<security_grp_rule_ID>"
export DB_SG_RULE_ID="sgr-035c9252e732b0edf"
gp env DB_SG_RULE_ID="<security_grp_rule_ID>"
gp env DB_SG_RULE_ID="sgr-035c9252e732b0edf"
```

- After setting those up, run the command below: 

```bash
aws ec2 modify-security-group-rules \
    --group-id $DB_SG_ID \
    --security-group-rules "SecurityGroupRuleId=$DB_SG_RULE_ID,SecurityGroupRule={Description=GITPOD,IpProtocol=tcp,FromPort=5432,ToPort=5432,CidrIpv4=$GITPOD_IP/32}"
```

- To create the security group rule script, do the following:

```bash
# create file
touch backend-flask/bin/rds-update-sg-rule

# make the file executable
chmod 555 backend-flask/bin/rds-update-sg-rule

# execute the script 
./bin/rds-update-sg-rule OR ./backend-flask/bin/rds-update-sg-rule

OR

sh bin/rds-update-sg-rule OR sh backend-flask/bin/rds-update-sg-rule
```

- Add the following contents to the newly created file: 

```bash
#! /usr/bin/bash

CYAN='\033[1;36m'
NO_COLOR='\033[0m'
LABEL="Updating security group rule..."
printf "${CYAN}==== ${LABEL}${NO_COLOR}\n"

aws ec2 modify-security-group-rules \
    --group-id $DB_SG_ID \
    --security-group-rules "SecurityGroupRuleId=$DB_SG_RULE_ID,SecurityGroupRule={Description=GITPOD,IpProtocol=tcp,FromPort=5432,ToPort=5432,CidrIpv4=$GITPOD_IP/32}"
```

- Now let's make the configuration run every time we start up our environment. Do this by adding the following to our `gitpod.yml` file:

```yaml
# under the postgres installation
command: |
      export GITPOD_IP=$(curl ifconfig.me)
      source "$THEIA_WORKSPACE_ROOT/backend-flask/bin/rds-update-sg-rule"
```

- Commit your work and stop your `gitpod` workspace. Start a new `gitpod` workspace, and try connecting to your `prd` database which is simply your RDS instance in our case. 

```bash
# check for prd connection
./bin/db-connect prd OR ./backend-flask/bin/db-connect prd

OR

sh bin/db-connect prd OR sh backend-flask/bin/db-connect prd
```

**Set Up PRD connection**

To set up our `prd` URL in `docker-compose.yml`, we need to add it as an env variable. Now when we do this, anytime we want to connect to our database, it will always be connected to the `prd` one because the variable has been set on `docker compose` to use only that URL. 

```yaml
# add in the environment variable section
# comment out the previous one there 
CONNECTION_URL: "${PRD_CONNECTION_URL}"
```


### 8. Implement Lambda 

Lambda will be serving as our custom authorizer for `cognito`. During its implementation, we have to ensure that it runs in the same VPC as our RDS instance → which is our `prd` instance. Let’s go ahead and implement a `lambda` function.

We need to make sure we have users for our activities and also our `cognito_user_id` . If we don’t have this, there’s no way we can verify our users. 

Let’s navigate to our AWS console and follow the steps below:
- Search for the service, `Lambda` and click on `Create function`
- Once inside the `create function` page, select `Author from scratch`
- The function name can be anything you want, but I will name mine `cruddur-post-confirmation`
- Choose runtime as `Python 3.8`
- Leave our architecture as `x86_64` tho the `arm64` one is more efficient, but for this bootcamp, we will leave the default
- Leave every other default selections
- Go ahead and click `Create`

![Image of Lambda Create Function](assets/lambda-create-function-wizard.png)

Now we have our `lambda function`, let’s go ahead and customize our function. Go ahead and create this file, `aws/lambdas/cruddur-post-confirrmation.py` with the following contents:

```python
import json
import psycopg2
import os

def lambda_handler(event, context):
    user = event['request']['userAttributes']
    print('userAttributes')
    print(user)

    user_display_name  = user['name']
    user_email         = user['email']
    user_handle        = user['preferred_username']
    user_cognito_id    = user['sub']
    try:
      print('entered-try')
      sql = f"""
         INSERT INTO public.users (
          display_name, 
          email,
          handle, 
          cognito_user_id
          ) 
        VALUES(%s,%s,%s,%s)

        /* use either one
        VALUES (
        '{user_display_name}'
        '{user_email}'
        '{user_handle}'
        '{user_cognito_id}'
        )
        */

      """
      print('SQL Statement ----')
      print(sql)
      conn = psycopg2.connect(os.getenv('CONNECTION_URL'))
      cur = conn.cursor()
      params = [
        user_display_name,
        user_email,
        user_handle,
        user_cognito_id
      ]
      cur.execute(sql,params)
      conn.commit() 

    except (Exception, psycopg2.DatabaseError) as error:
      print(error)
    finally:
      if conn is not None:
          cur.close()
          conn.close()
          print('Database connection closed.')
    return event
```

After the changes to the above file, go back to the `lambda function` you created in your AWS console.
- Select the function, and click `Edit code source`
- Replace the code in the `lambda_function.py` with the code you have in your `cruddur-post-confirrmation.py` file
- Now, click on `Deploy` to deploy/save our new code changes

![Image of Editing Lambda Function](assets/editing-lambda-function.png)

- Let’s set our environment variables
    - Go to the `Configuration` tab, select `Environment variables`
    - Click on `Add` to add one
    - For the key = `CONNECTION_URL` and the value = `<copy_your_prd_url_from_gitpod>`

**--Add Lambda Layers**

Still in your lambda function in AWS console,
- Navigate to the `Code` tab,
- Scroll down to the `Layers` section,
- Click on `Add a layer` to add a layer
- Scroll down to the `Layer source` and choose `specify an ARN`

![Image of Adding Lambda Layer](assets/adding-lambda-layer.png)

- For our `lambda ARN`, go to this [link](https://github.com/jetbridge/psycopg2-lambda-layer) and copy the ARN for your region.
- Click on `Verify` to verify the ARN you entered
- Now click `Add` to add that layer.

**--Add Lambda Trigger**

Navigate to `Cognito` in your AWS console to add a lambda trigger.
- Go to the `User pool properties` tab
- Under lambda triggers, click on `Add Lambda trigger`

![Image of Adding Lambda Trigger](assets/adding-lambda-trigger.png)

- Once selected, in the **Trigger type**, select `Sign-up` as our trigger type
- For **Sign-up**, select `Post confirmation trigger`
- Scroll down to **Assign Lambda function** and select the lambda function you just created
- Then go ahead and click `Add lambda trigger`

![Image of Adding Lambda Trigger Wizard](assets/adding-lambda-trigger-wizard.png)

**--Connect Lambda to same VPC as RDS**

Still inside the lambda function configuration, 
- Navigate to the `Configuration` tab
- Select `VPC` and click `Edit`
- Under the VPC section, select a vpc - make sure is the same one the RDS instance is using
- Under `Subnets`, choose 2-3 subnets with your configured availability zone. If you remember when we were provisioning our RDS we chose `<MY_REGION_NUMBER_with_a>`
- Under `Security groups`, choose the security group associated with your selected VPC
- After that go ahead and `Save` the configuration

**Note**: You might get an error if you don’t have an EC2 role with `CreateNetworkInterface` action allowed.

Don't worry, we can fix that. Follow the instructions below to resolve it:

Inside the lambda function configuration, 
- Under the `Configurations` tab, go to `Permissions`
- Click on the role link provided under `Role name`
    - let’s see if it added a custom policy or managed one
- Under the **permissions policies**, you should see the `AWSLambdaVPCAccessExecutionRole` custom role, if not, go ahead and create it
    - Navigate to `Policy` by your right to create a new policy
    - Select the `JSON` tab and add the following content
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeNetworkInterfaces",
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeInstances",
        "ec2:AttachNetworkInterface"
      ],
      "Resource": "*"
    }
  ]
}
```

![Image of AWS Policy Creation](assets/aws-policy-creation.png)

- Click `Next`
- In the **Review Policy** section,
    - Name - `AWSLambdaVPCAccessExecutionRole`
    - Description - So AWS Lambda can create a network interface
    - Go ahead and create

![Image of Created AWS Policy](assets/created-aws-policy.png)

- After creation, by your right, click on `Role` to attach the policy we created
- Select your function role `<lambda_function_name-role-xxxx>`
- Scroll down to the `permissions` tab
- Move to the right of the page and you should see `Add permissions`. Click `Attach policies` to add the policy we just created
- You should see the `AWSLambdaVPCAccessExecutionRole` custom role under **permissions policies**, select it and **attach**.

Now, you should be able to add your VPC to the `lambda function` again. Follow these steps again:

Inside the lambda function configuration, 
- Navigate to the `Configuration` tab
- Select `VPC` and click `Edit`
- Under the VPC section, select a vpc - make sure is the same one the RDS instance is using
- Under `Subnets`, choose 2-3 subnets with your configured availability zone. If you remember when we were provisioning our RDS we chose `<MY_REGION_NUMBER_with_a>`
- Under `Security groups`, choose the security group associated with your selected VPC
- After that go ahead and `Save` the configuration

After the above configurations, let’s go to the `Monitor` tab in our `lambda function` page to check if there’s been any trigger. You shouldn’t see one until `cognito` triggers it when we try to sign up. 

Before deploying testing out our configurations, go to your `backend-flask/db/schema.sql` file, let's add this line of attribute to avoid getting any sort of errors when we deploy our function. 

```sql
# under the users table, after the "handle" attribute
email text NOT NULL,
```

Don't forget to reload your schema to your DB. 

```bash
./bin/db-schema-load prd 
```

Let’s start up our `frontend` by doing a `docker compose up` . Go ahead and open your `frontend` UI in the browser and try signing up with a different user. 

**Note**: You can either use the previous user you created in `Cognito` but you have to delete that user from `Cognito` first through the console. OR you just create a brand new user that doesn’t exist in `Cognito`.

If you get any error when trying to sign up, check what the error is by looking through your `CloudWatch logs`. Remember, whatever change you make to your `cruddur-post-confirrmation.py` file, make those changes to your `lambda_function.py` file in the console.

After creating the new user, confirm this user has been added to your database. 

```bash
# connect to DB
./bin/db-connect prd

# run these inside the database 
\dt                        # view our tables
SELECT * FROM users;       # view the newly created user
\x on
SELECT * FROM users;       # you should now see the user you created 
```


### 9. Create new activities

In your `backend-flask/lib/db.py` file, replace the code with the following:

```python
from psycopg_pool import ConnectionPool
import os
import re
import sys
from flask import current_app as app

class Db:
  def __init__(self):
    self.init_pool()

  def template(self,*args):
    pathing = list((app.root_path,'db','sql',) + args)
    pathing[-1] = pathing[-1] + ".sql"

    template_path = os.path.join(*pathing)

    green = '\033[92m'
    no_color = '\033[0m'
    print("\n")
    print(f'{green} Load SQL Template: {template_path} {no_color}')

    with open(template_path, 'r') as f:
      template_content = f.read()
    return template_content

  def init_pool(self):
    connection_url = os.getenv("CONNECTION_URL")
    self.pool = ConnectionPool(connection_url)
  # we want to commit data such as an insert
  # be sure to check for RETURNING in all uppercases
  def print_params(self,params):
    blue = '\033[94m'
    no_color = '\033[0m'
    print(f'{blue} SQL Params:{no_color}')
    for key, value in params.items():
      print(key, ":", value)

  def print_sql(self,title,sql):
    cyan = '\033[96m'
    no_color = '\033[0m'
    print(f'{cyan} SQL STATEMENT-[{title}]------{no_color}')
    print(sql)
  def query_commit(self,sql,params={}):
    self.print_sql('commit with returning',sql)

    pattern = r"\bRETURNING\b"
    is_returning_id = re.search(pattern, sql)

    try:
      with self.pool.connection() as conn:
        cur =  conn.cursor()
        cur.execute(sql,params)
        if is_returning_id:
          returning_id = cur.fetchone()[0]
        conn.commit() 
        if is_returning_id:
          return returning_id
    except Exception as err:
      self.print_sql_err(err)
  # when we want to return a json object
  def query_array_json(self,sql,params={}):
    self.print_sql('array',sql)

    wrapped_sql = self.query_wrap_array(sql)
    with self.pool.connection() as conn:
      with conn.cursor() as cur:
        cur.execute(wrapped_sql,params)
        json = cur.fetchone()
        return json[0]
  # When we want to return an array of json objects
  def query_object_json(self,sql,params={}):

    self.print_sql('json',sql)
    self.print_params(params)
    wrapped_sql = self.query_wrap_object(sql)

    with self.pool.connection() as conn:
      with conn.cursor() as cur:
        cur.execute(wrapped_sql,params)
        json = cur.fetchone()
        if json == None:
          "{}"
        else:
          return json[0]
  def query_wrap_object(self,template):
    sql = f"""
    (SELECT COALESCE(row_to_json(object_row),'{{}}'::json) FROM (
    {template}
    ) object_row);
    """
    return sql
  def query_wrap_array(self,template):
    sql = f"""
    (SELECT COALESCE(array_to_json(array_agg(row_to_json(array_row))),'[]'::json) FROM (
    {template}
    ) array_row);
    """
    return sql
  def print_sql_err(self,err):
    # get details about the exception
    err_type, err_obj, traceback = sys.exc_info()

    # get the line number when exception occured
    line_num = traceback.tb_lineno

    # print the connect() error
    print ("\npsycopg ERROR:", err, "on line number:", line_num)
    print ("psycopg traceback:", traceback, "-- type:", err_type)

    # print the pgcode and pgerror exceptions
    print ("pgerror:", err.pgerror)
    print ("pgcode:", err.pgcode, "\n")

db = Db()
```

Now, in your `backend-flask/services/create_activities.py`, replace your code with the following code:

```python
from datetime import datetime, timedelta, timezone

from lib.db import db

class CreateActivity:
  def run(message, user_handle, ttl):
    model = {
      'errors': None,
      'data': None
    }

    now = datetime.now(timezone.utc).astimezone()

    if (ttl == '30-days'):
      ttl_offset = timedelta(days=30) 
    elif (ttl == '7-days'):
      ttl_offset = timedelta(days=7) 
    elif (ttl == '3-days'):
      ttl_offset = timedelta(days=3) 
    elif (ttl == '1-day'):
      ttl_offset = timedelta(days=1) 
    elif (ttl == '12-hours'):
      ttl_offset = timedelta(hours=12) 
    elif (ttl == '3-hours'):
      ttl_offset = timedelta(hours=3) 
    elif (ttl == '1-hour'):
      ttl_offset = timedelta(hours=1) 
    else:
      model['errors'] = ['ttl_blank']

    if user_handle == None or len(user_handle) < 1:
      model['errors'] = ['user_handle_blank']

    if message == None or len(message) < 1:
      model['errors'] = ['message_blank'] 
    elif len(message) > 280:
      model['errors'] = ['message_exceed_max_chars'] 

    if model['errors']:
      model['data'] = {
        'handle':  user_handle,
        'message': message
      }   
    else:
      expires_at = (now + ttl_offset)
      uuid = CreateActivity.create_activity(user_handle,message,expires_at)

      object_json = CreateActivity.query_object_activity(uuid)
      model['data'] = object_json
    return model

  def create_activity(handle, message, expires_at):
    sql = db.template('activities','create')
    uuid = db.query_commit(sql,{
      'handle': handle,
      'message': message,
      'expires_at': expires_at
    })
    return uuid
  def query_object_activity(uuid):
    sql = db.template('activities','object')
    return db.query_object_json(sql,{
      'uuid': uuid
    })
```

Also, in your `backend-flask/services/home_activities.py`, replace your code with the following code:

```python
from datetime import datetime, timedelta, timezone
from opentelemetry import trace

from lib.db import db

# tracer = trace.get_tracer("home.activities")

class HomeActivities:
  def run(cognito_user_id=None):
  # CloudWatch Logs
  # def run(logger):
    # logger.info("HomeActivities")
    
    # create a span
    #with tracer.start_as_current_span("home-activities-mock-data"):
      #span = trace.get_current_span()
      # add an attribute 
      #now = datetime.now(timezone.utc).astimezone()
      #span.set_attribute("app.now", now.isoformat())

      sql = db.template('activities','home')
      results = db.query_array_json(sql)
      return results
```

**Let's make some SQL scripts for our `activities` table**

```bash
# create the sql/activities folder 
mkdir -p backend-flask/db/sql/activities
```

- Create the `backend-flask/db/sql/activities/create.sql` script and add the following contents:

```bash
# create the "create activities" SQL script
touch backend-flask/db/sql/activities/create.sql
```

Script content:

```sql
# add the following contents
INSERT INTO public.activities (
  user_uuid,
  message,
  expires_at
)
VALUES (
  (SELECT uuid 
    FROM public.users 
    WHERE users.handle = %(handle)s
    LIMIT 1
  ),
  %(message)s,
  %(expires_at)s
) RETURNING uuid;
```

- Create the `backend-flask/db/sql/activities/home.sql` script and add the following contents:

```bash
touch backend-flask/db/sql/activities/home.sql
```

Script content:

```sql
# add the following contents
SELECT
  activities.uuid,
  users.display_name,
  users.handle,
  activities.message,
  activities.replies_count,
  activities.reposts_count,
  activities.likes_count,
  activities.reply_to_activity_uuid,
  activities.expires_at,
  activities.created_at
FROM public.activities
LEFT JOIN public.users ON users.uuid = activities.user_uuid
ORDER BY activities.created_at DESC
```

- Create the `backend-flask/db/sql/activities/object.sql` script and add the following contents:

```bash
touch backend-flask/db/sql/activities/object.sql
```

Script content:

```sql
# add the following contents
SELECT
  activities.uuid,
  users.display_name,
  users.handle,
  activities.message,
  activities.created_at,
  activities.expires_at
FROM public.activities
INNER JOIN public.users ON users.uuid = activities.user_uuid 
WHERE 
  activities.uuid = %(uuid)s
```

- Now, let's update our `aws/lambdas/cruddur-post-confirrmation.py` file to have the following content:

```python
# DELETE THIS 
cur.execute(sql)

# ADD THIS 
params = [
        user_display_name,
        user_email,
        user_handle,
        user_cognito_id
      ]
      cur.execute(sql,params)
```

**Important:** Don’t forget to update and deploy your changes to your `lambda_function.py` file in your AWS Console - Lambda.

After your configurations, do a `docker compose up` to test out your code. Try creating a post and see if it goes through.


**Troubleshooting**

***Error 1:*** If you are encountering this error, follow the instructions below to resolve them:

![Image of Lambda Function Error](assets/lambda-function-error.png)

The lambda error above is simply because of the `*` symbol in front of params in our `lambda_function.py` file. If you remove that and deploy the new changes, that should take the error away. Don't forget to replace the code in the `lambda_function.py` with the code you have in your `cruddur-post-confirrmation.py` file. 

![Image of Fixed Lambda Function Error](assets/fixed-lambda-function-error.png)


***Error 2:*** If you are encountering these errors, follow the instructions below to resolve them:

![Image of NotNullViolation Error 1](assets/not-null-violation-error-1.png)

![Image of NotNullViolation Error 2](assets/not-null-violation-error-2.png)

Make the following changes to your code, and that should fix that error. 

![Image of Fixing NotNullViolation Error 1](assets/fixing-not-null-violation-error-1.png)

![Image of Fixing NotNullViolation Error 2](assets/fixing-not-null-violation-error-2.png)

![Image of Fixing NotNullViolation Error 3](assets/fixing-not-null-violation-error-3.png)



