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
# create a database in postgres 
CREATE DATABASE cruddur;

# confirm the database has been created 
\l

# quit the database 
\q
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

### 4. Creating BASH scripts for the DB

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

--For our `seed.sql` file, here are the steps to create and add mock data:

In our `backend-flask/db`, create a file called `seed.sql`:

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

--For our `db-seed` file, here are the steps to create the script for mocking data: 

In our `backend-flask/bin`, create a file called `db-seed`:

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

First we need to log into our postgres client with our newly created scripts.

```bash
./bin/db-connect OR ./backend-flask/bin/db-connect

OR

sh bin/db-connect OR sh backend-flask/bin/db-connect
```

Inside the postgres database, run the following commands:

```sql
# see the contents of your activities table 
SELECT * FROM activities;

# to see the expanded display of the table - it makes it easier to view records 
\x
OR 
\x auto # automatically display the expanded version of the table
SELECT * FROM activities;
```

**SCRIPT 6 - Script for viewing DB sessions **

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




### 5. 

### 6.








